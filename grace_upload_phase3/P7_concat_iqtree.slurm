#!/bin/bash
# ============================================================================
# P7_concat_iqtree.slurm — Concatenated ML tree with site-heterogeneous model
# ============================================================================
#
# Purpose:
#   Infer an ML tree from the concatenated BUSCO supermatrix using
#   LG+C60+F+R (site-heterogeneous mixture model) as a concordance
#   check against the wASTRAL coalescent tree.
#
# Prerequisites:
#   P4+P5 complete: concatenated_supermatrix.fasta exists
#
# Resources: 1 node, 48 cores, 128GB
# Estimated time: 24-72 hours (large mixture model analysis)
#
# Can run IN PARALLEL with P.6 (wASTRAL)
#
# Usage:
#   sbatch P7_concat_iqtree.slurm
# ============================================================================

#SBATCH --job-name=scarab_P7_concat
#SBATCH --partition=bigmem
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=750G
#SBATCH --output=scarab_P7_concat_%j.log
#SBATCH --error=scarab_P7_concat_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
SUPERMATRIX="${PHYLO_DIR}/concatenated_supermatrix.fasta"
CONCAT_DIR="${PHYLO_DIR}/concat_iqtree"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

echo "============================================================"
echo "SCARAB P.7 -- Concatenated ML Tree (LG+C60+F+R)"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "============================================================"
echo ""

module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

mkdir -p "${CONCAT_DIR}"

# Verify inputs
if [ ! -f "${SUPERMATRIX}" ]; then
    echo "ERROR: ${SUPERMATRIX} not found. Run P4_P5 first."
    exit 1
fi

N_TAXA=$(grep -c "^>" "${SUPERMATRIX}")
echo "  Supermatrix: ${N_TAXA} taxa"

# ============================================================================
# RUN IQ-TREE WITH SITE-HETEROGENEOUS MIXTURE MODEL
# ============================================================================

echo ""
echo "Running IQ-TREE with LG+C60+F+R (site-heterogeneous mixture model)..."
echo "This is more defensible than partitioned MFP for deep-time phylogenomics"
echo "because it accounts for across-site compositional heterogeneity."

PREFIX="${CONCAT_DIR}/concat"

iqtree2 -s "${SUPERMATRIX}" \
        --prefix "${PREFIX}" \
        -m LG+C60+F+R \
        -bb 1000 \
        -alrt 1000 \
        -nt "${NCPUS}" \
        --mem 700G \
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
    echo "  Bootstrap consensus: ${PREFIX}.contree"
else
    echo "  WARNING: Tree file not found. Check logs for errors."
fi

echo ""
echo "NEXT STEP: P.8 -- Compare wASTRAL vs concatenation, finalize tree"
echo "============================================================"
echo "Finished: $(date)"
