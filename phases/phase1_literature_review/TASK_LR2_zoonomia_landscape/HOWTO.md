# HOWTO 1.2: Zoonomia Landscape Deep Review

**Phase:** Phase 1 - Literature Review
**Task:** 1.2 Deep Study of Zoonomia and Analogous Synteny Atlas Projects
**Timeline:** Day 2
**Executor:** Team (1-2 FTE recommended)

---

## OBJECTIVE

Conduct a thorough literature review of the original Zoonomia project and similar taxon-specific whole-genome alignment and synteny atlas efforts (birds, fish, mammals, plants). Extract methodological lessons, assess scalability, understand publication and data release strategies, and document how those lessons apply to our Coleoptera effort.

**Output acceptance criteria:** Two comprehensive markdown files synthesizing methods, timeline, and lessons learned

---

## INPUT

**From Task 1.1:** `SCARAB/results/phase1_literature/key_papers.bib`

Use the BibTeX library from Task 1.1 to guide your deep dives. Prioritize papers you marked as "foundational" or relevant to Zoonomia-like efforts.

---

## OUTPUTS (Exact Filenames & Locations)

### Output 1: Zoonomia Methods Summary
**Path:** `SCARAB/results/phase1_literature/zoonomia_methods_summary.md`

**Format:** Markdown document, 5-10 pages

**Sections to include:**

1. **Overview of Zoonomia Project**
   - What: Mammalian whole-genome alignment and synteny atlas
   - Scope: ≥100+ mammal genomes
   - Timeline: Project start → first preprint → final publication
   - Key publications and their dates
   - Consortium structure (institutions, PIs)

2. **Core Methods & Pipeline**
   - Genome assembly quality thresholds used
   - Phylogenetic tree construction and constraints
   - Alignment tool(s): progressiveCactus, other tools?
   - Synteny block definition and detection
   - Ancestral sequence inference
   - Rearrangement and breakpoint analysis

3. **Data Organization & Version Control**
   - How genomes were curated and stored
   - Reference genome choice (rationale)
   - Data repository structure
   - Version numbering scheme
   - Update frequency and cycles

4. **Computational Requirements**
   - Approximate runtime for alignment step (wall clock + CPU time)
   - Storage footprint for alignments and intermediate files
   - Hardware used (cores, RAM, high-performance clusters)
   - Bottlenecks and optimization strategies

5. **Publication & Preprint Strategy**
   - Preprint announcement and date
   - Journal submission (which journal, timeline)
   - Data embargo period (if any) before/after publication
   - Code release: GitHub, documentation
   - Data release: Zenodo, NCBI, project-specific servers

6. **Community Engagement**
   - Public website/portal for browsing alignments
   - Data access policies (open, registered users, restricted)
   - Workshops, tutorials, tool documentation
   - Interaction with user community (feedback loops)

---

### Output 2: Lessons Learned Summary
**Path:** `SCARAB/results/phase1_literature/lessons_learned.md`

**Format:** Markdown document, 5-8 pages

**Sections to include:**

1. **Scale & Feasibility**
   - Is ≥50 beetle genomes achievable in our 5-week timeline?
   - Comparison: Zoonomia took X months; we have Y time and resources
   - Which steps can be parallelized? Which are sequential?
   - Budget/FTE estimates for each phase

2. **Genome Assembly Requirements**
   - Quality thresholds (N50, contig count, BUSCO %, GC content)
   - What assembly level(s) should we target (chromosome, scaffold, contig)?
   - Implications for synteny detection (easier with chromosome-level?)
   - Which ~5 genomes should be "reference quality" vs "draft"?

3. **Phylogenetic Constraint & Tree Topology**
   - How was Zoonomia's mammal tree built? What sources?
   - For Coleoptera: best published phylogeny sources (e.g., Crowson, recent phylogenomics papers)
   - How strict to make topology constraints (fixed vs soft)
   - Impact of tree uncertainty on downstream analyses

