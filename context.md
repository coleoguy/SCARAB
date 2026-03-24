# SCARAB Project: Context & Overview

## Project Title
**SCARAB: Synteny, Chromosomes, And Rearrangements Across Beetles**

## Principal Investigator
Heath Blackmon

## Project Goal
Construct a systematic, genome-scale atlas of chromosomal rearrangements (fusions, fissions, inversions) across 439 beetle and outgroup genomes spanning the major clades of Coleoptera. This project aims to:
- Document the rate, frequency, and distribution of rearrangement hotspots across beetle lineages
- Reconstruct ancestral karyotypes at key nodes of the beetle phylogeny
- Identify associations between chromosomal changes and speciation events
- Establish baseline metrics for chromosomal evolution in the most species-rich eukaryotic order

## Current Status
**Phase 3: Whole-Genome Alignment — IN PROGRESS** (2026-03-22). Phases 1–2 COMPLETE. 439 genomes on Grace. Nuclear BUSCO marker guide tree: **COMPLETE** (439/439 molecular data, 0 grafted taxa).

**Bug diagnosed and fixed (2026-03-22):** Initial tBLASTn job (48 parallel jobs on 64GB) caused silent OOM kills for 38 genomes — `2>/dev/null || true` swallowed errors, creating 0-byte .blast files marked "OK hits=0." Fix job (18110451) re-BLASTed 38 genomes with 12 parallel jobs on 128GB, then rebuilt the full downstream pipeline. All 439 taxa now have molecular data.

**Phylogenomics strategy (decided 2026-03-23, updated 2026-03-23):**
- **Cactus guide tree** = FastTree from 15 BUSCO genes, re-rooted on Neuropterida. **DONE** — `nuclear_guide_tree_439_rooted.nwk` created, Cactus seqfile updated (440 lines verified).
- **Cactus test alignment** = **IN PROGRESS** — job 18117479 running on Grace (5 smallest genomes, medium partition). First attempt (18114304) failed due to Toil jobstore corruption; fixed by nuking work directory and resubmitting.
- **Rearrangement mapping tree** = Full phylogenomics pipeline with **1,286 BUSCO loci** (runs in parallel with Cactus):
  1. ~~Map all 1,367 BUSCO insecta_odb10 proteins to *Tribolium* chromosomes~~ **DONE** — 1,286 genes mapped to 10 Tcas chromosomes (job 18112279)
  2. ~~Select loci~~ **SKIPPED** — using ALL 1,286 mapped genes for maximum phylogenetic power
  3. tBLASTn 1,286 genes × 439 genomes — **IN PROGRESS** (job 18114486, ~1.5 days remaining)
  4. Per-gene MAFFT → per-gene IQ-TREE trees (1,286 independent jobs)
  5. ASTRAL-III species tree + gene/site concordance factors (gCF/sCF)
  6. Partitioned IQ-TREE on concatenation as concordance check
  7. Compare ASTRAL vs concatenation; McKenna backbone for unresolved deep nodes
- Rationale: 15 genes insufficient for coalescent methods or meaningful concordance analysis. 1,286 loci give ASTRAL maximum statistical power, enable per-node gCF/sCF, and critically enable the discordance × breakpoint analysis (see below). Cactus insensitive to moderate topology errors; rearrangement mapping is not.

**Novel analysis: Gene tree discordance × chromosomal breakpoints**
- With 1,286 gene trees mapped to chromosomal positions AND Cactus-inferred breakpoints, test whether discordant genes cluster near rearrangement breakpoints
- Temporal dimension: at nodes with high rearrangement rates, does discordance increase among breakpoint-proximal genes?
- Per-Stevens-element concordance factors: do rearranged elements show more discordance than conserved ones?
- Direct test of chromosomal speciation model (Rieseberg/Noor/Navarro-Barton) at unprecedented 439-genome scale
- Potential standalone result; at least 2 manuscript figures

