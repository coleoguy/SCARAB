#!/usr/bin/env python3
"""
Comprehensive monophyly analysis of 478-tip beetle tree
Against full 1121-taxon genome catalog
"""

import sys
import csv
from collections import defaultdict, Counter
from Bio import Phylo
from io import StringIO

# Paths
TREE_PATH = "/sessions/youthful-sweet-heisenberg/mnt/SCARAB/scarab_478_rooted.nwk"
CATALOG_PATH = "/sessions/youthful-sweet-heisenberg/mnt/SCARAB/data/genomes/genome_catalog.csv"

print("=== MONOPHYLY ANALYSIS FOR 478-TIP BEETLE TREE ===\n")

# ===== READ TREE =====
print(f"Reading tree from: {TREE_PATH}")
tree = Phylo.read(TREE_PATH, "newick")
print(f"Tree summary:")
print(f"  Number of tips: {len(tree.get_terminals())}")

tip_labels = [leaf.name for leaf in tree.get_terminals()]
print(f"  Sample tips (first 10): {', '.join(tip_labels[:10])}\n")

# ===== READ CATALOG =====
print(f"Reading catalog from: {CATALOG_PATH}")
catalog = []
with open(CATALOG_PATH, 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        catalog.append(row)

print(f"Catalog summary:")
print(f"  Number of rows: {len(catalog)}\n")

# ===== STEP 1: MAP TREE TIPS TO CATALOG =====
print("=== STEP 1: MAPPING TREE TIPS TO CATALOG ===\n")

# Build species name -> catalog index mapping (first match only)
species_to_catalog_idx = {}
for idx, row in enumerate(catalog):
    species_name = row['species_name']
    if species_name not in species_to_catalog_idx:
        species_to_catalog_idx[species_name] = idx

# Map each tip
mapping = {}
matched_count = 0
unmatched_tips = []

for tip in tip_labels:
    # Replace underscore with space
    spaced_tip = tip.replace('_', ' ')

    if spaced_tip in species_to_catalog_idx:
        cat_idx = species_to_catalog_idx[spaced_tip]
        cat_row = catalog[cat_idx]

        mapping[tip] = {
            'species_name': spaced_tip,
            'genus': cat_row.get('genus', ''),
            'family': cat_row.get('family', ''),
            'superfamily': cat_row.get('superfamily', ''),
            'suborder': cat_row.get('suborder', ''),
            'order': cat_row.get('order', ''),
        }
        matched_count += 1
    else:
        unmatched_tips.append(tip)
        mapping[tip] = {
            'species_name': spaced_tip,
            'genus': None,
            'family': None,
            'superfamily': None,
            'suborder': None,
            'order': None,
        }

print(f"Mapping results:")
print(f"  Total tips in tree: {len(tip_labels)}")
print(f"  Successfully mapped: {matched_count}")
print(f"  Failed to map: {len(unmatched_tips)}\n")

if unmatched_tips:
    print(f"UNMATCHED TIPS ({len(unmatched_tips)} total):")
    for tip in unmatched_tips:
        print(f"  - {tip}")
    print()
else:
    print("All 478 tips successfully mapped!\n")

# ===== HELPER FUNCTIONS FOR MONOPHYLY =====

def find_mrca_clade(tree, leaf_names):
    """Find the MRCA clade for a set of leaf names."""
    if not leaf_names:
        return None

    # Get all leaf nodes
    leaves = [l for l in tree.find_clades(terminal=True) if l.name in leaf_names]
    if len(leaves) == 0:
        return None

    # For each clade, check if all specified leaves are within it
    for clade in tree.find_clades(order='level'):
        clade_leaves = {l.name for l in clade.get_terminals()}
        # If all specified leaves are in this clade, and none outside are...
        if all(ln in clade_leaves for ln in leaf_names):
            # Check if this is minimal (no child clade also contains all)
            is_minimal = True
            for child in clade.clades:
                child_leaves = {l.name for l in child.get_terminals()}
                if all(ln in child_leaves for ln in leaf_names):
                    is_minimal = False
                    break
            if is_minimal:
                return clade
    return None

def get_clade_terminals(clade):
    """Get all terminal names in a clade."""
    if clade is None:
        return set()
    return {l.name for l in clade.get_terminals()}

def test_monophyly_group(tree, tip_names, group_label):
    """Test if a group of tips is monophyletic."""
    if len(tip_names) < 2:
        return {
            'group': group_label,
            'n_tips': len(tip_names),
            'monophyletic': None,
            'mrca_clade_size': 0,
            'n_intruders': 0,
            'intruders': []
        }

    # Get tips that exist in tree
    valid_tips = [t for t in tip_names if t in [leaf.name for leaf in tree.get_terminals()]]

    if len(valid_tips) < 2:
        return {
            'group': group_label,
            'n_tips': len(valid_tips),
            'monophyletic': None,
            'mrca_clade_size': 0,
            'n_intruders': 0,
            'intruders': []
        }

    # Find MRCA clade
    mrca_clade = find_mrca_clade(tree, valid_tips)
    if mrca_clade is None:
        return {
            'group': group_label,
            'n_tips': len(valid_tips),
            'monophyletic': False,
            'mrca_clade_size': 0,
            'n_intruders': 0,
            'intruders': []
        }

    mrca_tips = get_clade_terminals(mrca_clade)

    # Check monophyly: all tips in MRCA should be from the group
    is_mono = (mrca_tips == set(valid_tips))

    intruders = list(mrca_tips - set(valid_tips))
    intruder_info = []

    if intruders:
        for intruder in sorted(intruders):
            if intruder in mapping:
                fam = mapping[intruder]['family']
                gen = mapping[intruder]['genus']
                if gen and fam:
                    intruder_info.append(f"{gen} ({fam})")
                elif gen:
                    intruder_info.append(gen)

    return {
        'group': group_label,
        'n_tips': len(valid_tips),
        'monophyletic': is_mono,
        'mrca_clade_size': len(mrca_tips),
        'n_intruders': len(intruders),
        'intruders': intruder_info
    }

# ===== STEP 2: TEST EACH TAXONOMIC LEVEL =====
print("=== STEP 2: MONOPHYLY TESTING BY TAXONOMIC LEVEL ===\n")

levels = ['genus', 'family', 'superfamily', 'suborder', 'order']
all_level_results = {}

for level in levels:
    print(f"Testing monophyly at level: {level}")
    print("=" * 50 + "\n")

    # Group tips by this level
    groups_dict = defaultdict(list)
    for tip, info in mapping.items():
        value = info[level]
        if value:
            groups_dict[value].append(tip)

    # Filter to groups with >= 2 tips
    groups_to_test = {k: v for k, v in groups_dict.items() if len(v) >= 2}

    print(f"Number of groups at {level} level: {len(groups_dict)}")
    print(f"Groups with >= 2 tips: {len(groups_to_test)}\n")

    # Test monophyly
    level_results = []
    non_monophyletic_groups = []

    for group_name in sorted(groups_to_test.keys()):
        tip_list = groups_to_test[group_name]
        result = test_monophyly_group(tree, tip_list, group_name)
        level_results.append(result)

        if result['monophyletic'] == False:
            non_monophyletic_groups.append(result)

    all_level_results[level] = {
        'results': level_results,
        'non_monophyletic': non_monophyletic_groups,
        'n_tested': len(groups_to_test)
    }

# ===== STEP 3: REPORT NON-MONOPHYLETIC GROUPS =====
print("\n=== STEP 3: NON-MONOPHYLETIC GROUPS ===")
print("=" * 70 + "\n")

for level in levels:
    non_mono = all_level_results[level]['non_monophyletic']

    if non_mono:
        print(f"Level: {level.upper()} ({len(non_mono)} non-monophyletic groups)")
        print("-" * 70 + "\n")

        for result in non_mono:
            print(f"GROUP: {result['group']}")
            print(f"  Tips in group: {result['n_tips']}")
            print(f"  Tips in MRCA clade: {result['mrca_clade_size']}")
            print(f"  Number of intruders: {result['n_intruders']}")

            if result['intruders']:
                print(f"  Intruding taxa:")
                for intruder in result['intruders']:
                    print(f"    - {intruder}")
            print()
        print()

# ===== STEP 4: SPECIFIC TESTS =====
print("\n=== STEP 4: SPECIFIC GROUP MONOPHYLY TESTS ===")
print("=" * 70 + "\n")

# Helper to find tips by order/suborder
def find_tips_by_field(field, value):
    return [tip for tip, info in mapping.items() if info[field] == value]

# 1. Neuropterida
print("1. NEUROPTERIDA (Neuroptera + Megaloptera + Raphidioptera)")
print("-" * 70)

neuroptera_tips = find_tips_by_field('order', 'Neuroptera')
megaloptera_tips = find_tips_by_field('order', 'Megaloptera')
raphidioptera_tips = find_tips_by_field('order', 'Raphidioptera')
neuropterida_tips = neuroptera_tips + megaloptera_tips + raphidioptera_tips

print(f"Neuroptera tips: {len(neuroptera_tips)}")
print(f"Megaloptera tips: {len(megaloptera_tips)}")
print(f"Raphidioptera tips: {len(raphidioptera_tips)}")
print(f"Total Neuropterida tips: {len(neuropterida_tips)}\n")

result = test_monophyly_group(tree, neuropterida_tips, "Neuropterida")
print(f"GROUP: {result['group']}")
print(f"  Tips in group: {result['n_tips']}")
print(f"  Monophyletic: {result['monophyletic']}")
print(f"  Tips in MRCA clade: {result['mrca_clade_size']}")
print(f"  Number of intruders: {result['n_intruders']}")
if result['intruders']:
    print(f"  Intruding taxa:")
    for intruder in result['intruders']:
        print(f"    - {intruder}")
print("\n")

# 2. Coleoptera
print("2. COLEOPTERA (all)")
print("-" * 70)

coleoptera_tips = find_tips_by_field('order', 'Coleoptera')
print(f"Total Coleoptera tips: {len(coleoptera_tips)}\n")

result = test_monophyly_group(tree, coleoptera_tips, "Coleoptera")
print(f"GROUP: {result['group']}")
print(f"  Tips in group: {result['n_tips']}")
print(f"  Monophyletic: {result['monophyletic']}")
print(f"  Tips in MRCA clade: {result['mrca_clade_size']}")
print(f"  Number of intruders: {result['n_intruders']}")
if result['intruders']:
    print(f"  Intruding taxa:")
    for intruder in result['intruders']:
        print(f"    - {intruder}")
print("\n")

# 3. Adephaga
print("3. ADEPHAGA (suborder)")
print("-" * 70)

adephaga_tips = find_tips_by_field('suborder', 'Adephaga')
print(f"Total Adephaga tips: {len(adephaga_tips)}\n")

result = test_monophyly_group(tree, adephaga_tips, "Adephaga")
print(f"GROUP: {result['group']}")
print(f"  Tips in group: {result['n_tips']}")
print(f"  Monophyletic: {result['monophyletic']}")
print(f"  Tips in MRCA clade: {result['mrca_clade_size']}")
print(f"  Number of intruders: {result['n_intruders']}")
if result['intruders']:
    print(f"  Intruding taxa:")
    for intruder in result['intruders']:
        print(f"    - {intruder}")
print("\n")

# 4. Polyphaga
print("4. POLYPHAGA (suborder)")
print("-" * 70)

polyphaga_tips = find_tips_by_field('suborder', 'Polyphaga')
print(f"Total Polyphaga tips: {len(polyphaga_tips)}\n")

result = test_monophyly_group(tree, polyphaga_tips, "Polyphaga")
print(f"GROUP: {result['group']}")
print(f"  Tips in group: {result['n_tips']}")
print(f"  Monophyletic: {result['monophyletic']}")
print(f"  Tips in MRCA clade: {result['mrca_clade_size']}")
print(f"  Number of intruders: {result['n_intruders']}")
if result['intruders']:
    print(f"  Intruding taxa:")
    for intruder in result['intruders']:
        print(f"    - {intruder}")
print("\n")

# 5. Polyphaga series (based on superfamily)
print("5. POLYPHAGA SERIES (based on superfamily)")
print("-" * 70 + "\n")

# Get unique superfamilies in Polyphaga
polyphaga_superfamilies = set()
for tip, info in mapping.items():
    if info['suborder'] == 'Polyphaga' and info['superfamily']:
        polyphaga_superfamilies.add(info['superfamily'])

polyphaga_superfamilies = sorted(polyphaga_superfamilies)

print(f"Polyphaga superfamilies found:")
for sf in polyphaga_superfamilies:
    sf_tips = [t for t, info in mapping.items()
               if info['superfamily'] == sf and info['suborder'] == 'Polyphaga']
    print(f"  {sf}: {len(sf_tips)} tips")
print()

print(f"Testing monophyly of Polyphaga superfamilies:")
for sf in polyphaga_superfamilies:
    sf_tips = [t for t, info in mapping.items()
               if info['superfamily'] == sf and info['suborder'] == 'Polyphaga']
    if len(sf_tips) >= 2:
        result = test_monophyly_group(tree, sf_tips, f"Superfamily: {sf}")
        print(f"GROUP: {result['group']}")
        print(f"  Tips: {result['n_tips']}")
        print(f"  Monophyletic: {result['monophyletic']}")
        print(f"  Intruders: {result['n_intruders']}")
        if result['intruders']:
            for intruder in result['intruders'][:5]:  # Show first 5
                print(f"    - {intruder}")
            if len(result['intruders']) > 5:
                print(f"    ... and {len(result['intruders']) - 5} more")
        print()

# ===== STEP 5: SUPERFAMILY ANALYSIS =====
print("\n=== STEP 5: SUPERFAMILY MONOPHYLY SUMMARY ===")
print("=" * 70 + "\n")

# Get all superfamilies
all_superfamilies = set()
for tip, info in mapping.items():
    if info['superfamily']:
        all_superfamilies.add(info['superfamily'])

all_superfamilies = sorted(all_superfamilies)

superfamily_results = []

for sf in all_superfamilies:
    sf_tips = [t for t, info in mapping.items() if info['superfamily'] == sf]

    if len(sf_tips) >= 2:
        result = test_monophyly_group(tree, sf_tips, sf)
        superfamily_results.append(result)

# Sort by monophyly status
superfamily_results.sort(key=lambda x: (x['monophyletic'] != False, x['group']))

print("SUPERFAMILY MONOPHYLY TABLE:")
print("-" * 80)
print(f"{'Superfamily':<30} {'N Tips':>8} {'Monophyletic':>13} {'N Intruders':>12}")
print("-" * 80)

for result in superfamily_results:
    mono_str = "YES" if result['monophyletic'] else "NO"
    intruder_str = "-" if result['monophyletic'] else str(result['n_intruders'])
    print(f"{result['group']:<30} {result['n_tips']:>8} {mono_str:>13} {intruder_str:>12}")

print()

# ===== FINAL SUMMARY =====
print("\n=== FINAL SUMMARY ===")
print("=" * 70 + "\n")

print("Tree statistics:")
print(f"  Total tips: {len(tip_labels)}")
print(f"  Tips successfully mapped: {matched_count}")
print(f"  Mapping success rate: {100*matched_count/len(tip_labels):.1f}%\n")

print("Monophyly summary by level:")
for level in levels:
    n_tested = all_level_results[level]['n_tested']
    non_mono = all_level_results[level]['non_monophyletic']
    n_non_mono = len(non_mono)
    n_mono = n_tested - n_non_mono

    pct = 100 * n_non_mono / n_tested if n_tested > 0 else 0
    print(f"  {level:<15}: {n_tested:>3} tested, {n_mono:>3} monophyletic, {n_non_mono:>3} non-monophyletic ({pct:>5.1f}%)")

print("\nSuperfamily monophyly:")
n_sf_total = len(superfamily_results)
n_sf_mono = sum(1 for r in superfamily_results if r['monophyletic'])
n_sf_non_mono = sum(1 for r in superfamily_results if not r['monophyletic'])

print(f"  Total superfamilies: {n_sf_total}")
print(f"  Monophyletic: {n_sf_mono} ({100*n_sf_mono/n_sf_total:.1f}%)")
print(f"  Non-monophyletic: {n_sf_non_mono} ({100*n_sf_non_mono/n_sf_total:.1f}%)")

print("\nKey findings:")

# Check major groups
coleoptera_mono = test_monophyly_group(tree, find_tips_by_field('order', 'Coleoptera'), "Coleoptera")['monophyletic']
adephaga_mono = test_monophyly_group(tree, find_tips_by_field('suborder', 'Adephaga'), "Adephaga")['monophyletic']
polyphaga_mono = test_monophyly_group(tree, find_tips_by_field('suborder', 'Polyphaga'), "Polyphaga")['monophyletic']

print(f"  Coleoptera monophyletic: {coleoptera_mono}")
print(f"  Adephaga monophyletic: {adephaga_mono}")
print(f"  Polyphaga monophyletic: {polyphaga_mono}")

print("\nAnalysis complete.")
