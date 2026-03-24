#!/bin/bash
#SBATCH --job-name=scarab_download_recovery
#SBATCH --output=%x_%j.log
#SBATCH --partition=transfer             # transfer partition = no CPU charge, outbound internet
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=12:00:00                  # 27 Gb / ~100 Mb/s = ~5 min; 12h is very conservative
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

# ============================================================
# Download 39 SCARAB recovery genomes from NCBI FTP
# Idempotent: already-complete files are skipped automatically
# ============================================================

set -euo pipefail

echo "=== SCARAB recovery genome download ==="
echo "Start: $(date)"
echo "Node:  $(hostname)"
echo ""

SCARAB_DIR="$HOME/SCARAB"
OUTDIR="$SCRATCH/scarab/genomes"
LOG="$SCRATCH/scarab/download_recovery.log"

mkdir -p "$OUTDIR"

# Pull latest scripts in case anything changed
cd "$SCARAB_DIR"
git pull origin main --quiet

python3 "$SCARAB_DIR/grace_upload_phase3/download_recovery_genomes.py" \
    --outdir "$OUTDIR" \
    --log    "$LOG"

echo ""
echo "End: $(date)"
echo ""
echo "File count in $OUTDIR:"
ls "$OUTDIR"/*.fna.gz 2>/dev/null | wc -l
echo ""
echo "Disk used:"
du -sh "$OUTDIR"
