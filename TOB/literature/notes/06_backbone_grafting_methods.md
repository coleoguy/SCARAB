# 06 — Backbone Grafting and Mega-Phylogeny Methods for TOB

*Compiled 2026-05-03. Covers methods for combining a high-quality backbone (~500–600 taxa) with a taxon-rich supermatrix (~10–30k species) for Tree of Beetles.*

---

## 1. Topology Constraint in ML Tree Search

### IQ-TREE `-g` (backbone constraint)

`-g <tree_file>` forces the search to respect a multi-furcating constraint tree; taxa absent from the constraint are inserted via ML. The constraint is enforced throughout every SPR iteration, so the backbone topology is never violated. IQ-TREE 2 (Minh et al. 2020, *Mol Biol Evol* 37:1530) and the recently released IQ-TREE 3 both support `-g`. A known practical issue: when the constraint tree contains very few of the total taxa, terraces of equivalent-likelihood trees can proliferate; IQ-TREE's phylogenetic-terrace-aware (PTA) data structure mitigates but does not fully eliminate this. Missing data in the supermatrix—inevitable when tip-rich loci are grafted onto a BUSCO backbone—compounds terrace ambiguity. **Scalability:** tested routinely at thousands of taxa; full supermatrix at 30k+ taxa has not been benchmarked in the literature but is computationally tractable if the partition model is kept simple. **Key issue for TOB:** the constraint tree must contain all backbone taxa in exactly the labels used in the alignment; any mismatch silently drops the constraint for that tip.

### RAxML / RAxML-NG `-g` (backbone constraint)

RAxML distinguishes `-g` (multi-furcating backbone; unresolved nodes are free) from `-r` (binary backbone, fully fixed). RAxML-NG inherits the same flags. For TOB's use case, `-g` with the ~500-taxon backbone is appropriate: backbone splits are locked, family-level placements resolved by ML. RAxML-NG (Kozlov et al. 2019) is substantially faster than classic RAxML for large supermatrices under partitioned models, and its checkpoint/restart facility matters for 7-day wall jobs on Grace. **Known issue:** RAxML-NG reports that constraint violations can occasionally arise from starting-tree generation; always verify the final tree contains the expected bipartitions.

**Practical consensus:** Use `-g` in IQ-TREE or RAxML-NG for Tier-3 family-level analyses, not for the Tier-1 backbone itself. The constraint must be the finalized, fully-resolved Tier-1+2 backbone.

---

## 2. Supertree Synthesis Methods

### Matrix Representation with Parsimony (MRP)

