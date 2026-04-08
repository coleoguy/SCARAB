#!/bin/bash
# Build task list for rnaseq_qc.sh SLURM array
# Output: $SCRATCH/scarab/rnaseq/qc_tasks.txt
# Format: species<TAB>PE|SE<TAB>SRR_accession
#
# One line per paired-end pair or single-end file.
# PE pairs share an SRR accession (SRR_1.fastq.gz + SRR_2.fastq.gz = 1 task)
# SE files are individual (SRR.fastq.gz = 1 task)

set -euo pipefail

RNASEQ=/scratch/user/blackmon/scarab/rnaseq
OUTFILE="$RNASEQ/qc_tasks.txt"

> "$OUTFILE"

for SPECIES_DIR in "$RNASEQ"/*/; do
    SPECIES=$(basename "$SPECIES_DIR")

    # Skip non-directories (download logs etc)
    [ -d "$SPECIES_DIR" ] || continue

    # Paired-end: find all _1.fastq.gz, extract SRR
    for R1 in "$SPECIES_DIR"/*_1.fastq.gz; do
        [ -f "$R1" ] || continue
        SRR=$(basename "$R1" _1.fastq.gz)
        R2="$SPECIES_DIR/${SRR}_2.fastq.gz"
        if [ -f "$R2" ]; then
            printf '%s\tPE\t%s\n' "$SPECIES" "$SRR" >> "$OUTFILE"
        else
            echo "WARNING: $R1 has no R2 pair, skipping" >&2
        fi
    done

    # Single-end: find .fastq.gz that are NOT _1 or _2
    for SE in "$SPECIES_DIR"/*.fastq.gz; do
        [ -f "$SE" ] || continue
        BASENAME=$(basename "$SE")
        # Skip paired-end files
        echo "$BASENAME" | grep -qE '_[12]\.fastq\.gz$' && continue
        SRR=$(basename "$SE" .fastq.gz)
        printf '%s\tSE\t%s\n' "$SPECIES" "$SRR" >> "$OUTFILE"
    done
done

N=$(wc -l < "$OUTFILE")
echo "Built $OUTFILE with $N tasks"
echo "Submit with: sbatch --array=1-${N}%20 rnaseq_qc.sh"
