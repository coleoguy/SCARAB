#!/bin/bash
# ==============================================================================
# 04_align_per_family.slurm — SLURM array: MAFFT + trimAl per family
# ==============================================================================
# One array task per Coleoptera family. For each family:
#   - MAFFT --auto per locus (≥4 sequences required)
#   - trimAl -automated1 per aligned locus
#   - Writes per-locus trimmed FASTA to $SCRATCH/tob/alignments/{FAMILY}/
#
# Uses the same MAFFT module as SCARAB Phase 4–5.
# trimAl loaded via conda env (no Grace module conflict).
#
# Prerequisites: 03_filter_loci.sh complete
#
# Usage:
#   # Generate family list
#   ls $SCRATCH/tob/filtered_seqs/ > $SCRATCH/tob/data/family_list.txt
#   N=$(wc -l < $SCRATCH/tob/data/family_list.txt)
#   sbatch --array=1-${N}%100 04_align_per_family.slurm
#
# Notes:
#   - %100 throttle: limits concurrent jobs; increase if queue allows
#   - Min 4 taxa per locus to run MAFFT (trimAl requires ≥2, IQ-TREE ≥4)
# ==============================================================================

#SBATCH --job-name=tob_align
#SBATCH --partition=medium
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=/scratch/user/blackmon/tob/logs/align_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/align_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

SCRATCH_TOB="${SCRATCH}/tob"
FILT_DIR="${SCRATCH_TOB}/filtered_seqs"
ALN_DIR="${SCRATCH_TOB}/alignments"
FAMILY_LIST="${SCRATCH_TOB}/data/family_list.txt"
LOCI="COI 16S 18S 28S CAD EF1a ArgK RNApol2 wingless"
MIN_TAXA=4        # minimum sequences to attempt alignment
NCPUS=${SLURM_CPUS_PER_TASK:-4}

# Load MAFFT (GCC/12.3.0 toolchain, same as SCARAB)
module purge
module load GCC/12.3.0 MAFFT/7.520-with-extensions

# Load conda env for trimAl (avoids GCC conflict with Grace trimAl module)
module load Anaconda3/2024.02-1
source activate "${SCRATCH_TOB}/envs/supercrunch"

FAMILY=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${FAMILY_LIST}")
if [ -z "${FAMILY}" ]; then
    echo "ERROR: No family at array index ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

OUTDIR="${ALN_DIR}/${FAMILY}"
mkdir -p "${OUTDIR}"

echo "Family: ${FAMILY}"
echo "Started: $(date)"

for LOCUS in ${LOCI}; do
    INFASTA="${FILT_DIR}/${FAMILY}/${LOCUS}_filtered.fasta"

    if [ ! -s "${INFASTA}" ]; then
        echo "  ${LOCUS}: no filtered sequences, skipping"
        continue
    fi

    NTAXA=$(grep -c "^>" "${INFASTA}" || echo 0)
    if [ "${NTAXA}" -lt "${MIN_TAXA}" ]; then
        echo "  ${LOCUS}: ${NTAXA} sequences < ${MIN_TAXA} minimum, skipping"
        continue
    fi

    ALN_OUT="${OUTDIR}/${LOCUS}.aln"
    TRIM_OUT="${OUTDIR}/${LOCUS}.trim.fasta"

    # Skip if already done
    if [ -s "${TRIM_OUT}" ]; then
        echo "  ${LOCUS}: already done, skipping"
        continue
    fi

    # MAFFT alignment
    mafft --auto --thread "${NCPUS}" "${INFASTA}" > "${ALN_OUT}" 2>/dev/null
    if [ ! -s "${ALN_OUT}" ]; then
        echo "  ${LOCUS}: MAFFT failed"
        continue
    fi

    # trimAl -automated1
    trimal -in "${ALN_OUT}" -out "${TRIM_OUT}" -automated1 2>/dev/null
    if [ ! -s "${TRIM_OUT}" ]; then
        echo "  ${LOCUS}: trimAl failed or produced empty output"
        rm -f "${TRIM_OUT}"
        continue
    fi

    NTRIM=$(grep -c "^>" "${TRIM_OUT}" || echo 0)
    NCOLS=$(python3 -c "
from Bio import SeqIO
recs = list(SeqIO.parse('${TRIM_OUT}', 'fasta'))
print(len(recs[0].seq) if recs else 0)
" 2>/dev/null || echo 0)

    echo "  ${LOCUS}: ${NTRIM} taxa, ${NCOLS} columns after trim"

    # Drop loci with too few columns after trim (likely uninformative)
    # MINCOLS=100: confirm with Heath
    if [ "${NCOLS}" -lt 100 ]; then
        echo "  ${LOCUS}: only ${NCOLS} columns after trim (<100), removing"
        rm -f "${TRIM_OUT}"
    fi
done

echo "Family ${FAMILY} done: $(date)"