MRP (Baum 1992; Ragan 1992) encodes source-tree clade membership as a binary character matrix and applies parsimony. Bininda-Emonds & Sanderson (2001, *Syst Biol* 50:565; DOI: [10.1080/10635150120087](https://doi.org/10.1080/10635150120087)) assessed accuracy via simulation and found weighted MRP (nodes weighted by bootstrap support) slightly outperforms unweighted MRP and approaches total-evidence performance when source trees overlap substantially. Performance degrades sharply with incomplete taxon overlap—a central concern for TOB where genomic-backbone taxa and family-level supermatrix taxa are largely non-overlapping. **Scalability:** MRP itself scales well; the bottleneck is running parsimony on the matrix. **Verdict for TOB:** MRP is defensible for combining family-level trees into a beetle supertree but offers no probabilistic branch lengths and is sensitive to source-tree incongruence.

### Matrix Representation with Likelihood (MRL)

MRL analyzes the same MRP binary matrix under a likelihood model rather than parsimony. Nguyen, Mirarab & Warnow (2012, *Algorithms Mol Biol* 7:3) demonstrated that MRL consistently outperforms MRP on simulation and empirical benchmarks. SuperFine+MRL further improves accuracy by first constructing a supertree via short-subtree merging, then refining it with MRL. **Scalability:** comparable to MRP. **Verdict for TOB:** strictly better than MRP when source trees must be combined, but still inferior to direct constrained supermatrix analysis if data can be pooled.

### ASTRAL / ASTRAL-III Coalescent Summary

ASTRAL-III (Zhang et al. 2018, *BMC Bioinformatics* 19:153) is a summary-coalescent method that takes a set of gene trees and returns the species tree maximizing the quartet score. It does not naturally take a backbone constraint, but Rabiee & Mirarab (2020, *BMC Genomics* 21:187) introduced a mode for forcing external backbone constraints onto the ASTRAL optimization ("Forcing external constraints on tree inference using ASTRAL"). This enables scaffolding: build ASTRAL-backbone from ~500-taxon gene-tree set, then fix that backbone and add tip-only taxa. ASTRAL-Pro (Zhang & Mirarab 2020, *Mol Biol Evol* 37:3292) extends this to multi-copy gene families (paralogs). **Scalability:** ASTRAL-III runs in O(nk) where n = taxa, k = genes; practical for thousands of taxa and hundreds of genes. **Verdict for TOB:** most applicable for Tier-1+2 backbone construction where multi-locus gene trees exist; less suitable for grafting morphology-only or barcode-only Tier-3 taxa.

---

## 3. Mega-Phylogeny Construction

### Smith & Brown 2018 Seed-Plant Approach

Smith & Brown (2018, *Am J Bot* 105:302; DOI: [10.1002/ajb2.1019](https://doi.org/10.1002/ajb2.1019)) constructed a seed-plant phylogeny covering 79,881–353,185 terminal taxa by: (1) hierarchically clustering publicly available GenBank sequences into major clade-level supermatrices; (2) running separate ML analyses per clade; (3) grafting clade trees onto an established backbone (either Open Tree of Life or Magallón et al. 2015) using topological overlaps. Taxa with no molecular data were placed by taxonomy alone via the OTL taxonomy. This is the closest published analog to TOB's design. **Key lesson:** hierarchical decomposition—build within-family trees constrained to the backbone, graft—avoids a monolithic 353k-taxon supermatrix that would be computationally intractable. Branch lengths within grafted subtrees are internally consistent but inter-clade branch lengths are not comparable.

### Chesters 2017 Insect Hierarchical Approach (SOPHI)

Chesters (2017, *Syst Biol* 66:426; DOI: [10.1093/sysbio/syw099](https://doi.org/10.1093/sysbio/syw099)) built a 49,358-species insect tree using the SOPHI framework: (1) separate pipelines for nuclear transcriptomic, mitochondrial, and barcode data; (2) hierarchical inference in which species-rich analyses are nested inside a genomic backbone constraint. This is the direct precedent for TOB. The paper explicitly notes that gene-rich vs. species-rich partition structure is the central obstacle to scaling supermatrix analysis. Chesters (2023, *Mol Ecol Res* 23:1556) extended this to insectphylo.org, a living-synthesis hub for insects now covering Diptera at species level.

### Creedy, Vogler et al. 2025 Coleoptera Backbone

Creedy et al. (2025, *Syst Biol* syaf031; DOI: [10.1093/sysbio/syaf031](https://doi.org/10.1093/sysbio/syaf031)) combined >2,000 BUSCO loci from 119 coleopteran exemplars (nuclear backbone) with 491 mitogenomes run under that backbone constraint, yielding >80 universally supported nodes that define the major beetle lineages. This is the most current, coleopteran-specific backbone available and directly informs TOB's Tier-1+2 design.

---

## 4. Open Tree of Life Graph Synthesis

Hinchliff et al. (2015, *PNAS* 112:12764; DOI: [10.1073/pnas.1423041112](https://doi.org/10.1073/pnas.1423041112)) synthesized 2.3 million tips by: (1) building a unified taxonomy (OTT); (2) ranking published source phylogenies by quality; (3) applying a graph-based synthesis that prefers higher-ranked phylogenies and falls back to taxonomy when no source tree covers a clade. **Applicability to TOB:** OTL's synthesis algorithm is publicly available (propinquity) and could place unsequenced beetle genera by taxonomy-fallback. However, OTL beetle coverage is shallow and source-tree quality is uneven. **Verdict:** OTL is useful for placing incertae sedis and morphology-only genera in Tier-3 as a last resort, not as the primary engine.

---

## 5. Phylogenetic Placement Tools

### EPA-ng

Barbera et al. (2019, *Syst Biol* 68:365; DOI: [10.1093/sysbio/syy054](https://doi.org/10.1093/sysbio/syy054)) reimplemented the evolutionary placement algorithm (EPA) from RAxML with distributed-memory parallelism. EPA-ng placed 1 billion reads onto a 3,748-taxon tree in ~7 hours on 2,048 cores and outperforms pplacer by up to 30x sequentially. Placement accuracy is comparable to pplacer; the tool outputs jplace format with per-edge posterior probabilities. **When to use for TOB:** ideal for Tier-3 taxa represented only by a single short marker (COI barcode, 16S); query sequences are placed onto the finalized Tier-1+2 reference tree without modifying its topology.

### pplacer

Matsen et al. (2010, *BMC Bioinformatics* 11:538; DOI: [10.1186/1471-2105-11-538](https://doi.org/10.1186/1471-2105-11-538)) introduced pplacer, which computes both ML and Bayesian posterior placements with edge-by-edge uncertainty quantification. Slower than EPA-ng at scale but provides richer uncertainty output (expected distance between placement locations). **When to use for TOB:** when statistical rigor of placement confidence is needed, e.g., validating family-level placements.

### SEPP / TIPP

SEPP (Mirarab et al. 2012, PSB Proceedings; GitHub: smirarab/sepp) wraps an ensemble of HMMs to handle fragmentary query sequences—typical of ancient or degraded DNA and short-amplicon barcodes. It divides the reference alignment into overlapping subsets, fits HMMs, selects the best-scoring HMM for each query, and places via EPA. TIPP extends SEPP with taxonomic profiling. **When to use for TOB:** whenever query sequences are shorter or more divergent than the reference alignment, which is expected for many Tier-3 barcode-only taxa.

### RAPPAS

RAPPAS (Linard et al. 2019, *Bioinformatics* 35:2652) is alignment-free: it pre-computes phylo-kmer databases from the reference tree, then places queries without alignment. Fast in the placement step but requires expensive pre-build and is sensitive to molecular-clock violations and branch-length heterogeneity. PEWO benchmarks show RAPPAS has more outlier placements than EPA-ng under heterogeneous rates. **Verdict for TOB:** not recommended as primary placement tool; EPA-ng is faster and more accurate across typical beetle data.

### DEPP / C-DEPP (2022–2024)

Jiang et al. (2023, *Syst Biol* 72:17) proposed DEPP, a deep-learning metric-learning framework for phylogenetic placement. It matches or exceeds EPA-ng accuracy for 16S amplicons without specifying a substitution model. C-DEPP (2024, *Bioinformatics* 40:btae361) scales DEPP to ultra-large reference trees (~10M sequences). **Verdict for TOB:** promising but requires large training sets; not yet standard practice for novel taxon groups. Monitor for future applicability to beetle COI placement.

---

## 6. Practical Reports from Published Mega-Phylogenies

- **Smith & Brown 2018:** hierarchical clade decomposition + backbone grafting worked at 353k tips; key failure mode was taxa with conflicting names between GenBank and OTL requiring substantial curation.
- **Chesters 2017/2023:** SOPHI / insectphylo.org demonstrates that the gene-rich vs. species-rich partition must drive pipeline design, not be treated as a supermatrix homogeneity problem.
- **Creedy et al. 2025:** nuclear backbone constraint on mitogenome trees for Coleoptera worked with >80 universally resolved nodes; highlights that nuclear+mitochondrial integration requires careful selection of uncontested backbone nodes.
- **Bee supermatrix 2023 (*Mol Phylogenet Evol* 199:108144):** 4,586-species supermatrix for Anthophila showed robust family-/subfamily-level support but required explicit handling of sparse loci at species tips.

---

## Recommendation for TOB

**Recommended pipeline:**

1. **Tier-1+2 backbone (~500–600 taxa):** Build in IQ-TREE or RAxML-NG from a concatenated BUSCO supermatrix (>500 loci, genomic exemplars, all four Coleoptera suborders + Strepsiptera). Use ASTRAL-III in parallel on single-gene trees for cross-validation. The Creedy et al. (2025) 80+ universally supported beetle nodes constrain the prior topology. This tree becomes the fixed backbone.

2. **Tier-3 family-level supermatrix (~10–30k taxa):** Run per-family (or per-superfamily) ML analyses in IQ-TREE or RAxML-NG with `-g <backbone>`. Each family's data are a sparser supermatrix of mitochondrial genes + barcode loci available for member species. Constrained analyses resolve intra-family placements without violating the backbone. Following the Chesters/Smith & Brown hierarchical model, family trees are then grafted onto the backbone to produce the final composite tree.

3. **Tier-3 barcode-only taxa:** Place via EPA-ng onto the finalized composite tree. Use SEPP instead of bare EPA-ng when query sequences are fragmentary (<300 bp COI). OTL taxonomy-fallback for genera with no sequence data at all.

This combination—constrained ML per family, followed by EPA-ng graft for barcode singletons—matches the closest published precedents (Chesters 2017/2023, Smith & Brown 2018), uses tools actively maintained and benchmarked, and is compatible with Grace HPC resources (IQ-TREE/RAxML-NG SLURM arrays, EPA-ng distributed MPI).
