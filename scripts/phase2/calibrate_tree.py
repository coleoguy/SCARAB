#!/usr/bin/env python3
"""
calibrate_tree.py
Assign approximate divergence-time branch lengths to the SCARAB constraint tree
using McKenna et al. (2019) and other calibrated beetle phylogeny estimates.

Input:  constraint_tree.nwk (uniform branch lengths = 1.0)
        tree_tip_mapping.csv
Output: constraint_tree_calibrated.nwk (approximate Ma branch lengths)
"""

import csv
import sys
# sys.path may need adjustment for your environment
from ete3 import Tree

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # SCARAB project root

# Load tree
tree = Tree(f"{BASE}/data/genomes/constraint_tree.nwk", format=1)
print(f"Tree tips: {len(tree.get_leaves())}")
print(f"Internal nodes: {len(tree.get_descendants()) - len(tree.get_leaves())}")

# Load tip mapping
tip_info = {}
with open(f"{BASE}/data/genomes/tree_tip_mapping.csv") as f:
    reader = csv.DictReader(f)
    for row in reader:
        tip_info[row['tip_label']] = row

print(f"Tip mapping entries: {len(tip_info)}")

# Verify all tips are mapped
tree_tips = set(l.name for l in tree.get_leaves())
mapped_tips = set(tip_info.keys())
missing = tree_tips - mapped_tips
print(f"Tips missing from mapping: {len(missing)}")

# -------------------------------------------------------------------
# McKenna et al. (2019) approximate divergence times (Ma)
# -------------------------------------------------------------------
# Root: Coleoptera + Neuropterida split ~320 Ma
# Coleoptera crown: ~268 Ma
# Neuropterida MRCA: ~300 Ma
# Suborder/series crowns and family crowns below

# Build tip -> attribute lookups
def get_tips_by(column, value):
    return [name for name, info in tip_info.items()
            if info.get(column) == value and name in tree_tips]

# Calibration points: (column, value, age_Ma)
calibrations = [
    # Major clade MRCAs
    ("clade", "Adephaga", 215),
    ("clade", "Cucujiformia", 195),
    ("clade", "Scarabaeiformia", 175),
    ("clade", "Staphyliniformia", 185),
    ("clade", "Elateriformia", 190),
    ("role", "outgroup", 300),  # Neuropterida

    # Family-level crowns
    ("family", "Carabidae", 160),
    ("family", "Chrysomelidae", 100),
    ("family", "Cerambycidae", 120),
    ("family", "Curculionidae", 115),
    ("family", "Coccinellidae", 80),
    ("family", "Scarabaeidae", 120),
    ("family", "Lucanidae", 90),
    ("family", "Staphylinidae", 140),
    ("family", "Tenebrionidae", 130),
    ("family", "Cantharidae", 110),
    ("family", "Elateridae", 130),
    ("family", "Lampyridae", 100),
    ("family", "Geotrupidae", 130),
    ("family", "Silphidae", 120),
    ("family", "Corydalidae", 180),
    ("family", "Chrysopidae", 150),
    ("family", "Hydrophilidae", 140),
    ("family", "Leiodidae", 130),
    ("family", "Buprestidae", 140),
    ("family", "Meloidae", 90),
    ("family", "Anthribidae", 100),
]

# Assign ages to MRCA nodes
# We'll store ages as node features
# First, set root age
tree.add_feature("age", 320.0)

# Set Coleoptera crown
ingroup_tips = get_tips_by("role", "ingroup")
if len(ingroup_tips) >= 2:
    cole_mrca = tree.get_common_ancestor(ingroup_tips)
    cole_mrca.add_feature("age", 268.0)
    print(f"Coleoptera MRCA age: 268 Ma ({len(ingroup_tips)} tips)")

assigned = 0
for col, val, age in calibrations:
    tips = get_tips_by(col, val)
    if len(tips) >= 2:
        try:
            mrca = tree.get_common_ancestor(tips)
            mrca.add_feature("age", float(age))
            assigned += 1
        except Exception as e:
            print(f"  Warning: could not find MRCA for {col}={val}: {e}")

print(f"Assigned calibration ages to {assigned} nodes")

# -------------------------------------------------------------------
# Interpolate missing internal node ages
# Top-down traversal: for each uncalibrated internal node,
# place it midway between parent age and oldest calibrated child age
# -------------------------------------------------------------------

# Set tip ages to 0
for leaf in tree.get_leaves():
    leaf.add_feature("age", 0.0)

# Top-down interpolation
for node in tree.traverse("preorder"):
    if node.is_leaf():
        continue
    if not hasattr(node, "age") or node.age is None:
        # Get parent age
        if node.is_root():
            parent_age = 320.0
        else:
            parent_age = getattr(node.up, "age", 320.0) or 320.0

        # Get max child age (among calibrated children)
        child_ages = []
        for child in node.children:
            if hasattr(child, "age") and child.age is not None:
                child_ages.append(child.age)
        max_child = max(child_ages) if child_ages else 0.0

        node.add_feature("age", (parent_age + max_child) / 2.0)

# Enforce monotonicity (parent older than child)
for node in tree.traverse("preorder"):
    if node.is_root():
        continue
    parent_age = getattr(node.up, "age", 320.0)
    node_age = getattr(node, "age", 0.0)
    if node_age >= parent_age:
        node.age = parent_age * 0.95

# -------------------------------------------------------------------
# Convert node ages to branch lengths
# branch_length = parent_age - child_age
# -------------------------------------------------------------------
for node in tree.traverse("preorder"):
    if node.is_root():
        node.dist = 0
        continue
    parent_age = getattr(node.up, "age", 320.0)
    node_age = getattr(node, "age", 0.0)
    bl = parent_age - node_age
    node.dist = max(bl, 0.1)  # minimum 0.1 Ma

# -------------------------------------------------------------------
# Summary
# -------------------------------------------------------------------
branch_lengths = [n.dist for n in tree.traverse() if not n.is_root()]
print(f"\n=== Calibrated Tree Summary ===")
print(f"Tips: {len(tree.get_leaves())}")
print(f"Branch length range: {min(branch_lengths):.2f} - {max(branch_lengths):.2f} Ma")
print(f"Mean branch length: {sum(branch_lengths)/len(branch_lengths):.2f} Ma")
print(f"Root age: {tree.age:.2f} Ma")

# Root-to-tip distances
max_dist = max(tree.get_distance(l) for l in tree.get_leaves())
print(f"Max root-to-tip: {max_dist:.2f} Ma")

# Spot checks
for sp in ["Tribolium_castaneum", "Dendroctonus_ponderosae", "Chrysopa_pallens"]:
    leaves = tree.get_leaves_by_name(sp)
    if leaves:
        d = tree.get_distance(leaves[0])
        print(f"  {sp}: {d:.1f} Ma from root")

# Write
out_path = f"{BASE}/data/genomes/constraint_tree_calibrated.nwk"
tree.write(outfile=out_path, format=5)  # format 5: all branch lengths + internal names
print(f"\nCalibrated tree written to: {out_path}")

# Verify
test = Tree(out_path, format=1)
test_bls = [n.dist for n in test.traverse() if not n.is_root()]
print(f"Verification: {len(test.get_leaves())} tips")
print(f"Branch lengths: {min(test_bls):.2f} - {max(test_bls):.2f}")
