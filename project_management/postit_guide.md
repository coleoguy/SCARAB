# PostIt Guide: SCARAB Scrum Board

**Board Setup:** Three columns on whiteboard or wall:
- **TO DO** (left) | **IN PROGRESS** (middle) | **DONE** (right)

---

## Color Code: Difficulty / Time

| Color | Meaning | Time | Example |
|-------|---------|------|---------|
| 🟢 **GREEN** | Quick task | < 2 hours | Merge CSVs, QC check, sign-off |
| 🟡 **YELLOW** | Half-day task | 2–6 hours | Write R script, curate genomes, build tree |
| 🟠 **ORANGE** | Full-day+ task | 1–3 days | Full pipeline setup, ancestral reconstruction |
| 🔴 **RED** | Extended / HPC | > 3 days or HPC wall-clock | Full alignment on Grace, manuscript writing |
| 🟣 **PURPLE** | Blocked / waiting | Depends on upstream | Waiting for HPC job, waiting for Heath review |

**Owner marker:** Write initials in top-right corner of PostIt
- **HB** = Heath | **CL** = Claude/AI | **SA/SB/SC** = Students

---

## PHASE 1: Literature Review (Week 1)

### LR.1 Search Similar Projects 🟡
```
LR.1 Search Similar Projects     [CL]
├─ Zoonomia GitHub + papers
├─ Beetle comparative studies
└─ Compile methods summary
```
**Time:** ~4 hrs | **Depends:** None
**Folder:** phases/phase1_literature_review/TASK_LR1_search_similar_projects/

---

### LR.2 Zoonomia Landscape Review 🟡
```
LR.2 Zoonomia Landscape          [CL]
├─ Read Zoonomia preprints
├─ Cite beetle karyotype studies
└─ Identify our unique angle
```
**Time:** ~4 hrs | **Depends:** LR.1
**Folder:** phases/phase1_literature_review/TASK_LR2_zoonomia_landscape/

---

### LR.3 Preprint Strategy 🟢
```
LR.3 Preprint Strategy           [HB]
├─ Target journal + timeline
├─ Figure outline
└─ Risk mitigation plan
```
**Time:** ~1 hr | **Depends:** LR.2
**Folder:** phases/phase1_literature_review/TASK_LR3_preprint_strategy/

---

## PHASE 2: Genome Inventory & QC (Week 1–2)

### 1.1 Mine NCBI Genomes 🟡
```
1.1 Mine NCBI Genomes             [CL]
├─ Coleoptera assembly query
├─ Filter: Scaffold+, N50>100kb
├─ Extract metadata → CSV
└─ Script: ncbi_mine.R
```
**Time:** ~4 hrs | **Depends:** None
**Folder:** phases/phase2_genome_inventory/PHASE_1.1_ncbi_mining/

---

### 1.2 Mine Ensembl Genomes 🟡
```
1.2 Mine Ensembl Genomes          [CL]
├─ REST API + Ensembl Metazoa
├─ Deduplicate vs NCBI
└─ Script: ensembl_mine.R
```
**Time:** ~3 hrs | **Depends:** 1.1 (for dedup)
**Folder:** phases/phase2_genome_inventory/PHASE_1.2_ensembl_mining/

---

### 1.3 Merge & Deduplicate 🟢
```
1.3 Merge & Deduplicate           [CL]
├─ Combine NCBI + Ensembl
├─ 1 assembly per species
└─ Script: merge_genomes.R
```
**Time:** ~1 hr | **Depends:** 1.1, 1.2
**Folder:** phases/phase2_genome_inventory/PHASE_1.3_merge_deduplicate/

---

### 1.4 Phylogenetic Placement 🟡
```
1.4 HEATH: Phylo Curation         [HB]
├─ Assign family/subfamily
├─ Flag problem assemblies
├─ Select final genomes (439 selected)
└─ Script helper: place_taxa.R
```
**Time:** ~4 hrs | **Depends:** 1.3
**Folder:** phases/phase2_genome_inventory/PHASE_1.4_phylogenetic_placement/

---

