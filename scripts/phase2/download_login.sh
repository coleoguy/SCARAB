#!/bin/bash
# ============================================================================
# download_login.sh — Download 438 genomes from NCBI on Grace LOGIN node
# ============================================================================
#
# CONTEXT:
#   Grace compute nodes have NO internet access (curl exit code 7).
#   This script runs on the login node instead, with 4 parallel curl
#   processes to stay within the 8-core login node limit.
#
# USAGE (on Grace login node):
#   nohup bash $SCRATCH/scarab/scripts/download_login.sh \
#       > $SCRATCH/scarab/scripts/download_output.log 2>&1 &
#
# MONITORING:
#   tail -20 $SCRATCH/scarab/scripts/download_log.txt
#   ls -d $SCRATCH/scarab/genomes/GCA_*/ 2>/dev/null | wc -l
#
# RUNTIME: ~2-3 hours for 438 genomes at 4 parallel
#
# CREATED: 2026-03-21
# REPLACES: download_genomes.slurm (SLURM array approach — failed on Grace)
# ============================================================================

ACCFILE="$SCRATCH/scarab/scripts/accessions_to_download.txt"
OUTDIR="$SCRATCH/scarab/genomes"
LOGFILE="$SCRATCH/scarab/scripts/download_log.txt"
PARALLEL=4

mkdir -p "$OUTDIR"
> "$LOGFILE"

TOTAL=$(wc -l < "$ACCFILE")
COUNT=0

while IFS= read -r ACC || [ -n "$ACC" ]; do
    COUNT=$((COUNT + 1))

    # Skip if already downloaded (directory with .fna file exists)
    if find "$OUTDIR/$ACC/" -name "*.fna" 2>/dev/null | grep -q .; then
        echo "[$COUNT/$TOTAL] SKIP $ACC (already exists)" | tee -a "$LOGFILE"
        continue
    fi

    # Throttle: wait if we already have $PARALLEL background jobs
    while [ "$(jobs -rp | wc -l)" -ge "$PARALLEL" ]; do
        sleep 2
    done

    # Download in background
    (
        curl -s -o "$OUTDIR/${ACC}.zip" \
            "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/${ACC}/download?include_annotation_type=GENOME_FASTA,GENOME_GFF&filename=${ACC}.zip"

        if [ -f "$OUTDIR/${ACC}.zip" ] && [ "$(stat --printf='%s' "$OUTDIR/${ACC}.zip")" -gt 10000 ]; then
            unzip -o -q "$OUTDIR/${ACC}.zip" -d "$OUTDIR/${ACC}/" && rm -f "$OUTDIR/${ACC}.zip"
            echo "[$COUNT/$TOTAL] OK $ACC" | tee -a "$LOGFILE"
        else
            rm -f "$OUTDIR/${ACC}.zip"
            echo "[$COUNT/$TOTAL] FAILED $ACC" | tee -a "$LOGFILE"
        fi
    ) &

done < "$ACCFILE"

wait

echo "Done. $(grep -c ' OK ' "$LOGFILE") succeeded, $(grep -c ' FAILED ' "$LOGFILE") failed."
