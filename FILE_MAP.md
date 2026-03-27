# SCARAB File Map

**Last updated**: 2026-03-25
**Project**: Synteny, Chromosomes, And Rearrangements Across Beetles
**Status**: Phase 3 in progress (whole-genome alignment)

---

## Quick Reference

| What you need | Where to find it |
|---------------|-----------------|
| Current project status | `context.md` |
| Grace HPC paths & constraints | `CLAUDE.md` |
| Active HPC scripts | `grace_upload_phase3/` |
| Genome catalog (all 1,121 assemblies) | `data/genomes/genome_catalog.csv` |
| 478-taxon rooted tree | `scarab_478_rooted.nwk` |
| Karyotype database | `data/karyotypes/literature_karyotypes.csv` |
| Manuscript drafts | `manuscript/drafts/` |
| Progress tracking | `project_management/progress_tracking.md` |
| AI use log | `project_management/ai_use_log.md` |

---

## Local Repository

### Root Files

| File | Purpose |
|------|---------|
| `README.md` | Project overview and quick-start |
| `ANALYSIS_PLAN.md` | Full scientific plan for all 5 phases |
| `CLAUDE.md` | Claude Code context: Grace paths, Python constraints, quality gates |
| `FILE_MAP.md` | This file |
| `context.md` | Current project status (update whenever phase milestones complete) |
| `grace_filesystem_map.md` | Grace $SCRATCH directory tree with file descriptions |
| `nuclear_guide_tree_439.nwk` | 439-taxon FastTree guide tree (15 BUSCO proteins, unrooted) |
| `scarab_478.treefile` | 478-taxon IQ-TREE output (raw) |
| `scarab_478_rooted.nwk` | 478-taxon rooted guide tree (used as Cactus input) |

---

### `grace_upload_phase3/` — CANONICAL HPC SCRIPTS

**This is the only directory to edit for active HPC work.**
Workflow: edit here → `git push` → `git pull` on Grace → run from `$SCRATCH/scarab/`

#### Genome Download (Phase 2 supplement — complete)
| Script | Purpose | Status |
|--------|---------|--------|
| `download_recovery_genomes.py` | Download 39 recovery genomes from NCBI FTP (Python 3.6) | DONE |
| `download_recovery_genomes.sh` | Login-node wrapper for above | DONE |
| `download_recovery_genomes.slurm` | SLURM wrapper (transfer partition) | DONE |
| `recovery_accessions.txt` | List of 39 recovery taxon accessions | Data |

#### Nuclear Guide Tree — 15-gene (complete)
| Script | Purpose | Status |
|--------|---------|--------|
| `prepare_nuclear_markers.sh` | Download BUSCO insecta_odb10, select 15 marker proteins | DONE |
| `extract_nuclear_markers_and_build_tree.slurm` | tBLASTn → MAFFT → FastTree → 439-taxon tree | DONE (job 18109716) |
| `build_478_starting_tree.slurm` | Graft 39 recovery genomes → starting topology for IQ-TREE | READY |
| `iqtree_478.slurm` | IQ-TREE (LG+G4) 478-taxon tree — **reported in methods** | PENDING |

#### Phylogenomics — 1,286 BUSCO genes
| Script | Purpose | Status |
|--------|---------|--------|
| `P1_map_busco_to_tribolium.sh` | Map 1,367 BUSCO proteins → Tribolium chromosomes (Stevens elements) | DONE (job 18112279) |
| `P3_blast_selected_loci.slurm` | tBLASTn 1,286 × 478 genomes → per-gene FASTAs | RUNNING (job 18152861) |
| `P4_P5_align_and_gene_trees.slurm` | MAFFT per-gene alignment + IQ-TREE per-gene trees | PENDING |
| `P6_astral_species_tree.slurm` | ASTRAL-III species tree + gCF/sCF concordance | PENDING |
| `P7_concat_iqtree.slurm` | Partitioned IQ-TREE concatenation (concordance check) | PENDING |