### 1.5 FASTA URLs & Checksums 🟡
```
1.5 Compile FASTA URLs            [Student]
├─ FTP links for all genomes
├─ Test accessibility (curl)
├─ SHA256 checksums
└─ Script: compile_urls.sh
```
**Time:** ~3 hrs | **Depends:** 1.4
**Folder:** phases/phase2_genome_inventory/PHASE_1.5_fasta_urls/

---

### 1.6 Build Constraint Tree 🟡
```
1.6 Build Constraint Tree          [CL+HB]
├─ Literature backbone topology
├─ Branch lengths (substitution rates)
├─ Validate in R (ape::read.tree)
└─ Script: build_tree.R
```
**Time:** ~5 hrs | **Depends:** 1.4
**Folder:** phases/phase2_genome_inventory/PHASE_1.6_constraint_tree/

---

### 1.7 Phase 1 QC Report 🟢
```
1.7 QC Report & Sign-Off          [CL+HB]
├─ Genome size/N50/BUSCO stats
├─ Phylogenetic coverage
├─ Script: qc_report.R
└─ → PHASE_1_SIGN_OFF.txt
```
**Time:** ~1 hr | **Depends:** 1.5, 1.6
**Folder:** phases/phase2_genome_inventory/PHASE_1.7_qc_report/

---

## PHASE 3: Alignment & Synteny (Week 2–5)

### 2.1 Pipeline Setup on Grace 🟠
```
2.1 Grace Pipeline Setup           [CL+HB]
├─ Pull Singularity container
├─ Create scratch dirs
├─ Test 3-genome alignment (short queue)
├─ Scripts: setup_grace.sh
│           test_alignment.slurm
└─ Validate HAL output
```
**Time:** ~1 day | **Depends:** 1.7
**Folder:** phases/phase3_alignment_synteny/PHASE_2.1_pipeline_setup/

---

### 2.2 Full Alignment (Subtree Decomposition) 🔴
```
2.2 FULL ALIGNMENT ON GRACE        [HB]
├─ split_tree.R → 5 subtrees
├─ submit_all.sh → parallel SLURM
├─ 5× subtree jobs (long, 48c, 384GB)
├─ 1× backbone (bigmem, 80c, 3TB)
├─ merge_subtrees.slurm
└─ ~1 week wall-clock
```
**Time:** ~7 days HPC wall-clock (submit ~30 min) | **Depends:** 2.1
**Folder:** phases/phase3_alignment_synteny/PHASE_2.2_full_alignment/
**Scripts:** split_tree.R, submit_subtree.slurm, submit_backbone.slurm, merge_subtrees.slurm, submit_all.sh

---

### 2.3 Extract Synteny Blocks 🟡
```
2.3 HAL → Synteny Blocks           [CL]
├─ halSynteny on final HAL
├─ ≥10kb collinear blocks
├─ Pairwise + multi-way
└─ Script: extract_synteny.slurm
```
**Time:** ~3 hrs (medium queue) | **Depends:** 2.2
**Folder:** phases/phase3_alignment_synteny/PHASE_2.3_hal_synteny_extraction/

---

### 2.4 Synteny QC 🟢
```
2.4 Synteny QC & Filtering         [Student]
├─ Remove <10kb, <95% identity
├─ Remove assembly artifacts
├─ Species-level summaries
└─ Script: synteny_qc.R
```
**Time:** ~2 hrs | **Depends:** 2.3
**Folder:** phases/phase3_alignment_synteny/PHASE_2.4_synteny_qc/

---

### 2.5 Ancestral Reconstruction (RACA) 🟠
```
2.5 Ancestral Genomes (RACA)       [CL+HB]
├─ RACA pipeline on Grace
├─ ~25 internal nodes
├─ long queue, 48c, 384GB
├─ Script: run_raca.slurm
└─ Output: ancestral_node_*.fa
```
**Time:** ~1–2 days HPC | **Depends:** 2.4, 1.6
**Folder:** phases/phase3_alignment_synteny/PHASE_2.5_ancestral_reconstruction/

---

