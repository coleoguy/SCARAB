#!/bin/bash
# ============================================================================
# 07_concordance.slurm — gCF + sCF concordance factors
# ============================================================================
#
# Purpose:
#   Compute gene concordance factors (gCF) and site concordance factors (sCF)
#   on both the ML concatenation tree and the ASTRAL species tree.
#   Mirrors the SCARAB P6 approach (grace_upload_phase3/P6_astral_species_tree.slurm).
#
# Prerequisites:
#   05_iqtree_concat.slurm COMPLETE: concat_iqtree/concat.treefile
#   06_astral.slurm Stage B COMPLETE: astral/astral_species_tree_rooted.nwk
#   Per-locus gene trees: phylogenomics/gene_trees/*.treefile
#   Supermatrix: phylogenomics/supermatrix.fasta
#
# Resources: 1 node, 48 cores, 200 GB, 1 day wall.
#   sCF (likelihood-based) is the memory hog; 200 GB is conservative for
#   ~580 taxa x ~1M aa supermatrix.  If OOM, switch --scfl to --scf.
#
# Usage:
#   sbatch 07_concordance.slurm
# ============================================================================

#SBATCH --job-name=tob_concordance
#SBATCH --partition=bigmem
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=200G
#SBATCH --output=/scratch/user/blackmon/tob/logs/concordance_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/concordance_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TOB="${SCRATCH}/tob"
PHYLO="${TOB}/phylogenomics"
CONCAT_TREE="${PHYLO}/concat_iqtree/concat.treefile"
ASTRAL_TREE="${PHYLO}/astral/astral_species_tree_rooted.nwk"
GENE_TREES="${PHYLO}/astral/all_gene_trees.nwk"
SUPERMATRIX="${PHYLO}/supermatrix.fasta"
CF_DIR="${PHYLO}/concordance"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

mkdir -p "${CF_DIR}"

echo "============================================================"
echo "TOB Phase 1 -- Concordance Factors (gCF + sCF)"
echo "Job: ${SLURM_JOB_ID:-local}   Cores: ${NCPUS}"
echo "Started: $(date)"
echo "============================================================"
echo ""

module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

# Input checks
for F in "${CONCAT_TREE}" "${ASTRAL_TREE}" "${GENE_TREES}" "${SUPERMATRIX}"; do
    if [ ! -f "${F}" ]; then
        echo "ERROR: required file not found: ${F}"
        exit 1
    fi
done

N_TAXA=$(grep -c "^>" "${SUPERMATRIX}")
N_TREES=$(wc -l < "${GENE_TREES}")
echo "  Supermatrix: ${N_TAXA} taxa"
echo "  Gene trees:  ${N_TREES}"
echo ""

# ============================================================================
# 1. gCF ON CONCATENATION TREE
# ============================================================================

echo "[1] gCF on ML concatenation tree..."
iqtree2 \
    -t "${CONCAT_TREE}" \
    --gcf "${GENE_TREES}" \
    --prefix "${CF_DIR}/concat_gcf" \
    2>&1 | tail -10
echo "    concat_gcf.cf.stat: ${CF_DIR}/concat_gcf.cf.stat"

# ============================================================================
# 2. sCF ON CONCATENATION TREE (likelihood-based, 100 quartets)
# ============================================================================

echo ""
echo "[2] sCF on ML concatenation tree (likelihood, --scfl 100)..."
iqtree2 \
    -t "${CONCAT_TREE}" \
    -s "${SUPERMATRIX}" \
    --scfl 100 \
    --prefix "${CF_DIR}/concat_scfl" \
    -nt "${NCPUS}" \
    2>&1 | tail -10
echo "    concat_scfl.cf.stat: ${CF_DIR}/concat_scfl.cf.stat"

# ============================================================================
# 3. gCF ON ASTRAL TREE
# ============================================================================

echo ""
echo "[3] gCF on ASTRAL species tree..."
iqtree2 \
    -t "${ASTRAL_TREE}" \
    --gcf "${GENE_TREES}" \
    --prefix "${CF_DIR}/astral_gcf" \
    2>&1 | tail -10
echo "    astral_gcf.cf.stat: ${CF_DIR}/astral_gcf.cf.stat"

# ============================================================================
# 4. sCF ON ASTRAL TREE
# ============================================================================

echo ""
echo "[4] sCF on ASTRAL species tree (likelihood, --scfl 100)..."
iqtree2 \
    -t "${ASTRAL_TREE}" \
    -s "${SUPERMATRIX}" \
    --scfl 100 \
    --prefix "${CF_DIR}/astral_scfl" \
    -nt "${NCPUS}" \
    2>&1 | tail -10
echo "    astral_scfl.cf.stat: ${CF_DIR}/astral_scfl.cf.stat"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "============================================================"
echo "CONCORDANCE COMPLETE"
echo "  Outputs in: ${CF_DIR}/"
echo "  concat_gcf.cf.stat     -- gCF per node (concat tree)"
echo "  concat_scfl.cf.stat    -- sCF per node (concat tree)"
echo "  astral_gcf.cf.stat     -- gCF per node (ASTRAL tree)"
echo "  astral_scfl.cf.stat    -- sCF per node (ASTRAL tree)"
echo "  Annotated trees: *.cf.tree"
echo "============================================================"
echo "Finished: $(date)"
