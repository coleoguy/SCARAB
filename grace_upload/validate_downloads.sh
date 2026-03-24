#!/bin/bash
#
# validate_downloads.sh
# Check that all 438 genomes downloaded successfully and contain FASTA files.
# Run this AFTER the download array job completes.
#
# Usage:
#   cd $SCRATCH/scarab/scripts
#   bash validate_downloads.sh
#
# Outputs:
#   download_status.tsv — one row per accession (accession, status, fasta_path, size_bytes)
#   failed_accessions.txt — accessions that need re-downloading
#   download_summary.txt — human-readable summary
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCESSION_FILE="${SCRIPT_DIR}/accessions_to_download.txt"
GENOME_DIR="${SCRATCH}/scarab/genomes"

STATUS_FILE="${SCRIPT_DIR}/download_status.tsv"
FAILED_FILE="${SCRIPT_DIR}/failed_accessions.txt"
SUMMARY_FILE="${SCRIPT_DIR}/download_summary.txt"

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

if [ ! -f "$ACCESSION_FILE" ]; then
    echo "ERROR: Accession file not found: $ACCESSION_FILE"
    exit 1
fi

if [ ! -d "$GENOME_DIR" ]; then
    echo "ERROR: Genome directory not found: $GENOME_DIR"
    echo "Have the downloads been submitted yet?"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check each accession
# ---------------------------------------------------------------------------

echo -e "accession\tstatus\tfasta_path\tsize_bytes" > "$STATUS_FILE"
> "$FAILED_FILE"

TOTAL=0
OK=0
MISSING=0
NO_FASTA=0

while IFS= read -r ACC || [ -n "$ACC" ]; do
    TOTAL=$((TOTAL + 1))
    ACC_DIR="${GENOME_DIR}/${ACC}"

    if [ ! -d "$ACC_DIR" ]; then
        echo -e "${ACC}\tMISSING\tNA\t0" >> "$STATUS_FILE"
        echo "$ACC" >> "$FAILED_FILE"
        MISSING=$((MISSING + 1))
        continue
    fi

    # Find the genomic FASTA (datasets extracts to ncbi_dataset/data/ACCESSION/*.fna)
    FASTA=$(find "$ACC_DIR" -name "*.fna" -type f | head -1)

    if [ -z "$FASTA" ]; then
        echo -e "${ACC}\tNO_FASTA\tNA\t0" >> "$STATUS_FILE"
        echo "$ACC" >> "$FAILED_FILE"
        NO_FASTA=$((NO_FASTA + 1))
        continue
    fi

    SIZE=$(stat --printf="%s" "$FASTA")
    echo -e "${ACC}\tOK\t${FASTA}\t${SIZE}" >> "$STATUS_FILE"
    OK=$((OK + 1))

done < "$ACCESSION_FILE"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

FAILED_COUNT=$(wc -l < "$FAILED_FILE")

cat > "$SUMMARY_FILE" <<EOF
SCARAB Download Validation — $(date)
============================================
Total expected:   $TOTAL
OK (FASTA found): $OK
Missing (no dir): $MISSING
No FASTA found:   $NO_FASTA
--------------------------------------------
Success rate:     $(( OK * 100 / TOTAL ))%
Failed accessions written to: $FAILED_FILE
Full status table: $STATUS_FILE
EOF

cat "$SUMMARY_FILE"

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo ""
    echo "To re-download failed genomes, run:"
    echo "  # Update the array range to match failed count"
    echo "  cp ${FAILED_FILE} ${SCRIPT_DIR}/accessions_to_download.txt.bak"
    echo "  cp ${FAILED_FILE} ${SCRIPT_DIR}/accessions_retry.txt"
    echo "  # Then submit a retry job pointing at accessions_retry.txt"
fi
