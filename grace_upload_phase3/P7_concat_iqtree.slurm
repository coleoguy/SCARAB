#!/bin/bash
# ============================================================================
# P7_concat_iqtree.slurm — Partitioned IQ-TREE on concatenated supermatrix
# ============================================================================
#
# Purpose:
#   Infer a partitioned ML tree from the concatenated 300-500 gene supermatrix
#   as a concordance check against the ASTRAL coalescent tree.
#   Uses edge-linked proportional partition models.
#
# Prerequisites:
#   P4+P5 complete: concatenated_supermatrix.fasta and partitions.txt exist
#
# Resources: 1 node, 48 cores, 128GB
# Estimated time: 12-48 hours (large partitioned analysis)
#
# Can run IN PARALLEL with P.6 (ASTRAL)
#
# Usage:
#   sbatch P7_concat_iqtree.slurm
# ============================================================================

#SBATCH --job-name=scarab_P7_concat
#SBATCH --partition=long
#SBATCH --time=3-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --output=scarab_P7_concat_%j.log
#SBATCH --error=scarab_P7_concat_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
SUPERMATRIX="${PHYLO_DIR}/concatenated_supermatrix.fasta"
PARTITIONS="${PHYLO_DIR}/partitions.txt"
CONCAT_DIR="${PHYLO_DIR}/concat_iqtree"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

echo "============================================================"
echo "SCARAB P.7 — Partitioned IQ-TREE (Concatenation Check)"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "============================================================"
echo ""

module load GCC/12.2.0 IQ-TREE/2.2.6

mkdir -p "${CONCAT_DIR}"

# Verify inputs
if [ ! -f "${SUPERMATRIX}" ]; then
    echo "ERROR: ${SUPERMATRIX} not found. Run P4_P5 first."
    exit 1
fi
if [ ! -f "${PARTITIONS}" ]; then
    echo "ERROR: ${PARTITIONS} not found. Run P4_P5 first."
    exit 1
fi

N_TAXA=$(grep -c "^>" "${SUPERMATRIX}")
N_PARTS=$(wc -l < "${PARTITIONS}")
echo "  Supermatrix: ${N_TAXA} taxa"
echo "  Partitions: ${N_PARTS}"

# ============================================================================
# RUN PARTITIONED IQ-TREE
# ============================================================================

echo ""
echo "Running IQ-TREE with edge-linked proportional partitions..."

PREFIX="${CONCAT_DIR}/concat"

iqtree2 -s "${SUPERMATRIX}" \
        -p "${PARTITIONS}" \
        --prefix "${PREFIX}" \
        -m MFP \
        -bb 1000 \
        -alrt 1000 \
        -nt ${NCPUS} \
        --mem 120G \
        2>&1 | tail -30

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "============================================================"
echo "P.7 COMPLETE"
echo "============================================================"

if [ -f "${PREFIX}.treefile" ]; then
    echo "  Concatenation tree: ${PREFIX}.treefile"
    echo "  Model details: ${PREFIX}.iqtree"
    echo "  Bootstrap values: ${PREFIX}.contree"
else
    echo "  WARNING: Tree file not found. Check logs for errors."
fi

echo ""
echo "NEXT STEP: P.8 — Compare ASTRAL vs concatenation, finalize tree"
echo "============================================================"
echo "Finished: $(date)"
