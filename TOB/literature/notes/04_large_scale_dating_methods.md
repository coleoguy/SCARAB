# Large-Scale Phylogenetic Dating Methods for TOB

*Compiled 2026-05-03 for the Tree of Beetles (TOB) project, TAMU — PI: Heath Blackmon.*
*Target dataset: ~10,000–30,000 Coleoptera tips.*

---

## 1. treePL (Smith & O'Meara 2012)

**Citation:** Smith SA, O'Meara BC. 2012. treePL: divergence time estimation using penalized likelihood for large phylogenies. *Bioinformatics* 28(20):2689–2690.

**Description:** Semi-parametric penalized likelihood that places a smoothing penalty on rate variation across branches. Requires a fixed topology with branch lengths; calibrations are fossil node-age constraints. Key workflow: (1) cross-validation (CV) runs to select the optimal smoothing parameter; (2) optional priming step to identify high-impact optimisation options; (3) final dated run.

**Scalability ceiling:** Demonstrated on trees of >350,000 tips (Smith & Brown 2018 ALLMB seed-plant tree) and 31,526-tip fish tree of life (Rabosky et al. 2018 *Nature*). No hard tip-count ceiling exists in the code; wall-clock time is the binding constraint.

**Strengths:** The only method with a verified track record above 10,000 tips using node-age constraints from fossils. Open-source, runs on HPC without special hardware. Cross-validation is built in. Accepts any tree with branch lengths.

**Weaknesses:** Average run time ~52 hours per dataset (23-dataset benchmark, Barba-Montoya et al. 2022 *BMC Genomics*). Does not produce posterior distributions; the built-in `--wiggle` option (nodes within 2 log-likelihood units of optimum) captures single-parameter uncertainty only, not calibration uncertainty or branch-length estimation error. No formal confidence intervals without external resampling.

**Computational requirements:** Single-threaded by default; multi-thread option (`--nthreads`) available. Memory scales linearly with tips; Grace medium partition is sufficient for trees up to ~50k tips.

**Applicability to TOB:** Primary candidate. At 10k–30k tips, individual runs complete in 24–72 hours. Bootstrap or jackknife resampling is feasible (see Section 8).

---

## 2. MCMCTree (PAML — dos Reis & Yang)

**Citation:** dos Reis M, Yang Z. 2011. Approximate likelihood calculation on a phylogeny for Bayesian estimation of divergence times. *Mol Biol Evol* 28(7):2161–2172.

**Description:** Bayesian MCMC dating using an approximate likelihood (gradient + Hessian pre-computed from the ML tree) that is ~1000x faster than exact likelihood. Supports relaxed-clock models, multiple calibration types, and genome-scale partition matrices. IQ2MC (Demotte et al. 2025, EcoEvoRxiv) extends the workflow: IQ-TREE 3.0.1 computes the Hessian under mixture models, then MCMCTree performs MCMC sampling.

**Scalability ceiling:** Practical limit with node-dated analyses is approximately 200–500 taxa when using topology + sequence data directly. With a fixed topology (approximate likelihood only, no alignment), studies have scaled to ~500–1,000 species for genome-scale matrices. The approximate likelihood pre-computation step itself requires partitioned ML branch-length estimation, which becomes a bottleneck above ~1,000 tips with phylogenomic matrices.

**Strengths:** Full Bayesian posteriors on node ages; handles fossil calibration densities rigorously; now supports complex mixture models via IQ2MC (2025). Natural uncertainty quantification.

**Weaknesses:** Does not scale to 10,000–30,000 tips. MCMC convergence on large trees with hundreds of correlated node heights is intractable in reasonable wall-clock time even with approximate likelihood. Not viable for TOB at target scale.

**Computational requirements:** HPC with large RAM; bigmem or equivalent for genome-scale pre-computation step.

**Applicability to TOB:** Not viable at TOB scale. Useful for well-sampled subclades (~50–200 taxa) requiring posterior node-age distributions for hypothesis testing.

---

## 3. RelTime (Tamura et al. — MEGA)

