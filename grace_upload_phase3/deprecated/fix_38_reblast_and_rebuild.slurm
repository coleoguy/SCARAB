#!/bin/bash
#SBATCH --job-name=scarab_nuc_fix38
#SBATCH --partition=medium
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --output=%x_%j.log
#SBATCH --error=%x_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

# Fix for 38 genomes that got zero BLAST hits due to silent OOM kills
# when the original script ran 48 parallel tBLASTn jobs on 64GB.
# This script re-BLASTs only the 38 affected genomes (12 parallel),
# then rebuilds the full downstream pipeline using ALL 439 results.

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
GENOME_DIR="${PROJECT_DIR}/genomes"
DATA_DIR="${PROJECT_DIR}/data"
MARKER_DIR="${PROJECT_DIR}/nuclear_markers"
MARKER_FASTA="${MARKER_DIR}/marker_proteins.fasta"
TIP_MAP="${DATA_DIR}/tree_tip_mapping.csv"
WORK_DIR="${MARKER_DIR}/tree_build_18109816"

MIN_TAXA_WITH_DATA=395
MIN_HIT_LENGTH_AA=100
MIN_PIDENT=30.0
BATCH_SIZE=12

echo "============================================================"
echo "SCARAB — Fix 38 Failed BLAST Genomes & Rebuild Tree"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "Resources: 48 cores, 128 GB (12 parallel BLAST jobs)"
echo "============================================================"
echo ""

# ---- The 38 genomes with 0-byte BLAST files (OOM-killed) ----
declare -A REDO_GENOMES
REDO_GENOMES=(
    [Acanthoscelides_obtectus]="GCA_963669975.1"
    [Agriotes_ferrugineipennis]="GCA_044115295.2"
    [Agriotes_mancus]="GCA_041228495.2"
    [Agriotes_sputator]="GCA_044115325.2"
    [Agrypnus_murinus]="GCA_929113105.1"
    [Amphimallon_solstitiale]="GCA_963170755.1"
    [Anaglyptus_mysticus]="GCA_978041785.1"
    [Aquatica_leii]="GCA_035610365.1"
    [Arhopalus_unicolor]="GCA_045514315.1"
    [Chrysolina_herbacea]="GCA_979300175.1"
    [Crudosilis_ruficollis]="GCA_978018155.1"
    [Curculio_caryae]="GCA_051047995.1"
    [Denticollis_linearis]="GCA_964205235.1"
    [Diabrotica_balteata]="GCA_918026665.1"
    [Diabrotica_virgifera_virgifera]="GCF_917563875.1"
    [Distenia_gracilis]="GCA_055671715.1"
    [Lasiorhynchites_cavifrons]="GCA_976916715.1"
    [Lesteva_pubescens]="GCA_965644545.1"
    [Lesteva_punctata]="GCA_975739945.1"
    [Limonius_poneli]="GCA_965119595.1"
    [Liopterus_haemorrhoidalis]="GCA_963971575.1"
    [Longitarsus_dorsalis]="GCA_965178105.1"
    [Magdalis_cerasi]="GCA_965642045.1"
    [Monolepta_hieroglyphica]="GCA_045514875.1"
    [Nedyus_quadrimaculatus]="GCA_977969715.1"
    [Ocypus_olens]="GCA_910593695.2"
    [Ontholestes_murinus]="GCA_963969525.1"
    [Opilo_mollis]="GCA_964338635.1"
    [Oxystoma_pomonae]="GCA_963921995.1"
    [Pachyrhynchus_sulphureomaculatus]="GCA_019049505.1"
    [Phyllobius_argentatus]="GCA_965654255.1"
    [Platydracus_latebricola]="GCA_978021435.1"
    [Polydrusus_pterygomalis]="GCA_963969555.1"
    [Psylliodes_chrysocephalus]="GCA_927349885.1"
    [Rutpela_maculata]="GCA_936432065.2"
    [Sphaeroderma_testaceum]="GCA_971796245.1"
    [Stictoleptura_scutellata]="GCA_964212005.1"
    [Tillus_elongatus]="GCA_964006375.1"
)

echo "[1/7] Re-BLASTing 38 failed genomes..."
echo "  (${BATCH_SIZE} parallel jobs to avoid OOM)"

module purge 2>/dev/null || true
module load GCC/12.2.0
module load OpenMPI/4.1.4
module load BLAST+/2.14.0
echo "  tblastn: $(which tblastn)"
echo ""

