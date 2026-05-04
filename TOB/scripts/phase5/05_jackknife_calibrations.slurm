#!/bin/bash
# ============================================================================
# 05_jackknife_calibrations.slurm — Drop-one calibration sensitivity
# ============================================================================
#
# Purpose:
#   Run treePL once per calibration node, dropping that node's fossil from the
#   config each time (leave-one-out / jackknife). Allows assessment of which
#   fossils most strongly pull node ages and which are internally inconsistent.
#   Step 07 uses these outputs to generate per-node sensitivity diagnostics.
#
# How it works:
#   The script reads the working dated config and counts calibration blocks
#   (lines starting with 'mrca = '). Each SLURM array task corresponds to one
#   calibration node. That task removes the mrca/min/max triplet for its node
#   and runs treePL on the reduced calibration set.
#
# Prerequisites:
#   - 03_treepl_dating.slurm complete and primary dated tree approved.
#   - SMOOTHING set below.
#   - Working dated config at $SCRATCH/tob/dating/treepl_dated.config
#     (with 'smooth = SMOOTHING_PLACEHOLDER' replaced, OR use the sed method below)
#
# IMPORTANT:
#   - Count the number of 'mrca = ' lines in treepl_dated.config:
#       grep -c "^mrca" $SCRATCH/tob/dating/treepl_dated.config
#   - Submit with: sbatch --array=1-<N> 05_jackknife_calibrations.slurm
#   - Edit N_CALIBS and SMOOTHING below before submitting.
#
# Usage:
#   sbatch --array=1-43 05_jackknife_calibrations.slurm
#   (43 = number of TOB-applicable calibrations; adjust after running step 01)
# ============================================================================

#SBATCH --job-name=tob_treepl_jk
#SBATCH --partition=bigmem
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200G
#SBATCH --output=/scratch/user/blackmon/tob/logs/treepl_jk_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/treepl_jk_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit before submitting
# ============================================================================

SMOOTHING="EDIT_BEFORE_SUBMITTING"   # Optimal smoothing from CV step

TOB="${SCRATCH}/tob"
DATING="${TOB}/dating"
DATED_CONFIG="${DATING}/treepl_dated.config"
JK_DIR="${DATING}/jackknife"
LOG_DIR="${TOB}/logs"

TASK_ID=${SLURM_ARRAY_TASK_ID:-1}

echo "============================================================"
echo "TOB Phase 5 -- treePL Calibration Jackknife"
echo "Job ID:   ${SLURM_JOB_ID:-local}"
echo "Task ID:  ${TASK_ID}  (drops calibration #${TASK_ID})"
echo "Node:     $(hostname)"
echo "Smoothing: ${SMOOTHING}"
echo "Started: $(date)"
echo "============================================================"
echo ""

if [ "${SMOOTHING}" = "EDIT_BEFORE_SUBMITTING" ]; then
    echo "ERROR: SMOOTHING not set. Edit this script."
    exit 1
fi

if [ ! -f "${DATED_CONFIG}" ]; then
    echo "ERROR: Dated config not found: ${DATED_CONFIG}"
    exit 1
fi

mkdir -p "${JK_DIR}" "${LOG_DIR}"

# ============================================================================
# EXTRACT THE LABEL FOR THE CALIBRATION TO DROP (task N = Nth mrca block)
# ============================================================================
# mrca lines look like: mrca = LABEL tip1 tip2
# We also need to remove the corresponding min = LABEL and max = LABEL lines.

DROP_LABEL=$(grep "^mrca" "${DATED_CONFIG}" | sed -n "${TASK_ID}p" | awk '{print $3}')

if [ -z "${DROP_LABEL}" ]; then
    echo "ERROR: Could not extract label for calibration #${TASK_ID}"
    echo "Check that --array= range does not exceed the number of mrca lines."
    exit 1
fi

echo "Dropping calibration: ${DROP_LABEL}"

# ============================================================================
# BUILD JACKKNIFE CONFIG
# ============================================================================

TASK_CONFIG="${JK_DIR}/treepl_jk_${TASK_ID}_drop_${DROP_LABEL}.config"
TASK_OUTFILE="${JK_DIR}/dated_jk_${TASK_ID}_drop_${DROP_LABEL}.tre"

# Remove mrca, min, max lines for DROP_LABEL; set smoothing; strip cv block
grep -v "^mrca = ${DROP_LABEL} " "${DATED_CONFIG}" \
  | grep -v "^min = ${DROP_LABEL} " \
  | grep -v "^max = ${DROP_LABEL} " \
  | sed "s|smooth = SMOOTHING_PLACEHOLDER|smooth = ${SMOOTHING}|" \
  | sed "s|outfile = .*|outfile = ${TASK_OUTFILE}|" \
  | grep -v "^cv$" \
  | grep -v "^cvstart" \
  | grep -v "^cvstop" \
  | grep -v "^cvmultstep" \
  > "${TASK_CONFIG}"

echo "Task config written: ${TASK_CONFIG}"
echo "Removed: mrca/min/max lines for ${DROP_LABEL}"
echo ""

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
    exit 0
fi

# ============================================================================
# RUN treePL
# ============================================================================

cd "${JK_DIR}"

treePL "${TASK_CONFIG}" 2>&1

echo ""

if [ -f "${TASK_OUTFILE}" ] && [ -s "${TASK_OUTFILE}" ]; then
    echo "Task ${TASK_ID} (drop ${DROP_LABEL}) complete: ${TASK_OUTFILE}"
else
    echo "ERROR: Output not found or empty: ${TASK_OUTFILE}"
    exit 1
fi

echo "Finished: $(date)"
