# HOWTO 5.6: Assemble Manuscript Figures and Draft Results Section

**Responsible Person:** Claude (AI), reviewed by Heath
**Input files:**
- All outputs from Tasks 5.1–5.4 (interactive tree, dotplots, hotspots, ancestral karyotypes)
- All results files from Phases 1–4
- Any existing manuscript outline or methods section

**Output files:**
- manuscript/figures/figure1_phylogeny_overview.pdf
- manuscript/figures/figure2_synteny_dotplots.pdf
- manuscript/figures/figure3_hotspots.pdf
- manuscript/figures/figure4_ancestral_karyotypes.pdf
- manuscript/figures/supplementary_figures/ (if needed)
- manuscript/drafts/results_section.docx (3,000–5,000 words)
- manuscript/drafts/preprint_v1.docx (full preprint document)

**Duration:** 2 days

---

## Overview

Integrate all visualization outputs into publication-ready figures and draft a comprehensive Results section. This culminates the analysis and prepares the preprint for submission to bioRxiv.

---

## Part 1: Assemble Figures

### Figure 1: Phylogeny Overview & Rearrangement Summary

Combine:
- **Panel A:** Phylogenetic tree of all 438 beetle and outgroup genomes (from phase 2 or simplified version)
  - Species names at tips
  - Branch lengths proportional to evolutionary distance (if available)
  - Major clades highlighted or labeled (Adephaga, Polyphaga, etc.)

- **Panel B:** Overlay of rearrangement counts on tree
  - Color-coded branches (from Phase 5.1 interactive tree)
  - Colorbar legend showing rearrangement count scale

- **Panel C:** Phylogenetic distribution of rearrangement types
  - Bar chart or pie chart showing proportion of inversions, translocations, fusions across tree
  - Or: separate subpanels for each rearrangement type distribution

**Layout:** Figure 1 spans full page width (180 mm) or two-column format. Panels arranged A (left, 100×150 mm), B (middle, 50×150 mm), C (right, 50×150 mm).

**Caption (150–250 words):**
```
Figure 1: Phylogenetic distribution of chromosomal rearrangements in beetles.
(A) Phylogenetic tree of 438 beetle and outgroup genomes (Coleoptera) built from whole-genome
synteny analysis. Tree topology derived from constraint-based approach (Methods).
Species names shown at tips; major clades highlighted. (B) Rearrangement counts
mapped to phylogenetic branches. Branch colors indicate total number of chromosomal
rearrangements (inversions, translocations, fusions) inferred for each lineage.
Color scale ranges from white (0 rearrangements) to red (maximum). (C) Relative
proportions of rearrangement types across major clades. Inversions (blue),
translocations (red), fusions (green), other (gray).
```

### Figure 2: Synteny Dotplots

**Panels A–T (or as many as fit):** Selected synteny dotplots (15–20 species pairs)
- Close pairs in top row
- Intermediate pairs in middle rows
- Distant pairs at bottom

Each panel shows:
- Species names in title (e.g., "Tribolium × Dendroctonus")
- Dotplot with anchored synteny
- Collinearity visible as diagonal
- Inversions visible as "kinks" or reversals in diagonal

**Layout:** 4 columns × 5 rows (or 5×4) = 20 panels, each 40×40 mm

**Caption (150–200 words):**
```
Figure 2: Comparative synteny across beetle diversity.
Dotplots of syntenic alignments for representative species pairs spanning
evolutionary distances from recent divergence (top) to deep divergences (bottom).
Each point represents a synteny anchor (homologous genomic segment with conserved
order). X-axis: genome position in species 1; Y-axis: genome position in species 2.
Diagonal collinearity indicates conserved gene order (synteny). Deviations from
diagonal reveal inversions (local reversals), translocations (abrupt jumps between
chromosomes), and fusions (large jumps within a chromosome). Close pairs (top) show
tight collinearity; distant pairs (bottom) show extensive rearrangement.
```

### Figure 3: Rearrangement Hotspots

Combine three subpanels from Task 5.3:
- **Panel A:** Radial phylogenetic tree with rearrangement coloring (100×100 mm)
- **Panel B:** Heatmap of rearrangement types by branch (80×80 mm)
- **Panel C:** Genome-wide breakpoint density (180×60 mm, spanning full width below A+B)

**Layout:** A and B side by side at top, C spans full width below.

