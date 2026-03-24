# Progress Tracking — SCARAB

**Project Start:** 2026-03-21
**Preprint Target:** ~2026-05-02
**Last Updated:** 2026-03-23 (tree rooted, Cactus test + P3 BLAST running)

---

## Phase Status Overview

| Phase | Status | Tasks Done | Tasks Remaining |
|-------|--------|------------|-----------------|
| Literature Review (LR) | **COMPLETE** | 3/3 | — |
| Phase 2: Genome Inventory | **COMPLETE** | 7/7 | — |
| Genome Downloads | **COMPLETE** (439/439 validated) | 2/2 | — |
| Phase 3: Alignment & Synteny | **IN PROGRESS** | 5/7 | Tree rooted, Cactus test RUNNING (18117479), P3 BLAST RUNNING (18114486) |
| Phase 3.5: Karyotype Compilation | **COMPLETE** | 1/1 | — |
| Phase 4: Rearrangements | NOT STARTED | 0/7 | Blocked on Phase 3 |
| Phase 5: Viz & Manuscript | **PARTIAL** (Intro + Results drafted) | 2/7 | Blocked on Phase 4 |

---

## Current Status (2026-03-23)

**Phase 3: Whole-Genome Alignment — Two parallel tracks running on Grace**

**Track 1 — Cactus alignment:**
- Guide tree: DONE (439 tips, re-rooted on 17 Neuropterida, all monophyletic)
- Cactus seqfile: DONE (440 lines, rooted tree + 439 genome paths)
- Test alignment: **RUNNING** (job 18117479, 5 smallest genomes, medium partition). First attempt (18114304) failed due to Toil jobstore corruption; fixed by nuking work directory.
- Full alignment: BLOCKED on test results

**Track 2 — Phylogenomics (1,286-locus ASTRAL pipeline):**
- P.1 Map BUSCOs to Tribolium: **DONE** — 1,286 genes mapped to 10 Tcas chromosomes (job 18112279)
- P.2 Select loci: **SKIPPED** — using ALL 1,286 genes for maximum power
- P.3 BLAST 1,286 × 439: **RUNNING** (job 18114486, ~1.5 days remaining, long partition)
- P.4–P.8: PENDING (blocked on P.3)

**Tribolium chromosome distribution (1,286 genes):**
chr1: 190, chr2: 148, chr3: 171, chr4: 142, chr5: 177, chr6: 112, chr7: 80, chr8: 77, chr9: 123, chr10: 65, unplaced: 1

**Next actions (PER QUALITY GATE POLICY):**
1. **Check Cactus test results** when job 18117479 completes (~30-90 min) → Heath reviews → full alignment
2. **Check P3 BLAST results** when job 18114486 completes (~1.5 days) → submit P4/P5
3. **Stevens element assignment** — map Tcas chr1-10 to Stevens elements via Bracewell et al. (2024)
4. **Send $SCRATCH quota email** (Gmail draft ready, needs sending)
5. While waiting: Google.org AI for Science grant (deadline April 17)

---

## Pending / Awaiting Human Action

| Task | Owner | Action Needed | Priority |
|------|-------|---------------|----------|
| **Review Cactus test results** | **Heath** | Check job 18117479 output when complete → approve for full run | **URGENT** |
| **Review P3 BLAST results** | **Heath** | Check job 18114486 output (~1.5 days) → approve for P4/P5 | **HIGH** |
| **Send $SCRATCH quota email** | **Heath** | Gmail draft ready (r1569898534488795924) — send to help@hprc.tamu.edu | **HIGH** |
| **Full Alignment** | Heath | Submit `run_full_alignment.slurm` after test passes | HIGH |
| **Google.org Grant** | **Heath** | **Deadline April 17** — #1 strategic priority | **CRITICAL** |
| Stevens element assignment | Claude+Heath | Map Tcas chr1-10 to Stevens elements (Bracewell et al. 2024) | Medium |
| Introduction Review | Heath | Review `manuscript/drafts/introduction_draft.docx` | Low |
| Results Review | Heath | Accept tracked changes in `results_genome_dataset.docx` | Low |

---

## Critical Path

