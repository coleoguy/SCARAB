#!/bin/bash
##############################################################################
# PHASE_2.2_full_alignment/submit_backbone.slurm
#
# Purpose:
#   Align the backbone tree (root nodes of all subtrees + outgroups)
#   This creates the high-level hierarchical structure for merging subtrees
#   Uses bigmem queue for memory-intensive root alignment
#
# Queue:  bigmem (2 day limit, 3 TB RAM, 80 cores per node)
# Nodes:  1 (single bigmem node)
# Runtime: Typically 4-12 hours
#
# Submission:
#   sbatch submit_backbone.slurm
#
# Note:
#   This job should run AFTER all subtree alignments complete
#   When using submit_all.sh, it is automatically submitted with
#   proper dependency constraints (--dependency=afterok:subjob1:subjob2:...)
#
# Monitoring:
#   squeue -u $USER
#   tail -f backbone_alignment_%j.log
##############################################################################

#SBATCH --job-name=scarab_backbone
#SBATCH --partition=bigmem
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=80
#SBATCH --cpus-per-task=1
#SBATCH --mem=3000G
#SBATCH --output=backbone_alignment_%j.log
#SBATCH --error=backbone_alignment_%j.err

## <<<STUDENT: Enter your TAMU NetID>>>
NETID="your_netid"

## <<<STUDENT: Enter your email for SLURM notifications (optional)>>>
EMAIL="your_email@tamu.edu"

set -euo pipefail

# Define paths
SCRATCH_ROOT="/scratch/user/${NETID}"
PROJECT_DIR="${SCRATCH_ROOT}/coleoptera"
CONTAINER="${PROJECT_DIR}/cactus_container.sif"
SPLIT_TREE_DIR="${PROJECT_DIR}/split_trees"
WORK_DIR="${PROJECT_DIR}/work/backbone"
BACKBONE_TREE="${SPLIT_TREE_DIR}/backbone.nwk"
BACKBONE_SEQFILE="${SPLIT_TREE_DIR}/backbone.seqfile"
HAL_OUTPUT="${PROJECT_DIR}/hal_files/backbone.hal"
CHECKPOINT_DIR="${WORK_DIR}/checkpoint"

# Create working directories
mkdir -p "${WORK_DIR}"
mkdir -p "${CHECKPOINT_DIR}"

echo "============================================================"
echo "Coleoptera Backbone Alignment"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Started: $(date)"
echo "============================================================"
echo ""
echo "Configuration:"
echo "  Nodes:        ${SLURM_NNODES}"
echo "  CPUs:         $(( SLURM_NNODES * SLURM_CPUS_ON_NODE ))"
echo "  Memory:       ${SLURM_MEM_PER_NODE} MB"
echo "  Queue:        ${SLURM_QUEUE}"
echo "  Max Runtime:  ${SLURM_TIME}"
echo ""
echo "Paths:"
echo "  Container:    ${CONTAINER}"
echo "  Backbone:     ${BACKBONE_TREE}"
echo "  seqFile:      ${BACKBONE_SEQFILE}"
echo "  HAL Output:   ${HAL_OUTPUT}"
echo "  Work Dir:     ${WORK_DIR}"
echo ""

# ============================================================================
# Validation
# ============================================================================
echo "[$(date)] Validating inputs..."

if [ ! -f "${CONTAINER}" ]; then
  echo "ERROR: Container not found at ${CONTAINER}"
  exit 1
fi

if [ ! -f "${BACKBONE_TREE}" ]; then
  echo "ERROR: Backbone tree not found at ${BACKBONE_TREE}"
  echo "Please ensure split_tree.R has been run successfully"
  exit 1
fi

if [ ! -f "${BACKBONE_SEQFILE}" ]; then
  echo "ERROR: Backbone seqFile not found at ${BACKBONE_SEQFILE}"
  exit 1
fi

echo "  ✓ All inputs validated"
echo ""

# ============================================================================
# Verify all subtree HAL files exist (dependencies)
# ============================================================================
echo "[$(date)] Checking subtree alignment status..."

# Read backbone seqFile to count subtree placeholders
SUBTREE_COUNT=$(grep '^subtree_' "${BACKBONE_SEQFILE}" 2>/dev/null | wc -l || echo 0)

