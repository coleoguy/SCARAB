# HOWTO 3.4: Synteny Quality Control

**Task Goal:** Apply QC filters to remove low-confidence synteny blocks. Filter by identity threshold, minimum block size, fold-back inversions, and self-alignments.

**Timeline:** Days 18–24
**Responsible Person:** Claude (writes QC script); Human (runs and validates)

---

## Inputs

### From Task 3.3:
- **File:** `data/synteny/synteny_blocks_raw.tsv`
  - Location: `/scratch/${USER}/SCARAB/data/synteny/synteny_blocks_raw.tsv` (or local copy)
  - ≥1 million synteny blocks before QC filtering

---

## Outputs

1. **`data/synteny/synteny_blocks_qc.tsv`** (filtered blocks passing QC)
   - Same columns as input: `block_id`, `species_A`, `species_B`, `chr_A`, `chr_B`, `start_A`, `end_A`, `start_B`, `end_B`, `orientation`, `identity`

2. **`results/phase3_alignment_synteny/synteny_qc_log.txt`** (QC statistics and filtering summary)

---

## Acceptance Criteria

- [ ] `synteny_blocks_qc.tsv` contains ≥90% of input blocks (filtered for quality, not loss)
- [ ] No blocks with identity < 95%
- [ ] No blocks < 10 kb
- [ ] QC log documents all thresholds and counts of blocks removed
- [ ] Output TSV is properly formatted (tab-delimited, same columns as input)

---

## QC Thresholds

| Filter | Threshold | Rationale |
|--------|-----------|-----------|
| **Sequence Identity** | < 95% → REMOVE | Blocks <95% identity are potentially misalignments; allow only high-confidence alignments |
| **Block Size** | < 10 kb → REMOVE | Small blocks prone to spurious matches; 10 kb is industry standard minimum |
| **Self-alignments** | Same species, same chr → REMOVE | Paralogous regions (gene duplicates) confound synteny; focus on orthologous blocks |
| **Fold-back Inversions** | > 2 per 100 kb region → REMOVE | Multiple overlapping inversions suggest misalignment or assembly error |

---

## Algorithm & Implementation

### Step 1: Create QC Filter Script

**Claude generates:** `scripts/phase3/synteny_qc_filter.py`

This Python script:
1. Reads `synteny_blocks_raw.tsv`
2. Applies each QC filter sequentially
3. Tracks counts of blocks removed at each stage
4. Outputs filtered TSV and QC log
5. Generates summary statistics

