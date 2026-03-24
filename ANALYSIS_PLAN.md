# SCARAB: Detailed Analysis Plan

## Scientific Rationale

### Why Coleoptera? Why Now?

**Coleoptera (beetles) represent the most species-rich order of eukaryotes**, accounting for ~25% of all described animal species (~400,000 species). Despite this incredible diversity, the role of **chromosomal rearrangements in beetle speciation and diversification** remains poorly understood at the genomic scale. This project addresses a critical gap:

1. **No systematic whole-genome synteny atlas exists for Coleoptera**. While whole-genome alignments have been performed for primates (Zoonomia), mammals (Ensembl), and some insects (e.g., *Drosophila*), beetles—the hyperdiverse order—lack a coordinated, large-scale comparative genomics resource.

2. **Chromosome evolution is a major driver of speciation** (Faria & Navarro, 2010; Hoffmann & Rieseberg, 2008). Chromosomal rearrangements (fusions, fissions, inversions) create reproductive isolation through reduced fertility in heterozygous hybrids. In beetles, which exhibit extraordinary karyotypic diversity (2n ranging from 2 to 200+), the relationship between chromosomal changes and speciation rates is unexplored.

3. **Ancestral karyotype reconstruction is technically feasible but underutilized**. Methods like RACA and InferCARs can infer ancestral chromosome segments from modern genomes, enabling us to map rearrangement events onto the beetle phylogeny and identify periods of elevated chromosomal change.

4. **Preprint-first comparative genomics is now standard**. The Zoonomia Consortium's success (https://www.nature.com/articles/s41586-021-03794-8, 2021) established the value of rapid, open-access genome comparisons. We follow this model but focus on a single order, enabling deeper evolutionary inference.

### Unique Scientific Contribution

This project will deliver:
- **The first beetle-specific chromosomal rearrangement atlas**, annotated on a phylogenetic scaffold
- **Reconstructed ancestral karyotypes** at key beetle diversification nodes
- **Quantitative rates of chromosomal evolution** per beetle lineage, enabling comparative analysis
- **Identification of rearrangement hotspots** (genomic regions prone to repeated reorganization)
- **A publicly accessible resource** for beetle genomics and insect chromosome evolution research

---

## Analytical Approach: Step-by-Step

### Step 1: Genome Collection & Curation (Phase 2)

**Goal**: Assemble a high-quality, phylogenetically representative dataset of beetle genomes (current inventory: 438 genomes across 61 Coleoptera families + Neuropterida outgroups).

**Method**:
1. Mine **NCBI RefSeq, GenBank, and Ensembl Genomes** for beetle genomes (Coleoptera)
2. For each candidate genome, collect:
   - Assembly accession (GCF/GCA ID)
   - Assembly quality metrics: **N50, L50, number of contigs/scaffolds**
   - **BUSCO completeness score** (Simão et al., 2015) — target ≥90% single-copy orthologs
   - Sequencing technology (long-read, short-read, hybrid)
   - Repeat content (via `repeatmasker` or assembly report)
   - Chromosome count (2n) if available

3. **Phylogenetic sampling**: Select genomes to maximize representation across major beetle clades:
   - Adephaga (ground beetles, water beetles)
   - Archostemata
   - Myxophaga
   - Polyphaga (weevils, bark beetles, ladybugs, click beetles, etc.)

4. **Quality thresholds**:
   - Minimum N50: 100 kbp (prefer >1 Mbp)
   - Minimum BUSCO: 85% (prefer >90%)
   - Exclude: Heavily fragmented assemblies, suspicious repeat content (>80% masked)

5. **Output**: Curated genome table (CSV/TSV) with metadata, phylogenetic species tree (Newick format, constraint tree based on recent beetle systematics).

**Expected Output**:
- `data/genomes/`: 438 FASTA files, indexed (downloading to Grace `$SCRATCH/scarab/genomes/`)
- `data/karyotypes/metadata.csv`: Genome inventory with QC scores
- `results/phase2_genome_inventory/qc_report.txt`: Per-genome summary
- `results/phase2_genome_inventory/species_tree.nwk`: Constraint phylogeny (Newick)

**Feeds Into**: Step 1.5 (tree calibration), then Phase 3 (alignment)

---

### Step 1.5: Constraint Tree Calibration

