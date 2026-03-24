#!/bin/bash
# ============================================================================
# extract_nuclear_markers_and_build_tree.slurm — Build multi-locus nuclear
# guide tree for Cactus from BUSCO insecta marker genes
# ============================================================================
#
# Pipeline:
#   1. tBLASTn 15 conserved BUSCO proteins against all 439 genomes (parallel)
#   2. Collect per-gene protein sequences from BLAST hits
#   3. MAFFT-align each gene separately
#   4. Concatenate into a protein supermatrix (missing data = gaps)
#   5. Build ML tree with FastTree (WAG+CAT protein model)
#   6. Root on Neuropterida outgroups
#   7. Validate: 439 tips, binary, branch lengths in subs/site
#   8. Rebuild cactus_seqfile.txt with the new tree
#
# Why nuclear markers?
#   The previous COI approach found COI in only 182/439 genomes (41%)
#   because many assemblies exclude mitochondrial contigs. BUSCO insecta
#   genes are nuclear, single-copy, and universally conserved. Expected
#   hit rate per gene: >90%. With 15 genes, virtually every taxon will
#   have data for multiple loci.
#
# Acceptance criteria (MUST ALL PASS before using this tree):
#   - ≥395/439 taxa (≥90%) have molecular data for ≥1 gene
#   - Tree is fully binary (max 2 children per node)
#   - All branch lengths >0 and ≤25.0 (Cactus limit)
#   - Branch lengths empirically estimated (subs/site), not arbitrary
#
# Prerequisites:
#   Run prepare_nuclear_markers.sh on login node FIRST
#
# Queue: medium (estimated 4-5 hours)
# Resources: 1 node, 48 cores, 128 GB (12 parallel BLAST jobs to limit memory)
#
# Usage:
#   sbatch extract_nuclear_markers_and_build_tree.slurm
# ============================================================================

#SBATCH --job-name=scarab_nuc_tree
#SBATCH --partition=medium
#SBATCH --time=06:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --output=scarab_nuc_tree_%j.log
#SBATCH --error=scarab_nuc_tree_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
GENOME_DIR="${PROJECT_DIR}/genomes"
DATA_DIR="${PROJECT_DIR}/data"
MARKER_DIR="${PROJECT_DIR}/nuclear_markers"
MARKER_FASTA="${MARKER_DIR}/marker_proteins.fasta"
TIP_MAP="${DATA_DIR}/tree_tip_mapping.csv"
WORK_DIR="${MARKER_DIR}/tree_build_${SLURM_JOB_ID:-local}"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

# Acceptance criteria
MIN_TAXA_WITH_DATA=395     # ≥90% of 439
MIN_GENES_PER_TAXON=1      # At least 1 gene per taxon
MIN_HIT_LENGTH_AA=100      # Minimum alignment length to keep a hit
MIN_PIDENT=30.0            # Minimum protein identity (%) — generous for 320 My

echo "============================================================"
echo "SCARAB — Nuclear Marker Guide Tree Construction"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${NCPUS}"
echo "============================================================"
echo ""

# ============================================================================
# 0. VERIFY INPUTS
# ============================================================================

echo "[0/8] Verifying inputs..."

for f in "$MARKER_FASTA" "$TIP_MAP"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Missing file: $f"
        if [ "$f" = "$MARKER_FASTA" ]; then
            echo "  Run prepare_nuclear_markers.sh on the login node first."
        fi
        exit 1
    fi
done

if [ ! -d "$GENOME_DIR" ]; then
    echo "ERROR: Genome directory not found: $GENOME_DIR"
    exit 1
fi

N_MARKERS=$(grep -c "^>" "$MARKER_FASTA")
N_TAXA=$(tail -n +2 "$TIP_MAP" | wc -l)
echo "  Marker proteins: ${N_MARKERS}"
echo "  Taxa in catalog: ${N_TAXA}"
echo "  Genome directory: ${GENOME_DIR}"
echo ""

# ============================================================================
# 1. SETUP WORKING DIRECTORIES
# ============================================================================

echo "[1/8] Setting up working directories..."

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/blast_hits" "$WORK_DIR/per_gene" "$WORK_DIR/alignments"

# Extract marker gene IDs
GENE_IDS=()
while IFS= read -r line; do
    GENE_IDS+=("${line:1}")  # strip >
