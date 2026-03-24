# HOWTO 5.2: Generate Synteny Dotplot Gallery

**Responsible Person:** Claude (AI), reviewed by Heath
**Input files:**
- data/synteny/synteny_anchored.tsv

**Output files:**
- manuscript/figures/synteny_dotplots.pdf (multi-page PDF with all dotplots)
- scripts/phase5/generate_dotplots.R (reproducible R script)

**Duration:** 1 day

---

## Overview

Create synteny dotplots (genome dot plots) for 15–20 representative species pairs spanning evolutionary distances:
- **Close pairs (recent divergence):** e.g., sibling species with minimal rearrangement
- **Intermediate pairs:** e.g., different genera
- **Distant pairs:** e.g., different families

Dotplots visualize collinearity (conserved gene order) and rearrangements (inversions, translocations, fusions).

---

## Detailed Steps

### Step 1: Select Representative Species Pairs

From the Coleoptera phylogeny (data/genomes/constraint_tree.nwk), select pairs that maximize coverage of evolutionary distances:

**Criteria:**
- At least 2 close pairs (divergence time < 10 mya)
- At least 2 intermediate pairs (10–50 mya)
- At least 2 distant pairs (> 50 mya, if available)
- Prioritize pairs with complete genomes (not too fragmented)
- Avoid pairs where one species has very poor assembly quality

**Output:** Create a file scripts/phase5/species_pairs_for_dotplots.txt with one pair per line, tab-separated: species1 \t species2 \t divergence_category

### Step 2: Extract & Prepare Synteny Data

From data/synteny/synteny_anchored.tsv:
- Filter alignments for each selected species pair
- Ensure anchored coordinates are in order (species1_genome_position, species2_genome_position)
- Group alignments by chromosome pair (chromosome_A in species1, chromosome_B in species2)

### Step 3: Generate Individual Dotplots

For each species pair, create a dotplot showing:
- **X-axis:** chromosome positions in species1 (Mb scale)
- **Y-axis:** chromosome positions in species2 (Mb scale)
- **Points:** synteny anchors (one dot per anchor)
- **Colors (optional):** color by anchor identity or alignment quality
- **Chromosome boundaries:** faint grid lines at chromosome boundaries
- **Title:** "Species1 vs. Species2 (N anchors, estimated divergence: X mya)"

**Use R package:** genoPlotR, ggplot2, or base R graphics

**Resolution:** 300 dpi, suitable for print

### Step 4: Arrange Multi-Panel Figure

Organize dotplots in a grid:
- **Page 1:** Close pairs (2–4 dotplots)
- **Page 2:** Intermediate pairs (2–4 dotplots)
- **Page 3+:** Distant pairs (2–4 dotplots)
- Each page should have consistent scaling and styling

Include a legend and figure caption explaining dotplot interpretation (collinear = same line, inversions = direction reversal, etc.)

### Step 5: Export PDF

Save as manuscript/figures/synteny_dotplots.pdf with:
- High resolution (300 dpi)
- Embedded fonts
- All axes labeled
- Figure numbers and captions in footer or in separate caption document

---

## Data Format Notes

**synteny_anchored.tsv format (from Phase 3):**
```
species1_id	species2_id	species1_chr	species1_start	species1_end	species2_chr	species2_start	species2_end	alignment_identity	anchor_id
```

Example:
```
tribolium	drosophila	scaffold_1	100000	102000	2L	5000000	5002000	0.95	anchor_001
```

---

## Quality Checklist (Human Review)

- [ ] 15–20 species pairs selected and justified
- [ ] All dotplots render correctly (no missing data, no axis errors)
- [ ] Diagonal structure visible for collinear regions (expected)
- [ ] Inversions appear as "flip" in diagonal (locally inverted orientation)
- [ ] Chromosome boundaries clearly marked
- [ ] Titles and captions are informative
- [ ] Resolution suitable for publication (300 dpi)
- [ ] PDF file opens in standard PDF reader without errors
- [ ] Species names spelled consistently with rest of manuscript

---

## Reproducibility Notes

- Save scripts/phase5/generate_dotplots.R with full hardcoded species pair list
- Include comments explaining selection criteria
- Save intermediate data (e.g., filtered synteny files per species pair) in results/phase5_viz_manuscript/synteny_filtered/
- Document any filtering thresholds (e.g., minimum anchor identity, maximum gap size) in script header
