#!/bin/bash
##############################################################################
# PHASE_2.1_pipeline_setup/test_alignment.slurm
#
# Purpose:
#   Test the Cactus alignment pipeline on 5 SMALL beetle genomes to verify:
#     - Singularity container works
#     - Cactus can read our seqFile format
#     - HAL output is generated and validates with halStats
#     - Resource estimates are reasonable
#
#   This uses the modern Cactus v2.x API:
#     cactus <jobStore> <seqFile> <outputHal> [options]
#
# Queue:  short (4 hour limit on Grace)
# Resources: 1 node, 48 cores, 384 GB RAM
# Expected runtime: ~30-90 min for 5 small genomes
#
# Usage:
#   sbatch test_alignment.slurm
#
# Monitoring:
#   squeue -u $USER
#   tail -f scarab_test_alignment_<JOBID>.log
##############################################################################

#SBATCH --job-name=scarab_test
#SBATCH --partition=short
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=384G
#SBATCH --output=scarab_test_alignment_%j.log
#SBATCH --error=scarab_test_alignment_%j.err
#SBATCH --mail-type=END,FAIL
## Uncomment and edit:
##SBATCH --mail-user=youremail@tamu.edu

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

NETID="${USER}"
PROJECT_DIR="/scratch/user/${NETID}/scarab"
CONTAINER="${PROJECT_DIR}/cactus_v2.9.3.sif"

# We'll select 5 small genomes from the seqFile for testing
FULL_SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"

# Test-specific paths
TEST_DIR="${PROJECT_DIR}/work/test_alignment"
TEST_SEQFILE="${TEST_DIR}/test_seqfile.txt"
TEST_JOBSTORE="${TEST_DIR}/jobstore"
TEST_HAL="${TEST_DIR}/test_alignment.hal"

# Singularity bind mount
SING="singularity exec --cleanenv \
  -B ${PROJECT_DIR}:${PROJECT_DIR} \
  -B /tmp:/tmp \
  ${CONTAINER}"

# ============================================================================
# SETUP
# ============================================================================

echo "============================================================"
echo "SCARAB — Test Alignment"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-48}"
echo "Memory: ${SLURM_MEM_PER_NODE:-384000} MB"
echo "============================================================"
echo ""

mkdir -p "${TEST_DIR}"

# Remove stale jobstore if exists (Toil requires clean start or explicit --restart)
if [ -d "${TEST_JOBSTORE}" ]; then
    echo "Removing stale jobStore from previous attempt..."
    rm -rf "${TEST_JOBSTORE}"
fi

# ============================================================================
# VERIFY CONTAINER
# ============================================================================

echo "[1/5] Verifying container..."

if [ ! -f "${CONTAINER}" ]; then
    echo "ERROR: Container not found: ${CONTAINER}"
    echo "Run setup_grace.sh first."
    exit 1
fi

${SING} cactus --version
echo "  Container OK"
echo ""

# ============================================================================
# BUILD TEST SEQFILE (5 smallest genomes)
# ============================================================================

echo "[2/5] Building test seqFile with 5 small genomes..."

if [ ! -f "${FULL_SEQFILE}" ]; then
    echo "ERROR: Full seqFile not found: ${FULL_SEQFILE}"
    echo "Run setup_grace.sh first."
    exit 1
fi

# Extract tree (line 1 of seqFile)
TREE_LINE=$(head -1 "${FULL_SEQFILE}")

# Extract genome entries (lines 2+), find 5 smallest by file size
echo "  Scanning genome sizes..."
tail -n +2 "${FULL_SEQFILE}" | while IFS=' ' read -r taxon path; do
    [ -z "${taxon}" ] && continue
    [ -z "${path}" ] && continue
    if [ -f "${path}" ]; then
        SIZE=$(stat -c%s "${path}" 2>/dev/null || echo "999999999")
        echo "${SIZE} ${taxon} ${path}"
    fi
done | sort -n | head -5 > "${TEST_DIR}/test_genomes_sorted.txt"

# Check we got at least 3 genomes
TEST_COUNT=$(wc -l < "${TEST_DIR}/test_genomes_sorted.txt")
if [ "${TEST_COUNT}" -lt 3 ]; then
    echo "ERROR: Found only ${TEST_COUNT} genomes. Need at least 3 for test."
    echo "Make sure genomes are downloaded to ${PROJECT_DIR}/genomes/"
    exit 1
fi

echo "  Selected ${TEST_COUNT} test genomes (smallest by file size):"
cat "${TEST_DIR}/test_genomes_sorted.txt" | while read size taxon path; do
    SIZE_MB=$(echo "scale=1; ${size}/1048576" | bc)
    echo "    ${taxon}: ${SIZE_MB} MB"
done

# Build a simple star tree for test genomes
# (We don't need the full constraint tree for testing)
TEST_TAXA=$(awk '{print $2}' "${TEST_DIR}/test_genomes_sorted.txt" | paste -sd, -)

# Build Newick star tree: (t1:0.1,t2:0.1,t3:0.1,...);
STAR_TREE="("
FIRST=true
while read size taxon path; do
    if [ "${FIRST}" = true ]; then
        STAR_TREE="${STAR_TREE}${taxon}:0.1"
        FIRST=false
    else
        STAR_TREE="${STAR_TREE},${taxon}:0.1"
    fi
done < "${TEST_DIR}/test_genomes_sorted.txt"
STAR_TREE="${STAR_TREE});"

echo ""
echo "  Test tree: ${STAR_TREE}"

