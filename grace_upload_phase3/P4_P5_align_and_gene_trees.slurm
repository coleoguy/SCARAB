#!/bin/bash
# ============================================================================
# P4_P5_align_and_gene_trees.slurm — Per-gene MAFFT alignments + IQ-TREE
# gene trees for ASTRAL input
# ============================================================================
#
# Purpose:
#   For each selected locus:
#   1. MAFFT alignment (auto strategy)
#   2. IQ-TREE gene tree (ModelFinder + 1000 UFBoot)
#
# Prerequisites:
#   P3 complete — per-gene FASTA files in $SCRATCH/scarab/phylogenomics/per_gene_seqs/
#
# Resources: 1 node, 48 cores, 128GB
# Estimated time: 12-24 hours (500 gene trees × ~2 min each)
#
# Usage:
#   sbatch P4_P5_align_and_gene_trees.slurm
# ============================================================================

#SBATCH --job-name=scarab_P45_trees
#SBATCH --partition=long
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --output=scarab_P45_trees_%j.log
#SBATCH --error=scarab_P45_trees_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
SEQ_DIR="${PHYLO_DIR}/per_gene_seqs"
ALN_DIR="${PHYLO_DIR}/per_gene_alignments"
TREE_DIR="${PHYLO_DIR}/per_gene_trees"

NCPUS=${SLURM_CPUS_PER_TASK:-48}
MAX_PARALLEL=12       # 12 concurrent IQ-TREE jobs × 4 threads each = 48 cores
THREADS_PER=4         # threads per IQ-TREE job
MIN_TAXA=50           # skip genes with fewer taxa than this

echo "============================================================"
echo "SCARAB P.4+P.5 — Per-Gene Alignments and Gene Trees"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${NCPUS}"
echo "============================================================"
echo ""

module load GCC/12.3.0 OpenMPI/4.1.5 MAFFT/7.520-with-extensions IQ-TREE/2.3.6

mkdir -p "${ALN_DIR}" "${TREE_DIR}"

# ============================================================================
# 1. IDENTIFY LOCI TO PROCESS
# ============================================================================

echo "[1] Scanning per-gene FASTA files..."

LOCI_FILE="${PHYLO_DIR}/loci_for_trees.txt"
> "${LOCI_FILE}"

