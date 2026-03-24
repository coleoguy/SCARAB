# HOWTO 1.3: Preprint Strategy & Publication Timeline

**Phase:** Phase 1 - Literature Review
**Task:** 1.3 Define Publication Strategy, Preprint Venue, and Target Journals
**Timeline:** Day 2 (afternoon/evening) - Final decisions by EOD Day 2
**Executor:** Heath Blackmon (PI), with team input

---

## OBJECTIVE

Establish a clear publication roadmap:
1. **When** to submit preprint (relative to project timeline)
2. **Where** to submit preprint (bioRxiv vs other venues)
3. **What** content goes into preprint vs full journal paper vs supplementary materials
4. **Which** target journals for peer-reviewed publication
5. **How** to manage code/data release, authorship, and embargo periods

This strategy is locked at end of Phase 1 and communicated to all team members.

**Output acceptance criteria:** One comprehensive markdown plan document (3-5 pages)

---

## INPUT

**From Tasks 1.1 & 1.2:**
- `SCARAB/results/phase1_literature/competitive_landscape.csv` (scooping threats identified)
- `SCARAB/results/phase1_literature/zoonomia_methods_summary.md` (publication timeline lesson from Zoonomia)
- `SCARAB/results/phase1_literature/lessons_learned.md` (publication strategy insights)

Use these to inform preprint timing and venue choice.

---

## OUTPUT (Exact Filename & Location)

### Output: Preprint Plan
**Path:** `SCARAB/results/phase1_literature/preprint_plan.md`

**Format:** Markdown document, 3-5 pages

**Sections to include:**

1. **Executive Summary**
   - One-paragraph overview of publication strategy
   - Why preprint-first approach?
   - When preprint target date relative to phases

2. **Preprint Venue Decision**
   - Chosen venue: bioRxiv (or other)
   - Rationale (speed, visibility, audience, overlap with target journals)
   - Alternative venues considered and rejected
   - Timeline to submission

3. **Preprint Content Scope**
   - What goes INTO the preprint
   - What is held for full journal paper
   - What is supplementary (not in main text)
   - Approximate manuscript structure and page count target

4. **Manuscript & Supplementary Materials Plan**
   - Main figures (number and content)
   - Main tables
   - Supplementary figures (number and content)
   - Supplementary tables and data files
   - Methods section structure

5. **Full Journal Paper Publication Strategy**
   - Target journals (ranked list: 1st choice, 2nd, 3rd alternative)
   - Rationale for each journal choice
   - Estimated timeline: preprint → submission → peer review → revision
   - Any special sections or research categories (e.g., "Methods" journal, "Resources" category)

6. **Code & Software Release Plan**
   - GitHub repository (public from Day 1 or embargoed until preprint?)
   - Which code/scripts are released (all, or only final "publication-ready" versions?)
   - Documentation standard (README, vignettes, examples)
   - Dependencies and version pinning (conda environment, Docker image, requirements.txt)
   - Licencing (MIT, GPL, Apache 2.0, CC0?)

7. **Data Release & Availability**
   - Alignment data availability: where (NCBI, Zenodo, project GitHub, UCSC Genome Browser)?
   - Supplementary tables: CSV/Excel files on GitHub? Zenodo?
   - Intermediate files (genome FASTA, BAM alignments): public release or on-request?
   - Data embargo period (if any) relative to preprint/publication
   - Data access statement (template for methods section)

8. **Authorship & Acknowledgments**
   - Authorship strategy (who qualifies; criteria for inclusion)
   - Order of authors (if possible, draft now; may revise)
   - Acknowledgments (funders, data providers, tool developers)
   - Statement on AI/large language model use in analysis (if applicable) — transparency

9. **Community & Preprint Platform Strategy**
   - Will we announce preprint on Twitter/social media? (coordinate with Lab)
   - Engagement with community (expect questions, corrections, collaborations?)
   - Preprint life (expect multiple revisions before journal submission?)
   - Links back to GitHub and data repositories in preprint

10. **Contingency & Scooping Risk Mitigation**
    - What if similar study published before our preprint?
    - What if peer review is slow (delays > 3 months)?
    - What if we decide to split into 2 papers (results + methods)?
    - Fallback journals and timeline adjustments

---

## PREPRINT VENUE: COMPARISON & RATIONALE