4. **Alignment & Synteny Methods**
   - progressiveCactus: why use it? alternatives? (eg., MultiZ, LASTZ+GAP, HAL tools)
   - Whole-genome alignment vs pairwise: tradeoffs
   - Synteny block definition: length threshold, gap tolerance
   - Handling of repeats and low-complexity regions
   - Quality control / alignment validation approaches

5. **Reference Genome Strategy**
   - Zoonomia used human as reference; what should be our reference beetle?
   - Options: well-assembled major clade representative, most basal species, largest genome
   - Impact on downstream analysis and interpretation

6. **Ancestral Genome Inference**
   - What methods used in Zoonomia? (e.g., ANGES, RACA, inference from breakpoint graphs)
   - Assumptions and limitations
   - Output format (hypothetical ancestral karyotype, breakpoint lists, etc.)

7. **Timeline & Project Management**
   - Critical path analysis: which steps cannot be parallelized?
   - Zoonomia's timeline breakdown: genome assembly, QC, alignment, synteny, rearrangement, manuscript
   - Our 5-week compressed timeline: what gets sacrificed, what is core?
   - Staffing needs per phase

8. **Publication & Preprint Strategy (Extracted)**
   - Zoonomia preprint → peer review → revision timeline
   - What content went into preprint vs supplementary/follow-up papers
   - Coauthor and acknowledgment best practices
   - Data availability statements and repository choices

9. **Code, Tools & Reproducibility**
   - Were analysis scripts released? On GitHub?
   - How documented (README, vignettes, example commands)?
   - Dependencies and software versions clearly specified?
   - Containerization (Docker, Singularity) used?
   - Lessons for our own codebase and documentation

10. **Data Release & Community Resources**
    - How long was embargo (if any) before publication?
    - Data hosted where? (NCBI, Zenodo, project server, consortium FTP)
    - Portal for browsing/querying (e.g., UCSC Genome Browser, custom web app)
    - Format for public release (alignment HAL, synteny tables, etc.)
    - User support and feedback channels

11. **Challenges & Pitfalls (What Went Wrong?)**
    - Any published postmortems, errata, or version updates?
    - Assembly quality issues discovered post-publication?
    - Tree topology revisions?
    - Computational bottlenecks that slowed progress?
    - Authorship/acknowledgment disputes?

12. **Comparative Lessons from Other Synteny Atlases**
    - **Avian Phylogenomics (birds):** similar scale, relevant methods?
    - **Fish projects (eg., Ensembl plant genomes):** lessons on plant genomes?
    - **Plant synteny (eg., PLAZA, CoGe):** different scale but useful methods?
    - What worked? What would you do differently?

---

## PAPER PRIORITIES FOR DEEP READING

Prioritize reading in this order:

1. **Primary Zoonomia papers** (must-read)
   - Zoonomia Consortium main results paper (Nature, ~2024)
   - Zoonomia methods paper (if separate; often in supplementary)
   - Zoonomia data paper or resource announcement

2. **Methods papers** (skim or targeted reading)
   - progressiveCactus paper (if different from Zoonomia citation)
   - Any synteny detection tool papers (LASTZ, HAL tools, Cactus)
   - Ancestral genome inference papers

3. **Comparative genomics reviews** (skim, extract lessons)
   - Recent reviews on comparative genomics workflows
   - "Best practices" papers for multi-genome alignment
   - Genome assembly quality standards papers

4. **Other taxon-specific atlases** (compare & contrast)
   - Bird genome paper(s) from prior Zoonomia or related efforts
   - Fish synteny projects
   - Plant genome synteny resources

---

## DETAILED READING PROTOCOL

For each paper, document in a note or spreadsheet:

