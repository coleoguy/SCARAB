# TOB Workflow v1 — Locked-in Methodology

**Date:** 2026-05-03. **Status:** synthesis of 8 literature reviews + NCBI inventory refresh. Locks in tool choices and pipeline structure. All decisions traceable to evidence in `literature/notes/`.

---

## Headline numbers

**Tier 1 (genomes):**
- 478 SCARAB existing tips, of which 439 made it into the previous tree
- **546 new candidates** in NCBI not in SCARAB catalog (323 "include", 176 "conditional", 47 "exclude") — see [data/ncbi_inventory_refresh_2026-05.csv](data/ncbi_inventory_refresh_2026-05.csv)
- **101 new chromosome-level assemblies**, 306 new scaffold-level
- Top new entries are exceptional: *Monochamus alternatus* (82.97 Mb contig N50), *Onthophagus binodis* (58.69 Mb), *Larinus ursus* (45.36 Mb)
- Realistic Tier 1 final count: ~700–800 useful Coleoptera + Strepsiptera + Neuropterida genomes

**Tier 2 (transcriptomes + DIY):**
- 4 verified TSAs covering ancient suborders: *Priacma* (Cupedidae), *Micromalthus* (Micromalthidae), *Hydroscapha* (Hydroscaphidae), *Lepicerus* (Lepiceridae)
- 2 DIY assemblies from raw SRA: *Sphaerius* sp. Arizona + *Sphaerius* cf. *minutus* (Sphaeriusidae) — covers another myxophagan family
- Outgroup anchors: 2 Strepsiptera (*Xenos peckii* GCA_040167675 + 1 Mengenillidia), 6 Neuropterida (existing SCARAB), 2–3 Hymenoptera (NEW for TOB — McKenna 2019 set as guide)

**Tier 3 (Sanger fill-in):**
- Target: ~10,000–30,000 Coleoptera species mined from GenBank
- Common loci: COI, 16S, 18S, 28S, CAD, EF1α, ArgK, RNA pol II, wingless

---

## Locked-in methodology

### Backbone inference (Tier 1+2)

| Decision | Choice | Rationale | Source |
|----------|--------|-----------|--------|
| Ortholog set | BUSCO insecta_odb10 | Already used by SCARAB; same as McKenna 2019 framework | — |
| Per-locus alignment | MAFFT-LINSI | Standard, accurate for divergent insect orthologs | — |
| Trimming | TrimAl `-automated1` or BMGE | Both used in McKenna/Cai/Niehuis pipelines | notes/01 |
| Inference (ML) | **IQ-TREE with LG+C60+F+R or CAT-GTR+G4** — NOT vanilla GTR | Strepsiptera + Cucujiformia + Curculionoidea exhibit LBA artifacts under site-homogeneous models | notes/01, 07 |
| Inference (coalescent) | ASTRAL-III on per-locus gene trees, run alongside ML for cross-validation | Standard ILS-aware comparison | notes/06 |
| Topology constraint | Pin >80 universally supported nodes from **Creedy et al. 2025 *Syst Biol*** | Empirically grounded "hard" constraints — corroborated independently by Agents 1 and 6 | notes/01, 06 |
| Branch support | Ultrafast bootstrap (1000 reps) + SH-aLRT | IQ-TREE standard | — |
| Concordance | gCF / sCF per node (already wired in SCARAB pipeline) | Catches misleading high bootstrap on conflicting genes | notes/08 |
| Compositional bias check | BaCoCa or IQ-TREE GHOST on a 50-locus subsample | Insect mega-trees historically burned by base-comp heterogeneity | notes/08 |
| Outgroup composition | 2 Strepsiptera + 6 Neuropterida + 2–3 Hymenoptera = 10–11 taxa total | Matches McKenna 2019; Hymenoptera anchor stabilises Strepsiptera placement | notes/07 |

### Tier 3 (per-family fill-in)

