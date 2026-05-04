#!/bin/bash
#SBATCH --job-name=tob_sphaerius_spades
#SBATCH --partition=bigmem
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=300G
#SBATCH --array=0-1
#SBATCH --output=/scratch/user/blackmon/tob/logs/06_sphaerius_spades_%A_%a.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/06_sphaerius_spades_%A_%a.err

# TOB Phase 0 / Step 6 — DIY SPAdes assembly of 2 Sphaerius species.
# SLURM array: task 0 = Sphaerius sp. Arizona, task 1 = S. cf. minutus.
# Submit with: sbatch 06_assemble_sphaerius.slurm
set -euo pipefail

TOB_ROOT="/scratch/user/blackmon/tob"
READS_DIR="$TOB_ROOT/sphaerius/reads"
ASM_DIR="$TOB_ROOT/sphaerius/assemblies"
mkdir -p "$ASM_DIR"

# Module versions verified on Grace 2026-04. Adjust if newer SPAdes available.
module purge
module load GCC/12.3.0 SPAdes/3.15.5

SRRS=(SRR21231095 SRR21231096)
SPECIES=(Sphaerius_sp_Arizona Sphaerius_cf_minutus)

i=$SLURM_ARRAY_TASK_ID
srr="${SRRS[$i]}"
sp="${SPECIES[$i]}"

R1="${READS_DIR}/${srr}_1.fastq.gz"
R2="${READS_DIR}/${srr}_2.fastq.gz"
OUT="${ASM_DIR}/${sp}"

echo "[$(date)] Assembling $sp from $srr"
echo "  R1: $R1"
echo "  R2: $R2"
echo "  Out: $OUT"
echo "  CPUs: $SLURM_CPUS_PER_TASK, Mem: ${SLURM_MEM_PER_NODE} MB"

spades.py \
    -1 "$R1" \
    -2 "$R2" \
    -o "$OUT" \
    -t "$SLURM_CPUS_PER_TASK" \
    -m 300 \
    --only-assembler

echo "[$(date)] Assembly complete for $sp"
n_contigs=$(grep -c '^>' "${OUT}/contigs.fasta")
total_len=$(awk '!/^>/ { l += length($0) } END { print l }' "${OUT}/contigs.fasta")
echo "  Contigs: $n_contigs"
echo "  Total length: $total_len bp ($(awk -v x=$total_len 'BEGIN { printf "%.1f", x/1e6 }') Mb)"
