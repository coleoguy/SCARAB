# HOWTO 4.2: Rearrangement Filtering & Classification

**Task Goal:** Classify raw rearrangement calls as **Confirmed** (high confidence), **Inferred** (moderate confidence), or **Artifact** (likely errors). Use human-defined criteria for each class.

**Timeline:** Days 26–27
**Responsible Person:** Heath (defines criteria); Claude (implements filter); Human (reviews outputs)

---

## Inputs

### From Task 4.1:
- **File:** `data/karyotypes/rearrangements_raw.tsv`
  - Columns: rearrangement_id, type, species, ancestral_node, chr_involved, breakpoint_1, breakpoint_2, confidence, supporting_blocks, notes

### From Human:
- **Filtering Criteria:** Heath defines thresholds for Confirmed/Inferred/Artifact (see Step 2 below)

---

## Outputs

1. **`data/karyotypes/rearrangements_confirmed.tsv`** (high-confidence rearrangements)
2. **`data/karyotypes/rearrangements_inferred.tsv`** (moderate-confidence rearrangements)
3. **`data/karyotypes/rearrangements_artifact.tsv`** (likely errors; excluded from downstream analysis)
4. **`results/phase4_rearrangements/filtering_criteria.txt`** (human-defined criteria document)

All three TSV files have same columns as input (rearrangements_raw.tsv).

---

## Acceptance Criteria

- [ ] All input rearrangements classified into one of three categories
- [ ] Filtering criteria documented in filtering_criteria.txt
- [ ] Confirmed + Inferred >= 80% of input rearrangements (most are not artifacts)
- [ ] Output TSV files are properly formatted

---

## Filtering Criteria (Template for Heath)

**Claude and Human work together to define specific thresholds. Example template:**

### Confirmed Rearrangements (use for all downstream analysis)
- **Criteria:**
  - `supporting_blocks` >= 3 (strong evidence from multiple block pairs)
  - OR `confidence` >= 0.85 AND supported by orthologous comparisons
  - AND consistent across multiple species pairs
  - AND no conflicting evidence from other species

- **Rationale:** Multiple independent lines of evidence strongly support occurrence

### Inferred Rearrangements (use with caution; footnote in publication)
- **Criteria:**
  - `supporting_blocks` == 2 (moderate evidence)
  - OR `confidence` >= 0.70 AND < 0.85
  - AND no direct conflict with other rearrangements
  - AND plausible given known biology

- **Rationale:** Weaker evidence; may be real but less certain

### Artifact Rearrangements (exclude from analysis)
- **Criteria:**
  - `supporting_blocks` <= 1 (only single block pair)
  - OR `confidence` < 0.70
  - OR conflicting evidence from orthologous comparisons
  - OR breaks known synteny conservation patterns
  - OR would require multiple independent rearrangements in unrelated lineages

- **Rationale:** Likely assembly, alignment, or inference error; too unreliable for analysis

---

## Implementation

### Step 1: Document Filtering Criteria

Before running script, create criteria file:

```bash
cat > results/phase4_rearrangements/filtering_criteria.txt << 'EOF'
REARRANGEMENT FILTERING CRITERIA
================================

Defined by: Heath Blackmon, [DATE]

CONFIRMED REARRANGEMENTS
------------------------
Definition: Rearrangements with strong, independent evidence

Criteria:
- Supporting blocks: >= 3 OR
- Confidence: >= 0.85 AND supported by >= 2 species pairs OR
- Conservation score: >= 0.90 in ancestor AND >= 0.80 in descendant

Interpretation:
- Multiple synteny block pairs corroborate the rearrangement
- High conservation suggests real gene order change, not alignment artifact
- Present in multiple lineage comparisons

Examples: [Add specific examples from data]

INFERRED REARRANGEMENTS
-----------------------
Definition: Rearrangements with moderate evidence; include with caveats

Criteria:
- Supporting blocks: 2 OR
- Confidence: 0.70-0.85 AND
- No direct conflicting evidence AND
- Plausible given evolutionary context

Interpretation:
- Single block pair or moderate confidence
- No evidence contradicting the rearrangement
- Biologically plausible (e.g., known hotspots, related lineages)

Use in analysis: Include, but footnote or separate analysis showing results robust to inclusion/exclusion

Examples: [Add specific examples from data]

ARTIFACT REARRANGEMENTS
-----------------------
Definition: Likely alignment or assembly errors; exclude from analysis

Criteria:
- Supporting blocks: <= 1 OR
- Confidence: < 0.70 OR
- Direct conflicting evidence (same species has opposite rearrangement in other comparison) OR
- Would require implausible independent events

Interpretation:
- Insufficient evidence for a real rearrangement
- Probably misalignment, assembly error, or ancestral reconstruction artifact
- Including would introduce noise and false positives

Examples: [Add specific examples from data]

REVISION HISTORY:
[Track changes to criteria if refined during filtering]

EOF

cat results/phase4_rearrangements/filtering_criteria.txt
```

