#!/bin/bash
# TOB Phase 0 / Step 2b — pull the 127 SCARAB-source winners that exist in
# NCBI but were never materialized on Grace's $SCRATCH/scarab/genomes/.
#
# Surfaced 2026-05-04 by the Tier 1+2 manifest sub-agent: 127 species had
# winner_source=scarab in best_assembly_per_species.csv but no symlink in
# /scratch/user/blackmon/tob/genomes/scarab_existing/. Cause: the original
# SCARAB workflow filtered the catalog (687 entries) down to 439 actually
# downloaded; the 127 here are catalog entries that never made it to disk
# but ARE the best-quality assembly per their species.
#
# Pulls them via NCBI Datasets, batched + retried, into the same
# ncbi_dataset/data/{ACC}/ tree that step 02 populated.
#
# Run on Grace LOGIN NODE (needs internet).
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/SCARAB}"
TOB_ROOT="/scratch/user/blackmon/tob"
PULL_LIST_SRC="$REPO_ROOT/TOB/data/missing_scarab_winners_to_pull.txt"
ACC_LIST="$TOB_ROOT/genomes/missing_scarab_winners.txt"
LOG="$TOB_ROOT/logs/02b_pull_missing_scarab_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$TOB_ROOT/genomes" "$TOB_ROOT/logs"

if [ ! -f "$PULL_LIST_SRC" ]; then
    echo "ERROR: pull list not found at $PULL_LIST_SRC" >&2
    exit 1
fi

cp "$PULL_LIST_SRC" "$ACC_LIST"
n=$(wc -l < "$ACC_LIST")
echo "[$(date)] Pulling $n missing SCARAB-winner genomes via NCBI Datasets (batched)..." | tee -a "$LOG"

BATCH_SIZE=10
BATCH_DIR="$TOB_ROOT/genomes/_batches_2b"
FAIL_LIST="$TOB_ROOT/genomes/missing_scarab_failed.txt"
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
        unzip -q -o "$zipname" -d "$TOB_ROOT/genomes/"
        rm "$zipname"
        n_done=$((n_done + bsize))
        echo "  Batch $batch_id OK (running total: $n_done/$n)" | tee -a "$LOG"
    else
        echo "  Batch $batch_id FAILED 3x; recording:" | tee -a "$LOG"
        cat "$batch_file" | tee -a "$FAIL_LIST" | tee -a "$LOG"
        n_fail=$((n_fail + bsize))
    fi
done

cd "$TOB_ROOT/genomes"
rm -rf "$BATCH_DIR"

n_unpacked=$(find ncbi_dataset/data -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 2b summary:" | tee -a "$LOG"
echo "  Requested:                     $n" | tee -a "$LOG"
echo "  Succeeded:                     $n_done" | tee -a "$LOG"
echo "  Failed 3x:                     $n_fail (see $FAIL_LIST)" | tee -a "$LOG"
echo "  Total dirs in ncbi_dataset/data/ (cumulative across step 02 + 02b): $n_unpacked" | tee -a "$LOG"

if [ "$n_fail" -gt 0 ]; then
    exit 2
fi
