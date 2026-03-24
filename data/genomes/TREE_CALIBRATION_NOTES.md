# Constraint Tree Calibration Notes

## Files
- `constraint_tree.nwk` — Original tree with uniform branch lengths (1.0)
- `constraint_tree_calibrated.nwk` — Calibrated tree with approximate divergence times (Ma)
- `tree_tip_mapping.csv` — Maps tip labels to accessions, families, clades
- `calibrate_tree.py` — Script that performed the calibration (archived in scripts/phase2/)

## Why Calibrate?

ProgressiveCactus uses branch lengths in the guide tree to tune alignment sensitivity parameters. With uniform branch lengths, Cactus treats all pairs as equally divergent, which is suboptimal when the tree spans from congeneric species pairs (~5–10 Ma divergence) to beetle-neuropterid splits (~320 Ma). Calibrated branch lengths allow Cactus to use more sensitive alignment parameters for closely related taxa and more permissive parameters for deep divergences.

## Calibration Method

Approximate divergence times were assigned to key nodes using published molecular clock estimates, then interpolated across the remaining internal nodes.

### Primary Calibration Sources

1. **McKenna et al. (2019)** "The evolution and genomic basis of beetle diversity." *Systematic Entomology* 44(4): 939–966. doi:10.1111/syen.12386
   - Coleoptera crown age: ~268 Ma (early–mid Permian)
   - Adephaga crown: ~215 Ma (Triassic)
   - Polyphaga series-level divergences: 175–195 Ma (Jurassic)
   - Major family crown ages

2. **Zhang et al. (2018)** "The evolution of insect biodiversity." *Current Biology* 28(19): R1167–R1172. doi:10.1016/j.cub.2018.09.044
   - Holometabola divergence times
   - Coleoptera–Neuropterida split: ~320 Ma (Carboniferous)

3. **Hunt et al. (2007)** "A comprehensive phylogeny of beetles reveals the evolutionary origins of a superradiation." *Science* 318(5858): 1913–1916. doi:10.1126/science.1146954
   - Suborder-level divergence times
   - Family-level calibrations

4. **Misof et al. (2014)** "Phylogenomics resolves the timing and pattern of insect evolution." *Science* 346(6210): 763–767. doi:10.1126/science.1257570
   - Deep insect divergence times (Coleoptera–Neuropterida)

### Calibration Points Applied

| Node (MRCA of) | Age (Ma) | Source | Period |
|---|---|---|---|
| Root (Coleoptera + Neuropterida) | 320 | Zhang et al. 2018 | Carboniferous |
| Neuropterida | 300 | Misof et al. 2014 | Late Carboniferous |
| Coleoptera crown | 268 | McKenna et al. 2019 | Early Permian |
| Adephaga | 215 | McKenna et al. 2019 | Triassic |
| Cucujiformia | 195 | McKenna et al. 2019 | Early Jurassic |
| Elateriformia | 190 | McKenna et al. 2019 | Early Jurassic |
| Staphyliniformia | 185 | McKenna et al. 2019 | Early Jurassic |
| Scarabaeiformia | 175 | McKenna et al. 2019 | Jurassic |
| Carabidae | 160 | Hunt et al. 2007 | Late Jurassic |
| Chrysopidae | 150 | Misof et al. 2014 | Late Jurassic |
| Staphylinidae | 140 | McKenna et al. 2019 | Early Cretaceous |
| Hydrophilidae | 140 | McKenna et al. 2019 | Early Cretaceous |
| Buprestidae | 140 | McKenna et al. 2019 | Early Cretaceous |
| Tenebrionidae | 130 | McKenna et al. 2019 | Early Cretaceous |
| Elateridae | 130 | McKenna et al. 2019 | Early Cretaceous |
| Geotrupidae | 130 | McKenna et al. 2019 | Early Cretaceous |
| Leiodidae | 130 | McKenna et al. 2019 | Early Cretaceous |
| Cerambycidae | 120 | McKenna et al. 2019 | Cretaceous |
| Scarabaeidae | 120 | McKenna et al. 2019 | Cretaceous |
| Silphidae | 120 | McKenna et al. 2019 | Cretaceous |
| Curculionidae | 115 | McKenna et al. 2019 | Cretaceous |
| Cantharidae | 110 | McKenna et al. 2019 | Cretaceous |
| Chrysomelidae | 100 | McKenna et al. 2019 | Mid-Cretaceous |
| Lampyridae | 100 | McKenna et al. 2019 | Mid-Cretaceous |
| Anthribidae | 100 | McKenna et al. 2019 | Mid-Cretaceous |
| Lucanidae | 90 | Hunt et al. 2007 | Late Cretaceous |
| Meloidae | 90 | McKenna et al. 2019 | Late Cretaceous |
| Corydalidae | 180 | Misof et al. 2014 | Early Jurassic |
| Coccinellidae | 80 | McKenna et al. 2019 | Late Cretaceous |

### Interpolation

Uncalibrated internal nodes were placed at the midpoint between their parent's age and the oldest calibrated descendant's age. This produces a smooth, monotonically decreasing set of node depths. Minimum branch length was set to 0.1 Ma to avoid zero-length branches.

### Resulting Tree Properties

- Tips: 439
- Root age: 320 Ma
- Branch length range: ~5.5–225 Ma
- Mean branch length: ~101 Ma
- Tree is ultrametric (all root-to-tip distances = 320 Ma)

### Caveats

1. These are **approximate** divergence times used solely to parameterize the Cactus alignment. They are NOT the subject of biological analysis in this paper.
2. The constraint tree topology is from McKenna et al. (2019) with species grafted onto family-level polytomies. Within-family relationships are unresolved.
3. Branch lengths represent geologic time, not substitution rates. Cactus uses them to estimate expected divergence, which is appropriate for scaling alignment sensitivity.
4. For the rearrangement rate analysis (Phase 4), branch lengths will be re-estimated from alignment data.

---

*Created: 2026-03-21 | SCARAB Project | calibrate_tree.py*
