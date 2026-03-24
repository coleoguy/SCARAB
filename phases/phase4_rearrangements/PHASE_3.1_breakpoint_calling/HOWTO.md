# HOWTO 4.1: Breakpoint Calling

**Task Goal:** Identify chromosomal rearrangements (inversions, translocations, fusions, fissions) by comparing gene/block order in extant species versus their inferred ancestral genomes.

**Timeline:** Days 24–26
**Responsible Person:** Claude (writes calling script); Human (runs and reviews)

---

## Inputs

### From Phase 3:
- **File:** `data/synteny/synteny_anchored.tsv`
  - Pairwise synteny blocks with ancestral genome mappings
  - Columns: block_id, species_A, species_B, chr_A, chr_B, start_A, end_A, start_B, end_B, orientation, identity, ancestral_node, ancestral_chr, ancestral_start, ancestral_end, conservation_score

### From Phase 2:
- **File:** `data/genomes/constraint_tree.nwk`
  - Phylogenetic tree with internal node labels

---

## Outputs

1. **`data/karyotypes/rearrangements_raw.tsv`** (raw rearrangement calls before filtering)

**Column specification:**
```
rearrangement_id | type | species | ancestral_node | chr_involved | breakpoint_1 | breakpoint_2 | confidence | supporting_blocks | notes
```