**Caption (200–250 words):**
```
Figure 3: Rearrangement hotspots and branch-level variation.
(A) Radial phylogenetic tree with branches colored by rearrangement count.
Inner ring: phylogenetic tree; outer coloring: intensity of chromosomal
rearrangement activity per lineage. Root at center; species tips at periphery.
(B) Heatmap of rearrangement type composition across major branches. Rows:
major lineages (ordered phylogenetically); columns: rearrangement type
(inversions, translocations, fusions, etc.). Cell intensity reflects count of
each type per branch. (C) Genome-wide distribution of breakpoint density across
beetles' estimated ancestral genome. X-axis: genomic position (Mb, concatenated
across all chromosomes); Y-axis: density of breakpoints (count per 5 Mb window).
Shaded regions: hotspots (density > 95th percentile). Arrows: significant hotspot
regions associated with pericentromeric heterochromatin or segmental duplications.
```

### Figure 4: Ancestral Karyotype Evolution

Display schematic karyotypes at 5–8 major nodes, arranged along a simplified phylogenetic tree or as a timeline.

- **Top:** Coleoptera ancestor (root)
- **Middle rows:** Major clade ancestors
- **Bottom:** Representative extant species (for comparison)

For each node:
- Schematic chromosomes with morphology symbols
- Chromosome number labeled
- Major rearrangements annotated between successive nodes (arrows or labels)

**Layout:** Vertical layout down the page, with simplified tree on left and karyotypes on right (180×250 mm)

**Caption (200–250 words):**
```
Figure 4: Evolution of beetle genome organization.
Schematic karyotypes showing chromosome number and morphology at major
phylogenetic nodes. Top: reconstructed ancestral karyotype for Coleoptera
(root). Middle: ancestors at major clade divergences (Adephaga, Polyphaga,
and key subclades). Bottom: representatives of extant species for comparison.
Each chromosome shown as line segment colored by morphology: acrocentric
(centromere at one end, blue), metacentric (centromere in middle, red),
submetacentric (centromere off-center, yellow). Arrows between successive
nodes indicate major rearrangement events and net change in chromosome number.
Abbreviations: 2n, diploid chromosome number; A, acrocentric; M, metacentric;
S, submetacentric.
```

### Supplementary Figures (if needed)

Create supplementary_figures/ directory with:
- **Supplementary Figure 1:** Detailed phylogenetic tree with node ages and confidence intervals
- **Supplementary Figure 2:** Rearrangement rate per unit time (if phylogenetic dating available)
- **Supplementary Figure 3:** Comparison to literature karyotypes (validation)
- **Supplementary Figure 4:** Interactive tree screenshot or explanation
- Any other supporting analyses

---

## Part 2: Draft Results Section

Write a comprehensive Results section (3,000–5,000 words) organized by major findings:

### Outline:

1. **Phylogenetic Framework** (500 words)
   - Describe tree topology and species sampling
   - Phylogenetic placement of 50 beetles
   - Distinguish major clades (Adephaga, Polyphaga)
   - Mention phylogenetic dating (if available)

2. **Synteny and Comparative Genomics** (800 words)
   - Summary statistics: number of synteny anchors across species pairs
   - Average collinearity by evolutionary distance (e.g., close pairs = 95% collinearity, distant = 40%)
   - Identification of inversions, translocations, fusions from dotplots
   - Representative examples from Figure 2

3. **Rearrangement Inventory** (800 words)
   - Total number of rearrangements called
   - Breakdown by type (inversions, translocations, fusions, etc.)
   - Branch-by-branch summary: which lineages have high vs. low rearrangement rates
   - Interpretation: fast-evolving lineages vs. conserved lineages

4. **Hotspot Analysis** (600 words)
   - Identification of breakpoint hotspots (high-density regions)
   - Chromosomal location of hotspots
   - Association with genome features (heterochromatin, repeats, etc.) if known
   - Implications for mechanisms of rearrangement

5. **Ancestral Karyotype Reconstruction** (800 words)
   - Estimated ancestral karyotype for Coleoptera (chromosome number, morphology)
   - Changes in chromosome number across major divergences
   - Reconstructed karyotypes at key nodes
   - Confidence assessment

6. **Validation and Comparison to Literature** (400 words)
   - Comparison of inferred ancestral karyotypes to published cytogenetic data
   - Discrepancies and resolution
   - Concordance rate with literature estimates

### Style and Structure:

- Use past tense ("we found," "data show")
- Cite figures explicitly: "As shown in Figure 1B, rearrangement counts vary widely across branches"
- Include quantitative details: "A total of 247 rearrangements were identified across the phylogeny, comprising 142 inversions (57%), 78 translocations (32%), and 27 fusions (11%)"
- Subsection headings for clarity
- Maintain consistent terminology

### Example opening paragraph:

