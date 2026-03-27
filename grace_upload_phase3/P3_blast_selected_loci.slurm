#!/bin/bash
# ============================================================================
# P3_blast_selected_loci.slurm — tBLASTn 1,286 BUSCO loci × 478 genomes
# ============================================================================
#
# Searches all selected BUSCO proteins against all 478 genome assemblies
# and builds per-gene FASTA files for phylogenomics (P4-P7).
#
# Steps:
#   1. Build per-genome BLAST databases (skips existing)
#   2. tBLASTn 1,286 proteins × all genomes (skips completed genomes)
#   3. Parse BLAST results → per-gene FASTA files (all taxa, overwrite)
#
# Idempotent: safe to resubmit after failure — completed steps are skipped.
# On failure at step 3 (per-gene FASTA building), steps 1-2 are skipped
# entirely since all DBs and TSVs already exist.
#
# Prerequisites:
#   - phylogenomics/selected_proteins.fasta (1,286 query proteins)
#   - phylogenomics/busco_tribolium_map.tsv
#   - All 478 genomes in $SCRATCH/scarab/genomes/
#   - data/tree_tip_mapping.csv
#
# Output:
#   - phylogenomics/blast_per_genome/{ACCESSION}.tsv (one per genome)
#   - phylogenomics/per_gene_seqs/{GENE}.fasta (one per locus, 478 taxa)
#
# Last run: job 18159931 (2026-03-26) — step 3 fix for missing export
# ============================================================================

#SBATCH --job-name=scarab_P3
#SBATCH --partition=long
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --output=scarab_P3_%j.log
#SBATCH --error=scarab_P3_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
GENOME_DIR="${PROJECT_DIR}/genomes"
SELECTED="${PHYLO_DIR}/selected_proteins.fasta"
TIP_MAP="${PROJECT_DIR}/data/tree_tip_mapping.csv"
BLAST_DIR="${PHYLO_DIR}/blast_per_genome"
SEQ_DIR="${PHYLO_DIR}/per_gene_seqs"
DB_DIR="${PHYLO_DIR}/blast_dbs"
NCPUS=${SLURM_CPUS_PER_TASK:-48}
MAX_PARALLEL=12

echo "============================================================"
echo "SCARAB P.3 — tBLASTn 1,286 Loci x 478 Genomes"
echo "Job: ${SLURM_JOB_ID}, Started: $(date)"
echo "Node: $(hostname), CPUs: ${NCPUS}"
echo "============================================================"

module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

mkdir -p "${BLAST_DIR}" "${SEQ_DIR}" "${DB_DIR}"

# Step 1: Build BLAST databases for all genomes
echo "[1] Building per-genome BLAST databases..."
N_BUILT=0
N_SKIP=0
for FNA in $(find "${GENOME_DIR}" -name "*.fna"); do
    ACC=$(echo "$FNA" | grep -oP 'GC[AF]_[0-9]+\.[0-9]+' | head -1)
    DBPATH="${DB_DIR}/${ACC}"
    if [ -f "${DBPATH}.nsq" ] || [ -f "${DBPATH}.ndb" ]; then
        N_SKIP=$((N_SKIP + 1))
        continue
    fi
    makeblastdb -in "$FNA" -dbtype nucl -out "$DBPATH" -title "$ACC" >/dev/null 2>&1 || echo "  WARN: failed $ACC"
    N_BUILT=$((N_BUILT + 1))
done
N_TOTAL=$((N_BUILT + N_SKIP))
echo "  Databases: ${N_TOTAL} (${N_BUILT} new, ${N_SKIP} existing)"

# Step 2: BLAST all genomes with the 1,286 selected proteins
echo "[2] Running tBLASTn per genome (${MAX_PARALLEL} parallel)..."

