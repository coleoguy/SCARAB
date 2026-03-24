# LR.2: Zoonomia Landscape Review — Methods & Lessons for Our Beetle Atlas

**Date:** 2026-03-21 | **Author:** Claude (AI) | **Review:** Pending Heath

---

## 1. Zoonomia Consortium: What They Did Right

The Zoonomia project (240 mammal genomes) published a suite of papers in Science (2023) that collectively set the standard for large-scale comparative genomics. Key methodological lessons:

### 1.1 Alignment Strategy
- Used **ProgressiveCactus** (Armstrong et al. 2020, Nature) for whole-genome alignment — the same tool we plan to use
- Produced a HAL-format alignment enabling arbitrary pairwise comparisons
- **Lesson:** ProgressiveCactus scales well to 200+ genomes. Our 400+ beetle genomes are ambitious but feasible with subtree decomposition

### 1.2 Constraint Identification
- Christmas et al. (2023): Identified 332 million constrained bases (~10.7% of human genome)
- Used phylogenetic conservation scoring across 240-way alignment
- **Lesson:** Even with fewer functional annotations in beetles, we can identify conserved syntenic blocks as evolutionary constraints

### 1.3 Data Release
- Made all alignments, annotations, and analysis tools publicly available
- Created reusable comparative genomics resources
- **Lesson:** Our data release (Phase 4.5) should include: alignment HAL file, synteny blocks, rearrangement calls, ancestral karyotypes, and Stevens element assignments for all species

---

## 2. Lepidoptera Model: Wright et al. (2024) — Closest Template

This is our most direct methodological template since it applies the Zoonomia approach to insects.

### 2.1 Ancestral Linkage Group Inference
- **210 chromosome-level genomes** (vs. our ~400)
- Identified **32 ancestral linkage groups ("Merian elements")** using reference-free, phylogenetically aware approach
- Found remarkable stability: most Merian elements intact over 250 My
- 8 lineages with extensive reorganization (fissions or fusion+fission)
- **Fusions biased toward shorter autosomes and Z sex chromosome**

### 2.2 Key Methodological Choices
1. **Reference-free ancestral inference:** Did NOT anchor to one reference genome; instead used phylogenetic approach. We should consider this vs. our planned RACA approach (which is reference-based)
2. **Minimum synteny block size:** Used gene-based synteny rather than raw alignment blocks
3. **Classification:** Fusions vs. fissions vs. mixed events

### 2.3 What We Can Do Better
- **More species:** ~400 vs. 210 (beetles are genomically more diverse)
- **Karyotypic diversity:** Beetles vary from 2n=4 to 2n=70+; Lepidoptera are more constrained
- **Validation:** We have the Blackmon lab karyotype database (~4,700 beetle species) for independent cross-validation. Wright et al. had no comparable resource.
- **Rate heterogeneity:** With more species and deeper phylogenetic sampling, we can better characterize rate variation

---

## 3. Stevens Elements: What's Known and What We Add

### 3.1 Current Knowledge (Bracewell et al. 2024)
- **9 Stevens elements** identified from 12 beetle genomes
- Named after Nettie Stevens (Tenebrio molitor XY discovery, 1905)
- Ancestral X chromosome conserved across all beetles examined
- Independent neo-sex chromosome formations documented
- Focus was on sex chromosome evolution, not full rearrangement atlas

### 3.2 What Our Atlas Adds
| Bracewell et al. (2024) | Our Project |
|--------------------------|-------------|
| 12 genomes | ~400 genomes |
| 5 families | 61 families |
| Stevens element assignment | Stevens element validation + extension |
| No ancestral karyotype reconstruction | Full reconstruction at 25+ nodes |
| No rearrangement rates | Branch-specific rates + hotspots |
| Sex chromosome focus | Full autosomal + sex chromosome atlas |
| No karyotype validation | Cross-validation with 4,700-species database |

### 3.3 Open Questions We Can Address
1. Are all 9 Stevens elements equally conserved across all beetle lineages, or are some more labile?
2. Are there beetle-specific rearrangement hotspots (analogous to mammalian evolutionary breakpoint regions)?
3. Do rearrangement rates correlate with speciation rates?
4. Is the fusion bias toward shorter chromosomes (seen in Lepidoptera) also present in beetles?
5. How does karyotype diversity (from cytogenetic data) compare to genome-inferred rearrangements?

---

## 4. Ancestral Karyotype Reconstruction: Damas et al. (2022) Template

