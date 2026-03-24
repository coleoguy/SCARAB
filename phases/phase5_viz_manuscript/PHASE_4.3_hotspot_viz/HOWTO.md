# HOWTO 5.3: Create Rearrangement Hotspot Visualizations

**Responsible Person:** Claude (AI), reviewed by Heath
**Input files:**
- results/phase4_rearrangements/rearrangements_per_branch.tsv
- data/karyotypes/rearrangements_mapped.tsv

**Output files:**
- manuscript/figures/hotspot_figures.pdf (multi-panel figure)
- scripts/phase5/hotspot_viz.R (reproducible script)

**Duration:** 1 day

---

## Overview

Create three complementary visualizations to highlight rearrangement hotspots:

1. **Radial tree with branch coloring:** Branch thickness/color indicates rearrangement density
2. **Heatmap:** Rearrangement count matrix (branches × rearrangement type)
3. **Genome-wide density plot:** Identify breakpoint clusters across the genome

These visualizations answer: *Where in the genome do rearrangements cluster? Which branches accumulate the most?*

---

## Detailed Steps

### Step 1: Parse Input Data

**File 1: results/phase4_rearrangements/rearrangements_per_branch.tsv**

Expected columns:
```
branch_id	species_pair	rearrangement_count	inversions	translocations	fusions	deletions	insertions	breakpoint_density
```

Example:
```
branch_001	coleopteran_anc_A → tribolium	8	3	2	2	1	0	0.002
branch_002	tribolium → tribolium_subspecies	2	1	1	0	0	0	0.0005
```

**File 2: data/karyotypes/rearrangements_mapped.tsv**

Expected columns:
```
rearrangement_id	branch_id	type	chromosome	start_position	end_position	description
```

Example:
```
rear_001	branch_001	inversion	chr1	1000000	2000000	Large inversion in pericentromeric region
rear_002	branch_001	translocation	chr1,chr2	1500000,500000	...	Translocation between chr1 and chr2
```

### Step 2: Compute Hotspot Statistics

1. **Breakpoint density by chromosome:**
   - For each chromosome, count number of unique breakpoints within sliding windows (e.g., 5 Mb windows)
   - Identify regions with density > 95th percentile as "hotspots"

2. **Rearrangement rate by branch:**
   - Compute rearrangements per million years (if branch dates available) or per genomic distance
   - Identify branches with highest rates

3. **Rearrangement type distribution:**
   - Tally inversions, translocations, fusions, etc., per branch
   - Compute proportions

### Step 3: Create Radial Tree with Branch Coloring

**Visualization:**
- Start with phylogenetic tree layout (from Phase 2 or Phase 5.1 data)
- Draw tree in radial layout (root at center, tips at periphery)
- Color each branch by rearrangement count (colormap: white → yellow → orange → red)
- Optionally vary branch thickness by rearrangement rate
- Add legend: color scale and branch thickness scale

**Tool:** Use ggtree + ggplot2 in R, or phylotools in Python

**Output dimensions:** 300 mm diameter circle, 300 dpi

### Step 4: Create Heatmap

**Visualization:**
- Rows = branches (ordered by phylogenetic position or rearrangement count)
- Columns = rearrangement types (inversions, translocations, fusions, etc.)
- Cell values = count
- Colors: white (0) → light blue (low) → dark blue (high)

**Annotations:**
- Row labels: branch_id or species pair name
- Column labels: rearrangement type
- Cell values shown numerically (if heatmap is not too large)
- Include total rearrangement count per branch as a separate column on the right

**Tool:** ggplot2 + geom_tile() or pheatmap package

### Step 5: Create Genome-Wide Density Plot

**Visualization:**
- X-axis: genome position (in order, showing all chromosomes concatenated or separated)
- Y-axis: breakpoint density (count per 5 Mb window)
- Bars or line plot showing density across genome
- Highlight hotspot regions (density > threshold) with shaded background
- Optional: stratify by rearrangement type (inversions, translocations, fusions in different colors)

**Tool:** ggplot2 with geom_col() or geom_line()

**Output dimensions:** width 250 mm (to fit 2-column page), height 150 mm

### Step 6: Assemble Multi-Panel Figure

Combine all three visualizations into one manuscript-ready figure:
- **Panel A:** Radial phylogenetic tree (size: 150 × 150 mm)
- **Panel B:** Heatmap of rearrangement types by branch (size: 120 × 100 mm)
- **Panel C:** Genome-wide density plot (size: 200 × 80 mm)

Add panel labels (A, B, C) and a detailed figure caption (200+ words) explaining:
- How to interpret each panel
- Key findings (which branches are hotspots? which chromosomes?)
- Methods used for hotspot detection

### Step 7: Export PDF

Save as manuscript/figures/hotspot_figures.pdf with:
- High resolution (300 dpi)
- Consistent color schemes across panels
- All labels readable (font size ≥ 9 pt)

---

## Quality Checklist (Human Review)

- [ ] Radial tree topology correct (matches constraint_tree.nwk)
- [ ] Color scale in radial tree clearly shows high-count branches
- [ ] Heatmap is legible (not too many branches to read row labels)
- [ ] Heatmap shows expected pattern (certain branches enriched for certain types)
- [ ] Density plot clearly identifies hotspots (expected to be non-uniform)
- [ ] Hotspot regions biologically plausible (not purely random)
- [ ] All three panels have consistent styling (fonts, colors, sizing)
- [ ] Figure caption is informative and self-contained
- [ ] PDF renders correctly in Adobe Reader and online viewers

---

## Reproducibility Notes

- Save scripts/phase5/hotspot_viz.R with all visualization code
- Define hotspot threshold (e.g., 95th percentile density) in script header
- Document which rearrangement types are included (all types or filtered subset?)
- If using sliding windows, document window size and step size
- Save intermediate data (hotspot table, branch statistics) to results/phase5_viz_manuscript/hotspot_analysis/