| Field | Example |
|-------|---------|
| **Paper title** | "Comparative genomics across the whole mammalian tree of life" |
| **Authors/Year** | Zoonomia Consortium, 2024 |
| **Key methods** | progressiveCactus alignment, synteny blocks, ancestral inference |
| **Sample size** | 100+ mammal genomes |
| **Timeline** | 5 years from consortium start to publication |
| **Relevant to beetles?** | HIGH/MEDIUM/LOW |
| **Key figure/table** | "Fig 3: genome-wide alignment statistics" |
| **Quote/takeaway** | "Quality control at genome assembly stage critical to downstream success" |

---

## WRITING GUIDELINES FOR OUTPUT FILES

Both output markdown files should be:

- **Concrete and specific:** Use actual numbers, timelines, names of tools
- **Well-sourced:** Cite papers and sections (e.g., "Zoonomia Methods, Supplementary Fig 4")
- **Action-oriented:** End each major section with "Implication for Coleoptera effort:"
- **Comparative:** Always tie back to our beetles: "Zoonomia had 100+ genomes; we target 50+ beetles, so..."
- **Critical but fair:** Note where prior efforts succeeded and struggled

---

## EXAMPLE STRUCTURE (Section 1: Zoonomia Overview)

```markdown
## 1. Overview of Zoonomia Project

### What is Zoonomia?
Zoonomia is a large-scale whole-genome alignment and synteny atlas of [100+] mammalian species,
published in Nature [year]. The project aimed to [core goals]:
- Infer synteny blocks and rearrangements across Mammalia
- Identify conserved and rapidly evolving genomic regions
- Reconstruct ancestral mammalian karyotypes

**Key facts:**
- Start date: [X]
- First preprint: [date]
- Published: [journal, date]
- Total genomes: [N]
- Data released on: [platforms]

**Lead institutions:** [list]

### Why Zoonomia Matters for Our Project
Zoonomia is directly relevant because [explain method/scale/scope parallels].
We are adapting [specific aspect] for beetles.

### Key Publications
[Properly cited list with DOIs]
```

---

## WORKFLOW STEPS

1. **Set up literature system**
   - Import `key_papers.bib` into Zotero, Mendeley, or Papers
   - Create tags: "zoonomia", "methods", "birds", "fish", "plants", "pipeline"
   - Sort by relevance to our task

2. **Read and annotate**
   - Assign 2-3 team members to different topics (Zoonomia methods, tree biology, comparative projects)
   - Each person reads 3-5 papers deeply
   - Write notes using the template above

3. **Synthesize**
   - Consolidate individual notes into two cohesive documents
   - Ensure no contradictions across sections
   - Add comparative commentary where relevant (e.g., "unlike Zoonomia, we...")

4. **Cross-check**
   - Verify all citations are correct and traceable
   - Ensure timelines are consistent across mentions
   - Check that implications for beetles are clear

5. **Review and refine**
   - Heath (PI) reviews both documents for accuracy and completeness
   - Team discussion: any surprises or insights?
   - Finalize and save in exact paths

---

## ACCEPTANCE CRITERIA

Task 1.2 is complete when:

- [ ] `zoonomia_methods_summary.md` is 5-10 pages, covers all 6 core sections
- [ ] `lessons_learned.md` is 5-8 pages, covers all 12 sections
- [ ] All major papers cited with correct DOIs or PMIDs
- [ ] Every major section has an "Implication for Coleoptera" paragraph
- [ ] No factual errors (timeline, methods, numbers cross-checked with primary sources)
- [ ] Both documents are readable by non-expert (clear explanations, minimal jargon)
- [ ] Files saved in exact paths:
  - `SCARAB/results/phase1_literature/zoonomia_methods_summary.md`
  - `SCARAB/results/phase1_literature/lessons_learned.md`

---

## NEXT STEP

Once Task 1.2 is complete, proceed to **HOWTO_03_preprint_strategy.md** (Task 1.3).

---

*HOWTO 1.2 | Phase 1 Task 2 | SCARAB | Draft: 2026-03-21*
