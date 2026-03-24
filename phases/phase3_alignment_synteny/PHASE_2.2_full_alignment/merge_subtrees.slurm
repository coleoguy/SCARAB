#!/bin/bash
##############################################################################
# PHASE_2.2_full_alignment/merge_subtrees.slurm
#
# Purpose:
#   Merge all subtree and backbone HAL alignments into a single final HAL file
#   Uses halAppendSubtree to hierarchically merge alignments
#   Validates output with halValidate and halStats
#
# Queue:  medium (1 day limit, 128 nodes available)
# Nodes:  1 (single standard node: 48 cores, 384 GB RAM)
# Runtime: Typically 2-6 hours depending on number of subtrees
#
# Submission:
#   sbatch merge_subtrees.slurm
#
# Note:
#   This job should run AFTER backbone alignment completes
#   When using submit_all.sh, proper dependencies are set automatically
#
# Monitoring:
#   squeue -u $USER
#   tail -f merge_subtrees_%j.log
##############################################################################

#SBATCH --job-name=scarab_merge
#SBATCH --partition=medium
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=48
#SBATCH --cpus-per-task=1
#SBATCH --mem=384G
#SBATCH --output=merge_subtrees_%j.log
#SBATCH --error=merge_subtrees_%j.err

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
HAL_DIR="${PROJECT_DIR}/hal_files"
BACKBONE_HAL="${HAL_DIR}/backbone.hal"
FINAL_HAL="${PROJECT_DIR}/results/scarab_final.hal"
WORK_DIR="${PROJECT_DIR}/work/merge"

# Create working directories
mkdir -p "${WORK_DIR}"
mkdir -p "${PROJECT_DIR}/results"

echo "============================================================"
echo "Coleoptera HAL Subtree Merger"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Started: $(date)"
echo "============================================================"
echo ""
echo "Configuration:"
echo "  Nodes:        ${SLURM_NNODES}"
echo "  CPUs:         $(( SLURM_NNODES * SLURM_CPUS_ON_NODE ))"
echo "  Memory:       ${SLURM_MEM_PER_NODE} MB"
echo "  Queue:        ${SLURM_QUEUE}"
echo ""
echo "Paths:"
echo "  Container:    ${CONTAINER}"
echo "  Backbone HAL: ${BACKBONE_HAL}"
echo "  Final HAL:    ${FINAL_HAL}"
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

if [ ! -f "${BACKBONE_HAL}" ]; then
  echo "ERROR: Backbone HAL not found at ${BACKBONE_HAL}"
  exit 1
fi

echo "  ✓ Backbone HAL exists: $(du -h "${BACKBONE_HAL}" | cut -f1)"
echo ""

# ============================================================================
# Count subtrees and verify all HAL files exist
# ============================================================================
echo "[$(date)] Checking for subtree HAL files..."

# Count seqFile entries to determine number of subtrees
SEQFILE_PATH="${SPLIT_TREE_DIR}/backbone.seqfile"
if [ ! -f "${SEQFILE_PATH}" ]; then
  echo "ERROR: backbone.seqfile not found"
  exit 1
fi

SUBTREE_COUNT=$(grep '^subtree_' "${SEQFILE_PATH}" 2>/dev/null | wc -l || echo 0)
echo "  Expected subtrees: ${SUBTREE_COUNT}"

# Verify all subtree HAL files exist
for i in $(seq 1 ${SUBTREE_COUNT}); do
  SUBTREE_HAL="${HAL_DIR}/subtree_${i}.hal"
  if [ ! -f "${SUBTREE_HAL}" ]; then
    echo "  ✗ ERROR: Subtree ${i} HAL not found: ${SUBTREE_HAL}"
    exit 1
  fi
  echo "  ✓ subtree_${i}.hal ($(du -h "${SUBTREE_HAL}" | cut -f1))"
done

echo ""

# ============================================================================
# Copy backbone HAL to working directory (for safety)
# ============================================================================
echo "[$(date)] Preparing for merge..."

WORKING_HAL="${WORK_DIR}/working.hal"
cp "${BACKBONE_HAL}" "${WORKING_HAL}"
echo "  ✓ Copied backbone to working directory"
echo ""

# ============================================================================
# Merge subtrees into backbone using halAppendSubtree
# ============================================================================
echo "[$(date)] Merging subtrees..."
echo ""

MERGE_LOG="${WORK_DIR}/merge.log"

for i in $(seq 1 ${SUBTREE_COUNT}); do
  SUBTREE_HAL="${HAL_DIR}/subtree_${i}.hal"
  SUBTREE_NAME="subtree_${i}"

  echo "  Merging ${SUBTREE_NAME}..."

  ## <<<STUDENT: halAppendSubtree merges a pre-aligned subtree into a parent HAL>>>
  ## Syntax: halAppendSubtree parentHAL subtreeHAL subtreeNodeName
  ## The subtreeNodeName should match the placeholder in the backbone tree

  if singularity exec \
    -B "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER}" \
    halAppendSubtree \
    "${WORKING_HAL}" \
    "${SUBTREE_HAL}" \
    "${SUBTREE_NAME}" \
    2>&1 | tee -a "${MERGE_LOG}"; then
    echo "    ✓ ${SUBTREE_NAME} merged successfully"
  else
    echo "    ✗ ERROR: Failed to merge ${SUBTREE_NAME}"
    exit 1
  fi
