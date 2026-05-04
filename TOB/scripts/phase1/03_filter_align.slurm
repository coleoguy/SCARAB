#!/bin/bash
# ============================================================================
# 03_filter_align.slurm — per-locus array: filter, MAFFT-LINSI, trimAl
# ============================================================================
#
# Purpose:
#   For each BUSCO locus:
#     1. Filter: require >= 50% of total taxa (skip under-occupied loci).
#     2. Align: MAFFT --localpair --maxiterate 1000 (LINSI), proteins.
#     3. Trim:  trimAl -automated1.
#
# Prerequisites:
#   02_collect_orthologs.py complete; per_locus/*.faa exist.
#   Loci list built:
#     ls $SCRATCH/tob/orthologs/per_locus/*.faa | \
#       xargs -I{} basename {} .faa \
#       > $SCRATCH/tob/inputs/loci_all.txt
#
# Submission:
#   N=$(wc -l < $SCRATCH/tob/inputs/loci_all.txt)
#   sbatch --array=1-${N}%200 03_filter_align.slurm
#
# Notes:
#   - MAFFT-LINSI is slow (~1–10 min per locus for ~580 taxa); 200 concurrent
#     tasks is practical.  If wall-time becomes an issue, reduce --maxiterate
#     to 100 or switch to --globalpair for a subset of long loci.
#   - Resume-safe: skips loci with existing .trim output.
#   - Total taxa count is read from a file written by 02_collect_orthologs.py;
#     see TOTAL_TAXA_FILE below.
# ============================================================================

#SBATCH --job-name=tob_align
#SBATCH --partition=medium
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=/scratch/user/blackmon/tob/logs/align_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/align_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TOB="${SCRATCH}/tob"
LOCI_FILE="${TOB}/inputs/loci_all.txt"
RAW_DIR="${TOB}/orthologs/per_locus"
FILT_DIR="${TOB}/orthologs/per_locus_filtered"
ALN_DIR="${TOB}/orthologs/per_locus_aln"
TRIM_DIR="${TOB}/orthologs/per_locus_trimmed"
NCPUS=${SLURM_CPUS_PER_TASK:-4}

# Minimum fraction of taxa required to retain a locus (50%)
MIN_OCC="0.50"

# Total taxa count file — written by 02_collect_orthologs.py
# Contains a single integer: number of samples in the manifest
TOTAL_TAXA_FILE="${TOB}/inputs/total_taxa_count.txt"

mkdir -p "${FILT_DIR}" "${ALN_DIR}" "${TRIM_DIR}" "${TOB}/logs"

# ============================================================================
# RESOLVE LOCUS
# ============================================================================

BUSCO_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LOCI_FILE}")
if [ -z "${BUSCO_ID}" ]; then
    echo "ERROR: No locus at line ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

RAW_FASTA="${RAW_DIR}/${BUSCO_ID}.faa"
FILT_FASTA="${FILT_DIR}/${BUSCO_ID}.faa"
ALN_OUT="${ALN_DIR}/${BUSCO_ID}.aln"
TRIM_OUT="${TRIM_DIR}/${BUSCO_ID}.trim"

echo "Task ${SLURM_ARRAY_TASK_ID}: ${BUSCO_ID}  started $(date)"

# Resume check
if [ -f "${TRIM_OUT}" ] && [ -s "${TRIM_OUT}" ]; then
    echo "${BUSCO_ID}: already done, skipping."
    exit 0
fi

# ============================================================================
# MODULE LOAD
# ============================================================================

module load GCC/12.2.0 OpenMPI/4.1.4 MAFFT/7.520-with-extensions
module load GCCcore/12.3.0 trimAl/1.4.1

# ============================================================================
# 1. OCCUPANCY FILTER
# ============================================================================

if [ ! -f "${TOTAL_TAXA_FILE}" ]; then
    echo "ERROR: ${TOTAL_TAXA_FILE} not found. Create it with:"
    echo "  wc -l < \$SCRATCH/tob/inputs/genome_fnas.txt > ${TOTAL_TAXA_FILE}"
    exit 1
fi

TOTAL_TAXA=$(cat "${TOTAL_TAXA_FILE}" | tr -d '[:space:]')
N_IN=$(grep -c "^>" "${RAW_FASTA}" || echo 0)

# Integer arithmetic: require N_IN / TOTAL_TAXA >= MIN_OCC (50%)
# Equivalent: 2 * N_IN >= TOTAL_TAXA  (avoids floating point in bash)
MIN_COUNT=$(( (TOTAL_TAXA + 1) / 2 ))   # ceiling(TOTAL_TAXA / 2)

if [ "${N_IN}" -lt "${MIN_COUNT}" ]; then
    echo "${BUSCO_ID}: SKIP — only ${N_IN}/${TOTAL_TAXA} taxa (need >=${MIN_COUNT})"
    exit 0
fi

echo "${BUSCO_ID}: ${N_IN}/${TOTAL_TAXA} taxa — passes occupancy filter"

cp "${RAW_FASTA}" "${FILT_FASTA}"

# ============================================================================
# 2. MAFFT-LINSI ALIGNMENT
# ============================================================================

if [ ! -s "${ALN_OUT}" ]; then
    mafft \
        --localpair \
        --maxiterate 1000 \
        --thread "${NCPUS}" \
        --reorder \
        "${FILT_FASTA}" \
        > "${ALN_OUT}" \
        2>/dev/null
fi

if [ ! -s "${ALN_OUT}" ]; then
    echo "${BUSCO_ID}: MAFFT failed"
    exit 1
fi

N_ALN=$(grep -c "^>" "${ALN_OUT}")
echo "${BUSCO_ID}: aligned ${N_ALN} sequences"

# ============================================================================
# 3. TRIMAL
# ============================================================================

trimal \
    -in "${ALN_OUT}" \
    -out "${TRIM_OUT}" \
    -automated1 \
    2>/dev/null

if [ ! -s "${TRIM_OUT}" ]; then
    echo "${BUSCO_ID}: trimAl failed or produced empty output"
    exit 1
fi

TRIM_LEN=$(awk '/^>/{next}{len+=length($0)}END{print len}' "${TRIM_OUT}")
echo "${BUSCO_ID}: trimmed length ${TRIM_LEN} aa  done $(date)"
