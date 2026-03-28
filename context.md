# SCARAB Project: Context & Overview

## Project Title
**SCARAB: Synteny, Chromosomes, And Rearrangements Across Beetles**

## Principal Investigator
Heath Blackmon

## Project Goal
Construct a systematic, genome-scale atlas of chromosomal rearrangements (fusions, fissions, inversions) across ~453 beetle and outgroup genomes spanning the major clades of Coleoptera. This project aims to:
- Document the rate, frequency, and distribution of rearrangement hotspots across beetle lineages
- Reconstruct ancestral karyotypes at key nodes of the beetle phylogeny
- Identify associations between chromosomal changes and speciation events
- Establish baseline metrics for chromosomal evolution in the most species-rich eukaryotic order

## Current Status
**Phase 3: Whole-Genome Alignment — IN PROGRESS** (2026-03-28). Phases 1-2 COMPLETE.

**Accomplishments (2026-03-28):**
- Decomposed Cactus pipeline (`run_cactus_decomposed.py`): level-by-level submission with quality gates between levels. `cactus-prepare` decomposes alignment into 465 sub-problems across 33 tree-depth levels.
- Cactus preprocess: RUNNING (15 jobs, genome masking for 466 taxa)
- Cactus L1 (145 leaf-pair blast+align): ready to submit when preprocess completes
- P4/P5 gene trees: 489/1,284 done, 151 running as SLURM array. Auto-cleanup of IQ-TREE intermediates.
- Genome filter: 478 → 466 taxa (12 excluded). Tree binarized (fixed root trifurcation from R ape). Support values stripped.
- Stevens element mapping COMPLETE: all 1,286 BUSCO loci mapped to Stevens elements via BLASTn of Tcas5.2 LGs against icTriCast1.1. File: `busco_tribolium_stevens_map.tsv`.
- Combined BLAST database: building single db for all 478 genomes (replaces 3,900 individual db files).
- Inode limit management: scripts auto-clean Toil jobstores and IQ-TREE intermediates. Individual blast_dbs deleted (79 GB, 3,900 files freed). File count stable at ~43K/250K.
- Discordance x breakpoint analysis script: `scripts/phase4/discordance_x_breakpoints.R` (4 stages, ready to run when gene trees and Cactus complete).

**Currently running on Grace:**
- Cactus preprocess: 15 jobs (14 running, 1 done)
- Gene tree array: ~151 running (489/1,284 complete)
- Combined BLAST db build: 1 job

**Pending (in order):**
1. Cactus preprocess finishes → submit L1 (145 leaf-pair blast+align)
2. L1 finishes → QC sub-HALs → Heath approves → submit L2 (88 jobs) → continue through L33
3. Gene trees finish (1,284 total) → submit P6 (ASTRAL) → P7 (concatenation)
4. After P6/P7: run Stage A of discordance analysis (gCF by Stevens element)
5. After Cactus complete: breakpoint calling → Stage B discordance analysis

---

## Guide Tree Strategy (478 taxa)

**Cactus guide tree (15-gene FastTree):**
- Status: DONE for 439 taxa (nuclear_guide_tree_439_rooted.nwk)
- For 478 taxa: build_478_starting_tree.slurm BLASTs same 15 proteins against 39 recovery genomes, finds nearest neighbor in 439-taxon tree by shared gene count, grafts. Output: nuclear_guide_tree_478_rooted.nwk.
- This grafted tree is NOT the reported guide tree. It is only a starting topology for IQ-TREE.

**Reported guide tree (IQ-TREE on full matrix):**
- iqtree_478.slurm runs IQ-TREE with LG+G4 on concatenated BUSCO supermatrix for all 478 taxa, using grafted tree as -t starting topology
- Methods description: "A maximum likelihood guide tree for 478 taxa was inferred using IQ-TREE [version] on a concatenated matrix of BUSCO loci (LG+G4 model)"
- The grafting step is an internal implementation detail, not mentioned in methods
- Output: nuclear_guide_tree_478_iqtree.nwk

---

## Phylogenomics Strategy (2026-03-23, updated 2026-03-24)

