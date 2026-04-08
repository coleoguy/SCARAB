#!/bin/bash
# ============================================================================
# P4_P5_rerun23.slurm — Rerun 23 loci that timed out during ModelFinder
# ============================================================================
# These 23 loci have large alignments (0.7–2.2 MB, 400–475 taxa) where
# full MFP (848 models) cannot finish in 12h on 4 threads.
# Fix: restrict ModelFinder to 6 common protein matrices via --mset.
#
# Prerequisites: Alignments already exist in per_gene_alignments/
# Usage:
#   sbatch --array=1-23 P4_P5_rerun23.slurm
# ============================================================================

#SBATCH --job-name=scarab_re23
#SBATCH --partition=medium
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=phylogenomics/logs/rerun_%a_%j.log
#SBATCH --error=phylogenomics/logs/rerun_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
ALN_DIR="${PHYLO_DIR}/per_gene_alignments"
TREE_DIR="${PHYLO_DIR}/per_gene_trees"
LOCI_FILE="${PHYLO_DIR}/rerun_23_loci.txt"

BUSCO_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LOCI_FILE}")
if [ -z "${BUSCO_ID}" ]; then
    echo "ERROR: No locus at line ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

ALN="${ALN_DIR}/${BUSCO_ID}.aln"
TREE_PREFIX="${TREE_DIR}/${BUSCO_ID}"

echo "${BUSCO_ID}: started $(date)"

# Skip if already done
if [ -f "${TREE_PREFIX}.treefile" ]; then
    echo "${BUSCO_ID}: already done, skipping"
    exit 0
fi

# Clean stale IQ-TREE intermediates from previous failed runs
rm -f "${TREE_PREFIX}.ckp.gz" "${TREE_PREFIX}.log" "${TREE_PREFIX}.model.gz" \
      "${TREE_PREFIX}.uniqueseq.phy" "${TREE_PREFIX}.bionj" "${TREE_PREFIX}.contree" \
      "${TREE_PREFIX}.splits.nex" "${TREE_PREFIX}.iqtree" "${TREE_PREFIX}.mldist"

if [ ! -s "${ALN}" ]; then
    echo "${BUSCO_ID}: alignment missing or empty"
    exit 1
fi

N_TAXA=$(grep -c "^>" "${ALN}")
echo "${BUSCO_ID}: ${N_TAXA} taxa, running IQ-TREE with restricted model set"

# IQ-TREE with restricted model set (~50 models instead of 848)
iqtree2 -s "${ALN}" \
    --prefix "${TREE_PREFIX}" \
    -m MFP \
    --mset LG,WAG,JTT,Q.insect,Q.pfam,Q.yeast \
    -bb 1000 \
    -nt 4 \
    --quiet \
    2>/dev/null

if [ -f "${TREE_PREFIX}.treefile" ]; then
    # Clean IQ-TREE intermediates (save inodes)
    rm -f "${TREE_PREFIX}.ckp.gz" "${TREE_PREFIX}.contree" "${TREE_PREFIX}.splits.nex" \
          "${TREE_PREFIX}.bionj" "${TREE_PREFIX}.iqtree" "${TREE_PREFIX}.log" \
          "${TREE_PREFIX}.model.gz" "${TREE_PREFIX}.uniqueseq.phy" "${TREE_PREFIX}.mldist"
    echo "${BUSCO_ID}: done $(date)"
else
    echo "${BUSCO_ID}: IQ-TREE failed"
    exit 1
fi