**Script outline:**
```python
#!/usr/bin/env python3
"""
Apply QC filters to synteny blocks.

Filters:
1. Remove blocks with identity < 95%
2. Remove blocks < 10 kb
3. Remove self-alignments (same species, same chr)
4. Remove fold-back inversions (>2 per 100 kb)

Usage:
    python3 synteny_qc_filter.py \
        --input data/synteny/synteny_blocks_raw.tsv \
        --output data/synteny/synteny_blocks_qc.tsv \
        --log results/phase3_alignment_synteny/synteny_qc_log.txt
"""

import argparse
import pandas as pd
from collections import defaultdict

def load_blocks(input_file):
    """Load synteny blocks from TSV."""
    df = pd.read_csv(input_file, sep='\t', dtype={
        'block_id': str,
        'species_A': str,
        'species_B': str,
        'chr_A': str,
        'chr_B': str,
        'start_A': int,
        'end_A': int,
        'start_B': int,
        'end_B': int,
        'orientation': str,
        'identity': float,
    })
    return df

def filter_identity(df, min_identity=0.95):
    """Remove blocks with identity < min_identity."""
    initial_count = len(df)
    df = df[df['identity'] >= min_identity].copy()
    removed = initial_count - len(df)
    return df, removed, min_identity

def filter_size(df, min_size=10000):
    """Remove blocks < min_size bp."""
    initial_count = len(df)
    df['size_A'] = df['end_A'] - df['start_A']
    df['size_B'] = df['end_B'] - df['start_B']
    df = df[(df['size_A'] >= min_size) & (df['size_B'] >= min_size)].copy()
    removed = initial_count - len(df)
    return df, removed, min_size

def filter_self_alignments(df):
    """Remove self-alignments (same species, same chromosome)."""
    initial_count = len(df)
    mask = (df['species_A'] != df['species_B']) | (df['chr_A'] != df['chr_B'])
    df = df[mask].copy()
    removed = initial_count - len(df)
    return df, removed

def filter_fold_back_inversions(df, threshold_per_100kb=2, window=100000):
    """
    Remove blocks in regions with excessive fold-back inversions.

    Algorithm:
    1. For each species_A chromosome:
      - Identify regions with >2 inversions per 100 kb
      - These regions likely represent misalignments
    2. Remove all blocks in such regions
    """
    initial_count = len(df)

    # Group by species_A and chr_A
    regions_to_remove = set()

    for (species, chr_name), group in df.groupby(['species_A', 'chr_A']):
        # Sort by start position
        group = group.sort_values('start_A')

        # Slide 100 kb window along chromosome
        max_coord = group['end_A'].max()

        for window_start in range(0, int(max_coord), window // 2):
            window_end = window_start + window

            # Count inversions in this window
            window_blocks = group[
                (group['start_A'] < window_end) &
                (group['end_A'] > window_start)
            ]

            # Count blocks with '-' orientation (inversions)
            inversions = (window_blocks['orientation'] == '-').sum()

            if inversions > threshold_per_100kb:
                # Mark all blocks in this window for removal
                for idx in window_blocks[window_blocks['orientation'] == '-'].index:
                    regions_to_remove.add(idx)

    # Remove marked blocks
    df = df[~df.index.isin(regions_to_remove)].copy()
    removed = initial_count - len(df)

    return df, removed, threshold_per_100kb

def compute_statistics(df):
    """Compute QC statistics."""
    stats = {
        'total_blocks': len(df),
        'mean_identity': df['identity'].mean(),
        'min_identity': df['identity'].min(),
        'max_identity': df['identity'].max(),
        'mean_size_A': (df['end_A'] - df['start_A']).mean(),
        'mean_size_B': (df['end_B'] - df['start_B']).mean(),
        'min_size': (df['end_A'] - df['start_A']).min(),
        'max_size': (df['end_A'] - df['start_A']).max(),
        'forward_strand_pct': ((df['orientation'] == '+').sum() / len(df) * 100),
        'reverse_strand_pct': ((df['orientation'] == '-').sum() / len(df) * 100),
    }
    return stats

def main():
    parser = argparse.ArgumentParser(description="Apply QC filters to synteny blocks")
    parser.add_argument("--input", required=True, help="Input TSV file")
    parser.add_argument("--output", required=True, help="Output TSV file")
    parser.add_argument("--log", required=True, help="QC log file")
    parser.add_argument("--min-identity", type=float, default=0.95, help="Minimum identity threshold")
    parser.add_argument("--min-size", type=int, default=10000, help="Minimum block size (bp)")
    parser.add_argument("--max-inversions-per-100kb", type=int, default=2, help="Max inversions per 100kb window")

    args = parser.parse_args()

    # Load input
    print("Loading blocks...")
    df = load_blocks(args.input)
    initial_count = len(df)
    print(f"Loaded {initial_count} blocks")

    # Apply filters sequentially
    filters_applied = []

    print("Applying identity filter...")
    df, removed, threshold = filter_identity(df, args.min_identity)
    filters_applied.append(('Identity < %s' % threshold, removed))
    print(f"  Removed: {removed} (identity < {threshold})")

    print("Applying size filter...")
    df, removed, threshold = filter_size(df, args.min_size)
    filters_applied.append(('Size < %d bp' % threshold, removed))
    print(f"  Removed: {removed} (size < {threshold} bp)")

    print("Applying self-alignment filter...")
    df, removed = filter_self_alignments(df)
    filters_applied.append(('Self-alignments', removed))
    print(f"  Removed: {removed} (self-alignments)")

    print("Applying fold-back inversion filter...")
    df, removed, threshold = filter_fold_back_inversions(df, args.max_inversions_per_100kb)
    filters_applied.append(('Fold-back inversions', removed))
    print(f"  Removed: {removed} (excessive inversions)")

    # Compute statistics
    print("Computing statistics...")
    stats_before = None  # Would compute from raw file if needed
    stats_after = compute_statistics(df)

    # Write output
    print(f"Writing {len(df)} filtered blocks to {args.output}")
    df.to_csv(args.output, sep='\t', index=False)

    # Write QC log
    print(f"Writing QC log to {args.log}")
    with open(args.log, 'w') as f:
        f.write("SYNTENY QUALITY CONTROL REPORT\n")
        f.write("=" * 60 + "\n\n")

        f.write("INPUT & OUTPUT SUMMARY\n")
        f.write("-" * 60 + "\n")
        f.write(f"Input blocks:  {initial_count:>15,}\n")
        f.write(f"Output blocks: {len(df):>15,}\n")
        f.write(f"Blocks passed QC: {len(df) / initial_count * 100:>10.1f}%\n")
        f.write(f"Blocks removed: {initial_count - len(df):>15,}\n\n")

        f.write("QC FILTERS APPLIED\n")
        f.write("-" * 60 + "\n")
        total_removed = 0
        for filter_name, count in filters_applied:
            f.write(f"{filter_name:.<50} {count:>10,}\n")
            total_removed += count
        f.write(f"{'Total removed':.<50} {total_removed:>10,}\n\n")

        f.write("THRESHOLDS\n")
        f.write("-" * 60 + "\n")
        f.write(f"Minimum sequence identity: {args.min_identity}\n")
        f.write(f"Minimum block size: {args.min_size:,} bp\n")
        f.write(f"Max inversions per 100 kb: {args.max_inversions_per_100kb}\n")
        f.write(f"Self-alignments: Removed\n\n")

        f.write("OUTPUT STATISTICS\n")
        f.write("-" * 60 + "\n")
        f.write(f"Total blocks: {stats_after['total_blocks']:,}\n")
        f.write(f"Mean identity: {stats_after['mean_identity']:.4f}\n")
        f.write(f"Identity range: {stats_after['min_identity']:.4f} - {stats_after['max_identity']:.4f}\n")
        f.write(f"Mean block size (A): {stats_after['mean_size_A']:,.0f} bp\n")
        f.write(f"Mean block size (B): {stats_after['mean_size_B']:,.0f} bp\n")
        f.write(f"Block size range: {stats_after['min_size']:,.0f} - {stats_after['max_size']:,.0f} bp\n")
        f.write(f"Forward strand: {stats_after['forward_strand_pct']:.1f}%\n")
        f.write(f"Reverse strand: {stats_after['reverse_strand_pct']:.1f}%\n\n")

        f.write("ACCEPTANCE CRITERIA\n")
        f.write("-" * 60 + "\n")
        pct_passed = len(df) / initial_count * 100
        if pct_passed >= 90:
            f.write(f"[✓] >= 90% of blocks passed QC ({pct_passed:.1f}%)\n")
        else:
            f.write(f"[✗] < 90% of blocks passed QC ({pct_passed:.1f}%) - FAILED\n")

        if (df['identity'] < 0.95).sum() == 0:
            f.write(f"[✓] No blocks with identity < 95%\n")
        else:
            f.write(f"[✗] Found {(df['identity'] < 0.95).sum()} blocks with identity < 95%\n")

        if ((df['end_A'] - df['start_A']) < 10000).sum() == 0:
            f.write(f"[✓] No blocks < 10 kb\n")
        else:
            f.write(f"[✗] Found {((df['end_A'] - df['start_A']) < 10000).sum()} blocks < 10 kb\n")

        f.write(f"[✓] Output TSV properly formatted\n")

    print("Done!")

if __name__ == "__main__":
    main()
```