### 2.6 Anchor Synteny to Ancestors 🟡
```
2.6 Synteny Anchoring              [CL]
├─ Map blocks → ancestral nodes
├─ BLAST to ancestor genomes
├─ Conservation scores
└─ Script: anchor_synteny.R
```
**Time:** ~3 hrs | **Depends:** 2.4, 2.5
**Folder:** phases/phase3_alignment_synteny/PHASE_2.6_synteny_anchoring/

---

### 2.7 Phase 2 Integration 🟢
```
2.7 Integration Report             [CL+HB]
├─ Alignment stats summary
├─ Synteny block distributions
├─ Script: integration_report.R
└─ → PHASE_2_SIGN_OFF.txt
```
**Time:** ~1 hr | **Depends:** 2.6
**Folder:** phases/phase3_alignment_synteny/PHASE_2.7_integration_signoff/

---

## PHASE 4: Rearrangement Analysis (Week 5–7)

### 3.1 Call Breakpoints 🟡
```
3.1 Call Rearrangements             [CL]
├─ Fusions, fissions, inversions
├─ ±5kb confidence intervals
├─ Ancestral node assignment
└─ Script: call_breakpoints.R
```
**Time:** ~3 hrs | **Depends:** 2.6
**Folder:** phases/phase4_rearrangements/PHASE_3.1_breakpoint_calling/

---

### 3.2 Filter: Confirmed vs Inferred 🟡
```
3.2 HEATH: Filter Rearrangements   [HB]
├─ Define confirmation criteria
├─ Manual spot-check ~50 calls
├─ Classify: confirmed/inferred/artifact
└─ Script: filter_rearrangements.R
```
**Time:** ~4 hrs | **Depends:** 3.1
**Folder:** phases/phase4_rearrangements/PHASE_3.2_filtering/

---

### 3.3 Map to Phylogeny 🟡
```
3.3 Map to Tree Branches           [CL]
├─ Parsimony assignment
├─ Ancestral → derived node
├─ Flag reversions
└─ Script: map_to_tree.R
```
**Time:** ~3 hrs | **Depends:** 3.2
**Folder:** phases/phase4_rearrangements/PHASE_3.3_tree_mapping/

---

### 3.4 Branch Statistics & Hotspots 🟡
```
3.4 Branch Stats & Hotspots        [Student]
├─ Per-branch counts
├─ Normalize by branch length
├─ Identify >2 SD hotspots
└─ Script: branch_statistics.R
```
**Time:** ~2 hrs | **Depends:** 3.3
**Folder:** phases/phase4_rearrangements/PHASE_3.4_branch_stats/

---

### 3.5 Compare to Literature 🟡
```
3.5 Literature Validation           [Student+HB]
├─ Published karyotype data
├─ Compare to inferred events
├─ Agreement rate
└─ Script: compare_literature.R
```
**Time:** ~3 hrs | **Depends:** 3.3
**Folder:** phases/phase4_rearrangements/PHASE_3.5_literature_comparison/

---

### 3.6 Ancestral Karyotypes 🟡
```
3.6 Reconstruct Ancestral 2n       [CL+HB]
├─ Key nodes: MRCA, Adephaga, Polyphaga
├─ Linkage group counts
├─ Chromosome structure
└─ Script: reconstruct_karyotypes.R
```
**Time:** ~2 hrs | **Depends:** 3.3, 2.5
**Folder:** phases/phase4_rearrangements/PHASE_3.6_ancestral_karyotypes/

---

### 3.7 Phase 3 Integration 🟢
```
3.7 Integration Report              [CL+HB]
├─ Total rearrangements by type
├─ Clade rates + hotspots
├─ Script: phase3_report.R
└─ → PHASE_3_SIGN_OFF.txt
```
**Time:** ~1 hr | **Depends:** 3.6
**Folder:** phases/phase4_rearrangements/PHASE_3.7_integration_signoff/

---

## PHASE 5: Visualization & Manuscript (Week 7–10)

