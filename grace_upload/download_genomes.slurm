#!/bin/bash
# ============================================================================
# DEPRECATED — DO NOT USE ON GRACE
# ============================================================================
# Grace compute nodes have NO internet access (curl returns exit code 7).
# USE INSTEAD: download_login.sh (runs on login node with 4 parallel curl)
# ============================================================================
#
#SBATCH --job-name=scarab_download
#SBATCH --output=logs/download_%A_%a.out
#SBATCH --error=logs/download_%A_%a.err
#SBATCH --array=1-438%20
#SBATCH --time=01:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --ntasks=1
#SBATCH --partition=short

# SCARAB Genome Download Array Job
# Updated: 2026-03-21
# Total genomes: 438
# Throttle: 20 concurrent downloads
# STATUS: DEPRECATED — see download_login.sh
#
# Usage:
#   cd $SCRATCH/scarab/scripts
#   sbatch download_genomes.slurm
#
# Prerequisites:
#   - accessions_to_download.txt in same directory (438 accessions, one per line)
#   - NCBI datasets CLI available (module or conda)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

# Try loading the NCBI datasets module (Grace module name may vary)
module load NCBI-Datasets-CLI 2>/dev/null || module load ncbi-datasets-cli 2>/dev/null || true

SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
ACCESSION_FILE="${SCRIPT_DIR}/accessions_to_download.txt"
OUTDIR="${SCRATCH}/scarab/genomes"
LOGDIR="${SCRIPT_DIR}/logs"

mkdir -p "${OUTDIR}" "${LOGDIR}"

# ---------------------------------------------------------------------------
# Get accession for this array task
# ---------------------------------------------------------------------------

ACC=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${ACCESSION_FILE}")

if [ -z "$ACC" ]; then
    echo "ERROR: No accession found for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

echo "========================================"
echo "SCARAB genome download"
echo "Task ${SLURM_ARRAY_TASK_ID} of 438"
echo "Accession: ${ACC}"
echo "Output: ${OUTDIR}/${ACC}/"
echo "Start: $(date)"
echo "========================================"

# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

if command -v datasets &> /dev/null; then
    datasets download genome accession "$ACC" \
        --include gff3,genome \
        --filename "${OUTDIR}/${ACC}.zip"
    DL_STATUS=$?
else
    # Fallback: NCBI Datasets REST API via curl
    echo "WARNING: datasets CLI not found, falling back to curl"
    curl -s -o "${OUTDIR}/${ACC}.zip" \
        "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/${ACC}/download?include_annotation_type=GENOME_FASTA,GENOME_GFF&filename=${ACC}.zip"
    DL_STATUS=$?
fi

if [ $DL_STATUS -ne 0 ] || [ ! -f "${OUTDIR}/${ACC}.zip" ]; then
    echo "FAILED: download returned status $DL_STATUS for ${ACC}"
    exit 1
fi

# Check file isn't suspiciously small (< 10 KB likely means an error page)
FILE_SIZE=$(stat --printf="%s" "${OUTDIR}/${ACC}.zip")
if [ "$FILE_SIZE" -lt 10000 ]; then
    echo "FAILED: ${ACC}.zip is only ${FILE_SIZE} bytes — likely an error response"
    exit 1
fi

# ---------------------------------------------------------------------------
# Extract — keep only the genomic FASTA, discard zip
# ---------------------------------------------------------------------------

unzip -o -q "${OUTDIR}/${ACC}.zip" -d "${OUTDIR}/${ACC}/"
UNZIP_STATUS=$?

if [ $UNZIP_STATUS -ne 0 ]; then
    echo "FAILED: unzip failed for ${ACC}"
    exit 1
fi

rm -f "${OUTDIR}/${ACC}.zip"

# Verify a FASTA file exists in the extraction
FASTA_COUNT=$(find "${OUTDIR}/${ACC}/" -name "*.fna" -o -name "*.fasta" | wc -l)
if [ "$FASTA_COUNT" -eq 0 ]; then
    echo "WARNING: No FASTA files found after extraction for ${ACC}"
    exit 1
fi

echo "SUCCESS: ${ACC} — ${FASTA_COUNT} FASTA file(s), ${FILE_SIZE} bytes compressed"
echo "End: $(date)"
