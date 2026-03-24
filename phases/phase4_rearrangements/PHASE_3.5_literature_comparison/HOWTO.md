# HOWTO 4.5: Literature Comparison & Validation

**Task Goal:** Compare inferred rearrangements to published karyotype data and empirical cytogenetics literature. Validate predictions using independent data sources (if available).

**Timeline:** Days 28–29
**Responsible Person:** Human (gathers literature data); Claude (writes comparison script)

---

## Inputs

### From Task 4.3:
- **File:** `data/karyotypes/rearrangements_mapped.tsv`
  - All confirmed rearrangements with branch assignments

### From External Sources (optional):
- **Karyotype Database:** TraitTrawler (if available)
- **Published Literature:** Peer-reviewed papers with empirical karyotypes for Coleoptera
- **Manual Curation:** Heath's knowledge of beetle karyotypes

---

## Outputs

1. **`results/phase4_rearrangements/literature_comparison.csv`** (validation results)
2. **`results/phase4_rearrangements/validation_report.txt`** (summary and statistics)

---

## Acceptance Criteria

- [ ] ≥80% of inferred rearrangements consistent with published data (or no published data available)
- [ ] Discrepancies documented with explanations
- [ ] Validation report includes methodology and data sources

---

## Validation Strategy

### For Species with Published Karyotypes

Compare:
- Inferred 2n (chromosome number) → Published 2n
- Inferred chromosome structure → Published morphology
- Inferred rearrangements → Documented rearrangements in literature

**Agreement:**
- ✓ Exact match
- ~ Close match (minor discrepancies, likely due to assembly quality)
- ✗ Conflict (different 2n or major structure difference)

### For Species without Published Data

- Assess biological plausibility (e.g., rearrangement rates consistent with other insects)
- Check for outliers or unexpected patterns
- Document as "unvalidated but plausible"

---

## Implementation

### Step 1: Gather Literature Data

Human collects published karyotype data:

```bash
# Create template CSV for literature data
cat > data/karyotypes/literature_karyotypes.csv << 'EOF'
species,published_2n,chromosome_notes,reference,year,url
Tribolium_castaneum,20,Acrocentric chromosomes,Smith et al.,2010,doi:10.1111/xxx
Bombyx_mori,28,Well-characterized; holocentric,NCBI Reference Genome,2020,
[more rows...]
EOF
```

**Columns needed:**
- `species`: Species name (must match rearrangements_mapped.tsv)
- `published_2n`: Chromosome number from literature
- `chromosome_notes`: Description (structure, morphology, notes)
- `reference`: Citation or source
- `year`: Publication year
- `url`: DOI or direct link

---

### Step 2: Create Comparison Script

**Claude generates:** `scripts/phase4/compare_to_literature.py`

This Python script:
1. Reads inferred and literature karyotypes
2. Compares 2n values
3. Checks for structural consistency
4. Generates agreement metrics
5. Outputs comparison TSV

**Script outline:**
```python
#!/usr/bin/env python3
"""
Compare inferred rearrangements and karyotypes to literature.

Usage:
    python3 compare_to_literature.py \
        --rearrangements data/karyotypes/rearrangements_mapped.tsv \
        --ancestral data/karyotypes/ancestral_karyotypes.csv \
        --literature data/karyotypes/literature_karyotypes.csv \
        --output results/phase4_rearrangements/literature_comparison.csv
"""

import pandas as pd
import argparse
from collections import defaultdict

def main():
    parser = argparse.ArgumentParser(description="Compare inferred to published karyotypes")
    parser.add_argument("--rearrangements", required=True)
    parser.add_argument("--ancestral", required=True)
    parser.add_argument("--literature", required=True)
    parser.add_argument("--output", required=True)

    args = parser.parse_args()

    # Load data
    print("Loading data...")
    rear_df = pd.read_csv(args.rearrangements, sep='\t')
    ancestral_df = pd.read_csv(args.ancestral, sep='\t')

    # Load literature (if exists)
    try:
        lit_df = pd.read_csv(args.literature, sep=',')
        print(f"Loaded {len(lit_df)} literature karyotypes")
    except FileNotFoundError:
        print(f"Warning: Literature file not found; continuing without validation")
        lit_df = pd.DataFrame()

    # For each species, compile inferred vs. literature
    species_list = rear_df['species'].unique()
    comparison_rows = []

    for species in species_list:
        species_rear = rear_df[rear_df['species'] == species]

        # Get inferred 2n for this species (from rearrangement inference)
        # This is simplified; real implementation would count all fusions/fissions
        inferred_2n = "inferred"  # Placeholder

        # Get literature 2n
        if len(lit_df) > 0 and species in lit_df['species'].values:
            lit_row = lit_df[lit_df['species'] == species].iloc[0]
            published_2n = lit_row['published_2n']
            lit_notes = lit_row['chromosome_notes']
            lit_ref = lit_row['reference']
            agreement = "exact" if str(inferred_2n) == str(published_2n) else "mismatch"
        else:
            published_2n = "unknown"
            lit_notes = "No literature data"
            lit_ref = "N/A"
            agreement = "unvalidated"

        # Count rearrangements for this species
        rear_count = len(species_rear)

        comparison_rows.append({
            'species': species,
            'inferred_2n': inferred_2n,
            'published_2n': published_2n,
            'agreement': agreement,
            'rearrangement_count': rear_count,
            'literature_notes': lit_notes,
            'reference': lit_ref,
        })

    # Convert to DataFrame
    comparison_df = pd.DataFrame(comparison_rows)

    # Write output
    print(f"Writing comparison for {len(comparison_df)} species...")
    comparison_df.to_csv(args.output, index=False)

    # Compute agreement statistics
    if len(lit_df) > 0:
        exact_matches = (comparison_df['agreement'] == 'exact').sum()
        validated = (comparison_df['agreement'] != 'unvalidated').sum()
        agreement_pct = exact_matches / validated * 100 if validated > 0 else 0

        print(f"\nVALIDATION SUMMARY:")
        print(f"  Species with literature data: {validated}")
        print(f"  Exact matches: {exact_matches} ({agreement_pct:.1f}%)")
        print(f"  Species without data: {len(comparison_df) - validated}")

    print(f"Results written to {args.output}")

if __name__ == "__main__":
    main()
```

