# Phase 4: Rearrangement Annotation & Tree Mapping

**Timeline:** Days 24–30 (7 days)
**Key Dependencies:** Phase 3 outputs (synteny_anchored.tsv, ancestral genomes, constraint tree)
**Compute Requirements:** Mostly local (no HPC required; simple Python scripts)

## Phase Goal

Call chromosomal rearrangements (inversions, translocations, fusions, fissions) from synteny block order changes, map each rearrangement onto the phylogenetic tree, compute branch-level rearrangement rates, identify evolutionary hotspots, and reconstruct ancestral karyotypes at major nodes.

## Phase Overview

This phase transforms pairwise synteny alignments into evolutionary rearrangement events. By comparing gene/block order in extant species to their inferred ancestral genomes, we identify what rearrangements occurred on each phylogenetic branch. We then:
- Classify rearrangements by type (inversion, translocation, fusion, fission)
- Assign confidence scores (Confirmed vs. Inferred vs. Artifact)
- Map each to its originating branch via parsimony
- Compute rates (rearrangements per branch per million years)
- Identify lineages with elevated rearrangement activity ("hotspots")
- Reconstruct 2n (chromosome number) and chromosome structure at internal nodes

**Compressed Timeline:**
- Days 24–26: Call rearrangements, classify, and tree-map
- Days 26–28: Compute branch statistics and compare to literature
- Days 28–30: Reconstruct ancestral karyotypes and finalize outputs

## Phase Inputs

### From Phase 3:
- **File:** `data/synteny/synteny_anchored.tsv`
  - Pairwise synteny blocks anchored to ancestral genomes
  - Columns: block_id, species_A, species_B, chr_A, chr_B, ..., ancestral_node, ancestral_chr, conservation_score

- **Directory:** `data/ancestral/`
  - `ancestral_*.fa` (reconstructed ancestral genome sequences)
  - `ancestral_metadata.csv` (node metadata, ages)

### From Phase 2:
- **File:** `data/genomes/constraint_tree.nwk`
  - Phylogenetic tree with 438 genomes (422 Coleoptera + 17 Neuropterida outgroups) and internal node labels
  - Branch lengths in millions of years

### External (Human-curated if available):
- **File:** TraitTrawler database or published karyotype tables (optional, for validation)

---

## Phase Tasks

### Task 4.1: Breakpoint Calling
**HOWTO file:** `HOWTO_01_breakpoint_calling.md`

Identify chromosomal rearrangements by comparing block order in extant vs. ancestral genomes. For each species, identify when the gene order changed from its ancestor, classify the type of rearrangement, and record breakpoints.

**Algorithm:**
1. For each extant species and its ancestral lineage
2. Compare block order on each chromosome
3. Identify regions where blocks are in different order or on different chromosomes
4. Classify as: inversion, translocation, fusion, or fission
5. Record breakpoint coordinates

**Outputs:**
- `scripts/phase4/call_rearrangements.py` (Claude-written)
- `data/karyotypes/rearrangements_raw.tsv`

**Expected output columns:**
```
rearrangement_id | type | species | ancestral_node | chr_involved | breakpoint_1 | breakpoint_2 | confidence
```

---

### Task 4.2: Rearrangement Filtering & Classification
**HOWTO file:** `HOWTO_02_filtering.md`

Classify rearrangements as **Confirmed** (supported by multiple synteny blocks or orthologous comparisons), **Inferred** (supported by single block pair or weak evidence), or **Artifact** (likely assembly or alignment error).

**Inputs:**
- `data/karyotypes/rearrangements_raw.tsv` (from Task 4.1)
- Filtering criteria (defined by Heath)

**Outputs:**
- `data/karyotypes/rearrangements_confirmed.tsv`
- `data/karyotypes/rearrangements_inferred.tsv`
- `data/karyotypes/rearrangements_artifact.tsv`
- `results/phase4_rearrangements/filtering_criteria.txt`

---

### Task 4.3: Phylogenetic Tree Mapping
**HOWTO file:** `HOWTO_03_tree_mapping.md`