---

### Step 2: Create Filtering Script

**Claude generates:** `scripts/phase4/filter_rearrangements.py`

This Python script:
1. Reads raw rearrangements
2. Applies filtering criteria
3. Outputs three separate TSV files
4. Generates filtering statistics

**Script outline:**
```python
#!/usr/bin/env python3
"""
Filter and classify rearrangements as Confirmed, Inferred, or Artifact.

Usage:
    python3 filter_rearrangements.py \
        --input data/karyotypes/rearrangements_raw.tsv \
        --confirmed data/karyotypes/rearrangements_confirmed.tsv \
        --inferred data/karyotypes/rearrangements_inferred.tsv \
        --artifact data/karyotypes/rearrangements_artifact.tsv \
        --log results/phase4_rearrangements/filtering_stats.txt \
        --confirmed-min-blocks 3 \
        --confirmed-min-confidence 0.85 \
        --inferred-min-blocks 2 \
        --inferred-min-confidence 0.70
"""

import pandas as pd
import argparse
import os

def classify_rearrangement(row, confirmed_min_blocks, confirmed_min_confidence,
                          inferred_min_blocks, inferred_min_confidence):
    """
    Classify a single rearrangement as Confirmed, Inferred, or Artifact.
    """
    supporting_blocks = row['supporting_blocks']
    confidence = row['confidence']

    # CONFIRMED: strong evidence
    if supporting_blocks >= confirmed_min_blocks:
        return 'Confirmed'
    if confidence >= confirmed_min_confidence:
        return 'Confirmed'

    # INFERRED: moderate evidence
    if supporting_blocks >= inferred_min_blocks:
        if confidence >= inferred_min_confidence:
            return 'Inferred'

    # ARTIFACT: insufficient evidence
    return 'Artifact'

def main():
    parser = argparse.ArgumentParser(description="Filter rearrangements by confidence")
    parser.add_argument("--input", required=True, help="rearrangements_raw.tsv")
    parser.add_argument("--confirmed", required=True, help="Output for confirmed")
    parser.add_argument("--inferred", required=True, help="Output for inferred")
    parser.add_argument("--artifact", required=True, help="Output for artifacts")
    parser.add_argument("--log", required=True, help="Output log file")
    parser.add_argument("--confirmed-min-blocks", type=int, default=3)
    parser.add_argument("--confirmed-min-confidence", type=float, default=0.85)
    parser.add_argument("--inferred-min-blocks", type=int, default=2)
    parser.add_argument("--inferred-min-confidence", type=float, default=0.70)

    args = parser.parse_args()

    # Load input
    print("Loading rearrangements...")
    df = pd.read_csv(args.input, sep='\t')
    total = len(df)
    print(f"Loaded {total} rearrangements")

    # Classify each rearrangement
    print("Classifying rearrangements...")
    df['classification'] = df.apply(
        lambda row: classify_rearrangement(
            row,
            args.confirmed_min_blocks,
            args.confirmed_min_confidence,
            args.inferred_min_blocks,
            args.inferred_min_confidence
        ),
        axis=1
    )

    # Split into three outputs
    confirmed_df = df[df['classification'] == 'Confirmed'].drop('classification', axis=1)
    inferred_df = df[df['classification'] == 'Inferred'].drop('classification', axis=1)
    artifact_df = df[df['classification'] == 'Artifact'].drop('classification', axis=1)

    # Create output directories
    for output_file in [args.confirmed, args.inferred, args.artifact]:
        os.makedirs(os.path.dirname(output_file), exist_ok=True)

    # Write outputs
    print(f"Writing {len(confirmed_df)} confirmed rearrangements...")
    confirmed_df.to_csv(args.confirmed, sep='\t', index=False)

    print(f"Writing {len(inferred_df)} inferred rearrangements...")
    inferred_df.to_csv(args.inferred, sep='\t', index=False)

    print(f"Writing {len(artifact_df)} artifact rearrangements...")
    artifact_df.to_csv(args.artifact, sep='\t', index=False)

    # Generate log
    with open(args.log, 'w') as f:
        f.write("REARRANGEMENT FILTERING STATISTICS\n")
        f.write("=" * 60 + "\n\n")

        f.write("FILTERING PARAMETERS\n")
        f.write("-" * 60 + "\n")
        f.write(f"Confirmed thresholds:\n")
        f.write(f"  Min supporting blocks: {args.confirmed_min_blocks}\n")
        f.write(f"  Min confidence: {args.confirmed_min_confidence}\n")
        f.write(f"Inferred thresholds:\n")
        f.write(f"  Min supporting blocks: {args.inferred_min_blocks}\n")
        f.write(f"  Min confidence: {args.inferred_min_confidence}\n\n")

        f.write("RESULTS\n")
        f.write("-" * 60 + "\n")
        f.write(f"Total input rearrangements: {total:,}\n")
        f.write(f"Confirmed: {len(confirmed_df):>20,} ({len(confirmed_df)/total*100:>6.1f}%)\n")
        f.write(f"Inferred:  {len(inferred_df):>20,} ({len(inferred_df)/total*100:>6.1f}%)\n")
        f.write(f"Artifact:  {len(artifact_df):>20,} ({len(artifact_df)/total*100:>6.1f}%)\n\n")

        # Breakdown by type
        f.write("BREAKDOWN BY TYPE\n")
        f.write("-" * 60 + "\n")

        for category, category_df in [('Confirmed', confirmed_df), ('Inferred', inferred_df), ('Artifact', artifact_df)]:
            f.write(f"\n{category}:\n")
            for rear_type in ['inversion', 'translocation', 'fusion', 'fission']:
                count = (category_df['type'] == rear_type).sum()
                f.write(f"  {rear_type}: {count:>10,}\n")

        # Acceptance criteria
        f.write("\n\nACCEPTANCE CRITERIA\n")
        f.write("-" * 60 + "\n")

        ok_coverage = (len(confirmed_df) + len(inferred_df)) / total >= 0.80
        coverage_pct = (len(confirmed_df) + len(inferred_df)) / total * 100
        f.write(f"[{'✓' if ok_coverage else '✗'}] Confirmed + Inferred >= 80% of input ({coverage_pct:.1f}%)\n")

        f.write(f"[✓] Output TSV files created\n")
        f.write(f"[✓] All input rearrangements classified\n")

    # Print summary to console
    print(f"\nFILTERING SUMMARY:")
    print(f"  Confirmed: {len(confirmed_df):,} ({len(confirmed_df)/total*100:.1f}%)")
    print(f"  Inferred:  {len(inferred_df):,} ({len(inferred_df)/total*100:.1f}%)")
    print(f"  Artifact:  {len(artifact_df):,} ({len(artifact_df)/total*100:.1f}%)")

    print(f"\nResults written to:")
    print(f"  {args.confirmed}")
    print(f"  {args.inferred}")
    print(f"  {args.artifact}")
    print(f"  {args.log}")

if __name__ == "__main__":
    main()
```