### 4.1 Their Approach (Mammals)
- Used 34 genome assemblies (8 scaffolded + 26 chromosome-scale)
- Reconstructed ancestral karyotypes at 16 phylogenetic nodes
- Used RACA/DESCHRAMBLER for reconstruction
- Tested 3 different reference genomes to assess reference bias
- Found 19 ancestral autosome pairs for mammals
- Classified rearrangements per branch: inversions, fissions, fusions

### 4.2 Adaptation for Beetles
- We plan to use RACA (same tool)
- Need to consider reference bias — use Tribolium castaneum (best-annotated beetle) as primary reference
- Reconstruct at key nodes: MRCA Coleoptera, MRCA Adephaga, MRCA Polyphaga, major infraorder ancestors
- Our advantage: much denser taxon sampling within a single order

### 4.3 Methodological Concern: Reference-Free vs. Reference-Based
- **Wright et al. (Lepidoptera):** Reference-free approach
- **Damas et al. (Mammals):** Reference-based (RACA)
- **Decision needed:** We should consider doing BOTH and comparing results. Reference-free may be more appropriate for our scale.

---

## 5. Recommended Framing for Our Manuscript

### Title Options
1. "A chromosomal rearrangement atlas for the most species-rich eukaryotic order"
2. "Genome-scale synteny reveals dynamics of chromosome evolution across 400 beetle genomes"
3. "Stevens elements and the evolution of beetle karyotypes: a 400-genome atlas"

### Key Figures (Informed by Literature)
1. **Fig 1:** Phylogeny with branch-colored rearrangement rates (cf. Damas et al. Fig 3)
2. **Fig 2:** Stevens element conservation heatmap across families (novel)
3. **Fig 3:** Ancestral karyotype reconstructions at key nodes (cf. Damas et al. Fig 2)
4. **Fig 4:** Rearrangement rate vs. species diversity / karyotype diversity (novel — uses Blackmon lab data)
5. **Fig 5:** Synteny dotplots for representative pairs showing different rearrangement histories

### Key Narrative Points
1. Open with beetle diversity → genomic diversity → karyotype diversity
2. Validate Stevens elements at scale → most are conserved but some show lineage-specific instability
3. Ancestral beetle karyotype: 2n = ? (currently unknown with confidence)
4. Rearrangement rate heterogeneity across the tree → link to biological correlates
5. Comparison to Lepidoptera (Merian elements) and mammals (Damas et al.)
6. Resource value: public release for community

---

## 6. Bibliography (Sorted by Relevance to Our Project)

### Tier 1: Must-Cite (Directly Relevant)
1. Bracewell et al. (2024) PLOS Genet. Stevens elements. DOI: 10.1371/journal.pgen.1011477
2. Wright et al. (2024) Nat Eco Evo. Merian elements (Lepidoptera). DOI: 10.1038/s41559-024-02329-4
3. Damas et al. (2022) PNAS. Ancestral mammalian karyotype. DOI: 10.1073/pnas.2209139119
4. Armstrong et al. (2020) Nature. ProgressiveCactus. DOI: 10.1038/s41586-020-2871-y
5. Blackmon & Demuth (2014) Genetics. Beetle karyotype database. DOI: 10.1534/genetics.114.164269
6. Blackmon, Ross & Bachtrog (2016) J Hered. Insect karyotypes. DOI: 10.1093/jhered/esw047
7. Copeland et al. (2024) R Soc Open Sci. Dendroctonus Stevens elements. DOI: 10.1098/rsos.240755

### Tier 2: Important Context
8. Christmas et al. (2023) Science. Zoonomia constraint. DOI: 10.1126/science.abn3943
9. Foley et al. (2023) Science. Mammalian timescale. DOI: 10.1126/science.abl8189
10. Ruckman et al. (2020) PLOS Genet. Holocentric vs monocentric. DOI: 10.1371/journal.pgen.1009076
11. Toups & Viçoso (2023) Evolution. Ancient insect X. DOI: 10.1093/evolut/qpad169
12. Kim et al. (2021) eLife. 101 Drosophila genomes. DOI: 10.7554/elife.66405
13. Keeling et al. (2021) Mol Ecol Res. D. ponderosae chromosome-level. DOI: 10.1111/1755-0998.13528

### Tier 3: Methods & Tools
14. Kirilenko et al. (2023) Science. TOGA gene annotation. DOI: 10.1126/science.abn3107
15. Quigley et al. (2023) Bioinf Adv. syntenyPlotteR. DOI: 10.1093/bioadv/vbad161
16. Genereux et al. (2020) Nature. Zoonomia multitool. DOI: 10.1038/s41586-020-2876-6

---

**Last Updated:** 2026-03-21
