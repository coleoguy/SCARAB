#!/bin/bash
# TOB Phase 0 / Step 2 — pull the curated set of new genomes from NCBI Datasets.
# Run on Grace LOGIN NODE (needs internet).
#
# Per Heath 2026-05-03 review:
#  - Filter bleed-through (Apocrita = Hymenoptera, Pulicomorpha = fleas).
#  - Filter mitogenome / endosymbiont-misregistered "assemblies" (size < 50 Mb).
#  - Dedup: pull only the BEST assembly per species, comparing new candidates
#    against SCARAB's existing genome quality.
#
# All of that lives in TOB/scripts/select_best_per_species.py, run locally on
# Mac. Its output `TOB/data/accessions_to_pull.txt` is what this script
# consumes.
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/SCARAB}"
TOB_ROOT="/scratch/user/blackmon/tob"
PULL_LIST_SRC="$REPO_ROOT/TOB/data/accessions_to_pull.txt"
ACC_LIST="$TOB_ROOT/genomes/new_accessions.txt"
LOG="$TOB_ROOT/logs/02_pull_new_genomes_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$TOB_ROOT/genomes" "$TOB_ROOT/logs"

if [ ! -f "$PULL_LIST_SRC" ]; then
    echo "ERROR: pull list not found at $PULL_LIST_SRC" >&2
    echo "Run 'python3 TOB/scripts/select_best_per_species.py' on Mac and 'git pull' on Grace." >&2
    exit 1
fi

cp "$PULL_LIST_SRC" "$ACC_LIST"
n=$(wc -l < "$ACC_LIST")
echo "[$(date)] Pulling $n curated new genomes via NCBI Datasets (batched)..." | tee -a "$LOG"

# A first attempt downloading all 93 in one zip hit an NCBI HTTP/2 stream
# error at 10 GB. Single-bundle pulls of this size are fragile. Batching to
# small chunks (10 accessions ≈ 1-2 GB each) keeps any single flake recoverable.
BATCH_SIZE=10
BATCH_DIR="$TOB_ROOT/genomes/_batches"
FAIL_LIST="$TOB_ROOT/genomes/failed_accessions.txt"
rm -rf "$BATCH_DIR" && mkdir -p "$BATCH_DIR"
: > "$FAIL_LIST"
cd "$BATCH_DIR"

split -l "$BATCH_SIZE" -d -a 3 "$ACC_LIST" batch_

n_batches=$(ls batch_* | wc -l)
echo "[$(date)] Split into $n_batches batches of <= $BATCH_SIZE accessions" | tee -a "$LOG"

n_done=0
n_fail=0
for batch_file in batch_*; do
    batch_id=$(basename "$batch_file" | sed 's/^batch_//')
    zipname="batch_${batch_id}.zip"
    bsize=$(wc -l < "$batch_file")
    echo "[$(date)] === Batch $batch_id ($bsize accessions) ===" | tee -a "$LOG"

    success=0
    for try in 1 2 3; do
        # Strip terminal escape sequences from datasets' progress bar before
        # logging; keeps the log readable.
        if "$HOME/bin/datasets" download genome accession \
                --inputfile "$batch_file" \
                --include genome,protein,gff3 \
                --filename "$zipname" 2>&1 \
              | sed -u 's/\x1b\[[0-9;]*[A-Za-z]//g' | tail -3 | tee -a "$LOG"; then
            if [ -f "$zipname" ] && [ "$(stat -c%s "$zipname")" -gt 1000 ]; then
                success=1
                break
            fi
        fi
        echo "  Try $try failed; sleeping 30s before retry..." | tee -a "$LOG"
        sleep 30
        rm -f "$zipname"
    done

    if [ "$success" -eq 1 ]; then
        # Unpack INTO TOB_ROOT/genomes (not into batches/) so all assemblies
        # consolidate under one ncbi_dataset/data/{ACC}/ tree.
        unzip -q -o "$zipname" -d "$TOB_ROOT/genomes/"
        rm "$zipname"
        n_done=$((n_done + bsize))
        echo "  Batch $batch_id OK (running total: $n_done/$n)" | tee -a "$LOG"
    else
        echo "  Batch $batch_id FAILED 3x — adding to failed list:" | tee -a "$LOG"
        cat "$batch_file" | tee -a "$FAIL_LIST" | tee -a "$LOG"
        n_fail=$((n_fail + bsize))
    fi
done

# Cleanup batch dir; keep failed list for retry.
cd "$TOB_ROOT/genomes"
rm -rf "$BATCH_DIR"

n_unpacked=$(find ncbi_dataset/data -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 2 summary:" | tee -a "$LOG"
echo "  Requested:  $n" | tee -a "$LOG"
echo "  Succeeded:  $n_done" | tee -a "$LOG"
echo "  Failed 3x:  $n_fail (see $FAIL_LIST)" | tee -a "$LOG"
echo "  Unpacked dirs under ncbi_dataset/data/: $n_unpacked" | tee -a "$LOG"

if [ "$n_fail" -gt 0 ]; then
    echo "  RETRY: rerun script — it will read accessions_to_pull.txt fresh" | tee -a "$LOG"
    echo "  (or build a smaller list from failed_accessions.txt and rerun manually)" | tee -a "$LOG"
    exit 2
fi
