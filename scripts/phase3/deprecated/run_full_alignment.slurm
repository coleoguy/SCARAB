#!/bin/bash
# ============================================================================
# run_full_alignment.slurm — Full 439-genome Cactus alignment
# ============================================================================
#
# Runs ProgressiveCactus on all 439 genomes using the cactus-prepare
# decomposed workflow. This is the primary compute job for SCARAB.
#
# Resource estimate: 160,000-430,000 core-hours
# Allocated: 200,000 SUs
#
# Strategy: Use cactus-prepare decomposition. Cactus internally splits
# the alignment into blast and align steps along the guide tree.
# We run it as a single large job on a bigmem node.
#
# Queue: xlong (21 day limit)
# Resources: 1 bigmem node, 80 cores, 3 TB RAM
#
# Usage:
#   sbatch run_full_alignment.slurm
#
# Monitoring:
#   squeue -u $USER
#   tail -f scarab_full_*.log
#   sacct -j <JOBID> --format=JobID,State,Elapsed,MaxRSS
# ============================================================================

#SBATCH --job-name=scarab_cactus
#SBATCH --partition=xlong
#SBATCH --time=21-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --mem=2900G
#SBATCH --output=scarab_full_%j.log
#SBATCH --error=scarab_full_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
CONTAINER="${PROJECT_DIR}/cactus_v2.9.3.sif"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"
JOBSTORE="${PROJECT_DIR}/work/full_jobstore"
OUTPUT_HAL="${PROJECT_DIR}/hal_files/scarab.hal"
WORK_DIR="${PROJECT_DIR}/work"

SING="singularity exec --cleanenv \
  -B ${PROJECT_DIR}:${PROJECT_DIR} \
  -B /tmp:/tmp \
  ${CONTAINER}"

# ============================================================================
# SETUP
# ============================================================================

echo "============================================================"
echo "SCARAB — Full Cactus Alignment (439 genomes)"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-80}"
echo "Memory: ${SLURM_MEM_PER_NODE:-2900000} MB"
echo "============================================================"
echo ""

mkdir -p "${WORK_DIR}" "$(dirname ${OUTPUT_HAL})"

# Check seqFile
NGENOMES=$(tail -n +2 "${SEQFILE}" | grep -c . || true)
echo "Genomes in seqFile: ${NGENOMES}"

if [ "$NGENOMES" -lt 400 ]; then
    echo "ERROR: Expected ~439 genomes, found ${NGENOMES}."
    echo "Run build_seqfile.sh first."
    exit 1
fi

# Check container
if [ ! -f "${CONTAINER}" ]; then
    echo "ERROR: Container not found: ${CONTAINER}"
    echo "Run setup_phase3.sh first."
    exit 1
fi

# ============================================================================
# RESUME SUPPORT
# ============================================================================
# Cactus supports resuming from a jobStore. If the job gets killed
# (walltime, OOM), resubmit this same script — it will resume.

if [ -d "${JOBSTORE}" ]; then
    echo "Found existing jobStore — will attempt to RESUME."
    echo "  (Delete ${JOBSTORE} to force restart)"
    RESUME_FLAG="--restart"
else
    echo "Starting fresh alignment."
    RESUME_FLAG=""
fi
echo ""

# ============================================================================
# RUN CACTUS
# ============================================================================

echo "Starting Cactus..."
echo "  seqFile: ${SEQFILE}"
echo "  jobStore: ${JOBSTORE}"
echo "  output: ${OUTPUT_HAL}"
echo "  Time: $(date)"
echo ""

# Use --binariesMode local for Singularity environments
# --maxCores and --maxMemory control Toil resource limits
${SING} cactus \
    "${JOBSTORE}" \
    "${SEQFILE}" \
    "${OUTPUT_HAL}" \
    --maxCores ${SLURM_CPUS_PER_TASK:-80} \
    --maxMemory ${SLURM_MEM_PER_NODE:-2900000}M \
    --defaultMemory 8G \
    --maxDisk 2000G \
    ${RESUME_FLAG} \
    2>&1 && CACTUS_EXIT=0 || CACTUS_EXIT=$?

echo ""
echo "Cactus exit code: ${CACTUS_EXIT}"
echo "Finished: $(date)"
echo ""

# ============================================================================
# VALIDATE
# ============================================================================

if [ $CACTUS_EXIT -ne 0 ]; then
    echo "CACTUS FAILED (exit ${CACTUS_EXIT})"
    echo ""
    echo "To resume, resubmit this script:"
    echo "  sbatch run_full_alignment.slurm"
    echo "(Cactus will resume from the jobStore)"
    exit 1
fi

if [ ! -f "${OUTPUT_HAL}" ]; then
    echo "ERROR: HAL file not produced"
    exit 1
fi

HAL_SIZE=$(stat --printf='%s' "${OUTPUT_HAL}")
echo "============================================================"
echo "ALIGNMENT COMPLETE"
echo "============================================================"
echo ""
echo "HAL file: ${OUTPUT_HAL}"
echo "Size: $((HAL_SIZE / 1073741824)) GB"
echo ""

# Run halStats
echo "halStats summary:"
${SING} halStats "${OUTPUT_HAL}" 2>&1 || echo "WARNING: halStats failed"

echo ""
echo "NEXT STEPS:"
echo "  1. Review halStats output above"
echo "  2. Extract synteny: sbatch extract_synteny.slurm"
echo "  3. Back up HAL file (it's large and expensive to recreate)"
echo ""
echo "Finished: $(date)"
