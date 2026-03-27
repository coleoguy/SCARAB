#!/bin/bash
# ============================================================================
# P4_P5_array.slurm — SLURM array: one gene per task (MAFFT + IQ-TREE)
# ============================================================================
# Replaces serial P4_P5_align_and_gene_trees.slurm with massive parallelism.
# Each array task: MAFFT alignment + IQ-TREE (ModelFinder + 1000 UFBoot)
# for one BUSCO locus. Resumes: skips genes with existing .treefile.
#
# Prerequisites: P3 complete (per_gene_seqs/*.fasta)
# Expected: ~1,284 array tasks, each ~30-60 min on 4 cores
#
# Usage:
#   # Generate loci list first:
#   ls $SCRATCH/scarab/phylogenomics/per_gene_seqs/*.fasta | \
#     xargs -I{} sh -c 'n=$(grep -c ">" "{}"); [ "$n" -ge 50 ] && basename "{}" .fasta' \
#     > $SCRATCH/scarab/phylogenomics/loci_for_trees.txt
#   N=$(wc -l < $SCRATCH/scarab/phylogenomics/loci_for_trees.txt)
#   sbatch --array=1-${N}%200 P4_P5_array.slurm
# ============================================================================

#SBATCH --job-name=scarab_gene
#SBATCH --partition=medium
#SBATCH --time=4:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=phylogenomics/logs/gene_%a_%j.log
#SBATCH --error=phylogenomics/logs/gene_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

module load GCC/12.3.0 OpenMPI/4.1.5 MAFFT/7.520-with-extensions IQ-TREE/2.3.6

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
SEQ_DIR="${PHYLO_DIR}/per_gene_seqs"
ALN_DIR="${PHYLO_DIR}/per_gene_alignments"
TREE_DIR="${PHYLO_DIR}/per_gene_trees"
LOCI_FILE="${PHYLO_DIR}/loci_for_trees.txt"

mkdir -p "${ALN_DIR}" "${TREE_DIR}" "${PHYLO_DIR}/logs"

BUSCO_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LOCI_FILE}")
if [ -z "${BUSCO_ID}" ]; then
    echo "ERROR: No locus at line ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

FASTA="${SEQ_DIR}/${BUSCO_ID}.fasta"
ALN="${ALN_DIR}/${BUSCO_ID}.aln"
TREE_PREFIX="${TREE_DIR}/${BUSCO_ID}"

echo "${BUSCO_ID}: started $(date)"

# Skip if already done
if [ -f "${TREE_PREFIX}.treefile" ]; then
    echo "${BUSCO_ID}: already done, skipping"
    exit 0
fi

# MAFFT
if [ ! -s "${ALN}" ]; then
    mafft --auto --thread 4 "${FASTA}" > "${ALN}" 2>/dev/null
fi

if [ ! -s "${ALN}" ]; then
    echo "${BUSCO_ID}: MAFFT failed"
    exit 1
fi

N_TAXA=$(grep -c "^>" "${ALN}")
echo "${BUSCO_ID}: ${N_TAXA} taxa aligned"

if [ "${N_TAXA}" -lt 50 ]; then
    echo "${BUSCO_ID}: only ${N_TAXA} taxa, skipping IQ-TREE"
    exit 0
fi

# IQ-TREE
iqtree2 -s "${ALN}" \
    --prefix "${TREE_PREFIX}" \
    -m MFP \
    -bb 1000 \
    -nt 4 \
    --quiet \
    2>/dev/null

if [ -f "${TREE_PREFIX}.treefile" ]; then
    echo "${BUSCO_ID}: done $(date)"
else
    echo "${BUSCO_ID}: IQ-TREE failed"
    exit 1
fi