```
## Results

### Phylogenetic Framework

We constructed a comprehensive phylogenetic tree of 438 beetle and outgroup genomes (Coleoptera)
using whole-genome synteny analysis (Figure 1A). The tree included representatives
from major families and clades, including Adephaga (ground beetles, water beetles;
n=15) and Polyphaga (all other beetles; n=35). Phylogenetic placement was inferred
using a constraint-based approach (Methods) that preserves synteny block conservation,
yielding a tree with strong support across major nodes. The tree's topology was
consistent with existing molecular phylogenies (citations), confirming expected
relationships among major clades.
```

---

## Part 3: Assemble Full Preprint

Use Word, Google Docs, or LaTeX to create a complete preprint document with:

1. **Title page**
   - Title: "Genome-wide Rearrangement Dynamics in Beetles: A Comparative Cytogenomics Study"
   - Authors: Heath Blackmon, [other contributors]
   - Affiliation: Department of Entomology, Texas A&M University
   - Date: March 2026

2. **Abstract** (250 words)
   - Background: Chromosomal rearrangements shape genome evolution
   - Methods: Comparative genomics across 438 beetle and outgroup genomes
   - Results: X inversions, Y translocations, Z fusions identified
   - Key finding: Rearrangement rates vary widely across lineages; hotspots identified
   - Implications: Insights into mechanisms of genome evolution in insects

3. **Introduction** (800–1000 words)
   - Importance of chromosomal rearrangements
   - Prior work on insects and comparisons to other groups
   - SCARAB project and rationale
   - Coleoptera as model system (diversity, economic importance, available genomes)
   - Research questions: What is the extent of rearrangement variation? Are there hotspots?

4. **Methods** (1000–1500 words)
   - Genome selection and curation
   - Phylogenetic tree construction
   - Whole-genome alignment (HAL)
   - Synteny extraction
   - Rearrangement calling
   - Ancestral reconstruction
   - Include references to external tools (BLAST, minimap2, progressiveCactus)

5. **Results** (3000–5000 words) — see Part 2 above

6. **Discussion** (1000–1500 words)
   - Interpretation of main findings
   - Comparison to other arthropods and vertebrates
   - Evolutionary implications
   - Mechanisms of rearrangement (recombination, selection, drift)
   - Limitations and future directions

7. **Figures and Figure Legends**
   - Embed or link to Figures 1–4 and Supplementary Figures

8. **References**
   - Include all citations from Methods and Discussion
   - Format as BibTeX or manually formatted

### Output format:

Save as:
- Microsoft Word (.docx) – manuscript/drafts/preprint_v1.docx
- PDF for review – manuscript/drafts/preprint_v1.pdf

---

## bioRxiv Submission Checklist

Before final submission, verify:

- [ ] All figures are in PDF format (300 dpi minimum)
- [ ] Figure legends are self-contained and complete (can be read independently)
- [ ] All abbreviations are defined on first use
- [ ] All citations are complete (author, year, title, journal)
- [ ] Supplementary materials listed and referenced
- [ ] Data availability statement includes accession numbers and URLs
- [ ] No proprietary or confidential information in manuscript
- [ ] Authorship and contributor roles clearly stated
- [ ] Acknowledgments include funding and institutional support
- [ ] Preprint version number and date included

### Suggested Data Availability Statement:

```
All data and code are available in the SCARAB data release
(DOI: [TBD at submission]). Specific files and access instructions are
provided in the supplementary materials. Large files (whole-genome alignments)
are available from the authors or the TAMU HPC facility upon request.
```

---

## Quality Checklist (Human Review)

- [ ] All figures high-resolution (300 dpi) and properly formatted
- [ ] Figure captions comprehensive and accurately describe content
- [ ] Results section is accurate and supported by data
- [ ] Quantitative statements (e.g., "247 rearrangements") verified against raw data
- [ ] Comparisons to literature are fair and properly cited
- [ ] No typos or grammatical errors
- [ ] Manuscript flows logically and is easy to follow
- [ ] All AI-generated text has been reviewed and edited by human
- [ ] All methods sufficiently detailed for reproduction
- [ ] Preprint PDF renders correctly and is readable

---

## Notes on Authorship and AI Contribution

In the methods or acknowledgments, include:

```
### AI Contribution Disclosure

Computational code for visualization and some analyses was generated with
assistance from Claude (Anthropic), an AI language model. All code was reviewed
and validated by H.B. before use. A detailed log of AI-generated code and review
status is provided in supplementary materials (ai_code_provenance.md).
```

This ensures transparency and allows readers to assess the role of AI in the work.
