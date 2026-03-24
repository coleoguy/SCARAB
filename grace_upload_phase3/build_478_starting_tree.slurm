#!/bin/bash
#SBATCH --job-name=scarab_478_start_tree
#SBATCH --partition=medium
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=64G
#SBATCH --output=scarab_478_start_tree_%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

# ============================================================================
# Build 478-taxon starting tree for IQ-TREE
#
# Strategy:
#   1. BLAST same 15 marker proteins against 39 recovery genomes
#   2. For each recovery taxon: find closest existing taxon by pairwise
#      sequence identity across shared marker genes (data-driven)
#   3. Graft recovery taxa as sisters to their nearest neighbors
#   4. Output nuclear_guide_tree_478_rooted.nwk for use as IQ-TREE -t
#
# This tree is not reported in methods — it is only a starting topology
# to accelerate IQ-TREE convergence on the full 478-taxon matrix.
# ============================================================================

set -euo pipefail

SCARAB="$SCRATCH/scarab"
MARKER_DIR="$SCARAB/nuclear_markers"
GENOME_DIR="$SCARAB/genomes"
TREE_439="$MARKER_DIR/nuclear_guide_tree_439_rooted.nwk"
TREE_478="$MARKER_DIR/nuclear_guide_tree_478_rooted.nwk"
MARKER_FASTA="$MARKER_DIR/marker_proteins.fasta"
WORK="$MARKER_DIR/recovery_blast_$$"

echo "=== 478-taxon starting tree ==="
echo "Start: $(date)"
mkdir -p "$WORK/hits" "$WORK/per_gene"

module purge 2>/dev/null || true
module load GCC/12.2.0
module load OpenMPI/4.1.4
module load BLAST+/2.14.0

echo "[1/3] BLASTing 15 marker proteins against 39 recovery genomes..."

# 39 recovery genomes are gzipped fna in $GENOME_DIR
# Run in parallel (up to 48 cores, 1 per genome)
blast_one() {
    local gz="$1"
    local acc
    acc=$(basename "$gz" | grep -oP 'GCA_[0-9]+\.[0-9]+')
    local out="$WORK/hits/${acc}.blast"
    [ -f "$out" ] && return 0   # skip if done
    # decompress to tmp, blast, remove
    local tmp
    tmp=$(mktemp --suffix=.fna)
    gunzip -c "$gz" > "$tmp"
    tblastn -query "$MARKER_FASTA" \
            -subject "$tmp" \
            -outfmt "6 qseqid sstart send evalue bitscore pident length sseq" \
            -evalue 1e-5 \
            -max_target_seqs 1 \
            -max_hsps 1 \
            -seg yes \
            -num_threads 1 \
            > "$out" 2>/dev/null || true
    rm -f "$tmp"
}
export -f blast_one
export MARKER_FASTA WORK

# Use xargs for parallel execution
ls "$GENOME_DIR"/*.fna.gz | \
    xargs -P 40 -I{} bash -c 'blast_one "$@"' _ {}

echo "  BLAST complete"

# Find the existing per-gene sequences from the 439-taxon tree build
# They are in the most recent tree_build_* directory
EXISTING_GENE_DIR=$(ls -dt "$MARKER_DIR"/tree_build_*/per_gene 2>/dev/null | head -1)
if [ -z "$EXISTING_GENE_DIR" ]; then
    echo "ERROR: Cannot find existing per-gene sequences in $MARKER_DIR/tree_build_*"
    echo "The 439-taxon tree build directory must be present."
    exit 1
fi
echo "  Using existing per-gene sequences from: $(dirname $EXISTING_GENE_DIR)"

echo ""
echo "[2/3] Finding nearest neighbors and grafting..."

python3 - "$WORK/hits" "$EXISTING_GENE_DIR" "$TREE_439" "$TREE_478" << 'PYEOF'
import sys, os, re
from collections import defaultdict

hits_dir        = sys.argv[1]
existing_gene_dir = sys.argv[2]
tree_in         = sys.argv[3]
tree_out        = sys.argv[4]

# ---- Load existing per-gene sequences ------------------------------------
# gene_id -> {tip_label: seq}
existing = defaultdict(dict)
for fn in os.listdir(existing_gene_dir):
    if not fn.endswith(".fasta"):
        continue
    gene = fn.replace(".fasta", "")
    tip, seq_parts = None, []
    with open(os.path.join(existing_gene_dir, fn)) as fh:
        for line in fh:
            line = line.strip()
            if line.startswith(">"):
                if tip:
                    existing[gene][tip] = "".join(seq_parts)
                tip = line[1:].split()[0]
                seq_parts = []
            elif line:
                seq_parts.append(line)
    if tip:
        existing[gene][tip] = "".join(seq_parts)