for FASTA in "${SEQ_DIR}"/*.fasta; do
    [ -f "${FASTA}" ] || continue
    BUSCO_ID=$(basename "${FASTA}" .fasta)
    N_TAXA=$(grep -c "^>" "${FASTA}" 2>/dev/null || echo 0)
    if [ "${N_TAXA}" -ge "${MIN_TAXA}" ]; then
        echo "${BUSCO_ID}" >> "${LOCI_FILE}"
    fi
done

N_LOCI=$(wc -l < "${LOCI_FILE}")
echo "  Loci with ≥${MIN_TAXA} taxa: ${N_LOCI}"

# ============================================================================
# 2. PER-GENE ALIGNMENT + TREE
# ============================================================================

echo "[2] Running MAFFT + IQ-TREE for ${N_LOCI} loci..."

process_gene() {
    local BUSCO_ID="$1"
    local FASTA="${SEQ_DIR}/${BUSCO_ID}.fasta"
    local ALN="${ALN_DIR}/${BUSCO_ID}.aln"
    local TREE_PREFIX="${TREE_DIR}/${BUSCO_ID}"

    # Skip if tree already exists
    if [ -f "${TREE_PREFIX}.treefile" ]; then
        echo "  ${BUSCO_ID}: already done" >&2
        return 0
    fi

    # Step 1: MAFFT alignment
    mafft --auto --thread 1 "${FASTA}" > "${ALN}" 2>/dev/null

    if [ ! -s "${ALN}" ]; then
        echo "  ${BUSCO_ID}: MAFFT failed" >&2
        return 1
    fi

    # Check alignment has enough informative sites
    local N_TAXA=$(grep -c "^>" "${ALN}")
    if [ "${N_TAXA}" -lt "${MIN_TAXA}" ]; then
        echo "  ${BUSCO_ID}: only ${N_TAXA} taxa after alignment" >&2
        return 0
    fi

    # Step 2: IQ-TREE gene tree
    iqtree2 -s "${ALN}" \
             --prefix "${TREE_PREFIX}" \
             -m MFP \
             -bb 1000 \
             -nt "${THREADS_PER}" \
             --quiet \
             2>/dev/null

    if [ -f "${TREE_PREFIX}.treefile" ]; then
        echo "  ${BUSCO_ID}: done (${N_TAXA} taxa)" >&2
    else
        echo "  ${BUSCO_ID}: IQ-TREE failed" >&2
    fi
}

export -f process_gene
export SEQ_DIR ALN_DIR TREE_DIR MIN_TAXA THREADS_PER

# Run with controlled parallelism
cat "${LOCI_FILE}" | xargs -P ${MAX_PARALLEL} -I{} bash -c 'process_gene "$@"' _ {}

# ============================================================================
# 3. COLLECT GENE TREES INTO SINGLE FILE
# ============================================================================

echo ""
echo "[3] Collecting gene trees..."

GENE_TREES="${PHYLO_DIR}/all_gene_trees.nwk"
> "${GENE_TREES}"

N_TREES=0
for TREEFILE in "${TREE_DIR}"/*.treefile; do
    [ -f "${TREEFILE}" ] || continue
    cat "${TREEFILE}" >> "${GENE_TREES}"
    N_TREES=$((N_TREES + 1))
done

echo "  Collected ${N_TREES} gene trees → ${GENE_TREES}"

# ============================================================================
# 4. BUILD CONCATENATED SUPERMATRIX FOR PARTITIONED ANALYSIS (P.7)
# ============================================================================

echo ""
echo "[4] Building concatenated supermatrix..."

python3 - <<'PYEOF'
import os, glob

aln_dir = os.environ["ALN_DIR"]
phylo_dir = os.environ["PHYLO_DIR"]
loci_file = os.environ["LOCI_FILE"]

with open(loci_file) as f:
    loci = [l.strip() for l in f if l.strip()]

# Read all alignments
all_taxa = set()
gene_data = {}  # locus -> {taxon: seq}

for locus in loci:
    aln_path = os.path.join(aln_dir, f"{locus}.aln")
    if not os.path.exists(aln_path):
        continue

    seqs = {}
    current = None
    with open(aln_path) as f:
        for line in f:
            if line.startswith(">"):
                current = line[1:].strip().split()[0]
                seqs[current] = []
            elif current:
                seqs[current].append(line.strip())

    seqs = {k: "".join(v) for k, v in seqs.items()}
    if seqs:
        gene_data[locus] = seqs
        all_taxa.update(seqs.keys())

taxa = sorted(all_taxa)
print(f"  Total taxa across all loci: {len(taxa)}")
print(f"  Loci with alignments: {len(gene_data)}")

# Build supermatrix
partitions = []
pos = 1

supermatrix = {t: [] for t in taxa}

for locus in sorted(gene_data.keys()):
    seqs = gene_data[locus]
    aln_len = max(len(s) for s in seqs.values())

    for taxon in taxa:
        if taxon in seqs:
            seq = seqs[taxon]
            # Pad if shorter
            seq += "-" * (aln_len - len(seq))
        else:
            seq = "-" * aln_len
        supermatrix[taxon].append(seq)

    partitions.append(f"AUTO, {locus} = {pos}-{pos + aln_len - 1}")
    pos += aln_len

# Write FASTA supermatrix
outfile = os.path.join(phylo_dir, "concatenated_supermatrix.fasta")
with open(outfile, "w") as f:
    for taxon in taxa:
        f.write(f">{taxon}\n")
        full_seq = "".join(supermatrix[taxon])
        # Write in 80-char lines
        for i in range(0, len(full_seq), 80):
            f.write(full_seq[i:i+80] + "\n")

total_len = pos - 1
print(f"  Supermatrix: {len(taxa)} taxa × {total_len} positions")
print(f"  Wrote: {outfile}")

# Write partition file
partfile = os.path.join(phylo_dir, "partitions.txt")
with open(partfile, "w") as f:
    for p in partitions:
        f.write(p + "\n")
print(f"  Wrote: {partfile}")
PYEOF

# ============================================================================
# 5. SUMMARY
# ============================================================================

echo ""
echo "============================================================"
echo "P.4+P.5 COMPLETE"
echo "============================================================"
echo "  Gene trees inferred: ${N_TREES}"
echo "  Gene trees file: ${GENE_TREES}"
echo "  Supermatrix: ${PHYLO_DIR}/concatenated_supermatrix.fasta"
echo "  Partitions: ${PHYLO_DIR}/partitions.txt"
echo ""
echo "NEXT STEPS:"
echo "  P.6: sbatch P6_astral_species_tree.slurm"
echo "  P.7: sbatch P7_concat_iqtree.slurm  (can run in parallel with P.6)"
echo "============================================================"
echo "Finished: $(date)"
