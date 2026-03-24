#!/bin/bash
##############################################################################
# PHASE_2.2_full_alignment/submit_subtree.slurm
#
# Purpose:
#   Align a single clade subtree using Progressive Cactus
#   Supports checkpointing and restart logic
#   Can be submitted in parallel for multiple subtrees
#
# Queue:  long (7 day limit)
# Nodes:  1 (full node: 48 cores, 384 GB RAM)
# Runtime: Depends on subtree size; typically 1-4 days
#
# Usage:
#   sbatch --export=SUBTREE_NUM=1 submit_subtree.slurm
#   sbatch --export=SUBTREE_NUM=2 submit_subtree.slurm
#   ... (submit for each subtree in parallel)
#
# Submission script (submit_all.sh will do this automatically):
#   for i in {1..5}; do
#     sbatch --export=SUBTREE_NUM=$i submit_subtree.slurm
#   done
#
# Monitoring:
#   squeue -u $USER
#   tail -f subtree_${SUBTREE_NUM}_alignment_%j.log
#
# Checkpointing:
#   If job times out, resubmit with same SUBTREE_NUM
#   Cactus will resume from checkpoint automatically
##############################################################################

#SBATCH --job-name=scarab_subtree
#SBATCH --partition=long
#SBATCH --time=7-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=48
#SBATCH --cpus-per-task=1
#SBATCH --mem=384G
#SBATCH --output=subtree_%a_alignment_%j.log
#SBATCH --error=subtree_%a_alignment_%j.err
#SBATCH --open-mode=append

## <<<STUDENT: Enter your TAMU NetID>>>
NETID="your_netid"

## <<<STUDENT: Enter your email for SLURM notifications (optional)>>>
EMAIL="your_email@tamu.edu"

## <<<STUDENT: Subtree number - set via --export=SUBTREE_NUM=N>>>
## or use SLURM_ARRAY_TASK_ID if running as array job
SUBTREE_NUM=${SUBTREE_NUM:-${SLURM_ARRAY_TASK_ID:-1}}

set -euo pipefail

# Define paths
SCRATCH_ROOT="/scratch/user/${NETID}"
PROJECT_DIR="${SCRATCH_ROOT}/coleoptera"
CONTAINER="${PROJECT_DIR}/cactus_container.sif"
SPLIT_TREE_DIR="${PROJECT_DIR}/split_trees"
WORK_DIR="${PROJECT_DIR}/work/subtree_${SUBTREE_NUM}"
SUBTREE_FILE="${SPLIT_TREE_DIR}/subtree_${SUBTREE_NUM}.nwk"
SEQFILE="${SPLIT_TREE_DIR}/subtree_${SUBTREE_NUM}.seqfile"
HAL_OUTPUT="${PROJECT_DIR}/hal_files/subtree_${SUBTREE_NUM}.hal"
CHECKPOINT_DIR="${WORK_DIR}/checkpoint"

# Create working directories
mkdir -p "${WORK_DIR}"
mkdir -p "${CHECKPOINT_DIR}"
mkdir -p "${PROJECT_DIR}/hal_files"

echo "============================================================"
echo "Coleoptera Subtree Alignment - Subtree ${SUBTREE_NUM}"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Started: $(date)"
echo "============================================================"
echo ""
echo "Configuration:"
echo "  Subtree Num:  ${SUBTREE_NUM}"
echo "  Nodes:        ${SLURM_NNODES}"
echo "  CPUs:         $(( SLURM_NNODES * SLURM_CPUS_ON_NODE ))"
echo "  Memory:       ${SLURM_MEM_PER_NODE} MB"
echo "  Queue:        ${SLURM_QUEUE}"
echo "  Max Runtime:  ${SLURM_TIME}"
echo ""
echo "Paths:"
echo "  Container:    ${CONTAINER}"
echo "  Subtree:      ${SUBTREE_FILE}"
echo "  seqFile:      ${SEQFILE}"
echo "  HAL Output:   ${HAL_OUTPUT}"
echo "  Work Dir:     ${WORK_DIR}"
echo "  Checkpoints:  ${CHECKPOINT_DIR}"
echo ""

# ============================================================================
# Validation
# ============================================================================
echo "[$(date)] Validating inputs..."

if [ ! -f "${CONTAINER}" ]; then
  echo "ERROR: Container not found at ${CONTAINER}"
  exit 1
fi

if [ ! -f "${SUBTREE_FILE}" ]; then
  echo "ERROR: Subtree file not found at ${SUBTREE_FILE}"
  exit 1
fi

if [ ! -f "${SEQFILE}" ]; then
  echo "ERROR: seqFile not found at ${SEQFILE}"
  exit 1
fi

echo "  ✓ All inputs validated"
echo ""

# ============================================================================
# Check for existing checkpoint (resume mode)
# ============================================================================
echo "[$(date)] Checking for checkpoint..."

