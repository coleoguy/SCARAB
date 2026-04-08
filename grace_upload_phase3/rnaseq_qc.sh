#!/bin/bash
#SBATCH --job-name=rnaseq_qc
#SBATCH --partition=medium
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=/scratch/user/blackmon/scarab/logs/rnaseq_qc_%A_%a.out
#SBATCH --error=/scratch/user/blackmon/scarab/logs/rnaseq_qc_%A_%a.err

# RNA-seq QC + Trimming Pipeline
# ================================
# Step 1: FastQC on raw reads
# Step 2: fastp trimming (adapter removal, quality filtering, polyG trim)
# Step 3: FastQC on trimmed reads
#
# Run as SLURM array: one task per paired-end pair or single-end file
# Task list built by build_rnaseq_qc_tasks.sh
#
# Usage:
#   bash build_rnaseq_qc_tasks.sh          # generates task list
#   sbatch --array=1-N%20 rnaseq_qc.sh     # submit with throttle

set -euo pipefail

# Directories
RNASEQ=/scratch/user/blackmon/scarab/rnaseq
TRIMMED=/scratch/user/blackmon/scarab/rnaseq_trimmed
FASTQC_RAW=/scratch/user/blackmon/scarab/rnaseq_fastqc/raw
FASTQC_TRIM=/scratch/user/blackmon/scarab/rnaseq_fastqc/trimmed
TASK_FILE=/scratch/user/blackmon/scarab/rnaseq/qc_tasks.txt

# Load modules
module purge
module load GCC/12.3.0 fastp/0.23.4
module load FastQC/0.12.1-Java-11

# Read task line
LINE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$TASK_FILE")
if [ -z "$LINE" ]; then
    echo "ERROR: No task at line $SLURM_ARRAY_TASK_ID"
    exit 1
fi

SPECIES=$(echo "$LINE" | cut -f1)
TYPE=$(echo "$LINE" | cut -f2)      # PE or SE
SRR=$(echo "$LINE" | cut -f3)

echo "Task $SLURM_ARRAY_TASK_ID: $SPECIES / $SRR ($TYPE)"
echo "Started: $(date)"

# Create output directories
mkdir -p "$TRIMMED/$SPECIES"
mkdir -p "$FASTQC_RAW/$SPECIES"
mkdir -p "$FASTQC_TRIM/$SPECIES"

if [ "$TYPE" = "PE" ]; then
    R1="$RNASEQ/$SPECIES/${SRR}_1.fastq.gz"
    R2="$RNASEQ/$SPECIES/${SRR}_2.fastq.gz"
    T1="$TRIMMED/$SPECIES/${SRR}_1.trimmed.fastq.gz"
    T2="$TRIMMED/$SPECIES/${SRR}_2.trimmed.fastq.gz"
    HTML="$TRIMMED/$SPECIES/${SRR}.fastp.html"
    JSON="$TRIMMED/$SPECIES/${SRR}.fastp.json"

    # Verify input exists
    if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
        echo "ERROR: Missing input: $R1 or $R2"
        exit 1
    fi

    # Skip if already trimmed
    if [ -f "$T1" ] && [ -f "$T2" ] && [ -s "$T1" ] && [ -s "$T2" ]; then
        echo "Already trimmed, skipping fastp"
    else
        # Step 1: FastQC on raw
        fastqc --outdir "$FASTQC_RAW/$SPECIES" --threads 4 --quiet "$R1" "$R2"

        # Step 2: fastp trimming
        fastp \
            --in1 "$R1" \
            --in2 "$R2" \
            --out1 "$T1" \
            --out2 "$T2" \
            --html "$HTML" \
            --json "$JSON" \
            --thread 4 \
            --detect_adapter_for_pe \
            --qualified_quality_phred 20 \
            --unqualified_percent_limit 40 \
            --length_required 36 \
            --trim_poly_g \
            --cut_front \
            --cut_tail \
            --cut_window_size 4 \
            --cut_mean_quality 20 \
            --correction \
            --overrepresentation_analysis

        # Step 3: FastQC on trimmed
        fastqc --outdir "$FASTQC_TRIM/$SPECIES" --threads 4 --quiet "$T1" "$T2"
    fi

elif [ "$TYPE" = "SE" ]; then
    R1="$RNASEQ/$SPECIES/${SRR}.fastq.gz"
    T1="$TRIMMED/$SPECIES/${SRR}.trimmed.fastq.gz"
    HTML="$TRIMMED/$SPECIES/${SRR}.fastp.html"
    JSON="$TRIMMED/$SPECIES/${SRR}.fastp.json"

    if [ ! -f "$R1" ]; then
        echo "ERROR: Missing input: $R1"
        exit 1
    fi

    if [ -f "$T1" ] && [ -s "$T1" ]; then
        echo "Already trimmed, skipping fastp"
    else
        # Step 1: FastQC on raw
        fastqc --outdir "$FASTQC_RAW/$SPECIES" --threads 4 --quiet "$R1"

        # Step 2: fastp trimming
        fastp \
            --in1 "$R1" \
            --out1 "$T1" \
            --html "$HTML" \
            --json "$JSON" \
            --thread 4 \
            --qualified_quality_phred 20 \
            --unqualified_percent_limit 40 \
            --length_required 36 \
            --trim_poly_g \
            --cut_front \
            --cut_tail \
            --cut_window_size 4 \
            --cut_mean_quality 20 \
            --overrepresentation_analysis

        # Step 3: FastQC on trimmed
        fastqc --outdir "$FASTQC_TRIM/$SPECIES" --threads 4 --quiet "$T1"
    fi
else
    echo "ERROR: Unknown type '$TYPE' for $SRR"
    exit 1
fi

echo "Completed: $(date)"