- **Cactus guide tree** = FastTree from 15 BUSCO genes (439 taxa) + IQ-TREE from 1,286 loci (478 taxa). See above.
- **Rearrangement mapping tree** = Full phylogenomics pipeline with 1,286 BUSCO loci:
  1. ~~Map all 1,367 BUSCO insecta_odb10 proteins to Tribolium chromosomes~~ DONE (1,286 genes mapped, job 18112279)
  2. ~~Select loci~~ SKIPPED (using all 1,286 genes)
  3. tBLASTn 1,286 genes x 439 genomes -- RUNNING (job 18114486)
     tBLASTn 1,286 genes x 39 recovery genomes -- RUNNING (job 18122417)
  4. Per-gene MAFFT alignments (478 taxa) -- PENDING P4
  5. Per-gene IQ-TREE trees (1,286 trees) -- PENDING P5
  6. ASTRAL-III species tree + gCF/sCF -- PENDING P6
  7. Partitioned IQ-TREE concatenation -- PENDING P7

**Novel analysis: Gene tree discordance x chromosomal breakpoints**
- 1,286 gene trees mapped to chromosomal positions AND Cactus-inferred breakpoints
- Test whether discordant genes cluster near rearrangement breakpoints
- Temporal dimension: at nodes with high rearrangement rates, does discordance increase among breakpoint-proximal genes?
- Per-Stevens-element concordance factors
- Direct test of chromosomal speciation model (Rieseberg/Noor/Navarro-Barton) at 478-genome scale
- Potential standalone result; at least 2 manuscript figures

---

## Genome Recovery (2026-03-23, completed 2026-03-24)

- 39 additional species from "conditional" category pass Cactus quality thresholds (contig N50 >= 100 kb, scaffolds <= 10,000)
- All published_open except Lamprigera yunnana (to_verify)
- Adds 2 new families: Lycidae (Platerodrilus igneus), Rhagophthalmidae (Rhagophthalmus giganteus)
- 27 Gb download; many are excellent HiFi assemblies misclassified as "Contig" level by NCBI
- All 39 files now at $SCRATCH/scarab/genomes/ (verified 2026-03-24 00:33)
- Scripts:
  - download_recovery_genomes.py: Python 3.6 compatible, no datasets CLI needed, idempotent
  - download_recovery_genomes.slurm: SLURM wrapper (transfer partition, idempotent)
  - build_478_starting_tree.slurm: data-driven grafting + IQ-TREE starting tree
  - iqtree_478.slurm: full 478-taxon ML tree (reported in methods)
  - P3_blast_recovery_taxa.slurm: supplemental phylogenomics BLAST for recovery taxa

---

## Genome Inventory

**Catalog**: data/genomes/genome_catalog.csv

| Metric | Count |
|--------|-------|
| Total assemblies mined | 1,121 (971 Coleoptera + 150 Neuropterida) |
| Primary selections | 687 |
| Quality-filtered (original) | 439 |
| Recovery genomes (conditional, pass thresholds) | 39 |
| Pre-filter total | 478 |
| Estimated post-filter (for Cactus) | ~453 |
| Coleoptera families covered | 61+ (Lycidae + Rhagophthalmidae added) |
| Outgroup orders | Neuroptera (138), Megaloptera (8), Raphidioptera (4) |

**Downloads**: 439/439 original + 39/39 recovery = 478/478 on Grace (all validated).

**Competitive position**: ~453 post-filter = largest single-clade single-run Progressive Cactus alignment ever. Above B10K (363 birds, single run), Zoonomia (241 mammals), and all other single-clade WGA projects. UCSC 605-way amniotes used two merged sub-alignments.

---

## Genome Quality Filter

- Script: grace_upload_phase3/filter_genomes_for_alignment.R
- Thresholds: contig N50 >= 100 kb AND scaffold count <= 10,000
- T. castaneum is mandatory keep (Stevens element reference)
- ~25 genomes from the 478-taxon set expected to fail; final count from running script on Grace
- Duplicates to check: Agrilus planipennis (x2), Dendroctonus ponderosae (x3), T. castaneum (x3 in catalog)

---

## Full Alignment Strategy