**Goal**: Assign approximate divergence-time branch lengths to the constraint tree so Cactus can tune alignment sensitivity appropriately across the 5–320 Ma divergence range in our dataset.

**Method**: Node ages assigned from published molecular clock estimates, with interpolation for uncalibrated nodes.

**Primary calibration sources**:
- **McKenna et al. (2019)** *Systematic Entomology* 44:939–966 — Coleoptera crown (268 Ma), suborder/series divergences, family crown ages
- **Zhang et al. (2018)** *Current Biology* 28:R1167–R1172 — Coleoptera–Neuropterida split (320 Ma)
- **Hunt et al. (2007)** *Science* 318:1913–1916 — Suborder and family-level calibrations
- **Misof et al. (2014)** *Science* 346:763–767 — Deep insect divergence times

**Calibration points**: 29 MRCA nodes calibrated (root, Coleoptera crown, 5 series/suborder crowns, 22 family crowns). Uncalibrated internal nodes interpolated at the midpoint between parent and oldest calibrated descendant. Minimum branch length: 0.1 Ma. Resulting tree is ultrametric (all root-to-tip paths = 320 Ma).

**Scripts**: `scripts/phase2/calibrate_tree.py` (production), `scripts/phase2/calibrate_tree.R` (R equivalent)

**Output**: `data/genomes/constraint_tree_calibrated.nwk`

**Documentation**: `data/genomes/TREE_CALIBRATION_NOTES.md` (full table of calibration points with sources)

**Caveat**: These branch lengths are approximate and used solely to parameterize the alignment. Rearrangement rate analyses (Phase 4) will use branch lengths estimated from alignment data.

**Feeds Into**: Phase 3 (ProgressiveCactus seqFile uses calibrated tree)

---

### Step 2: Whole-Genome Alignment (Phase 3)

**Goal**: Construct a multiple whole-genome alignment (WGA) spanning 438 beetle and outgroup genomes, enabling synteny inference across the phylogeny.

**Method: ProgressiveCactus**

**Why ProgressiveCactus?**
- Proven in Zoonomia and other large-scale projects
- Handles hundreds of species without exponential scaling
- Outputs a HAL (Hierarchical Alignment Format) for efficient querying
- Scalable to long read assemblies and large genomes

**Workflow**:
1. **Prepare reference genome**: Choose a well-assembled, central beetle species (candidate: *Tribolium castaneum*, a model beetle with ~168 Mbp haploid genome)

2. **Build species tree**: Use curated constraint tree from Phase 2, with branch lengths estimated from sequence divergence

3. **ProgressiveCactus alignment**:
   ```
   cactus runCactusWorkflow \
     --halFile alignment.hal \
     --seqFile seqs.txt \
     --speciesTree tree.nwk
   ```
   - Input: reference genome + ≥49 query genomes (FASTA)
   - Process: Iterative pairwise alignment, progressive merging up the tree
   - Output: Single HAL file encoding multi-way alignment

4. **Validation**:
   - Check alignment coverage per species (target: >80% of each genome aligned)
   - Identify suspicious self-alignments (potential assembly artifacts)
   - Verify breakpoint density (should correlate with phylogenetic distance)

**Expected Output**:
- `data/alignments/alignment.hal`: HAL multi-way alignment file (~50–200 GB, depending on genomes)
- `results/phase3_alignment_synteny/alignment_qc.txt`: Coverage, self-alignment stats
- `results/phase3_alignment_synteny/per_species_coverage.csv`: Genome-by-genome alignment rates

**Feeds Into**: Phase 3 (synteny extraction), Phase 4 (rearrangement calling)

**Computational Resources**: ~160,000–430,000 core-hours on TAMU Grace cluster (revised estimate for 438 genomes, 2026-03-21); subtree decomposition reduces walltime to ~24–36 hours. Allocate 200,000 SUs.

---

### Step 3: Synteny Extraction & Block Definition (Phase 3)

**Goal**: Extract synteny blocks (collinear segments) from the multi-way alignment, defining conserved chromosome segments across beetle species.

**Method: halSynteny + Custom Post-Processing**

**Workflow**:
1. **Extract pairwise synteny**: For each species pair, use `halSynteny` to identify synteny blocks:
   ```
   halSynteny --alignmentFile alignment.hal \
     --queryGenome species1 --targetGenome species2 \
     --outPSL species1_species2.psl
   ```
   - Minimum block length: 10 kbp (to avoid spurious small blocks)
   - Minblocks filter to consolidate fragmented alignment