Assign each rearrangement to a specific phylogenetic branch using parsimony. For each rearrangement, determine which branch of the tree it occurred on (i.e., the ancestral node where it originated and the descendant species where it's fixed).

**Algorithm:**
1. For each rearrangement and species pair
2. Trace back through the tree from species to its ancestor
3. Determine the branch where the rearrangement first appears
4. Use parsimony: rearrangement assigned to the deepest node where it's present

**Outputs:**
- `data/karyotypes/rearrangements_mapped.tsv` (adds branch_ancestral_node, branch_derived_node columns)

---

### Task 4.4: Branch-Level Rearrangement Statistics
**HOWTO file:** `HOWTO_04_branch_stats.md`

Count rearrangements per branch, normalize by branch length (time), and identify evolutionary hotspots (lineages with >2 standard deviations above mean rate).

**Outputs:**
- `results/phase4_rearrangements/rearrangements_per_branch.tsv`
- `results/phase4_rearrangements/branch_stats.csv`
- `results/phase4_rearrangements/rearrangement_figures.pdf` (includes rate plots, hotspot visualization)

---

### Task 4.5: Literature Comparison & Validation
**HOWTO file:** `HOWTO_05_literature_comparison.md`

Compare inferred rearrangements to published karyotype data. Check agreement with empirical cytogenetics literature or public databases (e.g., TraitTrawler, Anisimova et al.).

**Outputs:**
- `results/phase4_rearrangements/literature_comparison.csv`
- `results/phase4_rearrangements/validation_report.txt`

**Acceptance:** ≥80% agreement with literature (for species with published data)

---

### Task 4.6: Ancestral Karyotype Reconstruction
**HOWTO file:** `HOWTO_06_ancestral_karyotypes.md`

Reconstruct karyotype (2n, chromosome number and structure) at key ancestral nodes. Use mapped rearrangements to trace chromosome number changes (fusions ↓ 2n, fissions ↑ 2n) and generate diagrams.

**Outputs:**
- `data/karyotypes/ancestral_karyotypes.csv` (node, 2n, chromosome_structure)
- `results/phase4_rearrangements/ancestral_karyotype_diagrams.pdf` (visual summary)

---

## Data File Organization

```
SCARAB/
├── data/
│   ├── synteny/
│   │   └── synteny_anchored.tsv      (from Phase 3)
│   ├── ancestral/
│   │   ├── ancestral_*.fa             (from Phase 3)
│   │   └── ancestral_metadata.csv     (from Phase 3)
│   ├── genomes/
│   │   └── constraint_tree.nwk        (from Phase 2)
│   └── karyotypes/
│       ├── rearrangements_raw.tsv     (output Task 4.1)
│       ├── rearrangements_confirmed.tsv (output Task 4.2)
│       ├── rearrangements_inferred.tsv  (output Task 4.2)
│       ├── rearrangements_artifact.tsv  (output Task 4.2)
│       ├── rearrangements_mapped.tsv   (output Task 4.3)
│       └── ancestral_karyotypes.csv    (output Task 4.6)
├── scripts/phase4/
│   ├── call_rearrangements.py         (output Task 4.1)
│   ├── filter_rearrangements.py       (output Task 4.2)
│   ├── map_to_tree.py                 (output Task 4.3)
│   ├── compute_branch_stats.py        (output Task 4.4)
│   ├── compare_literature.py          (output Task 4.5)
│   └── reconstruct_karyotypes.py      (output Task 4.6)
└── results/phase4_rearrangements/
    ├── filtering_criteria.txt         (output Task 4.2)
    ├── rearrangements_per_branch.tsv  (output Task 4.4)
    ├── branch_stats.csv               (output Task 4.4)
    ├── rearrangement_figures.pdf      (output Task 4.4)
    ├── literature_comparison.csv      (output Task 4.5)
    ├── validation_report.txt          (output Task 4.5)
    └── ancestral_karyotype_diagrams.pdf (output Task 4.6)
```

---

## Critical Notes

### Rearrangement Confidence Scoring

**Confirmed:**
- Supported by ≥2 independent synteny block pairs
- Consistent across multiple pairwise comparisons
- High confidence in ancestral genome placement

**Inferred:**
- Supported by single synteny block pair
- Plausible but weaker evidence
- May be assembly artifact in one species

**Artifact:**
- Conflicting evidence from multiple comparisons
- Likely assembly or alignment error
- Discard for final analysis

### Hotspot Detection

A branch has elevated rearrangement rate if:
```
rate = rearrangements / branch_length_Ma
hotspot if: (rate - mean_rate) > 2 * SD(rates)
```

### Branch Time Estimates

Use branch lengths from constraint_tree.nwk (in millions of years) to compute time-normalized rates. This allows comparison across branches with different divergence times.

---

## Expected Results Summary

### Key Metrics to Report

1. **Total rearrangements:** [COUNT]
   - Confirmed: [COUNT]
   - Inferred: [COUNT]
   - Artifact: [COUNT]

2. **Rearrangement types:** [BREAKDOWN by inversion, translocation, fusion, fission]

3. **Hotspots:** [NUMBER and which lineages]

4. **Mean 2n in Coleoptera:**
   - MRCA Coleoptera: [2N]
   - Major clades: [2N values]

5. **Literature agreement:** [PERCENT]% concordant

---

## Next Phase
Phase 4 is the final computational phase. Outputs feed into publication-quality figures, supplementary tables, and manuscript writing (Phase 5, not detailed here).

---

## AI Use Tracking

All scripts in Phase 4 are written by Claude and logged in `ai_use_log.md`. Human reviews outputs and filtering criteria before finalizing.
