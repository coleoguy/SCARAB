#!/bin/bash
# ============================================================================
# 04_bootstrap_array.slurm — treePL array over 100 IQ-TREE bootstrap trees
# ============================================================================
#
# Purpose:
#   Run treePL independently on each of 100 IQ-TREE ultrafast bootstrap trees
#   to capture branch-length sampling uncertainty in divergence dates.
#   Each task extracts one bootstrap tree, builds a treePL config, and runs
#   treePL with the optimal smoothing from step 02.
#   Outputs are 100 dated trees; step 07 summarizes 95% HPD intervals across them.
#
# Prerequisites:
#   - 03_treepl_dating.slurm complete and primary dated tree approved.
#   - SMOOTHING set below (same value used in step 03).
#   - IQ-TREE bootstrap trees at:
#       $SCRATCH/tob/phylogenomics/concat/tob_concat.ufboot
#     (one Newick per line; 100 lines if Phase 1 used -B 100, or 1000 if -B 1000)
#
# IMPORTANT: Edit SMOOTHING and TOTAL_BS before submitting.
#
# Usage:
#   sbatch --array=1-100 04_bootstrap_array.slurm
#   (If TOTAL_BS=1000: sbatch --array=1-100 ... still runs 100 evenly-spaced trees)
# ============================================================================

#SBATCH --job-name=tob_treepl_bs
#SBATCH --partition=bigmem
#SBATCH --time=8:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200G
#SBATCH --output=/scratch/user/blackmon/tob/logs/treepl_bs_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/treepl_bs_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit before submitting
# ============================================================================

SMOOTHING="EDIT_BEFORE_SUBMITTING"   # Optimal smoothing from CV step
TOTAL_BS=100                         # Number of bootstrap trees in .ufboot file
                                     # Set to 1000 if IQ-TREE used -B 1000

TOB="${SCRATCH}/tob"
DATING="${TOB}/dating"
UFBOOT="${TOB}/phylogenomics/concat/tob_concat.ufboot"
DATED_CONFIG="${DATING}/treepl_dated.config"
BS_DIR="${DATING}/bootstrap"
LOG_DIR="${TOB}/logs"

TASK_ID=${SLURM_ARRAY_TASK_ID:-1}

echo "============================================================"
echo "TOB Phase 5 -- treePL Bootstrap Array"
echo "Job ID:   ${SLURM_JOB_ID:-local}"
echo "Task ID:  ${TASK_ID}"
echo "Node:     $(hostname)"
echo "Smoothing: ${SMOOTHING}"
echo "Started: $(date)"
echo "============================================================"
echo ""

if [ "${SMOOTHING}" = "EDIT_BEFORE_SUBMITTING" ]; then
    echo "ERROR: SMOOTHING not set. Edit this script."
    exit 1
fi

if [ ! -f "${UFBOOT}" ]; then
    echo "ERROR: Bootstrap file not found: ${UFBOOT}"
    exit 1
fi

if [ ! -f "${DATED_CONFIG}" ]; then
    echo "ERROR: Dated config template not found: ${DATED_CONFIG}"
    exit 1
fi

mkdir -p "${BS_DIR}" "${LOG_DIR}"

# ============================================================================
# EXTRACT BOOTSTRAP TREE FOR THIS TASK
# ============================================================================
# If TOTAL_BS=100, task N uses line N.
# If TOTAL_BS=1000, we subsample evenly: task N uses line (N * TOTAL_BS / 100).
# This gives 100 trees spanning the full bootstrap distribution.

if [ "${TOTAL_BS}" -eq 100 ]; then
    LINE_NUM=${TASK_ID}
else
    LINE_NUM=$(( TASK_ID * TOTAL_BS / 100 ))
    if [ "${LINE_NUM}" -lt 1 ]; then
        LINE_NUM=1
    fi
fi

BS_TREE="${BS_DIR}/bs_tree_${TASK_ID}.nwk"
sed -n "${LINE_NUM}p" "${UFBOOT}" > "${BS_TREE}"

if [ ! -s "${BS_TREE}" ]; then
    echo "ERROR: Failed to extract line ${LINE_NUM} from ${UFBOOT}"
    exit 1
fi

echo "Extracted bootstrap tree: line ${LINE_NUM} -> ${BS_TREE}"

# ============================================================================
# BUILD TASK-SPECIFIC treePL CONFIG
# ============================================================================

TASK_CONFIG="${BS_DIR}/treepl_bs_${TASK_ID}.config"
TASK_OUTFILE="${BS_DIR}/dated_bs_${TASK_ID}.tre"

# Replace treefile and outfile paths, set smoothing
sed \
    -e "s|treefile = .*|treefile = ${BS_TREE}|" \
    -e "s|outfile = .*|outfile = ${TASK_OUTFILE}|" \
    -e "s|smooth = SMOOTHING_PLACEHOLDER|smooth = ${SMOOTHING}|" \
    -e "/^cv$/d" \
    -e "/^cvstart/d" \
    -e "/^cvstop/d" \
    -e "/^cvmultstep/d" \
    "${DATED_CONFIG}" > "${TASK_CONFIG}"

echo "Task config: ${TASK_CONFIG}"

# ============================================================================
# ENVIRONMENT
# ============================================================================

module purge
module load Anaconda3/2024.02-1
source "${EBROOTANACONDA3}/etc/profile.d/conda.sh"
conda activate tob-treepl

# ============================================================================
# RESUME CHECK
# ============================================================================

if [ -f "${TASK_OUTFILE}" ] && [ -s "${TASK_OUTFILE}" ]; then
    echo "Output already exists: ${TASK_OUTFILE} — skipping."
    echo "Delete file to re-run this task."
    exit 0
fi

# ============================================================================
# RUN treePL
# ============================================================================

cd "${BS_DIR}"

treePL "${TASK_CONFIG}" 2>&1

echo ""

if [ -f "${TASK_OUTFILE}" ] && [ -s "${TASK_OUTFILE}" ]; then
    echo "Task ${TASK_ID} complete: ${TASK_OUTFILE}"
else
    echo "ERROR: Task ${TASK_ID} output not found or empty: ${TASK_OUTFILE}"
    exit 1
fi

echo "Finished: $(date)"
