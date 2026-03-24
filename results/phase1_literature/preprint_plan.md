# LR.3: Preprint & Publication Strategy — SCARAB

**Date:** 2026-03-21 | **Author:** Claude (AI) | **Review:** Pending Heath
**Status:** DRAFT — awaiting PI approval

---

## 1. Executive Summary

SCARAB will follow a **preprint-first strategy** via bioRxiv, targeting submission once Phase 4 (rearrangement analysis) is complete (~Day 30). This balances priority establishment against data completeness. Scooping risk is LOW-MEDIUM (no competing beetle synteny atlas visible, but Bracewell group could scale up). The primary journal target is **Nature Ecology & Evolution**, which published the directly analogous Lepidoptera atlas (Wright et al. 2024). The preprint establishes priority while we prepare the full submission.

---

## 2. Preprint Venue

**Decision: bioRxiv**

Rationale: bioRxiv is the standard venue for comparative genomics preprints (Zoonomia used it, Wright et al. used it). Posted within 24 hours, gets DOI, indexed rapidly. The evolutionary biology and genomics community monitors bioRxiv routinely.

Zenodo will be used as a supplementary data archive (alignment HAL files, synteny blocks, ancestral reconstructions) — these are too large for bioRxiv supplementary materials.

---

## 3. Preprint Timing

**Decision: Scenario C (Late preprint) — End of Phase 4, ~Day 30**

Rationale: Scooping risk is LOW-MEDIUM. No one else has 400+ beetle genomes aligned. Bracewell et al. (2024) defined Stevens elements from 12 genomes but their focus is sex chromosomes, not a full rearrangement atlas. We gain more from submitting a near-complete manuscript than from rushing an incomplete preprint. The preprint will contain all major results so journal submission follows within 1-2 weeks.

Timeline:
- **Day 30**: Preprint submitted to bioRxiv
- **Day 35**: Full manuscript submitted to Nature Ecology & Evolution
- **Day 35**: GitHub repo made public, Zenodo archive minted

---

## 4. Preprint Content Scope

**In the preprint (= main manuscript):**
- Genome inventory and selection criteria (439 genomes, 61 Coleoptera families + 3 Neuropterida orders)
- Calibrated phylogeny (439-tip tree, 29 fossil calibration points)
- Whole-genome alignment via ProgressiveCactus (HAL format)
- Stevens element validation and extension (from 12 → 439 genomes)
- Ancestral karyotype reconstructions at 25+ internal nodes
- Branch-specific rearrangement rates (fusions, fissions, inversions)
- Rearrangement hotspot identification
- Cross-validation with Blackmon lab cytogenetic database (~4,700 beetle species)

**Held for supplementary materials:**
- Extended synteny maps per clade
- Per-genome QC details (assembly stats, BUSCO)
- Sensitivity analyses (quality thresholds, reference bias)
- Full rearrangement breakpoint tables
- Alternative tree topologies tested

---

## 5. Manuscript Structure & Figure Plan

### Main Figures (6)

1. **Fig 1: Phylogeny with rearrangement rates.** Time-calibrated 439-tip tree, branches colored by rearrangement rate. Side panel showing chromosome number variation from cytogenetic database. (cf. Damas et al. 2022 Fig 3)

2. **Fig 2: Stevens element conservation heatmap.** Rows = Stevens elements (9+), columns = families. Cell color = conservation level. Shows which elements are universally conserved vs. lineage-specific instability. (Novel figure)

3. **Fig 3: Ancestral karyotype reconstructions.** Key nodes: MRCA Coleoptera, MRCA Polyphaga, MRCA Adephaga, major infraorders. Painted chromosomes showing element composition. (cf. Damas et al. 2022 Fig 2)

4. **Fig 4: Rearrangement rate heterogeneity.** Panel A: rate distribution across branches. Panel B: rate vs. species diversity per clade. Panel C: rate vs. karyotype diversity (Blackmon lab data). (Novel — no other study has this cross-validation)

5. **Fig 5: Representative synteny dotplots.** 3-4 species pairs spanning different divergence times and rearrangement histories. Annotated with breakpoints and Stevens elements. (cf. Wright et al. 2024 extended data)

6. **Fig 6: Comparison to Lepidoptera.** Stevens elements vs. Merian elements. Rearrangement rates in beetles vs. Lepidoptera vs. mammals. Fusion bias analysis (shorter chromosomes?).

### Main Tables (3)

1. **Table 1:** Genome inventory summary — species counts by suborder/family, assembly quality, chromosome-level counts
2. **Table 2:** Stevens element properties — size, gene content, conservation across families
3. **Table 3:** Rearrangement rates by clade — fusions, fissions, inversions per My per lineage

### Supplementary Figures: 10-15
### Supplementary Tables: 5-8
### Supplementary Data: alignment HAL, synteny BED, rearrangement calls, ancestral karyotypes (via Zenodo)

---

## 6. Target Journals (Ranked)

### 1st Choice: Nature Ecology & Evolution
- **Rationale:** Wright et al. (2024) Lepidoptera atlas published here. Our beetle project is the direct Coleoptera equivalent. Same scope (hundreds of genomes, ancestral linkage groups, rearrangement mapping). Editor familiarity with this type of study. IF ~16.
- **Expected timeline:** 3-4 months peer review, 1-2 months revision
- **Risk:** Rejection rate ~80%. Need a clear narrative beyond "we did it in beetles too."
- **Our edge:** Cross-validation with 4,700-species karyotype database is genuinely novel. No other comparative genomics atlas has an independent cytogenetic dataset for validation.

