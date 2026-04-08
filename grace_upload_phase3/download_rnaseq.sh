#!/bin/bash
# download_rnaseq.sh — Download RNA-seq FASTQs from ENA for 53 both-sex species
#
# Run on Grace LOGIN NODE (compute nodes have no internet):
#   nohup bash $SCRATCH/scarab/grace_upload_phase3/download_rnaseq.sh > $SCRATCH/scarab/rnaseq/download.out 2>&1 &
#
# Prerequisites:
#   - selected_rnaseq_runs.csv must be at $SCRATCH/scarab/rnaseq/selected_rnaseq_runs.csv
#   - Copy from local: sftp selected_rnaseq_runs.csv to Grace

set -uo pipefail

BASEDIR="$SCRATCH/scarab/rnaseq"
CSV="$BASEDIR/selected_rnaseq_runs.csv"
LOGFILE="$BASEDIR/download_log.txt"
MAX_PARALLEL=4
MIN_SIZE=1000000  # 1 MB minimum to consider complete

# --- Validation ---
if [ ! -f "$CSV" ]; then
    echo "ERROR: $CSV not found. Copy it from local first."
    exit 1
fi

# Warn if on compute node
if hostname | grep -q "\.compute\."; then
    echo "WARNING: This appears to be a compute node. Downloads may fail (no internet)."
    echo "Run on login node instead."
    exit 1
fi

mkdir -p "$BASEDIR"
echo "$(date): Starting RNA-seq download" > "$LOGFILE"
echo "Manifest: $CSV" >> "$LOGFILE"

# --- Download function ---
download_one() {
    local url="$1"
    local outdir="$2"
    local filename=$(basename "$url")
    local outpath="$outdir/$filename"

    # Skip if exists and large enough
    if [ -f "$outpath" ] && [ $(stat -f%z "$outpath" 2>/dev/null || stat -c%s "$outpath" 2>/dev/null) -gt $MIN_SIZE ]; then
        echo "SKIP $filename (exists)" >> "$LOGFILE"
        return 0
    fi

    mkdir -p "$outdir"

    # Try HTTPS first, then FTP
    wget --timeout=120 --tries=3 --waitretry=10 -c -q -O "$outpath" "$url" 2>/dev/null
    if [ $? -eq 0 ] && [ -f "$outpath" ] && [ $(stat -f%z "$outpath" 2>/dev/null || stat -c%s "$outpath" 2>/dev/null) -gt $MIN_SIZE ]; then
        echo "OK   $filename" >> "$LOGFILE"
        return 0
    fi

    # Try FTP fallback
    local ftp_url=$(echo "$url" | sed 's|https://ftp.sra.ebi.ac.uk|ftp://ftp.sra.ebi.ac.uk|')
    wget --timeout=120 --tries=3 --waitretry=10 -c -q -O "$outpath" "$ftp_url" 2>/dev/null
    if [ $? -eq 0 ] && [ -f "$outpath" ] && [ $(stat -f%z "$outpath" 2>/dev/null || stat -c%s "$outpath" 2>/dev/null) -gt $MIN_SIZE ]; then
        echo "OK   $filename (ftp fallback)" >> "$LOGFILE"
        return 0
    fi

    # Clean up partial file
    rm -f "$outpath"
    echo "FAIL $filename" >> "$LOGFILE"
    return 1
}

export -f download_one
export LOGFILE MIN_SIZE

# --- Build download tasks ---
# Read CSV, extract URLs and output directories
TASKFILE=$(mktemp)
tail -n +2 "$CSV" | while IFS=, read -r species tip_label family clade srr sex tissue tissue_norm spots layout url_r1 url_r2 species_dir est_gb; do
    outdir="$BASEDIR/$species_dir"
    if [ -n "$url_r1" ]; then
        echo "$url_r1 $outdir"
    fi
    if [ -n "$url_r2" ]; then
        echo "$url_r2 $outdir"
    fi
done > "$TASKFILE"

TOTAL=$(wc -l < "$TASKFILE")
echo "Total files to download: $TOTAL"
echo "$(date): $TOTAL files to download" >> "$LOGFILE"

# --- Download with throttling ---
RUNNING=0
OK=0
FAIL=0
SKIP=0
COUNT=0

while read -r url outdir; do
    COUNT=$((COUNT + 1))

    # Throttle: wait if at max parallel
    while [ $RUNNING -ge $MAX_PARALLEL ]; do
        wait -n 2>/dev/null || true
        RUNNING=$((RUNNING - 1))
    done

    download_one "$url" "$outdir" &
    RUNNING=$((RUNNING + 1))

    if [ $((COUNT % 20)) -eq 0 ]; then
        echo "  Progress: $COUNT / $TOTAL files dispatched..."
    fi
done < "$TASKFILE"

# Wait for remaining
wait

rm -f "$TASKFILE"

# --- Summary ---
OK=$(grep -c "^OK" "$LOGFILE" 2>/dev/null || echo 0)
FAIL=$(grep -c "^FAIL" "$LOGFILE" 2>/dev/null || echo 0)
SKIP=$(grep -c "^SKIP" "$LOGFILE" 2>/dev/null || echo 0)

echo ""
echo "=== Download Summary ==="
echo "OK:   $OK"
echo "SKIP: $SKIP"
echo "FAIL: $FAIL"
echo ""

# Disk usage
echo "Disk usage per species:"
for d in "$BASEDIR"/*/; do
    if [ -d "$d" ]; then
        echo "  $(basename $d): $(du -sh $d | cut -f1)"
    fi
done

TOTAL_SIZE=$(du -sh "$BASEDIR" | cut -f1)
echo ""
echo "Total: $TOTAL_SIZE"
echo "$(date): Download complete. OK=$OK SKIP=$SKIP FAIL=$FAIL Total=$TOTAL_SIZE" >> "$LOGFILE"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failed files:"
    grep "^FAIL" "$LOGFILE"
    exit 1
fi
