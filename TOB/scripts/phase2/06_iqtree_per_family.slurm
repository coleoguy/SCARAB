#!/bin/bash
# ==============================================================================
# 06_iqtree_per_family.slurm — SLURM array: IQ-TREE per family
# ==============================================================================
# One array task per family. Infers a constrained ML tree for each family
# supermatrix using:
#   -g backbone.tre   topology constraint (backbone from Phase 1)
#   LG+G4             model per workflow_v1.md (adequate for within-family;
#                     LBA concern is at deep backbone nodes, not within-family)
#   -bb 1000          ultrafast bootstrap
#   -alrt 1000        SH-aLRT support
#   -q partitions.txt per-locus partition model
#
# Prerequisites:
#   - 05_concat_per_family.py complete
#   - Backbone constraint tree at $BACKBONE_TREE (set below)
#   - $SCRATCH/tob/data/family_list_with_supermatrix.txt generated (see Usage)
#
# Usage:
#   # Build list of families that have a supermatrix
#   ls $SCRATCH/tob/supermatrices/ | \
#     while read f; do
#       [ -s "$SCRATCH/tob/supermatrices/$f/supermatrix.fasta" ] && echo "$f"
#     done > $SCRATCH/tob/data/family_list_with_supermatrix.txt
#   N=$(wc -l < $SCRATCH/tob/data/family_list_with_supermatrix.txt)
#   sbatch --array=1-${N}%100 06_iqtree_per_family.slurm
#
# Notes:
#   - The constraint tree must contain the family stem node but need not
#     include all species. IQ-TREE -g accepts supertrees with fewer tips
#     than the supermatrix (unresolved constraint = soft polytomy).
#   - If a family has NO tips in the constraint tree, IQ-TREE runs unconstrained.
#     This is acceptable for families absent from the Phase 1 backbone.
# ==============================================================================

#SBATCH --job-name=tob_iqtree
#SBATCH --partition=medium
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output=/scratch/user/blackmon/tob/logs/iqtree_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/iqtree_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

SCRATCH_TOB="${SCRATCH}/tob"
SUPERMATRIX_DIR="${SCRATCH_TOB}/supermatrices"
TREE_DIR="${SCRATCH_TOB}/trees"
FAMILY_LIST="${SCRATCH_TOB}/data/family_list_with_supermatrix.txt"
NCPUS=${SLURM_CPUS_PER_TASK:-8}

# Path to Phase 1 backbone constraint tree.
# Update this after Phase 1 tree is approved.
BACKBONE_TREE="${SCRATCH_TOB}/backbone/backbone.tre"

module purge
module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

FAMILY=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${FAMILY_LIST}")
if [ -z "${FAMILY}" ]; then
    echo "ERROR: No family at array index ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

FAMDIR="${SUPERMATRIX_DIR}/${FAMILY}"
SUPERMATRIX="${FAMDIR}/supermatrix.fasta"
PARTITIONS="${FAMDIR}/partitions.txt"
OUTDIR="${TREE_DIR}/${FAMILY}"

mkdir -p "${OUTDIR}"

echo "Family: ${FAMILY}"
echo "Started: $(date)"

if [ ! -s "${SUPERMATRIX}" ]; then
    echo "ERROR: supermatrix not found: ${SUPERMATRIX}"
    exit 1
fi

N_TAXA=$(grep -c "^>" "${SUPERMATRIX}")
echo "  Taxa in supermatrix: ${N_TAXA}"

# IQ-TREE prefix
PREFIX="${OUTDIR}/${FAMILY}"

# Skip if tree already exists
if [ -f "${PREFIX}.treefile" ]; then
    echo "  Tree already exists, skipping."
    exit 0
fi

# Build IQ-TREE command
# Use constraint if backbone exists AND family has >=1 tip in the backbone.
# If backbone is absent, run unconstrained (do NOT fail the job).
IQTREE_CMD="iqtree2 -s ${SUPERMATRIX} --prefix ${PREFIX} -m LG+G4 -bb 1000 -alrt 1000 -nt ${NCPUS} --quiet"

if [ -f "${BACKBONE_TREE}" ]; then
    # Check if any supermatrix taxon appears in the backbone tree
    NTIPS_IN_BACKBONE=$(python3 -c "
import re, sys
try:
    backbone = open('${BACKBONE_TREE}').read()
    taxa = []
    with open('${SUPERMATRIX}') as f:
        for line in f:
            if line.startswith('>'):
                taxa.append(line[1:].strip().split()[0])
    hits = sum(1 for t in taxa if t in backbone)
    print(hits)
except Exception as e:
    print(0)
" 2>/dev/null || echo 0)

    if [ "${NTIPS_IN_BACKBONE}" -gt 0 ]; then
        echo "  Constraint: ${NTIPS_IN_BACKBONE} taxa in backbone — using -g"
        IQTREE_CMD="${IQTREE_CMD} -g ${BACKBONE_TREE}"
    else
        echo "  No backbone tips found for ${FAMILY} — running unconstrained"
    fi
else
    echo "  WARNING: backbone tree not found at ${BACKBONE_TREE}"
    echo "  Running unconstrained. Update BACKBONE_TREE after Phase 1."
fi

# Add partition file if it exists (per-locus models)
if [ -s "${PARTITIONS}" ]; then
    IQTREE_CMD="${IQTREE_CMD} -q ${PARTITIONS}"
fi

echo "  Running: ${IQTREE_CMD}"
eval "${IQTREE_CMD}"

if [ -f "${PREFIX}.treefile" ]; then
    # Clean bulky IQ-TREE intermediates
    rm -f "${PREFIX}.ckp.gz" "${PREFIX}.splits.nex" "${PREFIX}.bionj" \
          "${PREFIX}.uniqueseq.phy" "${PREFIX}.mldist" "${PREFIX}.model.gz"
    NTIPS_TREE=$(grep -o ',' "${PREFIX}.treefile" | wc -l || echo 0)
    echo "  Done: ${NTIPS_TREE} tips in tree"
else
    echo "  ERROR: IQ-TREE failed — no treefile produced"
    exit 1
fi

echo "Family ${FAMILY} done: $(date)"
