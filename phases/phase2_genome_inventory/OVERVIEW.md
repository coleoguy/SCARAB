# PHASE 2: GENOME INVENTORY & QUALITY CONTROL

**Project:** SCARAB - Comparative Genomics of Beetles
**PI:** Heath Blackmon, Texas A&M University
**Phase Timeline:** Days 3-7 (compressed 5-week timeline)
**Status:** COMPLETE (439 genomes downloaded and validated on Grace; all tasks done)

---

## PHASE GOAL

Assemble a curated, high-quality inventory of Coleoptera and Neuropterida genomes from public repositories. Perform quality control, assign phylogenetic positions, retrieve genome files, validate checksums, and build a constraint phylogenetic tree. Output is the foundational dataset for Phase 3 (whole-genome alignment). **Final result: 439 quality-approved genomes (422 Coleoptera + 17 Neuropterida outgroups).**

---

## INPUT FROM PHASE 1

**From Task 1.1:** `SCARAB/results/phase1_literature/competitive_landscape.csv`
- Informs which genomes competitors have used (helps prioritize our selections)

**From Task 1.2:** `SCARAB/results/phase1_literature/zoonomia_methods_summary.md`
- Documents quality thresholds and assembly standards used in analogous projects

**From Task 1.3:** `SCARAB/results/phase1_literature/preprint_plan.md`
- Confirms publication timeline and data release strategy

---

## PHASE 2 TASKS (7 Tasks, Compressed into 4 Days)

| Task | Title | Executor | Duration | Output |
|------|-------|----------|----------|--------|
| 2.1 | NCBI Mining | Team | ~1 day | ncbi_assemblies_raw.csv (≥50 genomes) |
| 2.2 | Ensembl Mining | Team | ~0.5 day | ensembl_assemblies_raw.csv (≥10 additional) |
| 2.3 | Merge & Deduplicate | Team | ~0.5 day | merged_genomes.csv |
| 2.4 | Phylogenetic Curation | Heath (PI) | ~0.5 day | curated_genomes.csv (≥50 high-conf) |
| 2.5 | Retrieve FASTA URLs | Team | ~1 day | fasta_urls.csv, genome_checksums.txt |
| 2.6 | Build Constraint Tree | Team | ~0.5 day | constraint_tree.nwk |
| 2.7 | Generate QC Report | Team | ~0.5 day | qc_report.pdf, data_manifest.csv |

**Total effort:** ~4-5 FTE-days, high parallelization (tasks 2.1, 2.2, 2.5 can run in parallel)

---

## TASK BREAKDOWN & DEPENDENCIES

### Task 2.1: NCBI Mining
**Executor:** Team
**Duration:** ~1 day
**Input:** None (first data collection step)
**Output:** `data/genomes/ncbi_assemblies_raw.csv` (≥50 assemblies)
**Acceptance:** ≥50 high-quality Coleoptera assemblies identified, filtration criteria documented
**See:** `HOWTO_01_ncbi_mining.md`

---

### Task 2.2: Ensembl Mining
**Executor:** Team
**Duration:** ~0.5 day
**Input:** `data/genomes/ncbi_assemblies_raw.csv` (from Task 2.1)
**Output:** `data/genomes/ensembl_assemblies_raw.csv` (≥10 additional non-redundant)
**Acceptance:** Deduplicated against NCBI set, no species duplicates
**See:** `HOWTO_02_ensembl_mining.md`

**Can run in parallel with Task 2.1**

---

### Task 2.3: Merge & Deduplicate
**Executor:** Team
**Duration:** ~0.5 day
**Input:** Both CSV files from Tasks 2.1 & 2.2
**Output:** `data/genomes/merged_genomes.csv` (one row per species, quality-ranked)
**Output:** `results/phase2_genome_inventory/dedup_report.txt` (deduplication decisions)
**Acceptance:** ≥60 unique beetle species, no duplicate rows, quality ranking documented
**See:** `HOWTO_03_merge_deduplicate.md`

**Depends on:** Tasks 2.1 & 2.2 complete

---

### Task 2.4: Phylogenetic Placement (Curation by PI)
**Executor:** Heath Blackmon
**Duration:** ~0.5 day
**Input:** `data/genomes/merged_genomes.csv` (from Task 2.3)
**Output:** `data/genomes/curated_genomes.csv` (adds family, tribe, clade position, QC flags, include_yn)
**Acceptance:** All genomes taxonomically placed, QC issues documented, ≥50 marked for inclusion
**See:** `HOWTO_04_phylogenetic_placement.md`

**Depends on:** Task 2.3 complete

---

### Task 2.5: Retrieve FASTA URLs & Verify
**Executor:** Team
**Duration:** ~1 day
**Input:** `data/genomes/curated_genomes.csv` where `include_yn=YES` (from Task 2.4)
**Output:** `data/genomes/fasta_urls.csv` (FTP URLs + metadata for all ≥50 selected genomes)
**Output:** `data/genomes/genome_checksums.txt` (MD5 or SHA256 hashes)
**Acceptance:** All URLs tested and confirmed accessible, all checksums present and validated
**See:** `HOWTO_05_fasta_urls.md`