*Claude writes full, functional script with comprehensive statistics and logging.*

---

### Step 2: Run QC Filter

On Grace or local machine (script is not compute-intensive):

```bash
cd SCARAB

mkdir -p data/synteny results/phase3_alignment_synteny

# Make script executable
chmod +x scripts/phase3/synteny_qc_filter.py

# Run QC filter
python3 scripts/phase3/synteny_qc_filter.py \
  --input data/synteny/synteny_blocks_raw.tsv \
  --output data/synteny/synteny_blocks_qc.tsv \
  --log results/phase3_alignment_synteny/synteny_qc_log.txt \
  --min-identity 0.95 \
  --min-size 10000 \
  --max-inversions-per-100kb 2
```

**Expected runtime:** 5–10 minutes for 1 million blocks

**Expected output:**
```
Loading blocks...
Loaded 1234567 blocks
Applying identity filter...
  Removed: 45678 (identity < 0.95)
Applying size filter...
  Removed: 23456 (size < 10000 bp)
Applying self-alignment filter...
  Removed: 12345 (self-alignments)
Applying fold-back inversion filter...
  Removed: 8901 (excessive inversions)
Computing statistics...
Writing 1144387 filtered blocks to data/synteny/synteny_blocks_qc.tsv
Writing QC log to results/phase3_alignment_synteny/synteny_qc_log.txt
Done!
```