- Script: grace_upload_phase3/run_full_alignment.slurm
- Approach: bigmem node (80 cores, 2.9 TB RAM), xlong queue, 18-day wall time with --restart resume
- SIGTERM received 1 hour before wall time; Toil checkpoints and exits cleanly
- Watchdog: grace_upload_phase3/cactus_watchdog.sh (run in tmux on login node, auto-resubmits)
- Expected cycles: 4-5 (18 days each, ~75 days total)
- Scratch needed: ~660-1,160 Gb total; quota increase requested (7 TB)
- Uses filtered seqfile: $SCRATCH/scarab/cactus_seqfile_filtered.txt

---

## Grace File Structure

```
$SCRATCH/scarab/
├── genomes/                     # 478 genome files (*.fna.gz)
│   ├── [439 original genomes]
│   └── [39 recovery genomes]    # COMPLETE as of 2026-03-24
├── nuclear_markers/
│   ├── marker_proteins.fasta    # 15 BUSCO proteins for guide tree
│   ├── nuclear_guide_tree_439.nwk
│   ├── nuclear_guide_tree_439_rooted.nwk   # current Cactus guide tree
│   ├── nuclear_guide_tree_478_rooted.nwk   # PENDING (build_478_starting_tree.slurm)
│   ├── nuclear_guide_tree_478_iqtree.nwk   # PENDING (iqtree_478.slurm)
│   └── tree_build_*/            # Per-gene sequences from 439-taxon build
├── phylogenomics/
│   ├── busco_tribolium_map.tsv  # DONE (1,286 genes)
│   ├── selected_loci.txt        # DONE
│   ├── selected_proteins.fasta  # DONE
│   ├── per_gene_seqs/           # IN PROGRESS (P3 job 18114486 + 18122417)
│   └── [P4-P7 outputs pending]
├── cactus_seqfile.txt           # 439-taxon seqfile (current)
├── cactus_seqfile_478.txt       # PENDING (after IQ-TREE tree ready)
├── cactus_seqfile_filtered.txt  # PENDING (after filter_genomes_for_alignment.R)
├── recovery_accessions.txt      # 39 recovery accessions
├── download_recovery_genomes.py # Python download script
├── build_478_starting_tree.slurm
├── iqtree_478.slurm
└── [other scripts]

$HOME/SCARAB/                    # Git clone of coleoguy/SCARAB
```

---

## GitHub Repository

**Repo**: coleoguy/SCARAB (public)
**URL**: https://github.com/coleoguy/SCARAB
**SSH**: git@github.com:coleoguy/SCARAB.git (set up on Grace)

**Workflow**: Edit on Mac/Cowork -> git push from Mac -> git pull on Grace -> cp to $SCRATCH/scarab/
**Current state**: Fully synced as of 2026-03-24. All grace_upload_phase3/ scripts committed.

**Known issue**: HEAD.lock conflicts occur when Cowork VM and Mac git processes run concurrently on Google Drive. Fix: rm the .git/HEAD.lock file from Mac terminal, then push normally.

---

## QUALITY GATE POLICY -- MANDATORY

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
Even if a SLURM job exits 0 and a quality gate script says "PASSED," the assistant must still walk through the output with Heath.

### Acceptance Criteria by Stage

**Guide tree (478-taxon IQ-TREE):**
- >= 90% of taxa must have molecular data in the concatenated matrix
- Tree must be binary with branch lengths in substitutions/site
- No branch length > 25.0 (Cactus hard limit)
- Topology must be biologically plausible (Neuropterida outgroup monophyletic, major beetle suborders recovered)
- Heath must approve before Cactus seqfile is updated and full alignment is submitted

**Test alignment:**
- Job completes without error
- HAL file is produced and non-empty
- halStats summary reviewed (number of genomes, total aligned bases)
- Heath approves before full alignment is submitted

**Full alignment:**
- Review halStats, alignment coverage, per-genome stats before downstream analysis

---

## Manuscript Status

| Document | Status |
|----------|--------|
| Introduction | Draft complete (manuscript/drafts/introduction_draft.docx) |
| Methods | Draft complete (manuscript/drafts/methods_draft.docx); Species tree section added 2026-03-23; genome filter paragraph added 2026-03-23 |
| Results | Phase 2 results drafted (manuscript/drafts/results_genome_dataset.docx) |
| Table S1 | Complete (manuscript/supplementary/Table_S1_genome_dataset.xlsx) |
| Figures S1-S5 | Complete (manuscript/figures/) |

