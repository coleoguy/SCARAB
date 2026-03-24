# AI Use Log — SCARAB Project

**Last updated:** 2026-03-23
**AI tool:** Claude (Anthropic) via Cowork mode

This log documents all AI-assisted tasks for transparency and reproducibility. Each entry records what Claude did, what it produced, and whether a human reviewed it.

---

## Phase 2: Genome Inventory

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 1 | 1.1 NCBI Genome Mining | Queried NCBI Datasets API v2 for Coleoptera + Neuropterida. 971 + 150 records. | `data/genomes/genome_catalog.csv` | ~200 (Python) | Heath approved |
| 2 | 1.2 Taxonomy Assignment | Batch NCBI Taxonomy efetch for 687 tax IDs. Extracted family/superfamily/order lineage. | `genome_catalog.csv` (taxonomy cols) | ~100 (Python) | Automated |
| 3 | 1.3 Catalog Cleanup & Dedup | Removed 22 GCA/GCF mirrors. Scored assemblies. Selected 687 primary from 1,121. | `genome_catalog_primary.csv`, `catalog_cleanup_report.txt` | ~150 (Python) | Pending |
| 4 | 1.5 Download Infrastructure | SLURM array job + standalone bash script. Accession list + manifest. | `download_genomes.slurm`, `download_manifest.csv` | ~120 (SLURM+bash) | Pending |
| 5 | 1.5 Restriction Audit | Audited 687 genomes for data use restrictions. All primary = LOW risk. | `restriction_audit.csv`, `restriction_audit_report.txt` | ~100 (Python) | Automated |
| 6 | 1.6 Constraint Tree | 439-tip Newick tree. McKenna et al. (2019) backbone. Validated with ete3. | `constraint_tree.nwk`, `tree_tip_mapping.csv` | ~250 (Python) | Pending |
| 7 | 1.7 QC Report & Figures | 5 supplementary figures (PDF, 300 dpi) + 2-page QC report. | `Fig_S1–S5`, `genome_inventory_qc_report.pdf` | ~300 (Python) | Pending |
| 8 | Download Script Fixes | Fixed scratch path, array range, added size validation. Wrote validate_downloads.sh. | `download_genomes.slurm` (fixed), `validate_downloads.sh` | ~200 (bash) | Heath executed |
| 9 | Grace Submission | Guided VPN/sftp/SLURM workflow. Fixed --ntasks=1 requirement. | None (interactive) | ~5 | Heath executed |
| 10 | Login-Node Downloads | Discovered compute nodes lack internet. Deployed login-node parallel curl script. | `download_login.sh` | ~80 (bash) | Heath deployed |
| 11 | Download Validation | 439/439 genomes confirmed present with valid FASTA files. | None | ~10 | Automated |

## Phase 2 Supporting Work

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 12 | R Script Templates | 6 production-ready base R scripts (clean, build tree, QC, figures, downloads, restrictions). | `phases/phase2_genome_inventory/` (6 scripts) | 3,050 (R) | Pending |
| 13 | Tree Calibration | Calibrated 439-tip tree with divergence times. 29 MRCA nodes from 4 published studies. | `constraint_tree_calibrated.nwk` | ~120 (Python) | Pending |

## Literature Review

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 14 | LR.1 Competitive Landscape | Identified Bracewell et al. (2024) — 9 Stevens elements from 12 genomes. Scooping risk LOW-MEDIUM. | `LR1_competitive_landscape.md` | 0 | Pending |
| 15 | LR.2 Zoonomia Landscape | Reviewed Zoonomia, Lepidoptera Merian elements, Damas et al. ancestral karyotypes. 16-paper bibliography. | `LR2_zoonomia_landscape.md` | 0 | Pending |
| 16 | LR.3 Preprint Strategy | Drafted preprint/publication plan: bioRxiv, journal ranking, data release, authorship. | `preprint_plan.md` | 0 | Pending |