CHECKPOINT_FLAG=""
if [ -d "${CHECKPOINT_DIR}" ] && [ -f "${CHECKPOINT_DIR}/jobStateFile" ]; then
  echo "  ✓ Found checkpoint; will resume alignment"
  CHECKPOINT_FLAG="--checkpoint ${CHECKPOINT_DIR}"
else
  echo "  No checkpoint found; starting fresh alignment"
fi
echo ""

# ============================================================================
# Pre-alignment checks
# ============================================================================
echo "[$(date)] Pre-alignment checks..."

# Count genomes in seqFile
GENOME_COUNT=$(grep -v '^#' "${SEQFILE}" | wc -l)
echo "  Genomes in subtree: ${GENOME_COUNT}"

# Show first few genomes
echo "  Sample genomes:"
head -3 "${SEQFILE}" | sed 's/^/    /'
[ $(grep -v '^#' "${SEQFILE}" | wc -l) -gt 3 ] && echo "    ... (${GENOME_COUNT} total)"

echo ""

# ============================================================================
# Run cactus alignment
# ============================================================================
echo "[$(date)] Starting cactus alignment for subtree ${SUBTREE_NUM}..."
echo ""

## <<<STUDENT: Adjust --consCores to match your allocation>>>
## --consCores 48 means use 48 cores for consensus calls
## --batchSystem slurm allows Cactus to submit SLURM jobs for its own parallelization
## --logFile captures detailed Cactus logs
## --workDir stores intermediate files

CACTUS_OPTS="
  --batchSystem slurm
  --consCores 48
  --maxCores 48
  --logFile ${WORK_DIR}/cactus_${SUBTREE_NUM}.log
  --workDir ${WORK_DIR}
  --retryCount 1
  ${CHECKPOINT_FLAG}
"

## <<<STUDENT: Uncomment to enable GPU acceleration for lastz (if available)>>>
# CACTUS_OPTS="${CACTUS_OPTS} --gpu"

if singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  cactus \
  ${CACTUS_OPTS} \
  "${SUBTREE_FILE}" \
  "${SEQFILE}" \
  "${HAL_OUTPUT}"; then

  echo ""
  echo "[$(date)] ✓ Alignment completed successfully"

else
  CACTUS_EXIT=$?
  echo ""
  echo "[$(date)] ✗ Alignment failed with exit code ${CACTUS_EXIT}"
  echo ""
  echo "Checkpoint files are saved at:"
  echo "  ${CHECKPOINT_DIR}"
  echo ""
  echo "To resume, resubmit this job:"
  echo "  sbatch --export=SUBTREE_NUM=${SUBTREE_NUM} submit_subtree.slurm"
  echo ""

  # Don't exit; continue to post-alignment checks
fi

# ============================================================================
# Post-alignment validation
# ============================================================================
echo ""
echo "[$(date)] Post-alignment validation..."

if [ -f "${HAL_OUTPUT}" ]; then
  echo "  ✓ HAL file created: ${HAL_OUTPUT}"
  echo "  File size: $(du -h "${HAL_OUTPUT}" | cut -f1)"
  echo ""

  ## <<<STUDENT: Run halStats to validate alignment>>>
  echo "[$(date)] Running halStats..."
  if singularity exec \
    -B "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER}" \
    halStats "${HAL_OUTPUT}" > "${WORK_DIR}/halstats_${SUBTREE_NUM}.txt"; then
    echo "  ✓ halStats completed"
    echo ""
    echo "  Alignment statistics:"
    head -20 "${WORK_DIR}/halstats_${SUBTREE_NUM}.txt" | sed 's/^/    /'
  else
    echo "  ⚠ halStats failed (non-fatal)"
  fi
else
  echo "  ✗ ERROR: HAL file not created"
  echo "  Checkpoint files retained for debugging:"
  ls -la "${CHECKPOINT_DIR}" 2>/dev/null || echo "  (no checkpoint files)"
  exit 1
fi

# ============================================================================
# Cleanup
# ============================================================================
echo ""
echo "[$(date)] Cleanup..."

## <<<STUDENT: Optionally remove checkpoint dir if alignment succeeded>>>
## This saves disk space but prevents resumption
# rm -rf "${CHECKPOINT_DIR}"

## <<<STUDENT: Optionally remove intermediate work files>>>
# rm -f "${WORK_DIR}"/*.tmp

echo "  Work directory retained at: ${WORK_DIR}"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "============================================================"
echo "Subtree ${SUBTREE_NUM} Alignment Complete"
echo "============================================================"
echo ""
echo "Output:"
echo "  HAL file:  ${HAL_OUTPUT}"
echo "  Stats:     ${WORK_DIR}/halstats_${SUBTREE_NUM}.txt"
echo "  Logs:      ${WORK_DIR}/cactus_${SUBTREE_NUM}.log"
echo ""
echo "Next steps:"
echo "  1. Review halStats output for alignment quality"
echo "  2. Once all subtrees complete, submit merge_subtrees.slurm"
echo ""
echo "Finished: $(date)"
echo "============================================================"