**Tree quality assessment (15-gene FastTree, 2026-03-22):**
- Neuropterida: monophyletic (17 taxa) ✓
- Adephaga: monophyletic (45 taxa) ✓
- Monophyletic families: Carabidae (44), Scarabaeidae s.l. (37), Cerambycidae (28), Coccinellidae (23), Cantharidae (17), Lucanidae (6), Lampyridae (5), Leiodidae (8), Buprestidae (5), Meloidae (3), Geotrupidae (2), Hydrophilidae (3), Dermestidae (2)
- Non-monophyletic: Tenebrionidae (root artifact), Staphylinidae (expected — Staphylinoidea), Chrysomelidae (Bruchinae placement), Elateridae (Lampyridae nested — defensible)
- Problematic: *Otiorhynchus rugosostriatus* on 1.33 subs/site branch (possible bad sequence data)
- 1 polytomy (3 children at Tenebrionidae root — will resolve with re-rooting)

**Guide tree outputs:**
- FastTree (15 genes): `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk` (DONE)
- Re-rooted (for Cactus): `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439_rooted.nwk` (DONE — 17/17 Neuropterida outgroup, monophyletic)
- Phylogenomics pipeline (1,286 genes): `$SCRATCH/scarab/phylogenomics/` (IN PROGRESS — P3 BLAST running)

**Phylogenomics SLURM scripts (on Grace at `$SCRATCH/scarab/phylogenomics/`):**
- `P1_map_busco_to_tribolium.slurm` — **DONE** (job 18112279). Mapped 1,286 BUSCO genes to 10 Tribolium chromosomes
- `P2_select_loci.sh` — **SKIPPED** (using all 1,286 genes)
- `P3_blast_1286_loci.slurm` + `blast_one.sh` — **RUNNING** (job 18114486). tBLASTn 1,286 proteins × 439 genomes
- `P4_P5_align_and_gene_trees.slurm` — PENDING, MAFFT + IQ-TREE gene trees
- `P6_astral_species_tree.slurm` — PENDING, ASTRAL-III + gCF/sCF
- `P7_concat_iqtree.slurm` — PENDING, partitioned concatenation ML tree

**Local copies in grace_upload_phase3/:** P1–P7 template scripts (may differ from final versions on Grace)

**Methods draft updated (2026-03-23):** Full Species Tree Inference section + discordance × breakpoints analysis added to methods_draft.docx. Three missing references added as tracked changes (2026-03-23): Rieseberg 2001, Noor et al. 2001, Navarro & Barton 2003.

**Computational estimates from test run (2026-03-23):**
- Test: 5 smallest genomes (550 Mb total), 84 min wall, 48 cores = 67 core-hours (SUs)
- Full Cactus alignment estimate: ~144,000 SUs (scaling by n × genome_size × log2(n))
- Wall-clock: requires subtree decomposition across multiple nodes (single-node would be ~125 days)
- Scratch space peak: ~660-1,160 Gb total (genomes already on scratch: ~311 Gb; new: HAL ~62-124 Gb, jobstore peak ~187-622 Gb temporary, phylogenomics intermediates ~100 Gb)
- 5 TB quota request is well-justified; 2-3 TB is likely sufficient but 5 TB gives safe headroom

