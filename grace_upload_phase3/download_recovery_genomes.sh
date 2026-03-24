#!/bin/bash
#===============================================================================
# Download 39 recovery genomes to Grace
#===============================================================================
# These are species that were excluded in Phase 2 as "conditional" but pass
# the Cactus quality filter (contig N50 >= 100 kb, scaffolds <= 10,000).
# Adding them brings SCARAB from ~410 to ~453 genomes, making it the largest
# single-clade Progressive Cactus alignment ever published.
#
# Run this on the Grace LOGIN NODE (needs internet).
# Usage: bash download_recovery_genomes.sh
#===============================================================================

set -euo pipefail

SCRATCH_DIR="${SCRATCH}/scarab"
GENOME_DIR="${SCRATCH_DIR}/genomes"
ACCESSION_FILE="$(dirname "$0")/recovery_accessions.txt"
LOG_FILE="${SCRATCH_DIR}/recovery_download.log"
FAILED_FILE="${SCRATCH_DIR}/recovery_download_failed.txt"

# Verify we're on a login node (has internet)
if [[ $(hostname) == *.compute.* ]]; then
    echo "ERROR: This script must run on the login node (needs internet)."
    exit 1
fi

mkdir -p "${GENOME_DIR}"
> "${LOG_FILE}"
> "${FAILED_FILE}"

TOTAL=$(wc -l < "${ACCESSION_FILE}")
COUNT=0
SUCCESS=0
FAIL=0

echo "========================================" | tee -a "${LOG_FILE}"
echo "Downloading ${TOTAL} recovery genomes"   | tee -a "${LOG_FILE}"
echo "Target: ${GENOME_DIR}"                   | tee -a "${LOG_FILE}"
echo "Started: $(date)"                        | tee -a "${LOG_FILE}"
echo "========================================" | tee -a "${LOG_FILE}"

while IFS= read -r ACCESSION; do
    # Skip empty lines
    [[ -z "${ACCESSION}" ]] && continue

    COUNT=$((COUNT + 1))
    echo "[${COUNT}/${TOTAL}] Downloading ${ACCESSION}..." | tee -a "${LOG_FILE}"

    # Check if already downloaded
    EXPECTED="${GENOME_DIR}/${ACCESSION}*_genomic.fna.gz"
    if ls ${EXPECTED} 1>/dev/null 2>&1; then
        echo "  Already exists, skipping." | tee -a "${LOG_FILE}"
        SUCCESS=$((SUCCESS + 1))
        continue
    fi

    # Download using NCBI datasets (preferred) or direct FTP
    if command -v datasets &>/dev/null; then
        # Use NCBI datasets CLI
        TMPDIR=$(mktemp -d)
        if datasets download genome accession "${ACCESSION}" \
            --include genome \
            --filename "${TMPDIR}/${ACCESSION}.zip" 2>>"${LOG_FILE}"; then

            cd "${TMPDIR}"
            unzip -q "${ACCESSION}.zip" 2>>"${LOG_FILE}"

            # Find the .fna file and copy to genome dir
            FNA=$(find . -name "*.fna" -type f | head -1)
            if [[ -n "${FNA}" ]]; then
                gzip -c "${FNA}" > "${GENOME_DIR}/${ACCESSION}_genomic.fna.gz"
                echo "  Success (datasets CLI)" | tee -a "${LOG_FILE}"
                SUCCESS=$((SUCCESS + 1))
            else
                echo "  FAILED: no .fna in archive" | tee -a "${LOG_FILE}"
                echo "${ACCESSION}" >> "${FAILED_FILE}"
                FAIL=$((FAIL + 1))
            fi
            cd -
            rm -rf "${TMPDIR}"
        else
            rm -rf "${TMPDIR}"
            # Fallback to direct FTP
            echo "  datasets CLI failed, trying FTP..." | tee -a "${LOG_FILE}"
            # Construct FTP path from accession
            PREFIX=$(echo "${ACCESSION}" | sed 's/\(GC[AF]_\)\([0-9]\{3\}\)\([0-9]\{3\}\)\([0-9]\{3\}\).*/\1\/\2\/\3\/\4/')
            FTP_BASE="https://ftp.ncbi.nlm.nih.gov/genomes/all/${PREFIX}"

            # Get the directory name
            DIR_NAME=$(curl -sL "${FTP_BASE}/" | grep -oP 'href="\K[^"]+(?=/)' | grep "${ACCESSION}" | head -1)
            if [[ -n "${DIR_NAME}" ]]; then
                URL="${FTP_BASE}/${DIR_NAME}/${DIR_NAME}_genomic.fna.gz"
                if wget -q -O "${GENOME_DIR}/${ACCESSION}_genomic.fna.gz" "${URL}" 2>>"${LOG_FILE}"; then
                    echo "  Success (FTP)" | tee -a "${LOG_FILE}"
                    SUCCESS=$((SUCCESS + 1))
                else
                    echo "  FAILED: FTP download error" | tee -a "${LOG_FILE}"
                    echo "${ACCESSION}" >> "${FAILED_FILE}"
                    rm -f "${GENOME_DIR}/${ACCESSION}_genomic.fna.gz"
                    FAIL=$((FAIL + 1))
                fi
            else
                echo "  FAILED: could not resolve FTP path" | tee -a "${LOG_FILE}"
                echo "${ACCESSION}" >> "${FAILED_FILE}"
                FAIL=$((FAIL + 1))
            fi
        fi
    else
        # No datasets CLI, use direct FTP
        PREFIX=$(echo "${ACCESSION}" | sed 's/\(GC[AF]_\)\([0-9]\{3\}\)\([0-9]\{3\}\)\([0-9]\{3\}\).*/\1\/\2\/\3\/\4/')
        FTP_BASE="https://ftp.ncbi.nlm.nih.gov/genomes/all/${PREFIX}"
        DIR_NAME=$(curl -sL "${FTP_BASE}/" | grep -oP 'href="\K[^"]+(?=/)' | grep "${ACCESSION}" | head -1)

        if [[ -n "${DIR_NAME}" ]]; then
            URL="${FTP_BASE}/${DIR_NAME}/${DIR_NAME}_genomic.fna.gz"
            if wget -q -O "${GENOME_DIR}/${ACCESSION}_genomic.fna.gz" "${URL}" 2>>"${LOG_FILE}"; then
                echo "  Success (FTP)" | tee -a "${LOG_FILE}"
                SUCCESS=$((SUCCESS + 1))
            else
                echo "  FAILED" | tee -a "${LOG_FILE}"
                echo "${ACCESSION}" >> "${FAILED_FILE}"
                rm -f "${GENOME_DIR}/${ACCESSION}_genomic.fna.gz"
                FAIL=$((FAIL + 1))
            fi
        else
            echo "  FAILED: could not resolve FTP path" | tee -a "${LOG_FILE}"
            echo "${ACCESSION}" >> "${FAILED_FILE}"
            FAIL=$((FAIL + 1))
        fi
    fi
done < "${ACCESSION_FILE}"

echo "" | tee -a "${LOG_FILE}"
echo "========================================" | tee -a "${LOG_FILE}"
echo "Download complete: $(date)"              | tee -a "${LOG_FILE}"
echo "Success: ${SUCCESS}/${TOTAL}"            | tee -a "${LOG_FILE}"
echo "Failed:  ${FAIL}/${TOTAL}"               | tee -a "${LOG_FILE}"
echo "========================================" | tee -a "${LOG_FILE}"

if [[ ${FAIL} -gt 0 ]]; then
    echo ""
    echo "Failed accessions saved to: ${FAILED_FILE}"
    echo "Review and retry manually."
fi
