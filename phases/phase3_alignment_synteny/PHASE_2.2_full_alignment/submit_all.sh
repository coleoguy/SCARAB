#!/bin/bash
##############################################################################
# PHASE_2.2_full_alignment/submit_all.sh
#
# Purpose:
#   Master submission script for the entire Coleoptera alignment pipeline
#   Submits all subtree jobs in parallel
#   Chains backbone and merge jobs with proper dependency ordering
#   Uses SLURM --dependency flag to manage job dependencies
#
# Workflow:
#   1. Submit all subtree jobs in parallel (captures job IDs)
#   2. Submit backbone job with dependency on all subtree jobs
#   3. Submit merge job with dependency on backbone job
#
# Usage:
#   bash submit_all.sh
#
# Configuration:
#   Edit NUM_SUBTREES below to match your tree decomposition
#   Edit NETID to match your TAMU username
#
# Output:
#   - Prints job IDs for monitoring
#   - Creates submission_log.txt with all job IDs and timeline
#
# Monitoring:
#   squeue -u $USER
#   watch 'squeue -u $USER | grep coleoptera'
##############################################################################

set -euo pipefail

## <<<STUDENT: Enter your TAMU NetID>>>
NETID="your_netid"

## <<<STUDENT: Number of subtrees from your tree decomposition>>>
NUM_SUBTREES=5

## <<<STUDENT: Path to split_tree output directory>>>
SPLIT_TREE_DIR="/scratch/user/${NETID}/scarab/split_trees"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo "Coleoptera Alignment - Master Submission Script"
echo "============================================================"
echo ""
echo "Configuration:"
echo "  NetID:          ${NETID}"
echo "  Num Subtrees:   ${NUM_SUBTREES}"
echo "  Script Dir:     ${SCRIPT_DIR}"
echo "  Split Tree Dir: ${SPLIT_TREE_DIR}"
echo ""
echo "Started: $(date)"
echo ""

# Verify split tree directory exists
if [ ! -d "${SPLIT_TREE_DIR}" ]; then
  echo "ERROR: Split tree directory not found: ${SPLIT_TREE_DIR}"
  echo "Please run split_tree.R first"
  exit 1
fi

echo "[$(date)] Verifying split tree files..."
for i in $(seq 1 ${NUM_SUBTREES}); do
  if [ ! -f "${SPLIT_TREE_DIR}/subtree_${i}.nwk" ]; then
    echo "ERROR: Missing subtree file: subtree_${i}.nwk"
    exit 1
  fi
done

if [ ! -f "${SPLIT_TREE_DIR}/backbone.nwk" ]; then
  echo "ERROR: Missing backbone.nwk"
  exit 1
fi

echo "✓ All required files present"
echo ""

# ============================================================================
# Phase 1: Submit subtree alignment jobs in parallel
# ============================================================================
echo "============================================================"
echo "PHASE 1: Submitting subtree alignment jobs (in parallel)"
echo "============================================================"
echo ""

SUBTREE_JOB_IDS=()

for i in $(seq 1 ${NUM_SUBTREES}); do
  echo "[$(date)] Submitting subtree ${i}..."

  ## <<<STUDENT: Adjust sbatch command as needed (queue, resources, etc.)>>>
  JOB_ID=$(sbatch \
    --export=SUBTREE_NUM=${i} \
    --parsable \
    "${SCRIPT_DIR}/submit_subtree.slurm")

  SUBTREE_JOB_IDS+=("${JOB_ID}")
  echo "  ✓ Job ID: ${JOB_ID}"
done

echo ""
echo "Submitted subtree jobs: ${SUBTREE_JOB_IDS[@]}"
echo ""

# ============================================================================
# Phase 2: Submit backbone job with dependency on all subtree jobs
# ============================================================================
echo "============================================================"
echo "PHASE 2: Submitting backbone alignment job"
echo "============================================================"
echo ""

## Build dependency string from all subtree job IDs
## Format: --dependency=afterok:JOBID1:JOBID2:JOBID3...
DEPENDENCY_STRING="afterok:$(printf '%s:' "${SUBTREE_JOB_IDS[@]}" | sed 's/:$//')"

echo "[$(date)] Submitting backbone job..."
echo "  Dependency: ${DEPENDENCY_STRING}"

## <<<STUDENT: Adjust sbatch command as needed>>>
BACKBONE_JOB_ID=$(sbatch \
  --dependency="${DEPENDENCY_STRING}" \
  --parsable \
  "${SCRIPT_DIR}/submit_backbone.slurm")

echo "  ✓ Job ID: ${BACKBONE_JOB_ID}"
echo ""

# ============================================================================
# Phase 3: Submit merge job with dependency on backbone
# ============================================================================
echo "============================================================"
echo "PHASE 3: Submitting merge job"
echo "============================================================"
echo ""

echo "[$(date)] Submitting merge job..."
echo "  Dependency: afterok:${BACKBONE_JOB_ID}"

