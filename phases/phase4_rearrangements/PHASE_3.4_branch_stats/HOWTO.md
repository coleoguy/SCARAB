# HOWTO 4.4: Branch-Level Rearrangement Statistics

**Task Goal:** Count rearrangements per branch, normalize by branch length (time), identify evolutionary hotspots (lineages with elevated rearrangement rates), and generate publication-quality visualizations.

**Timeline:** Days 28–29
**Responsible Person:** Claude (writes statistics script); Human (reviews figures)

---

## Inputs

### From Task 4.3:
- **File:** `data/karyotypes/rearrangements_mapped.tsv`
  - All confirmed rearrangements with branch assignments

### From Phase 2:
- **File:** `data/genomes/constraint_tree.nwk`
  - Phylogenetic tree with branch lengths (millions of years)

---

## Outputs

1. **`results/phase4_rearrangements/rearrangements_per_branch.tsv`** (count and statistics by branch)
2. **`results/phase4_rearrangements/branch_stats.csv`** (summary statistics)
3. **`results/phase4_rearrangements/rearrangement_figures.pdf`** (visualizations)

---

## Output Specifications

### rearrangements_per_branch.tsv

**Columns:**
```
branch_ancestral_node | branch_derived_node | rearrangement_count | branch_length_Ma | rearrangement_rate | z_score | is_hotspot | pvalue | inversions | translocations | fusions | fissions
```

**Column descriptions:**
- `branch_ancestral_node`: Parent node in tree
- `branch_derived_node`: Child node (or species)
- `rearrangement_count`: Total rearrangements on this branch
- `branch_length_Ma`: Time duration of branch (millions of years)
- `rearrangement_rate`: Rate = rearrangement_count / branch_length_Ma
- `z_score`: Standardized rate (how many SD above/below mean)
- `is_hotspot`: TRUE if z_score > 2 (statistical significance)
- `pvalue`: Poisson test p-value for excess rearrangements
- `inversions`, `translocations`, `fusions`, `fissions`: Count by type

### branch_stats.csv

**Rows:**
```
Statistic,Value
Total rearrangements,2345
Total branches in tree,104
Mean rearrangement rate (per Ma),0.45
SD rearrangement rate,0.12
Median rearrangement rate,0.38
Hotspot branches (z>2),8
Rearrangement hotspots,Polyphaga,Coleoptera_clade_X,...
```

---

## Acceptance Criteria

- [ ] All branches have rearrangement counts and rates
- [ ] Hotspots identified with statistical significance (z>2 or p<0.05)
- [ ] Figures are clear and publication-ready
- [ ] Results biologically plausible (no negative rates or impossible hotspots)

---

## Implementation

### Step 1: Create Branch Statistics Script

**Claude generates:** `scripts/phase4/compute_branch_statistics.py`

This Python script:
1. Reads mapped rearrangements and tree
2. Counts rearrangements per branch
3. Computes rates (rearrangement / million years)
4. Identifies hotspots via z-score
5. Performs statistical tests (Poisson)
6. Outputs TSV and CSV files

