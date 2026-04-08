# SCARAB: Future Analyses Board

**Created**: 2026-03-28
**Purpose**: Document analyses identified during review that are deferred from Paper 1 but enabled by the current data (WGA + 1,286 BUSCO gene trees + 478-genome dataset).

Paper 1 scope: species tree (wASTRAL + concatenated LG+C60+F+R), concordance factors (gCF/sCF/sDF), Stevens element mapping at 466-genome scale, karyotype evolution cross-validated against 4,700-species cytogenetic database, gene tree discordance x breakpoint analysis.

---

## Tier 1: Next papers (enabled by current data, minimal new computation)

### 1.1 CNEE extraction and regulatory phylogenomics
- Extract conserved non-exonic elements from Cactus HAL using phastCons/phyloP (`halPhyloPTrain.py`, `halTreePhyloP.py`)
- Build CNEE-based phylogeny as independent cross-validation of BUSCO tree
- Detect lineage-specific rate shifts with PhyloAcc-GT (Yan et al. 2023, MBE)
- Note: arthropods are CNE-poor relative to vertebrates (Marletaz et al. 2024, GBE); calibrate expectations
- **Dependencies**: completed Cactus HAL

### 1.2 Full introgression pipeline
- QuIBL (Edelman et al. 2019, Science) on targeted triplets around nodes with asymmetric sDF1/sDF2
- Dsuite D-statistics with ABBA-site clustering test (Koppetsch et al. 2024, Systematic Biology) to control for rate-variation false positives
- SNaQ/PhyloNet-MPL on pruned subsets (15-25 taxa) around candidate reticulation events
- BPP MSC-I validation on focal clades (10-15 species)
- **Key caution**: D-statistics produce false positives at deep divergences due to rate variation; topology-based tests (QuIBL) should be prioritized
- **Dependencies**: completed gene trees, species tree

### 1.3 Dayhoff-6 recoding and PhyloBayes CAT-GTR validation
- Dayhoff-6 recode amino acid supermatrix to suppress compositional noise
- Run PhyloBayes-MPI CAT-GTR+G4 on taxon-reduced matrix (~50-80 taxa) around 6 contentious nodes: Cucujiformia backbone, Staphyliniformia composition, Nosodendridae position, Elateroidea internal structure, Derodontiformia polyphyly, suborder interrelationships
- Posterior predictive analyses for model adequacy (saturation, diversity tests)
- **Dependencies**: completed supermatrix

### 1.4 CAT-PMSF supermatrix tree
- Short PhyloBayes guide run to export site-specific frequency profiles
- Apply PMSF profiles in IQ-TREE on full supermatrix (Szantho et al. 2023, Systematic Biology)
- More rigorous than LG+C60+F+R; deploy if reviewers request stronger model adequacy
- **Dependencies**: completed supermatrix

### 1.5 Sensitivity analyses
- Subsample 100 loci per Stevens element, compare topology to full tree (RF distance, 10 replicates)
- RY-recoding of third codon positions in nucleotide alignments
- Gene-level filtering: remove loci with extreme GC-content or rate heterogeneity
- Observed variability (OV) sorting to remove fast-evolving sites
- IQ-TREE chi-square composition test to flag taxa failing homogeneity
- **Dependencies**: completed gene trees, Stevens element mapping

