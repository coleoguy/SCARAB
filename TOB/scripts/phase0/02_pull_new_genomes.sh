#!/bin/bash
# TOB Phase 0 / Step 2 — pull all 546 new genomes from NCBI Datasets.
# Run on Grace LOGIN NODE (needs internet).
#
# Per Heath 2026-05-03: KEEP ALL new candidates including "conditional" and
# "exclude" tier ratings. BUSCO completeness will be the real filter, not
# assembly metadata. We only skip the 16 Hymenoptera bleed-through entries
# the inventory script flagged (those come from Apocrita misassignments in
# NCBI's taxonomy expansion of "Coleoptera"; we do want Hymenoptera anchors
# but those come from script 04 with curated accessions).
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$HOME/SCARAB}"
TOB_ROOT="/scratch/user/blackmon/tob"
INV_CSV="$REPO_ROOT/TOB/data/ncbi_inventory_refresh_2026-05.csv"
ACC_LIST="$TOB_ROOT/genomes/new_accessions.txt"
LOG="$TOB_ROOT/logs/02_pull_new_genomes_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$TOB_ROOT/genomes" "$TOB_ROOT/logs"

if [ ! -f "$INV_CSV" ]; then
    echo "ERROR: inventory CSV not found at $INV_CSV" >&2
    echo "Did you 'git pull' on Grace?" >&2
    exit 1
fi

# Extract all accessions where in_scarab_catalog == "no" and suborder != "Apocrita".
# Python 3.6 compatible (no f-strings, no walrus, no DictReader-as-typed-dict).
python3 - "$INV_CSV" "$ACC_LIST" <<'PY'
import csv, sys
inp, out = sys.argv[1], sys.argv[2]
n_total = n_skip_in_scarab = n_skip_hym = n_kept = 0
with open(inp, newline='') as f, open(out, 'w') as g:
    rdr = csv.DictReader(f)
    for row in rdr:
        n_total += 1
        in_scarab = (row.get('in_scarab_catalog') or '').strip().lower()
        if in_scarab != 'no':
            n_skip_in_scarab += 1
            continue
        suborder = (row.get('suborder') or '').strip().lower()
        if suborder == 'apocrita':
            n_skip_hym += 1
            continue
        acc = (row.get('accession') or '').strip()
        if acc:
            g.write(acc + '\n')
            n_kept += 1
print('Inventory rows total:', n_total)
print('Skipped (already in SCARAB):', n_skip_in_scarab)
print('Skipped (Hymenoptera bleed-through):', n_skip_hym)
print('Kept for new pull:', n_kept)
PY

n=$(wc -l < "$ACC_LIST")
echo "[$(date)] Pulling $n new genomes via NCBI Datasets..." | tee -a "$LOG"

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