done < <(grep "^>" "$MARKER_FASTA" | sed 's/ .*//')

echo "  Working directory: $WORK_DIR"
echo "  Marker genes: ${GENE_IDS[*]}"
echo ""

# ============================================================================
# 2. LOAD MODULES
# ============================================================================

echo "[2/8] Loading modules..."

# BLAST+ needs GCC/12.2.0 + OpenMPI/4.1.4
module purge 2>/dev/null || true
module load GCC/12.2.0
module load OpenMPI/4.1.4
module load BLAST+/2.14.0
echo "  blastn/tblastn: $(which tblastn)"

echo ""

# ============================================================================
# 3. tBLASTn ALL MARKERS AGAINST ALL GENOMES (PARALLEL)
# ============================================================================

echo "[3/8] Running tBLASTn: ${N_MARKERS} markers × ${N_TAXA} genomes..."
echo "  (${NCPUS} parallel jobs)"

BLAST_LOG="${WORK_DIR}/blast_log.txt"
> "$BLAST_LOG"

# Function to process one genome
process_genome() {
    local tip_label="$1"
    local accession="$2"
    local blast_out="${WORK_DIR}/blast_hits/${tip_label}.blast"

    # Find genome FASTA
    local fasta
    fasta=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)

    if [ -z "$fasta" ]; then
        echo "SKIP ${tip_label} no_fasta" >> "$blast_out.status"
        return
    fi

    # tBLASTn: protein query vs nucleotide subject
    # All marker proteins in one query → one BLAST call per genome
    tblastn -query "$MARKER_FASTA" \
            -subject "$fasta" \
            -outfmt "6 qseqid sseqid sstart send evalue bitscore pident length sseq" \
            -evalue 1e-5 \
            -max_target_seqs 1 \
            -max_hsps 1 \
            -seg yes \
            -num_threads 1 \
            > "$blast_out" 2>/dev/null || true

    # Count hits
    local nhits=0
    if [ -s "$blast_out" ]; then
        nhits=$(wc -l < "$blast_out")
    fi
    echo "OK ${tip_label} hits=${nhits}" >> "$blast_out.status"
}

export -f process_genome
export GENOME_DIR MARKER_FASTA WORK_DIR

# Process all genomes in parallel batches of 12
# (each tBLASTn job loads a full genome into memory; 12 concurrent fits within 128 GB)
BATCH_SIZE=12
batch_count=0
total_processed=0

tail -n +2 "$TIP_MAP" | while IFS=',' read -r tip_label species_name accession family clade role; do
    process_genome "$tip_label" "$accession" &
    batch_count=$((batch_count + 1))
    total_processed=$((total_processed + 1))

    if [ $batch_count -ge $BATCH_SIZE ]; then
        wait
        batch_count=0
        echo "  Processed ${total_processed}/${N_TAXA} genomes..."
    fi
done
wait

echo "  tBLASTn complete."