*Claude writes full, functional script with flexible threshold parameters.*

---

### Step 3: Run Filtering

```bash
chmod +x scripts/phase4/filter_rearrangements.py

python3 scripts/phase4/filter_rearrangements.py \
  --input data/karyotypes/rearrangements_raw.tsv \
  --confirmed data/karyotypes/rearrangements_confirmed.tsv \
  --inferred data/karyotypes/rearrangements_inferred.tsv \
  --artifact data/karyotypes/rearrangements_artifact.tsv \
  --log results/phase4_rearrangements/filtering_stats.txt \
  --confirmed-min-blocks 3 \
  --confirmed-min-confidence 0.85 \
  --inferred-min-blocks 2 \
  --inferred-min-confidence 0.70
```

**Expected runtime:** < 1 minute

**Expected output:**
```
Loading rearrangements...
Loaded 4567 rearrangements
Classifying rearrangements...
Writing 2345 confirmed rearrangements...
Writing 1234 inferred rearrangements...
Writing 988 artifact rearrangements...

FILTERING SUMMARY:
  Confirmed: 2,345 (51.4%)
  Inferred:  1,234 (27.0%)
  Artifact:    988 (21.6%)

Results written to:
  data/karyotypes/rearrangements_confirmed.tsv
  data/karyotypes/rearrangements_inferred.tsv
  data/karyotypes/rearrangements_artifact.tsv
  results/phase4_rearrangements/filtering_stats.txt
```