#### Cactus Whole-Genome Alignment
| Script | Purpose | Status |
|--------|---------|--------|
| `setup_phase3.sh` | One-time: pull Cactus v2.9.3 Singularity container, build seqfile | DONE |
| `build_seqfile.sh` | Map tree tips → genome FASTA paths → Cactus seqfile | DONE |
| `filter_genomes_for_alignment.R` | QC filter: N50 ≥100 kb, ≤10k scaffolds | DONE |
| `test_alignment.slurm` | 5-genome Cactus test (quality gate) | DONE, PASSED (job 18117479) |
| `run_full_alignment.slurm` | Full 478-genome Cactus alignment (bigmem, 18-day wall, restart-safe) | BLOCKED (quota + guide tree) |
| `cactus_watchdog.sh` | Auto-resubmit on wall-time kill (run in tmux on login node) | READY |

#### `grace_upload_phase3/deprecated/`
| Script | Why deprecated |
|--------|---------------|
| `extract_coi_and_build_tree.slurm` | COI only 41% hit rate; replaced by nuclear BUSCO approach |
| `integrate_recovery_genomes.R` | Hardcoded taxonomy grafting; replaced by data-driven BLAST approach |
| `fix_38_reblast_and_rebuild.slurm` | One-time repair; complete |
| `P2_select_loci.sh` | Locus-selection step skipped; using all 1,286 BUSCO genes |
| `P3_blast_recovery_taxa.slurm` | Redundant; main P3 job already handles recovery genomes |

---

### `grace_upload/` — DEPRECATED (Phase 2 download scripts)

Old genome download scripts for Grace, kept for reference. Do not edit or run.

| Script | Notes |
|--------|-------|
| `download_login.sh` | Working — login-node parallel curl; how 439 genomes were downloaded |
| `validate_downloads.sh` | Working — post-download integrity checks |
| `download_genomes.slurm` | BROKEN — compute nodes have no internet |
| `setup_and_submit.sh` | BROKEN — depended on broken SLURM downloader |
| `accessions_to_download.txt` | Original 439 accessions |

---

### `scripts/`

Local analysis and reference scripts. Not run on Grace.

| Directory | Contents | Status |
|-----------|---------|--------|
| `scripts/phase2/` | Genome download, validation, tree calibration (Python + R) | Active reference |
| `scripts/phase3/deprecated/` | Old setup_phase3.sh and build_seqfile.sh (superseded by grace_upload_phase3/) | Deprecated |
| `scripts/phase4/` | Placeholder for rearrangement calling scripts | Future |
| `scripts/phase5/` | Placeholder for visualization scripts | Future |

---

### `data/`

| Path | Contents |
|------|---------|
| `data/genomes/genome_catalog.csv` | 1,121 NCBI assemblies, 43 metadata columns |
| `data/genomes/genome_catalog_primary.csv` | 687 best-per-species selections |
| `data/genomes/tree_tip_mapping.csv` | 439 tip labels → genome accessions → metadata |
| `data/genomes/constraint_tree.nwk` | 439-tip unrooted constraint tree |
| `data/genomes/constraint_tree_calibrated.nwk` | 439-tip tree with divergence times (Ma, 29 fossil calibrations) |
| `data/genomes/stevens_elements.csv` | Tribolium chromosome → Stevens element mapping |
| `data/karyotypes/literature_karyotypes.csv` | Empirical karyotypes for 439 species (60.4% coverage) |
| `data/alignments/` | Future: Cactus HAL files |
| `data/synteny/` | Future: synteny blocks |
| `data/ancestral/` | Future: ancestral karyotype reconstructions |

---

### `phases/` — Phase Documentation

HOWTOs, overviews, and task guides for each phase. Read these before starting a new phase step.

| Directory | Phase | Status |
|-----------|-------|--------|
| `phases/phase1_literature_review/` | Literature review | COMPLETE |
| `phases/phase2_genome_inventory/` | Genome curation & download | COMPLETE |
| `phases/phase3_alignment_synteny/` | Whole-genome alignment | IN PROGRESS |
| `phases/phase4_rearrangements/` | Rearrangement calling | NOT STARTED |
| `phases/phase5_viz_manuscript/` | Visualization & manuscript | NOT STARTED |

---

### `results/`

Analysis outputs organized by phase. Currently populated through Phase 3 (growing).

---

### `manuscript/`

| Path | Contents |
|------|---------|
| `manuscript/drafts/introduction_draft.docx` | Complete introduction (5 paragraphs) |
| `manuscript/drafts/methods_draft.docx` | Complete methods (~3k words, through Phase 3 setup) |
| `manuscript/drafts/results_genome_dataset.docx` | Phase 2 results + karyotype validation |
| `manuscript/supplementary/Table_S1_genome_dataset.xlsx` | 439 species × 15 metadata columns |
| `manuscript/supplementary/software_and_tools.docx` | Software versions and citations |
| `manuscript/figures/` | Future: Phase 5 figures |