done

echo ""
echo "[$(date)] ✓ All subtrees merged successfully"
echo ""

# ============================================================================
# Copy final HAL to results directory
# ============================================================================
echo "[$(date)] Finalizing output..."

cp "${WORKING_HAL}" "${FINAL_HAL}"
echo "  ✓ Final HAL written: ${FINAL_HAL}"
echo "  File size: $(du -h "${FINAL_HAL}" | cut -f1)"
echo ""

# ============================================================================
# Validate final HAL structure
# ============================================================================
echo "[$(date)] Validating final HAL..."
echo ""

## <<<STUDENT: halValidate checks HAL file integrity and structure>>>
echo "  Running halValidate..."
if singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  halValidate --alignmentFile "${FINAL_HAL}" 2>&1 | tee "${WORK_DIR}/validate.log"; then
  echo "  ✓ halValidate passed"
else
  echo "  ⚠ halValidate reported issues - see ${WORK_DIR}/validate.log"
fi

echo ""

# ============================================================================
# Generate alignment statistics
# ============================================================================
echo "[$(date)] Generating alignment statistics..."
echo ""

STATS_FILE="${WORK_DIR}/halstats_final.txt"

## <<<STUDENT: halStats generates comprehensive alignment summary>>>
if singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  halStats "${FINAL_HAL}" > "${STATS_FILE}"; then
  echo "  ✓ Statistics generated: ${STATS_FILE}"
  echo ""
  echo "  Summary statistics:"
  head -30 "${STATS_FILE}" | sed 's/^/    /'
else
  echo "  ✗ Failed to generate statistics"
fi

echo ""

# ============================================================================
# List all genomes in final alignment
# ============================================================================
echo "[$(date)] Listing genomes in final alignment..."
echo ""

GENOMES_FILE="${WORK_DIR}/genomes_in_alignment.txt"

## <<<STUDENT: Extract list of all genomes in the alignment>>>
if singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  halStats "${FINAL_HAL}" --printGenomes > "${GENOMES_FILE}"; then
  echo "  Genomes in alignment:"
  cat "${GENOMES_FILE}" | sed 's/^/    /'
  echo ""
  GENOME_COUNT=$(wc -l < "${GENOMES_FILE}")
  echo "  Total genomes: ${GENOME_COUNT}"
else
  echo "  ⚠ Failed to extract genome list"
fi

echo ""

# ============================================================================
# Create merge report
# ============================================================================
echo "[$(date)] Creating merge report..."

REPORT_FILE="${WORK_DIR}/merge_report.txt"

cat > "${REPORT_FILE}" <<EOF
COLEOPTERA HAL MERGER REPORT
================================================================================
Generated: $(date)
Job ID: ${SLURM_JOB_ID}

INPUTS:
  Backbone HAL:     ${BACKBONE_HAL} ($(du -h "${BACKBONE_HAL}" | cut -f1))
  Subtrees merged:  ${SUBTREE_COUNT}
  Subtree location: ${HAL_DIR}

OUTPUTS:
  Final HAL:        ${FINAL_HAL} ($(du -h "${FINAL_HAL}" | cut -f1))
  Validation log:   ${WORK_DIR}/validate.log
  Statistics:       ${STATS_FILE}
  Genomes list:     ${GENOMES_FILE}

MERGE PROCESS:
  Method:           halAppendSubtree (sequential merging)
  Merge log:        ${MERGE_LOG}
  Working dir:      ${WORK_DIR}

GENOME COUNT: ${GENOME_COUNT}

NEXT STEPS:
  1. Review halStats output for coverage and structure
  2. Back up final HAL file to long-term storage
  3. Proceed with synteny extraction (PHASE_2.3)
  4. Generate ancestral reconstructions (PHASE_2.5)
  5. Produce visualizations and manuscript figures (PHASE_4)

================================================================================
EOF

echo "  Report: ${REPORT_FILE}"
cat "${REPORT_FILE}" | sed 's/^/  /'

echo ""

# ============================================================================
# Cleanup
# ============================================================================
echo "[$(date)] Cleanup..."

## <<<STUDENT: Optionally remove working HAL and intermediate files>>>
## This saves space but may be useful for debugging
# rm "${WORKING_HAL}"

echo "  Working files retained at: ${WORK_DIR}"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "============================================================"
echo "Subtree Merging Complete!"
echo "============================================================"
echo ""
echo "Key Output:"
echo "  Final HAL:  ${FINAL_HAL}"
echo "  Size:       $(du -h "${FINAL_HAL}" | cut -f1)"
echo "  Genomes:    ${GENOME_COUNT}"
echo ""
echo "Quality Checks:"
echo "  Validation: ${WORK_DIR}/validate.log"
echo "  Statistics: ${STATS_FILE}"
echo ""
echo "Next steps:"
echo "  1. Back up final HAL to long-term storage"
echo "  2. Submit PHASE_2.3 synteny extraction job"
echo "  3. Monitor downstream analysis"
echo ""
echo "Finished: $(date)"
echo "============================================================"