| Decision | Choice | Rationale | Source |
|----------|--------|-----------|--------|
| GenBank mining | **SuperCRUNCH** primary, **phylotaR** for obscure families | SuperCRUNCH targets named loci with BLAST + has built-in synonym flagging; phylotaR's unsupervised BLAST clustering catches what SuperCRUNCH misses | notes/02 |
| Taxonomic authority | **Bouchard et al. 2024** (*ZooKeys* 1194), accessed via Catalogue of Life ChecklistBank API | Newest authoritative Coleoptera classification; CoL already conformed to it | notes/05 |
| Synonym reconciliation | Custom Bouchard↔NCBI table (one-time build) | SuperCRUNCH flags but doesn't auto-correct; recognised as the dominant up-front time cost | notes/02 |
| Per-family ML | IQ-TREE with `-g backbone.tre` constraint | Pins family stem to backbone, frees within-family relationships | notes/06 |
| Occupancy threshold | Taxa with <30% locus occupancy excluded from primary supermatrix; either dropped or routed to placement | Bocak 2014 demonstrated catastrophic failure of low-occupancy supermatrices | notes/08 |

### Tier 4 / placement

| Decision | Choice | Rationale | Source |
|----------|--------|-----------|--------|
| Barcode-only species placement | **EPA-ng** | Standard for adding very-low-data tips to a fixed reference tree | notes/06 |
| Fragmentary sequences | SEPP for highly fragmentary | Used in OToL pipeline | notes/06 |
| Taxonomy-only placeholders | **Excluded from the published tree** | Hard rule — Bocak/OToL/TimeTree all degraded by taxonomy-only tips polluting downstream analyses | notes/08 |

### Dating