**Can run in parallel with Task 2.4 (after Task 2.3 complete)**

---

### Task 2.6: Build Constraint Phylogeny
**Executor:** Team
**Duration:** ~0.5 day
**Input:** `data/genomes/curated_genomes.csv` (from Task 2.4, for taxonomy and clade assignments)
**Output:** `data/genomes/constraint_tree.nwk` (Newick format, rooted, all species included)
**Acceptance:** Valid Newick, all species in tree, monophyletic major clades, cited topology sources
**See:** `HOWTO_06_constraint_tree.md`

**Can run in parallel with Task 2.5**

---

### Task 2.7: QC Report & Data Manifest
**Executor:** Team
**Duration:** ~0.5 day
**Input:** All Phase 2 outputs (Tasks 2.1-2.6)
**Output:** `results/phase2_genome_inventory/qc_report.pdf` (summary stats, figures)
**Output:** `results/phase2_genome_inventory/data_manifest.csv` (audit trail of all genomes)
**Acceptance:** Report complete with figures and tables, ready to append to paper supplementary
**See:** `HOWTO_07_qc_report.md`

**Depends on:** All other tasks complete (final synthesis)

---

## PHASE 2 OUTPUTS SUMMARY

By end of Phase 2, the project will have:

1. **Inventory of ≥50 curated Coleoptera genomes** with quality metrics
2. **Accessible genome files** (FASTA, validated checksums)
3. **Constraint phylogenetic tree** (topology from literature, all species positioned)
4. **QC documentation** (assembly quality, BUSCO completeness, coverage)
5. **Data manifest** (audit trail, ready for publication supplement)

**All data ready for Phase 3 (genome alignment)**

**Files ready for publication:** QC report, data manifest, constraint tree, supplementary genome table

---

## QUALITY THRESHOLDS (Derived from Phase 1 Lessons)

Based on Zoonomia and analogous projects, these thresholds are applied:

| Metric | Minimum Threshold | Rationale |
|--------|------------------|-----------|
| Assembly level | Scaffold or better | Avoid fragmented contig-only genomes |
| N50 | ≥100 kb | Ensures sufficient contiguity |
| BUSCO completeness | ≥85% | Core gene set mostly present |
| Genome size | 100-600 Mb (beetles) | Coleoptera typical range |
| Publication year | ≥2018 | Quality standards improved; modern sequencing |

**Quality ranking:** Priority given to chromosome-level assemblies (RefSeq), then scaffold-level

---

## OUTPUTS DIRECTORY STRUCTURE

```
SCARAB/
├── data/
│   └── genomes/
│       ├── ncbi_assemblies_raw.csv
│       ├── ensembl_assemblies_raw.csv
│       ├── merged_genomes.csv
│       ├── curated_genomes.csv
│       ├── fasta_urls.csv
│       ├── genome_checksums.txt
│       └── constraint_tree.nwk
└── results/
    └── phase2_genome_inventory/
        ├── dedup_report.txt
        ├── qc_report.pdf
        └── data_manifest.csv
```

---

## SUCCESS CRITERIA FOR PHASE 2

Phase 2 is complete when:

- [ ] Task 2.1: ≥50 NCBI Coleoptera assemblies identified, filtered by quality
- [ ] Task 2.2: ≥10 additional non-redundant Ensembl genomes added
- [ ] Task 2.3: Merged dataset has ≥60 unique beetle species, no duplicates
- [ ] Task 2.4: All genomes taxonomically placed by Heath, ≥50 marked `include_yn=YES`
- [ ] Task 2.5: All FTP URLs accessible, all checksums validated
- [ ] Task 2.6: Constraint tree is valid Newick, monophyletic clades verified
- [ ] Task 2.7: QC report complete with figures and tables
- [ ] All files in designated paths with exact filenames
- [ ] Data ready for Phase 3 (alignment & synteny)

---

## NEXT PHASE

**Phase 3 begins:** Day 8
**Input:** Phase 2 outputs (curated genomes, constraint tree, FASTA URLs)
**Goal:** Whole-genome alignment using progressiveCactus

---

## BLOCKING ISSUES & MITIGATION

**Potential issue:** Some NCBI genomes no longer accessible (retracted, moved)
**Mitigation:** Task 2.5 includes URL validation step; substitute with alternative if needed

**Potential issue:** Heath's curation of Task 2.4 becomes bottleneck
**Mitigation:** Start Task 2.5 in parallel; Heath curation can proceed while team retrieves URLs

**Potential issue:** Ensembl API down or overloaded (Task 2.2)
**Mitigation:** Fallback to direct FTP download from Ensembl FTP server

---

## NOTES FOR TEAM

- **Data integrity:** All checksums will be validated before Phase 3 starts
- **Reproducibility:** Commands and scripts documented in each HOWTO
- **Version control:** Phase 2 outputs are locked (read-only) once approved; no revisions during Phase 3
- **Communication:** Weekly team sync to track progress; flag blockers immediately

---

*Phase 2 OVERVIEW | SCARAB | Draft Date: 2026-03-21*