**Script outline:**
```python
#!/usr/bin/env python3
"""
Compute branch-level rearrangement statistics.

Compute rate = rearrangements per million years
Identify hotspots using z-score test

Usage:
    python3 compute_branch_statistics.py \
        --rearrangements data/karyotypes/rearrangements_mapped.tsv \
        --tree data/genomes/constraint_tree.nwk \
        --output results/phase4_rearrangements/
"""

import pandas as pd
import argparse
import numpy as np
from scipy.stats import poisson
from collections import defaultdict
import dendropy

def read_newick_tree(tree_file):
    """Parse Newick tree."""
    tree = dendropy.Tree.get(
        path=tree_file,
        schema='newick',
        rooting='force-unrooted'
    )
    return tree

def get_branch_lengths(tree):
    """
    Extract branch lengths from tree.

    Returns: dict {(parent, child): branch_length_Ma}
    """
    branch_lengths = {}

    for node in tree.preorder_node_iter():
        if node.parent_node is None:
            continue

        # Get names
        child_name = node.label if node.label else (node.taxon.label if node.taxon else 'unknown')
        parent_name = node.parent_node.label if node.parent_node.label else 'root'

        # Get branch length
        edge_length = node.edge_length if node.edge_length else 0.0

        branch_lengths[(parent_name, child_name)] = edge_length

    return branch_lengths

def main():
    parser = argparse.ArgumentParser(description="Compute branch-level rearrangement statistics")
    parser.add_argument("--rearrangements", required=True, help="rearrangements_mapped.tsv")
    parser.add_argument("--tree", required=True, help="constraint_tree.nwk")
    parser.add_argument("--output", required=True, help="Output directory")

    args = parser.parse_args()

    # Load data
    print("Loading tree...")
    tree = read_newick_tree(args.tree)
    branch_lengths = get_branch_lengths(tree)
    print(f"Tree has {len(branch_lengths)} branches")

    print("Loading rearrangements...")
    rear_df = pd.read_csv(args.rearrangements, sep='\t')
    print(f"Loaded {len(rear_df)} rearrangements")

    # Count rearrangements per branch
    print("Counting rearrangements per branch...")
    branch_counts = defaultdict(int)
    branch_types = defaultdict(lambda: {'inversion': 0, 'translocation': 0, 'fusion': 0, 'fission': 0})

    for _, rear in rear_df.iterrows():
        branch = (rear['branch_ancestral_node'], rear['branch_derived_node'])
        branch_counts[branch] += 1

        # Count by type
        rtype = rear['type'].lower()
        if rtype in branch_types[branch]:
            branch_types[branch][rtype] += 1

    print(f"Found rearrangements on {len(branch_counts)} branches")

    # Compute rates and statistics
    print("Computing statistics...")
    stats_rows = []

    rates = []  # For computing mean and SD
    for branch, count in branch_counts.items():
        ancestral, derived = branch

        # Get branch length
        length_ma = branch_lengths.get(branch, 0.0)
        if length_ma == 0:
            length_ma = 0.01  # Avoid division by zero

        # Compute rate
        rate = count / length_ma

        stats_rows.append({
            'branch_ancestral_node': ancestral,
            'branch_derived_node': derived,
            'rearrangement_count': count,
            'branch_length_Ma': f"{length_ma:.3f}",
            'rearrangement_rate': f"{rate:.4f}",
            'inversions': branch_types[branch]['inversion'],
            'translocations': branch_types[branch]['translocation'],
            'fusions': branch_types[branch]['fusion'],
            'fissions': branch_types[branch]['fission'],
        })

        rates.append(rate)

    # Compute z-scores
    rates_array = np.array(rates)
    mean_rate = rates_array.mean()
    std_rate = rates_array.std()

    print(f"Mean rate: {mean_rate:.4f} rearrangements/Ma")
    print(f"SD rate: {std_rate:.4f}")

    for row in stats_rows:
        rate = float(row['rearrangement_rate'])
        z_score = (rate - mean_rate) / (std_rate + 1e-6)

        # Poisson test: is count significantly elevated?
        count = row['rearrangement_count']
        expected = mean_rate * float(row['branch_length_Ma'])
        pvalue = 1 - poisson.cdf(count - 1, expected)  # Right-tail test

        is_hotspot = z_score > 2.0 or pvalue < 0.05

        row['z_score'] = f"{z_score:.3f}"
        row['is_hotspot'] = 'TRUE' if is_hotspot else 'FALSE'
        row['pvalue'] = f"{pvalue:.4f}"

    # Write rearrangements_per_branch.tsv
    stats_df = pd.DataFrame(stats_rows)
    per_branch_file = f"{args.output}/rearrangements_per_branch.tsv"
    stats_df.to_csv(per_branch_file, sep='\t', index=False)
    print(f"Wrote branch statistics to {per_branch_file}")

    # Write branch_stats.csv (summary)
    hotspot_branches = stats_df[stats_df['is_hotspot'] == 'TRUE']
    hotspot_names = ', '.join(hotspot_branches['branch_derived_node'].tolist())

    summary_stats = [
        ('Total rearrangements', len(rear_df)),
        ('Total branches in tree', len(branch_counts)),
        ('Mean rearrangement rate (per Ma)', f"{mean_rate:.4f}"),
        ('SD rearrangement rate', f"{std_rate:.4f}"),
        ('Median rearrangement rate', f"{np.median(rates):.4f}"),
        ('Hotspot branches (z>2)', len(hotspot_branches)),
        ('Hotspot branch names', hotspot_names),
    ]

    summary_df = pd.DataFrame(summary_stats, columns=['Statistic', 'Value'])
    summary_file = f"{args.output}/branch_stats.csv"
    summary_df.to_csv(summary_file, index=False)
    print(f"Wrote summary statistics to {summary_file}")

    # Print to console
    print("\nBRANCH STATISTICS SUMMARY:")
    print(f"  Total rearrangements: {len(rear_df)}")
    print(f"  Total branches: {len(branch_counts)}")
    print(f"  Mean rate: {mean_rate:.4f} / Ma")
    print(f"  Hotspot branches: {len(hotspot_branches)}")
    if len(hotspot_branches) > 0:
        print(f"    Top hotspots: {hotspot_names[:100]}")

    print("\nDone!")

if __name__ == "__main__":
    main()
```