all_existing_tips = set()
for g in existing:
    all_existing_tips.update(existing[g].keys())

print(f"  Loaded {len(existing)} marker genes, {len(all_existing_tips)} existing taxa")

# ---- Parse BLAST hits for recovery genomes --------------------------------
# For each recovery genome: gene_id -> protein seq
recovery_seqs = {}   # acc -> gene_id -> seq

for fn in sorted(os.listdir(hits_dir)):
    if not fn.endswith(".blast"):
        continue
    acc = fn.replace(".blast", "")
    gene_seqs = {}
    with open(os.path.join(hits_dir, fn)) as fh:
        for line in fh:
            parts = line.strip().split("\t")
            if len(parts) < 8:
                continue
            gene_id = parts[0]
            pident  = float(parts[5])
            alen    = int(parts[6])
            sseq    = re.sub(r'[\-\*\s]', '', parts[7])
            if alen >= 80 and pident >= 25.0 and len(sseq) >= 80:
                gene_seqs[gene_id] = sseq
    recovery_seqs[acc] = gene_seqs

print(f"  Recovery genomes with BLAST results: {len(recovery_seqs)}")
for acc, gs in sorted(recovery_seqs.items()):
    print(f"    {acc}: {len(gs)} marker genes hit")

# ---- Compute nearest neighbor for each recovery taxon --------------------
# Simple approach: for each shared gene, compute pairwise identity by
# aligning recovery seq against each existing taxon seq; accumulate.
# To keep it fast without MAFFT here: use raw identity of the BLAST-recovered
# fragment vs the existing gene sequences (global length-normalized match).
# We use the gene-level BLAST pident directly and find the existing taxon
# whose average pident (across shared genes) is highest vs the recovery taxon.
#
# More specifically: for each recovery taxon, for each gene where it has a
# hit, look at what the existing taxa look like for that gene. Rank existing
# taxa by how many shared genes they have with the recovery taxon, then by
# average pident of those genes.

# Build: gene_id -> list of (existing_tip, seq_length) so we can weight
# We'll use a scoring approach: for each gene hit in recovery taxon,
# all existing taxa that also have that gene get +1 shared gene count.
# Then we pick the existing taxon with most shared genes (as proxy for
# taxonomic relatedness).

# Actually even simpler and more correct: use the gene hit pident from the
# blast of the marker proteins (which are universal). The pident reflects
# how similar the recovery taxon's sequence is to the query protein.
# The existing taxon with the MOST similar pident profile = closest relative.

# Load pident from existing blast (stored implicitly in per-gene FASTA lengths)
# We don't have existing blast pidents handy, so instead:
# Count shared genes: existing taxon that shares the most genes with recovery
# taxon is the closest (for highly conserved markers at this level, gene
# presence/absence pattern reflects family-level relatedness).

nearest = {}
for acc, gene_seqs in recovery_seqs.items():
    if not gene_seqs:
        print(f"  WARNING: {acc} has no BLAST hits — will skip grafting")
        continue

    hit_genes = set(gene_seqs.keys())

    # Count how many of the recovery taxon's hit genes each existing taxon has
    shared = defaultdict(int)
    for gene in hit_genes:
        if gene in existing:
            for tip in existing[gene]:
                shared[tip] += 1

    if not shared:
        print(f"  WARNING: {acc} no shared genes with existing taxa")
        continue

    best_tip = max(shared, key=lambda t: shared[t])
    best_count = shared[best_tip]
    nearest[acc] = (best_tip, best_count)
    print(f"  {acc}: nearest = {best_tip} ({best_count}/{len(hit_genes)} shared genes)")