### 4.1 Phylogenetic Tree Figure 🟡
```
4.1 Publication Tree Figure         [CL]
├─ ggtree / ape
├─ Branches colored by rate
├─ Ancestral 2n at nodes
└─ Script: plot_tree.R
```
**Time:** ~4 hrs | **Depends:** 3.4, 3.6
**Folder:** phases/phase5_viz_manuscript/PHASE_4.1_interactive_tree/

---

### 4.2 Synteny Dotplots 🟡
```
4.2 Dotplot Gallery                 [CL+Student]
├─ 15–20 species pairs
├─ Color by orientation
├─ Multi-page PDF
└─ Script: make_dotplots.R
```
**Time:** ~3 hrs | **Depends:** 2.6
**Folder:** phases/phase5_viz_manuscript/PHASE_4.2_synteny_dotplots/

---

### 4.3 Hotspot Visualizations 🟡
```
4.3 Hotspot Figures                 [CL]
├─ Circular tree + heatmap
├─ Species × type heatmap
├─ Genome-wide density
└─ Script: hotspot_figures.R
```
**Time:** ~2 hrs | **Depends:** 3.4
**Folder:** phases/phase5_viz_manuscript/PHASE_4.3_hotspot_viz/

---

### 4.4 Ancestral Karyotype Figures 🟡
```
4.4 Karyotype Diagrams             [CL+HB]
├─ Schematic chromosomes
├─ Synteny block colors
├─ Node-to-node overlays
└─ Script: ancestral_karyotype_figures.R
```
**Time:** ~3 hrs | **Depends:** 3.6
**Folder:** phases/phase5_viz_manuscript/PHASE_4.4_ancestral_figures/

---

### 4.5 Data Release Package 🟢
```
4.5 Package Data Release            [CL]
├─ Organize directories
├─ manifest.csv + README
├─ Create tarball
└─ Script: package_release.sh
```
**Time:** ~1 hr | **Depends:** All Phase 3–4 outputs
**Folder:** phases/phase5_viz_manuscript/PHASE_4.5_data_release/

---

### 4.6 Manuscript Figures & Results 🔴
```
4.6 MANUSCRIPT ASSEMBLY             [HB+CL]
├─ Fig 1: Tree + rearrangements
├─ Fig 2: Synteny dotplots
├─ Fig 3: Ancestral karyotypes
├─ Fig 4: Rates by clade
├─ Results section draft
└─ Script: compile_figures.R
```
**Time:** ~3–5 days | **Depends:** 4.1–4.5
**Folder:** phases/phase5_viz_manuscript/PHASE_4.6_manuscript_figures/

---

### 4.7 Completion & Sign-Off 🟢
```
4.7 Final Checklist                 [HB]
├─ All figures 300 dpi
├─ Data files validated
├─ References formatted
├─ Script: final_checklist.R
└─ → SUBMIT PREPRINT
```
**Time:** ~1 hr | **Depends:** 4.6
**Folder:** phases/phase5_viz_manuscript/PHASE_4.7_completion_signoff/

---

## Summary by Color

| Color | Count | Total Time | Tasks |
|-------|-------|------------|-------|
| 🟢 GREEN (< 2 hrs) | 7 | ~8 hrs | 1.3, 1.7, 2.4, 2.7, 3.7, 4.5, 4.7 |
| 🟡 YELLOW (2–6 hrs) | 17 | ~55 hrs | LR.1, LR.2, 1.1, 1.2, 1.4, 1.5, 1.6, 2.3, 2.6, 3.1–3.6, 4.1–4.4 |
| 🟠 ORANGE (1–3 days) | 2 | ~3 days | 2.1, 2.5 |
| 🔴 RED (>3 days / HPC) | 2 | ~10 days | 2.2, 4.6 |

**Critical path:** 1.1 → 1.4 → 1.6 → 2.1 → **2.2 (7 days HPC)** → 2.3 → 2.5 → 2.6 → 3.1 → 3.3 → 3.6 → 4.1 → **4.6 (manuscript)** → 4.7

**Bottleneck:** Task 2.2 (full alignment) dominates the timeline. Everything downstream is blocked until this completes.
