#!/bin/bash
# TOB Phase 0 / Step 5 — pull 2 raw WGS read sets for Sphaerius DIY assembly.
# Source: BioProject PRJNA870497, Oregon State Univ., released 2023-09.
# Run on Grace LOGIN NODE.
set -euo pipefail

TOB_ROOT="/scratch/user/blackmon/tob"
READS_DIR="$TOB_ROOT/sphaerius/reads"
LOG="$TOB_ROOT/logs/05_pull_sphaerius_reads_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$READS_DIR" "$TOB_ROOT/logs"

# Load SRA Toolkit (verify module name on current Grace; adjust if different)
module purge
# SRA-Toolkit/3.2.0 requires this exact toolchain prereq pair on Grace:
module load GCC/13.3.0 OpenMPI/5.0.3 SRA-Toolkit/3.2.0

cd "$READS_DIR"

SRRS=(
    "SRR21231095:Sphaerius_sp_Arizona"     # 18.4 Gbases HiSeq 3000
    "SRR21231096:Sphaerius_cf_minutus"     # 16.1 Gbases HiSeq 3000
)

for entry in "${SRRS[@]}"; do
    srr=$(echo "$entry"     | cut -d: -f1)
    species=$(echo "$entry" | cut -d: -f2)
    echo "[$(date)] $species ($srr) — prefetching..." | tee -a "$LOG"
    prefetch --max-size 50g "$srr" 2>&1 | tee -a "$LOG"

    echo "[$(date)] $species ($srr) — converting to FASTQ..." | tee -a "$LOG"
    fasterq-dump --split-files --threads 8 "$srr" 2>&1 | tee -a "$LOG"

    echo "[$(date)] $species ($srr) — gzipping..." | tee -a "$LOG"
    gzip "${srr}_1.fastq" "${srr}_2.fastq"

    rm -rf "$srr"
done

echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 5 complete." | tee -a "$LOG"
ls -lh "$READS_DIR"/*.fastq.gz | tee -a "$LOG"
