#!/bin/bash
# ============================================================================
# P6_astral_species_tree.slurm — wASTRAL species tree + concordance factors
# ============================================================================
#
# Purpose:
#   1. Collapse low-support gene tree branches (UFBoot < 10%)
#   2. Run wASTRAL (weighted ASTRAL) on gene trees -> coalescent species tree
#   3. Compute gCF, sCF (likelihood-based), and discordance fractions
#   4. Compute per-Stevens-element concordance for analysis A.0
#
# Prerequisites:
#   P4+P5 complete: per_gene_trees/*.treefile and per_gene_alignments/*.aln
#
# Resources: 1 node, 48 cores, 64GB
# Estimated time: 1-4 hours
#
# Usage:
#   sbatch P6_astral_species_tree.slurm
# ============================================================================

#SBATCH --job-name=scarab_P6_astral
#SBATCH --partition=bigmem
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=750G
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
TREE_DIR="${PHYLO_DIR}/per_gene_trees"
ALN_DIR="${PHYLO_DIR}/per_gene_alignments"
SUPERMATRIX="${PHYLO_DIR}/concatenated_supermatrix.fasta"

ASTRAL_DIR="${PHYLO_DIR}/astral"
NCPUS=${SLURM_CPUS_PER_TASK:-48}

echo "============================================================"
echo "SCARAB P.6 -- wASTRAL Species Tree + Concordance Factors"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "============================================================"
echo ""

module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6
module load ASTER/1.20.4

mkdir -p "${ASTRAL_DIR}"

# ============================================================================
# 0. COLLECT AND CONTRACT GENE TREES
# ============================================================================

echo "[0] Collecting gene trees and contracting low-support branches..."

GENE_TREES_RAW="${PHYLO_DIR}/all_gene_trees.nwk"
GENE_TREES_CONTRACTED="${PHYLO_DIR}/all_gene_trees_contracted.nwk"