*Claude writes full, functional script with Poisson statistical testing.*

---

### Step 2: Run Statistics

```bash
chmod +x scripts/phase4/compute_branch_statistics.py

python3 scripts/phase4/compute_branch_statistics.py \
  --rearrangements data/karyotypes/rearrangements_mapped.tsv \
  --tree data/genomes/constraint_tree.nwk \
  --output results/phase4_rearrangements/
```

**Expected runtime:** < 1 minute

**Expected output:**
```
Loading tree...
Tree has 104 branches
Loading rearrangements...
Loaded 2345 rearrangements
Counting rearrangements per branch...
Found rearrangements on 87 branches
Computing statistics...
Mean rate: 0.4523 rearrangements/Ma
SD rate: 0.1234

BRANCH STATISTICS SUMMARY:
  Total rearrangements: 2345
  Total branches: 104
  Mean rate: 0.4523 / Ma
  Hotspot branches: 8
    Top hotspots: Polyphaga, Carabidae, Chrysomelidae, ...

Wrote branch statistics to results/phase4_rearrangements/rearrangements_per_branch.tsv
Wrote summary statistics to results/phase4_rearrangements/branch_stats.csv

Done!
```

---

### Step 3: Validate Statistics Output

```bash
# Check files exist
ls -lh results/phase4_rearrangements/rearrangements_per_branch.tsv
ls -lh results/phase4_rearrangements/branch_stats.csv

# Inspect per-branch statistics
head -20 results/phase4_rearrangements/rearrangements_per_branch.tsv

# Verify hotspot detection
tail -n +2 results/phase4_rearrangements/rearrangements_per_branch.tsv | \
  awk '$8 == "TRUE" {print $2, $6, $7}' | sort -k3 -rn

# Check summary
cat results/phase4_rearrangements/branch_stats.csv
```

---

### Step 4: Create Publication Figures

**Claude generates:** `scripts/phase4/create_rearrangement_figures.py`

This script creates PDF figures:

