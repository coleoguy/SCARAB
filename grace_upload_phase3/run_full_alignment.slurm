#!/bin/bash
# ============================================================================
# run_full_alignment.slurm — Full Cactus alignment, restart-safe
# ============================================================================
#
# Strategy: bigmem node, 18-day wall time, automatic restart support.
# The total alignment needs ~75 days at 80 cores. Submit 4-5 consecutive
# runs; each resumes from the Toil jobstore automatically.
#
# RESTART PROCEDURE (when job ends or is killed):
#   squeue -u $USER                        # confirm it ended
#   sbatch run_full_alignment.slurm        # resubmit — auto-resumes
#
# For convenience, use the watchdog (runs in a tmux session on the login node):
#   tmux new -s cactus_watch
#   bash cactus_watchdog.sh
#
# Resource estimate: ~144,000 SUs total across all restart cycles
# Per-cycle cost:    ~18 days x 80 cores = ~34,560 SUs per submission
# Expected cycles:   4-5 (depending on actual runtime)
#
# Queue: xlong (21 day limit) — using 18 days to allow clean SIGTERM landing
# Resources: 1 bigmem node (80 cores, 3 TB RAM)
# ============================================================================

#SBATCH --job-name=scarab_cactus
#SBATCH --partition=xlong
#SBATCH --time=18-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --mem=2900G
#SBATCH --output=%x_%j.log
#SBATCH --error=%x_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com
#SBATCH --signal=SIGTERM@3600

# SIGTERM will be sent 1 hour before wall time.
# This gives Toil time to checkpoint and exit cleanly.
# The jobstore will be intact for the next restart.

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
CONTAINER="${PROJECT_DIR}/cactus_v2.9.3.sif"
SEQFILE="${PROJECT_DIR}/cactus_seqfile_filtered.txt"   # use filtered seqfile
JOBSTORE="${PROJECT_DIR}/work/full_jobstore"
OUTPUT_HAL="${PROJECT_DIR}/hal_files/scarab.hal"
WORK_DIR="${PROJECT_DIR}/work/cactus_tmp"
LOG_DIR="${PROJECT_DIR}/work/logs"

SING="singularity exec --cleanenv \
  -B ${PROJECT_DIR}:${PROJECT_DIR} \
  -B /tmp:/tmp \
  ${CONTAINER}"

CORES="${SLURM_CPUS_PER_TASK:-80}"
MEM_MB="${SLURM_MEM_PER_NODE:-2900000}"

# ============================================================================
# SETUP
# ============================================================================

echo "============================================================"
echo "SCARAB Full Cactus Alignment"
echo "Job ID:   ${SLURM_JOB_ID:-local}"
echo "Node:     $(hostname)"
echo "Started:  $(date)"
echo "Cores:    ${CORES}"
echo "Mem:      ${MEM_MB} MB"
echo "SeqFile:  ${SEQFILE}"
echo "Jobstore: ${JOBSTORE}"
echo "HAL:      ${OUTPUT_HAL}"
echo "============================================================"
echo ""

mkdir -p "${WORK_DIR}" "${LOG_DIR}" "$(dirname ${OUTPUT_HAL})"

# Validate seqfile
if [ ! -f "${SEQFILE}" ]; then
  echo "ERROR: Seqfile not found: ${SEQFILE}"
  echo "Run filter_genomes_for_alignment.R first, then:"
  echo "  cp cactus_seqfile_filtered.txt \$SCRATCH/scarab/"
  exit 1
fi

NGENOMES=$(tail -n +2 "${SEQFILE}" | grep -c . || true)
echo "Genomes in seqfile: ${NGENOMES}"
if [ "${NGENOMES}" -lt 350 ]; then
  echo "ERROR: Expected 350-439 genomes, found ${NGENOMES}. Check seqfile."
  exit 1
fi

# Validate container
if [ ! -f "${CONTAINER}" ]; then
  echo "ERROR: Container not found: ${CONTAINER}"
  exit 1
fi

# ============================================================================
# JOBSTORE VALIDATION AND RESUME DETECTION
# ============================================================================

RESUME_FLAG=""

