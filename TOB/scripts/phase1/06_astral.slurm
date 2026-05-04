#!/bin/bash
# ============================================================================
# 06_astral.slurm — per-locus gene trees (IQ-TREE array) + ASTRAL-III
# ============================================================================
#
# Purpose:
#   Stage A (array): infer one gene tree per trimmed locus with IQ-TREE
#                    (ModelFinder + ufboot 1000).
#   Stage B (single job, after array):
#                    collect gene trees, contract low-support branches,
#                    run ASTRAL-III (via ASTER/wastral) for the coalescent
#                    species tree, root on Hymenoptera outgroup.
#
# This script handles BOTH stages via a SLURM_ARRAY_TASK_ID check:
#   - If SLURM_ARRAY_TASK_ID is set  -> Stage A (gene tree for one locus)
#   - If not set (or == "")          -> Stage B (collect + ASTRAL)
#
# Submission:
#   # Stage A
#   N=$(wc -l < $SCRATCH/tob/inputs/loci_trimmed.txt)
#   sbatch --array=1-${N}%200 06_astral.slurm
#   # Stage B (after Stage A complete)
#   sbatch 06_astral.slurm
#
# Build loci_trimmed.txt:
#   ls $SCRATCH/tob/orthologs/per_locus_trimmed/*.trim | \
#     xargs -I{} basename {} .trim \
#     > $SCRATCH/tob/inputs/loci_trimmed.txt
#
# Resources:
#   Stage A: medium, 4 cores, 8 GB, 4 h wall (many short gene trees)
#   Stage B: medium, 16 cores, 64 GB, 12 h wall (ASTRAL is RAM-light)
#   Adjust #SBATCH lines per stage; two separate sbatch calls.
# ============================================================================

# ---- Stage A resources (comment out for Stage B submission) ----
#SBATCH --job-name=tob_genetrees
#SBATCH --partition=medium
#SBATCH --time=4:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --output=/scratch/user/blackmon/tob/logs/genetree_%a_%j.log
#SBATCH --error=/scratch/user/blackmon/tob/logs/genetree_%a_%j.err
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=coleoguy@gmail.com

# ---- Stage B resources (uncomment + comment out Stage A before Stage B run)
## SBATCH --job-name=tob_astral
## SBATCH --partition=medium
## SBATCH --time=12:00:00
## SBATCH --nodes=1
## SBATCH --ntasks=1
## SBATCH --cpus-per-task=16
## SBATCH --mem=64G
## SBATCH --output=/scratch/user/blackmon/tob/logs/astral_%j.log
## SBATCH --error=/scratch/user/blackmon/tob/logs/astral_%j.err
## SBATCH --mail-type=END,FAIL
## SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

TOB="${SCRATCH}/tob"
LOCI_FILE="${TOB}/inputs/loci_trimmed.txt"
TRIM_DIR="${TOB}/orthologs/per_locus_trimmed"
TREE_DIR="${TOB}/phylogenomics/gene_trees"
ASTRAL_DIR="${TOB}/phylogenomics/astral"
NCPUS=${SLURM_CPUS_PER_TASK:-4}

mkdir -p "${TREE_DIR}" "${ASTRAL_DIR}" "${TOB}/logs"

# ============================================================================
# DISPATCH: Stage A vs Stage B
# ============================================================================

if [ -n "${SLURM_ARRAY_TASK_ID:-}" ]; then

    # ==========================================================================
    # STAGE A — Gene tree for one locus
    # ==========================================================================

    module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

    BUSCO_ID=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${LOCI_FILE}")
    if [ -z "${BUSCO_ID}" ]; then
        echo "ERROR: No locus at line ${SLURM_ARRAY_TASK_ID}"
        exit 1
    fi

    FASTA="${TRIM_DIR}/${BUSCO_ID}.trim"
    PREFIX="${TREE_DIR}/${BUSCO_ID}"

    echo "Task ${SLURM_ARRAY_TASK_ID}: ${BUSCO_ID}  started $(date)"

    # Resume check
    if [ -f "${PREFIX}.treefile" ]; then
        echo "${BUSCO_ID}: treefile exists, skipping."
        exit 0
    fi

    if [ ! -f "${FASTA}" ]; then
        echo "ERROR: ${FASTA} not found"
        exit 1
    fi

    N_TAXA=$(grep -c "^>" "${FASTA}")
    echo "${BUSCO_ID}: ${N_TAXA} taxa"

    if [ "${N_TAXA}" -lt 4 ]; then
        echo "${BUSCO_ID}: fewer than 4 taxa, skip IQ-TREE"
        exit 0
    fi

    iqtree2 -s "${FASTA}" \
        --prefix "${PREFIX}" \
        -m MFP \
        -bb 1000 \
        -alrt 1000 \
        -nt "${NCPUS}" \
        --quiet \
        2>/dev/null

    # Clean IQ-TREE intermediates to save inodes
    if [ -f "${PREFIX}.treefile" ]; then
        rm -f "${PREFIX}.ckp.gz" "${PREFIX}.contree" "${PREFIX}.splits.nex" \
              "${PREFIX}.bionj" "${PREFIX}.iqtree" "${PREFIX}.log" \
              "${PREFIX}.model.gz" "${PREFIX}.uniqueseq.phy" "${PREFIX}.mldist"
        echo "${BUSCO_ID}: done $(date)"
    else
        echo "${BUSCO_ID}: IQ-TREE failed"
        exit 1
    fi