---

### Step 4: Validate Outputs

```bash
# Check all three files exist and are non-empty
ls -lh data/karyotypes/rearrangements_*.tsv

# Count rows in each
echo "Confirmed:" && wc -l data/karyotypes/rearrangements_confirmed.tsv
echo "Inferred:" && wc -l data/karyotypes/rearrangements_inferred.tsv
echo "Artifact:" && wc -l data/karyotypes/rearrangements_artifact.tsv

# Inspect confirmed (most important)
head -20 data/karyotypes/rearrangements_confirmed.tsv

# Check type distribution in confirmed
tail -n +2 data/karyotypes/rearrangements_confirmed.tsv | cut -f2 | sort | uniq -c

# Verify filtering stats
cat results/phase4_rearrangements/filtering_stats.txt
```

---

### Step 5: Manual Review (Human Quality Control)

Human samples and inspects ~20 rearrangements from each category:

```bash
# Sample from confirmed (should all be high-quality)
tail -n +2 data/karyotypes/rearrangements_confirmed.tsv | \
  shuf -n 20 > /tmp/sample_confirmed.tsv

# Sample from inferred (should be reasonable but weaker)
tail -n +2 data/karyotypes/rearrangements_inferred.tsv | \
  shuf -n 20 > /tmp/sample_inferred.tsv

# Sample from artifact (should look like errors)
tail -n +2 data/karyotypes/rearrangements_artifact.tsv | \
  shuf -n 20 > /tmp/sample_artifact.tsv

# Review each
cat /tmp/sample_confirmed.tsv
cat /tmp/sample_inferred.tsv
cat /tmp/sample_artifact.tsv
```

**Validation questions:**
- Confirmed: Do all have ≥3 supporting blocks or confidence ≥0.85?
- Inferred: Are they borderline cases (2 blocks, moderate confidence)?
- Artifact: Do they look like errors (1 block, low confidence, conflicting evidence)?

If satisfied, proceed. If not, adjust filtering thresholds and rerun.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Script crashes on missing column | Input TSV missing expected column | Verify input is rearrangements_raw.tsv from Task 4.1; check column names |
| All rearrangements classified as Artifact | Thresholds too strict | Lower `--confirmed-min-confidence` and `--inferred-min-confidence` values |
| > 30% classified as Artifact | Too many errors in calling | Check upstream calling script; may need to adjust block overlap thresholds |
| Distribution looks wrong (e.g., 90% Confirmed) | Thresholds too loose | Increase `--confirmed-min-blocks` or `--confirmed-min-confidence` |

---

## Next Steps

Once filtering complete and validated:
1. Use rearrangements_confirmed.tsv for all downstream analysis
2. Use rearrangements_inferred.tsv for sensitivity testing
3. Proceed to Task 4.3 (tree mapping)
4. Update `ai_use_log.md` with completion