### 1.6 Gene tree discordance along Stevens elements and genome coordinates
- **What we prototyped (2026-04-04)**: preliminary quartet topology scoring and RF distance mapping using local gene trees + wASTRAL species tree. Scripts in `/tmp/` (not yet saved to repo). Results are suggestive but need polishing for publication.
- **Analyses to formalize:**
  1. **RF discordance by element**: Kruskal-Wallis + pairwise Wilcoxon of normalized RF(gene tree, species tree) across 9 Stevens elements. Preliminary result: no significant variation (p=0.62), Element H borderline (p=0.066). Redo after sCF/gCF are final.
  2. **RF along physical coordinates**: Plot nRF at each locus's Tribolium chromosomal position with loess smoothing per element. Preliminary: Element C hotspot at 10–15 Mb. Need to control for gene density, alignment length, missing taxa.
  3. **Quartet topology proportions at contested nodes**: For each node, sample 4-taxon quartets from gene trees, score 3 possible unrooted topologies (5 replicates, majority vote). Nodes tested so far:
     - Node 1 (Polyphaga backbone): Haplogastra 61.1% — moderately supported
     - Node 2 (Buprestoidea): sister to Elateroidea 84.4% — strongly resolved
     - Node 3 (Lampyridae–Elateridae): fireflies within click beetles 54.3% — weakly supported
     - Node 4 (Silphidae–Staphylinidae): nested within rove beetles 42.2% — essentially unresolved
     - Node 5 (Lucanidae–Scarabaeidae): sister to scarabs 69.3% — well supported
  4. **Sliding window topology proportions along genome**: 20 Mb windows, proportion of each topology along concatenated genome. Preliminary plots exist for nodes 1–2. Extend to all 5 nodes.
  5. **Per-element topology summaries**: Test whether certain elements consistently favor alternative topologies (chi-square or Fisher's exact per element × topology).
- **Novelty**: No beetle study has mapped phylogenetic conflict onto ancestral chromosomal elements. Closest precedent: Herrig & Linnen 2024 (Syst Biol) painted sCF onto sawfly chromosomes (~8 spp), but without ancestral linkage groups. Quartet topology scoring per Stevens element appears novel for any organism.
- **Comparison to field**: Zhang 2018 (95 loci, concatenation only), McKenna 2019 (concatenation only), Cai 2022 (CAT-GTR, no coalescent), Bergsten 2025 (149 taxa, gCF+sCF but no chromosomal mapping), Creedy 2025 (BUSCO from SRA, no discordance mapping). SCARAB's 478 WGS + element-level discordance analysis is unprecedented.
- **Dependencies**: completed gene trees, wASTRAL species tree, Stevens element mapping, sCF/gCF (from P6)
- **Scripts to save**: `/tmp/rf_analysis.R`, `/tmp/rf_along_chrom.R`, `/tmp/topology_along_genome.R`, `/tmp/real_contentious.R`, `/tmp/scan_contentious_nodes.R`, `/tmp/deep_backbone.R`, `/tmp/check_contested_nodes.R`

---

## Tier 2: Major follow-up projects (substantial new analysis required)

### 2.1 HGT/PCWDE mapping
- Trace horizontal gene transfer of plant cell wall-degrading enzymes (pectinases, GH28) across WGA
- Map chromosomal integration sites, tandem duplications, copy-number expansions
- Test synchrony between PCWDE expansion and diversification rate shifts (BAMM/RevBayes)
- Extends McKenna et al. 2019 (PNAS)
- **Dependencies**: completed Cactus HAL, time-calibrated tree

### 2.2 Neo-sex chromosome evolution
- Use WGA structural variation to trace autosome-sex chromosome fusions
- Map TE accumulation on neo-Y chromosomes
- Document dosage compensation evolution across lineages
- Cross-validate with cytogenetic database (70+ independent Y losses in beetles vs 12 in Diptera)
- Test link between neo-XY formation and speciation rates
- **Dependencies**: completed Cactus HAL, Stevens element assignments

### 2.3 Regulatory rewiring (evo-devo)
- PhyloAcc-GT on CNEEs to identify accelerated elements at nodes of morphological innovation
- Target phenotypes: elytra evolution, bioluminescence in Elateroidea, horn development in Scarabaeinae, aquatic adaptation in Adephaga, miniaturization events
- Frame as: beetle diversity driven by regulatory modularity, not novel gene invention
- **Dependencies**: CNEE extraction (1.1), completed HAL

### 2.4 RACA ancestral karyotype reconstruction
- Full RACA pipeline (Kim et al. 2013) at 25+ internal nodes
- Reference bias testing with alternative references (Harmonia axyridis, not just Tribolium)
- Ancestral chromosome painting
- **Dependencies**: completed Cactus HAL, robust species tree

### 2.5 Diversification rate analysis
- ClaDS, BAMM, HiSSE for trait-dependent diversification
- Test hypotheses for: herbivory, flight loss, karyotype number, genome size, TE content
- Ikeda et al. 2012: flightless beetles have 2x speciation rate
- Condamine et al. 2016: Coleoptera has constant diversification (unlike other hyperdiverse orders)
- **Dependencies**: time-calibrated tree, trait database

---

## Tier 3: Opportunistic (cutting-edge methods, may require method development)

### 3.1 TRAILS v2 HMM
- Base-pair-level ILS vs introgression discrimination along Cactus WGA contigs
- Expanded hidden state space for pulse-like unidirectional introgression
- Previously restricted to population genetics; WGA enables application at species level
- **Dependencies**: completed Cactus HAL, calibrated species tree

### 3.2 TOGA ortholog inference
- Genome-wide gene loss detection and selection screens from Cactus alignment (Kirilenko et al. 2023)
- Applied to 488 mammals and 501 birds; no insect application yet
- **Dependencies**: completed Cactus HAL

### 3.3 CASTER alignment-based coalescent
- Apply CASTER (ASTER package) directly to WGA-extracted regions
- Bypasses gene tree estimation step entirely; promising for rapid radiations with high GTEE
- **Dependencies**: completed Cactus HAL

### 3.4 Network inference at scale
- CAMUS algorithm (Warnow group, 2026 preprint) for level-1 networks on 100-200 taxa subsets
- Currently only method that scales beyond 25 taxa
- **Dependencies**: completed gene trees

### 3.5 IQ-TREE 3 advanced models
- MixtureFinder (`-m MIX+MF`) for automated DNA mixture model selection
- GTRpmix+C60+F+R for exchangeability matrices under profile mixtures (Banos et al. 2024, MBE)
- MAST model for mixtures across sites and trees
- GHOST model for heterotachy (rate variation across lineages through time)
- **Dependencies**: IQ-TREE 3 release (currently EcoEvoRxiv preprint)

---

## Key references

- Armstrong et al. 2020, Nature (Progressive Cactus)
- Cai, Tihelka, Giacomelli et al. 2022, R Soc Open Sci (model adequacy in beetles)
- Christmas et al. 2023, Science (Zoonomia)
- Edelman et al. 2019, Science (QuIBL, Heliconius introgression)
- Hoff et al. 2024, PLOS Genetics (Stevens elements, 12 genomes)
- Koppetsch, Malinsky & Matschiner 2024, Syst Biol (D-statistic false positives)
- Lanfear, Hahn & Minh 2024, MBE (concordance vectors)
- Stiller et al. 2024, Nature (B10K)
- Szantho et al. 2023, Syst Biol (CAT-PMSF)
- Wong et al. 2025, EcoEvoRxiv (IQ-TREE 3)
- Zhang & Mirarab 2022, MBE (wASTRAL)
- Bergsten et al. 2025, Syst Entomol (Dytiscidae WGS phylogenomics, gCF/sCF)
- Creedy et al. 2025, Syst Biol (Coleoptera BUSCO from SRA mining)
- Herrig & Linnen 2024, Syst Biol (sCF painted onto sawfly chromosomes)
