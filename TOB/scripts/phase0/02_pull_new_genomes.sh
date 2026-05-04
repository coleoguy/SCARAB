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
echo "[$(date)] Pulling $n curated new genomes via NCBI Datasets..." | tee -a "$LOG"

cd "$TOB_ROOT/genomes"

# NCBI Datasets handles batching, rate-limits, and resume internally.
# Including: genome FASTA + protein FASTA + GFF3. Many new entries lack
# annotation; datasets just skips those gracefully.
"$HOME/bin/datasets" download genome accession \
    --inputfile "$ACC_LIST" \
    --include genome,protein,gff3 \
    --filename new_genomes.zip \
    2>&1 | tee -a "$LOG"

echo "[$(date)] Unpacking..." | tee -a "$LOG"
unzip -q -o new_genomes.zip
rm new_genomes.zip

# Quick sanity check — count assembly directories under ncbi_dataset/data/.
n_unpacked=$(find ncbi_dataset/data -maxdepth 1 -mindepth 1 -type d | wc -l)
echo "[$(date)] Unpacked $n_unpacked assembly directories." | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 2 complete." | tee -a "$LOG"