# Write test seqFile
echo "${STAR_TREE}" > "${TEST_SEQFILE}"
while read size taxon path; do
    echo "${taxon} ${path}" >> "${TEST_SEQFILE}"
done < "${TEST_DIR}/test_genomes_sorted.txt"

echo "  Test seqFile: ${TEST_SEQFILE}"
echo ""
echo "  Contents:"
cat "${TEST_SEQFILE}" | sed 's/^/    /'
echo ""

# ============================================================================
# RUN CACTUS
# ============================================================================

echo "[3/5] Running ProgressiveCactus alignment..."
echo "  jobStore: ${TEST_JOBSTORE}"
echo "  seqFile:  ${TEST_SEQFILE}"
echo "  output:   ${TEST_HAL}"
echo ""

# Modern Cactus v2.x CLI:
#   cactus <jobStore> <seqFile> <outputHal> [options]
#
# Key options:
#   --maxCores N      : limit parallel threads (match SLURM allocation)
#   --maxMemory NM    : limit memory (M=megabytes, G=gigabytes)
#   --binariesMode local : don't try to use Docker/Singularity internally
#   --restart         : resume from existing jobStore (omit for fresh start)

START_TIME=$(date +%s)

${SING} cactus \
    "${TEST_JOBSTORE}" \
    "${TEST_SEQFILE}" \
    "${TEST_HAL}" \
    --maxCores ${SLURM_CPUS_PER_TASK:-48} \
    --maxMemory $(( ${SLURM_MEM_PER_NODE:-384000} * 1000000 ))  \
    --binariesMode local \
    --logLevel INFO \
    2>&1 | tee "${TEST_DIR}/cactus_test.log"

CACTUS_EXIT=${PIPESTATUS[0]}
END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
ELAPSED_MIN=$(( ELAPSED / 60 ))

echo ""
if [ ${CACTUS_EXIT} -eq 0 ]; then
    echo "  CACTUS COMPLETED SUCCESSFULLY in ${ELAPSED_MIN} minutes"
else
    echo "  CACTUS FAILED with exit code ${CACTUS_EXIT}"
    echo "  Check ${TEST_DIR}/cactus_test.log for details"
    exit 1
fi
echo ""

# ============================================================================
# VALIDATE HAL OUTPUT
# ============================================================================

echo "[4/5] Validating HAL output..."

if [ ! -f "${TEST_HAL}" ]; then
    echo "ERROR: HAL file not created"
    exit 1
fi

HAL_SIZE=$(du -h "${TEST_HAL}" | cut -f1)
echo "  HAL file: ${TEST_HAL}"
echo "  Size: ${HAL_SIZE}"
echo ""

echo "  halStats output:"
${SING} halStats "${TEST_HAL}" 2>&1 | tee "${TEST_DIR}/halstats_test.txt" | sed 's/^/    /'

echo ""
echo "  HAL validation: PASS"
echo ""

# ============================================================================
# RESOURCE USAGE SUMMARY
# ============================================================================

echo "[5/5] Resource usage summary..."
echo ""

# SLURM accounting (if available)
if command -v sacct &>/dev/null; then
    echo "  SLURM job statistics:"
    sacct -j ${SLURM_JOB_ID:-0} --format=JobID,Elapsed,MaxRSS,MaxVMSize,CPUTime 2>/dev/null | sed 's/^/    /' || true
fi

echo ""

# ============================================================================
# VALIDATION REPORT
# ============================================================================

cat > "${TEST_DIR}/test_validation_report.txt" <<REPORT
SCARAB — Test Alignment Validation Report
==========================================
Date:        $(date)
Job ID:      ${SLURM_JOB_ID:-local}
Node:        $(hostname)

TEST CONFIGURATION:
  Genomes:       ${TEST_COUNT}
  CPUs:          ${SLURM_CPUS_PER_TASK:-48}
  Memory:        ${SLURM_MEM_PER_NODE:-384000} MB
  Wall-time:     ${ELAPSED_MIN} minutes
  Cactus ver:    $(${SING} cactus --version 2>&1)

RESULTS:
  Container test:      PASS
  seqFile generation:  PASS
  Cactus alignment:    PASS (exit code ${CACTUS_EXIT})
  HAL file created:    PASS (${HAL_SIZE})
  halStats validation: PASS

RESOURCE EXTRAPOLATION:
  Test: ${TEST_COUNT} genomes in ${ELAPSED_MIN} min
  Full: ~439 genomes
  Estimated full alignment: Scale depends heavily on genome sizes and
  phylogenetic distance. Use cactus-prepare decomposition for production.
  Expected: 3-7 days on single node; faster with multi-node decomposition.

FILES:
  HAL output:  ${TEST_HAL}
  halStats:    ${TEST_DIR}/halstats_test.txt
  Cactus log:  ${TEST_DIR}/cactus_test.log
  This report: ${TEST_DIR}/test_validation_report.txt

NEXT STEPS:
  1. Review this report and halStats output
  2. If satisfied, proceed to full alignment:
     a. Run setup_grace.sh (if not already done)
     b. Review cactus-prepare output in prepared/steps.sh
     c. Submit: bash submit_prepared.sh
REPORT

echo "  Validation report: ${TEST_DIR}/test_validation_report.txt"
echo ""

# ============================================================================
# DONE
# ============================================================================

echo "============================================================"
echo "Test Alignment Complete!"
echo "============================================================"
echo ""
echo "  Runtime: ${ELAPSED_MIN} minutes"
echo "  HAL:     ${TEST_HAL} (${HAL_SIZE})"
echo "  Report:  ${TEST_DIR}/test_validation_report.txt"
echo ""
echo "Finished: $(date)"