batch_count=0
total_done=0
total_redo=${#REDO_GENOMES[@]}

for tip_label in "${!REDO_GENOMES[@]}"; do
    accession="${REDO_GENOMES[$tip_label]}"
    blast_out="${WORK_DIR}/blast_hits/${tip_label}.blast"

    # Find the genome FASTA
    fasta=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)
    if [ -z "$fasta" ]; then
        echo "  SKIP ${tip_label} — no FASTA in ${accession}"
        echo "SKIP ${tip_label} no_fasta" > "${blast_out}.status"
        total_done=$((total_done + 1))
        continue
    fi

    # Remove old empty file
    rm -f "$blast_out" "${blast_out}.status"

    (
        tblastn -query "$MARKER_FASTA" \
                -subject "$fasta" \
                -outfmt "6 qseqid sseqid sstart send evalue bitscore pident length sseq" \
                -evalue 1e-5 \
                -max_target_seqs 1 \
                -max_hsps 1 \
                -seg yes \
                -num_threads 1 \
                > "$blast_out" 2>/dev/null

        local_hits=0
        if [ -s "$blast_out" ]; then
            local_hits=$(wc -l < "$blast_out")
        fi
        echo "OK ${tip_label} hits=${local_hits}" > "${blast_out}.status"
        echo "  ${tip_label}: ${local_hits} hits"
    ) &

    batch_count=$((batch_count + 1))
    total_done=$((total_done + 1))

    if [ $batch_count -ge $BATCH_SIZE ]; then
        wait
        batch_count=0
        echo "  Processed ${total_done}/${total_redo}..."
    fi
done
wait
echo "  Re-BLAST complete: ${total_redo} genomes"
echo ""

# Verify the fix worked
echo "  Verifying re-BLASTed files..."
n_fixed=0
n_still_empty=0
for tip_label in "${!REDO_GENOMES[@]}"; do
    blast_out="${WORK_DIR}/blast_hits/${tip_label}.blast"
    if [ -s "$blast_out" ]; then
        n_fixed=$((n_fixed + 1))
    else
        n_still_empty=$((n_still_empty + 1))
        echo "  WARNING: still empty: ${tip_label}"
    fi
done
echo "  Fixed: ${n_fixed}/${total_redo}"
if [ $n_still_empty -gt 0 ]; then
    echo "  Still empty: ${n_still_empty} (check these genomes manually)"
fi
echo ""

# ---- STAGE 2: Re-parse ALL BLAST results ----
echo "[2/7] Parsing ALL BLAST results into per-gene FASTAs..."
N_TAXA=$(tail -n +2 "$TIP_MAP" | wc -l)

