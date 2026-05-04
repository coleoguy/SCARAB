# 07 Outgroup strategy: Strepsiptera and the rooting of a Coleoptera phylogeny

*Compiled 2026-05-03 for Tree of Beetles (TOB) project, PI: Heath Blackmon, TAMU*

---

## 1. State of the Strepsiptera–Coleoptera sister relationship

The "Strepsiptera problem" — the uncertain placement of twisted-wing parasites within Holometabola — was a source of genuine controversy for three decades. Two competing hypotheses dominated: (1) **Coleopterida**: Strepsiptera sister to Coleoptera, supported by morphological tradition and most nuclear gene analyses; (2) **Halteria**: Strepsiptera sister to Diptera, recovered by parsimony on ribosomal RNA data (Wheeler et al. 1993 and Rokas et al. 1999) and attributed to long-branch attraction (LBA) between two fast-evolving lineages.

The balance shifted decisively with two landmark phylogenomic studies. Niehuis et al. (2012, *Current Biology*; PMID 22704986) sequenced the genome of a mengenillid Strepsiptera and compared it against 12 insect genomes using ~4,500 genes and ~18 million nucleotides. Both amino-acid and recoded-DNA trees strongly supported Strepsiptera as sister to Coleoptera, with Neuropterida sister to that pair — and morphological reanalysis was congruent. That study explicitly rejected Halteria as an LBA artifact of parsimony and compositionally biased data.

Boussau et al. (2014, *PLOS ONE*; DOI 10.1371/journal.pone.0107709) — the paper directly targeting the LBA concern — sequenced seven additional transcriptomes to include Ripiphoridae and Meloidae (coleopteran families historically proposed as relatives of Strepsiptera), two Strepsiptera, and a Neuropterida representative. Using PhyloBayes with site-heterogeneous CAT and CAT-GTR models robust against LBA, all model-based analyses recovered Strepsiptera sister to Coleoptera, Neuropterida sister to the pair (Neuropteroidea). Only parsimony was discordant, placing Strepsiptera outside Neuropteroidea — a result consistent with LBA, not biology. Recoding in 2-, 4-, and 6-state schemes did not change the topology.

The 1KITE project (Misof et al. 2014, *Science*; PMID 25378627) confirmed Strepsiptera as sister to Coleoptera in a 1,478-gene transcriptomic framework spanning all major insect orders, with Hymenoptera as the earliest-diverging Holometabola. McKenna et al. 2019 (*PNAS*; DOI 10.1073/pnas.1909655116) included Neuroptera, Megaloptera, Raphidioptera, and Strepsiptera as outgroups for the 4,818-gene, 146-taxon beetle phylogeny. Cai et al. 2022 (*Royal Society Open Science*; DOI 10.1098/rsos.211771) independently recovered the same Neuropteroidea topology using the site-heterogeneous CAT-GTR+G4 model on 68 genes from Zhang et al.'s dataset.

The most recent review (Strepsiptera systematics: past, present, and future, *Insect Systematics and Diversity* 2025, DOI 10.1093/isd/ixaf024) states the current consensus plainly: Strepsiptera and Coleoptera are sister, with Neuropterida sister to both; this grouping is supported by multiple independent genomic and transcriptomic datasets and morphological synapomorphies (enlarged hindwings, immobile pupal mandibles).

**Assessment of robustness:** The Strepsiptera–Coleoptera sister relationship is now robustly supported. Key caveats remain: (a) Strepsiptera retain long branches in amino-acid trees because of their reduced, fast-evolving genomes (~72 Mb, BUSCO 87%; Xenos peckii GCA_040167675, *Scientific Data* 2024); (b) parsimony and site-homogeneous maximum-likelihood models continue to misplace Strepsiptera; (c) any analysis of Coleoptera that includes Strepsiptera must use site-heterogeneous mixture models (CAT-GTR or LG+C20 minimum) and verify Strepsiptera branch-length behavior. Compositional heterogeneity is also a documented problem in Coleoptera themselves (Cai et al. 2022), so model choice is doubly important.

---

## 2. Best-practice outgroup composition in insect phylogenomics

The collective experience of beetle phylogenomics since 2015 supports the following principles:

**Include the immediate sister (Strepsiptera) and the next outgroup ring (Neuropterida).** Zhang et al. 2018 (*Nature Communications*; DOI 10.1038/s41467-017-02644-4) used four Neuropterida (3 Neuroptera + 1 Megaloptera) but deliberately excluded Strepsiptera because too many of the 95 targeted genes were missing (>50% gaps in the published genome). McKenna et al. 2019 included Strepsiptera alongside all three Neuropterida orders. Cai et al. 2022 reanalyzed the Zhang gene matrix and also did not add Strepsiptera, but the topology was nevertheless consistent with Coleopterida because the outgroup correctly placed the Coleoptera root.

**Include a more distant holometabolan anchor.** All major studies use Hymenoptera (typically 2–3 species) and/or Lepidoptera or Diptera to provide a more distant node that stabilizes the root of Holometabola. Without taxa well outside Neuropteroidea, the root of the Coleoptera ingroup cannot be reliably placed and branch-length estimation for the Neuropterida–Coleoptera node is degraded.