else

    # ==========================================================================
    # STAGE B — Collect gene trees + ASTRAL-III
    # ==========================================================================

    module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6
    module load ASTER/1.20.4

    echo "============================================================"
    echo "TOB Phase 1 -- ASTRAL-III  (Stage B)"
    echo "Job: ${SLURM_JOB_ID:-local}   Cores: ${NCPUS}"
    echo "Started: $(date)"
    echo "============================================================"
    echo ""

    GENE_TREES_RAW="${ASTRAL_DIR}/all_gene_trees.nwk"
    GENE_TREES_CONTRACTED="${ASTRAL_DIR}/all_gene_trees_contracted.nwk"
    ASTRAL_TREE="${ASTRAL_DIR}/astral_species_tree.nwk"
    ROOTED_TREE="${ASTRAL_DIR}/astral_species_tree_rooted.nwk"

    # 1. Collect gene trees
    echo "[1] Collecting gene trees..."
    > "${GENE_TREES_RAW}"
    for TREEFILE in "${TREE_DIR}"/*.treefile; do
        [ -f "${TREEFILE}" ] || continue
        cat "${TREEFILE}" >> "${GENE_TREES_RAW}"
    done
    N_TREES=$(wc -l < "${GENE_TREES_RAW}")
    echo "    Gene trees collected: ${N_TREES}"

    # 2. Contract branches with UFBoot < 10 (reduces stochastic noise in ASTRAL)
    echo ""
    echo "[2] Contracting low-support branches (UFBoot < 10)..."
    iqtree2 -t "${GENE_TREES_RAW}" --branch-min 10 -o "${GENE_TREES_CONTRACTED}" 2>/dev/null \
        || cp "${GENE_TREES_RAW}" "${GENE_TREES_CONTRACTED}"
    echo "    Done."

    # 3. Run ASTRAL-III (wastral from ASTER module)
    echo ""
    echo "[3] Running ASTRAL-III (wastral)..."
    wastral \
        -t "${NCPUS}" \
        -o "${ASTRAL_TREE}" \
        "${GENE_TREES_CONTRACTED}"

    echo "    ASTRAL tree: ${ASTRAL_TREE}"

    # 4. Root on Hymenoptera outgroup
    echo ""
    echo "[4] Rooting on Hymenoptera outgroup..."

    # TODO: replace the OUTGROUP_LABELS list with the actual tip labels used
    # for Apis mellifera, Nasonia vitripennis, and Athalia rosae once the
    # TOB taxon labels are finalised by 02_collect_orthologs.py.
    # Labels here are placeholders matching the NCBI dataset accession IDs.
    OUTGROUP_LABELS="GCA_003254395 GCA_009193385 GCF_000004015"

    python3 - "${ASTRAL_TREE}" "${ROOTED_TREE}" "${OUTGROUP_LABELS}" << 'PYEOF'
import sys
try:
    import dendropy
except ImportError:
    sys.stderr.write("ERROR: dendropy not available. Install: pip install dendropy --user\n")
    sys.exit(1)

astral_path = sys.argv[1]
rooted_path = sys.argv[2]
outgroup_str = sys.argv[3]

outgroup_labels = outgroup_str.strip().split()

tree = dendropy.Tree.get(path=astral_path, schema="newick")

outgroup_taxa = []
for taxon in tree.taxon_namespace:
    label = taxon.label.replace(" ", "_")
    for og in outgroup_labels:
        if og in label:
            outgroup_taxa.append(taxon)
            break

sys.stdout.write("  Outgroup taxa matched: %d / %d\n" % (
    len(outgroup_taxa), len(outgroup_labels)))

if len(outgroup_taxa) >= 2:
    mrca = tree.mrca(taxa=outgroup_taxa)
    tree.reroot_at_edge(mrca.edge, update_bipartitions=True)
    tree.write(path=rooted_path, schema="newick")
    sys.stdout.write("  Rooted tree: %s\n" % rooted_path)
elif len(outgroup_taxa) == 1:
    node = tree.find_node_with_taxon_label(outgroup_taxa[0].label)
    tree.reroot_at_edge(node.edge, update_bipartitions=True)
    tree.write(path=rooted_path, schema="newick")
    sys.stdout.write("  Rooted on single outgroup.\n")
else:
    sys.stderr.write("  WARNING: No outgroup taxa found. Writing unrooted.\n")
    tree.write(path=rooted_path, schema="newick")
PYEOF

    echo ""
    echo "============================================================"
    echo "ASTRAL STAGE B COMPLETE"
    echo "  Gene trees:    ${N_TREES}"
    echo "  ASTRAL tree:   ${ASTRAL_TREE}"
    echo "  Rooted tree:   ${ROOTED_TREE}"
    echo "  NEXT: sbatch 07_concordance.slurm"
    echo "============================================================"
    echo "Finished: $(date)"

fi