| Decision | Choice | Rationale | Source |
|----------|--------|-----------|--------|
| Primary method | **treePL** (Smith & O'Meara 2012) | Only method with verified record at >10k tips for fossil-calibrated dating; runs on Grace single-node | notes/04 |
| Cross-check | **RelTime** (MEGA) | 60–100× faster than treePL, statistically equivalent to Bayesian per Barba-Montoya 2022; use for sensitivity tests | notes/04 |
| Calibration set | **Cai et al. 2022 (*R Soc Open Sci* 9:211771)** as the starting set, ~25 calibrations applicable at TOB scope (of 57 total in the paper) | Only fully justified calibration set per Parham 2012 best practice | notes/03 |
| Curculionoidea calibration | Use Cai's stem-not-crown reassignment of Karatau Obrieniidae | McKenna 2015 / Zhang 2018 used incorrect crown assignment | notes/03 |
| Burmese amber sensitivity | Run dating with and without ~15 Burmese amber calibrations | Ethical embargo; report sensitivity rather than ignore | notes/03 |
| Root prior | 251.9 Ma minimum / 307 Ma soft maximum on crown Coleoptera | Estimates span 252–333 Ma; report root-prior sensitivity | notes/03 |
| Uncertainty | 100 IQ-TREE bootstrap trees → 100 treePL runs (SLURM array) + calibration jackknife (drop-one fossil per run) | Captures both branch-length sampling and fossil sensitivity | notes/04 |

---

## Five-phase pipeline

**Phase 0 — Data acquisition (estimated 1 week clock)**
- Set up `$SCRATCH/tob/` on Grace mirroring SCARAB conventions
- Pull the 323 "include"-rated new NCBI assemblies via NCBI Datasets CLI (login node, has internet)
- Pull the 4 verified TSAs (transcriptomes)
- DIY-assemble *Sphaerius* sp. Arizona + cf. *minutus* on bigmem partition (~36–48h each)
- Pull 2–3 Hymenoptera anchors (e.g., *Apis mellifera* GCA_003254395, *Nasonia vitripennis*)

**Phase 1 — Backbone inference (~2–3 weeks compute)**
- BUSCO insecta_odb10 on all Tier-1+2 assemblies & transcriptomes
- Per-locus alignment + trim
- Concatenated supermatrix → IQ-TREE LG+C60+F+R with Creedy 2025 topology constraint, ufboot+SH-aLRT
- Per-locus gene trees → ASTRAL-III
- gCF/sCF concordance, BaCoCa compositional check
- Cross-validate ML vs ASTRAL; flag conflicts; resolve before locking the constraint tree for Tier 3

**Phase 2 — Tier 3 mining (~1–2 weeks)**
- ChecklistBank API pull of full Bouchard 2024 Coleoptera classification
- Build Bouchard↔NCBI synonym reconciliation table (one-time, mostly automatable but needs manual review for ~170 families)
- SuperCRUNCH per-family runs targeting standard loci
- phylotaR fallback for families with poor SuperCRUNCH yield

**Phase 3 — Per-family ML (~2 weeks compute, parallel SLURM array)**
- IQ-TREE with `-g backbone.tre` constraint, per family
- Bootstrap + concordance per family
- Apply 30% occupancy filter; route excluded taxa to Tier 4

**Phase 4 — Synthesis (~few days)**
- Graft family trees onto backbone at stem nodes
- EPA-ng placement of barcode-only Tier-4 taxa onto the composite tree (flagged in metadata)

**Phase 5 — Dating + uncertainty (~1–2 weeks compute)**
- treePL on full tree with Cai 2022 calibrations
- 100-bootstrap dated tree array on bigmem
- Calibration jackknife
- Burmese amber sensitivity test
- Final tree + 95% date intervals + per-node CIs

---

## Locked decisions (Heath, 2026-05-03)

1. **BUSCO from scratch**, not reusing SCARAB's `selected_proteins.fasta`. Run insecta_odb10 against every assembly + transcriptome from scratch.
2. **Keep all 546 new NCBI candidates** including the 176 "conditional" and the 47 "exclude". The real quality gate is BUSCO completeness, not assembly metadata. Together with the 478 SCARAB existing genomes, that's **~1,024 Coleoptera + outgroup assemblies** going into Phase 1 (plus the 4 TSAs and the 2 *Sphaerius* DIY).
3. **No McKenna outreach** about *Tetraphalerus*. Ommatidae locked to Tier-3 (Sanger markers + mitogenome only).
4. **Phase 0 + Phase 1 only first.** Get a backbone tree, inspect, then decide whether to commit to Phases 2–5.
5. **Grace working dir = `$SCRATCH/tob/`** parallel to existing `$SCRATCH/scarab/`. Keeps state clean and lets SCARAB resume cleanly later.

## Recommended immediate next step

**Execute Phase 0:** start data acquisition on Grace. ~1 week clock time, no inference, leaves a clean Tier-1+2 inventory ready for BUSCO extraction.

## Evidence base

| Note | Topic | Word count |
|------|-------|------------|
| [01](literature/notes/01_recent_coleoptera_phylogenomics.md) | Recent Coleoptera phylogenomics | 1,735 |
| [02](literature/notes/02_genbank_mining_tools.md) | GenBank mining tools | 1,514 |
| [03](literature/notes/03_coleoptera_fossil_calibrations.md) | Fossil calibrations | 1,502 |
| [04](literature/notes/04_large_scale_dating_methods.md) | Large-scale dating | 1,640 |
| [05](literature/notes/05_coleoptera_taxonomy.md) | Taxonomy authorities | 733 |
| [06](literature/notes/06_backbone_grafting_methods.md) | Backbone + grafting | 1,785 |
| [07](literature/notes/07_outgroup_strepsiptera.md) | Outgroup composition | 1,236 |
| [08](literature/notes/08_megaphylogeny_lessons.md) | Mega-phylogeny lessons | 1,868 |
| [inventory](data/ncbi_inventory_refresh_notes.md) | NCBI genome inventory refresh | 658 |
| **total** | | **12,671 words** |