## Manuscript

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 17 | Methods Draft | Complete Methods section (docx). 9 key references. Times New Roman, justified. | `methods_draft.docx` | ~250 (JS) | Pending |
| 18 | Methods Update | Tracked changes: calibrated tree, actual download method, Cactus v2.9.3. | `methods_draft.docx` (tracked changes) | ~50 (XML) | Pending |
| 19 | Results Draft | Results section 1 (genome dataset). Table S1 xlsx (439×15). Software tracking docx. | `results_genome_dataset.docx`, `Table_S1_genome_dataset.xlsx` | ~300 (JS/Python) | Pending |
| 20 | Introduction Draft | 5-paragraph intro. Updated Results with karyotype cross-validation subsection. | `introduction_draft.docx`, `results_genome_dataset.docx` (updated) | ~300 (JS/XML) | Pending |

## Phase 3: Alignment

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 21 | Pipeline Rewrite (2.1) | Rewrote scripts for Cactus v2.x API. Fixed CLI syntax, checkpoint flags, batch system. | `setup_grace.sh`, `test_alignment.slurm`, `submit_prepared.sh` | ~600 (bash) | Pending |
| 22 | Phase 3 Scripts | build_seqfile.sh, setup_phase3.sh, test_alignment.slurm, run_full_alignment.slurm. | `grace_upload_phase3/` (4 scripts) | ~400 (bash) | Pending |
| 23 | Script Bug Fixes | Fixed --mem limits, --maxMemory math, exit code capture, halStats syntax. | 4 scripts updated | ~30 (bash) | Local fixes applied |
| 24 | SU Budget Analysis | Estimated 160K–430K core-hours for 439-genome Cactus. Recommended pilot test. | None (advisory) | 0 | Heath reviewed |
| 25 | Grace Upload & Setup | Guided sftp upload + setup_phase3.sh execution (Cactus container pull). | Files on Grace | ~10 | Heath executed |
| 26 | Nuclear BUSCO Guide Tree | Multi-locus nuclear tree from 15 BUSCO insecta conserved proteins. tBLASTn × 439 genomes → per-gene MAFFT → protein supermatrix → FastTree (WAG+CAT). Quality gate ≥90% molecular data. Initial run: 38/439 genomes had silent OOM kills (48 parallel jobs on 64GB). | `prepare_nuclear_markers.sh`, `extract_nuclear_markers_and_build_tree.slurm` | ~750 (bash/Python) | Job completed (38 genomes failed — fixed in #30) |

| 30 | Fix 38-Genome OOM Bug | Diagnosed silent OOM kills in initial tBLASTn (48 parallel jobs on 64GB, errors swallowed by `2>/dev/null \|\| true`). Wrote fix script: re-BLAST 38 affected genomes with 12 parallel jobs on 128GB, then rebuild full downstream pipeline (parse ALL 439 → MAFFT → supermatrix → FastTree → validate → seqFile). Result: 439/439 molecular data (100%), 0 grafted, 43,060 aa supermatrix. | `fix_38_reblast_and_rebuild.slurm` | ~400 (bash) | Job 18110451 COMPLETED (1h44m, 46GB peak) |
| 31 | Methods & Project File Updates | Updated methods_draft.docx guide tree section with final stats. Updated context.md, progress_tracking.md, ai_use_log.md to reflect completed tree and bug fix. | `methods_draft.docx`, `context.md`, `progress_tracking.md`, `ai_use_log.md` | ~50 (XML) | Automated |
| 32 | Tree Quality Assessment & Two-Tree Strategy | Analyzed 439-tip FastTree topology: checked monophyly of Neuropterida, Adephaga, 17 families. Identified *Otiorhynchus* long branch (1.33 subs/site), 1 polytomy, Neuropterida sister to wrong taxon (unrooted). Adopted two-tree strategy: re-rooted FastTree for Cactus guide, IQ-TREE+ModelFinder on same supermatrix for rearrangement mapping. Updated all project files (context.md, progress_tracking.md, ai_use_log.md, task_board.html, methods_draft.docx). | Analysis output, updated project files | ~200 (Python/dendropy) | Heath decided strategy |
| 33 | Phylogenomics Pipeline Expansion (P.1–P.8 + A.0) | Expanded from IQ-TREE on 15-gene supermatrix to full multi-locus ASTRAL-III pipeline. Original plan: 300–500 loci; **actual execution: 1,286 loci** (Heath decided to use all mapped genes). 8 pipeline tasks: P.1 map BUSCO proteins to Tribolium chromosomes/Stevens elements; P.2 select loci (SKIPPED — using all 1,286); P.3 tBLASTn 1,286 genes × 439 genomes; P.4 per-gene MAFFT; P.5 per-gene IQ-TREE gene trees; P.6 ASTRAL-III species tree + gCF/sCF; P.7 partitioned IQ-TREE on concatenation; P.8 compare ASTRAL vs concat, constrain deep nodes with McKenna backbone. Novel analysis A.0: test gene tree discordance × chromosomal breakpoint proximity across Stevens elements (chromosomal speciation model test). Updated task_board.html (11 new tasks), context.md, progress_tracking.md. | Updated project files, SLURM scripts (pending) | ~100 (HTML/JS edits) | Heath designed strategy |

| 34 | Re-root Tree + Update Cactus Seqfile | Re-rooted 439-tip FastTree on 17 Neuropterida outgroup taxa using `ape::root()` on Grace login node. All 17 present and monophyletic. Updated Cactus seqfile line 1 with rooted tree (440 lines verified). | `nuclear_guide_tree_439_rooted.nwk`, `cactus_seqfile.txt` (updated) | ~20 (R) | Heath executed on Grace |
| 35 | P1: Map BUSCO→Tribolium Chromosomes | tBLASTn of 13,663 BUSCO insecta_odb10 proteins against Tribolium castaneum (icTriCast1.1, GCF_031307605.1). Job 18112279 hit 1hr time limit but captured 57,904 hits (98% of genes). Parsed to 1,286 unique genes on 10 Tcas chromosomes (chr11 had no hits). Extracted 1,286 protein sequences for downstream BLAST. | `busco_tribolium_map.tsv`, `selected_loci.txt`, `selected_proteins.fasta` | ~150 (bash/Python) | Job completed on Grace |
| 36 | P3: BLAST 1,286 Loci × 439 Genomes | Two-phase script: (1) build per-genome BLAST databases (sequential loop), (2) tBLASTn 1,286 proteins × 439 genomes via xargs + wrapper script (12 parallel). First version failed (`export -f` + xargs caused exit 255 on Grace compute nodes). Rewrote with separate `blast_one.sh` wrapper. Job 18114486 running on long partition. | `P3_blast_1286_loci.slurm`, `blast_one.sh` | ~200 (bash/Python) | Job running |
| 37 | Grace Filesystem Map | Created comprehensive directory tree of `$SCRATCH/scarab/` with file descriptions, key files reference table, genome path patterns, BUSCO database notes, module load commands, disk quota info. | `grace_filesystem_map.md` | 0 (markdown) | Created |
| 38 | Cactus Test Troubleshooting | Diagnosed Toil jobstore corruption (missing `config.pickle` + `stats` directory). Root cause: Lustre parallel filesystem latency after `rm -rf`. Fixed by manually nuking entire `work/test_alignment/` directory before resubmission. Job 18117479 submitted clean. | None | 0 | Heath resubmitted on Grace |
| 39 | $SCRATCH Quota Increase Email | Drafted Gmail email to help@hprc.tamu.edu requesting $SCRATCH quota increase from 1TB to 5TB for Cactus whole-genome alignment of 439 beetle genomes. | Gmail draft (r1569898534488795924) | 0 | Draft created, needs sending |

## Phase 3.5: Karyotype Compilation

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 27 | Karyotype Data | Cross-referenced 439 species against Blackmon & Demuth DB (4,958 records). 60.4% coverage. | `literature_karyotypes.csv` | ~150 (Python) | Heath reviewed |

## Project Management

| # | Task | Action Summary | Output Files | Code | Review |
|---|------|---------------|--------------|------|--------|
| 28 | Task Board | Interactive HTML task board with drag-and-drop + PostIt guide. | `task_board.html`, `postit_guide.md` | ~1,200 (HTML/JS) | Heath reviewed |
| 29 | Project Audit | Audited 150+ files. Rewrote stale HOWTOs. Deprecated old scripts. Created README.md. | HOWTOs, `scripts/phase3/deprecated/`, `README.md` | ~600 (markdown) | N/A |

---

**Total AI-assisted tasks:** 39
**Total lines of code generated:** ~9,120+
