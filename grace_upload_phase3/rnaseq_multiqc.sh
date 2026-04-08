#!/bin/bash
#SBATCH --job-name=rnaseq_multiqc
#SBATCH --partition=short
#SBATCH --time=1:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --output=/scratch/user/blackmon/scarab/logs/rnaseq_multiqc_%j.out
#SBATCH --error=/scratch/user/blackmon/scarab/logs/rnaseq_multiqc_%j.err

# Aggregate FastQC + fastp reports into MultiQC summaries
# Run AFTER all rnaseq_qc.sh array tasks complete

set -euo pipefail

module purge
module load GCC/13.2.0 OpenMPI/4.1.6 MultiQC/1.27.1

BASEDIR=/scratch/user/blackmon/scarab

echo "=== MultiQC: Raw reads ==="
multiqc \
    "$BASEDIR/rnaseq_fastqc/raw" \
    --outdir "$BASEDIR/rnaseq_fastqc/multiqc_raw" \
    --title "SCARAB RNA-seq Raw Reads QC" \
    --force \
    --no-data-dir

echo "=== MultiQC: Trimmed reads ==="
multiqc \
    "$BASEDIR/rnaseq_fastqc/trimmed" \
    "$BASEDIR/rnaseq_trimmed" \
    --outdir "$BASEDIR/rnaseq_fastqc/multiqc_trimmed" \
    --title "SCARAB RNA-seq Trimmed Reads QC" \
    --force \
    --no-data-dir

echo "=== MultiQC: fastp reports ==="
multiqc \
    "$BASEDIR/rnaseq_trimmed" \
    --outdir "$BASEDIR/rnaseq_fastqc/multiqc_fastp" \
    --title "SCARAB RNA-seq fastp Trimming Summary" \
    --module fastp \
    --force \
    --no-data-dir

echo "Done: $(date)"
echo "Reports at:"
echo "  $BASEDIR/rnaseq_fastqc/multiqc_raw/multiqc_report.html"
echo "  $BASEDIR/rnaseq_fastqc/multiqc_trimmed/multiqc_report.html"
echo "  $BASEDIR/rnaseq_fastqc/multiqc_fastp/multiqc_report.html"