### Option 1: bioRxiv (Recommended)

**Venue:** https://www.biorxiv.org/
**Run by:** Cold Spring Harbor Laboratory
**Timeline to posting:** ~24 hours after submission

**Pros:**
- **Audience:** Widely read in evolutionary and comparative genomics community
- **Speed:** Posted within 24 hours (vs Zenodo ~5 min, but less visible; vs journal submission months)
- **Prestige:** Preprints here are taken seriously by journals (many journals already indexed)
- **Data:** Citable (gets DOI, version tracking)
- **Integration:** Easy to cross-post to Twitter, Mastodon, lab website
- **Zoonomia precedent:** Zoonomia preprint was on bioRxiv; follow their model

**Cons:**
- Moderation queue (24 hours) may feel slow in fast-moving field
- Limited formatting (no embedded videos, interactive figures)
- Not automatically sent to PubMed (but indexed within days)

**Best for:** Primary research results (genome alignments, synteny atlas, rearrangement analysis)

---

### Option 2: Zenodo (Backup/Supplementary)

**Venue:** https://zenodo.org/
**Run by:** CERN (open-access research repository)
**Timeline to posting:** ~5 minutes (instant)

**Pros:**
- Fastest posting (useful if we want immediate priority claim)
- Can host large datasets alongside preprint
- Citable with version tracking
- Open and agnostic to subject matter

**Cons:**
- Less discoverable by genomics community than bioRxiv
- Not moderated (can post anything, less prestige filtering)
- Harder to track citations in bibliometric systems

**Best for:** Associated data releases, supplementary materials, or backup preprint copy

---

### Option 3: arXiv (Not Recommended for Biology)

**Reason to skip:** arXiv is physics/CS/math focused; less read by biologists and less acceptance for empirical biology

---

## TIMELINE DECISION: WHEN TO SUBMIT PREPRINT

### Scenario A: Early Preprint (End of Phase 2-3, ~Day 10-14)

**Pros:**
- Establish priority immediately
- Get community feedback early
- Shorter time to eventual publication

**Cons:**
- Data may be incomplete (not all genomes aligned yet)
- Figures may be preliminary
- Higher risk of major revisions before journal submission
- Code/data may not be fully documented

**Recommended if:** HIGH scooping threat identified in Task 1.1

---

### Scenario B: Mid-Project Preprint (End of Phase 3, ~Day 14-18)

**Pros:**
- Major results solidified (alignments complete, synteny blocks detected)
- More complete dataset
- Less likely to need major revisions

**Cons:**
- Slightly longer to journal submission
- Competitors have slightly more time to catch up

**Recommended if:** MEDIUM scooping threat or balanced risk/completeness

---

### Scenario C: Late Preprint (End of Phase 4, ~Day 20-24, after rearrangement analysis)

**Pros:**
- Nearly final manuscript (only polishing for journal)
- All major analyses complete
- High confidence in results

**Cons:**
- Very late in process (close to journal submission)
- Less time for community feedback to influence work
- If competing paper published first, we've lost priority window

**Recommended if:** LOW scooping threat or very robust expected results

---

## TARGET JOURNAL SELECTION

### Tier 1 (Ideal, but long peer review)

| Journal | Impact Factor | Timeline | Scope |
|---------|---------------|----------|-------|
| **Nature** | ~50 | 3-4 months | Top genomics, synthetic, high impact |
| **Science** | ~35 | 3-4 months | Integrative, big picture |
| **Cell** | ~30+ | 3-4 months | Cutting-edge methods + results |

**Pros:** Highest prestige, fastest impact
**Cons:** Rejection rate ~90-95%, very high bar for methods rigor, stringent review

**Decision:** Submit here only if confident in results and methods; else risk 2-month delay for rejection

---

### Tier 2 (Likely acceptance, reasonable peer review)

| Journal | Impact Factor | Timeline | Scope |
|---------|---------------|----------|-------|
| **Genome Biology** | ~15-20 | 2-3 months | Computational genomics, comparative |
| **Molecular Biology & Evolution** (MBE) | ~12-15 | 2-3 months | Evolution, sequence analysis, phylogenomics |
| **Genome Research** | ~12-15 | 2-3 months | Genomics methods, data resources |
| **PLOS Biology** | ~10 | 2-3 months | Open-access, broad biology audience |