```
CRITICAL PATH (Cactus alignment):
1.1 → 1.3 → 1.5 → 1.6 → 1.7 → 2.1 → 1.8 → 1.9 → nuc_tree → reroot → test → 2.2(7-21d HPC) → 2.3 → 2.5 → 2.6 → 3.1 → 3.3 → 3.6 → 4.1 → 4.6 → 4.7
↑done↑ ↑done↑ ↑done↑ ↑done↑ ↑done↑ ↑done↑ ↑done↑ ↑done↑ ↑DONE↑   ↑DONE↑  ↑RUN↑

PARALLEL TRACK (phylogenomics — feeds into 3.3):
P.1(BUSCO→Tcas) → P.2(SKIP) → P.3(BLAST 1286×439) → P.4(align) → P.5(gene trees) → P.6(ASTRAL+gCF) → P.8(finalize) ──→ 3.3 + A.0
↑DONE↑             ↑DONE↑      ↑RUNNING(18114486)↑                                     P.7(concat IQ-TREE) ────────────↗
```

**Bottleneck:** Task 2.2 (full Cactus alignment on Grace, ~7–21 days wall-clock). Everything downstream is blocked until alignment completes.

**Parallel work while Cactus runs:** Phylogenomics pipeline (P.1–P.8), Google.org grant, literature review (LR.3), karyotype data review, methods editing, figure review, student DOI curation.

---

## Completed Tasks

### Phase 1: Literature Review — COMPLETE
- LR.1: Competitive landscape analysis (Bracewell et al. 2024, Wright et al. 2024)
- LR.2: Zoonomia landscape review (16-paper annotated bibliography)
- LR.3: Preprint strategy drafted

### Phase 2: Genome Inventory — COMPLETE
- 1.1: Mined NCBI — 1,121 assemblies (971 Coleoptera + 150 Neuropterida)
- 1.2: Confirmed DNAzoo/Ensembl already captured via NCBI
- 1.3: Deduplicated to 687 primary selections
- 1.5: Download infrastructure + restriction audit
- 1.6: 439-tip constraint tree (McKenna et al. 2019 backbone)
- 1.7: QC report + 5 supplementary figures
- 1.8: 439/439 genomes downloaded on Grace (login-node curl, 3 rounds)
- 1.9: Downloads validated (439/439 confirmed)

### Phase 2 Supporting Work — COMPLETE
- Tree calibration: 29 nodes, 4 published sources, root 320 Ma
- Phase 3 scripts: build_seqfile.sh, setup_phase3.sh, test_alignment.slurm, run_full_alignment.slurm
- 6 R script templates (3,050 lines, base R)
- Methods section draft (docx)
- Results section draft + Table S1 (xlsx)
- Introduction draft (docx)
- Karyotype compilation: 265/439 species (60.4% coverage)

### Phase 3: Guide Tree (15-gene FastTree) — COMPLETE
- Nuclear BUSCO marker approach: `prepare_nuclear_markers.sh` + `extract_nuclear_markers_and_build_tree.slurm` + `fix_38_reblast_and_rebuild.slurm`
- 15 conserved BUSCO insecta proteins (1,778–3,033 aa each)
- 439/439 taxa with molecular data (100%), 0 grafted
- Supermatrix: 43,060 aligned amino acid positions
- FastTree WAG+CAT: 439 tips, branch lengths 1.06e-03 to 1.33 subs/site
- Quality gate PASSED (100% > 90% threshold)
- Tree quality: Neuropterida, Adephaga, 13+ families monophyletic. *Otiorhynchus* on extreme long branch.
- Bug fix: 38 genomes had silent OOM kills; fixed by job 18110451
- **Re-root on Neuropterida → use as Cactus guide tree**

### Phylogenomics Pipeline (1,286-gene ASTRAL) — IN PROGRESS
- Runs in parallel with Cactus alignment (does not block critical path)
- P.1: Map all BUSCO insecta proteins to Tribolium chromosomes — **DONE** (1,286 genes on 10 chromosomes)
- P.2: Select loci — **SKIPPED** (using all 1,286 for maximum power)
- P.3: tBLASTn 1,286 genes × 439 genomes — **RUNNING** (job 18114486, ~1.5 days remaining)
- P.4: Per-gene MAFFT alignments — PENDING
- P.5: Per-gene IQ-TREE trees (1,286 independent SLURM array jobs) — PENDING
- P.6: ASTRAL-III species tree + gene/site concordance factors (gCF/sCF) — PENDING
- P.7: Partitioned IQ-TREE on concatenation as concordance check — PENDING
- P.8: Compare ASTRAL vs concat; McKenna backbone for unresolved deep nodes — PENDING
- **Purpose**: Publication-quality species tree for rearrangement mapping + enables novel discordance × breakpoint analysis (A.0)
- **Novel analysis A.0**: Test whether gene tree discordance correlates with proximity to chromosomal breakpoints. Per-Stevens-element concordance. Direct test of chromosomal speciation model at 439-genome scale.
