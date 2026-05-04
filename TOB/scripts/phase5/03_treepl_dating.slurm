#!/bin/bash
# ============================================================================
# 03_treepl_dating.slurm — treePL final dated tree run
# ============================================================================
#
# Purpose:
#   Run treePL with the optimal smoothing parameter (chosen from CV in step 02)
#   to produce the primary fossil-calibrated dated tree for TOB.
#
# Prerequisites:
#   - 02_treepl_cv.slurm complete; optimal smoothing identified.
#   - treepl_dated.config has 'smooth = SMOOTHING_PLACEHOLDER' replaced with
#     the actual optimal value (edit before submitting).
#
# IMPORTANT: Edit SMOOTHING below before submitting this script.
#
# Runtime notes:
#   - treePL is single-threaded; actual optimization (not CV) is faster than CV.
#   - Typical wall time: 6-12 hr for a ~10k-tip tree.
#   - 200 GB RAM request is conservative; monitor actual usage in the log.
#
# Usage:
#   # First, edit SMOOTHING= in this script (and in treepl_dated.config)
#   sbatch 03_treepl_dating.slurm
# ============================================================================

#SBATCH --job-name=tob_treepl_dated
#SBATCH --partition=bigmem
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200G
#SBATCH --output=/scratch/user/blackmon/tob/logs/treepl_dated_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/treepl_dated_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit SMOOTHING before submitting
# ============================================================================

TOB="${SCRATCH}/tob"
DATING="${TOB}/dating"
DATED_CONFIG="${DATING}/treepl_dated.config"
OUTFILE="${DATING}/tob_dated.tre"
LOG_DIR="${TOB}/logs"

# Optimal smoothing from CV (step 02). MUST be set before submitting.
# Example: SMOOTHING=100
SMOOTHING="EDIT_BEFORE_SUBMITTING"

echo "============================================================"
echo "TOB Phase 5 -- treePL Final Dated Tree"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Node:   $(hostname)"
echo "Smoothing: ${SMOOTHING}"
echo "Started: $(date)"
echo "============================================================"
echo ""

# Validate SMOOTHING was set
if [ "${SMOOTHING}" = "EDIT_BEFORE_SUBMITTING" ]; then
    echo "ERROR: SMOOTHING not set. Edit this script and set SMOOTHING=<value>"
    echo "       from the CV results in ${DATING}/cv/cv_scores_parsed.txt"
    exit 1
fi

# Validate inputs
if [ ! -f "${DATED_CONFIG}" ]; then
    echo "ERROR: Dated config not found: ${DATED_CONFIG}"
    echo "Run 01_calibs_to_treepl_config.py first."
    exit 1
fi

# Substitute smoothing value into a working copy of the config
WORKING_CONFIG="${DATING}/treepl_dated_smooth${SMOOTHING}.config"
sed "s/smooth = SMOOTHING_PLACEHOLDER/smooth = ${SMOOTHING}/" \
    "${DATED_CONFIG}" > "${WORKING_CONFIG}"

echo "Working config: ${WORKING_CONFIG}"
echo "Contents (first 30 lines):"
head -30 "${WORKING_CONFIG}"
echo "..."
echo ""

mkdir -p "${LOG_DIR}"

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
# RUN treePL
# ============================================================================

cd "${DATING}"

treePL "${WORKING_CONFIG}" 2>&1

echo ""
echo "============================================================"
echo "treePL dated run complete"
echo "============================================================"

if [ -f "${OUTFILE}" ]; then
    echo "  Dated tree: ${OUTFILE}"
    echo "  Tree size:  $(wc -c < "${OUTFILE}") bytes"
    # Quick tip count
    NTIPS=$(grep -o "," "${OUTFILE}" | wc -l || echo "unknown")
    echo "  Approx tip count (commas): ${NTIPS}"
else
    echo "  WARNING: ${OUTFILE} not found — check log for errors."
    exit 1
fi

echo ""
echo "============================================================"
echo "NEXT STEPS (after Heath review)"
echo "============================================================"
echo "  sbatch 04_bootstrap_array.slurm    # 100-bootstrap uncertainty"
echo "  sbatch 05_jackknife_calibrations.slurm  # fossil sensitivity"
echo "  sbatch 06_burmese_amber_sensitivity.slurm"
echo "============================================================"
echo "Finished: $(date)"
