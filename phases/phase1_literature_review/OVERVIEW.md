# PHASE 1: LITERATURE REVIEW & COMPETITIVE LANDSCAPE

**Project:** SCARAB - Comparative Genomics of Beetles
**PI:** Heath Blackmon, Texas A&M University
**Phase Timeline:** Days 1-3 (compressed 5-week timeline)
**Status:** COMPLETE (all 3 tasks done, 2026-03-21)

---

## PHASE GOAL

Rapidly assess the competitive landscape, identify similar beetle and insect whole-genome alignment projects, determine scooping risk, and refine our unique scientific angle. We move fast because publication-first strategy requires knowing what exists.

---

## CONTEXT: PREPRINT-FIRST STRATEGY

This project adopts a **preprint-first publication model** to establish priority and solicit community feedback rapidly:

1. **Preprint submission (bioRxiv):** Early in Phase 3-4, after core alignment and synteny results are solid
2. **Simultaneous journal submission:** Target high-impact journal (Nature, Genome Biology, PLOS Biol)
3. **Rationale:**
   - Scooping risk is real; preprints establish priority claim
   - Early dissemination enables community input on methods and interpretations
   - 2-3 month preprint → peer review → revision cycle is standard
   - All code, data, and results publicly available from Day 1 of preprint

---

## PHASE 1 TASKS (3 Tasks)

| Task | Title | Executor | Output |
|------|-------|----------|--------|
| 1.1 | Search Similar Projects | Team | competitive_landscape.csv, key_papers.bib |
| 1.2 | Zoonomia Landscape Review | Team | zoonomia_methods_summary.md, lessons_learned.md |
| 1.3 | Preprint Strategy | Heath (PI) | preprint_plan.md |

---

## TASK BREAKDOWN

### Task 1.1: Search Similar Projects
**Who:** Team (parallel search across multiple sources)
**Duration:** ~1 day
**Input:** None (literature search)
**Output Files:**
- `results/phase1_literature/competitive_landscape.csv` (≥20 projects reviewed)
- `results/phase1_literature/key_papers.bib` (BibTeX bibliography)

**What:** Systematic search across PubMed, bioRxiv, Google Scholar, and NCBI BioProjects for:
- Zoonomia-like beetle projects
- Large-scale insect whole-genome alignment projects
- Coleoptera synteny and karyotype studies
- Any published or in-progress beetle genomic consortia

**See:** `HOWTO_01_search_similar_projects.md`

---

### Task 1.2: Zoonomia Landscape Deep Review
**Who:** Team
**Duration:** ~1 day
**Input:** None (literature review)
**Output Files:**
- `results/phase1_literature/zoonomia_methods_summary.md` (5-10 pages)
- `results/phase1_literature/lessons_learned.md` (methods, scale, timeline, publication insights)

**What:** Deep study of:
- Original Zoonomia project (mammalian reference)
- Bird synteny atlas projects
- Fish phylogenomic alignments
- Plant synteny resources
- Extract: methods, pipeline steps, scale of effort, timeline, publication strategy, data release

**See:** `HOWTO_02_zoonomia_landscape.md`

---

### Task 1.3: Preprint Strategy & Publication Timeline
**Who:** Heath Blackmon (PI)
**Duration:** ~0.5 day
**Input:** Results from 1.1 and 1.2
**Output Files:**
- `results/phase1_literature/preprint_plan.md` (2-3 pages with timeline and venue decisions)

**What:** Strategic decisions:
- bioRxiv vs medRxiv vs other preprint servers
- Timeline: when to submit preprint relative to phases
- What goes in preprint vs full journal paper
- Target journals (Nature, Genome Biology, PLOS Biology, Molecular Biology and Evolution, etc.)
- Authorship and acknowledgments strategy
- Code/data release plan (GitHub, Zenodo, NCBI)

**See:** `HOWTO_03_preprint_strategy.md`

---

## PHASE 1 OUTPUTS SUMMARY

By end of Phase 1, the team will have:

1. **Competitive landscape map:** ≥20 relevant projects identified, threat levels assessed
2. **Key references library:** Curated BibTeX with all foundational papers (Zoonomia, insect projects, methods)
3. **Methods lessons:** Clear understanding of what worked in prior efforts
4. **Publication strategy:** Dates, venues, authorship, data release plan agreed

**Total effort:** ~2-3 FTE-days
**Blocking issues:** None anticipated; pure literature work

**Success criteria:**
- All 3 tasks completed with outputs in designated paths
- Phase 1 literature review informs Phase 2 genome curation
- Publication strategy is locked and communicated to all team members

---

## OUTPUTS DIRECTORY STRUCTURE

```
SCARAB/
├── results/
│   └── phase1_literature/
│       ├── competitive_landscape.csv
│       ├── key_papers.bib
│       ├── zoonomia_methods_summary.md
│       ├── lessons_learned.md
│       └── preprint_plan.md
```

---

## NEXT PHASE

**Phase 2 begins:** Day 3
**Input:** Literature review informs genome selection (which genomes do competing projects use?)
**Goal:** Curate 439 quality-approved genomes and build calibrated constraint phylogeny

---

*Phase 1 OVERVIEW | SCARAB | Draft Date: 2026-03-21*