**Citation:** Tamura K, Tao Q, Kumar S. 2018. Theoretical foundation of the RelTime method for estimating divergence times from variable evolutionary rates. *Mol Biol Evol* 35(7):1770–1782.

**Description:** Relative-rate framework that estimates lineage-specific rates analytically from the input tree topology and branch lengths without MCMC. Calibration constraints anchor the relative time scale. Implemented in MEGA (v11+), which is optimised for 64-bit systems and large datasets.

**Scalability ceiling:** No published hard ceiling. The 2022 benchmark (Barba-Montoya et al. *BMC Genomics*) found RelTime ran in ~0.9 hours average on the same 23 datasets where treePL took ~52 hours; RelTime was 60–100x faster. Designed to handle tens of thousands of sequences.

**Strengths:** Dramatically faster than treePL. Produces confidence intervals natively. Node age estimates statistically equivalent to Bayesian divergence times in the benchmark study. GUI (MEGA) lowers barrier to use.

**Weaknesses:** Requires MEGA GUI or command-line wrapper; less HPC-friendly than treePL. Confidence intervals are analytical approximations, not resampling-based. Calibration uncertainty handling is less flexible than MCMCTree. Accuracy on very heterogeneous rate trees (e.g., Coleoptera with parasitic lineages) has not been benchmarked above 5,000 tips.

**Computational requirements:** Single-node; MEGA binary. Very fast even on large trees.

**Applicability to TOB:** Strong runner-up. Speed makes it ideal for rapid exploratory analyses and sensitivity testing of calibration sets. Confidence intervals are available but should be validated against treePL bootstrap distributions.

---

## 4. BEAST2 with Constrained Topology + FBD

**Citation:** Bouckaert R et al. 2019. BEAST 2.5. *PLOS Comput Biol* 15(3):e1006650. FBD: Stadler et al. 2018.

**Description:** Full Bayesian divergence time estimation with Fossilized Birth-Death process. Constrained topology mode (fixed backbone) reduces dimension of MCMC space but still requires sampling thousands of correlated node heights.

**Scalability ceiling:** Practical ceiling is approximately 500–1,000 extant tips even with constrained topology and BEAGLE GPU acceleration. BEAST X (2025, *Nature Methods*) adds linear-gradient HMC kernels that accelerate sampling by ~5–10x for moderately sized trees, but have not been demonstrated above ~2,000 tips for divergence-time dating specifically.

**Strengths:** Gold-standard posteriors; handles tip-dating, sampled ancestors, complex diversification models. BEAST X (2025) implements linear-time HMC for node heights in a ratio-transformed space, materially improving convergence.

**Weaknesses:** Computationally infeasible at 10,000–30,000 tips. MCMC mixing on thousands of correlated node heights fails to converge in tractable time regardless of hardware.

**Computational requirements:** GPU cluster; weeks of wall time at moderate scale.

**Applicability to TOB:** Not applicable at full dataset scale. Reserve for deep-node calibration of 50–200 taxon sub-problems.

---

## 5. RevBayes Scalable Approaches

**Citation:** Höhna S et al. 2016. RevBayes. *Syst Biol* 65(4):726–736. Ratio-transform: Hassler G et al. 2023. Scalable Bayesian Divergence Time Estimation with Ratio Transformations. *Syst Biol* 72(5):1136–1153.

**Description:** Hassler et al. (2023) implemented a ratio transformation that maps N−1 correlated node heights to one root age + N−2 bounded ratios, enabling linear-time gradient computation and Hamiltonian Monte Carlo sampling. Demonstrated 5-fold+ efficiency gains on datasets of ~50–200 taxa (coralline algae, pathogenic viruses).

**Scalability ceiling:** Ratio-transform HMC has been demonstrated to ~200 taxa. No published application above ~500 taxa for full Bayesian divergence time estimation.

**Strengths:** Theoretically the most scalable Bayesian framework; flexible graphical model language; ratio transform is directly integrated into BEAST X (2025) as well.

**Weaknesses:** Still Bayesian MCMC; mixing at 10,000 tips remains intractable. No published demonstration at TOB scale. Steep scripting learning curve.

