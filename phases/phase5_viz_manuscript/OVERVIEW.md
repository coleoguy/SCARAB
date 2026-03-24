# Phase 5: Visualization, Data Release & Manuscript

**Goal:** Create publication figures, interactive browser, data release package, draft Results section, submit preprint

**Timeline:** Days 30–35 (5 working days)

**Input from Phase 4:**
- results/phase4_rearrangements/rearrangements_per_branch.tsv
- data/karyotypes/ancestral_karyotypes.csv
- data/karyotypes/rearrangements_mapped.tsv

**Deliverable:** Preprint submitted to bioRxiv by Day 35

---

## Phase 5 Tasks

### Task 5.1: Interactive Phylogenetic Tree Visualization
**File:** HOWTO_01_interactive_tree.md
**Input:** data/genomes/constraint_tree.nwk, results/phase4_rearrangements/rearrangements_per_branch.tsv, data/karyotypes/ancestral_karyotypes.csv
**Output:** results/phase5_viz_manuscript/beetle_tree_interactive.html, scripts/phase5/build_interactive_tree.R (or .js)
**Owner:** Claude (AI) + Heath review
**Duration:** 1 day

### Task 5.2: Synteny Dotplot Gallery
**File:** HOWTO_02_synteny_dotplots.md
**Input:** data/synteny/synteny_anchored.tsv
**Output:** manuscript/figures/synteny_dotplots.pdf, scripts/phase5/generate_dotplots.R
**Owner:** Claude (AI) + Heath review
**Duration:** 1 day

### Task 5.3: Rearrangement Hotspot Visualizations
**File:** HOWTO_03_hotspot_viz.md
**Input:** results/phase4_rearrangements/rearrangements_per_branch.tsv, data/karyotypes/rearrangements_mapped.tsv
**Output:** manuscript/figures/hotspot_figures.pdf, scripts/phase5/hotspot_viz.R
**Owner:** Claude (AI) + Heath review
**Duration:** 1 day

### Task 5.4: Ancestral Karyotype Figures
**File:** HOWTO_04_ancestral_figures.md
**Input:** data/karyotypes/ancestral_karyotypes.csv, data/karyotypes/rearrangements_mapped.tsv
**Output:** manuscript/figures/ancestral_karyotype_figures.pdf
**Owner:** Claude (AI) + Heath review
**Duration:** 0.5 day

### Task 5.5: Data Release Package
**File:** HOWTO_05_data_release.md
**Input:** All data/ and results/ from Phases 1–4
**Output:** results/phase5_viz_manuscript/scarab_release/ (structured directory), results/phase5_viz_manuscript/scarab_release.tar.gz
**Owner:** Claude (AI) + Heath review
**Duration:** 0.5 day

### Task 5.6: Manuscript Figures & Results Draft
**File:** HOWTO_06_manuscript_figures_results.md
**Input:** All manuscript/figures/ from Tasks 5.1–5.4, all results/ from Phases 1–4
**Output:** manuscript/figures/figure1_phylogeny_overview.pdf through figure4_rates.pdf, manuscript/drafts/results_section.docx, manuscript/drafts/preprint_v1.docx
**Owner:** Claude (AI) + Heath review
**Duration:** 2 days

---

## Success Criteria

- [ ] Interactive tree viewable in web browser with zoom, pan, rearrangement overlay
- [ ] All dotplot panels high-resolution (300 dpi minimum)
- [ ] Hotspot visualizations highlight breakpoint clusters and rate variation
- [ ] Ancestral karyotypes clearly labeled at major nodes
- [ ] Data release tarball includes metadata, documentation, code provenance
- [ ] Results section (3,000+ words) drafted with all figures embedded
- [ ] Preprint PDF assembled and formatted for bioRxiv
- [ ] All AI code reviewed and logged (ai_use_log.md)
- [ ] All manuscripts tracked in project_management/contributions_tracker.md
