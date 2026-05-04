#!/bin/bash
# ============================================================================
# 02_treepl_cv.slurm — treePL cross-validation for optimal smoothing parameter
# ============================================================================
#
# Purpose:
#   Run treePL in cross-validation (cv) mode to identify the optimal penalized
#   likelihood smoothing parameter for the TOB dated tree. treePL tests a log-
#   spaced grid of smoothing values (cvstart/cvstop/cvmultstep in config) and
#   reports the leave-one-out cross-validation score for each. The smoothing
#   value with the lowest CV score is used for the final dated run.
#
# Prerequisites:
#   - 01_calibs_to_treepl_config.py run; CV config exists at:
#       $SCRATCH/tob/dating/treepl_cv.config
#   - tob-treepl conda env installed (scripts/setup/install_treepl_grace.sh)
#
# Runtime notes:
#   - treePL CV is single-threaded and can be memory-hungry for large trees
#     (10k+ tips can use 50-150 GB RAM; bigmem is mandatory).
#   - Typical wall time: 12-24 hr for a ~10k-tip tree and 10-step CV grid.
#   - CV output is written to stdout/stderr captured in the log; the CV scores
#     are lines matching "smooth = X  CV = Y" in the treePL output.
#
# Usage:
#   sbatch 02_treepl_cv.slurm
# ============================================================================

#SBATCH --job-name=tob_treepl_cv
#SBATCH --partition=bigmem
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200G
#SBATCH --output=/scratch/user/blackmon/tob/logs/treepl_cv_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/treepl_cv_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

TOB="${SCRATCH}/tob"
DATING="${TOB}/dating"
CV_CONFIG="${DATING}/treepl_cv.config"
CV_DIR="${DATING}/cv"
CV_RESULTS="${CV_DIR}/cv_results.txt"
LOG_DIR="${TOB}/logs"

echo "============================================================"
echo "TOB Phase 5 -- treePL Cross-Validation"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Node:   $(hostname)"
echo "Started: $(date)"
echo "============================================================"
echo ""

# Validate inputs
if [ ! -f "${CV_CONFIG}" ]; then
    echo "ERROR: CV config not found: ${CV_CONFIG}"
    echo "Run 01_calibs_to_treepl_config.py first."
    exit 1
fi

mkdir -p "${CV_DIR}" "${LOG_DIR}"

# ============================================================================
# ENVIRONMENT
# ============================================================================

module purge
module load Anaconda3/2024.02-1
source "${EBROOTANACONDA3}/etc/profile.d/conda.sh"
conda activate tob-treepl

echo "treePL binary: $(which treePL 2>/dev/null || echo NOT_FOUND)"
echo ""

# ============================================================================
# RUN treePL CV
# ============================================================================

echo "Config: ${CV_CONFIG}"
echo "Output dir: ${CV_DIR}"
echo ""

# Run from cv dir so treePL's temp files land there
cd "${CV_DIR}"

treePL "${CV_CONFIG}" 2>&1 | tee "${CV_RESULTS}"

echo ""
echo "============================================================"
echo "CV run complete. Raw output in: ${CV_RESULTS}"
echo "============================================================"
echo ""

# ============================================================================
# PARSE CV SCORES — extract and summarize
# ============================================================================

echo "Parsing CV scores..."
echo ""

PARSED="${CV_DIR}/cv_scores_parsed.txt"

# treePL prints lines like: "smooth = <val> lnL = <val> CV = <val>"
# Extract them for easy review
grep -E "^smooth" "${CV_RESULTS}" > "${PARSED}" || true

if [ -s "${PARSED}" ]; then
    echo "CV score summary (all tested smoothing values):"
    echo "------------------------------------------------"
    cat "${PARSED}"
    echo ""
    echo "Best smoothing (lowest CV score):"
    # Sort numerically on the CV field (field 6) and pick minimum
    # Format: smooth = X lnL = Y CV = Z
    sort -k6 -n "${PARSED}" | head -1
else
    echo "WARNING: No 'smooth = ...' lines found in CV output."
    echo "Check ${CV_RESULTS} for errors."
fi

echo ""
echo "============================================================"
echo "NEXT STEPS"
echo "============================================================"
echo "  1. Inspect ${PARSED}"
echo "  2. Identify the smoothing value with the LOWEST CV score"
echo "  3. Edit smooth = SMOOTHING_PLACEHOLDER in:"
echo "     ${DATING}/treepl_dated.config"
echo "  4. Get Heath's approval, then submit:"
echo "     sbatch 03_treepl_dating.slurm"
echo "============================================================"
echo "Finished: $(date)"
