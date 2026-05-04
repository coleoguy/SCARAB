#!/bin/bash
# ============================================================================
# 01_busco_array.slurm — BUSCO array: one task per input assembly/transcriptome
# ============================================================================
#
# Purpose:
#   Run BUSCO 6.0.0 (insecta_odb10) on every Tier-1+2 input genome,
#   transcriptome, or DIY assembly.  Outputs land in:
#     $SCRATCH/tob/orthologs/busco_results/{LABEL}/
#
# Prerequisites:
#   - Phase 0 complete; all input paths in $SCRATCH/tob/inputs/genome_fnas.txt
#     (one absolute path per line, ~585-595 lines).
#   - insecta_odb10 database downloaded to $SCRATCH/tob/busco_downloads/
#     (on login node: busco --download insecta_odb10
#                            --download_path $SCRATCH/tob/busco_downloads/)
#
# Submission:
#   N=$(wc -l < $SCRATCH/tob/inputs/genome_fnas.txt)
#   sbatch --array=1-${N}%100 01_busco_array.slurm
#
# Notes:
#   - --mode genome for .fna assemblies; --mode transcriptome for .fasta.gz
#     The script detects the extension and sets mode automatically.
#   - Throttled at 100 concurrent (100 × 16 G = 1.6 TB; safe for medium).
#   - Resume-safe: skips samples with an existing short_summary file.
#   - Transcriptome tasks (.fasta.gz) are un-gzipped to $TMPDIR first.
# ============================================================================

#SBATCH --job-name=tob_busco
#SBATCH --partition=medium
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --output=/scratch/user/blackmon/tob/logs/busco_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/busco_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TOB="${SCRATCH}/tob"
INPUTS="${TOB}/inputs/genome_fnas.txt"
BUSCO_DB="${TOB}/busco_downloads/lineages/insecta_odb10"
OUT_ROOT="${TOB}/orthologs/busco_results"
NCPUS=${SLURM_CPUS_PER_TASK:-8}

mkdir -p "${OUT_ROOT}" "${TOB}/logs"

# ============================================================================
# RESOLVE THIS TASK'S INPUT
# ============================================================================

INPUT_PATH=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${INPUTS}")
if [ -z "${INPUT_PATH}" ]; then
    echo "ERROR: No input at line ${SLURM_ARRAY_TASK_ID} of ${INPUTS}"
    exit 1
fi

# Derive a clean label from the path (use the parent directory basename or
# the filename stem — whichever is more informative)
LABEL=$(basename "$(dirname "${INPUT_PATH}")")
# If the parent is "data" (ncbi_dataset layout) go one level up
if [ "${LABEL}" = "data" ]; then
    LABEL=$(basename "$(dirname "$(dirname "${INPUT_PATH}")")")
fi
# Strip trailing .fna / .fasta / .fasta.gz / .gz
LABEL=$(echo "${LABEL}" | sed 's/\.[^.]*$//' | sed 's/\.[^.]*$//')

OUT_DIR="${OUT_ROOT}/${LABEL}"

echo "============================================================"
echo "TOB Phase 1 -- BUSCO"
echo "Task: ${SLURM_ARRAY_TASK_ID}  Label: ${LABEL}"
echo "Input: ${INPUT_PATH}"
echo "Output: ${OUT_DIR}"
echo "Started: $(date)"
echo "============================================================"

# Resume check
if ls "${OUT_DIR}"/short_summary*.txt 1>/dev/null 2>&1; then
    echo "SKIP: ${LABEL} already has a short_summary file."
    exit 0
fi

# ============================================================================
# MODULE LOAD
# ============================================================================

module load GCC/12.3.0 OpenMPI/4.1.5 BUSCO/6.0.0

# ============================================================================
# HANDLE GZIPPED TRANSCRIPTOMES
# ============================================================================

FASTA="${INPUT_PATH}"
BUSCO_MODE="genome"
CLEANUP_FASTA=0

case "${INPUT_PATH}" in
    *.fasta.gz|*.fa.gz|*.fna.gz)
        BUSCO_MODE="transcriptome"
        FASTA="${TMPDIR}/${LABEL}.fasta"
        echo "Decompressing transcriptome to ${FASTA}..."
        gunzip -c "${INPUT_PATH}" > "${FASTA}"
        CLEANUP_FASTA=1
        ;;
    *.fasta|*.fa)
        # Could be a transcriptome or a small assembly — default genome;
        # Sphaerius DIY contigs.fasta are genome mode.
        BUSCO_MODE="genome"
        ;;
    *.fna)
        BUSCO_MODE="genome"
        ;;
esac

echo "BUSCO mode: ${BUSCO_MODE}"

# ============================================================================
# RUN BUSCO
# ============================================================================

busco \
    --in "${FASTA}" \
    --out "${LABEL}" \
    --out_path "${OUT_ROOT}" \
    --lineage_dataset "${BUSCO_DB}" \
    --mode "${BUSCO_MODE}" \
    --cpu "${NCPUS}" \
    --offline \
    --force \
    2>&1

# ============================================================================
# CLEANUP + SUMMARY
# ============================================================================

if [ "${CLEANUP_FASTA}" -eq 1 ]; then
    rm -f "${FASTA}"
fi

if ls "${OUT_DIR}"/short_summary*.txt 1>/dev/null 2>&1; then
    echo ""
    echo "BUSCO summary for ${LABEL}:"
    grep -A 8 "Results:" "${OUT_DIR}"/short_summary*.txt || true
    echo "Done: $(date)"
else
    echo "ERROR: BUSCO did not produce a short_summary file for ${LABEL}."
    exit 1
fi
