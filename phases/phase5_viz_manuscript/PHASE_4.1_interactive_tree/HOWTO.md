# HOWTO 5.1: Create Interactive Phylogenetic Tree Visualization

**Responsible Person:** Claude (AI), reviewed by Heath
**Input files:**
- data/genomes/constraint_tree.nwk
- results/phase4_rearrangements/rearrangements_per_branch.tsv
- data/karyotypes/ancestral_karyotypes.csv

**Output files:**
- results/phase5_viz_manuscript/beetle_tree_interactive.html (interactive web visualization)
- scripts/phase5/build_interactive_tree.R (or build_interactive_tree.js if using D3.js)

**Duration:** 1 day

---

## Overview

Create an interactive phylogenetic tree that:
1. Displays the full Coleoptera phylogeny from constraint_tree.nwk
2. Color-codes branches by rearrangement count (gradient scale)
3. Shows ancestral karyotypes at internal nodes (hover tooltip or popup)
4. Includes interactive features: zoom, pan, branch collapse/expand
5. Scalable to hundreds of species without performance degradation

**Technology choice:** R Shiny (recommended for integration with existing R pipeline) OR D3.js (for lightweight standalone HTML)

---

## Detailed Steps

### Step 1: Parse Input Data

Load three files:
1. **constraint_tree.nwk** – Newick format phylogenetic tree
2. **rearrangements_per_branch.tsv** – Tab-separated with columns: branch_id, species_pair, rearrangement_count, rearrangement_types (inversions/translocations/fusions)
3. **ancestral_karyotypes.csv** – Comma-separated with columns: node_id, chromosome_count, chromosome_structure_summary

Map branch_id in rearrangements_per_branch.tsv to internal nodes in the phylogeny.

### Step 2: Compute Layout & Styling

For each branch in the tree:
- Assign a rearrangement color (colormap: white → light blue → dark blue → red, scaled to max rearrangement count)
- Assign branch width proportional to rearrangement count (or constant width with color emphasis)
- For internal nodes, prepare tooltip with:
  - Node ID
  - Estimated age (if available from phylogenetic analysis)
  - Ancestral karyotype summary
  - Number of rearrangements on descending branches

### Step 3: Build Interactive Visualization

**Option A (R Shiny):**
- Use ggtree R package for initial tree layout
- Convert to plotly/Shiny for interactivity
- Add reactive controls: filter by rearrangement type, zoom to clade, show/hide ancestral info
- Deploy as Shiny app or compile to standalone HTML via renderHTML()

**Option B (D3.js):**
- Parse Newick into JSON tree structure
- Use d3-phylotree or custom force layout
- Implement SVG-based circles for nodes, lines for branches
- Add mouseover tooltips with ancestral karyotype details
- Include zoom/pan via d3.zoom()

### Step 4: Add Annotations

For each branch, display:
- Rearrangement count as text label (optional, if space permits)
- Color legend at bottom: "Rearrangement count" with gradient scale
- Node legend: "Internal node = ancestral state"

Hover tooltip content example:
```
Species A → Species B
Rearrangements: 3 inversions, 1 translocation
Ancestor karyotype: 2n=20, 8 acrocentric + 4 metacentric
```

### Step 5: Export & Validate

- Save as results/phase5_viz_manuscript/beetle_tree_interactive.html
- Test in web browser (Chrome, Firefox, Safari)
- Verify:
  - Tree renders without JavaScript errors
  - Zoom/pan works smoothly
  - Hover tooltips appear correctly
  - File size < 10 MB (if using D3.js embedded data)

---

## Quality Checklist (Human Review)

- [ ] Tree topology matches constraint_tree.nwk (spot-check 5 random nodes)
- [ ] Rearrangement color scale is perceptually distinct
- [ ] Tooltip shows correct ancestral karyotypes (manually verify 3 nodes)
- [ ] Interactive features are responsive (< 500 ms latency)
- [ ] Browser console shows no JavaScript errors
- [ ] All species names are readable (font size ≥ 10pt at default zoom)
- [ ] Code is commented (if R Shiny) or well-structured (if D3.js)

---

## Reproducibility Notes

- If using R Shiny: save sessionInfo() output to scripts/phase5/sessioninfo_interactive_tree.txt
- If using D3.js: document D3 version and any external libraries in script header
- Include a data processing script (build_interactive_tree.R or .js) that regenerates the HTML from raw input files