2. **Call multi-way synteny blocks**:
   - Define a "consensus block" as a segment conserved in ≥N species (e.g., N=3 or N=5)
   - Merge overlapping consensus blocks across all species
   - Assign unique block IDs and record: block_id, span (bp), species composition, breakpoints

3. **Synteny graph construction**:
   - Nodes = synteny blocks
   - Edges = adjacency (consecutive blocks on the same chromosome/contig)
   - Label edges with: species in which adjacency is observed

4. **QC**:
   - Plot block length distribution (expect power-law tail; outliers may be artifacts)
   - Check for unexpected large blocks (>50 Mbp may indicate missing breakpoints)
   - Validate blocks against known karyotypes (if available for reference species)

**Expected Output**:
- `data/synteny/pairwise_synteny/`: PSL files for all species pairs
- `data/synteny/multi_way_synteny/`: Block definitions (GFF3 or BED format)
- `data/synteny/synteny_blocks.csv`: Block inventory (id, length, species_composition)
- `results/phase3_alignment_synteny/block_stats.txt`: Summary (# blocks, length distribution, etc.)

**Feeds Into**: Phase 4 (rearrangement calling, ancestral reconstruction)

---

### Step 4: Rearrangement Calling & Annotation (Phase 4)

**Goal**: Identify and classify chromosomal rearrangements (fusions, fissions, inversions) by comparing synteny block order across the beetle phylogeny.

**Method: Phylogenetic Reconstruction of Rearrangements**

**Workflow**:
1. **Define rearrangement types**:
   - **Fusion**: Two adjacent blocks in an ancestral genome are merged into one chromosome in a descendant
   - **Fission**: One block in an ancestral genome is split across two chromosomes in a descendant
   - **Inversion**: A block is present in both ancestral and descendant but in reverse orientation
   - **Translocation**: A block moves to a different chromosome (complex; may defer to secondary analysis)

2. **Rearrangement inference**:
   - For each internal node in the phylogeny, infer the ancestral synteny order (using methods below, Step 5)
   - Compare ancestral order to descendant order along each branch
   - Record: rearrangement type, affected species, breakpoints (±10 kbp resolution), block IDs involved

3. **Phylogenetic mapping**:
   - Map each rearrangement to its origin branch (the first branch where the rearrangement arose)
   - Parsimonious method: Choose the branch minimizing total rearrangement count across the tree

4. **Annotation**:
   - Per-branch rearrangement counts: # fusions, # fissions, # inversions
   - Per-genomic-region rearrangement density: count rearrangements per Mbp in sliding windows
   - Per-clade statistics: rearrangement rates, relative to branch length

**Expected Output**:
- `data/ancestral/rearrangements.csv`: Rearrangement calls (type, branch, affected_blocks, breakpoints)
- `results/phase4_rearrangements/per_branch_stats.csv`: Counts per branch
- `results/phase4_rearrangements/rearrangement_map.txt`: Phylogeny with rearrangement annotations
- `results/phase4_rearrangements/hotspots.csv`: Genomic regions with elevated rearrangement density

**Feeds Into**: Phase 4 (ancestral reconstruction), Phase 5 (visualization)

---

### Step 5: Ancestral Karyotype Reconstruction (Phase 4)

**Goal**: Reconstruct the chromosome composition and gene order in ancestral beetle genomes at key phylogenetic nodes.

**Method: RACA (Reconstruct Ancestral Chromosomes with Annotations) / InferCARs**

**Rationale**:
- Ancestral reconstructions enable us to map rearrangement events onto branches
- Provide evolutionary context for extant beetle chromosome diversity
- Can infer plausible ancestral karyotypes at the base of major beetle clades

**Workflow**:
1. **Prepare input for RACA/InferCARs**:
   - Synteny blocks as "segments" (define blocks from Step 3)
   - Species phylogenetic tree (with branch lengths)
   - Species-to-block adjacency matrix (which species have which blocks in which order)

2. **Run RACA**:
   ```
   RACA.py -i segments.txt -t tree.nwk -o ancestral_genomes/
   ```
   - Output: Reconstructed ancestral chromosome orders for each internal node
   - Confidence scores for each adjacency (based on parsimony)

3. **Validate reconstructions**:
   - Check confidence scores (aim for >80% of adjacencies at high confidence)
   - Compare ancestral karyotypes to modern karyotypes (should show gradual transformation)
   - Flag uncertain or ambiguous regions (low confidence may indicate alignment errors or genuine ambiguity)

4. **Ancestral karyotype summary**:
   - For each internal node, report: # predicted chromosomes, # synteny blocks, key rearrangements relative to parent node
   - Create visual summary (phylogeny colored by predicted chromosome count)

**Expected Output**:
- `data/ancestral/ancestral_genomes/`: Per-node ancestral chromosome orders (text format)
- `data/ancestral/ancestral_karyotypes.csv`: Summary (node_id, predicted_2n, # blocks, confidence)
- `results/phase4_rearrangements/ancestral_summary.txt`: Narrative summary of key ancestral states

**Feeds Into**: Phase 5 (visualization, manuscript figures)

---

### Step 6: Statistical Quantification of Rearrangement Rates (Phase 4)

**Goal**: Quantify rearrangement frequencies and identify hotspots with statistical rigor.

**Method: Phylogenetic Comparative Methods (R: ape, phytools)**

**Workflow**:
1. **Branch-level rearrangement rates**:
   - For each branch, calculate:
     - Raw count of rearrangements (from Step 4)
     - **Normalized rate**: count / (branch length in Mya, or expected substitutions per site)
     - 95% confidence intervals (via bootstrap or Poisson uncertainty)
   - Output: Per-branch rate table

2. **Hotspot identification**:
   - Genome-wide rearrangement density: rearrangements per Mbp
   - Calculate mean (μ) and standard deviation (σ) across all sliding windows (window size: 1 Mbp, step: 0.5 Mbp)
   - Define hotspots as windows with density > μ + 2σ
   - Report: hotspot locations, species in which they're active, mechanism (fusions, inversions, etc.)

3. **Phylogenetic signal**:
   - Test for phylogenetic autocorrelation in rearrangement rates (Pagel's λ, phylogenetic ANOVA)
   - Are rearrangement rates clustered by clade or distributed randomly?

4. **Association with speciation**:
   - Correlate rearrangement density with speciation rates (using node ages from phylogeny)
   - Exploratory: Are clades with high rearrangement rates more speciose?

**Expected Output**:
- `results/phase4_rearrangements/per_branch_rates.csv`: Branch ID, count, rate, 95% CI
- `results/phase4_rearrangements/hotspots.csv`: Genomic location, density, significance
- `results/phase4_rearrangements/statistical_summary.txt`: Phylogenetic signal, correlation analysis

**Feeds Into**: Phase 5 (manuscript Results section)

---

## Statistical Framework in Detail

### Rearrangement Rate Calculation

**Normalized Rate** = (Rearrangement Count) / (Branch Length)

**Branch Length** can be measured as:
1. **Evolutionary time** (Mya): Uses fossil calibrations or molecular clock estimates
2. **Expected substitutions per site** (dS): Synonymous substitution rate, less affected by selection
3. **Number of DNA changes** (e.g., SNPs + indels normalized by genome size)

**Choice**: Use evolutionary time (Mya) for primary analysis, with dS-normalized rates in sensitivity analysis.

**Confidence Intervals**:
- Poisson 95% CI: If count = k rearrangements on a branch, use Poisson distribution to get CI for rate
- Bootstrap: Resample blocks (with replacement), recount rearrangements, estimate CI empirically

### Hotspot Identification

**Method: Z-score windowing**
1. Divide the beetle reference genome into non-overlapping 1 Mbp windows
2. For each window, count total rearrangements across all species (or restrict to a clade)
3. Calculate μ = mean, σ = SD across all windows
4. **Z-score** for window i: Z_i = (count_i - μ) / σ
5. Define hotspots as windows with |Z_i| > 2 (p < 0.05 for two-tailed test)

**Validation**: Compare hotspot locations to known fragile sites, repeat elements, or genes under positive selection.

### Ancestral State Inference

**Parsimony-based reconstruction**:
- At each internal node, the ancestral state is the one that minimizes total rearrangement count across all daughter branches
- Implemented in RACA; alternative: Fitch algorithm (if binary character states are used)

**Confidence**: RACA provides per-adjacency confidence scores (% of equally-parsimonious reconstructions supporting that adjacency)

---

## Key Software & Tools

| Tool | Purpose | Citation/Link |
|------|---------|---------------|
| **ProgressiveCactus** | Multi-way genome alignment | Paten et al., 2011; GitHub: ComparativeGenomicsToolkit/cactus |
| **halTools** | HAL file manipulation, synteny extraction | Hickey et al., 2013 |
| **RACA** | Ancestral chromosome reconstruction | Ma et al., 2006; GitHub: RACA |
| **InferCARs** | Alternative ancestral reconstruction | Pauletto et al., 2012 |
| **R (ape, phytools)** | Phylogenetic comparative methods | Paradis & Schliep, 2019; Revell, 2012 |
| **BUSCO** | Genome completeness assessment | Simão et al., 2015 |
| **RepeatMasker** | Repeat element identification | Smit et al., http://www.repeatmasker.org |
| **Snakemake** | Workflow orchestration | Mölder et al., 2021 |
| **Circos** | Genome visualization | Krzywinski et al., 2009 |

---

## Computational Resources

### TAMU Grace Cluster Allocation

**Estimated Requirements**:

| Phase | Task | Core-Hours | Walltime | Notes |
|-------|------|-----------|----------|-------|
| **Phase 3** | ProgressiveCactus alignment (438 genomes, subtree decomposition) | 160,000–430,000 | 24–36 hrs walltime | 4–6 parallel subtree jobs + backbone merge |
| **Phase 3** | halSynteny extraction | 500–2,000 | 2–3 days | Scales with genome count |
| **Phase 4** | RACA ancestral reconstruction | 200–500 | 1–2 days | Low-memory; single-threaded |
| **Phase 5** | Visualization, R analyses | 10–20 | <1 day | CPU-light; I/O-bound |
| **Total** | | **~160,000–430,000** | | Dominated by Cactus alignment |

**Allocation**: 200,000 SUs on TAMU Grace (allocated 2026-03-21). May be tight for 438 genomes — monitor usage during Phase 3 and request supplemental if needed.

**Storage**:
- Input genomes: ~500 GB–1 TB (438 genomes × 100 Mbp–2 Gbp FASTA)
- HAL alignment: ~100–300 GB (depends on compression, # genomes)
- Results: ~50 GB (synteny blocks, ancestral reconstructions, figures)
- **Total**: ~500 GB–1 TB (manageable within typical allocation)

---

## AI Integration Philosophy

### Role of Claude (AI Assistant)

**Responsibilities**:
1. **Code generation**: Write Python, R, Bash scripts for data processing, analysis, and visualization
2. **Workflow development**: Generate Snakemake workflows for reproducible, parallelizable pipelines
3. **Documentation**: Annotate code, write methods, generate analysis reports
4. **Troubleshooting**: Debug errors, suggest optimizations

**Accountability**:
- **All code is human-reviewed** before execution by Heath or team members
- **Code review checklist** (see below) ensures correctness and best practices
- **All AI contributions logged** in `project_management/ai_use_log.md` with timestamps and descriptions
- **Reproducibility**: Every AI-generated script is version-controlled and can be traced back to this log

### Code Review Checklist

Before running any AI-generated code, verify:
- [ ] **Correctness**: Does the code correctly implement the intended analysis?
- [ ] **Input validation**: Does it check for valid input formats, missing files, edge cases?
- [ ] **Error handling**: Does it fail gracefully with informative error messages?
- [ ] **Efficiency**: Is the code reasonably efficient (e.g., no unnecessary loops)?
- [ ] **Documentation**: Are functions documented with docstrings? Is the script self-explanatory?
- [ ] **Testing**: Has it been tested on a small subset of real data before full-scale run?
- [ ] **Reproducibility**: Can the code be run identically on any system with required dependencies?
- [ ] **Best practices**: Does it follow Python/R/Bash best practices (PEP 8, style, comments)?

### AI Use Log Format

Each entry in `project_management/ai_use_log.md` should include:
```
**Date**: [YYYY-MM-DD]
**Phase**: [Phase #]
**Task**: [Brief description]
**Claude Contribution**: [What Claude wrote/generated]
**Output File(s)**: [Path(s) to scripts/outputs]
**Review Status**: [Reviewed by X, approved / Pending review]
**Notes**: [Any modifications, caveats, or follow-up]
```

---

## Preprint Strategy

### Why Preprint First?

1. **Establish Priority**: In fast-moving fields like comparative genomics, preprints establish intellectual priority while peer review is underway
2. **Community Feedback**: Early sharing allows feedback from the beetle genomics community, improving the final paper
3. **Risk Mitigation**: Reduces risk of being scooped; if another group publishes similar work, our preprint date proves precedence
4. **Data Release**: Positions our dataset as a communal resource; early access accelerates downstream research

### Preprint Timeline & Plan

- **Submission Target**: Day 35 (end of Phase 5), anticipated 2026-05-02
- **Venue**: bioRxiv (https://www.biorxiv.org/)
- **Content**:
  - Full Methods, Results, Discussion
  - All main figures + supplementary figures (>20 figures anticipated)
  - Supplementary tables (genome inventory, rearrangement calls, ancestral karyotypes, hotspots)
  - Data availability statement with DOI for deposited datasets

### Peer-Reviewed Submission (Post-Preprint)

- **Target Journals** (in order of preference):
  1. *Nature Ecology & Evolution* (high impact, broad readership)
  2. *Molecular Biology and Evolution* (specialist journal, faster review)
  3. *Genome Biology & Evolution* (solid alternative)

- **Timeline**: Submit peer-reviewed version within 2–4 weeks post-preprint (to minimize time between public release and formal publication)

- **Content Additions** (post-preprint feedback):
  - Revised analyses based on community comments
  - Additional figures/tables addressing reviewer concerns
  - Expanded Discussion linking rearrangement patterns to beetle speciation

---

## Expected Outputs & Deliverables

### Data & Analysis Outputs

| Phase | Output | Format | Location |
|-------|--------|--------|----------|
| 2 | Curated genome inventory | CSV | `data/karyotypes/metadata.csv` |
| 2 | Species phylogenetic tree | Newick | `results/phase2_genome_inventory/species_tree.nwk` |
| 3 | Multi-way alignment | HAL | `data/alignments/alignment.hal` |
| 3 | Synteny blocks | GFF3/BED | `data/synteny/multi_way_synteny/` |
| 4 | Rearrangement calls | CSV | `data/ancestral/rearrangements.csv` |
| 4 | Ancestral karyotypes | Text | `data/ancestral/ancestral_genomes/` |
| 4 | Per-branch rates | CSV | `results/phase4_rearrangements/per_branch_rates.csv` |
| 4 | Hotspots | CSV | `results/phase4_rearrangements/hotspots.csv` |
| 5 | Interactive browser | HTML/JS | `results/phase5_viz_manuscript/browser/` |
| 5 | Manuscript figures | PDF/PNG | `manuscript/figures/` |
| 5 | Supplementary tables | XLSX/CSV | `manuscript/tables/` |

### Manuscript Components

- **Methods** (~3,000 words): Genome collection, alignment, synteny extraction, rearrangement calling, statistics, ancestral reconstruction
- **Results** (~4,000 words):
  - Genome inventory and phylogenetic framework
  - Alignment quality and synteny landscape
  - Rearrangement frequency, hotspots, phylogenetic distribution
  - Ancestral karyotypes and evolutionary transitions
  - Correlation with speciation (if data support)
- **Discussion** (~2,000 words): Biological implications, comparison to other taxa, evolutionary insights
- **Figures**: ≥8 main figures (phylogeny with rearrangements, synteny Circos plots, hotspot maps, ancestral karyotypes, rate distributions, speciation correlations)
- **Supplementary**: >20 supplementary figures, ≥10 supplementary tables

### Data Release Package

- **Zenodo or OSF deposit** (CC-BY 4.0 license):
  - All input genomes (or links to NCBI/Ensembl)
  - Multi-way alignment (HAL file)
  - Synteny blocks (GFF3)
  - Rearrangement calls (BED, VCF, or custom format)
  - Ancestral karyotypes (text, FASTA)
  - R/Python scripts for all analyses
  - Processed data tables (rates, hotspots, etc.)
  - README with documentation

---

## Limitations & Caveats

### Known Limitations

1. **Genome Assembly Quality Heterogeneity**
   - Not all beetle genomes are equal quality (N50 ranges from 100 kbp to >10 Mbp)
   - **Mitigation**: Stringent QC thresholds in Phase 2; sensitivity analysis with/without low-quality genomes

2. **Alignment Resolution**
   - ProgressiveCactus may miss small rearrangements (<10 kbp)
   - Synteny blocks have ~10 kbp granularity (lower bound for reliable calling)
   - **Caveat**: Ancestral reconstructions assume alignments are correct; errors propagate

3. **Rearrangement Ambiguity**
   - Complex rearrangements (multi-step fusions, inversions with translocation) may be misclassified
   - Inversions in poorly-aligned regions may be undetectable
   - **Mitigation**: Conservative calling; flag uncertain events

4. **Ancestral State Reconstruction Uncertainty**
   - RACA uses parsimony; multiple equally-parsimonious solutions may exist
   - **Mitigation**: Report confidence scores; highlight ambiguous nodes

5. **Phylogenetic Sampling Bias**
   - 438 genomes across 61 families still only sample a fraction of beetle diversity (~400K species)
   - Some clades (e.g., deep-branching Archostemata with only 1 genome) are underrepresented
   - **Caveat**: Results biased toward well-sequenced, economically important beetles

6. **No Ancient Samples**
   - Cannot validate ancestral reconstructions with fossil genomes
   - Relies entirely on inference from modern sequences
   - **Caveat**: Ancestral karyotypes are model predictions, not ground truth

7. **Statistical Power for Speciation Correlation**
   - With 438 genomes, statistical power is reasonable but still limited for some clade-level correlations
   - **Mitigation**: Treat speciation correlations as exploratory; require robust effect sizes

### Interpretation Warnings

- **Hotspot identification at p < 0.05 is exploratory**: Multiple testing correction (Benjamini-Hochberg FDR) will be applied post-hoc
- **Branch-level rates have wide confidence intervals**: Do not over-interpret small differences
- **Rearrangement counts scale with genome size**: Smaller genomes may have fewer detectable rearrangements; normalize by expected alignment coverage
- **Non-independence**: Rearrangements on the same branch are not statistically independent; no formal statistical tests of causation

### Future Directions (Not in Scope)

- **Single-cell or transcriptomic validation**: Does gene expression correlate with chromosomal structure?
- **Functional genomics**: Do rearrangement hotspots overlap genes under positive selection?
- **Experimental validation**: Hybrid crosses to test reproductive isolation predictions from chromosomal inversions
- **Paleogenomics**: If ancient beetle DNA becomes available, validate ancestral reconstructions

---

## Reproducibility & Transparency

### Version Control
- All scripts, workflows, and manuscript drafts are version-controlled in Git
- Repository: `[TBD — set up during Phase 1]`
- All code commits include descriptions of changes and any AI contributions

### Code Availability
- All analysis code released under MIT or GPL 3.0 license
- Zenodo release with DOI for each major milestone
- Snakemake workflows provided for complete reproducibility

### Data Availability
- All input genomes: links to NCBI/Ensembl (with accession numbers, versions)
- All processed data: Zenodo deposit (DOI)
- Manuscript Methods section includes detailed parameter choices for all tools

### AI Contribution Transparency
- `project_management/ai_use_log.md` lists all Claude-generated code and contributions
- Each code file includes header comment: "Generated/reviewed by Claude AI [date], reviewed by [human] [date]"
- Clear boundaries between AI-generated and hand-written code

---

## Timeline & Milestones

| Date | Phase | Milestone | Owner |
|------|-------|-----------|-------|
| 2026-03-21 (Day 1) | 1 | Finalize Phase 1 scope; literature review begins | Heath + Claude |
| 2026-03-23 (Day 3) | 1→2 | Preprint strategy finalized; genome mining begins | Health |
| 2026-03-28 (Day 7) | 2→3 | 438 genomes curated; constraint tree built (439-tip) | Team |
| 2026-04-14 (Day 24) | 3→4 | Alignment complete; synteny extracted | TAMU cluster |
| 2026-04-29 (Day 30) | 4→5 | Rearrangements called; ancestral genomes reconstructed | Team |
| 2026-05-02 (Day 35) | 5 | **Preprint submitted to bioRxiv** | Health + Claude |
| 2026-05-30 | Post-5 | Peer-reviewed manuscript submitted | Health + Claude |

---

## Contact & Questions

**Project PI**: Heath Blackmon

**AI Assistant**: Claude (Anthropic)

**For questions about this analysis plan**:
- Review `context.md` for project overview
- Check `project_management/` for decision logs and progress tracking
- See `phases/phase*_*/` for phase-specific documentation

---

**Last Updated**: 2026-03-21
**Document Version**: 1.0
**Status**: Ready for Phase 1 initiation