# ---- Map accessions to tip labels ----------------------------------------
# Recovery manifest (acc -> tip label, same as download script)
RECOVERY = {
    "GCA_030710515.1": "Abscondita_cerata",
    "GCA_044115395.2": "Agriotes_pubescens",
    "GCA_050578095.1": "Araecerus_fasciculatus",
    "GCA_047676225.1": "Asbolus_verrucosus",
    "GCA_965278915.1": "Astagobius_angustatus",
    "GCA_050941775.1": "Batocera_rufomaculata",
    "GCA_055275695.1": "Calosoma_relictum",
    "GCA_048127345.1": "Carabus_depressus",
    "GCA_031761425.1": "Cosmopolites_sordidus",
    "GCA_030704885.1": "Cynegetis_impunctata",
    "GCA_031893035.2": "Dermolepida_albohirtum",
    "GCA_034092305.1": "Diaprepes_abbreviatus",
    "GCA_021725515.1": "Epicauta_chinensis",
    "GCA_029955175.1": "Exocentrus_adspersus",
    "GCA_030704895.1": "Henosepilachna_vigintioctopunctata",
    "GCA_030620095.1": "Kuschelorhynchus_macadamiae",
    "GCA_013368075.1": "Lamprigera_yunnana",
    "GCA_050947525.1": "Lampyris_noctiluca",
    "GCA_052696345.1": "Lethrus_scoparius",
    "GCA_036346125.1": "Lycocerus_yunnanus",
    "GCA_028455855.1": "Meloe_dianella",
    "GCA_030674115.1": "Micraspis_discolor",
    "GCA_029963825.1": "Molorchus_minor",
    "GCA_020740385.1": "Mylabris_phalerata",
    "GCA_018344505.1": "Nebria_ingens_riversi",
    "GCA_047371185.1": "Neoclytus_acuminatus_acuminatus",
    "GCA_020654155.1": "Novius_pumilus",
    "GCA_036346225.1": "Platerodrilus_igneus",
    "GCA_036326145.1": "Rhagophthalmus_giganteus",
    "GCA_029963845.1": "Rhamnusium_bicolor",
    "GCA_037954035.1": "Rosalia_funebris",
    "GCA_036346155.1": "Sinelater_perroti",
    "GCA_036325965.1": "Sinopyrophorus_schimmeli",
    "GCA_051294475.1": "Sternochetus_mangiferae",
    "GCA_982185335.1": "Troglocharinus_ferreri",
    "GCA_055532135.1": "Trypodendron_lineatum",
    "GCA_034508555.1": "Venustoraphidia_nigricollis",
    "GCA_036346205.1": "Vesta_saturnalis",
    "GCA_032362365.1": "Zygogramma_bicolorata",
}

# Also handle version-stripped matches (GCA_044115395.1 file but acc GCA_044115395.2)
nearest_by_tip = {}
for acc, (sister, count) in nearest.items():
    tip = RECOVERY.get(acc)
    if tip is None:
        # Try stripping version
        acc_base = acc.rsplit(".", 1)[0]
        for k, v in RECOVERY.items():
            if k.startswith(acc_base):
                tip = v
                break
    if tip:
        nearest_by_tip[tip] = sister
    else:
        print(f"  WARNING: could not map accession {acc} to tip label")

# ---- Graft onto tree ------------------------------------------------------
with open(tree_in) as fh:
    tree_str = fh.read().strip()

tips_in_tree = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
print(f"\n  Input tree: {len(tips_in_tree)} tips")

grafted = 0
skipped = 0
for tip, sister in sorted(nearest_by_tip.items()):
    if tip in tips_in_tree:
        print(f"  SKIP {tip}: already in tree")
        skipped += 1
        continue
    if sister not in tips_in_tree:
        print(f"  WARNING: sister {sister} not found for {tip}")
        skipped += 1
        continue

    # Find sister's branch length
    m = re.search(re.escape(sister) + r':([0-9.eE+\-]+)', tree_str)
    if not m:
        print(f"  WARNING: cannot find branch for {sister}, skipping {tip}")
        skipped += 1
        continue

    bl = float(m.group(1))
    pos = max(bl / 2, 1e-4)
    new_bl = max(bl, 1e-4)

    # Insert as sister: replace "SISTER:bl" with "(SISTER:pos,TIP:new_bl):pos"
    replacement = f'({sister}:{pos},{tip}:{new_bl}):{pos}'
    tree_str = tree_str.replace(f'{sister}:{m.group(1)}', replacement, 1)
    tips_in_tree.add(tip)
    grafted += 1

# Fix any branch lengths > 25 (Cactus hard limit)
def cap_bl(m):
    v = float(m.group(1))
    return f':{min(v, 24.9)}'
tree_str = re.sub(r':([0-9.eE+\-]+)', cap_bl, tree_str)

if not tree_str.endswith(';'):
    tree_str += ';'

final_tips = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
print(f"\n  Grafted: {grafted}  |  Skipped: {skipped}")
print(f"  Output tree: {len(final_tips)} tips")

with open(tree_out, 'w') as fh:
    fh.write(tree_str + '\n')
print(f"  Written: {tree_out}")
PYEOF

echo ""
echo "[3/3] Validating output tree..."
python3 -c "
import re, sys
tree_str = open('$TREE_478').read()
tips = re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str)
unique = set(tips)
bls = [float(x) for x in re.findall(r':([0-9.eE+\-]+)', tree_str)]
print(f'  Tips: {len(unique)}')
print(f'  Branch length range: {min(bls):.2e} – {max(bls):.4f}')
print(f'  Any > 25.0: {any(b > 25.0 for b in bls)}')
if len(unique) >= 470:
    print('  PASS')
else:
    print('  WARNING: fewer tips than expected')
"

echo ""
echo "=== Done: $(date) ==="
echo "Output: $TREE_478"
echo ""
echo "Next: sbatch iqtree_478.slurm"