if [ ${SUBTREE_COUNT} -gt 0 ]; then
  echo "  Expected subtree alignments: ${SUBTREE_COUNT}"

  MISSING_SUBTREES=0
  for i in $(seq 1 ${SUBTREE_COUNT}); do
    SUBTREE_HAL="${PROJECT_DIR}/hal_files/subtree_${i}.hal"
    if [ ! -f "${SUBTREE_HAL}" ]; then
      echo "  ⚠ Missing: ${SUBTREE_HAL}"
      ((MISSING_SUBTREES++))
    else
      echo "  ✓ Found: subtree_${i}.hal ($(du -h "${SUBTREE_HAL}" | cut -f1))"
    fi
  done

  if [ ${MISSING_SUBTREES} -gt 0 ]; then
    echo ""
    echo "ERROR: ${MISSING_SUBTREES} subtree alignments missing"
    echo "Please ensure all subtree jobs have completed successfully"
    exit 1
  fi
else
  echo "  ⚠ No subtree placeholders found in backbone seqFile"
  echo "  (proceeding with caution)"
fi

echo "  ✓ All subtree dependencies satisfied"
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

# Show backbone tree structure
echo "  Backbone tree structure:"
cat "${BACKBONE_TREE}" | fold -w 80 | sed 's/^/    /'

echo ""
echo "  Genomes in backbone alignment:"
head -5 "${BACKBONE_SEQFILE}" | sed 's/^/    /'
BACKBONE_COUNT=$(grep -v '^#' "${BACKBONE_SEQFILE}" | wc -l)
[ ${BACKBONE_COUNT} -gt 5 ] && echo "    ... (${BACKBONE_COUNT} total)"

echo ""

# ============================================================================
# Run cactus backbone alignment
# ============================================================================
echo "[$(date)] Starting cactus backbone alignment..."
echo ""

## <<<STUDENT: Adjust --consCores to match available cores on bigmem nodes>>>
## bigmem nodes have 80 cores; using 64-78 allows room for other processes
## --maxCores limits parallelization; set to available cores
## --workDir should point to local scratch for performance

CACTUS_OPTS="
  --batchSystem slurm
  --consCores 64
  --maxCores 78
  --logFile ${WORK_DIR}/cactus_backbone.log
  --workDir ${WORK_DIR}
  --retryCount 1
  ${CHECKPOINT_FLAG}
"

## <<<STUDENT: Uncomment to enable GPU acceleration (if available)>>>
# CACTUS_OPTS="${CACTUS_OPTS} --gpu"

if singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  cactus \
  ${CACTUS_OPTS} \
  "${BACKBONE_TREE}" \
  "${BACKBONE_SEQFILE}" \
  "${HAL_OUTPUT}"; then

  echo ""
  echo "[$(date)] ✓ Backbone alignment completed successfully"

else
  CACTUS_EXIT=$?
  echo ""
  echo "[$(date)] ✗ Alignment failed with exit code ${CACTUS_EXIT}"
  echo ""
  echo "Checkpoint files are saved at:"
  echo "  ${CHECKPOINT_DIR}"
  echo ""
  echo "To resume, resubmit this job:"
  echo "  sbatch submit_backbone.slurm"
  echo ""
  exit 1
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

  ## <<<STUDENT: Run halStats to validate backbone alignment>>>
  echo "[$(date)] Running halStats..."
  if singularity exec \
    -B "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER}" \
    halStats "${HAL_OUTPUT}" > "${WORK_DIR}/halstats_backbone.txt"; then
    echo "  ✓ halStats completed"
    echo ""
    echo "  Alignment statistics:"
    head -20 "${WORK_DIR}/halstats_backbone.txt" | sed 's/^/    /'
  else
    echo "  ⚠ halStats failed (non-fatal)"
  fi

  ## <<<STUDENT: Run halValidate to check for structural issues>>>
  echo ""
  echo "[$(date)] Running halValidate..."
  if singularity exec \
    -B "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER}" \
    halValidate --alignmentFile "${HAL_OUTPUT}"; then
    echo "  ✓ halValidate passed"
  else
    echo "  ⚠ halValidate reported issues (check logs)"
  fi

else
  echo "  ✗ ERROR: HAL file not created"
  echo "  Checkpoint files retained for debugging"
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

echo "  Work directory retained at: ${WORK_DIR}"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "============================================================"
echo "Backbone Alignment Complete"
echo "============================================================"
echo ""
echo "Output:"
echo "  HAL file:  ${HAL_OUTPUT}"
echo "  Stats:     ${WORK_DIR}/halstats_backbone.txt"
echo "  Logs:      ${WORK_DIR}/cactus_backbone.log"
echo ""
echo "Next steps:"
echo "  1. Review halStats and halValidate output"
echo "  2. Submit merge_subtrees.slurm to merge alignments"
echo ""
echo "Finished: $(date)"
echo "============================================================"
