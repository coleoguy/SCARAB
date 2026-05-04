#!/bin/bash
# TOB Phase 0 / Step 4 — pull 3 Hymenoptera anchor genomes for deep outgroup.
# Per notes/07: Hymenoptera anchors stabilise Strepsiptera placement and
# match McKenna 2019's outgroup composition.
# Run on Grace LOGIN NODE.
#
# NOTE: verify these accessions before running — pulled from RefSeq for
# stability but versions may have advanced. If a pull fails, look up the
# current "representative" accession at https://www.ncbi.nlm.nih.gov/genome/
set -euo pipefail

TOB_ROOT="/scratch/user/blackmon/tob"
ANCHOR_DIR="$TOB_ROOT/outgroups/hymenoptera"
LOG="$TOB_ROOT/logs/04_pull_hymenoptera_anchors_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$ANCHOR_DIR" "$TOB_ROOT/logs"
cd "$ANCHOR_DIR"

# 3 references spanning Apocrita (Apis, Nasonia) + Symphyta (Athalia)
# — gives the outgroup some internal structure.
ACCS=(
    "GCF_003254395.2:Apis_mellifera:Apidae:Apocrita"
    "GCF_009193385.2:Nasonia_vitripennis:Pteromalidae:Apocrita"
    "GCA_910592395.2:Athalia_rosae:Tenthredinidae:Symphyta"
)

for entry in "${ACCS[@]}"; do
    acc=$(echo "$entry"  | cut -d: -f1)
    name=$(echo "$entry" | cut -d: -f2)
    echo "[$(date)] $name ($acc)" | tee -a "$LOG"

    "$HOME/bin/datasets" download genome accession "$acc" \
        --include genome,protein \
        --filename "${acc}.zip" 2>&1 | tee -a "$LOG"
    unzip -q -o "${acc}.zip"
    rm "${acc}.zip"
    sleep 2
done

echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 4 complete." | tee -a "$LOG"
ls -la "$ANCHOR_DIR/ncbi_dataset/data/" 2>/dev/null | tee -a "$LOG"