## <<<STUDENT: Adjust sbatch command as needed>>>
MERGE_JOB_ID=$(sbatch \
  --dependency="afterok:${BACKBONE_JOB_ID}" \
  --parsable \
  "${SCRIPT_DIR}/merge_subtrees.slurm")

echo "  ✓ Job ID: ${MERGE_JOB_ID}"
echo ""

# ============================================================================
# Summary and logging
# ============================================================================
echo "============================================================"
echo "Job Submission Complete!"
echo "============================================================"
echo ""

LOG_FILE="submission_log_$(date +%Y%m%d_%H%M%S).txt"

cat > "${LOG_FILE}" <<EOF
COLEOPTERA ALIGNMENT SUBMISSION LOG
================================================================================
Submitted: $(date)
NetID: ${NETID}
Script: ${SCRIPT_DIR}/submit_all.sh

CONFIGURATION:
  Number of subtrees:  ${NUM_SUBTREES}
  Split tree dir:      ${SPLIT_TREE_DIR}

SUBMITTED JOBS:
================================================================================

SUBTREE ALIGNMENT JOBS (Parallel):
  Queue:      long (7 days)
  Resources:  48 cores, 384 GB RAM per node

EOF

for i in "${!SUBTREE_JOB_IDS[@]}"; do
  JOB_NUM=$((i + 1))
  echo "  Subtree ${JOB_NUM}: ${SUBTREE_JOB_IDS[$i]}" >> "${LOG_FILE}"
done

cat >> "${LOG_FILE}" <<EOF

BACKBONE ALIGNMENT JOB:
  Queue:      bigmem (2 days)
  Resources:  80 cores, 3 TB RAM
  Job ID:     ${BACKBONE_JOB_ID}
  Depends on: All subtree jobs (afterok:${SUBTREE_JOB_IDS[*]})

MERGE JOB:
  Queue:      medium (1 day)
  Resources:  48 cores, 384 GB RAM
  Job ID:     ${MERGE_JOB_ID}
  Depends on: Backbone job (${BACKBONE_JOB_ID})

EXPECTED TIMELINE:
  T+0:    Subtree jobs start immediately
  T+1-4d: Subtree jobs complete (dependent on genome counts)
  T+4-5d: Backbone job starts (upon subtree completion)
  T+5-6d: Backbone job completes
  T+6-7d: Merge job starts (upon backbone completion)
  T+7d:   Final HAL ready

MONITORING:
  View job status:  squeue -u ${NETID}
  Watch progress:   watch 'squeue -u ${NETID} | grep coleoptera'
  Check subtree:    tail -f subtree_N_alignment_*.log
  Check backbone:   tail -f backbone_alignment_*.log
  Check merge:      tail -f merge_subtrees_*.log

OUTPUT FILES:
  Final HAL:        /scratch/user/${NETID}/scarab/results/coleoptera_final.hal
  Statistics:       /scratch/user/${NETID}/scarab/work/merge/halstats_final.txt
  Validation log:   /scratch/user/${NETID}/scarab/work/merge/validate.log

TROUBLESHOOTING:
  1. If a subtree job fails, resubmit it individually:
     sbatch --export=SUBTREE_NUM=N submit_subtree.slurm
     (Cactus will resume from checkpoint)

  2. If backbone job fails:
     sbatch --dependency=afterok:${BACKBONE_JOB_ID} submit_backbone.slurm

  3. If merge job fails:
     sbatch --dependency=afterok:${BACKBONE_JOB_ID} merge_subtrees.slurm

NEXT PHASES:
  After merge completes successfully:
    1. Submit PHASE_2.3: Synteny extraction (extract_synteny.slurm)
    2. Submit PHASE_2.4: Synteny QC (run synteny_qc.R)
    3. Submit PHASE_2.5: Ancestral reconstruction (run_raca.slurm)
    4. Submit PHASE_2.6: Synteny anchoring (anchor_synteny.R)
    5. Submit PHASE_2.7: Integration report (integration_report.R)

================================================================================
EOF

echo "Job Summary:"
echo "============================================================"
echo ""
echo "Subtree jobs (${NUM_SUBTREES} parallel):"
for i in "${!SUBTREE_JOB_IDS[@]}"; do
  JOB_NUM=$((i + 1))
  echo "  ${JOB_NUM}. ${SUBTREE_JOB_IDS[$i]}"
done

echo ""
echo "Backbone job:"
echo "  ${BACKBONE_JOB_ID}"
echo ""
echo "Merge job:"
echo "  ${MERGE_JOB_ID}"
echo ""

echo "Submission log: ${LOG_FILE}"
echo ""

echo "To monitor progress:"
echo "  squeue -u ${NETID}"
echo ""

echo "To view logs:"
echo "  tail -f subtree_*_alignment_*.log  (use job ID from above)"
echo "  tail -f backbone_alignment_*.log"
echo "  tail -f merge_subtrees_*.log"
echo ""

echo "============================================================"
echo "All jobs submitted! Finished: $(date)"
echo "============================================================"