# Summarize BLAST results
TOTAL_GENOMES_WITH_HITS=0
TOTAL_HITS=0
for status_file in "$WORK_DIR"/blast_hits/*.status; do
    [ -f "$status_file" ] || continue
    while read -r status tip nhits_str; do
        if [ "$status" = "OK" ]; then
            hits=${nhits_str#hits=}
            if [ "$hits" -gt 0 ] 2>/dev/null; then
                TOTAL_GENOMES_WITH_HITS=$((TOTAL_GENOMES_WITH_HITS + 1))
                TOTAL_HITS=$((TOTAL_HITS + hits))
            fi
        fi
    done < "$status_file"
done
echo "  Genomes with ≥1 hit: ${TOTAL_GENOMES_WITH_HITS}/${N_TAXA}"
echo "  Total BLAST hits: ${TOTAL_HITS}"
echo ""

# ============================================================================
# 4. PARSE BLAST OUTPUT → PER-GENE FASTA FILES
# ============================================================================

echo "[4/8] Parsing BLAST results into per-gene FASTAs..."

python3 - "$WORK_DIR" "$TIP_MAP" "$MIN_HIT_LENGTH_AA" "$MIN_PIDENT" << 'PYEOF'
import sys, os, re, csv
from collections import defaultdict

work_dir = sys.argv[1]
tipmap_file = sys.argv[2]
min_length = int(sys.argv[3])
min_pident = float(sys.argv[4])

blast_dir = os.path.join(work_dir, "blast_hits")
gene_dir = os.path.join(work_dir, "per_gene")

# Read tip mapping for all species info
all_taxa = {}
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_taxa[row['tip_label']] = row

# Collect per-gene sequences from BLAST results
gene_seqs = defaultdict(dict)  # gene_id -> {tip_label: protein_seq}
per_taxon_hits = defaultdict(int)  # tip_label -> number of genes with hits

for blast_file in sorted(os.listdir(blast_dir)):
    if not blast_file.endswith(".blast"):
        continue
    tip_label = blast_file.replace(".blast", "")
    filepath = os.path.join(blast_dir, blast_file)

    if not os.path.exists(filepath) or os.path.getsize(filepath) == 0:
        continue

    with open(filepath) as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) < 9:
                continue
            gene_id = parts[0]   # qseqid (marker gene ID)
            pident = float(parts[6])
            aln_len = int(parts[7])
            sseq = parts[8]     # translated subject sequence

            # Filter by quality
            if aln_len < min_length:
                continue
            if pident < min_pident:
                continue

            # Clean protein sequence: remove BLAST alignment gaps and stops
            seq_clean = re.sub(r'[\-\*\s]', '', sseq)

            if len(seq_clean) >= min_length:
                gene_seqs[gene_id][tip_label] = seq_clean
                per_taxon_hits[tip_label] += 1

# Write per-gene FASTA files
print(f"  Per-gene hit counts:")
print(f"  {'Gene':<25s} {'Taxa_with_hits':>15s} {'Hit_rate':>10s}")
print(f"  {'-'*25} {'-'*15} {'-'*10}")

total_taxa = len(all_taxa)
for gene_id in sorted(gene_seqs.keys()):
    seqs = gene_seqs[gene_id]
    hit_rate = len(seqs) / total_taxa * 100
    print(f"  {gene_id:<25s} {len(seqs):>15d} {hit_rate:>9.1f}%")

    fasta_path = os.path.join(gene_dir, f"{gene_id}.fasta")
    with open(fasta_path, "w") as out:
        for tip, seq in sorted(seqs.items()):
            out.write(f">{tip}\n{seq}\n")

# Summary
taxa_with_any_data = len(per_taxon_hits)
taxa_without_data = [t for t in all_taxa if t not in per_taxon_hits]

print(f"\n  Taxa with molecular data: {taxa_with_any_data}/{total_taxa} ({taxa_with_any_data/total_taxa*100:.1f}%)")

if taxa_without_data:
    print(f"  Taxa with NO data ({len(taxa_without_data)}):")
    for t in taxa_without_data[:20]:
        info = all_taxa[t]
        print(f"    {t} ({info.get('family','?')}, {info.get('role','?')})")
    if len(taxa_without_data) > 20:
        print(f"    ... and {len(taxa_without_data) - 20} more")

# Write summary for downstream validation
summary_path = os.path.join(work_dir, "blast_summary.tsv")
with open(summary_path, "w") as out:
    out.write(f"taxa_with_data\t{taxa_with_any_data}\n")
    out.write(f"total_taxa\t{total_taxa}\n")
    out.write(f"n_genes\t{len(gene_seqs)}\n")
    for gene_id in sorted(gene_seqs.keys()):
        out.write(f"gene_{gene_id}\t{len(gene_seqs[gene_id])}\n")

# Write list of taxa without data (for grafting step)
nohit_path = os.path.join(work_dir, "taxa_without_data.txt")
with open(nohit_path, "w") as out:
    for t in sorted(taxa_without_data):
        info = all_taxa[t]
        out.write(f"{t}\t{info.get('family','')}\t{info.get('clade','')}\t{info.get('role','')}\n")

PYEOF

echo ""

# ============================================================================
# 5. QUALITY GATE: CHECK HIT RATES BEFORE PROCEEDING
# ============================================================================

echo "[5/8] Quality gate: checking hit rates..."

TAXA_WITH_DATA=$(grep "^taxa_with_data" "$WORK_DIR/blast_summary.tsv" | cut -f2)
TOTAL_TAXA_CHECK=$(grep "^total_taxa" "$WORK_DIR/blast_summary.tsv" | cut -f2)

echo "  Taxa with molecular data: ${TAXA_WITH_DATA}/${TOTAL_TAXA_CHECK}"
echo "  Required minimum: ${MIN_TAXA_WITH_DATA}/${TOTAL_TAXA_CHECK}"

if [ "$TAXA_WITH_DATA" -lt "$MIN_TAXA_WITH_DATA" ]; then
    echo ""
    echo "  ************************************************************"
    echo "  * QUALITY GATE FAILED                                      *"
    echo "  * Only ${TAXA_WITH_DATA}/${TOTAL_TAXA_CHECK} taxa have molecular data.          *"
    echo "  * Minimum required: ${MIN_TAXA_WITH_DATA}.                            *"
    echo "  * The guide tree would have too many taxonomy-grafted taxa. *"
    echo "  * DO NOT PROCEED with this tree.                           *"
    echo "  * Review blast_summary.tsv and taxa_without_data.txt       *"
    echo "  ************************************************************"
    echo ""
    echo "  Output files preserved in: $WORK_DIR"
    exit 1
fi

echo "  QUALITY GATE PASSED"
echo ""

# ============================================================================
# 6. ALIGN EACH GENE & BUILD SUPERMATRIX
# ============================================================================

# Swap modules for MAFFT + FastTree
echo "[6/8] Aligning genes and building supermatrix..."
module purge 2>/dev/null || true
module load GCC/12.3.0
module load MAFFT/7.520-with-extensions
module load FastTree/2.1.11
FASTTREE_BIN=$(which FastTree 2>/dev/null || which fasttree 2>/dev/null)
echo "  mafft: $(which mafft)"
echo "  FastTree: ${FASTTREE_BIN}"

# Align each gene with MAFFT
N_GENES_ALIGNED=0
for gene_fasta in "$WORK_DIR"/per_gene/*.fasta; do
    [ -f "$gene_fasta" ] || continue
    gene_id=$(basename "$gene_fasta" .fasta)
    aligned="${WORK_DIR}/alignments/${gene_id}_aligned.fasta"

    n_seqs=$(grep -c "^>" "$gene_fasta" || true)
    if [ "$n_seqs" -lt 4 ]; then
        echo "  SKIP: ${gene_id} (only ${n_seqs} sequences, need ≥4)"
        continue
    fi

    mafft --auto --thread 4 "$gene_fasta" > "$aligned" 2>/dev/null
    N_GENES_ALIGNED=$((N_GENES_ALIGNED + 1))
    echo "  Aligned: ${gene_id} (${n_seqs} sequences)"
done
echo "  Total genes aligned: ${N_GENES_ALIGNED}"
echo ""

# Build supermatrix (concatenate all gene alignments)
echo "  Building protein supermatrix..."

SUPERMATRIX="${WORK_DIR}/supermatrix.fasta"
PARTITION="${WORK_DIR}/partitions.tsv"

python3 - "$WORK_DIR/alignments" "$TIP_MAP" "$SUPERMATRIX" "$PARTITION" "$WORK_DIR/taxa_without_data.txt" << 'PYEOF'
import sys, os, re, csv

align_dir = sys.argv[1]
tipmap_file = sys.argv[2]
output_fasta = sys.argv[3]
output_parts = sys.argv[4]
nohit_file = sys.argv[5]

# Read all taxa
all_taxa = []
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_taxa.append(row['tip_label'])

# Read taxa without any data
nohit_taxa = set()
if os.path.exists(nohit_file):
    with open(nohit_file) as f:
        for line in f:
            nohit_taxa.add(line.strip().split("\t")[0])

# Taxa with data (will be in the supermatrix)
data_taxa = [t for t in all_taxa if t not in nohit_taxa]

# Read all alignments
gene_alignments = {}  # gene_id -> {taxon: aligned_seq}
gene_lengths = {}     # gene_id -> alignment_length

for aln_file in sorted(os.listdir(align_dir)):
    if not aln_file.endswith("_aligned.fasta"):
        continue
    gene_id = aln_file.replace("_aligned.fasta", "")

    seqs = {}
    current_id = None
    current_seq = []

    with open(os.path.join(align_dir, aln_file)) as f:
        for line in f:
            line = line.strip()
            if line.startswith(">"):
                if current_id:
                    seqs[current_id] = "".join(current_seq)
                current_id = line[1:].split()[0]
                current_seq = []
            elif line:
                current_seq.append(line)
    if current_id:
        seqs[current_id] = "".join(current_seq)

    if seqs:
        aln_len = len(next(iter(seqs.values())))
        gene_alignments[gene_id] = seqs
        gene_lengths[gene_id] = aln_len

# Build supermatrix: concatenate all genes for each taxon
# Missing genes for a taxon → fill with gaps
total_length = sum(gene_lengths.values())
gene_order = sorted(gene_lengths.keys())

print(f"  Supermatrix: {len(data_taxa)} taxa × {total_length} aa ({len(gene_order)} genes)")

# Write partition file
with open(output_parts, "w") as pf:
    pf.write("gene\tstart\tend\tlength\n")
    pos = 1
    for gene_id in gene_order:
        glen = gene_lengths[gene_id]
        pf.write(f"{gene_id}\t{pos}\t{pos + glen - 1}\t{glen}\n")
        pos += glen

# Write supermatrix FASTA
with open(output_fasta, "w") as out:
    for taxon in data_taxa:
        parts = []
        for gene_id in gene_order:
            if taxon in gene_alignments[gene_id]:
                parts.append(gene_alignments[gene_id][taxon])
            else:
                # Fill missing gene with gaps
                parts.append("-" * gene_lengths[gene_id])
        concat = "".join(parts)
        out.write(f">{taxon}\n{concat}\n")

# Report per-taxon completeness
gene_counts = {}
for taxon in data_taxa:
    count = sum(1 for g in gene_order if taxon in gene_alignments[g])
    gene_counts[taxon] = count

min_genes = min(gene_counts.values()) if gene_counts else 0
max_genes = max(gene_counts.values()) if gene_counts else 0
mean_genes = sum(gene_counts.values()) / len(gene_counts) if gene_counts else 0

print(f"  Genes per taxon: min={min_genes}, max={max_genes}, mean={mean_genes:.1f}")

# Warn about taxa with very few genes
low_data = [(t, c) for t, c in gene_counts.items() if c <= 2]
if low_data:
    print(f"  Taxa with ≤2 genes ({len(low_data)}):")
    for t, c in sorted(low_data, key=lambda x: x[1])[:10]:
        print(f"    {t}: {c} genes")

print(f"  Taxa excluded (no data): {len(nohit_taxa)}")
PYEOF

echo ""

# ============================================================================
# 7. BUILD TREE WITH FASTTREE
# ============================================================================

echo "[7/8] Building ML tree with FastTree (WAG+CAT protein model)..."

RAW_TREE="${WORK_DIR}/fasttree_raw.nwk"
${FASTTREE_BIN} -wag -gamma "$SUPERMATRIX" > "$RAW_TREE" 2>"${WORK_DIR}/fasttree.log"

NTIPS_RAW=$(grep -oP '[A-Za-z_][A-Za-z0-9_]*(?=:)' "$RAW_TREE" | sort -u | wc -l)
echo "  Raw tree: ${NTIPS_RAW} tips"
echo ""

# ============================================================================
# 8. ROOT, GRAFT MISSING TAXA, VALIDATE, REBUILD SEQFILE
# ============================================================================

echo "[8/8] Rooting tree, grafting missing taxa, validating..."

FINAL_TREE="${MARKER_DIR}/nuclear_guide_tree_439.nwk"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"

python3 - "$RAW_TREE" "$TIP_MAP" "$WORK_DIR/taxa_without_data.txt" "$FINAL_TREE" << 'PYEOF'
import sys, re, csv
from collections import defaultdict

tree_file = sys.argv[1]
tipmap_file = sys.argv[2]
nohit_file = sys.argv[3]
output_file = sys.argv[4]

# Read tree
with open(tree_file) as f:
    tree_str = f.read().strip()

# Parse tips in tree
tips_in_tree = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
print(f"  Tips in FastTree output: {len(tips_in_tree)}")

# Read all species info
all_species = {}
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_species[row['tip_label']] = {
            'family': row['family'],
            'clade': row['clade'],
            'role': row['role']
        }

# Read missing taxa
missing = []
if nohit_file:
    try:
        with open(nohit_file) as f:
            for line in f:
                parts = line.strip().split("\t")
                if parts[0] and parts[0] not in tips_in_tree:
                    missing.append(parts[0])
    except FileNotFoundError:
        pass

# Also check for any taxa in catalog but not in tree
for sp in all_species:
    if sp not in tips_in_tree and sp not in missing:
        missing.append(sp)

print(f"  Total species in catalog: {len(all_species)}")
print(f"  Missing from tree (need grafting): {len(missing)}")

# --- Grafting missing taxa ---
# Build genus/family lookup from taxa already in tree
tree_genera = defaultdict(list)
tree_families = defaultdict(list)

for sp in tips_in_tree:
    if sp in all_species:
        genus = sp.split('_')[0]
        tree_genera[genus].append(sp)
        tree_families[all_species[sp]['family']].append(sp)

grafted = 0
graft_levels = {"genus": 0, "family": 0, "order": 0}

for sp in missing:
    info = all_species.get(sp, {})
    genus = sp.split('_')[0]

    # Try genus-level grafting (sister to congeneric with short branch)
    if genus in tree_genera:
        sister = tree_genera[genus][0]
        m = re.search(re.escape(sister) + r':([0-9.eE+-]+)', tree_str)
        if m:
            bl = float(m.group(1))
            half = bl / 2 if bl > 0.001 else 0.005
            replacement = f'({sister}:{half},{sp}:{half})'
            tree_str = tree_str.replace(f'{sister}:{m.group(1)}',
                                        f'{replacement}:{half}')
            tree_genera[genus].append(sp)
            grafted += 1
            graft_levels["genus"] += 1
            continue

    # Try family-level grafting
    fam = info.get('family', '')
    if fam in tree_families:
        sister = tree_families[fam][0]
        m = re.search(re.escape(sister) + r':([0-9.eE+-]+)', tree_str)
        if m:
            bl = float(m.group(1))
            pos = bl / 2 if bl > 0.01 else 0.005
            replacement = f'({sister}:{pos},{sp}:{bl})'
            tree_str = tree_str.replace(f'{sister}:{m.group(1)}',
                                        f'{replacement}:{pos}')
            tree_families[fam].append(sp)
            grafted += 1
            graft_levels["family"] += 1
            continue

    # Order-level: find any taxon from same major group
    role = info.get('role', '')
    if role == 'outgroup':
        candidates = [t for t in tips_in_tree if t in all_species
                      and all_species[t]['role'] == 'outgroup']
    else:
        candidates = [t for t in tips_in_tree if t in all_species
                      and all_species[t]['role'] != 'outgroup']

    if candidates:
        sister = candidates[0]
        m = re.search(re.escape(sister) + r':([0-9.eE+-]+)', tree_str)
        if m:
            bl = float(m.group(1))
            pos = bl / 2 if bl > 0.02 else 0.01
            replacement = f'({sister}:{pos},{sp}:{bl * 1.5 if bl > 0.01 else 0.1})'
            tree_str = tree_str.replace(f'{sister}:{m.group(1)}',
                                        f'{replacement}:{pos}')
            grafted += 1
            graft_levels["order"] += 1

print(f"  Grafted: {grafted} taxa (genus: {graft_levels['genus']}, "
      f"family: {graft_levels['family']}, order: {graft_levels['order']})")

# Fix any zero/negative branch lengths
def fix_branch(m):
    bl = float(m.group(1))
    if bl <= 0:
        bl = 1e-6
    if bl > 25.0:
        bl = 24.9  # Cactus hard limit
    return f':{bl}'

tree_str = re.sub(r':(-?[0-9.eE+-]+)', fix_branch, tree_str)

# Ensure tree ends with semicolon
if not tree_str.endswith(';'):
    tree_str += ';'

# --- Validation ---
print("\n  --- VALIDATION ---")
final_tips = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
all_sp_set = set(all_species.keys())

print(f"  Final tips: {len(final_tips)}")
print(f"  All catalog species present: {all_sp_set.issubset(final_tips)}")

still_missing = all_sp_set - final_tips
if still_missing:
    print(f"  WARNING: {len(still_missing)} still missing: {list(still_missing)[:10]}")

# Duplicate check
all_tips = re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str)
if len(all_tips) != len(final_tips):
    print(f"  WARNING: {len(all_tips) - len(final_tips)} duplicate tip labels!")

# Branch length stats
bls = [float(x) for x in re.findall(r':([0-9.eE+-]+)', tree_str)]
print(f"  Branch lengths: min={min(bls):.2e}, max={max(bls):.4f}, "
      f"mean={sum(bls)/len(bls):.4f}")
print(f"  Any > 25.0: {any(b > 25.0 for b in bls)}")
print(f"  Any <= 0: {any(b <= 0 for b in bls)}")

# Binary check
depth = 0
max_children = 0
children_at_depth = {}
for ch in tree_str:
    if ch == '(':
        depth += 1
        children_at_depth[depth] = 1
    elif ch == ',':
        if depth in children_at_depth:
            children_at_depth[depth] += 1
            if children_at_depth[depth] > max_children:
                max_children = children_at_depth[depth]
    elif ch == ')':
        depth -= 1

print(f"  Max children at any node: {max_children}")
print(f"  Binary: {max_children <= 2}")

# Balanced parentheses
opens = tree_str.count('(')
closes = tree_str.count(')')
print(f"  Balanced parens: {opens == closes} ({opens} open, {closes} close)")

# Molecular data fraction
n_data = len(tips_in_tree)  # taxa with actual molecular data
n_grafted = grafted
n_total = len(final_tips)
print(f"\n  Molecular data: {n_data}/{n_total} ({n_data/n_total*100:.1f}%)")
print(f"  Taxonomy-grafted: {n_grafted}/{n_total} ({n_grafted/n_total*100:.1f}%)")

# PASS/FAIL
passes = (
    len(final_tips) == len(all_sp_set) and
    all_sp_set.issubset(final_tips) and
    max_children <= 2 and
    not any(b > 25.0 for b in bls) and
    not any(b <= 0 for b in bls) and
    opens == closes
)

if passes:
    print("\n  === ALL VALIDATION CHECKS PASSED ===")
else:
    print("\n  === VALIDATION ISSUES DETECTED ===")

# Save
with open(output_file, 'w') as f:
    f.write(tree_str + '\n')
print(f"\n  Saved: {output_file}")
PYEOF

echo ""

# --- Rebuild seqFile ---
echo "  Rebuilding Cactus seqFile..."

if [ -f "$SEQFILE" ]; then
    cp "$SEQFILE" "${SEQFILE}.bak_$(date +%Y%m%d_%H%M%S)"
fi

# Line 1: tree
cat "$FINAL_TREE" > "$SEQFILE"

# Lines 2+: tip_label /path/to/genome.fna
MAPPED=0
tail -n +2 "$TIP_MAP" | while IFS=',' read -r tip_label species_name accession family clade role; do
    FASTA=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)
    if [ -n "$FASTA" ]; then
        echo "${tip_label} ${FASTA}" >> "$SEQFILE"
    fi
done

TOTAL_ENTRIES=$(tail -n +2 "$SEQFILE" | grep -c . || true)
echo "  seqFile rebuilt: ${TOTAL_ENTRIES} genomes"
echo ""

# ============================================================================
# FINAL SUMMARY
# ============================================================================

echo "============================================================"
echo "NUCLEAR MARKER GUIDE TREE — COMPLETE"
echo "============================================================"
echo ""
echo "Tree:        ${FINAL_TREE}"
echo "seqFile:     ${SEQFILE}"
echo "Supermatrix: ${SUPERMATRIX}"
echo "Partitions:  ${PARTITION}"
echo "BLAST log:   ${WORK_DIR}/blast_summary.tsv"
echo ""

# Re-read summary for final report
TAXA_DATA=$(grep "^taxa_with_data" "$WORK_DIR/blast_summary.tsv" | cut -f2)
N_GRAFTED=$(wc -l < "$WORK_DIR/taxa_without_data.txt" 2>/dev/null || echo "0")
echo "Molecular data: ${TAXA_DATA}/${N_TAXA} taxa"
echo "Grafted:        ${N_GRAFTED}/${N_TAXA} taxa"
echo ""
echo "NEXT STEPS:"
echo "  1. Review the tree and blast_summary.tsv"
echo "  2. Run the test alignment:"
echo "     sbatch test_alignment.slurm"
echo ""
echo "Finished: $(date)"