**Target journals**: Nature Ecology & Evolution (primary), MBE, Current Biology, Genome Research

---

## Novel Downstream Analyses

### Tier 0 -- Enabled by phylogenomics pipeline
- **A.0 Gene tree discordance x chromosomal breakpoints**: 1,286 BUSCO gene trees mapped to chromosomal positions (Stevens elements) via Tribolium reference. Test whether discordant genes (low gCF) cluster near Cactus-inferred rearrangement breakpoints. Direct test of chromosomal speciation model (Rieseberg/Noor/Navarro-Barton) at 478-genome scale. At least 2 manuscript figures.

### Tier 1 -- Only possible in beetles
- **A.1 Karyotype rate vs. genomic rearrangement rate**: Correlate cytogenetic fusion/fission rates with Cactus-inferred rates. CENTERPIECE ANALYSIS.
- **A.2 Fragile-Y hypothesis tested genomically**: Trace X and neo-sex chromosome origins across 400+ species.
- **A.3 Rearrangement rate shifts x diversification**: Correlate branch-specific rearrangement rates with speciation rates.

### Tier 2 -- High-impact
- **A.4 Breakpoint hotspot characterization**: Recurrent breakpoint regions, TE enrichment
- **A.5 Stevens element conservation across 56+ families**
- **A.6 Fusion partner asymmetry**

---

## Computational Infrastructure

### TAMU Grace Cluster
- 800 standard nodes: 48 cores, 384 GB RAM
- 8 bigmem nodes: 80 cores, 3 TB RAM
- Queues: short (2h), medium (1d), long (7d), xlong (21d), bigmem (2d)
- Compute nodes have NO internet. Downloads run on login node only.
- File transfer: sftp (not scp -- Duo 2FA causes timeout)
- Container runtime: Singularity (not Docker)
- Python version: 3.6 (use stdout=subprocess.PIPE, stderr=subprocess.PIPE, not capture_output=True)
- Scratch quota: 1 TB (increase to 7 TB requested 2026-03-24, account 02-133547-00003)

---

## Competitive Landscape

**Closest analog**: Wright et al. (2024) Nat Eco Evo -- 210 Lepidoptera genomes, 32 Merian elements.
**Key competitor**: Bracewell et al. (2024) PLOS Genetics -- 9 "Stevens elements" from 12 beetle genomes.
**WGA leaders**: UCSC 605-way amniotes (two merged sub-alignments), B10K 363 birds (single run), Zoonomia 241 mammals.
**Our position**: ~453 post-filter = largest single-clade single-run Progressive Cactus alignment ever attempted.
**Unique contributions**: Scale, ancestral karyotype reconstruction, rearrangement rate mapping, cross-validation with 4,700-species karyotype database, two-tier approach (Cactus WGA for shallow nodes + gene-order synteny for deep nodes), discordance x breakpoint analysis.
**Scooping risk**: LOW-MEDIUM.

---

## Team

| Role | Name | Responsibility |
|------|------|-----------------|
| PI | Heath Blackmon | Project direction, biological interpretation, final decisions |
| AI Assistant | Claude | Code generation, analysis scripting, documentation |

---

## Timeline
- **Phase 1** (Days 1-3): Literature review -- COMPLETE
- **Phase 2** (Days 3-7): Genome inventory -- COMPLETE
- **Phase 3** (Days 7-24): Whole-genome alignment -- IN PROGRESS
- **Phase 4** (Days 24-30): Rearrangement annotation
- **Phase 5** (Days 30-35): Visualization, manuscript figures

**Project Start**: 2026-03-21
**Preprint Target**: ~2026-05-02
**Full Submission Target**: ~2026-07-02

---

## Writing Style Rule
Never use emdashes in any project text. Prefer commas, parentheses, colons, semicolons, or separate sentences.

---

**Last Updated**: 2026-03-28 (Decomposed Cactus pipeline running; gene trees 489/1284; Stevens element mapping complete; discordance analysis script written; inode management fixed)
