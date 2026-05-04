# Recent Coleoptera Phylogenomics (2023–2026)

Literature survey for TOB (Tree of Beetles) — compiled 2026-05-03.
All papers verified via PubMed, bioRxiv API, or direct web confirmation. No unverified citations included.

---

## 1. Creedy et al. (2025/2026) — Nuclear + Mitochondrial Phylogenomics, Key Classification Nodes

**Citation:** Creedy, T.J., Ding, Y., Gregory, K.M., Swaby, L., Zhang, F., & Vogler, A.P. (2025). Bioinformatics of combined nuclear and mitochondrial phylogenomics to define key nodes for the classification of Coleoptera. *Systematic Biology*, 75(3): 445–467. DOI: [10.1093/sysbio/syaf031](https://doi.org/10.1093/sysbio/syaf031)

The most comprehensive recent backbone phylogeny of Coleoptera. Vogler's group (Imperial College) mined >2,000 BUSCO loci from 119 genome-sequenced exemplars covering all four suborders and all 16 recognized Polyphaga superfamilies (78 families total, 527,095 amino acid sites from 2,127 loci). They combined these nuclear results with 492 mitogenomes under a backbone constraint, producing a high-coverage family-level tree. Comparison across three recent nuclear studies revealed >80 universally supported nodes — a set of "hard" topological agreements that now constitute a stable backbone for higher classification. Polyphaga series arrangement follows (Scirtiformia (Elateriformia (Staphyliniformia+Scarabaeiformia (Bostrichiformia, Cucujiformia)))). Scarabaeiformia is nested within Staphyliniformia, consistent with Cai et al. 2022. Mitogenomes served as an independent arbitrating character set for nodes where nuclear analyses conflicted. Preprint posted October 2024 (bioRxiv 2024.10.26.620449).

**Implication for TOB:** This is the primary reference for hard topological constraints on the backbone; the >80 universal nodes should anchor any TOB constraint tree and define the scaffold for Tier 1/2 backbone placement.

---

## 2. Boudinot et al. (2023) vs. Cai et al. (2024) — Compositional Bias Debate

**Citation (critique):** Boudinot, B.E., Fikáček, M., Lieberman, Z., Kusy, D., Bocak, L., McKenna, D.D., & Beutel, R.G. (2023). Systematic bias and the phylogeny of Coleoptera — a response to Cai et al. (2022) following the responses to Cai et al. (2020). *Systematic Entomology*, 48(2): 223–232. DOI: [10.1111/syen.12570](https://doi.org/10.1111/syen.12570)

**Citation (reply):** Cai, C., Tihelka, E., Pisani, D., & Donoghue, P.C.J. (2024). Resolving incongruences in insect phylogenomics: a reply to Boudinot et al. (2023). *Palaeoentomology*, 7(2). URL: [https://mapress.com/pe/article/view/palaeoentomology.7.2.2](https://mapress.com/pe/article/view/palaeoentomology.7.2.2)

This exchange represents the central methodological controversy in current Coleoptera systematics. Boudinot et al. challenged Cai et al.'s (2022) reanalysis of the Zhang et al. (2018) dataset, arguing that applying CAT-GTR and compositional filtering obfuscates rather than illuminates beetle phylogeny, and that several of Cai's topological claims are unsupported or misleading. They are particularly critical of Cai's proposed changes to higher classification. Cai et al. replied in 2024 demonstrating that removal of the most compositionally heterogeneous sites and use of site-heterogeneous mixture models consistently recovers topologies more congruent with morphological evidence and fossil placements, including the controversial placement of Scarabaeiformia within Staphyliniformia.

**Implication for TOB:** This debate directly affects which higher-level topology TOB should adopt; Cai's heterogeneous-model topology (which places Scarabaeiformia inside Staphyliniformia) appears more morphologically grounded but remains contested by McKenna/Beutel/Boudinot — both topologies should be tested as constraint alternatives.

---

## 3. Li, Engel, Tihelka & Cai (2023) — Weevil Phylogenomics, Compositional Heterogeneity

**Citation:** Li, Y.-D., Engel, M.S., Tihelka, E., & Cai, C. (2023). Phylogenomics of weevils revisited: data curation and modelling compositional heterogeneity. *Biology Letters*, 19(9): 20230307. DOI: [10.1098/rsbl.2023.0307](https://doi.org/10.1098/rsbl.2023.0307) (PubMed PMID: 37727076)

Reanalysis of genome-scale anchored hybrid enrichment (AHE) data for Curculionoidea (weevils, the most species-rich beetle superfamily). A prior phylogenomic study had placed Belidae anomalously as sister to Nemonychidae+Anthribidae — contradicting morphology. Using CAT-GTR or compositionally filtered datasets, Belidae consistently moved to its morphologically supported position: sister to (Attelabidae, (Caridae, (Brentidae, Curculionidae))). This paper is a concrete demonstration that ignoring across-site compositional heterogeneity produces strong but artifactual placements in beetle datasets, and that data curation plus site-heterogeneous models resolves them.

**Implication for TOB:** Confirms that AHE/UCE datasets for Curculionoidea require heterogeneous model treatment; relevant for any backbone calibration or constraint node involving the largest beetle superfamily.

---

## 4. Li et al. (2024) — Cucujiformia Comprehensive Phylogenomics

**Citation:** Li, X.-H., Li, R.-F., Hu, F.-J., Zheng, S., Rao, F.-Q., An, R., Li, Y.-H., & Liu, D.-G. (2024). Comprehensive phylogenomic analyses revealed higher-level phylogenetic relationships within the Cucujiformia. *Journal of Systematics and Evolution*, 62(6): 1137–1149. DOI: [10.1111/jse.13079](https://doi.org/10.1111/jse.13079)

Large-scale transcriptome study of 143 Cucujiformia species (569,990+ amino acid sites), including three newly sequenced Curculionoidea genomes. Recovered superfamily topology: (Coccinelloidea, (Cleroidea, ((Lymexyloidea, Tenebrionoidea), (Erotyloidea, (Nitiduloidea, (Cucujoidea, (Chrysomeloidea, Curculionoidea))))))). The placement of Lymexyloidea as sister to Tenebrionoidea (rather than as isolated basally within Cucujiformia) is the key novel result. Divergence time analyses place the origin of Cucujiformia in the Permian with most superfamilies arising in the Jurassic–Cretaceous. An independently published study (Batelka et al. 2025, below) corroborates the Lymexyloidea+Tenebrionoidea clade with denser taxon sampling.

**Implication for TOB:** Establishes the superfamily scaffold for ~170,000 Cucujiformia species; TOB Tier 3 placements of Sanger-only taxa in Cucujiformia can follow this backbone.

---

## 5. Batelka, Kundrata & Straka (2025) — Lymexyloidea + Tenebrionoidea Phylogenomics

**Citation:** Batelka, J., Kundrata, R., & Straka, J. (2025). Phylogenomics and revised classification of Lymexyloidea and Tenebrionoidea (Coleoptera: Polyphaga: Cucujiformia). *Systematic Entomology*, 50(4): 794–812. DOI: [10.1111/syen.12683](https://doi.org/10.1111/syen.12683)

Dense taxon sampling (six lymexylids, 10 ripiphorids, three mordellids) confirms Lymexyloidea as sister to Tenebrionoidea — corroborating Li et al. (2024) with independent data. Within Tenebrionoidea, Ripiphoridae + Mordellidae form a "mordelloid clade" sister to all remaining tenebrionoids. Ripiphoridae recovered as monophyletic (contra some prior studies). Formal classification changes: Hylecoetidae sensu nov. raised to accommodate Hylecoetinae + Melittommatinae distinct from Lymexylidae.

**Implication for TOB:** Provides the most current, denser reference for Tenebrionoidea topology; relevant for constraint tree construction and classification matching in Tier 3.

---

## 6. Dietz et al. (2023) — Scarabaeoidea Transcriptome Phylogeny

**Citation:** Dietz, L., Seidel, M., Eberle, J., Misof, B., Pacheco, T.L., Podsiadlowski, L., Ranasinghe, S., Gunter, N.L., Niehuis, O., Mayer, C., & Ahrens, D. (2023). A transcriptome-based phylogeny of Scarabaeoidea confirms the sister group relationship of dung beetles and phytophagous pleurostict scarabs (Coleoptera). *Systematic Entomology*, 48(4): 672–686. DOI: [10.1111/syen.12602](https://doi.org/10.1111/syen.12602) (bioRxiv: 10.1101/2023.03.11.532172)

Phylogenetic analyses of >4,000 genes mined from transcriptomes of >50 Scarabaeidae and Scarabaeoidea species (including Niehuis as co-author). Confirmed monophyly of Scarabaeidae and the sister-group relationship between dung beetles (Scarabaeinae) and phytophagous pleurostict scarabs — a previously contested node. Found Melolonthinae to be paraphyletic, proposing restoration of Sericinae and Sericoidinae as separate subfamilies forming a monophyletic clade sister to other pleurostict scarabs except Orphninae. Non-monophyly of Scarabaeidae in some prior analyses shown to be long-branch attraction artifact between outgroup and long-branched dung beetles.

**Implication for TOB:** Resolves a contested node within Staphyliniformia sensu lato; relevant for any Scarabaeoidea-rich lineage in TOB Tier 1/2 backbone.

---

## 7. Li et al. (2024, McKenna lab) — Belidae Phylogenomics and Gondwana Biogeography

**Citation:** Li, X., Marvaldi, A.E., Oberprieler, R.G., Clarke, D., Farrell, B.D., Sequeira, A., Ferrer, M.S., O'Brien, C., Salzman, S., Shin, S., Tang, W., & McKenna, D.D. (2024). The evolutionary history of the ancient weevil family Belidae (Coleoptera: Curculionoidea) reveals the marks of Gondwana breakup and major floristic turnovers, including the rise of angiosperms. *eLife*, 13: RP97552. DOI: [10.7554/eLife.97552](https://doi.org/10.7554/eLife.97552) (PubMed PMID: 39665616)

McKenna lab integrated phylogenomic + Sanger data for all seven Belidae tribes (60% of extant genera). Crown Belidae originated ~138 Ma in Gondwana on Pinopsida. Vicariance tracked Gondwana breakup; subsequent host shifts to angiosperms and cycads occurred as conifers declined regionally. Provides time-calibrated phylogeny for this basal Curculionoidea lineage. Independently supports the morphologically expected Belidae placement (sister to higher Curculionoidea, consistent with Li et al. 2023 above using CAT-GTR).

**Implication for TOB:** Adds fossil calibrations and biogeographic context for basal Curculionoidea; McKenna lab's continued engagement with weevil phylogenomics is directly relevant to TOB's largest Tier 3 sampling challenge (Curculionidae is the largest beetle family).

---

## 8. Beutel et al. (2024) — Palaeozoic/Mesozoic Coleoptera History (with McKenna, Kundrata, Boudinot)

**Citation:** Beutel, R.G., Xu, X., Jarzembowski, E.A., Kundrata, R., Boudinot, B.E., McKenna, D.D., & Goczał, J. (2024). The evolutionary history of Coleoptera (Insecta) in the late Palaeozoic and the Mesozoic. *Systematic Entomology*, 49(3): 355–388. DOI: [10.1111/syen.12623](https://doi.org/10.1111/syen.12623)

Comprehensive synthesis of ~300 My of Coleoptera fossil history, written by a coalition including the principal antagonists of the Cai-Boudinot debate (McKenna and Boudinot alongside Beutel). Key palaeontological conclusions: tight elytral fit and epipleura originated Middle Permian; Adephaga+Myxophaga diversified first in the Triassic; Polyphaga is Triassic–Jurassic in first appearance, with Cucujiformia appearing only by the Cretaceous. Summarizes which subordinal and superfamilial nodes are supported by fossil morphology vs. molecular-only evidence. Authors note ongoing tension between compositional-model-based topologies and the fossil/morphological record, without fully endorsing either position.

**Implication for TOB:** Establishes the stratigraphic bracketing for deep divergences — directly relevant for treePL calibration strategy; also signals that the Cai vs. McKenna topological controversy is not yet resolved even within a joint authorship.

---

## Synthesis: Current Consensus and Contested Nodes

The 2023–2026 literature shows meaningful convergence on several aspects of Coleoptera deep phylogenetics while leaving others unresolved.

**Areas of consensus.** Monophyly of all four suborders (Archostemata, Myxophaga, Adephaga, Polyphaga) is now uncontested across all recent nuclear phylogenomic studies. The position of Polyphaga as the largest and most derived suborder is universally recovered. Within Polyphaga, Scirtiformia as the earliest-diverging series and Cucujiformia as the most derived series are consistent across Cai et al. 2022, Creedy et al. 2025, and Li et al. 2024. The Creedy et al. (2025) identification of >80 universally supported nodes across nuclear and mitochondrial datasets provides the first empirical list of "hard" agreement nodes for classification. Within Cucujiformia, convergence is emerging around Lymexyloidea+Tenebrionoidea (Li et al. 2024; Batelka et al. 2025) and (Chrysomeloidea, Curculionoidea) as the most derived clade. The sister-group relationship of dung beetles and pleurostict scarabs within Scarabaeoidea (Dietz et al. 2023) is now strongly supported.

**Areas of active dispute.** The position of Scarabaeiformia — whether nested within Staphyliniformia (Cai et al. 2022 and replicated by Creedy et al. 2025) or treated separately — remains debated: morphologists and the McKenna/Beutel/Boudinot coalition continue to prefer the traditional separation, while Cai's mixture-model analyses consistently recover nesting. The suborder-level topology for non-Polyphaga beetles (specifically whether Adephaga is sister to Myxophaga+Archostemata, or other arrangements) carries residual uncertainty driven by long-branch effects and sparse Archostemata/Myxophaga genome sampling. The correct placement of Belidae within Curculionoidea appears largely resolved by model-aware analysis (Li et al. 2023; Li et al. 2024), but highlights a broader unresolved issue: early-diverging Curculionoidea relationships depend heavily on which substitution model is applied, with standard GTR yielding artifactual placements. The fundamental methodological dispute — whether CAT-GTR and compositional filtering reveal signal or introduce artifacts — is unresolved and will require additional genome data for poorly sampled lineages (especially Archostemata and Myxophaga) and benchmark datasets to adjudicate.
