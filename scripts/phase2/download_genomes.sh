#!/bin/bash
# ============================================================================
# DEPRECATED — This standalone script was an early version.
# On Grace, use download_login.sh instead (login node, 4 parallel curl).
# ============================================================================
# SCARAB Genome Download Script
# Generated: 2026-03-21
# Usage: bash download_genomes.sh [output_dir]
# Total genomes: 439

OUTDIR=${1:-"./genomes"}
ACCESSION_FILE="accessions_to_download.txt"
LOG="download_log.txt"

mkdir -p "$OUTDIR"
echo "Starting download of 439 genomes to $OUTDIR" | tee "$LOG"
echo "Date: $(date)" >> "$LOG"

SUCCESS=0
FAIL=0
TOTAL=439

while IFS= read -r ACC; do
    if [ -d "$OUTDIR/$ACC" ]; then
        echo "SKIP (exists): $ACC" | tee -a "$LOG"
        ((SUCCESS++))
        continue
    fi
    
    echo "[$((SUCCESS+FAIL+1))/$TOTAL] Downloading $ACC..."
    
    if command -v datasets &> /dev/null; then
        datasets download genome accession "$ACC" \
            --include gff3,genome \
            --filename "$OUTDIR/${ACC}.zip" 2>/dev/null
    else
        curl -s -o "$OUTDIR/${ACC}.zip" \
            "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/${ACC}/download?include_annotation_type=GENOME_FASTA,GENOME_GFF&filename=${ACC}.zip"
    fi
    
    if [ -f "$OUTDIR/${ACC}.zip" ]; then
        unzip -o -q "$OUTDIR/${ACC}.zip" -d "$OUTDIR/$ACC/" 2>/dev/null
        rm -f "$OUTDIR/${ACC}.zip"
        echo "  SUCCESS: $ACC" | tee -a "$LOG"
        ((SUCCESS++))
    else
        echo "  FAILED: $ACC" | tee -a "$LOG"
        ((FAIL++))
    fi
    
    sleep 0.5  # Be nice to NCBI
done < "$ACCESSION_FILE"

echo "" | tee -a "$LOG"
echo "DOWNLOAD COMPLETE" | tee -a "$LOG"
echo "  Success: $SUCCESS / $TOTAL" | tee -a "$LOG"
echo "  Failed: $FAIL / $TOTAL" | tee -a "$LOG"