**Taxon breadth within Neuropterida matters.** Misof et al. 2014 and McKenna et al. 2019 both sample Neuroptera, Megaloptera, and Raphidioptera. The integrative phylogenomic analysis of Neuropterida (BMC Ecology and Evolution 2020; DOI 10.1186/s12862-020-01631-6) demonstrated that Raphidioptera is sister to (Neuroptera + Megaloptera), making all three orders needed to properly resolve and date the Coleoptera–Neuropterida split. Omitting Raphidioptera creates a long-branch artifact analogous to the Strepsiptera problem.

**Limit Strepsiptera to 1–2 genome-quality taxa.** Because all available Strepsiptera genomes are compact and fast-evolving, more than one taxon does not add signal but can amplify LBA risk if site-heterogeneous models are not used. One well-assembled genome provides the positional anchor; a second from a different suborder (Mengenillidia vs. Stylopidia) tests ordinal monophyly.

---

## 3. TOB-specific recommendation

### Strepsiptera

Include **2 taxa**:

| Taxon | Accession | Notes |
|-------|-----------|-------|
| *Xenos peckii* (Xenidae; Stylopidia) | GCA_040167675 | N50 7.4 Mb, 72 Mb, BUSCO 87.4%; the best-assembled strepsipteran genome as of 2024 |
| *Mengenilla* sp. (Mengenillidae; Mengenillidia) | Genome available; Niehuis et al. 2012 used this lineage | Represents the free-living sister lineage; tests Strepsiptera monophyly |

The two suborders (Mengenillidia + Stylopidia) diverged deep within Strepsiptera; both are needed to avoid a single-taxon representation of the entire order. Use CAT-GTR+G4 (PhyloBayes) or at minimum LG+C60 (IQ-TREE) for any concatenation tree involving these taxa.

### Neuropterida

SCARAB already catalogs Neuroptera, Megaloptera, and Raphidioptera; TOB should include **at minimum 2 taxa per order** (6 total), sampling morphologically and ecologically disparate families:

| Order | Suggested families | Rationale |
|-------|--------------------|-----------|
| Neuroptera | Chrysopidae + Myrmeleontidae | Most species-rich; genomes available on NCBI |
| Megaloptera | Corydalidae + Sialidae | Long divergence; bracketed representation |
| Raphidioptera | Raphidiidae | Sister to Neuroptera+Megaloptera; prevents long-branch collapse |

### Distant holometabolan anchors

Add **2–3 Hymenoptera** (e.g., *Apis mellifera*, *Nasonia vitripennis*, one ant). Hymenoptera is the earliest-diverging Holometabola order (Misof et al. 2014) and provides the stable outgroup root. Optionally add 1 Lepidoptera and 1 Diptera for Holometabola-wide calibration, but these are lower priority than Hymenoptera.

### Summary outgroup composition

- 2 Strepsiptera (1 Stylopidia + 1 Mengenillidia)
- 6 Neuropterida (2 per order: Neuroptera, Megaloptera, Raphidioptera)
- 2–3 Hymenoptera

Total outgroup taxa: **10–11**, consistent with McKenna et al. 2019. This composition mirrors the only large-scale beetle phylogenomics study to include all four outgroup orders and achieved consistently high bootstrap support at basal nodes.

---

## Key references

- Niehuis O et al. 2012. Genomic and morphological evidence converge to resolve the enigma of Strepsiptera. *Current Biology* 22:1309–1313. PMID 22704986.
- Boussau B et al. 2014. Strepsiptera, phylogenomics and the long branch attraction problem. *PLOS ONE* 9:e107709. DOI [10.1371/journal.pone.0107709](https://doi.org/10.1371/journal.pone.0107709).
- Misof B et al. 2014. Phylogenomics resolves the timing and pattern of insect evolution. *Science* 346:763–767. PMID 25378627.
- Zhang S-Q et al. 2018. Evolutionary history of Coleoptera revealed by extensive sampling of genes and species. *Nature Communications* 9:205. DOI [10.1038/s41467-017-02644-4](https://doi.org/10.1038/s41467-017-02644-4).
- McKenna DD et al. 2019. The evolution and genomic basis of beetle diversity. *PNAS* 116:24729–24737. DOI [10.1073/pnas.1909655116](https://doi.org/10.1073/pnas.1909655116).
- Cai C et al. 2022. Integrated phylogenomics and fossil data illuminate the evolution of beetles. *Royal Society Open Science* 9:211771. DOI [10.1098/rsos.211771](https://doi.org/10.1098/rsos.211771).
- Winterton SL et al. 2025. Strepsiptera systematics: past, present, and future. *Insect Systematics and Diversity* 9(4):ixaf024. DOI [10.1093/isd/ixaf024](https://doi.org/10.1093/isd/ixaf024).
- Tihelka E et al. 2024. First genome assembly of the order Strepsiptera using PacBio HiFi reads reveals a miniature genome. *Scientific Data* 11:914. DOI [10.1038/s41597-024-03808-w](https://doi.org/10.1038/s41597-024-03808-w).