**Pros:** Rapid handling, good fit, high acceptance rate for solid work
**Cons:** Slightly lower prestige than Tier 1, but still very reputable

**Decision:** Safest tier for first submission if confident in results

---

### Tier 3 (Backup venues, open-access, rapid)

| Journal | Impact Factor | Timeline | Scope |
|---------|---------------|----------|-------|
| **BMC Genomics** | ~3-5 | 1-2 months | Genomics, open-access |
| **GigaScience** | ~5-7 | 1-2 months | Data papers, bioinformatics |
| **Evolutionary Applications** | ~4-5 | 2-3 months | Applied evolution |

**Pros:** Fast, open-access, guaranteed publication
**Cons:** Lower impact factor, smaller audience

**Decision:** Fallback if Tier 1 or 2 rejects

---

## JOURNAL RANKING DECISION FRAMEWORK

For the preprint plan, recommend:
1. **1st choice:** [Journal] because [reason specific to Coleoptera project]
2. **2nd choice:** [Journal] (fallback if 1st rejects)
3. **3rd choice:** [Journal] (final safety)

**Example reasoning:**
- *Genome Biology:* Best fit for synteny methods + comparative genomics in beetles; open-access bonus
- *MBE:* Evolutionary focus aligns with beetle phylogenomics; strong comparative methods audience
- *PLOS Biology:* If Genome Biology rejects; broader impact potential

---

## MANUSCRIPT CONTENT PLAN

### What Goes in Preprint/Main Paper

**Essential:**
- Introduction (background on Coleoptera, why comparative genomics matters)
- Genome assembly QC and selection criteria
- Phylogenetic constraint tree (with clade assignments and uncertainty discussion)
- Whole-genome alignment methods (progressiveCactus parameters, convergence)
- Synteny block detection and validation
- Comparative synteny figures (examples across clades)
- Ancestral karyotype inference (key examples)
- Rearrangement analysis (breakpoint rates, hotspots)
- Discussion of evolutionary insights

**Core figures:** 5-8 (alignment overview, synteny examples, rearrangement summary, evolutionary tree)
**Core tables:** 2-4 (genome inventory summary, alignment statistics, top synteny blocks, rearrangement rates by clade)

---

### What Goes in Supplementary Materials

**Supplementary figures:** 10-20
- Extended synteny maps per clade
- Alignment coverage plots
- BUSCO completeness benchmarks
- Tree topology alternative hypotheses

**Supplementary tables:** 5-10
- Full genome inventory (all 50+ species)
- All synteny blocks (BED format, can be large)
- Rearrangement breakpoints
- Quality control metrics per genome