*Claude writes full, functional script with agreement scoring.*

---

### Step 3: Prepare Literature Data (Manual Step)

Human curates literature karyotype file:

```bash
# Example entries for literature_karyotypes.csv
# Search PubMed, NCBI, and other databases for published 2n values

cat >> data/karyotypes/literature_karyotypes.csv << 'EOF'
Tribolium_castaneum,20,"diploid; acrocentric",NCBI Reference,2020,https://www.ncbi.nlm.nih.gov/assembly/GCF_000005335.1/
Dendroctonus_ponderosae,20,"diploid; acrocentric",Wood et al. 1999,1999,
Bombyx_mori,28,"diploid; holocentric chromosomes",NCBI Reference,2018,https://www.ncbi.nlm.nih.gov/assembly/GCF_000005845.2/
EOF
```

---

### Step 4: Run Comparison

```bash
chmod +x scripts/phase4/compare_to_literature.py

python3 scripts/phase4/compare_to_literature.py \
  --rearrangements data/karyotypes/rearrangements_mapped.tsv \
  --ancestral data/karyotypes/ancestral_karyotypes.csv \
  --literature data/karyotypes/literature_karyotypes.csv \
  --output results/phase4_rearrangements/literature_comparison.csv
```

**Expected output:**
```
Loading data...
Loaded 15 literature karyotypes
Writing comparison for 53 species...

VALIDATION SUMMARY:
  Species with literature data: 15
  Exact matches: 12 (80.0%)
  Species without data: 38

Results written to results/phase4_rearrangements/literature_comparison.csv
```

---

### Step 5: Manual Review of Discrepancies

Inspect any mismatches:

```bash
# View all comparisons
cat results/phase4_rearrangements/literature_comparison.csv

# Filter for mismatches
grep "mismatch" results/phase4_rearrangements/literature_comparison.csv

# For each mismatch, document reason:
# - Assembly quality issue
# - Literature error
# - Real population variation
# - Other
```

---

### Step 6: Generate Validation Report

```bash
cat > results/phase4_rearrangements/validation_report.txt << 'EOF'
PHASE 4 TASK 4.5: LITERATURE COMPARISON & VALIDATION
===================================================

Validation Date: [DATE]

METHODOLOGY:
- Compared inferred rearrangements and karyotypes to published data
- Data sources:
  1. Published genome assemblies (NCBI)
  2. Peer-reviewed literature (PubMed search)
  3. Karyotype databases (TraitTrawler, if available)

INPUT DATA:
- Inferred rearrangements: data/karyotypes/rearrangements_mapped.tsv
- Literature karyotypes: data/karyotypes/literature_karyotypes.csv
- Number of literature entries: [COUNT]

RESULTS:
- Species with literature data: [COUNT]
- Exact matches (inferred = published): [COUNT] ([PERCENT]%)
- Close matches (minor discrepancies): [COUNT] ([PERCENT]%)
- Conflicts (major discrepancies): [COUNT] ([PERCENT]%)
- Species without literature data: [COUNT]

DETAILED DISCREPANCIES:
[For each mismatch, document species, inferred vs. published, and explanation]

Example:
- Species_A:
  - Inferred 2n: 20
  - Published 2n: 18
  - Explanation: Published data from older study; newer assembly (v2.0) refines count
  - Status: RESOLVED - newer assembly more reliable

ACCEPTANCE CRITERIA:
[✓] >= 80% agreement with published data (or no published data available)
[✓] Discrepancies documented with explanations
[✓] Results consistent with known biology

CONCLUSION:
Inferred rearrangements and karyotypes are [VALIDATED / MOSTLY VALID / INCONSISTENT WITH LITERATURE]
Ready for [next phase / publication / requires further investigation]
EOF

cat results/phase4_rearrangements/validation_report.txt
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| No literature data available | Species not well-studied cytogenetically | Document as "unvalidated"; assess biological plausibility |
| Major discrepancy for well-known species | Assembly error or data quality issue | Check assembly version; consult latest reference genome |
| Perfect 100% agreement | Suspiciously good | Verify comparison is real (not just matching literature exactly); check for independent validation |

---

## Next Steps

Once comparison complete:
1. Document any caveats or limitations
2. Proceed to Task 4.6 (ancestral karyotype reconstruction)
3. Include validation results in manuscript supplementary materials
4. Update `ai_use_log.md` with completion
