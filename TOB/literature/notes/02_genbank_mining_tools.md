# GenBank Mining Tools for TOB Supermatrix Construction

*Prepared: 2026-05-03 | Scope: Coleoptera Sanger markers (COI, 16S, 18S, 28S, CAD, EF1α, ArgK, RpII, wingless)*

---

## Tools Reviewed

### 1. PHLAWD (Smith, Beaulieu & Donoghue 2009)
**Citation:** Smith SA, Beaulieu JM, Donoghue MJ. 2009. Mega-phylogeny approach for comparative biology. *BMC Evol Biol* 9:37. doi:10.1186/1471-2148-9-37

PHLAWD (Phylogenetic Assembly with Databases) is a C++ program that mines GenBank using user-supplied bait sequences — typically 10–20 full-length representatives spanning the clade of interest for each target locus. BLAST comparisons identify putative homologs within a user-specified taxonomic scope; sequences passing length and identity thresholds are aligned with MAFFT and trimmed. PHLAWD was the workhorse behind several large plant supermatrices in the 2009–2016 era and directly inspired both PyPHLAWD and SuperCRUNCH. It requires local GenBank flatfile mirrors and a C++ build environment. The software has received no substantive updates since approximately 2015 and is effectively unmaintained.

**Strengths:** Proven at scale; well-understood bait-and-filter logic.
**Weaknesses:** Requires pre-downloaded GenBank mirrors; unmaintained; C++ build failures common on modern Linux; no synonym handling.
**TOB applicability:** Superseded. Do not use — replaced by PyPHLAWD and SuperCRUNCH.

---

### 2. PyPHLAWD (Smith & Walker 2019)
**Citation:** Smith SA, Walker JF. 2019. PyPHLAWD: a python tool for phylogenetic dataset construction. *Methods Ecol Evol* 10:104–108. doi:10.1111/2041-210X.13096

PyPHLAWD is the Python reimplementation of PHLAWD (GitHub: `FePhyFoFum/PyPHLAWD`). It implements two complementary orthology strategies: a **baited analysis** analogous to the original PHLAWD workflow (provide 10–20 bait sequences per locus, BLAST against a local GenBank copy, filter by coverage and identity), and a **tip-to-root clustering** mode that requires no a priori bait sequences — instead it runs all-by-all BLAST followed by Markov Clustering (MCL) across all sequences for a taxon, summarizing results as an interactive HTML. The clustering mode is well-suited for exploratory surveys of what Sanger data exist across Coleoptera families. PyPHLAWD still requires a local mirror of GenBank (BLAST-formatted), which for insects may be tens of GB per release. GitHub commit history shows low activity after 2021; open issues regarding the `treemake` function remain unresolved. The tool is Python 3 compatible and installable from the repository.

**Strengths:** Dual orthology modes; HTML cluster summaries; familiar PHLAWD logic extended for exploratory use.
**Weaknesses:** Local GenBank mirror required; low maintenance 2022–2026; `treemake` flag unimplemented; no built-in synonym reconciliation.
**TOB applicability:** Useful for the exploratory clustering pass to survey marker availability per family, but SuperCRUNCH should handle the production pipeline.

---

### 3. SuperCRUNCH (Portik & Wiens 2020)
**Citation:** Portik DM, Wiens JJ. 2020. SuperCRUNCH: a bioinformatics toolkit for creating and manipulating supermatrices and other large phylogenetic datasets. *Methods Ecol Evol* 11:763–772. doi:10.1111/2041-210X.13392

SuperCRUNCH is a modular, Python-based toolkit that operates on a user-supplied sequence FASTA (downloaded from NCBI Entrez or provided locally) rather than a full GenBank mirror. The pipeline is decomposed into explicit, inspectable stages: (1) taxon-list filtering against NCBI sequence records; (2) locus identification via BLAST with reference sequences; (3) sequence quality filtering (length, completeness, ambiguity); (4) duplicate/ambiguous-ID handling (subspecies flagging, voucher-only records); (5) alignment per locus (MAFFT or MUSCLE); (6) trimming; and (7) supermatrix construction with configurable missing-data thresholds. A dedicated **Taxonomy Assessment** module compares the user's taxon list against NCBI Taxonomy synonyms and flags name mismatches, which is directly relevant to reconciling against the Bouchard 2011 Coleoptera catalogue. The published benchmark built a 1,400-taxon × 66-locus supermatrix from 16 GB of GenBank data in ~1.5 hours. The GitHub repository (`dportik/SuperCRUNCH`) shows a stable v1.3.0 release (last code commit 2022); the codebase is mature Python 3 and unlikely to break, though active feature development has slowed. Critically, SuperCRUNCH's modular design means each stage can be rerun independently when new sequences are added to GenBank.

**Strengths:** No full GenBank mirror needed; explicit modular stages; built-in taxonomy synonym detection; contamination/ambiguous-ID filtering; proven at >1,000 taxon scale; well-documented wiki.
**Weaknesses:** Requires a pre-curated taxon list; synonym reconciliation is flagging only (not auto-correction); active development slowed after 2022.
**TOB applicability:** Primary recommendation for TOB. Scales to >10k taxa by downloading per-family sequence sets from Entrez, running locus identification with bait sequences for each of the 9 target markers, and applying the taxonomy module against a Bouchard-derived name list.

---

### 4. SUMAC (Freyman 2015)
**Citation:** Freyman WA. 2015. SUMAC: constructing phylogenetic supermatrices and assessing partially decisive taxon coverage. *Evol Bioinform* 11:263–266. doi:10.4137/EBO.S35384