DB_LIST="${PHYLO_DIR}/db_list.txt"
> "${DB_LIST}"
for DBFILE in "${DB_DIR}"/*.nsq "${DB_DIR}"/*.ndb; do
    [ -f "$DBFILE" ] || continue
    ACC=$(basename "$DBFILE" | sed 's/\.\(nsq\|ndb\)$//')
    OUTFILE="${BLAST_DIR}/${ACC}.tsv"
    if [ -f "$OUTFILE" ] && [ -s "$OUTFILE" ]; then
        continue
    fi
    echo "${ACC}" >> "${DB_LIST}"
done
sort -u "${DB_LIST}" -o "${DB_LIST}"
N_TODO=$(wc -l < "${DB_LIST}")
echo "  Genomes to BLAST: ${N_TODO}"

WRAPPER="${PHYLO_DIR}/blast_one.sh"
cat > "${WRAPPER}" << 'INNER'
#!/bin/bash
ACC="$1"
DB_DIR="$2"
BLAST_DIR="$3"
SELECTED="$4"
DBPREFIX="${DB_DIR}/${ACC}"
OUTFILE="${BLAST_DIR}/${ACC}.tsv"
tblastn -query "${SELECTED}" \
        -db "${DBPREFIX}" \
        -out "${OUTFILE}" \
        -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore sseq" \
        -evalue 1e-5 \
        -max_target_seqs 1 \
        -num_threads 1 \
        2>/dev/null
echo "  Done: ${ACC} ($(wc -l < "${OUTFILE}") hits)" >&2
INNER
chmod +x "${WRAPPER}"

cat "${DB_LIST}" | xargs -P ${MAX_PARALLEL} -I{} bash "${WRAPPER}" {} "${DB_DIR}" "${BLAST_DIR}" "${SELECTED}"

N_DONE=$(ls "${BLAST_DIR}"/*.tsv 2>/dev/null | wc -l)
echo "  BLAST results: ${N_DONE} genomes"

# Step 3: Parse BLAST results into per-gene FASTA files
# NOTE: export required so Python heredoc can read these as os.environ vars
echo "[3] Building per-gene FASTA files..."
export PHYLO_DIR PROJECT_DIR
python3 << 'PYEOF'
import os, glob

phylo_dir = os.environ["PHYLO_DIR"]
project_dir = os.environ["PROJECT_DIR"]
blast_dir = os.path.join(phylo_dir, "blast_per_genome")
seq_dir = os.path.join(phylo_dir, "per_gene_seqs")

# Load tip mapping: accession -> tip_label
acc_to_tip = {}
with open(os.path.join(project_dir, "data", "tree_tip_mapping.csv")) as f:
    for line in f:
        parts = line.strip().split(",")
        if len(parts) >= 3:
            acc_to_tip[parts[2]] = parts[0]
print("  Tip mappings: {}".format(len(acc_to_tip)))

# gene_seqs: {gene_id: {tip_label: protein_seq}}
gene_seqs = {}
n_files = 0

for blast_file in sorted(glob.glob(os.path.join(blast_dir, "*.tsv"))):
    acc = os.path.basename(blast_file).replace(".tsv", "")
    tip = acc_to_tip.get(acc, acc)
    n_files += 1

    best = {}
    try:
        with open(blast_file) as f:
            for line in f:
                cols = line.strip().split("\t")
                if len(cols) < 13:
                    continue
                qid = cols[0]
                pident = float(cols[2])
                alen = int(cols[3])
                bitscore = float(cols[11])
                sseq = cols[12].replace("-", "").replace("*", "")

                if alen < 100 or pident < 30.0:
                    continue

                gene = qid.rsplit("_", 1)[0] if "_" in qid and qid.rsplit("_", 1)[1].isdigit() else qid

                if gene not in best or bitscore > best[gene][0]:
                    best[gene] = (bitscore, sseq)
    except Exception:
        continue

    for gene, (bs, seq) in best.items():
        if gene not in gene_seqs:
            gene_seqs[gene] = {}
        gene_seqs[gene][tip] = seq

os.makedirs(seq_dir, exist_ok=True)
n_good = 0
for gene in sorted(gene_seqs):
    outpath = os.path.join(seq_dir, "{}.fasta".format(gene))
    taxa = gene_seqs[gene]
    with open(outpath, "w") as f:
        for tip in sorted(taxa):
            f.write(">{}\n{}\n".format(tip, taxa[tip]))
    if len(taxa) >= 50:
        n_good += 1

print("  BLAST files parsed: {}".format(n_files))
print("  Total genes: {}".format(len(gene_seqs)))
print("  Genes with >=50 taxa: {}".format(n_good))
taxa_counts = [len(v) for v in gene_seqs.values()]
if taxa_counts:
    print("  Taxa per gene: min={} max={} mean={:.0f}".format(
        min(taxa_counts), max(taxa_counts), sum(taxa_counts)/len(taxa_counts)))
PYEOF

echo ""
echo "============================================================"
echo "P.3 COMPLETE — $(date)"
echo "  Per-gene FASTAs: ${SEQ_DIR}/"
echo "  NEXT: sbatch P4_P5_align_and_gene_trees.slurm"
echo "============================================================"