**Next actions on Grace (each step requires Heath's review before proceeding):**
1. ~~Re-root FastTree on Neuropterida~~ — **DONE** (17/17 outgroup taxa found, monophyletic)
2. ~~Request $SCRATCH quota increase to 5TB~~ — Gmail draft created (draft ID: r1569898534488795924). **Needs sending.**
3. ~~Start phylogenomics pipeline~~ — P1 DONE, P2 SKIPPED, **P3 RUNNING** (job 18114486)
4. ~~Submit test alignment~~ — **COMPLETE** (job 18117479). Quality gate PENDING Heath approval (halStats shows 5 genomes, all present, ancestral recovery 15-20%).
5. **NEXT (Cactus track)**: Download 39 recovery genomes → `integrate_recovery_genomes.R` → `filter_genomes_for_alignment.R` → review exclusion list → `sbatch run_full_alignment.slurm`
6. **NEXT (phylogenomics track)**: When P3 completes → check results → submit P4/P5 (MAFFT + IQ-TREE gene trees)
7. ~~Stevens element assignment~~ — **DONE** (2026-03-23). `data/genomes/stevens_elements.csv` created. Mapping: LG2=E, LG3=A, LG4=G, LG5=D, LG6=H, LG7=B, LG8=F, LG9=C, LGX=X. LG10 is NOT a Stevens element (genes map to multiple chromosomes in other beetles).

**Genome recovery (2026-03-23):**
- 39 additional species identified in "conditional" category that pass Cactus quality thresholds (contig N50 >= 100 kb, scaffolds <= 10,000)
- All published_open except Lamprigera yunnana (to_verify)
- Adds 2 new families: Lycidae, Rhagophthalmidae; 27 Gb additional download
- Many are excellent HiFi assemblies misclassified as "Contig" level by NCBI (e.g., Neoclytus acuminatus: 52.6 Mb N50, 19 scaffolds)
- Scripts: `download_recovery_genomes.sh` (login node), `integrate_recovery_genomes.R` (tree grafting + seqfile), `P3_blast_recovery_taxa.slurm` (supplemental phylogenomics BLAST)
- Target: 478 genomes pre-filter, ~453 post-filter (largest single-clade Progressive Cactus alignment ever)

**Genome quality filter (2026-03-23):**
- Script: `grace_upload_phase3/filter_genomes_for_alignment.R` — run on Grace against actual seqfile (478-taxon version)
- Thresholds (established pre-alignment): contig N50 >= 100 kb AND scaffold count <= 10,000
- T. castaneum is mandatory keep (Stevens element reference)
- From catalog analysis, ~25 genomes from the 478-taxon set will fail; final count determined by running the script on Grace
- Important duplicates to check on Grace: Agrilus planipennis (x2), Dendroctonus ponderosae (x3), T. castaneum (x3 in catalog, only best should be on Grace)
- Methods paragraph added to methods_draft.docx (tracked change, 2026-03-23)

**Full alignment strategy (2026-03-23):**
- Script: `grace_upload_phase3/run_full_alignment.slurm` (updated)
- Approach: bigmem node (80 cores, 2.9 TB RAM), xlong queue, 18-day wall time with `--restart` resume
- SIGTERM received 1 hour before wall time; Toil checkpoints and exits cleanly
- Watchdog: `grace_upload_phase3/cactus_watchdog.sh` (run in tmux on login node — auto-resubmits)
- Expected cycles: 4-5 (18 days each, ~75 days total)
- Uses filtered seqfile: `$SCRATCH/scarab/cactus_seqfile_filtered.txt`
- HAL written incrementally; each cycle resumes from jobstore

---

## QUALITY GATE POLICY — MANDATORY

**This policy is non-negotiable. It exists because the assistant has twice attempted to advance the pipeline with garbage input (COI tree with 41% hit rate, calibrated tree with unrealistic branch lengths). Heath has explicitly required a higher standard.**

### Rule 1: Every output must be examined before it becomes input
Before ANY pipeline output is used as input to the next step, it MUST be:
1. Downloaded/transferred so Heath can see it
2. Quantitatively evaluated against acceptance criteria listed below
3. Visually inspected where applicable (e.g., tree topology, alignment stats)
4. Explicitly approved by Heath

**The assistant must NEVER suggest submitting the next job in the same breath as checking the current one. Present results first. Wait for Heath's approval. Only then discuss next steps.**

### Rule 2: If acceptance criteria fail, STOP
Do not rationalize. Do not suggest "it's probably fine." Flag the problem, quantify it, and propose alternatives.

### Rule 3: Never assume success
Even if a SLURM job exits 0 and a quality gate script says "PASSED," the assistant must still walk through the output with Heath. Automated checks catch known failure modes; human review catches unknown ones.

### Acceptance Criteria by Stage

**Guide tree:**
- ≥90% of taxa (≥395/439) must have molecular data (not taxonomy-grafted)
- Tree must be binary with branch lengths in substitutions/site
- No branch length >25.0 (Cactus hard limit)
- Branch lengths must be empirically estimated, not arbitrary constants
- Topology must be biologically plausible (Neuropterida outgroup monophyletic, major beetle suborders recovered)
- Heath must visually inspect the tree before test alignment is submitted

**Test alignment:**
- Job completes without error
- HAL file is produced and non-empty
- halStats summary reviewed (number of genomes, total aligned bases)
- Heath approves before full alignment is submitted

**Full alignment:**
- Review halStats, alignment coverage, per-genome stats before downstream analysis

---

## Timeline
- **Total Duration**: 5 weeks (compressed schedule)
- **Target**: Preprint submission by end of week 5
- **Full manuscript**: Submission to high-impact journal (e.g., *Nature Ecology & Evolution*, *Molecular Biology and Evolution*) within 2 months post-preprint
- **Phase Schedule**:
  - **Phase 1** (Days 1–3): Literature review & competitive landscape analysis — COMPLETE
  - **Phase 2** (Days 3–7): Genome inventory & quality control — COMPLETE
  - **Phase 3** (Days 7–24): Whole-genome alignment & synteny inference — IN PROGRESS
  - **Phase 4** (Days 24–30): Rearrangement annotation & ancestral reconstruction
  - **Phase 5** (Days 30–35): Visualization, data release, manuscript figures & results

## Key Project Decisions

### Preprint-First Strategy
Submit to bioRxiv as soon as Phase 5 is complete (day 35) to establish priority. Simultaneously prepare full manuscript for peer-reviewed submission.

### AI-Assisted Development
- Claude generates code; all code reviewed by Heath and team before execution
- All AI contributions logged in `project_management/ai_use_log.csv` (canonical) and `ai_use_log.md` (narrative)

### Compressed Timeline & Risk Mitigation
- Use established tools (ProgressiveCactus, halTools, RACA) rather than developing novel methods
- Focus on clear, defensible analyses over exploratory refinement

---

## Folder Structure

```
SCARAB/
├── README.md                # Project overview and quick start
├── context.md               # This file — full project context
├── ANALYSIS_PLAN.md         # Detailed methodology
├── data/                    # Raw and processed datasets
│   ├── DATA_DICTIONARY.md   # Column definitions for all CSV files
│   ├── genomes/             # Genome catalog, trees, tip mapping
│   ├── alignments/          # (placeholder) HAL alignment outputs from Grace
│   ├── synteny/             # (placeholder) Synteny blocks from Phase 3
│   ├── ancestral/           # (placeholder) Reconstructed ancestral genomes
│   └── karyotypes/          # Karyotype DB for cross-validation (Task 3.5)
├── grace_upload/            # Phase 2 download scripts for Grace
├── grace_upload_phase3/     # ★ CANONICAL Phase 3 alignment scripts
│   └── deprecated/          # Superseded scripts (COI approach)
├── results/                 # Analysis outputs organized by phase
├── scripts/                 # Production scripts by phase
├── manuscript/              # Figures, tables, text drafts
├── phases/                  # Phase-specific HOWTOs (31 total) and template
├── project_management/      # Tracking, timelines, AI use logs
└── background/              # Literature and reference materials
```

---

## Phase Summary

### Phase 1: Literature Review — COMPLETE
- Annotated bibliography, competitive landscape, preprint strategy
- Location: `results/phase1_literature/`, `phases/phase1_literature_review/`

### Phase 2: Genome Inventory — COMPLETE
- 1,121 assemblies mined → 687 primary → 439 quality-filtered
- 439 genomes downloaded on Grace (100% validated)
- Calibrated constraint tree (29 calibration points, McKenna et al. 2019)
- Location: `data/genomes/`, `results/phase2_genome_inventory/`, `scripts/phase2/`

### Phase 3: Whole-Genome Alignment — IN PROGRESS (Guide Tree COMPLETE)
- **Guide tree**: COMPLETE — 15 conserved BUSCO insecta proteins via tBLASTn across 439 genomes
  - 439/439 taxa with molecular data (100%), 0 grafted
  - Genes per taxon: min=9, max=15, mean=13.5
  - Supermatrix: 43,060 aligned amino acid positions
  - FastTree WAG+CAT → 439-tip tree, branch lengths 1.06e-03 to 1.33 subs/site (mean 0.097)
  - Minor polytomies (max 3 children) — acceptable for Cactus
  - Output: `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk`
- **Pipeline**: tBLASTn → per-gene MAFFT → protein supermatrix → FastTree (WAG+CAT) → root → validate → seqFile
- **Quality gate**: ≥90% of taxa must have molecular data — PASSED (100%)
- **Scripts**: `grace_upload_phase3/` (8 scripts: prepare, tree builder, fix_38_reblast, build_seqfile, setup, test, full alignment, + 1 deprecated)
- **Computational resources**: ~160,000–430,000 core-hours on TAMU Grace; subtree decomposition reduces wall-clock
- Location: `data/alignments/`, `data/synteny/`, `phases/phase3_alignment_synteny/`

### Phase 4: Rearrangements — NOT STARTED (blocked on Phase 3)
- Call fusions/fissions/inversions, map to phylogeny, reconstruct ancestral karyotypes
- Location: `phases/phase4_rearrangements/`, `scripts/phase4/`

### Phase 5: Viz & Manuscript — PARTIAL (Intro + Results drafted)
- Introduction, Methods, Results drafts exist; figures pending Phase 4
- Location: `manuscript/`, `phases/phase5_viz_manuscript/`, `scripts/phase5/`

---

## Genome Inventory

**Catalog**: `data/genomes/genome_catalog.csv`

| Metric | Count |
|--------|-------|
| Total assemblies mined | 1,121 (971 Coleoptera + 150 Neuropterida) |
| Primary selections | 687 |
| Quality-filtered (original) | 439 |
| Recovery genomes (conditional, pass thresholds) | 39 |
| Pre-filter total | 478 |
| Estimated post-filter (for Cactus) | ~453 |
| Coleoptera families | 61 |
| Outgroup orders | Neuroptera (138), Megaloptera (8), Raphidioptera (4) |

**Downloads**: 439/439 on Grace at `/scratch/user/blackmon/scarab/genomes/` (validated 2026-03-21).

**Calibrated tree**: `data/genomes/constraint_tree_calibrated.nwk` — 439 tips, 29 calibration points, root 320 Ma.

**Student curation needed**: publication DOIs, EBP/DToL restriction status (284 flagged).

---

## Guide Tree (Nuclear BUSCO Markers)

**Approach**: 15 conserved BUSCO insecta_odb10 proteins (1,778–3,033 aa each) extracted via tBLASTn from all 439 genomes. Per-gene protein alignment (MAFFT), concatenated supermatrix, ML tree (FastTree WAG+CAT).

**Results**: 439/439 taxa with molecular data (100%). Supermatrix: 43,060 aa. FastTree: 439 tips, branch lengths 1.06e-03 to 1.33 subs/site. Quality gate PASSED.

**Bug & fix (2026-03-22)**: Initial job used 48 parallel tBLASTn on 64GB → silent OOM kills for 38 genomes (0-byte .blast files). Fix job 18110451 re-BLASTed 38 genomes with 12 parallel jobs on 128GB, rebuilt full downstream pipeline. Completed in 1h44m, 46GB peak RAM.

**Phylogenomics strategy**: FastTree from 15 genes (re-rooted) for Cactus guide tree. Expanded 1,286-locus pipeline (ASTRAL-III + partitioned IQ-TREE + gCF/sCF) for rearrangement mapping tree. 1,286 loci across 10 Tribolium chromosomes enable novel discordance × breakpoint analysis. See top-level status section for full pipeline and rationale.

**Scripts**:
- `grace_upload_phase3/prepare_nuclear_markers.sh` — login node: downloads BUSCO data, selects 15 markers (DONE)
- `grace_upload_phase3/extract_nuclear_markers_and_build_tree.slurm` — SLURM: tBLASTn + align + tree + seqFile (DONE — job 18110215)
- `grace_upload_phase3/fix_38_reblast_and_rebuild.slurm` — SLURM: re-BLAST 38 failed genomes + rebuild (DONE — job 18110451)

**Outputs (15-gene pipeline)**:
- FastTree: `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk` (DONE)
- Re-rooted: `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439_rooted.nwk` (PENDING)
- Supermatrix (15 genes): `$SCRATCH/scarab/nuclear_markers/supermatrix.fasta` (DONE)

**Outputs (1,286-gene phylogenomics pipeline — IN PROGRESS)**:
- BUSCO→Tribolium mapping: `$SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv` (DONE — 1,286 rows)
- Selected loci list: `$SCRATCH/scarab/phylogenomics/selected_loci.txt` (DONE — 1,286 variant IDs)
- Selected proteins: `$SCRATCH/scarab/phylogenomics/selected_proteins.fasta` (DONE — 1,286 seqs)
- Per-genome BLAST DBs: `$SCRATCH/scarab/phylogenomics/blast_dbs/` (IN PROGRESS via P3)
- Per-gene FASTA: `$SCRATCH/scarab/phylogenomics/per_gene_fasta/` (IN PROGRESS via P3)
- Gene alignments: `$SCRATCH/scarab/phylogenomics/alignments/` (PENDING — P4)
- Gene trees: `$SCRATCH/scarab/phylogenomics/gene_trees/` (PENDING — P5)
- ASTRAL tree + gCF: `$SCRATCH/scarab/phylogenomics/astral/` (PENDING — P6)
- Partitioned IQ-TREE: `$SCRATCH/scarab/phylogenomics/concat_iqtree/` (PENDING — P7)

**Execution order on Grace**:
1. `bash prepare_nuclear_markers.sh` (login node) — DONE
2. `sbatch extract_nuclear_markers_and_build_tree.slurm` — DONE (38 genomes had silent OOM kills)
3. `sbatch fix_38_reblast_and_rebuild.slurm` — DONE (all 439 taxa now have data)
4. **Re-root FastTree on Neuropterida** (R on login node) — NEXT
5. `sbatch test_alignment.slurm` → `sbatch run_full_alignment.slurm` — Cactus track
6. **In parallel**: P.1→P.8 phylogenomics pipeline (map BUSCOs → select loci → BLAST → align → gene trees → ASTRAL + concat → compare)

---

## Karyotype Cross-Validation Data

**File**: `data/karyotypes/literature_karyotypes.csv` (439 rows, 14 columns)
**Source**: Blackmon & Demuth Coleoptera Karyotype Database (4,958 records) + manual literature for Neuropterida
**Coverage**: 265/439 species (60.4%) — 121 species-level, 144 genus-level, 174 no data
**Purpose**: Cross-validation of genome-inferred chromosome counts against empirical cytogenetics (Task 3.5)

---

## Manuscript Status

| Document | Status |
|----------|--------|
| Introduction | Draft complete (`manuscript/drafts/introduction_draft.docx`) |
| Methods | Draft complete (`manuscript/drafts/methods_draft.docx`) |
| Results | Phase 2 results drafted (`manuscript/drafts/results_genome_dataset.docx`) |
| Table S1 | Complete (`manuscript/supplementary/Table_S1_genome_dataset.xlsx`) |
| Figures S1–S5 | Complete (`manuscript/figures/`) |

**Target journals**: Nature Ecology & Evolution (primary), MBE, Current Biology, Genome Research

---

## Novel Downstream Analyses

### Tier 0 — Enabled by phylogenomics pipeline (NEW)
- **A.0 Gene tree discordance × chromosomal breakpoints**: 500 BUSCO gene trees mapped to chromosomal positions (Stevens elements) via Tribolium reference. Test whether discordant genes (low gCF) cluster near Cactus-inferred rearrangement breakpoints. Temporal dimension: at nodes with high rearrangement rates, does discordance increase among breakpoint-proximal genes? Per-element concordance factors: do rearranged Stevens elements show more gene tree discordance than conserved ones? **Direct test of chromosomal speciation model (Rieseberg/Noor/Navarro-Barton) at 439-genome scale. Nobody has done this in any clade.** At least 2 manuscript figures. Depends on: P.6 (ASTRAL+gCF), 3.1 (breakpoints), 2.3 (synteny blocks).

### Tier 1 — Only possible in beetles
- **A.1 Karyotype rate vs. genomic rearrangement rate**: Correlate cytogenetic fusion/fission rates (Ruckman et al. 2020, ~4,400 spp) with Cactus-inferred rates. **CENTERPIECE ANALYSIS.**
- **A.2 Fragile-Y hypothesis tested genomically**: Trace X and neo-sex chromosome origins across 400+ species. Test whether Y-bearing Stevens elements show elevated breakpoint density.
- **A.3 Rearrangement rate shifts × diversification**: Correlate branch-specific rearrangement rates with speciation rates (BAMM/ClaDS).

### Tier 2 — High-impact
- **A.4 Breakpoint hotspot characterization**: Recurrent breakpoint regions, TE enrichment
- **A.5 Stevens element conservation across 56 families**: Element stability across 320 My
- **A.6 Fusion partner asymmetry**: Does the Xyp show preferential fusion partners?

---

## Computational Infrastructure

### TAMU Grace Cluster
- 800 standard nodes: 48 cores, 384 GB RAM
- 8 bigmem nodes: 80 cores, 3 TB RAM
- Queues: short (2hr), medium (1d), long (7d), xlong (21d), bigmem (2d)
- **Compute nodes have NO internet**. Downloads and container pulls run on login node only.
- File transfer: sftp (not scp — Duo 2FA causes timeout)
- Container runtime: Singularity (not Docker)

### PROJECT_ROOT Convention
All scripts use portable paths:
- R: `PROJECT_ROOT <- Sys.getenv("SCARAB_ROOT", unset = normalizePath(file.path(dirname(sys.frame(1)$ofile), "..", "..", ".."), mustWork = FALSE))`
- Bash: `PROJECT_ROOT="${SCARAB_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"`

---

## Competitive Landscape

**Key competitor**: Bracewell et al. (2024) PLOS Genetics — 9 "Stevens elements" from 12 beetle genomes.
**Closest analog**: Wright et al. (2024) Nat Eco Evo — 210 Lepidoptera genomes, 32 Merian elements.
**Our unique contributions**: Scale (~453 genomes, largest single-clade Progressive Cactus alignment ever), ancestral karyotype reconstruction, rearrangement rate mapping, cross-validation with 4,700-species karyotype database, two-tier approach (Cactus WGA for shallow nodes + gene-order synteny for deep nodes).
**Scooping risk**: LOW-MEDIUM.

---

## Team

| Role | Name | Responsibility |
|------|------|-----------------|
| **PI** | Heath Blackmon | Project direction, biological interpretation, final decisions |
| **Students** | TBD | Genome QC, data curation, analysis support, code review |
| **AI Assistant** | Claude | Code generation, analysis scripting, documentation, data processing |

---

**Last Updated**: 2026-03-23 (Recovery genomes identified: 39 additional species, target 478 pre-filter ~453 post-filter. Download/integration/BLAST scripts created. Largest single-clade Cactus alignment claim established.)
**Project Start Date**: 2026-03-21
**Preprint Target**: ~2026-05-02
**Full Submission Target**: ~2026-07-02

## Writing Style Rule
When producing text for this project, never use emdashes unless they truly are the only option. Prefer commas, parentheses, colons, semicolons, or separate sentences instead.