```python
#!/usr/bin/env python3
"""Generate rearrangement visualization figures."""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch-stats", required=True)
    parser.add_argument("--output-pdf", required=True)

    args = parser.parse_args()

    # Load data
    stats_df = pd.read_csv(args.branch_stats, sep='\t')

    # Create multi-panel figure
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('Rearrangement Rates Across Phylogenetic Branches', fontsize=14, fontweight='bold')

    # Panel A: Scatter plot of rate vs. branch length
    ax = axes[0, 0]
    ax.scatter(
        stats_df['branch_length_Ma'].astype(float),
        stats_df['rearrangement_rate'].astype(float),
        c=['red' if x == 'TRUE' else 'blue' for x in stats_df['is_hotspot']],
        alpha=0.6,
        s=100
    )
    ax.set_xlabel('Branch Length (Ma)', fontsize=11)
    ax.set_ylabel('Rearrangement Rate (rearrangements/Ma)', fontsize=11)
    ax.set_title('A) Rate vs. Branch Length', fontsize=12)
    ax.grid(True, alpha=0.3)

    # Panel B: Distribution of rates
    ax = axes[0, 1]
    rates = stats_df['rearrangement_rate'].astype(float)
    ax.hist(rates, bins=20, color='steelblue', edgecolor='black', alpha=0.7)
    ax.axvline(rates.mean(), color='red', linestyle='--', linewidth=2, label=f'Mean={rates.mean():.3f}')
    ax.set_xlabel('Rearrangement Rate (rearrangements/Ma)', fontsize=11)
    ax.set_ylabel('Frequency', fontsize=11)
    ax.set_title('B) Distribution of Rates', fontsize=12)
    ax.legend()

    # Panel C: Rearrangement type distribution in hotspots
    ax = axes[1, 0]
    hotspot_df = stats_df[stats_df['is_hotspot'] == 'TRUE']

    types = ['inversions', 'translocations', 'fusions', 'fissions']
    totals = [hotspot_df[t].sum() for t in types]

    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A']
    ax.bar(types, totals, color=colors, edgecolor='black', alpha=0.7)
    ax.set_ylabel('Count', fontsize=11)
    ax.set_title('C) Rearrangement Types in Hotspot Branches', fontsize=12)
    ax.grid(True, alpha=0.3, axis='y')

    # Panel D: Top hotspot branches
    ax = axes[1, 1]
    top_hotspots = hotspot_df.nlargest(10, 'z_score')

    y_pos = np.arange(len(top_hotspots))
    ax.barh(y_pos, top_hotspots['z_score'].astype(float), color='coral', edgecolor='black', alpha=0.7)
    ax.set_yticks(y_pos)
    ax.set_yticklabels(top_hotspots['branch_derived_node'], fontsize=9)
    ax.set_xlabel('Z-Score', fontsize=11)
    ax.set_title('D) Top 10 Hotspot Branches', fontsize=12)
    ax.axvline(2.0, color='red', linestyle='--', linewidth=2, alpha=0.5)
    ax.grid(True, alpha=0.3, axis='x')

    plt.tight_layout()
    plt.savefig(args.output_pdf, dpi=300, format='pdf', bbox_inches='tight')
    print(f"Saved figure to {args.output_pdf}")

if __name__ == "__main__":
    main()
```

Run figure generation:

```bash
chmod +x scripts/phase4/create_rearrangement_figures.py

python3 scripts/phase4/create_rearrangement_figures.py \
  --branch-stats results/phase4_rearrangements/rearrangements_per_branch.tsv \
  --output-pdf results/phase4_rearrangements/rearrangement_figures.pdf
```

**Output:** `rearrangement_figures.pdf` with 4-panel figure showing:
- Scatter: rate vs. branch length (hotspots highlighted)
- Histogram: distribution of rates
- Bar chart: rearrangement types in hotspot branches
- Top 10 hotspots (z-scores)

---

### Step 5: Verify Figures

```bash
# Check PDF exists
ls -lh results/phase4_rearrangements/rearrangement_figures.pdf

# View PDF (in Finder or PDF viewer)
# Ensure all panels are present and labels are clear
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Negative rearrangement rates | Branch length = 0 or negative | Check tree has valid branch lengths; handle zero-length branches |
| No hotspots detected | All rates similar (low variation) or thresholds too strict | Reduce z-score threshold (e.g., z > 1.5); check if data makes sense |
| Figure fonts too small | Default DPI or figure size | Increase figure size (figsize) or DPI in matplotlib |
| Tree parsing fails | Newick format issue | Verify constraint_tree.nwk is valid |

---

## Next Steps

Once branch statistics complete:
1. Review figures for publication quality; adjust as needed
2. Proceed to Task 4.5 (literature comparison)
3. Identify hotspots for discussion in publication
4. Update `ai_use_log.md` with completion