**Column descriptions:**
- `rearrangement_id`: Unique ID (format: `rear_XXXXXX`)
- `type`: Rearrangement class: `inversion`, `translocation`, `fusion`, `fission`
- `species`: Species in which rearrangement occurred (where it's derived/fixed)
- `ancestral_node`: Internal node name (where rearrangement originated; to be refined in Task 4.3)
- `chr_involved`: Chromosome(s) involved (e.g., `chr1,chr2` for translocation; `chr1` for inversion)
- `breakpoint_1`: Genomic position of first breakpoint in species (0-based)
- `breakpoint_2`: Genomic position of second breakpoint in species (0-based)
- `confidence`: Confidence score (0–1) based on supporting evidence
- `supporting_blocks`: Number of synteny blocks supporting this call
- `notes`: Text description of rearrangement

---

## Acceptance Criteria

- [ ] All rearrangements identified from block order changes
- [ ] Each rearrangement has explicit type classification
- [ ] All major rearrangements ≥10 kb detected
- [ ] Output TSV properly formatted
- [ ] Spot-check: Human manually reviews 10 random rearrangements for accuracy

---

## Algorithm Overview

### Rearrangement Detection Strategy

For each extant species, compare its block order on each chromosome to the ancestral genome(s):

1. **Inversion:** Same blocks, same chromosome, but reversed order
   - Ancestral order: block_A → block_B → block_C
   - Derived order: block_A ← block_B → block_C (block_B reversed)
   - Signature: Adjacent blocks have opposite orientation

2. **Translocation:** Blocks move between chromosomes
   - Ancestral: block_A on chr1, block_B on chr1
   - Derived: block_A on chr1, block_B on chr2
   - Signature: Adjacent blocks in ancestor are on different chromosomes in derived

3. **Fusion:** Two ancestral chromosomes merge into one
   - Ancestral: blocks on chr1 and chr2 (separate)
   - Derived: blocks on same chromosome (merged)
   - Signature: Blocks from different ancestral chromosomes are adjacent in derived

4. **Fission:** One ancestral chromosome splits into two
   - Ancestral: blocks on same chromosome
   - Derived: blocks on different chromosomes
   - Signature: Adjacent blocks in ancestor are on different chromosomes in derived

---

## Implementation

### Step 1: Create Breakpoint Calling Script

**Claude generates:** `scripts/phase4/call_rearrangements.py`

This Python script:
1. Reads synteny blocks anchored to ancestral genomes
2. Reconstructs gene/block order on each chromosome for each species
3. Compares derived vs. ancestral order
4. Identifies rearrangement breakpoints and types
5. Assigns confidence scores
6. Outputs TSV

**Script outline:**
```python
#!/usr/bin/env python3
"""
Call chromosomal rearrangements from synteny blocks.

Algorithm:
1. For each extant species and its immediate ancestor
2. Extract block order on each chromosome
3. Compare order between derived and ancestral
4. Identify rearrangement events
5. Classify type (inversion, translocation, fusion, fission)

Usage:
    python3 call_rearrangements.py \
        --blocks data/synteny/synteny_anchored.tsv \
        --tree data/genomes/constraint_tree.nwk \
        --output data/karyotypes/rearrangements_raw.tsv
"""

import pandas as pd
import argparse
from collections import defaultdict
import re

def read_tree(tree_file):
    """Parse Newick tree to get species and internal nodes."""
    with open(tree_file) as f:
        tree_text = f.read()

    # Extract species names (leaf nodes)
    # Simplified regex; real Newick parsing is more complex
    species = re.findall(r'([A-Za-z_0-9]+):', tree_text)
    species = list(set(species))  # Unique

    # Extract internal node names (after closing paren)
    nodes = re.findall(r'\)([A-Za-z_0-9]*)[,:;]', tree_text)
    nodes = [n for n in nodes if n]  # Filter empty

    return species, nodes

def get_block_order(blocks_df, species_name, use_chr='chr_A'):
    """
    Reconstruct block order on each chromosome for a species.

    Returns dict: {chr_name: [(block_id, orientation), ...]}
    """
    # Filter for blocks involving this species
    species_blocks = blocks_df[
        (blocks_df['species_A'] == species_name) |
        (blocks_df['species_B'] == species_name)
    ]

    chr_orders = defaultdict(list)

    for _, block in species_blocks.iterrows():
        # Determine which chromosome is 'species_name'
        if block['species_A'] == species_name:
            chr_name = block['chr_A']
            orientation = block['orientation']
        else:
            chr_name = block['chr_B']
            # Flip orientation if species_B
            orientation = '-' if block['orientation'] == '+' else '+'

        chr_orders[chr_name].append((block['block_id'], orientation))

    # Sort by block coordinates within each chromosome
    for chr_name in chr_orders:
        # Sort by position; ideally use start coordinate
        # For simplicity, assume order in dataframe is positional order
        chr_orders[chr_name] = list(set(chr_orders[chr_name]))

    return dict(chr_orders)

def detect_inversions(derived_order, ancestral_order, blocks_df):
    """Detect inversions: blocks in same order but reversed orientation."""
    inversions = []

    for chr_name in derived_order:
        if chr_name not in ancestral_order:
            continue

        derived_blocks = derived_order[chr_name]
        ancestral_blocks = ancestral_order[chr_name]

        # Check for reversed stretches
        for i in range(len(derived_blocks) - 1):
            block1_id, orient1 = derived_blocks[i]
            block2_id, orient2 = derived_blocks[i + 1]

            # Check if adjacent in ancestor with opposite orientation
            if (block1_id in str(ancestral_blocks) and
                block2_id in str(ancestral_blocks)):

                # This is a simplification; real inversion detection
                # requires more careful sequence comparison

                if orient1 != orient2:
                    # Potential inversion
                    inversions.append({
                        'type': 'inversion',
                        'chr': chr_name,
                        'blocks': [block1_id, block2_id],
                        'confidence': 0.8,
                    })

    return inversions

def detect_translocations(derived_order, ancestral_order):
    """Detect translocations: blocks move between chromosomes."""
    translocations = []

    # For each pair of adjacent blocks in ancestral on same chr
    for chr_name_anc, blocks_anc in ancestral_order.items():
        for i in range(len(blocks_anc) - 1):
            block1_id, _ = blocks_anc[i]
            block2_id, _ = blocks_anc[i + 1]

            # Find these blocks in derived
            chr1_derived = None
            chr2_derived = None

            for chr_name_der, blocks_der in derived_order.items():
                for block_id, _ in blocks_der:
                    if block_id == block1_id:
                        chr1_derived = chr_name_der
                    if block_id == block2_id:
                        chr2_derived = chr_name_der

            # If on different chromosomes in derived, translocation occurred
            if chr1_derived and chr2_derived and chr1_derived != chr2_derived:
                translocations.append({
                    'type': 'translocation',
                    'chrs': [chr1_derived, chr2_derived],
                    'blocks': [block1_id, block2_id],
                    'confidence': 0.7,
                })

    return translocations

def detect_fusions(derived_order, ancestral_order):
    """Detect fusions: blocks from different ancestral chromosomes merge."""
    fusions = []

    # For each derived chromosome
    for chr_name_der, blocks_der in derived_order.items():
        # Find ancestral chromosomes represented
        ancestral_chrs_in_derived = set()

        for block_id, _ in blocks_der:
            # Find which ancestral chromosome this block came from
            for chr_name_anc in ancestral_order:
                if any(b[0] == block_id for b in ancestral_order[chr_name_anc]):
                    ancestral_chrs_in_derived.add(chr_name_anc)
                    break

        # If derived chr contains blocks from 2+ ancestral chromosomes, fusion occurred
        if len(ancestral_chrs_in_derived) >= 2:
            fusions.append({
                'type': 'fusion',
                'derived_chr': chr_name_der,
                'ancestral_chrs': list(ancestral_chrs_in_derived),
                'confidence': 0.75,
            })

    return fusions

def detect_fissions(derived_order, ancestral_order):
    """Detect fissions: blocks from same ancestral chr split into different derived."""
    fissions = []

    # For each ancestral chromosome
    for chr_name_anc, blocks_anc in ancestral_order.items():
        # Find derived chromosomes representing
        derived_chrs = set()

        for block_id, _ in blocks_anc:
            for chr_name_der, blocks_der in derived_order.items():
                if any(b[0] == block_id for b in blocks_der):
                    derived_chrs.add(chr_name_der)
                    break

        # If ancestral chr split into 2+ derived chromosomes, fission occurred
        if len(derived_chrs) >= 2:
            fissions.append({
                'type': 'fission',
                'ancestral_chr': chr_name_anc,
                'derived_chrs': list(derived_chrs),
                'confidence': 0.75,
            })

    return fissions

def main():
    parser = argparse.ArgumentParser(description="Call chromosomal rearrangements")
    parser.add_argument("--blocks", required=True, help="synteny_anchored.tsv")
    parser.add_argument("--tree", required=True, help="constraint_tree.nwk")
    parser.add_argument("--output", required=True, help="Output TSV")

    args = parser.parse_args()

    # Load data
    print("Loading data...")
    blocks_df = pd.read_csv(args.blocks, sep='\t')
    species, internal_nodes = read_tree(args.tree)

    print(f"Found {len(species)} species: {species[:5]}...")
    print(f"Found {len(internal_nodes)} internal nodes: {internal_nodes[:3]}...")

    # For each species, identify rearrangements relative to its immediate ancestor
    all_rearrangements = []
    rear_id_counter = 0

    for species_name in species:
        print(f"Processing {species_name}...")

        # Get block order in this species
        derived_order = get_block_order(blocks_df, species_name)

        # Find most recent common ancestor (next node in tree)
        # Simplified: use all internal nodes as potential ancestors
        # (Real implementation would trace actual lineage)
        for node_name in internal_nodes:
            # Get block order in ancestor
            ancestral_blocks = blocks_df[blocks_df['ancestral_node'] == node_name]

            if len(ancestral_blocks) == 0:
                continue

            ancestral_order = {}
            for _, block in ancestral_blocks.iterrows():
                chr_name = block['ancestral_chr']
                if chr_name not in ancestral_order:
                    ancestral_order[chr_name] = []
                ancestral_order[chr_name].append((block['block_id'], '+'))

            # Detect rearrangements
            inversions = detect_inversions(derived_order, ancestral_order, blocks_df)
            translocations = detect_translocations(derived_order, ancestral_order)
            fusions = detect_fusions(derived_order, ancestral_order)
            fissions = detect_fissions(derived_order, ancestral_order)

            # Record all rearrangements
            for rear in inversions + translocations + fusions + fissions:
                rear['rearrangement_id'] = f"rear_{rear_id_counter:06d}"
                rear['species'] = species_name
                rear['ancestral_node'] = node_name
                rear['supporting_blocks'] = len(rear.get('blocks', []))

                all_rearrangements.append(rear)
                rear_id_counter += 1

    # Convert to DataFrame and output
    print(f"Found {len(all_rearrangements)} rearrangement candidates")

    output_rows = []
    for rear in all_rearrangements:
        output_rows.append({
            'rearrangement_id': rear['rearrangement_id'],
            'type': rear['type'],
            'species': rear['species'],
            'ancestral_node': rear['ancestral_node'],
            'chr_involved': ','.join(rear.get('chrs', rear.get('ancestral_chrs', rear.get('derived_chrs', rear.get('chr', ''))))),
            'breakpoint_1': '-1',  # Placeholder; real breakpoint coordinate
            'breakpoint_2': '-1',
            'confidence': rear.get('confidence', 0.5),
            'supporting_blocks': rear.get('supporting_blocks', 0),
            'notes': f"{rear['type']} involving {rear.get('chrs', rear.get('ancestral_chrs', rear.get('derived_chrs', [])))}",
        })

    output_df = pd.DataFrame(output_rows)
    output_df.to_csv(args.output, sep='\t', index=False)

    print(f"Wrote {len(output_df)} rearrangements to {args.output}")

    # Summary
    print("\nREARRANGEMENT SUMMARY:")
    for rtype in ['inversion', 'translocation', 'fusion', 'fission']:
        count = (output_df['type'] == rtype).sum()
        print(f"  {rtype}: {count}")

if __name__ == "__main__":
    main()
```

*Claude writes full, functional script with all rearrangement type detections.*

---

### Step 2: Prepare Input Files

```bash
cd SCARAB

# Verify inputs exist
ls -lh data/synteny/synteny_anchored.tsv
ls -lh data/genomes/constraint_tree.nwk

# Create output directory
mkdir -p data/karyotypes results/phase4_rearrangements
```

---

### Step 3: Run Breakpoint Calling

```bash
chmod +x scripts/phase4/call_rearrangements.py

python3 scripts/phase4/call_rearrangements.py \
  --blocks data/synteny/synteny_anchored.tsv \
  --tree data/genomes/constraint_tree.nwk \
  --output data/karyotypes/rearrangements_raw.tsv
```

**Expected runtime:** 5–15 minutes

**Expected output:**
```
Loading data...
Found 53 species: [Tribolium_castaneum, Dendroctonus_ponderosae, ...]
Found 8 internal nodes: [MRCA_Coleoptera, Polyphaga, ...]
Processing Tribolium_castaneum...
Processing Dendroctonus_ponderosae...
...
Found 4567 rearrangement candidates
Wrote 4567 rearrangements to data/karyotypes/rearrangements_raw.tsv

REARRANGEMENT SUMMARY:
  inversion: 2345
  translocation: 890
  fusion: 654
  fission: 678
```

---

### Step 4: Validate Output

```bash
# Check file exists
ls -lh data/karyotypes/rearrangements_raw.tsv

# Count rearrangements
wc -l data/karyotypes/rearrangements_raw.tsv

# Inspect first 20 rows
head -20 data/karyotypes/rearrangements_raw.tsv

# Check rearrangement type distribution
tail -n +2 data/karyotypes/rearrangements_raw.tsv | cut -f2 | sort | uniq -c

# Check confidence distribution
tail -n +2 data/karyotypes/rearrangements_raw.tsv | cut -f8 | sort -n

# Verify columns
head -1 data/karyotypes/rearrangements_raw.tsv | tr '\t' '\n' | nl
```

**Example output:**
```
rearrangement_id        type            species                 ancestral_node      chr_involved    breakpoint_1    breakpoint_2    confidence  supporting_blocks   notes
rear_000000             inversion       Tribolium_castaneum     MRCA_Coleoptera     chr1            -1              -1              0.8         2                   inversion involving ['chr1']
rear_000001             translocation   Dendroctonus_ponderosae Polyphaga           chr1,chr2       -1              -1              0.7         2                   translocation involving ['chr1', 'chr2']
rear_000002             fusion          Bombyx_mori             MRCA_Coleoptera     chr1            -1              -1              0.75        3                   fusion involving ['chr1', 'chr2']
...
```

---

### Step 5: Spot-Check Random Rearrangements

Manually inspect 10 random rearrangements to assess accuracy:

```bash
# Extract 10 random rows
tail -n +2 data/karyotypes/rearrangements_raw.tsv | \
  shuf -n 10 > /tmp/sample_rearrangements.tsv

# Review each
cat /tmp/sample_rearrangements.tsv

# For each, manually verify by checking:
# 1. Are the supporting blocks actually adjacent in extant?
# 2. Are they in different order in ancestor?
# 3. Is the type assignment correct?
```

---

### Step 6: Generate Calling Report

```bash
cat > results/phase4_rearrangements/breakpoint_calling_report.txt << 'EOF'
PHASE 4 TASK 4.1: BREAKPOINT CALLING
====================================

Calling Date: [DATE]

INPUT:
- Synteny blocks: data/synteny/synteny_anchored.tsv
- Tree: data/genomes/constraint_tree.nwk

ALGORITHM:
- Compare block order in extant vs. ancestral genomes
- Classify rearrangements by type
- Compute confidence scores

OUTPUT:
- Raw rearrangements: data/karyotypes/rearrangements_raw.tsv

STATISTICS:
- Total rearrangements called: [COUNT]
- By type:
  - Inversions: [COUNT]
  - Translocations: [COUNT]
  - Fusions: [COUNT]
  - Fissions: [COUNT]

QUALITY CHECKS:
- Spot-check (n=10 random): [RESULT - all correct / some issues]
- All rearrangements >= 10kb: [YES/NO]

NOTES:
- [Human notes on quality]
- Ready for filtering in Task 4.2

NEXT STEPS:
- Filter rearrangements by confidence
- Classify as Confirmed / Inferred / Artifact
EOF

cat results/phase4_rearrangements/breakpoint_calling_report.txt
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Script runs but output empty | No rearrangements detected | Check synteny_anchored.tsv has ancestral_node column populated; verify tree has internal node labels |
| Rearrangement counts unrealistically high | Algorithm too sensitive or detecting artifacts | Increase confidence threshold in detection functions; manually review sample |
| Tree parsing fails | Newick format issue | Verify constraint_tree.nwk is valid Newick; use specialized Newick parser (dendropy library) |
| Breakpoint coordinates all -1 | Algorithm didn't compute actual genomic coordinates | Implement proper coordinate extraction from synteny blocks |

---

## Next Steps

Once breakpoint calling complete:
1. Review spot-check results; document quality
2. Proceed to Task 4.2 (rearrangement filtering)
3. Update `ai_use_log.md` with completion
