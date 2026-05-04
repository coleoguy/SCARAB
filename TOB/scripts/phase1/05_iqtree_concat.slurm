#!/bin/bash
# ============================================================================
# 05_iqtree_concat.slurm — Concatenated ML tree, LG+C60+F+R
# ============================================================================
#
# Purpose:
#   Infer the backbone ML tree from the concatenated BUSCO protein supermatrix
#   using the site-heterogeneous mixture model LG+C60+F+R.
#   Optionally applies a topology constraint (-g) from Creedy et al. 2025
#   when the CONSTRAINT variable is set.
#
# Model rationale (from workflow_v1.md notes/01,07):
#   LBA artefacts documented for Strepsiptera + Cucujiformia under GTR and
#   vanilla LG.  LG+C60+F+R (or CAT-GTR+G4 via --gmedusa) is the agreed
#   site-heterogeneous model.
#
# Prerequisites:
#   04_concat.py complete:
#     $SCRATCH/tob/phylogenomics/supermatrix.fasta
#     $SCRATCH/tob/phylogenomics/partitions.txt
#
# Resources: 1 node, 48 cores, 750 GB (bigmem).
# Wall time: 2 days — IQ-TREE writes checkpoints; resubmit with same
#   --prefix to resume.
#
# Usage:
#   sbatch 05_iqtree_concat.slurm
#
# To run unconstrained (first pass):
#   Leave CONSTRAINT="" below.
# To run with Creedy 2025 constraint:
#   Set CONSTRAINT="$SCRATCH/tob/inputs/creedy2025_constraint.nwk"
# ============================================================================

#SBATCH --job-name=tob_iqtree_concat
#SBATCH --partition=bigmem
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=750G
#SBATCH --output=/scratch/user/blackmon/tob/logs/iqtree_concat_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/iqtree_concat_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit before submitting
# ============================================================================

TOB="${SCRATCH}/tob"
SUPERMATRIX="${TOB}/phylogenomics/supermatrix.fasta"
OUT_DIR="${TOB}/phylogenomics/concat_iqtree"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

# Topology constraint tree (Creedy et al. 2025 Syst Biol nodes).
# Set to "" to run unconstrained.
# TODO: update path once constraint tree is available from the retrieval agent.
CONSTRAINT=""
# CONSTRAINT="${TOB}/inputs/creedy2025_constraint.nwk"

# ============================================================================

echo "============================================================"
echo "TOB Phase 1 -- IQ-TREE Concatenated ML  (LG+C60+F+R)"
echo "Job: ${SLURM_JOB_ID:-local}   Cores: ${NCPUS}"
echo "Started: $(date)"
echo "============================================================"
echo ""

module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

mkdir -p "${OUT_DIR}"

# Input checks
if [ ! -f "${SUPERMATRIX}" ]; then
    echo "ERROR: ${SUPERMATRIX} not found. Run 04_concat.py first."
    exit 1
fi

N_TAXA=$(grep -c "^>" "${SUPERMATRIX}")
echo "  Supermatrix: ${N_TAXA} taxa"
echo "  Constraint:  ${CONSTRAINT:-NONE (unconstrained run)}"
echo ""

PREFIX="${OUT_DIR}/concat"

# Build IQ-TREE argument list
IQTREE_ARGS="-s ${SUPERMATRIX} --prefix ${PREFIX} -m LG+C60+F+R -bb 1000 -alrt 1000 -nt ${NCPUS} --mem 700G"

if [ -n "${CONSTRAINT}" ]; then
    if [ ! -f "${CONSTRAINT}" ]; then
        echo "ERROR: CONSTRAINT file not found: ${CONSTRAINT}"
        exit 1
    fi
    IQTREE_ARGS="${IQTREE_ARGS} -g ${CONSTRAINT}"
    echo "Applying topology constraint: ${CONSTRAINT}"
fi

echo "Running: iqtree2 ${IQTREE_ARGS}"
echo ""

iqtree2 ${IQTREE_ARGS} 2>&1 | tail -50

echo ""
echo "============================================================"
echo "IQ-TREE CONCAT COMPLETE"
echo "============================================================"

if [ -f "${PREFIX}.treefile" ]; then
    echo "  ML tree:         ${PREFIX}.treefile"
    echo "  Model log:       ${PREFIX}.iqtree"
    echo "  Bootstrap cons:  ${PREFIX}.contree"
    N_TIPS=$(grep -o "," "${PREFIX}.treefile" | wc -l)
    N_TIPS=$((N_TIPS + 1))
    echo "  Tips: ${N_TIPS}"
else
    echo "  WARNING: .treefile not found."
    echo "  If job timed out: resubmit with same prefix — IQ-TREE will resume."
fi

echo ""
echo "Finished: $(date)"