SUMAC (Supermatrix Constructor) is a Python package (pip installable, v2.23 on PyPI) that queries GenBank's Entrez API directly — no local mirror needed. Given a NCBI taxonomic ID and optional guide sequences, it retrieves all sequences for the clade, clusters them into putative homologs via BLAST, builds alignments, and computes a novel **Missing Sequence Decisiveness Score (MSDS)** that quantifies how much each missing sequence reduces matrix decisiveness. This metric is valuable for prioritizing targeted sequencing campaigns. SUMAC parallelizes BLAST across cores and ran faster than PhyLoTa in direct benchmarks. However, SUMAC's clustering is purely exploratory — it is not designed to target named loci (COI, CAD, etc.) explicitly, making locus-level control weaker than SuperCRUNCH. The GitHub repository (`wf8/sumac`) shows no commits after 2017 and is effectively abandoned.

**Strengths:** MSDS metric for missing-data prioritization; direct Entrez queries; easy pip install.
**Weaknesses:** Abandoned since 2017; weak named-locus targeting; no synonym module.
**TOB applicability:** Not recommended for production pipeline. MSDS concept is worth borrowing as a post-hoc matrix evaluation step.

---

### 5. PhyLoTa / phylotaR (Sanderson et al. 2008; Bennett et al. 2018)
**Citations:**
- Sanderson MJ et al. 2008. The PhyLoTA Browser: processing GenBank for molecular phylogenetics research. *Syst Biol* 57:335–346. doi:10.1080/10635150802158039
- Bennett DJ et al. 2018. phylotaR: an automated pipeline for retrieving orthologous DNA sequences from GenBank in R. *Life* 8:20. doi:10.3390/life8020020

The original PhyLoTa Browser was a static web database (last updated GenBank release 194, circa 2009) that clustered all eukaryotic GenBank sequences into homologous groups for download; it is no longer current. phylotaR (rOpenSci, R package) reimplements the PhyLoTa pipeline as a four-stage automated workflow: taxonomy retrieval, sequence download, all-vs-all BLAST clustering within and across taxonomic nodes, and sister-cluster merging. It operates against live GenBank via Entrez, handles large sequences by splitting on feature annotations, and generates paraphyletic clusters for small nodes. The rOpenSci provenance means it has community review and is better maintained than SUMAC; GitHub commits through 2023 are visible. The R interface and cluster-output format are less suited to multi-locus supermatrix assembly than SuperCRUNCH's explicit locus-targeting approach.

**Strengths:** Live GenBank; rOpenSci quality standards; handles sequence annotation; BLAST-based orthology avoids name-matching.
**Weaknesses:** R ecosystem adds friction for HPC bash pipelines; cluster output requires additional parsing to produce per-locus FASTAs; no named-locus targeting.
**TOB applicability:** Runner-up option if SuperCRUNCH fails to recover sufficient sequences for obscure families; phylotaR's unsupervised clusters can rescue loci with no standard name in the NCBI description field.

---

## Newer Tools (2022–2026) — Verified Only

No tool published between 2022 and 2026 specifically targeting Sanger-marker supermatrix construction from GenBank for large arthropod datasets was found in verified searches. The field has shifted toward WGS/BUSCO pipelines for phylogenomics. The recent Coleoptera literature (Batelka et al. 2025 *Syst Entomol*; Liu et al. 2025 *Syst Biol* syaf031) uses SRA + BUSCO rather than GenBank Sanger mining. For Sanger-based TOB work, the 2019–2020 tools remain the current state of the art.

---

## Practical Considerations for TOB

**Scaling to >10k taxa.** SuperCRUNCH's per-family Entrez downloads bypass the need for a full GenBank mirror; ~170 beetle families with 0.1–5 GB each is manageable on Grace's login node.

**Synonym reconciliation against Bouchard 2011.** Build a master taxon list from the Bouchard catalogue and run SuperCRUNCH's `Assess_Taxonomy.py` against NCBI Taxonomy to flag mismatches; resolve conflicts by adding accepted synonyms as alternate query names. This is the single most time-consuming step and should be scoped as a discrete task.

**Ambiguous IDs and contamination.** `Filter_Seqs_and_Species.py` excludes records with "sp.", "cf.", or "aff."; COI records should additionally be cross-checked against BOLD. Post-alignment, per-locus outlier detection (RogueNaRok or IQ-TREE per-site likelihood) should precede concatenation.

**IQ-TREE backbone constraint.** The SCARAB 466-taxon backbone (`results/species_tree/constraint_tree_466.nwk`) is used with the `-g` flag; TOB Sanger taxa are added as free-floating leaves constrained only to their family clade.

---

## Recommendation

**Use SuperCRUNCH (Portik & Wiens 2020) as the primary pipeline.** It is the only tool in this comparison that (a) targets named loci explicitly, (b) provides a taxonomy synonym-checking module, (c) requires no local GenBank mirror, (d) has documented performance at >1,000-taxon scale, and (e) has a modular design that allows iterative re-runs as new GenBank sequences accumulate. The main gotcha is that SuperCRUNCH's synonym module flags mismatches but does not automatically resolve them — a Bouchard-to-NCBI name reconciliation table must be built manually before running. Estimated time for that reconciliation across ~170 families is substantial and should be scoped as a discrete project task.

**Runner-up: phylotaR.** Use phylotaR for families where SuperCRUNCH recovers few sequences because locus names are non-standard in NCBI records (common in obscure beetle families). phylotaR's unsupervised BLAST clusters will surface sequences labeled only with gene ID or partial descriptions that SuperCRUNCH's name-based locus search would miss.

**Do not use:** PHLAWD (unmaintained), SUMAC (abandoned 2017), or the original PhyLoTa Browser (static, stale GenBank release).
