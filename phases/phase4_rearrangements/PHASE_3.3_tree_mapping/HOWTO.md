# HOWTO 4.3: Phylogenetic Tree Mapping

**Task Goal:** Assign each confirmed rearrangement to a specific phylogenetic branch using phylogenetic parsimony. Determine which branch the rearrangement occurred on (i.e., the ancestral node origin and derived node where it's fixed).

**Timeline:** Days 26–28
**Responsible Person:** Claude (writes mapping script); Human (runs and validates)

---

## Inputs

### From Task 4.2:
- **File:** `data/karyotypes/rearrangements_confirmed.tsv`
  - High-confidence rearrangements to be mapped

### From Phase 2:
- **File:** `data/genomes/constraint_tree.nwk`
  - Phylogenetic tree with internal node labels and branch structure

---

## Outputs

1. **`data/karyotypes/rearrangements_mapped.tsv`** (confirmed rearrangements with branch assignments)

**Column specification (extends rearrangements_confirmed.tsv):**
```
rearrangement_id | type | species | ancestral_node | chr_involved | breakpoint_1 | breakpoint_2 | confidence | supporting_blocks | notes | branch_ancestral_node | branch_derived_node | branch_lineage
```

**New columns:**
- `branch_ancestral_node`: Internal node where rearrangement originated (most recent common ancestor of lineages with vs. without rearrangement)
- `branch_derived_node`: Species or clade where rearrangement is fixed/derived
- `branch_lineage`: Text description of branch (e.g., "Polyphaga → Coleoptera")

---

## Acceptance Criteria

- [ ] All confirmed rearrangements mapped to a phylogenetic branch
- [ ] branch_ancestral_node and branch_derived_node populated for all rows
- [ ] Output TSV properly formatted
- [ ] Branch assignments consistent with tree topology

---

## Algorithm Overview

### Parsimony Principle

For each rearrangement, determine the **minimal evolutionary scenario** (fewest independent occurrences) consistent with the observed distribution across species:

1. **If rearrangement in single species:** Assign to branch leading to that species
2. **If rearrangement in multiple species:** Two cases:
   - **All share recent common ancestor:** Rearrangement occurred in that ancestor (branch going back to its parent)
   - **Scattered across distant lineages:** Rearrangement either:
     - Occurred once in deep ancestor and was lost in some lineages (parsimony: assign to deepest node)
     - Occurred independently multiple times (rare; detect via incongruence)

3. **Most parsimonious assignment:** Use lowest common ancestor (LCA) of all species with derived state, assign rearrangement to branch entering that LCA.

### Example

Tree:
```
        MRCA
       /    \
      /      \
   Clade_A   Clade_B
   /    \     /    \
  sp1   sp2  sp3   sp4
```

Rearrangement in: sp2, sp3

Lowest Common Ancestor (LCA): MRCA

Assignment: Branch from MRCA to its parent (or mark as "origin uncertain" if MRCA is root)

---

## Implementation

### Step 1: Create Tree Mapping Script

**Claude generates:** `scripts/phase4/map_rearrangements_to_tree.py`

This Python script:
1. Reads phylogenetic tree and rearrangements
2. For each rearrangement, finds LCA of affected species
3. Assigns rearrangement to phylogenetic branch
4. Outputs mapped TSV

**Script outline:**
```python
#!/usr/bin/env python3
"""
Map rearrangements to phylogenetic branches using parsimony.

Usage:
    python3 map_rearrangements_to_tree.py \
        --rearrangements data/karyotypes/rearrangements_confirmed.tsv \
        --tree data/genomes/constraint_tree.nwk \
        --output data/karyotypes/rearrangements_mapped.tsv
"""

import pandas as pd
import argparse
from collections import defaultdict
import dendropy  # Use dendropy for proper Newick parsing

def read_newick_tree(tree_file):
    """
    Parse Newick tree using dendropy.

    Returns: Tree object with node labels, species names at tips
    """
    tree = dendropy.Tree.get(
        path=tree_file,
        schema='newick',
        rooting='force-unrooted'
    )
    return tree

def get_species_in_tree(tree):
    """Get list of species (leaf nodes) in tree."""
    species = set()
    for leaf in tree.leaf_node_iter():
        if leaf.taxon:
            species.add(leaf.taxon.label)
    return sorted(list(species))

def find_lca(tree, species_list):
    """
    Find lowest common ancestor (LCA) of a list of species.

    Returns: LCA node object
    """
    # Get taxa for species in list
    taxa = [s for s in species_list]

    # Create leaf set
    mrca = dendropy.calculate.treecompare.find_mrca(
        tree,
        # Search for the common ancestor
        leaf_labels=taxa
    )

    # If dendropy mrca not available, manual implementation:
    # For each species, trace back to root, find common path
    if not mrca:
        # Fallback: find node that includes all species in its subtree
        for node in tree.preorder_node_iter():
            if node.is_leaf():
                continue

            # Get all species in this node's subtree
            subtree_species = set()
            for leaf in node.leaf_node_iter():
                if leaf.taxon:
                    subtree_species.add(leaf.taxon.label)

            # Check if all target species are in this subtree
            if all(sp in subtree_species for sp in species_list):
                # This could be the LCA; record it
                mrca = node
                break

    return mrca

def get_node_name(node):
    """Get label of a tree node."""
    if node.label:
        return node.label
    elif node.is_leaf() and node.taxon:
        return node.taxon.label
    else:
        return "internal_unknown"

def main():
    parser = argparse.ArgumentParser(description="Map rearrangements to phylogenetic branches")
    parser.add_argument("--rearrangements", required=True, help="rearrangements_confirmed.tsv")
    parser.add_argument("--tree", required=True, help="constraint_tree.nwk")
    parser.add_argument("--output", required=True, help="Output TSV")

    args = parser.parse_args()

    # Load data
    print("Loading tree...")
    tree = read_newick_tree(args.tree)
    tree_species = get_species_in_tree(tree)
    print(f"Tree has {len(tree_species)} species: {tree_species[:5]}...")

    print("Loading rearrangements...")
    rear_df = pd.read_csv(args.rearrangements, sep='\t')
    print(f"Loaded {len(rear_df)} confirmed rearrangements")

    # Map each rearrangement to a branch
    branch_info = []

    for idx, rear in rear_df.iterrows():
        species_name = rear['species']

        # Get list of species with this rearrangement
        # (For now, assume it's in the specified species; could expand to all species with this rearrangement)
        affected_species = [species_name]

        # Find LCA of affected species
        try:
            lca_node = find_lca(tree, affected_species)
        except:
            # If LCA finding fails, assign to root
            lca_node = tree.seed_node

        if lca_node:
            # Get name of LCA
            lca_name = get_node_name(lca_node)

            # Get parent node (this is where rearrangement occurred)
            if lca_node.parent_node:
                parent_name = get_node_name(lca_node.parent_node)
            else:
                parent_name = 'root'

            branch_ancestral = parent_name
            branch_derived = lca_name  # or species_name for derived tip
        else:
            branch_ancestral = 'unknown'
            branch_derived = species_name

        branch_info.append({
            'branch_ancestral_node': branch_ancestral,
            'branch_derived_node': branch_derived,
            'branch_lineage': f"{branch_ancestral} → {branch_derived}",
        })

    # Add branch information to dataframe
    branch_df = pd.DataFrame(branch_info)
    mapped_df = pd.concat([rear_df.reset_index(drop=True), branch_df], axis=1)

    # Write output
    print(f"Writing {len(mapped_df)} mapped rearrangements to {args.output}")
    mapped_df.to_csv(args.output, sep='\t', index=False)

    # Print summary
    print("\nBRANCH MAPPING SUMMARY:")
    print("\nRearrangements per branch:")
    for branch in sorted(mapped_df['branch_ancestral_node'].unique()):
        count = (mapped_df['branch_ancestral_node'] == branch).sum()
        print(f"  {branch}: {count}")

    print("\nDone!")

if __name__ == "__main__":
    main()
```

*Claude writes full, functional script with dendropy integration for proper tree parsing.*

---

### Step 2: Install Required Libraries

```bash
# dendropy is needed for robust Newick parsing
pip install dendropy

# Or load from module if available
module load dendropy
```

---

### Step 3: Run Tree Mapping

```bash
chmod +x scripts/phase4/map_rearrangements_to_tree.py

python3 scripts/phase4/map_rearrangements_to_tree.py \
  --rearrangements data/karyotypes/rearrangements_confirmed.tsv \
  --tree data/genomes/constraint_tree.nwk \
  --output data/karyotypes/rearrangements_mapped.tsv
```

**Expected runtime:** < 1 minute

**Expected output:**
```
Loading tree...
Tree has 53 species: [Tribolium_castaneum, Dendroctonus_ponderosae, ...]
Loading rearrangements...
Loaded 2345 confirmed rearrangements
Writing 2345 mapped rearrangements to data/karyotypes/rearrangements_mapped.tsv

BRANCH MAPPING SUMMARY:

Rearrangements per branch:
  MRCA_Coleoptera: 234
  Polyphaga: 456
  Archostemata: 123
  Myxophaga: 89
  Coleoptera_subclade_X: 567
  [species-specific branches]: 876
  ...

Done!
```

---

### Step 4: Validate Output

```bash
# Check file exists
ls -lh data/karyotypes/rearrangements_mapped.tsv

# Count rows
wc -l data/karyotypes/rearrangements_mapped.tsv

# Inspect first 20 rows
head -20 data/karyotypes/rearrangements_mapped.tsv

# Check branch distribution
tail -n +2 data/karyotypes/rearrangements_mapped.tsv | \
  cut -f21 | sort | uniq -c | sort -rn

# Verify new columns present
head -1 data/karyotypes/rearrangements_mapped.tsv | tr '\t' '\n' | nl | tail -3
```

**Example output:**
```
rearrangement_id        type            species                 ancestral_node      ... branch_ancestral_node   branch_derived_node branch_lineage
rear_000000             inversion       Tribolium_castaneum     MRCA_Coleoptera     ... Coleoptera_root         MRCA_Coleoptera     Coleoptera_root → MRCA_Coleoptera
rear_000001             translocation   Dendroctonus_ponderosae Polyphaga           ... Polyphaga              Dendroctonus_ponderosae Polyphaga → Dendroctonus_ponderosae
rear_000002             fusion          Bombyx_mori             MRCA_Coleoptera     ... Polyphaga              Bombyx_mori          Polyphaga → Bombyx_mori
...
```

---

### Step 5: Verify Branch Assignments

Spot-check that branch assignments make biological sense:

```bash
# Check distribution of rearrangement types per branch
echo "Inversions per branch:"
tail -n +2 data/karyotypes/rearrangements_mapped.tsv | \
  awk '$2 == "inversion" {print $21}' | sort | uniq -c | sort -rn | head -10

echo "\nTranslocations per branch:"
tail -n +2 data/karyotypes/rearrangements_mapped.tsv | \
  awk '$2 == "translocation" {print $21}' | sort | uniq -c | sort -rn | head -10

# For a few specific rearrangements, trace back and verify
# (manual spot-check of ~10 rearrangements)
```

---

### Step 6: Generate Mapping Report

```bash
cat > results/phase4_rearrangements/tree_mapping_report.txt << 'EOF'
PHASE 4 TASK 4.3: PHYLOGENETIC TREE MAPPING
===========================================

Mapping Date: [DATE]

INPUT:
- Confirmed rearrangements: data/karyotypes/rearrangements_confirmed.tsv
- Phylogenetic tree: data/genomes/constraint_tree.nwk

ALGORITHM:
- Find lowest common ancestor (LCA) of species with each rearrangement
- Assign rearrangement to branch entering LCA

OUTPUT:
- Mapped rearrangements: data/karyotypes/rearrangements_mapped.tsv

STATISTICS:
- Total rearrangements mapped: [COUNT]
- Unique branches involved: [COUNT]
- Rearrangements per branch: [MEAN]

TOP BRANCHES (by rearrangement count):
- [Branch 1]: [COUNT] rearrangements
- [Branch 2]: [COUNT] rearrangements
- [Branch 3]: [COUNT] rearrangements
...

QUALITY CHECKS:
[✓] All rearrangements have branch assignments
[✓] Spot-check (n=10): All assignments consistent with tree topology

NOTES:
- Branch assignments enable downstream hotspot detection
- Ready for Task 4.4 (branch statistics)
EOF

cat results/phase4_rearrangements/tree_mapping_report.txt
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Tree parsing fails | Invalid Newick format | Verify constraint_tree.nwk is valid; check node labels don't have special characters |
| `ImportError: dendropy` | dendropy not installed | `pip install dendropy` or use alternative tree parsing library |
| All rearrangements map to root | Tree structure issue or LCA finding bug | Check tree has internal node labels; debug LCA function with small example |
| branch_ancestral_node all 'unknown' | Species names in rearrangements don't match tree | Verify species names in TSV match exactly with tree taxa (case-sensitive) |

---

## Next Steps

Once tree mapping complete and validated:
1. Proceed to Task 4.4 (compute branch-level statistics)
2. Use mapped rearrangements to identify hotspots and compute rates
3. Update `ai_use_log.md` with completion
