# Lessons from Prior Insect and Arthropod Mega-Phylogeny Attempts

Compiled for Tree of Beetles (TOB) project, TAMU, PI: Heath Blackmon. 2026-05.

---

## 1. Bocak et al. 2014 — Coleoptera Supermatrix

**Citation:** Bocak L et al. 2014. Building the Coleoptera tree-of-life for >8,000 species: composition of public DNA data and fit with Linnaean classification. *Systematic Entomology* 39:97–107. doi:10.1111/syen.12037

**Scale:** 8,441 species-level terminals; 4 loci (18S rRNA, 28S rRNA, rrnL, cox1); 6,600 aligned nucleotide positions. Represents ~2.2% of described Coleoptera.

**What worked:** The broadest taxon-sampled Coleoptera tree to that point. Family-level topology agreed well with Linnaean classification. Confirmed Polyphaga monophyly; resolved Cucujoidea paraphyly; demonstrated that public GenBank data can be assembled into a workable supermatrix with filtering.

**What failed:**
- Only 4 loci, yielding a matrix heavily dominated by missing data; many taxon pairs share no overlapping sites, eliminating pairwise phylogenetic signal.
- Nodal support was characteristically weak throughout, especially at subfamily and genus level.
- Some suborders (e.g., Archostemata) were severely undersampled.
- The 2.2% species coverage means the tree is a scaffold, not a species-level resource.
- Rogue taxa with extreme missing data destabilized topology.

**Lesson for TOB:** Four loci cannot sustain a stable mega-tree. Genome-scale markers are essential. Missing data must be actively managed — not merely tolerated — by enforcing minimum occupancy thresholds per taxon before they enter the matrix.

---

## 2. Hinchliff et al. 2015 — Open Tree of Life