if [ -d "${JOBSTORE}" ]; then
  echo "Found existing jobstore — checking integrity..."

  # Check that the jobstore contains required HDF5 files
  # Toil jobstore must have a jobStoreVersion file to be valid
  if ls "${JOBSTORE}"/jobStoreVersion* > /dev/null 2>&1 || \
     ls "${JOBSTORE}"/*.db > /dev/null 2>&1 || \
     [ -f "${JOBSTORE}/config" ]; then
    echo "  Jobstore appears intact. Will RESUME."
    RESUME_FLAG="--restart"
  else
    echo "  WARNING: Jobstore exists but may be incomplete."
    echo "  Contents: $(ls ${JOBSTORE} 2>/dev/null | head -5)"
    echo "  Will attempt resume anyway (--restart). If this fails,"
    echo "  delete the jobstore and resubmit for a fresh start:"
    echo "    rm -rf ${JOBSTORE} && sbatch run_full_alignment.slurm"
    RESUME_FLAG="--restart"
  fi

  # Check HAL file status
  if [ -f "${OUTPUT_HAL}" ]; then
    HAL_SIZE_GB=$(( $(stat --printf='%s' "${OUTPUT_HAL}") / 1073741824 ))
    echo "  HAL file exists: ${HAL_SIZE_GB} GB (progress so far)"
  else
    echo "  HAL file does not yet exist (will be created)"
  fi
else
  echo "No existing jobstore — starting FRESH alignment."
  RESUME_FLAG=""
fi

echo ""

# ============================================================================
# SIGTERM HANDLER
# ============================================================================
# When SLURM sends SIGTERM (1 hour before wall time), set a flag.
# Cactus/Toil catches SIGTERM internally and attempts a clean shutdown,
# writing completed tasks to the jobstore before exiting.
# We just need to NOT kill the process ourselves.

SIGTERM_RECEIVED=0
handle_sigterm() {
  echo ""
  echo "============================================================"
  echo "SIGTERM received at $(date)"
  echo "Wall time approaching. Toil will checkpoint and exit cleanly."
  echo "Resubmit this script to resume: sbatch run_full_alignment.slurm"
  echo "============================================================"
  SIGTERM_RECEIVED=1
  # Do NOT kill Cactus here — let Toil handle it
}
trap handle_sigterm SIGTERM

# ============================================================================
# RUN CACTUS
# ============================================================================

echo "Launching Cactus at $(date)..."
echo ""

${SING} cactus \
    "${JOBSTORE}" \
    "${SEQFILE}" \
    "${OUTPUT_HAL}" \
    --maxCores    "${CORES}" \
    --maxMemory   "${MEM_MB}M" \
    --defaultMemory 16G \
    --defaultCores  8 \
    --maxDisk     3000G \
    --workDir     "${WORK_DIR}" \
    --retryCount  3 \
    --disableCaching \
    --binariesMode local \
    ${RESUME_FLAG} \
    2>&1
CACTUS_EXIT=$?

echo ""
echo "Cactus exited with code: ${CACTUS_EXIT} at $(date)"
echo ""

# ============================================================================
# POST-RUN ASSESSMENT
# ============================================================================

if [ $CACTUS_EXIT -eq 0 ]; then
  # Alignment completed successfully
  echo "============================================================"
  echo "ALIGNMENT COMPLETE"
  echo "============================================================"
  echo ""

  if [ -f "${OUTPUT_HAL}" ]; then
    HAL_SIZE=$(stat --printf='%s' "${OUTPUT_HAL}")
    echo "HAL file: ${OUTPUT_HAL}"
    echo "Size: $((HAL_SIZE / 1073741824)) GB ($((HAL_SIZE / 1048576)) MB)"
    echo ""
    echo "halStats summary:"
    ${SING} halStats "${OUTPUT_HAL}" 2>&1 || echo "WARNING: halStats failed"
  else
    echo "ERROR: HAL file missing after successful exit!"
    exit 1
  fi

  # Record completion
  echo "ALIGNMENT_COMPLETE $(date)" >> "${LOG_DIR}/alignment_status.log"

  echo ""
  echo "NEXT STEPS:"
  echo "  1. Review halStats output above (quality gate)"
  echo "  2. Back up the HAL file — it is expensive to recreate"
  echo "  3. Submit: sbatch extract_synteny.slurm"
  echo ""

elif [ $SIGTERM_RECEIVED -eq 1 ]; then
  # Wall-time kill — expected, not an error
  echo "Job ended due to wall time limit. This is normal."
  echo ""
  echo "Cycle completed. Resubmit to continue:"
  echo "  sbatch run_full_alignment.slurm"
  echo ""
  echo "The jobstore at ${JOBSTORE} preserves all completed work."
  echo "Record this cycle:"
  echo "  CYCLE_END $(date) job=${SLURM_JOB_ID}" >> "${LOG_DIR}/alignment_status.log"
  exit 0

else
  # Actual failure
  echo "============================================================"
  echo "CACTUS FAILED (exit code ${CACTUS_EXIT})"
  echo "============================================================"
  echo ""
  echo "Diagnose before resubmitting:"
  echo "  1. Check this log for the error above"
  echo "  2. Check: ${JOBSTORE}"
  echo "  3. If OOM: check MaxRSS with sacct -j ${SLURM_JOB_ID}"
  echo "  4. If jobstore corrupt: rm -rf ${JOBSTORE} to force fresh start"
  echo ""
  echo "If the failure is transient (OOM on one task, I/O error):"
  echo "  sbatch run_full_alignment.slurm   (--restart auto-applied)"
  echo ""
  echo "  CYCLE_FAIL $(date) job=${SLURM_JOB_ID} exit=${CACTUS_EXIT}" >> "${LOG_DIR}/alignment_status.log"
  exit 1
fi