---

## Grace HPC (`$SCRATCH/scarab/`)

`$SCRATCH` = `/scratch/user/blackmon/scarab`

### Active Scripts (root level)

| Script | Purpose | Status |
|--------|---------|--------|
| `build_478_starting_tree.slurm` | 478-taxon starting tree for IQ-TREE | READY TO SUBMIT |
| `iqtree_478.slurm` | 478-taxon IQ-TREE guide tree | PENDING |
| `extract_nuclear_markers_and_build_tree.slurm` | 15-gene guide tree builder | DONE |
| `P3_blast_selected_loci.slurm` | tBLASTn 1,286 × 478 | RUNNING (job 18152861) |
| `P4_P5_align_and_gene_trees.slurm` | MAFFT + IQ-TREE per gene | PENDING |
| `P6_astral_species_tree.slurm` | ASTRAL-III | PENDING |
| `P7_concat_iqtree.slurm` | Concatenation IQ-TREE | PENDING |
| `run_full_alignment.slurm` | Full Cactus alignment | BLOCKED |
| `cactus_watchdog.sh` | Cactus auto-resubmit | READY |
| `filter_genomes_for_alignment.R` | Genome QC filter | DONE |
| `download_recovery_genomes.*` | Recovery genome download | DONE |

### Key Data Directories

| Path | Contents | Size |
|------|---------|------|
| `genomes/` | 478 genome FASTAs (`{ACC}/ncbi_dataset/data/{ACC}/*.fna`) | ~296 GB |
| `nuclear_markers/insecta_odb10/` | BUSCO insecta database (1,367 genes) | ~2 GB |
| `nuclear_markers/iqtree_478/` | IQ-TREE 478-taxon output | small |
| `nuclear_markers/nuclear_guide_tree_439_rooted.nwk` | 439-taxon rooted guide tree | tiny |
| `nuclear_markers/nuclear_guide_tree_478_rooted.nwk` | 478-taxon grafted starting tree | tiny |
| `phylogenomics/per_gene_seqs/` | Per-gene FASTAs from P3 BLAST (~2,571 files, growing) | medium |
| `phylogenomics/blast_dbs/` | Per-genome BLAST databases (478 genomes) | ~20 GB |
| `cactus_seqfile.txt` | Cactus input: tree + 439 genome paths | tiny |
| `cactus_seqfile_478.txt` | Cactus input: tree + 478 genome paths | tiny |
| `cactus_v2.9.3.sif` | Cactus Singularity container | ~12 GB |
| `work/test_alignment/test_alignment.hal` | 5-genome test HAL (PASSED) | small |
| `hal_files/` | Future: full 478-genome alignment HAL | ~500 GB est. |

### Deprecated on Grace

| Path | Why |
|------|-----|
| `deprecated/integrate_recovery_genomes.R` | Hardcoded taxonomy grafting — replaced |
| `deprecated/fix_38_reblast_and_rebuild.slurm` | One-time repair — complete |
| `scripts/phase3/` | Old working directory; superseded by root-level scripts |
| `coi_tree/` | COI approach abandoned (41% hit rate) |

### Logs

Active job logs: `phylogenomics/scarab_P3_18152861.log`
Archived logs: `logs/archived/` and `logs/archived/phylogenomics/`

---

## Phase Status Summary

| Phase | Name | Status | Key Output |
|-------|------|--------|-----------|
| 1 | Literature review | COMPLETE | `results/phase1_literature/` |
| 2 | Genome inventory | COMPLETE | 478 genomes downloaded, calibrated tree |
| 3a | Nuclear guide tree (439) | COMPLETE | `nuclear_guide_tree_439_rooted.nwk` |
| 3b | Guide tree (478, IQ-TREE) | IN PROGRESS | `scarab_478_rooted.nwk` (interim) |
| 3c | Phylogenomics (1,286 genes) | RUNNING | Job 18152861, ~22h remaining |
| 3d | Cactus alignment | BLOCKED | Waiting: quota approval + IQ-TREE tree |
| 4 | Rearrangement calling | NOT STARTED | Blocked on Phase 3d |
| 5 | Visualization & manuscript | PARTIAL | Intro/methods/results drafted; figures pending |