rm -f "$WORK_DIR"/per_gene/*.fasta 2>/dev/null || true

python3 - "$WORK_DIR" "$TIP_MAP" "$MIN_HIT_LENGTH_AA" "$MIN_PIDENT" << 'PYEOF'
import sys, os, re, csv
from collections import defaultdict
work_dir = sys.argv[1]
tipmap_file = sys.argv[2]
min_length = int(sys.argv[3])
min_pident = float(sys.argv[4])
blast_dir = os.path.join(work_dir, "blast_hits")
gene_dir = os.path.join(work_dir, "per_gene")
all_taxa = {}
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_taxa[row['tip_label']] = row
gene_seqs = defaultdict(dict)
per_taxon_hits = defaultdict(int)
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
            gene_id = parts[0]
            pident = float(parts[6])
            aln_len = int(parts[7])
            sseq = parts[8]
            if aln_len < min_length:
                continue
            if pident < min_pident:
                continue
            seq_clean = re.sub(r'[\-\*\s]', '', sseq)
            if len(seq_clean) >= min_length:
                gene_seqs[gene_id][tip_label] = seq_clean
                per_taxon_hits[tip_label] += 1
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
summary_path = os.path.join(work_dir, "blast_summary.tsv")
with open(summary_path, "w") as out:
    out.write(f"taxa_with_data\t{taxa_with_any_data}\n")
    out.write(f"total_taxa\t{total_taxa}\n")
    out.write(f"n_genes\t{len(gene_seqs)}\n")
    for gene_id in sorted(gene_seqs.keys()):
        out.write(f"gene_{gene_id}\t{len(gene_seqs[gene_id])}\n")
nohit_path = os.path.join(work_dir, "taxa_without_data.txt")
with open(nohit_path, "w") as out:
    for t in sorted(taxa_without_data):
        info = all_taxa[t]
        out.write(f"{t}\t{info.get('family','')}\t{info.get('clade','')}\t{info.get('role','')}\n")
PYEOF
echo ""

# ---- STAGE 3: Quality gate ----
echo "[3/7] Quality gate..."
TAXA_WITH_DATA=$(grep "^taxa_with_data" "$WORK_DIR/blast_summary.tsv" | cut -f2)
TOTAL_TAXA_CHECK=$(grep "^total_taxa" "$WORK_DIR/blast_summary.tsv" | cut -f2)
echo "  Taxa with data: ${TAXA_WITH_DATA}/${TOTAL_TAXA_CHECK} (need >=${MIN_TAXA_WITH_DATA})"
if [ "$TAXA_WITH_DATA" -lt "$MIN_TAXA_WITH_DATA" ]; then
    echo "  *** QUALITY GATE FAILED ***"
    echo "  Output preserved in: $WORK_DIR"
    exit 1
fi
echo "  QUALITY GATE PASSED"
echo ""

# ---- STAGE 4: MAFFT per-gene alignment ----
echo "[4/7] Aligning genes..."
module purge 2>/dev/null || true
module load GCC/12.3.0
module load MAFFT/7.520-with-extensions
module load FastTree/2.1.11
FASTTREE_BIN=$(which FastTree 2>/dev/null || which fasttree 2>/dev/null)
echo "  mafft: $(which mafft)"
echo "  FastTree: ${FASTTREE_BIN}"

rm -f "$WORK_DIR"/alignments/*.fasta 2>/dev/null || true

N_GENES_ALIGNED=0
for gene_fasta in "$WORK_DIR"/per_gene/*.fasta; do
    [ -f "$gene_fasta" ] || continue
    gene_id=$(basename "$gene_fasta" .fasta)
    aligned="${WORK_DIR}/alignments/${gene_id}_aligned.fasta"
    n_seqs=$(grep -c "^>" "$gene_fasta" || true)
    if [ "$n_seqs" -lt 4 ]; then
        echo "  SKIP: ${gene_id} (only ${n_seqs} sequences, need >=4)"
        continue
    fi
    mafft --auto --thread 4 "$gene_fasta" > "$aligned" 2>/dev/null
    N_GENES_ALIGNED=$((N_GENES_ALIGNED + 1))
    echo "  Aligned: ${gene_id} (${n_seqs} seqs)"
done
echo "  Total aligned: ${N_GENES_ALIGNED}"
echo ""

# ---- STAGE 5: Supermatrix ----
echo "  Building supermatrix..."
SUPERMATRIX="${WORK_DIR}/supermatrix.fasta"
PARTITION="${WORK_DIR}/partitions.tsv"

python3 - "$WORK_DIR/alignments" "$TIP_MAP" "$SUPERMATRIX" "$PARTITION" "$WORK_DIR/taxa_without_data.txt" << 'PYEOF'
import sys, os, re, csv
align_dir = sys.argv[1]
tipmap_file = sys.argv[2]
output_fasta = sys.argv[3]
output_parts = sys.argv[4]
nohit_file = sys.argv[5]
all_taxa = []
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_taxa.append(row['tip_label'])
nohit_taxa = set()
if os.path.exists(nohit_file):
    with open(nohit_file) as f:
        for line in f:
            nohit_taxa.add(line.strip().split("\t")[0])
data_taxa = [t for t in all_taxa if t not in nohit_taxa]
gene_alignments = {}
gene_lengths = {}
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
total_length = sum(gene_lengths.values())
gene_order = sorted(gene_lengths.keys())
print(f"  Supermatrix: {len(data_taxa)} taxa x {total_length} aa ({len(gene_order)} genes)")
with open(output_parts, "w") as pf:
    pf.write("gene\tstart\tend\tlength\n")
    pos = 1
    for gene_id in gene_order:
        glen = gene_lengths[gene_id]
        pf.write(f"{gene_id}\t{pos}\t{pos + glen - 1}\t{glen}\n")
        pos += glen
with open(output_fasta, "w") as out:
    for taxon in data_taxa:
        parts = []
        for gene_id in gene_order:
            if taxon in gene_alignments[gene_id]:
                parts.append(gene_alignments[gene_id][taxon])
            else:
                parts.append("-" * gene_lengths[gene_id])
        concat = "".join(parts)
        out.write(f">{taxon}\n{concat}\n")
gene_counts = {}
for taxon in data_taxa:
    count = sum(1 for g in gene_order if taxon in gene_alignments[g])
    gene_counts[taxon] = count
min_genes = min(gene_counts.values()) if gene_counts else 0
max_genes = max(gene_counts.values()) if gene_counts else 0
mean_genes = sum(gene_counts.values()) / len(gene_counts) if gene_counts else 0
print(f"  Genes per taxon: min={min_genes}, max={max_genes}, mean={mean_genes:.1f}")
print(f"  Taxa excluded (no data): {len(nohit_taxa)}")
PYEOF
echo ""

# ---- STAGE 6: FastTree ----
echo "[5/7] Building ML tree (WAG+CAT)..."
RAW_TREE="${WORK_DIR}/fasttree_raw.nwk"
${FASTTREE_BIN} -wag -gamma "$SUPERMATRIX" > "$RAW_TREE" 2>"${WORK_DIR}/fasttree.log"
NTIPS_RAW=$(grep -oP '[A-Za-z_][A-Za-z0-9_]*(?=:)' "$RAW_TREE" | sort -u | wc -l)
echo "  Raw tree: ${NTIPS_RAW} tips"
echo ""

# ---- STAGE 7: Root, graft, validate, rebuild seqFile ----
echo "[6/7] Root, graft, validate..."
FINAL_TREE="${MARKER_DIR}/nuclear_guide_tree_439.nwk"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"

python3 - "$RAW_TREE" "$TIP_MAP" "$WORK_DIR/taxa_without_data.txt" "$FINAL_TREE" << 'PYEOF'
import sys, re, csv
from collections import defaultdict
tree_file = sys.argv[1]
tipmap_file = sys.argv[2]
nohit_file = sys.argv[3]
output_file = sys.argv[4]
with open(tree_file) as f:
    tree_str = f.read().strip()
tips_in_tree = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
print(f"  Tips in FastTree output: {len(tips_in_tree)}")
all_species = {}
with open(tipmap_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        all_species[row['tip_label']] = {
            'family': row['family'],
            'clade': row['clade'],
            'role': row['role']
        }
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
for sp in all_species:
    if sp not in tips_in_tree and sp not in missing:
        missing.append(sp)
print(f"  Total species: {len(all_species)}")
print(f"  Need grafting: {len(missing)}")
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
print(f"  Grafted: {grafted} (genus={graft_levels['genus']}, family={graft_levels['family']}, order={graft_levels['order']})")

def fix_branch(m):
    bl = float(m.group(1))
    if bl <= 0:
        bl = 1e-6
    if bl > 25.0:
        bl = 24.9
    return f':{bl}'
tree_str = re.sub(r':(-?[0-9.eE+-]+)', fix_branch, tree_str)
if not tree_str.endswith(';'):
    tree_str += ';'

print("\n  --- VALIDATION ---")
final_tips = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
all_sp_set = set(all_species.keys())
print(f"  Final tips: {len(final_tips)}")
print(f"  All species present: {all_sp_set.issubset(final_tips)}")
still_missing = all_sp_set - final_tips
if still_missing:
    print(f"  WARNING: {len(still_missing)} still missing: {list(still_missing)[:10]}")
bls = [float(x) for x in re.findall(r':([0-9.eE+-]+)', tree_str)]
print(f"  Branch lengths: min={min(bls):.2e}, max={max(bls):.4f}, mean={sum(bls)/len(bls):.4f}")
print(f"  Any >25: {any(b > 25.0 for b in bls)}")
print(f"  Any <=0: {any(b <= 0 for b in bls)}")
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
print(f"  Binary: {max_children <= 2} (max children: {max_children})")
opens = tree_str.count('(')
closes = tree_str.count(')')
print(f"  Balanced parens: {opens == closes}")

n_data = len(tips_in_tree)
n_total = len(final_tips)
print(f"\n  Molecular data: {n_data}/{n_total} ({n_data/n_total*100:.1f}%)")
print(f"  Grafted: {grafted}/{n_total} ({grafted/n_total*100:.1f}%)")

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
    print("\n  === ISSUES DETECTED ===")

with open(output_file, 'w') as f:
    f.write(tree_str + '\n')
print(f"  Saved: {output_file}")
PYEOF

echo ""
echo "[7/7] Rebuilding seqFile..."
if [ -f "$SEQFILE" ]; then
    cp "$SEQFILE" "${SEQFILE}.bak_$(date +%Y%m%d_%H%M%S)"
fi
cat "$FINAL_TREE" > "$SEQFILE"
tail -n +2 "$TIP_MAP" | while IFS=',' read -r tip_label species_name accession family clade role; do
    FASTA=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)
    if [ -n "$FASTA" ]; then
        echo "${tip_label} ${FASTA}" >> "$SEQFILE"
    fi
done
TOTAL_ENTRIES=$(tail -n +2 "$SEQFILE" | grep -c . || true)
echo "  seqFile: ${TOTAL_ENTRIES} genomes"
echo ""

echo "============================================================"
echo "DONE — $(date)"
echo "Tree: ${FINAL_TREE}"
echo "seqFile: ${SEQFILE}"
echo "============================================================"