**Supplementary data files:**
- Constraint tree (Newick format)
- Alignment HAL file (or link to where it's stored)
- Synteny block GFF/BED files
- Ancestral karyotype reconstructions

**Supplementary methods:**
- Detailed alignment parameter justification
- QC validation approaches
- Sensitivity analyses (e.g., what if we include lower-quality genomes?)
- Reproducibility notes (software versions, exact commands)

---

## CODE & DATA RELEASE: DETAILED PLAN

### GitHub Repository Structure

**Repo name:** `SCARAB` (or similar)
**Public from:** Day 1 (preprint submission) OR embargoed until preprint acceptance?

**Structure:**
```
SCARAB/
├── README.md                    # Overview, installation, quick start
├── LICENSE                      # MIT or CC-BY-4.0
├── CITATION.cff                 # How to cite this work
├── environment.yml              # Conda dependencies
├── Dockerfile                   # Optional: reproducible container
├── scripts/
│   ├── phase2_genome_qc.R
│   ├── phase3_alignment.sh
│   ├── phase4_synteny_detect.R
│   └── phase5_visualization.R
├── data/                        # Minimal; most in NCBI/Zenodo
│   ├── constraint_tree.nwk
│   └── README_data.md           # Where to find actual genomes
├── results/                     # Paper figures and tables
│   ├── figures/
│   ├── tables/
│   └── supplementary/
├── docs/                        # Extended documentation
│   ├── methods.md
│   └── faq.md
└── .gitignore                   # Exclude large files, confidential data
```

**What's in GitHub:**
- All analysis scripts (R, Python, shell)
- README with installation instructions
- Data manifests (CSV files listing genomes, with FTP URLs)
- Conda environment file (reproducible dependency spec)
- Final figures and tables (PNG, PDF, CSV)

**What's NOT in GitHub (too large):**
- Genome FASTA files (link to NCBI instead)
- Alignment HAL files (link to project data server)
- Large intermediate BAM files

---

### Data Release: Zenodo Archive

**Create Zenodo entry** when preprint submitted:
- Upload supplementary tables (CSV format)
- Upload supplementary figures (high-res PNG/PDF)
- Link to GitHub repo (persistent DOI)
- DOI mint automatically; cite in preprint

**Embargo:** None (release everything with preprint)

---

### NCBI Data Release

**If genomes are new:** Deposit to NCBI BioProject, Assembly database
**If using existing genomes:** Just cite BioProject IDs, link in methods

---

## AUTHORSHIP STRATEGY

**Principles:**
- All major contributors (Phase 2, 3, 4, 5 leads) are authors
- Data providers (if from external sources) acknowledged in text
- Tool developers cited in methods/acknowledgments

**Author order proposal:**
1. Heath Blackmon (PI, corresponding author)
2. [Post-doc/graduate student lead on alignments & synteny]
3. [Grad student lead on genome curation & QC]
4. [Grad student lead on rearrangement analysis]
5. [Other contributors sorted by contribution size]

*Final order decided when manuscript drafted (Phase 5), can adjust based on final contributions*

---

## AI/LARGE LANGUAGE MODEL USE STATEMENT

**If Claude AI was used for coding/writing (which it is):**

Include in acknowledgments and/or methods:

> "Analysis scripts and documentation were developed with assistance from Claude AI (Anthropic). All code was reviewed and validated by human researchers. AI use was tracked and documented per institutional policy."

**Why important:**
- Transparency with journal and community
- Meets emerging guidelines from journals (Nature, Science) on AI disclosure
- Honest accounting of research effort

---

## CONTINGENCY PLANS

### If High-Threat Competitor Publishes First

**Response:**
- Emphasize our unique contributions (specific beetle clades, novel rearrangement analysis, etc.)
- Do NOT suppress preprint; instead highlight complementary aspects
- Reframe as "building on X work, we extend to [unique focus]"
- Proceed to Tier 2 journal; focus on methods rigor rather than novelty

---

### If Peer Review Takes Longer Than Expected (> 3 months)

**Options:**
1. Submit to Tier 2 journal (faster handling)
2. Dual submit to Tier 2 while Tier 1 is in review (check journal policies)
3. Post revised preprint while journal reviews (allowed by most)

---

### If Results Change Significantly During Analysis

**Options:**
1. If early preprint (Scenario A): Post revised preprint (versioning)
2. If late preprint (Scenario C): Minor revisions OK, no new preprint version needed
3. If major reinterpretation: Discuss with coauthors before journal submission

---

## COMMUNICATION & ROLLOUT

**Who needs to know:**
- All team members (Phase 1 kickoff meeting)
- Collaborators outside TAMU (email summary)
- Funding agencies (annual report mention)

**When:**
- EOD Day 2 of Phase 1 (announce decision at team meeting)
- Weekly updates during project (preprint progress, target date locked in)

---

## ACCEPTANCE CRITERIA

Task 1.3 is complete when:

- [ ] `preprint_plan.md` is 3-5 pages, covers all 10 sections
- [ ] Preprint venue is decided with rationale
- [ ] Target journals ranked (1st, 2nd, 3rd choice) with reasoning
- [ ] Estimated timeline to preprint submission is specified (e.g., "Day 16")
- [ ] Estimated timeline to journal submission is specified (e.g., "Day 25")
- [ ] Code/data release strategy is clear (GitHub public from Day 1? Embargoed? What's in each repo?)
- [ ] Authorship strategy is drafted (names, order, criteria)
- [ ] AI use disclosure statement is drafted
- [ ] Contingency plans for scooping/slow review are documented
- [ ] File saved in exact path:
  - `SCARAB/results/phase1_literature/preprint_plan.md`

---

## PHASE 1 COMPLETE

Once this file is finalized and approved by Heath, **Phase 1 is complete**. Proceed to Phase 2 (Genome Inventory & QC).

---

*HOWTO 1.3 | Phase 1 Task 3 | SCARAB | Draft: 2026-03-21*
