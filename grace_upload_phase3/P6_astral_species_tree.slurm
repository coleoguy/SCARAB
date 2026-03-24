#!/bin/bash
# ============================================================================
# P6_astral_species_tree.slurm — ASTRAL-III species tree + concordance factors
# ============================================================================
#
# Purpose:
#   1. Run ASTRAL-III on gene trees → coalescent species tree
#   2. Compute gene concordance factors (gCF) and site concordance factors (sCF)
#      using IQ-TREE v2
#
# Prerequisites:
#   P4+P5 complete: all_gene_trees.nwk and per-gene alignments exist
#
# Resources: 1 node, 48 cores, 64GB (ASTRAL is memory-intensive but fast)
# Estimated time: 1-4 hours
#
# Usage:
#   sbatch P6_astral_species_tree.slurm
# ============================================================================

#SBATCH --job-name=scarab_P6_astral
#SBATCH --partition=medium
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=64G
#SBATCH --output=scarab_P6_astral_%j.log
#SBATCH --error=scarab_P6_astral_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
GENE_TREES="${PHYLO_DIR}/all_gene_trees.nwk"
ALN_DIR="${PHYLO_DIR}/per_gene_alignments"
SUPERMATRIX="${PHYLO_DIR}/concatenated_supermatrix.fasta"
PARTITIONS="${PHYLO_DIR}/partitions.txt"

ASTRAL_DIR="${PHYLO_DIR}/astral"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

echo "============================================================"
echo "SCARAB P.6 — ASTRAL-III Species Tree + Concordance Factors"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "============================================================"
echo ""

module load GCC/12.2.0
module load Java/17.0.6   # ASTRAL needs Java
module load IQ-TREE/2.2.6

mkdir -p "${ASTRAL_DIR}"

# ============================================================================
# 0. VERIFY INPUTS
# ============================================================================

echo "[0] Verifying inputs..."

if [ ! -f "${GENE_TREES}" ]; then
    echo "ERROR: ${GENE_TREES} not found. Run P4_P5 first."
    exit 1
fi

N_TREES=$(wc -l < "${GENE_TREES}")
echo "  Gene trees: ${N_TREES}"

# ============================================================================
# 1. RUN ASTRAL-III
# ============================================================================

echo ""
echo "[1] Running ASTRAL-III..."

# ASTRAL-III location — check common paths on Grace
ASTRAL_JAR=""
for candidate in \
    "${PROJECT_DIR}/software/astral/astral.5.7.8.jar" \
    "${PROJECT_DIR}/software/ASTRAL/Astral/astral.5.7.8.jar" \
    "/sw/eb/sw/ASTRAL-III/5.7.8-Java-17/ASTRAL-III-5.7.8.jar" \
    "${HOME}/software/astral/astral.5.7.8.jar"; do
    if [ -f "${candidate}" ]; then
        ASTRAL_JAR="${candidate}"
        break
    fi
done

if [ -z "${ASTRAL_JAR}" ]; then
    echo "ERROR: ASTRAL-III jar not found."
    echo "  Install ASTRAL-III:"
    echo "    mkdir -p \${SCRATCH}/scarab/software/astral"
    echo "    cd \${SCRATCH}/scarab/software/astral"
    echo "    wget https://github.com/smirarab/ASTRAL/raw/master/Astral/astral.5.7.8.jar"
    echo "  Then re-submit this job."
    exit 1
fi

ASTRAL_TREE="${ASTRAL_DIR}/astral_species_tree.nwk"
ASTRAL_LOG="${ASTRAL_DIR}/astral.log"

java -Xmx48g -jar "${ASTRAL_JAR}" \
    -i "${GENE_TREES}" \
    -o "${ASTRAL_TREE}" \
    2>"${ASTRAL_LOG}"

echo "  ASTRAL tree: ${ASTRAL_TREE}"