**Applicability to TOB:** Not applicable at full scale. Note the ratio-transform method for future use on beetle sub-tree analyses.

---

## 6. Newer Methods 2022–2026

**LSD2** (To et al. 2016, updated through 2022; integrated in IQ-TREE 2/3): Least-squares dating, designed for serial-sampled (tip-dated) sequences; scales to >10,000 tips. Primarily validated on molecular-epidemiology datasets with contemporaneous sampling — the temporal signal model differs from deep-time fossil calibration. Not well-validated for deep Coleoptera divergences.

**IQ2MC (Demotte et al. 2025):** Pipeline combining IQ-TREE 3.0.1 (for Hessian under mixture models) + MCMCTree (for MCMC). Extends MCMCTree's model flexibility but inherits its tip-count ceiling (~200–500 taxa).

**BEAST X (Baele et al. 2025, *Nature Methods*):** Linear-gradient HMC, new clock and diversification models, GPU-accelerated. A meaningful advance but still Bayesian MCMC; not demonstrated at TOB scale.

**No verified method published 2022–2026 breaks the ~1,000-tip ceiling for full Bayesian node-dating with fossil calibrations.**

---

## 7. Penalized Likelihood vs. Bayesian Tradeoffs at TOB Scale

At 10,000–30,000 tips, full Bayesian methods are computationally infeasible. Penalized likelihood (treePL) and the relative-rate framework (RelTime) are the only methods with empirical track records at this scale. The 2022 benchmark (Barba-Montoya et al.) found RelTime estimates statistically equivalent to Bayesian ages on 23 phylogenomic datasets, suggesting that point estimates from non-Bayesian methods are reliable when calibrations are adequate. The chief limitation is uncertainty quantification: neither treePL nor RelTime propagates calibration uncertainty or branch-length estimation error into node-age distributions automatically.

---

## 8. Uncertainty Intervals from treePL

treePL itself offers only the `--wiggle` flag (2 log-likelihood unit window), which characterises optimisation uncertainty around a single best solution but ignores calibration and branch-length uncertainty. Published large-tree studies use two approaches:

1. **Bootstrap distributions:** Run treePL on a set of bootstrap ML trees (100 replicates is standard). Each tree yields a dated estimate for every node; the distribution across replicates captures branch-length sampling uncertainty. Rabosky et al. (2018) built a distribution of 100 complete dated trees this way. Wall-clock cost for 100 treePL runs at TOB scale is high (~2,500–7,200 CPU-hours total) but parallelisable.

2. **Jackknife over calibrations:** Run treePL repeatedly, each time dropping one fossil calibration. Node-age variance across jackknife replicates quantifies sensitivity to individual calibration choices. Lower cost than bootstrap (N_calibrations runs); standard practice in the Smith & Brown (2018) seed-plant analyses.

Published large-tree papers typically report both: bootstrap trees provide topological/branch-length uncertainty; calibration jackknife provides fossil-constraint sensitivity.

---

## Recommendation

**Primary method: treePL.** It is the only method with a verified empirical record at >10,000 tips for deep-time, fossil-calibrated, node-dated analyses (seed plants: 356k tips; fish: 31k tips; both using treePL with fossil node constraints). It runs on Grace without special hardware and integrates directly into the IQ-TREE ML tree that TOB already produces.

**Runner-up: RelTime (MEGA).** RelTime is 60–100x faster, produces native confidence intervals, and shows equivalent accuracy to Bayesian methods in benchmarks. Use it for rapid sensitivity tests of calibration sets and as a cross-check on treePL point estimates before investing in bootstrap replicates.

**Uncertainty intervals:** Run treePL on 100 IQ-TREE bootstrap ML trees (parallelised as a SLURM array on Grace) to obtain a distribution of dated trees capturing branch-length uncertainty. Additionally run a calibration jackknife (one constraint dropped per run) to quantify fossil sensitivity. Report 95% ranges across bootstrap trees as the primary uncertainty metric, flagging nodes with high calibration-jackknife sensitivity. This two-pronged approach matches the methodology of the largest published dated phylogenies and is feasible on Grace within the 7TB scratch quota and 500-job submission limit.
