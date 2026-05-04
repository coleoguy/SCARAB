#!/bin/bash
# ============================================================================
# 06_burmese_amber_sensitivity.slurm — Burmese amber calibration sensitivity
# ============================================================================
#
# Purpose:
#   Run treePL TWICE: (A) with all Burmese amber calibrations included (the
#   default run), and (B) with all 9 Burmese amber calibrations removed.
#   Per workflow_v1.md, this directly tests the Burmese amber sensitivity
#   called for by the Parham 2012 best-practice framework and the ethical
#   embargo concerns around Burmese amber specimens.
#
# Burmese amber calibrations in Cai et al. 2022 with TOB scope (9 nodes):
#   node 12  — Crown Psephenidae
#   node 17  — Elateridae (Lissomini) - Lycidae split
#   node 18  — Lampyridae - (Phengodidae + Rhagophthalmidae) split
#   node 29  — Staphylinidae Apateticinae - Osoriinae (EXCLUDED: TOB scope N)
#   node 31  — Crown Bostrichidae
#   node 37  — Rhipiphoridae - Mordellidae split
#   node 41  — Crown Zopheridae
#   node 44  — Crown Endomychidae
#   node 50  — Crown Silvanidae
# Of the 57 calibrations, 9 have TOB scope=Y and burmese_amber_flag=Y.
# Script removes all lines whose treePL label contains nodes flagged # BURMESE_AMBER
# in the config (marked by the comment appended by 01_calibs_to_treepl_config.py).
#
# IMPORTANT: Edit SMOOTHING before submitting.
#
# Usage:
#   sbatch 06_burmese_amber_sensitivity.slurm
# ============================================================================

#SBATCH --job-name=tob_amber_sens
#SBATCH --partition=bigmem
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200G
#SBATCH --output=/scratch/user/blackmon/tob/logs/treepl_amber_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/treepl_amber_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION — edit before submitting
# ============================================================================

SMOOTHING="EDIT_BEFORE_SUBMITTING"   # Optimal smoothing from CV step

TOB="${SCRATCH}/tob"
DATING="${TOB}/dating"
DATED_CONFIG="${DATING}/treepl_dated.config"
AMBER_DIR="${DATING}/amber_sensitivity"
LOG_DIR="${TOB}/logs"

echo "============================================================"
echo "TOB Phase 5 -- Burmese Amber Sensitivity"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Node:   $(hostname)"
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

mkdir -p "${AMBER_DIR}" "${LOG_DIR}"

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
# HELPER: get amber node labels from config
# ============================================================================
# 01_calibs_to_treepl_config.py appends "# BURMESE_AMBER" to mrca lines for
# amber nodes. We extract the label (field 3) from those lines.

AMBER_LABELS=$(grep "# BURMESE_AMBER" "${DATED_CONFIG}" | awk '{print $3}' || true)

if [ -z "${AMBER_LABELS}" ]; then
    echo "WARNING: No BURMESE_AMBER-flagged mrca lines found in config."
    echo "         Check that 01_calibs_to_treepl_config.py annotated them."
    echo "         Proceeding with both runs (without-amber config = with-amber config)."
fi

echo "Burmese amber node labels to remove:"
echo "${AMBER_LABELS}" | tr ' ' '\n' | sed 's/^/  /'
echo ""

# ============================================================================
# RUN A: WITH all amber calibrations (standard run = same as 03)
# ============================================================================

CONFIG_WITH="${AMBER_DIR}/treepl_with_amber.config"
OUTFILE_WITH="${AMBER_DIR}/dated_with_amber.tre"

sed \
    -e "s|smooth = SMOOTHING_PLACEHOLDER|smooth = ${SMOOTHING}|" \
    -e "s|outfile = .*|outfile = ${OUTFILE_WITH}|" \
    -e "/^cv$/d" -e "/^cvstart/d" -e "/^cvstop/d" -e "/^cvmultstep/d" \
    "${DATED_CONFIG}" > "${CONFIG_WITH}"

echo "============================================================"
echo "RUN A: WITH Burmese amber calibrations"
echo "Config: ${CONFIG_WITH}"
echo "============================================================"

if [ -f "${OUTFILE_WITH}" ] && [ -s "${OUTFILE_WITH}" ]; then
    echo "Output already exists, skipping Run A: ${OUTFILE_WITH}"
else
    cd "${AMBER_DIR}"
    treePL "${CONFIG_WITH}" 2>&1
    echo "Run A complete: ${OUTFILE_WITH}"
fi

echo ""

# ============================================================================
# RUN B: WITHOUT Burmese amber calibrations
# ============================================================================

CONFIG_WITHOUT="${AMBER_DIR}/treepl_without_amber.config"
OUTFILE_WITHOUT="${AMBER_DIR}/dated_without_amber.tre"

# Build without-amber config: start from dated config, then strip amber labels
cp "${DATED_CONFIG}" "${CONFIG_WITHOUT}.tmp"

for LABEL in ${AMBER_LABELS}; do
    grep -v "^mrca = ${LABEL} " "${CONFIG_WITHOUT}.tmp" \
      | grep -v "^min = ${LABEL} " \
      | grep -v "^max = ${LABEL} " \
      > "${CONFIG_WITHOUT}.tmp2"
    mv "${CONFIG_WITHOUT}.tmp2" "${CONFIG_WITHOUT}.tmp"
done

sed \
    -e "s|smooth = SMOOTHING_PLACEHOLDER|smooth = ${SMOOTHING}|" \
    -e "s|outfile = .*|outfile = ${OUTFILE_WITHOUT}|" \
    -e "/^cv$/d" -e "/^cvstart/d" -e "/^cvstop/d" -e "/^cvmultstep/d" \
    "${CONFIG_WITHOUT}.tmp" > "${CONFIG_WITHOUT}"

rm -f "${CONFIG_WITHOUT}.tmp"

# Count remaining calibrations
N_WITH=$(grep -c "^mrca" "${CONFIG_WITH}" || true)
N_WITHOUT=$(grep -c "^mrca" "${CONFIG_WITHOUT}" || true)
echo "Calibration counts: with_amber=${N_WITH}  without_amber=${N_WITHOUT}"
echo "Removed: $((N_WITH - N_WITHOUT)) amber calibrations"
echo ""

echo "============================================================"
echo "RUN B: WITHOUT Burmese amber calibrations"
echo "Config: ${CONFIG_WITHOUT}"
echo "============================================================"

if [ -f "${OUTFILE_WITHOUT}" ] && [ -s "${OUTFILE_WITHOUT}" ]; then
    echo "Output already exists, skipping Run B: ${OUTFILE_WITHOUT}"
else
    cd "${AMBER_DIR}"
    treePL "${CONFIG_WITHOUT}" 2>&1
    echo "Run B complete: ${OUTFILE_WITHOUT}"
fi

echo ""
echo "============================================================"
echo "Burmese amber sensitivity runs complete"
echo "============================================================"
echo "  With amber:    ${OUTFILE_WITH}"
echo "  Without amber: ${OUTFILE_WITHOUT}"
echo ""
echo "Both trees are inputs to 07_summarize_dates.R for node-age comparison."
echo "============================================================"
echo "Finished: $(date)"