# Quick validation
N_TIPS=$(python3 -c "
import re
with open('${ASTRAL_TREE}') as f:
    tree = f.read()
tips = re.findall(r'[\w.]+(?=:)', tree)
print(len(set(tips)))
")
echo "  Tips in ASTRAL tree: ${N_TIPS}"

# ============================================================================
# 2. ROOT ON NEUROPTERIDA
# ============================================================================

echo ""
echo "[2] Rooting ASTRAL tree on Neuropterida..."

ROOTED_TREE="${ASTRAL_DIR}/astral_species_tree_rooted.nwk"

python3 - <<'PYEOF'
import sys
try:
    import dendropy
except ImportError:
    print("ERROR: dendropy not installed. Install: pip install dendropy --user")
    sys.exit(1)

tree = dendropy.Tree.get(path="${ASTRAL_TREE}", schema="newick")

# Neuropterida outgroup taxa (same list as guide tree rooting)
outgroup_names = [
    "Sisyra_nigra", "Sisyra_terminalis", "Micromus_angulatus",
    "Osmylus_fulvicephalus", "Conwentzia_psociformis",
    "Brachynemurus_nebulosus", "Nothochrysa_capitata", "Nineta_flava",
    "Chrysopa_pallens", "Chrysoperla_carnea", "Chrysoperla_zastrowi_sillemi",
    "Mongoloraphidia_duomilia", "Xanthostigma_xanthostigma",
    "Sialis_fuliginosa", "Sialis_lutaria",
    "Acanthacorydalis_orientalis", "Neoneuromus_ignobilis"
]

# Find outgroup taxa in tree (dendropy may convert underscores to spaces)
outgroup_taxa = []
for taxon in tree.taxon_namespace:
    label = taxon.label.replace(" ", "_")
    if label in outgroup_names:
        outgroup_taxa.append(taxon)

print(f"  Outgroup taxa found: {len(outgroup_taxa)} / {len(outgroup_names)}")

if len(outgroup_taxa) >= 2:
    mrca = tree.mrca(taxa=outgroup_taxa)
    tree.reroot_at_edge(mrca.edge, update_bipartitions=True)
    tree.write(path="${ROOTED_TREE}", schema="newick")
    print(f"  Rooted tree written: ${ROOTED_TREE}")
else:
    print("  WARNING: Not enough outgroup taxa found. Writing unrooted.")
    tree.write(path="${ROOTED_TREE}", schema="newick")
PYEOF

# ============================================================================
# 3. GENE CONCORDANCE FACTORS (gCF) AND SITE CONCORDANCE FACTORS (sCF)
# ============================================================================

echo ""
echo "[3] Computing concordance factors (gCF + sCF)..."

CF_PREFIX="${ASTRAL_DIR}/concordance"

iqtree2 -t "${ROOTED_TREE}" \
        --gcf "${GENE_TREES}" \
        -s "${SUPERMATRIX}" \
        --scf 100 \
        --prefix "${CF_PREFIX}" \
        -nt ${NCPUS} \
        2>&1 | tail -20

echo "  Concordance factors: ${CF_PREFIX}.cf.stat"
echo "  Annotated tree: ${CF_PREFIX}.cf.tree"

# ============================================================================
# 4. PER-ELEMENT CONCORDANCE (for analysis A.0)
# ============================================================================

echo ""
echo "[4] Computing per-Stevens-element concordance..."

ELEMENT_MAP="${PHYLO_DIR}/loci_by_element.tsv"

if [ -f "${ELEMENT_MAP}" ]; then
    python3 - <<'PYEOF2'
import os

phylo_dir = os.environ["PHYLO_DIR"]
astral_dir = os.environ["ASTRAL_DIR"]
tree_dir = os.path.join(phylo_dir, "per_gene_trees")
element_map_file = os.path.join(phylo_dir, "loci_by_element.tsv")

# Read element assignments
locus_element = {}
with open(element_map_file) as f:
    header = f.readline()
    for line in f:
        cols = line.strip().split("\t")
        locus_element[cols[0]] = cols[1]

# Group gene trees by Stevens element
from collections import defaultdict
element_trees = defaultdict(list)

for locus, element in locus_element.items():
    tree_file = os.path.join(tree_dir, f"{locus}.treefile")
    if os.path.exists(tree_file):
        with open(tree_file) as f:
            tree_str = f.read().strip()
            if tree_str:
                element_trees[element].append(tree_str)

print(f"  Gene trees by Stevens element:")
for elem in sorted(element_trees.keys()):
    n = len(element_trees[elem])
    print(f"    {elem}: {n} gene trees")

    # Write per-element gene tree files
    outfile = os.path.join(astral_dir, f"gene_trees_element_{elem}.nwk")
    with open(outfile, "w") as f:
        for t in element_trees[elem]:
            f.write(t + "\n")

print(f"\n  Per-element gene tree files written to {astral_dir}/")
print("  Use these for per-element gCF analysis in A.0")
PYEOF2
else
    echo "  WARNING: ${ELEMENT_MAP} not found. Skipping per-element analysis."
fi

# ============================================================================
# 5. SUMMARY
# ============================================================================

echo ""
echo "============================================================"
echo "P.6 COMPLETE"
echo "============================================================"
echo "  ASTRAL species tree: ${ROOTED_TREE}"
echo "  Concordance factors: ${CF_PREFIX}.cf.stat"
echo "  Annotated tree: ${CF_PREFIX}.cf.tree"
echo "  Per-element gene trees: ${ASTRAL_DIR}/gene_trees_element_*.nwk"
echo ""
echo "NEXT STEPS:"
echo "  P.7: Check concatenation tree (may already be running)"
echo "  P.8: Compare ASTRAL vs concatenation → finalize rearrangement tree"
echo "============================================================"
echo "Finished: $(date)"