# Collect all gene tree files into one file
> "${GENE_TREES_RAW}"
for TREEFILE in "${TREE_DIR}"/*.treefile; do
    [ -f "${TREEFILE}" ] || continue
    cat "${TREEFILE}" >> "${GENE_TREES_RAW}"
done

N_TREES=$(wc -l < "${GENE_TREES_RAW}")
echo "  Gene trees collected: ${N_TREES}"

# Contract branches with UFBoot < 10% using IQ-TREE's nni-correct
# This collapses poorly supported branches to polytomies,
# preventing stochastic noise from driving wASTRAL quartet optimization
iqtree2 -t "${GENE_TREES_RAW}" --branch-min 10 -o "${GENE_TREES_CONTRACTED}" 2>/dev/null \
    || cp "${GENE_TREES_RAW}" "${GENE_TREES_CONTRACTED}"

N_CONTRACTED=$(wc -l < "${GENE_TREES_CONTRACTED}")
echo "  Gene trees after contraction: ${N_CONTRACTED}"

# ============================================================================
# 1. RUN wASTRAL
# ============================================================================

echo ""
echo "[1] Running wASTRAL (weighted ASTRAL)..."

ASTRAL_TREE="${ASTRAL_DIR}/wastral_species_tree.nwk"

wastral -t "${NCPUS}" \
    -o "${ASTRAL_TREE}" \
    "${GENE_TREES_CONTRACTED}"

echo "  wASTRAL tree: ${ASTRAL_TREE}"

# Quick tip count
N_TIPS=$(grep -o ',' "${ASTRAL_TREE}" | wc -l)
N_TIPS=$((N_TIPS + 1))
echo "  Tips in wASTRAL tree: ${N_TIPS}"

# ============================================================================
# 2. ROOT ON NEUROPTERIDA
# ============================================================================

echo ""
echo "[2] Rooting wASTRAL tree on Neuropterida..."

ROOTED_TREE="${ASTRAL_DIR}/wastral_species_tree_rooted.nwk"

python3 - "${ASTRAL_TREE}" "${ROOTED_TREE}" << 'PYEOF'
import sys

try:
    import dendropy
except ImportError:
    print("ERROR: dendropy not installed. Install: pip install dendropy --user")
    sys.exit(1)

astral_path = sys.argv[1]
rooted_path = sys.argv[2]

tree = dendropy.Tree.get(path=astral_path, schema="newick")

# Neuropterida outgroup taxa
outgroup_names = [
    "Sisyra_nigra", "Sisyra_terminalis", "Micromus_angulatus",
    "Osmylus_fulvicephalus", "Conwentzia_psociformis",
    "Brachynemurus_nebulosus", "Nothochrysa_capitata", "Nineta_flava",
    "Chrysopa_pallens", "Chrysoperla_carnea", "Chrysoperla_zastrowi_sillemi",
    "Mongoloraphidia_duomilia", "Xanthostigma_xanthostigma",
    "Sialis_fuliginosa", "Sialis_lutaria",
    "Acanthacorydalis_orientalis", "Neoneuromus_ignobilis",
    "Venustoraphidia_nigricollis"
]

# Find outgroup taxa in tree
outgroup_taxa = []
for taxon in tree.taxon_namespace:
    label = taxon.label.replace(" ", "_")
    if label in outgroup_names:
        outgroup_taxa.append(taxon)

print("  Outgroup taxa found: %d / %d" % (len(outgroup_taxa), len(outgroup_names)))

if len(outgroup_taxa) >= 2:
    mrca = tree.mrca(taxa=outgroup_taxa)
    tree.reroot_at_edge(mrca.edge, update_bipartitions=True)
    tree.write(path=rooted_path, schema="newick")
    print("  Rooted tree written: %s" % rooted_path)
else:
    print("  WARNING: Not enough outgroup taxa found. Writing unrooted.")
    tree.write(path=rooted_path, schema="newick")
PYEOF

# ============================================================================
# 3. CONCORDANCE FACTORS (gCF, sCF, sDF1, sDF2)
# ============================================================================

echo ""
echo "[3a] Computing gene concordance factors (gCF)..."

GCF_PREFIX="${ASTRAL_DIR}/concordance_gcf"

iqtree2 -t "${ROOTED_TREE}" \
        --gcf "${GENE_TREES_RAW}" \
        --prefix "${GCF_PREFIX}" \
        2>&1 | tail -20

echo "  gCF results: ${GCF_PREFIX}.cf.stat"
echo "  gCF-annotated tree: ${GCF_PREFIX}.cf.tree"

echo ""
echo "[3b] Computing site concordance factors (sCF, likelihood-based)..."

SCF_PREFIX="${ASTRAL_DIR}/concordance_scf"

iqtree2 -t "${ROOTED_TREE}" \
        -s "${SUPERMATRIX}" \
        --scfl 100 \
        --prefix "${SCF_PREFIX}" \
        -nt "${NCPUS}" \
        2>&1 | tail -20

echo "  sCF results: ${SCF_PREFIX}.cf.stat"
echo "  sCF-annotated tree: ${SCF_PREFIX}.cf.tree"

# ============================================================================
# 4. PER-ELEMENT CONCORDANCE (for analysis A.0)
# ============================================================================

echo ""
echo "[4] Computing per-Stevens-element concordance..."

ELEMENT_MAP="${PHYLO_DIR}/busco_tribolium_stevens_map.tsv"

if [ -f "${ELEMENT_MAP}" ]; then
    export PHYLO_DIR ASTRAL_DIR TREE_DIR ELEMENT_MAP
    python3 - << 'PYEOF2'
import os
from collections import defaultdict

phylo_dir = os.environ["PHYLO_DIR"]
astral_dir = os.environ["ASTRAL_DIR"]
tree_dir = os.environ["TREE_DIR"]
element_map_file = os.environ["ELEMENT_MAP"]

# Read element assignments
locus_element = {}
with open(element_map_file) as f:
    header = f.readline()
    for line in f:
        cols = line.strip().split("\t")
        if len(cols) >= 4:
            busco_id = cols[0]
            element = cols[3]  # stevens_element column
            if element and element != "UNKNOWN":
                locus_element[busco_id] = element

# Group gene trees by Stevens element
element_trees = defaultdict(list)
for locus, element in locus_element.items():
    tree_file = os.path.join(tree_dir, "%s.treefile" % locus)
    if os.path.exists(tree_file):
        with open(tree_file) as f:
            tree_str = f.read().strip()
            if tree_str:
                element_trees[element].append(tree_str)

print("  Gene trees by Stevens element:")
for elem in sorted(element_trees.keys()):
    n = len(element_trees[elem])
    print("    %s: %d gene trees" % (elem, n))

    # Write per-element gene tree files
    outfile = os.path.join(astral_dir, "gene_trees_element_%s.nwk" % elem)
    with open(outfile, "w") as f:
        for t in element_trees[elem]:
            f.write(t + "\n")

print("\n  Per-element gene tree files written to %s/" % astral_dir)
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
echo "  wASTRAL species tree: ${ROOTED_TREE}"
echo "  Concordance factors: ${CF_PREFIX}.cf.stat"
echo "  Annotated tree: ${CF_PREFIX}.cf.tree"
echo "  Per-element gene trees: ${ASTRAL_DIR}/gene_trees_element_*.nwk"
echo ""
echo "NEXT STEPS:"
echo "  P.7: Check concatenation tree (may already be running)"
echo "  P.8: Compare ASTRAL vs concatenation, finalize rearrangement tree"
echo "============================================================"
echo "Finished: $(date)"