**Citation:** Hinchliff CE et al. 2015. Synthesis of phylogeny and taxonomy into a comprehensive tree of life. *PNAS* 112:12764–12769. doi:[10.1073/pnas.1423041112](https://doi.org/10.1073/pnas.1423041112)

**Scale:** 2.3 million tips; graph-synthesis of published phylogenies + Open Tree Taxonomy; no direct sequence analysis.

**What worked:** First automated pipeline to integrate all published phylogenies with a global reference taxonomy. Provides a computable, continuously updated resource. Graph synthesis outperformed MultiLevelSupertree in normalized Robinson-Foulds distance (15 vs. 31 average error). Coleoptera family-level topology present via input trees.

**What failed:**
- Most tips in the synthetic tree are placed by taxonomy alone, not by any phylogenetic analysis. For Coleoptera, the overwhelming majority of species exist only as taxonomic placeholders.
- No branch lengths are inferrable from synthesis; the tree cannot be used for rate estimation or divergence dating.
- Expert manual ranking of input trees is required; without it, conflicting studies of different quality are weighted equally.
- Phylogenetic conflict among input trees is collapsed to polytomies rather than resolved, producing an unresolved topology for many Coleoptera clades.

**Lesson for TOB:** Supertree synthesis is adequate for broad topology but produces branch-length artifacts and leaves most nodes taxonomically inferred. TOB needs primary molecular data for all included tips — taxonomy-only imputation should be a last resort, not the default.

---

## 3. Hedges et al. — TimeTree of Life

**Citation:** Hedges SB et al. 2017. TimeTree: A resource for timelines, timetrees, and divergence times. *Molecular Biology and Evolution* 34:1812–1819. doi:10.1093/molbev/msx116. Updated as TimeTree 5 (Kumar et al. 2022, *MBE* 39:msac174).

**Scale:** Synthesis of published molecular timetrees; TimeTree 5 covers >150,000 species. Coleoptera included at order and family level from published studies (McKenna 2009 chapter provides beetle divergence times).

**What failed for Coleoptera:**
- Most Coleoptera node ages in TimeTree derive from a single published study; very few nodes are calibrated by multiple independent analyses, so uncertainty is underrepresented.
- TimeTree 5 achieved only 20–43% increases in coverage of major groups, leaving deep gaps for beetle families.
- Divergence times for the Adephaga–Polyphaga split (~277–266 Ma) and most family origins are informed by ≤2 studies, making confidence intervals unreliable.
- TimeTree is a meta-database, not an analysis: it cannot resolve conflicts among input studies.

**Lesson for TOB:** For TOB to produce credible node ages, fossil calibrations must be applied within a unified Bayesian framework on primary data, not aggregated from heterogeneous published estimates. Relying on TimeTree values as priors risks circular calibration.

---

## 4. Misof et al. 2014 (1KITE) — Insect Phylogenomics

**Citation:** Misof B et al. 2014. Phylogenomics resolves the timing and pattern of insect evolution. *Science* 346:763–767. doi:[10.1126/science.1257570](https://doi.org/10.1126/science.1257570)

**Scale:** 144 insect species (1 per major lineage); 1,478 single-copy protein-coding loci; transcriptome-based. Coalition of >100 authors (1KITE consortium).

**What worked:** Resolved most deep insect order relationships with high support. Site-specific substitution models and domain-specific amino acid models reduced systematic error. Established Holometabola and Polyneoptera as robust; placed Strepsiptera as sister to Diptera. Provided dated backbone for insect evolution (origin ~479 Ma, flight ~406 Ma).

**What failed:**
- Only 1 to 2 species per order — deep topology resolved but species-level diversity not sampled.
- Previously published transcriptomes had lower gene recovery (79% and 62% vs. 98% for de novo sequences), introducing data heterogeneity.
- Sparse matrix with missing loci across taxa; sparsely populated matrices can yield biased bootstrap support even for incorrect topologies.
- Gene tree discordance from ILS at rapid radiations was acknowledged but not fully resolved.
- Transcriptome approach requires fresh tissue; not applicable to museum specimens.

**Lesson for TOB:** Locus selection strategy matters as much as locus count. Single-copy nuclear orthologs with high occupancy outperform randomly chosen transcriptome loci. TOB should enforce a minimum occupancy filter (e.g., ≥50% taxa per locus) and apply gene-tree concordance (gCF/sCF) as a check on matrix-level support.

---

## 5. Regier et al. 2010 — Arthropoda Phylogenomics

**Citation:** Regier JC et al. 2010. Arthropod relationships revealed by phylogenomic analysis of nuclear protein-coding sequences. *Nature* 463:1079–1083. doi:[10.1038/nature08742](https://doi.org/10.1038/nature08742)

**Scale:** 75 arthropod species; 62 single-copy nuclear protein-coding genes; >41 kb aligned DNA. Likelihood, Bayesian, parsimony consensus.

**What worked:** Established Mandibulata and Pancrustacea with strong support; placed Hexapoda sister to Xenocarida (Remipedia + Cephalocarida). Showed that 62 nuclear genes from 75 taxa could definitively settle century-long debates.

**What failed:**
- Species with missing genes or long stretches of missing sites had to be excluded in downstream reanalyses.
- Supermatrix alignment quality degraded with deep divergences; homology erosion across distantly related lineages is difficult to detect.
- The dataset was subsequently reused in many follow-up studies; any assembly errors propagate through derivative analyses.
- 75 taxa cannot represent within-Hexapoda diversity needed for insect-level questions.

**Lesson for TOB:** Alignment quality review is not optional. For a 10–30k tip tree, automated alignment must be followed by occupancy filtering, trimming (e.g., trimAl), and systematic checks for non-homologous columns before tree inference.

---

## 6. Upham et al. 2019 — Mammal Mega-Phylogeny

**Citation:** Upham NS, Esselstyn JA, Jetz W. 2019. Inferring the mammal tree: Species-level sets of phylogenies for questions in ecology, evolution, and conservation. *PLOS Biology* 17:e3000494. doi:[10.1371/journal.pbio.3000494](https://doi.org/10.1371/journal.pbio.3000494)

**Scale:** ~6,000 extant mammal species; 31-gene supermatrix; "backbone-and-patch" Bayesian inference with fossil calibration; DNA-only and taxonomically completed trees.

**What worked:** Backbone-and-patch approach applies a unified modeling framework across all branches, avoiding the branch-length artifacts of classic supertrees. Explicitly showed that supertree polytomies inflate or deflate tip-level speciation rate estimates. Credible sets of trees (not single estimates) capture topological and divergence time uncertainty. Model provided a template adopted by BirdTree and VertLife.

**What failed:**
- Taxonomic imputation for DNA-absent species remains sensitive to assumed birth-death model; rates can be mis-estimated in clades with poor DNA coverage.
- Patch boundaries require expert judgment; clade definitions that are later revised require re-inference of patches.

**Lesson for TOB:** Model branch lengths within a single inferential framework. Joining separately estimated trees without reconciling branch length scales produces systematic biases in downstream analyses (diversification rates, ancestral state estimation). For TOB, a uniform substitution model applied across the supermatrix, or a properly grafted backbone, is preferable to ad hoc supertree joining.

---

## 7. Smith & Brown 2018 — Seed Plant Mega-Phylogeny

**Citation:** Smith SA, Brown JW. 2018. Constructing a broadly inclusive seed plant phylogeny. *American Journal of Botany* 105:302–314. doi:10.1002/ajb2.1019

**Scale:** ~79,880 seed plant taxa; hierarchical clustering of GenBank sequences; dated phylogeny (GBOTB); open-source pipeline.

**What worked:** Demonstrated a fully automated hierarchical pipeline for assembling a species-level dated tree from GenBank. Showed that Quartet Concordance scores identify conflicted regions of the tree that require additional data. Open-source code lowered barriers for community replication and extension.

**What failed:**
- Human intervention was necessary to remove branch-length outliers and misidentified GenBank sequences; automation alone was insufficient for data quality control.
- Even when the same gene was sampled for two taxa, non-overlapping site coverage between accessions eliminated pairwise signal.
- Biased taxon sampling (data-rich families overrepresented) inflated apparent diversification rates in well-sampled clades.

**Lesson for TOB:** At TOB scale, automated GenBank mining requires a curated post-processing step. Sequence misidentification and contamination in public databases are real and disproportionately affect rare taxa — exactly the species TOB most needs to place correctly.

---

## 8. Kjer et al. 2016 — History of Insect Phylogenetics

**Citation:** Kjer KM et al. 2016. Progress, pitfalls and parallel universes: a history of insect phylogenetics. *Journal of the Royal Society Interface* 13:20160363. PMID:27558853.

**Key finding:** Large datasets do not guarantee correct trees. Model-based analyses outperform parsimony, but "if history is a guide, the quality of conclusions will be determined by an improved understanding of both molecular and morphological evolution, not simply the number of genes analysed." Documented that long-branch attraction, compositional bias, and rate heterogeneity have each derailed apparent majority consensus in insect phylogenetics.

---

## Synthesis: Top 5 Pitfalls TOB Must Avoid

**1. Excess missing data without taxon filtering.**
Why: Supermatrices with many locus-absent taxa create taxon pairs with zero shared sites, making placement driven by noise rather than signal (as demonstrated in Bocak 2014 and Regier 2010 follow-up analyses).
Mitigation: Enforce a minimum occupancy threshold per taxon (e.g., ≥30% of loci present) before inclusion in the primary matrix; build a separate sparse "extended" tree for downstream imputation.

**2. Taxonomy-only species placement (no primary molecular data).**
Why: Open Tree of Life and TimeTree show that taxonomy-imputed tips produce unresolved polytomies and unreliable branch lengths, distorting diversification rates and ancestral state reconstructions.
Mitigation: For TOB, every tip must have at least one sequenced BUSCO locus; taxonomic-only placement is flagged and excluded from rate analyses.

**3. Supertree branch-length artifacts from joining separately estimated trees.**
Why: Upham 2019 quantified that classic supertree approaches produce systematically biased branch lengths, inflating or deflating speciation rate estimates at nodes where polytomies are collapsed.
Mitigation: Apply the backbone-and-patch approach within a single modeling framework (as in Upham 2019), or use a supermatrix with a unified substitution model across all taxa.

**4. Failure to audit alignment quality and GenBank contamination.**
Why: Smith & Brown 2018 found that human inspection was still necessary to remove outlier sequences and non-overlapping accessions; automated pipelines propagate assembly errors into branch lengths and topology.
Mitigation: After automated BUSCO extraction and alignment (MAFFT), run trimAl for gappy-column removal, AMAS for occupancy reporting, and manual spot-checks of any taxon with aberrant branch lengths before tree inference.

**5. Unchecked systematic biases (long-branch attraction, compositional heterogeneity).**
Why: Kjer et al. 2016 document that LBA and compositional bias have each overturned apparent consensus in insect phylogenetics; large gene counts amplify false support rather than reducing it when systematic error is present.
Mitigation: Run gCF/sCF concordance analyses (IQ-TREE) on the final species tree to distinguish genuine support from matrix-wide statistical noise; test for compositional heterogeneity (IQTREE GHOST or BaCoCa) in a representative subsample before committing to a model.

---

*Prepared by Claude Code for TOB project, TAMU. Sources verified from PubMed (DOIs provided), publisher pages, and Web searches.*
