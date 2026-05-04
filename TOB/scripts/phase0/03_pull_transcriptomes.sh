#!/bin/bash
# TOB Phase 0 / Step 3 — pull 4 verified Tier-2 transcriptomes (TSA).
# Covers the ancient suborders (Archostemata + Myxophaga) where genome data
# is absent or unusable. Source verified 2026-05-03 from NCBI search.
# Run on Grace LOGIN NODE.
set -euo pipefail

TOB_ROOT="/scratch/user/blackmon/tob"
TR_DIR="$TOB_ROOT/transcriptomes"
LOG="$TOB_ROOT/logs/03_pull_transcriptomes_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$TR_DIR" "$TOB_ROOT/logs"
cd "$TR_DIR"

# species_safe_name : TSA_master_acc : family : suborder
TSAS=(
    "Priacma_serrata:GACO00000000.1:Cupedidae:Archostemata"
    "Micromalthus_debilis:GDOQ00000000.1:Micromalthidae:Archostemata"
    "Hydroscapha_redfordi:GDMJ00000000.1:Hydroscaphidae:Myxophaga"
    "Lepicerus_sp:GAZB00000000.2:Lepiceridae:Myxophaga"
)

for entry in "${TSAS[@]}"; do
    name=$(echo "$entry"     | cut -d: -f1)
    acc=$(echo "$entry"      | cut -d: -f2)
    family=$(echo "$entry"   | cut -d: -f3)
    suborder=$(echo "$entry" | cut -d: -f4)
    out="${name}_${acc}.fasta.gz"

    echo "[$(date)] $suborder/$family — $name ($acc)" | tee -a "$LOG"

    # Build WGS FTP URL: GACO00000000.1 -> ftp/.../GA/CO/GACO/GACO01.1.fsa_nt.gz
    prefix="${acc:0:4}"
    v="${acc##*.}"
    p1="${prefix:0:2}"
    p2="${prefix:2:2}"
    url="https://ftp.ncbi.nlm.nih.gov/genbank/wgs/wgs_aux/${p1}/${p2}/${prefix}/${prefix}01.${v}.fsa_nt.gz"
    echo "  URL: $url" | tee -a "$LOG"

    if curl -sLf --retry 3 --retry-delay 5 -o "$out" "$url"; then
        echo "  Saved $out ($(du -h "$out" | cut -f1))" | tee -a "$LOG"
    else
        echo "  WGS FTP fetch failed; trying efetch fallback..." | tee -a "$LOG"
        # efetch can be flaky for large WGS but worth a shot.
        curl -sL --retry 3 \
            "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${acc}&rettype=fasta&retmode=text" \
            | gzip -c > "$out"
        if [ -s "$out" ] && [ "$(stat -c%s "$out")" -gt 5000 ]; then
            echo "  Fallback saved $out ($(du -h "$out" | cut -f1))" | tee -a "$LOG"
        else
            echo "  WARNING: $name fetch failed both ways. Manual intervention needed." | tee -a "$LOG"
            rm -f "$out"
        fi
    fi
    sleep 2
done

echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 3 complete." | tee -a "$LOG"
ls -lh "$TR_DIR" | tee -a "$LOG"