### 2nd Choice: Molecular Biology and Evolution (MBE)
- **Rationale:** Core audience for evolutionary genomics. IF ~10. Faster review (~2-3 months). Strong history of publishing large-scale comparative genomics. Less prestige than NEE but higher acceptance rate for solid work.
- **When to go here:** If NEE rejects, or if we decide the novelty bar is better met at MBE.

### 3rd Choice: Genome Research
- **Rationale:** Resource-focused journal. Excellent for data-heavy papers. Good if reviewers want us to emphasize the resource (alignment, database) over biological interpretation.
- **When to go here:** If both NEE and MBE reject, or if we split into a methods/resource paper.

### Alternative: Current Biology
- **When to go here:** If we find an unexpectedly striking result (e.g., a universal rearrangement hotspot, or karyotype evolution linked to species diversification). Current Biology loves surprising findings.

---

## 7. Code & Data Release Plan

### GitHub Repository
- **Name:** `SCARAB` (public from preprint submission day)
- **License:** MIT (code) + CC-BY-4.0 (data/figures)
- **Contents:** All analysis scripts (R, Python, bash/SLURM), constraint tree, genome catalog, figure-generating code, conda environment.yml
- **NOT in GitHub:** Genome FASTAs (link to NCBI), HAL alignment (link to Zenodo), large intermediate files

### Zenodo Archive
- Created at preprint submission
- Contains: supplementary tables (CSV), supplementary figures (PDF), alignment HAL file, synteny blocks, ancestral karyotype reconstructions
- Gets DOI, cited in manuscript

### NCBI
- All genomes already in NCBI (we used existing assemblies)
- Data availability statement references accession list in Table S1

---

## 8. Authorship Strategy

**Proposed author list (draft — adjust based on contributions):**
1. Heath Blackmon (PI, corresponding author, project conception, biological interpretation, cytogenetic validation)
2. [Student/postdoc lead on genome curation & alignment — TBD]
3. [Student lead on rearrangement analysis — TBD]
4. [Additional contributors as warranted]

**AI disclosure:** "Analysis scripts and project documentation were developed with assistance from Claude AI (Anthropic, 2026). All AI-generated code was reviewed and validated by human researchers prior to execution. AI contributions are logged in the project repository (ai_use_log.md)."

**Authorship criteria:** CRediT taxonomy. All authors must contribute to at least two of: conceptualization, methodology, software, formal analysis, data curation, writing, visualization.

---

## 9. Community & Communication Strategy

**At preprint posting:**
- Announce on Twitter/X, Bluesky, Mastodon (coordinate with Blackmon Lab accounts)
- Email key colleagues: Bracewell, Wright, Bachtrog (professional courtesy — we cite their work extensively)
- Post to EvolDir mailing list
- Share on TAMU Biology department channels

**Engagement:**
- Expect questions about Stevens element validation, ancestral karyotype confidence
- Be prepared to share additional synteny views for specific lineages on request
- Invite community to use the data (that's the point of the resource)

---

## 10. Contingency Plans

### If Bracewell group publishes a scaled-up Stevens element paper first:
- Our project is still valuable — we have different focus (full rearrangement atlas, ancestral reconstruction, rate heterogeneity, cytogenetic validation)
- Reframe: "Building on Bracewell et al., who established Stevens elements with 12 genomes and later extended to N genomes, we present the first comprehensive rearrangement atlas..."
- Drop to MBE as primary target (novelty bar lower there)

### If peer review exceeds 4 months:
- Post revised preprint incorporating any new analyses done during review
- Consider withdrawing and resubmitting to MBE if NEE review drags beyond 6 months

### If alignment fails for some genomes:
- Report results for whatever subset succeeds (even 300+ genomes is far beyond Bracewell's 12)
- Document failures transparently in supplement
- This is unlikely given 439 genomes already downloaded and validated

### If we find a surprising result:
- Consider pivoting to Current Biology (likes surprising findings)
- Or keep at NEE but lead with the surprise in abstract/title

---

## Timeline Summary

| Milestone | Target Date | Notes |
|-----------|------------|-------|
| Phase 3 alignment begins | 2026-03-21 | In progress (Cactus setup on Grace) |
| Phase 3 alignment complete | ~2026-04-11 | 7-21 days wall-clock |
| Phase 4 rearrangement analysis | ~2026-04-18 | 7 days |
| Preprint draft complete | ~2026-04-25 | 7 days writing |
| bioRxiv submission | ~2026-04-27 | Day ~37 |
| GitHub + Zenodo public | ~2026-04-27 | Same day as preprint |
| NEE submission | ~2026-05-04 | 1 week after preprint |
| Expected NEE decision | ~2026-08-04 | 3 months |
| Revised manuscript | ~2026-09-04 | 1 month revision |
| Publication | ~2026-10-04 | Optimistic |

---

**Decision required from Heath:**
1. Confirm journal ranking (NEE → MBE → Genome Research)
2. Confirm preprint timing (Day ~30 vs. earlier)
3. Draft authorship list (who else is contributing?)
4. GitHub repo: create now or at preprint?

---

*LR.3 Preprint Strategy | SCARAB | Draft: 2026-03-21*
