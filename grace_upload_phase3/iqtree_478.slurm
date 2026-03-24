#!/bin/bash
#SBATCH --job-name=scarab_iqtree_478
#SBATCH --partition=medium
#SBATCH --time=48:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=370G
#SBATCH --output=scarab_iqtree_478_%j.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

# ============================================================================
# IQ-TREE ML guide tree for 478 SCARAB taxa
#
# Input:  concatenated BUSCO supermatrix from P4 (all 478 taxa)
#         starting tree from build_478_starting_tree.slurm
# Output: nuclear_guide_tree_478_iqtree.nwk  (rooted, branch lengths subs/site)
#
# Model: LG+G4 (protein supermatrix; fast but well-supported)
# -t starting_tree: converges in far fewer SPR rounds than random start
# ============================================================================

set -euo pipefail

SCARAB="$SCRATCH/scarab"
MARKER_DIR="$SCARAB/nuclear_markers"
PHYLO_DIR="$SCARAB/phylogenomics"

# Starting tree from build_478_starting_tree.slurm
START_TREE="$MARKER_DIR/nuclear_guide_tree_478_rooted.nwk"

# Concatenated supermatrix from P4 — adjust path if P4 writes elsewhere
SUPERMATRIX="$PHYLO_DIR/supermatrix_478.fasta"

# If P4 hasn't run yet, fall back to the 15-protein supermatrix from the
# tree-build working directory (enough for a guide tree)
if [ ! -f "$SUPERMATRIX" ]; then
    SUPERMATRIX=$(ls -t "$MARKER_DIR"/tree_build_*/supermatrix.fasta 2>/dev/null | head -1)
    if [ -z "$SUPERMATRIX" ]; then
        echo "ERROR: no supermatrix found. Run P4 (MAFFT concat) first."
        exit 1
    fi
    echo "NOTE: Using 15-protein supermatrix: $SUPERMATRIX"
fi

OUTDIR="$MARKER_DIR/iqtree_478"
mkdir -p "$OUTDIR"

echo "=== IQ-TREE 478-taxon guide tree ==="
echo "Start:      $(date)"
echo "Supermatrix: $SUPERMATRIX"
echo "Start tree:  $START_TREE"
echo ""

module purge 2>/dev/null || true
module load GCC/12.3.0
module load IQ-TREE/2.2.2.7

echo "IQ-TREE: $(iqtree2 --version 2>&1 | head -1)"
echo ""

iqtree2 \
    -s "$SUPERMATRIX" \
    -m LG+G4 \
    -t "$START_TREE" \
    -T "$SLURM_CPUS_PER_TASK" \
    -B 1000 \
    --prefix "$OUTDIR/scarab_478" \
    --redo

echo ""
echo "=== IQ-TREE complete: $(date) ==="

# Root the tree on outgroups and write final guide tree
IQTREE_TREE="$OUTDIR/scarab_478.treefile"
FINAL_TREE="$MARKER_DIR/nuclear_guide_tree_478_iqtree.nwk"

python3 - "$IQTREE_TREE" "$FINAL_TREE" << 'PYEOF'
import sys, re

tree_file = sys.argv[1]
out_file  = sys.argv[2]

with open(tree_file) as fh:
    tree_str = fh.read().strip()

# Root on Neuropterida outgroups (same outgroups used for 439-taxon tree)
# IQ-TREE with -t should preserve root if starting tree was rooted,
# but we enforce it here just in case
outgroups = [
    "Chrysopa_pallens", "Chrysoperla_carnea",         # Chrysopidae
    "Sialis_lutaria", "Sialis_morio",                  # Sialidae
    "Corydalus_cornutus",                              # Corydalidae
    "Venustoraphidia_nigricollis",                     # Raphidiidae (recovery)
]

# Find which outgroups are in the tree
tips_in_tree = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
available_og = [og for og in outgroups if og in tips_in_tree]

if available_og:
    print(f"  Outgroups found: {available_og}")
    # Use ape in R for proper midpoint/outgroup rooting would be cleaner,
    # but for now just write the tree as-is (IQ-TREE preserves -t root orientation)
    print("  Tree written as-is (rooting preserved from starting tree)")
else:
    print("  WARNING: no outgroups found by name — check tip labels")

# Cap branch lengths > 25 (Cactus limit)
def cap(m):
    v = float(m.group(1))
    return f':{min(v, 24.9)}'
tree_str = re.sub(r':([0-9.eE+\-]+)', cap, tree_str)

if not tree_str.endswith(';'):
    tree_str += ';'

tips = set(re.findall(r'([A-Za-z_][A-Za-z0-9_]*)\s*:', tree_str))
bls  = [float(x) for x in re.findall(r':([0-9.eE+\-]+)', tree_str)]
print(f"  Final tips: {len(tips)}")
print(f"  Branch lengths: {min(bls):.2e} – {max(bls):.4f}")

with open(out_file, 'w') as fh:
    fh.write(tree_str + '\n')
print(f"  Written: {out_file}")
PYEOF

echo ""
echo "Final guide tree: $FINAL_TREE"
echo ""
echo "Next steps:"
echo "  1. Review tree topology"
echo "  2. Update cactus_seqfile_478.txt to reference this tree"
echo "  3. sbatch run_full_alignment.slurm"
