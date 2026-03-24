#!/bin/bash
# ============================================================================
# setup_phase3.sh — One-step Phase 3 setup on Grace
# ============================================================================
#
# Steps:
#   1. Create directory structure
#   2. Pull Cactus Singularity container (v2.9.3)
#   3. Build seqFile (calls build_seqfile.sh)
#   4. Run cactus-prepare to decompose alignment into steps
#   5. Print next-step instructions
#
# Prerequisites:
#   - 439 genomes in $SCRATCH/scarab/genomes/ (Phase 2 complete)
#   - tree_tip_mapping.csv in $SCRATCH/scarab/data/
#   - Guide tree: either nuclear BUSCO tree (from extract_nuclear_markers_and_build_tree.slurm)
#     or calibrated tree in $SCRATCH/scarab/data/constraint_tree_calibrated.nwk
#
# RECOMMENDED: Run prepare_nuclear_markers.sh + extract_nuclear_markers_and_build_tree.slurm
# FIRST to build an empirical guide tree from 15 conserved BUSCO proteins.
#
# Usage (on Grace login node):
#   bash setup_phase3.sh
#
# NOTE: Pulling the container takes ~15-30 min on Grace login node.
#       Run this with nohup if needed.
# ============================================================================

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
CACTUS_VERSION="v2.9.3"
CACTUS_IMAGE="quay.io/comparative-genomics-toolkit/cactus:${CACTUS_VERSION}"
CONTAINER="${PROJECT_DIR}/cactus_${CACTUS_VERSION}.sif"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"
PREPARED_DIR="${PROJECT_DIR}/prepared"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================================"
echo "SCARAB — Phase 3 Setup"
echo "Started: $(date)"
echo "User: ${USER}"
echo "============================================================"
echo ""

# ---- 1. Create directory structure ----
echo "[1/4] Creating directory structure..."
for d in data work hal_files prepared logs results tmp; do
    mkdir -p "${PROJECT_DIR}/${d}"
done
echo "  Done: ${PROJECT_DIR}/"
echo ""

# ---- 2. Pull Cactus Singularity container ----
echo "[2/4] Pulling Cactus Singularity container..."
echo "  Image: ${CACTUS_IMAGE}"
echo "  Target: ${CONTAINER}"

if [ -f "${CONTAINER}" ]; then
    echo "  Container already exists — skipping pull."
else
    module load Singularity 2>/dev/null || module load singularity 2>/dev/null || true

    SINGULARITY_TMPDIR="${PROJECT_DIR}/tmp" \
    singularity pull "${CONTAINER}" "docker://${CACTUS_IMAGE}"
    echo "  Pull complete."
fi
echo ""

# Verify container tools
echo "  Verifying container..."
SING="singularity exec --cleanenv -B ${PROJECT_DIR}:${PROJECT_DIR} -B /tmp:/tmp ${CONTAINER}"

CACTUS_VER=$(${SING} cactus --version 2>&1 || echo "FAILED")
echo "  cactus: ${CACTUS_VER}"
# halStats has no --version flag; just check it runs at all
HAL_CHECK=$(${SING} halStats --help 2>&1 | head -1 || echo "FAILED")
echo "  halStats: ${HAL_CHECK}"
echo ""

# ---- 3. Build seqFile ----
echo "[3/4] Building Cactus seqFile..."
if [ -f "${SCRIPT_DIR}/build_seqfile.sh" ]; then
    bash "${SCRIPT_DIR}/build_seqfile.sh"
else
    echo "  ERROR: build_seqfile.sh not found in ${SCRIPT_DIR}"
    exit 1
fi
echo ""

# ---- 4. Run cactus-prepare ----
echo "[4/4] Running cactus-prepare (decomposition)..."

TOTAL_ENTRIES=$(tail -n +2 "${SEQFILE}" | grep -c . 2>/dev/null || echo "0")

if [ "${TOTAL_ENTRIES}" -gt 2 ]; then
    mkdir -p "${PREPARED_DIR}"

    ${SING} cactus-prepare \
        "${SEQFILE}" \
        --outDir "${PREPARED_DIR}" \
        --outSeqFile "${PREPARED_DIR}/prepared_seqfile.txt" \
        --outHal "${PROJECT_DIR}/hal_files/scarab.hal" \
        --jobStore "${PROJECT_DIR}/work/js" \
        > "${PREPARED_DIR}/steps.sh" 2>&1 || {
            echo "  WARNING: cactus-prepare returned non-zero exit."
            echo "  Check ${PREPARED_DIR}/steps.sh for details."
        }

    if [ -f "${PREPARED_DIR}/steps.sh" ]; then
        STEP_COUNT=$(grep -c "^cactus" "${PREPARED_DIR}/steps.sh" 2>/dev/null || echo "0")
        echo "  cactus-prepare generated ${STEP_COUNT} steps"
        echo "  Steps file: ${PREPARED_DIR}/steps.sh"
        echo ""
        echo "  First 10 lines:"
        head -10 "${PREPARED_DIR}/steps.sh" | sed 's/^/    /'
    fi
else
    echo "  ERROR: Only ${TOTAL_ENTRIES} genomes in seqFile. Expected ~439."
    exit 1
fi

echo ""
echo "============================================================"
echo "Setup Complete"
echo "============================================================"
echo ""
echo "Container:     ${CONTAINER}"
echo "seqFile:       ${SEQFILE} (${TOTAL_ENTRIES} genomes)"
echo "Prepared dir:  ${PREPARED_DIR}"
echo ""
echo "NEXT STEPS:"
echo "  1. Build nuclear guide tree (if not already done):"
echo "     bash ${SCRIPT_DIR}/prepare_nuclear_markers.sh"
echo "     sbatch ${SCRIPT_DIR}/extract_nuclear_markers_and_build_tree.slurm"
echo ""
echo "  2. Test alignment on 5 small genomes:"
echo "     sbatch ${SCRIPT_DIR}/test_alignment.slurm"
echo ""
echo "  3. If test passes, submit full alignment:"
echo "     sbatch ${SCRIPT_DIR}/run_full_alignment.slurm"
echo ""
echo "Finished: $(date)"
