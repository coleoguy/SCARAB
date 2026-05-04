#!/bin/bash
# TOB Phase 0 / Step 7 — symlink the 478 SCARAB genomes into TOB's tree.
# This avoids re-downloading 100+ GB we already have.
# Run on any Grace node (no internet required).
set -euo pipefail

SCARAB_GENOMES="/scratch/user/blackmon/scarab/genomes"
TOB_LINK_DIR="/scratch/user/blackmon/tob/genomes/scarab_existing"
LOG="/scratch/user/blackmon/tob/logs/07_link_scarab_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$TOB_LINK_DIR" "$(dirname "$LOG")"

if [ ! -d "$SCARAB_GENOMES" ]; then
    echo "ERROR: SCARAB genome dir not found at $SCARAB_GENOMES" | tee -a "$LOG"
    exit 1
fi

n=0
for d in "$SCARAB_GENOMES"/GCA_* "$SCARAB_GENOMES"/GCF_*; do
    [ -d "$d" ] || continue
    acc=$(basename "$d")
    ln -sfn "$d" "$TOB_LINK_DIR/$acc"
    n=$((n + 1))
done

echo "[$(date)] Linked $n SCARAB genome dirs into $TOB_LINK_DIR" | tee -a "$LOG"
echo "[$(date)] Verify count below matches expected (~478):" | tee -a "$LOG"
ls "$TOB_LINK_DIR" | wc -l | tee -a "$LOG"