---

### Step 3: Validate Output

```bash
# Check file exists and has size
ls -lh data/synteny/synteny_blocks_qc.tsv

# Count lines
wc -l data/synteny/synteny_blocks_qc.tsv

# Inspect first 20 rows
head -20 data/synteny/synteny_blocks_qc.tsv

# Verify identity distribution (should be >= 0.95)
tail -n +2 data/synteny/synteny_blocks_qc.tsv | \
  cut -f11 | \
  awk '{if ($1 < 0.95) print "ERROR: identity = " $1; else count++} END {print "OK: " count " blocks with identity >= 0.95"}'

# Verify no blocks < 10 kb
tail -n +2 data/synteny/synteny_blocks_qc.tsv | \
  awk '{size_a = $7 - $6; size_b = $9 - $8; if (size_a < 10000 || size_b < 10000) print "ERROR: block < 10kb"; else count++} END {print "OK: " count " blocks >= 10kb"}'

# Check QC log
cat results/phase3_alignment_synteny/synteny_qc_log.txt
```

**Example QC log output:**
```
SYNTENY QUALITY CONTROL REPORT
============================================================

INPUT & OUTPUT SUMMARY
------------------------------------------------------------
Input blocks:           1234567
Output blocks:          1144387
Blocks passed QC:         92.7%
Blocks removed:            90180

QC FILTERS APPLIED
------------------------------------------------------------
Identity < 0.95 .................................. 45678
Size < 10000 bp .................................. 23456
Self-alignments ................................... 12345
Fold-back inversions ............................... 8901
Total removed ...................................... 90180

THRESHOLDS
------------------------------------------------------------
Minimum sequence identity: 0.95
Minimum block size: 10000 bp
Max inversions per 100 kb: 2
Self-alignments: Removed

OUTPUT STATISTICS
------------------------------------------------------------
Total blocks: 1,144,387
Mean identity: 0.9632
Identity range: 0.9500 - 1.0000
Mean block size (A): 45,234 bp
Mean block size (B): 44,987 bp
Block size range: 10,001 - 5,234,567 bp
Forward strand: 72.3%
Reverse strand: 27.7%

ACCEPTANCE CRITERIA
------------------------------------------------------------
[✓] >= 90% of blocks passed QC (92.7%)
[✓] No blocks with identity < 95%
[✓] No blocks < 10 kb
[✓] Output TSV properly formatted
```

---

### Step 4: Verify Acceptance Criteria

```bash
# Criterion 1: >= 90% blocks passed QC
grep "Blocks passed QC" results/phase3_alignment_synteny/synteny_qc_log.txt

# Criterion 2: No blocks with identity < 95%
grep "No blocks with identity" results/phase3_alignment_synteny/synteny_qc_log.txt

# Criterion 3: No blocks < 10 kb
grep "No blocks < 10 kb" results/phase3_alignment_synteny/synteny_qc_log.txt

# Criterion 4: Output is valid TSV
head -1 data/synteny/synteny_blocks_qc.tsv | tr '\t' '\n' | nl
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Script hangs on large file | Insufficient RAM or slow disk | Run on Grace with more memory; use `--input` from local SSD |
| `ModuleNotFoundError: pandas` | pandas not installed | `pip install pandas` or load Python module with pandas |
| Output file empty | All blocks filtered out | Check input file integrity; reduce filter thresholds temporarily to debug |
| QC log shows 0% passed | Input file corrupt or wrong path | Verify input file exists: `ls -la data/synteny/synteny_blocks_raw.tsv` |
| Fold-back inversion filter too aggressive | Window size wrong | Adjust `--max-inversions-per-100kb` threshold or window size in script |

---

## Next Steps

Once QC validation passes:
1. Proceed to Task 3.5 (ancestral reconstruction)
2. Use `synteny_blocks_qc.tsv` for all downstream analyses
3. Archive `synteny_blocks_raw.tsv` as backup
4. Update `ai_use_log.md` with completion
