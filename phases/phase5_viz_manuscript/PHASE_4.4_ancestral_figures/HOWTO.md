# HOWTO 5.4: Create Ancestral Karyotype Schematic Diagrams

**Responsible Person:** Claude (AI), reviewed by Heath
**Input files:**
- data/karyotypes/ancestral_karyotypes.csv
- data/karyotypes/rearrangements_mapped.tsv

**Output files:**
- manuscript/figures/ancestral_karyotype_figures.pdf (schematic karyotypes at major phylogenetic nodes)

**Duration:** 0.5 day

---

## Overview

Create publication-quality schematic karyotype diagrams for the major ancestral nodes in the Coleoptera phylogeny. These schematics illustrate:

1. Chromosome number and morphology (acrocentric, metacentric, submetacentric) at each node
2. Major rearrangements that occurred between successive nodes (inversions, translocations, fusions, fissions)
3. The evolutionary trajectory of genome organization across the tree

---

## Detailed Steps

### Step 1: Identify Major Phylogenetic Nodes

Select 5–8 key nodes representing major divergences in Coleoptera:
- Root of Coleoptera
- Major clade divergences (e.g., Adephaga, Polyphaga)
- Representative subclades (choose 1–2 per major clade)

For each node, record:
- Node ID
- Estimated age (time since MRCA)
- Taxa descending from this node
- Key species in downstream clades (for context)

**Output:** scripts/phase5/ancestral_nodes_selected.txt with one node per line

### Step 2: Parse Ancestral Karyotype Data

From data/karyotypes/ancestral_karyotypes.csv, extract for each selected node:

Expected columns:
```
node_id	clade_name	estimated_age_mya	chromosome_count	chromosome_morphologies	chromosome_structure_json	notes
```

Example:
```
node_001	Coleoptera_root	150	20	8x_acrocentric + 4x_metacentric + 8x_submetacentric	{"chr1": "metacentric", "chr2": "acrocentric", ...}	Ancestral karyotype inferred from synteny
```

Parse JSON or comma-separated morphology string into structured format.

### Step 3: Design Karyotype Schematics

For each ancestral node, create a schematic showing:
- **Chromosome representation:** Each chromosome drawn as a line segment or stylized karyogram
- **Morphology coding:**
  - Acrocentric (dot at one end): ▼
  - Metacentric (dot in middle): ◆
  - Submetacentric (dot off-center): ◇
- **Chromosome numbering:** Label each chromosome with ID (chr1, chr2, etc.) or just count them
- **Banding (optional):** Show broad heterochromatin (dark) vs. euchromatin (light) regions if data available
- **Layout:** Arrange chromosomes in 3 columns to fit on a standard page

Example text representation (actual PDF will be graphical):
```
Node 001: Coleoptera ancestor (2n=20)
▼ chr1   ◆ chr2   ▼ chr3
▼ chr4   ◆ chr5   ▼ chr6
... (7 more)
```

### Step 4: Annotate Rearrangements Between Nodes

For each adjacent node pair in the selected set, identify and annotate rearrangements:
- From data/karyotypes/rearrangements_mapped.tsv, filter for rearrangements on branches connecting the two nodes
- Annotate type and affected chromosomes

Example annotation:
```
Ancestor A → Ancestor B
- Inversion on chr3 (1 Mb region)
- Translocation: chr1 ↔ chr5 fusion → new chromosome
- Net result: 2n reduced from 20 to 18
```

Place annotations below/beside the ancestral karyotype diagrams.

### Step 5: Create Publication Figure

Arrange selected ancestral nodes and their rearrangements in a vertical or diagonal layout that mirrors the phylogenetic tree:

**Layout option 1 (Vertical timeline):**
- Top: Coleoptera root (most ancestral)
- Middle: Major divergence nodes
- Bottom: Representative extant species karyotypes (for comparison)

**Layout option 2 (Tree-aligned):**
- Position each ancestral karyotype at its corresponding node on a simplified phylogenetic tree
- Draw branches connecting ancestor to descendant
- Label branches with rearrangement summary (e.g., "1 inversion, 1 fusion")

**Styling:**
- Consistent chromosome morphology symbols across all panels
- Clear node labels and estimated ages
- Color-code rearrangement types if desired (e.g., red = inversions, blue = translocations)
- High-quality PDF rendering (300 dpi)

### Step 6: Export PDF

Save as manuscript/figures/ancestral_karyotype_figures.pdf with:
- All schematic karyotypes rendered at high quality
- Annotations readable (font size ≥ 10 pt)
- Consistent styling throughout
- Figure caption (200+ words) explaining interpretation

---

## Data Format Notes

**ancestral_karyotypes.csv expected format:**
```
node_id,clade_name,species_descending_from_node,estimated_age_mya,chromosome_count,morphology_summary,structure_details,confidence
node_001,Coleoptera,All beetles,150,20,8A+4M+8S,"[detailed chromosome-by-chromosome description]",high
node_002,Adephaga,Carabidae+Dytiscidae,120,20,8A+4M+8S,"[detailed]",high
```

Where A=acrocentric, M=metacentric, S=submetacentric

---

## Quality Checklist (Human Review)

- [ ] Chromosome numbers match between ancestral nodes and literature data (if available)
- [ ] Morphology symbols are consistent and legible
- [ ] Rearrangement annotations are accurate and clearly explained
- [ ] Node ages are reasonable given known timescale
- [ ] Figure layout is visually clear and not cluttered
- [ ] Captions fully explain how to interpret schematics
- [ ] PDF renders correctly at 300 dpi
- [ ] All ancestor-descendant relationships are correctly represented

---

## Reproducibility Notes

- Save scripts/phase5/build_ancestral_karyotypes.R with all figure generation code
- Include data processing steps (parsing JSON, filtering rearrangements)
- Document any assumptions or inferences made about chromosome morphology
- Save intermediate schematic files (if using graphical tools) in results/phase5_viz_manuscript/karyotype_schematics/
