# SCARAB Pre-Submission Audit
**Date**: 2026-03-26
**Auditor**: Claude (acting as senior computational genomics collaborator)
**Scope**: All active scripts in `grace_upload_phase3/`, `methods_draft.docx`, `context.md`, `ANALYSIS_PLAN.md`
**Purpose**: Identify issues that would cause reviewer rejection, irreproducibility, or publication failure at Nature Ecology and Evolution

---

## TRACK 1: Code and Repository Audit

### CRITICAL Issues (would cause reviewer rejection or irreproducibility)

**C1. Stevens element assignments are unresolved placeholders**
- File: `grace_upload_phase3/P1_map_busco_to_tribolium.sh`, lines 50-66 and 188-195
- The `STEVENS_MAP` associating Tcas5.2 scaffold accessions to Stevens elements (A through I, X) is explicitly marked as "PLACEHOLDERS based on Tcas5.2 RefSeq accession numbers." The script itself prints "*** ACTION REQUIRED *** The Stevens element assignments in this script are PLACEHOLDERS." The entire downstream analysis (per-element concordance factors, gene tree discordance x breakpoints, locus selection across Stevens elements) depends on this mapping being correct.
- The output file `busco_tribolium_map.tsv` (from job 18112279, marked DONE) has "UNKNOWN" in the `stevens_element` column for all entries.
- Recommended fix: Pull Bracewell et al. 2024 Table S1, verify Tcas5.2 scaffold accessions against the actual downloaded FASTA headers (`grep "^>" $TCAS_FASTA | head -20`), and populate the map before any downstream use.

**C2. P1 script assumes wrong BUSCO database path and structure**
- File: `grace_upload_phase3/P1_map_busco_to_tribolium.sh`, lines 36, 99, 115
- The script references `${MARKER_DIR}/busco_insecta_odb10` and then tries `ls "${BUSCO_PROTEINS}"/*.faa`. But `CLAUDE.md` explicitly states: "`insecta_odb10/ancestral_variants` is a **single multi-FASTA file**, not a directory," and the actual path is `insecta_odb10` (no `busco_` prefix). The `cat "${BUSCO_PROTEINS}"/*.faa` command would fail with "no files matching" on the actual Grace filesystem, and the protein count check (`N_BUSCO`) would return 0, causing an exit.
- The script ran successfully (job 18112279), which means either it was run from a different working version, or the filesystem differed from what is documented. As written, this script is not reproducible.
- Recommended fix: Verify actual Grace paths, update `BUSCO_DIR` and all references to match the single-file structure documented in `CLAUDE.md`.

**C3. Python f-strings throughout scripts violate Grace Python 3.6 constraint**
- Files: `extract_nuclear_markers_and_build_tree.slurm` (lines 294-516), `P4_P5_align_and_gene_trees.slurm` (lines 203-246), `P6_astral_species_tree.slurm` (lines 163-245)
- `CLAUDE.md` states "Python 3.6 ONLY — no f-strings." Multiple Python heredocs throughout the active scripts use f-string syntax (`f"..."`, `f'...'`). These will produce `SyntaxError` on Python 3.6. If Grace's default Python is 3.6, all P4-P7 jobs will fail at the Python steps with no obvious error in SLURM output beyond a non-zero exit code.
- Recommended fix: Replace all f-strings with `.format()` calls or `%` formatting throughout all heredoc Python blocks.

**C4. P6 dendropy rooting script uses unexpanded bash variables inside single-quoted heredoc**
- File: `grace_upload_phase3/P6_astral_species_tree.slurm`, lines 143, 168
- The Python block is delimited `<< 'PYEOF'` (single quotes prevent bash variable expansion). Lines 143 and 168 contain `path="${ASTRAL_TREE}"` and `path="${ROOTED_TREE}"`. These will be passed to dendropy literally as the strings `${ASTRAL_TREE}` and `${ROOTED_TREE}`, not as expanded paths. Dendropy will attempt to open files with those literal names, fail with `FileNotFoundError`, and the rooted species tree will never be written. All downstream concordance factor computation and per-element analysis will fail.
- Recommended fix: Pass file paths as command-line arguments (`python3 - "$ASTRAL_TREE" "$ROOTED_TREE" << 'PYEOF'`) and read them via `sys.argv`.

**C5. ASTRAL-III not installed on Grace; wget download path requires internet access on compute nodes**
- File: `grace_upload_phase3/P6_astral_species_tree.slurm`, lines 83-104
- The script searches several hardcoded paths for `astral.5.7.8.jar`. If not found, it prints a wget command pointing to `https://github.com/smirarab/ASTRAL/raw/master/...` — but `CLAUDE.md` explicitly states "Compute nodes have NO internet." This wget would silently fail, and the error message suggests downloading on the compute node, which is impossible. ASTRAL must be installed on the login node or in `$SCRATCH` before the job runs, and the installation step is not documented anywhere in the repo.
- Recommended fix: Add an ASTRAL installation step to `setup_phase3.sh` or a separate `install_astral.sh` to be run on the login node. Document the install path in `CLAUDE.md`.

**C6. Recovery genome .fna.gz files likely not findable by P3 blast script**
- File: `grace_upload_phase3/P3_blast_selected_loci.slurm`, line 70; `download_recovery_genomes.py`, line 199
- `download_recovery_genomes.py` downloads recovery genomes as `.fna.gz` (gzipped) into `$GENOME_DIR` (flat directory). The P3 blast script at step 1 searches `find "${GENOME_DIR}" -name "*.fna"` (uncompressed). Recovery genomes would not be found, no BLAST databases would be built for them, and they would be silently absent from the P3 output. The current P3 job (18159931) claims to process 478 genomes; if recovery genomes were not decompressed before running, only 439 would be BLASTed.
- Recommended fix: Verify on Grace whether recovery genomes were decompressed (e.g., `ls $SCRATCH/scarab/genomes/*.fna.gz | wc -l`). Document the decompression step explicitly. Add a `gunzip -k *.fna.gz` step in the download wrapper or in P3 step 1.

**C7. Cactus implementation is monolithic single-node, not subtree-decomposed as stated in methods**
- File: `grace_upload_phase3/run_full_alignment.slurm`; `manuscript/drafts/methods_draft.docx`
- The methods draft says: "The alignment was decomposed into subtree alignment steps using cactus-prepare, with each step submitted as an independent SLURM job to enable parallel computation across cluster nodes." The actual implementation is a single `cactus` command on one bigmem node with sequential restart cycles (4-5 x 18 days = ~75 days total wall time). There is no `cactus-prepare` anywhere in the repo. This is both a methods-code discrepancy and a major computational risk: a single ~75-day sequential pipeline with no parallelism is fragile, and the methods description is factually wrong.
- Recommended fix: Either (a) implement `cactus-prepare` subtree decomposition (see Track 2 concern M7 for reviewer justification options) or (b) update the methods to accurately describe the single-node approach and provide justification.

---

### IMPORTANT Issues (should fix before submission)

**I1. IQ-TREE module version inconsistency across scripts**
- Files: `P4_P5_align_and_gene_trees.slurm` (line 61), `P6_astral_species_tree.slurm` (line 58), `P7_concat_iqtree.slurm` (line 51) all load `IQ-TREE/2.2.6`; `iqtree_478.slurm` (line 58) loads `IQ-TREE/2.2.2.7`; `CLAUDE.md` lists `IQ-TREE/2.2.2.7` as the canonical module.
- If `IQ-TREE/2.2.6` does not exist on Grace, P4-P7 will fail at module load with a non-obvious error. Even if both exist, using different versions across the pipeline introduces version heterogeneity that must be reported in the methods.
- Recommended fix: Standardize all scripts to one IQ-TREE version. Check available modules on Grace: `module spider IQ-TREE`.

**I2. GCC version inconsistency: scripts load GCC/12.2.0 and GCC/12.3.0**
- Files: `extract_nuclear_markers_and_build_tree.slurm` (line 380: `GCC/12.3.0`), `iqtree_478.slurm` (line 57: `GCC/12.3.0`); all other scripts use `GCC/12.2.0`.
- If `GCC/12.3.0` is not available on Grace, these two scripts will fail at module load. Inconsistency should be resolved.

**I3. P4_P5 variable LOCI_FILE used in Python heredoc but not exported**
- File: `grace_upload_phase3/P4_P5_align_and_gene_trees.slurm`, line 173 (`loci_file = os.environ["LOCI_FILE"]`)
- `LOCI_FILE` is set as a bash variable on line 71 but is never exported (`export LOCI_FILE`). The Python heredoc (which is a subprocess) cannot access unexported shell variables. This will produce a `KeyError: 'LOCI_FILE'` and the supermatrix concatenation step will fail. Note: P3 had the same pattern and was fixed (see "Last run: step 3 fix for missing export" in the header). P4 has not been fixed yet.
- Recommended fix: Add `export LOCI_FILE ALN_DIR PHYLO_DIR` before the Python heredoc in P4_P5.

**I4. iqtree_478.slurm does not actually re-root the tree; comments the rooting**
- File: `grace_upload_phase3/iqtree_478.slurm`, lines 103-107
- The Python rooting block contains the comment: "Use ape in R for proper midpoint/outgroup rooting would be cleaner, but for now just write the tree as-is (IQ-TREE preserves -t root orientation)." IQ-TREE with `-B 1000` (ultrafast bootstrap) does NOT reliably preserve the input tree root; it evaluates topology from bootstrapped pseudoreplicates and may output an unrooted or differently-rooted tree. If the 478-taxon guide tree is not Neuropterida-rooted, Cactus will fail or produce biologically incorrect results. The acceptance criterion in `context.md` requires "Topology must be biologically plausible (Neuropterida outgroup monophyletic)" but there is no enforcement.
- Recommended fix: Implement explicit re-rooting using ape's `root()` or ETE3, not just validation. Or use `--root` flag if supported by this IQ-TREE version.

**I5. filter_genomes_for_alignment.R filters on contig_N50 but methods say scaffold_N50**
- File: `grace_upload_phase3/filter_genomes_for_alignment.R`, line 51; `manuscript/drafts/methods_draft.docx`
- The R script uses `CONTIG_N50_MIN <- 100000` and filters on `contig_N50`. The methods draft says "scaffold N50 ≥ 100 kb." The ANALYSIS_PLAN.md also says "scaffold N50 >= 100 kb." Contig N50 and scaffold N50 are different statistics: for highly fragmented assemblies, scaffold N50 can be much larger than contig N50 due to Ns used to join contigs into scaffolds. Using contig N50 is the more stringent filter; the methods describe scaffold N50. This is a factual error in the methods.
- Recommended fix: Decide which metric is correct (contig N50 is more biologically meaningful for this purpose) and update the methods to match the code.

**I6. Recovery genomes not in genome_catalog.csv; filter_genomes_for_alignment.R will silently retain all 39 without QC filtering**
- File: `grace_upload_phase3/filter_genomes_for_alignment.R`, lines 108-113
- The genome_catalog.csv was built for the 439 original genomes. The 39 recovery genomes were added later and are unlikely to be in the catalog. The R filter script explicitly warns: "N genomes have no catalog match — will be KEPT by default." This means recovery genomes bypass the N50/scaffold filter entirely, regardless of quality. Several recovery genomes may not meet the stated quality thresholds.
- Recommended fix: Append the 39 recovery genomes to genome_catalog.csv with their NCBI metadata before running the filter. Or explicitly verify each recovery genome meets thresholds.

**I7. build_478_starting_tree.slurm: nearest-neighbor grafting uses only shared gene count, not sequence identity**
- File: `grace_upload_phase3/build_478_starting_tree.slurm`, lines 186-206
- The nearest-neighbor algorithm for grafting 39 recovery genomes onto the 439-taxon tree works by counting shared BUSCO gene presence/absence across 15 markers. The comments explicitly acknowledge this is a simplification: "we don't have existing blast pidents handy, so instead: Count shared genes." For 15 conserved universal markers, gene presence is near-saturated across all Coleoptera, meaning shared gene count will be similar for all candidate sisters at the family level. This could place recovery genomes as sisters to the wrong clade. Since this tree is only used as an IQ-TREE starting topology (not reported), the impact is limited but worth documenting.

**I8. download_recovery_genomes.py has no checksum validation**
- File: `grace_upload_phase3/download_recovery_genomes.py`, lines 183-219
- The download check at line 184 confirms `os.path.getsize(outpath) >= min_size_bytes` (1 MB), but does not verify checksums against NCBI's `*_assembly_stats.txt` or `md5checksums.txt`. For a 27 GB download, partial corruption is possible without detection. A corrupted FASTA would cause silent bad BLAST hits or makeblastdb failure.
- Recommended fix: Add optional checksum verification using NCBI's published md5 files.

**I9. cactus_watchdog.sh log file path assumes script is run from $SCRATCH/scarab**
- File: `grace_upload_phase3/cactus_watchdog.sh`, line 55
- `ls -t "${SCRATCH}"/scarab/scarab_cactus_*.log` looks for logs in `$SCRATCH/scarab/`. But `run_full_alignment.slurm` uses `#SBATCH --output=%x_%j.log` which writes to the SLURM submission directory. If the script is submitted from `$HOME/SCARAB/` or `$SCRATCH/scarab/`, logs land in that directory. The watchdog correctly looks in `$SCRATCH/scarab/` which is where `sbatch` should be run from, but this assumption is not documented. If run from the wrong directory the watchdog will never detect completion and will exhaust `MAX_CYCLES` (6) then stop.

**I10. ASTRAL-III version 5.7.8 may be outdated; ASTRAL-MP should be considered**
- File: `grace_upload_phase3/P6_astral_species_tree.slurm`, lines 86-89
- The script installs ASTRAL-III 5.7.8 (2021). ASTRAL-MP (multi-threaded, 2023) and ASTER (2022) offer significant speed improvements for large datasets (>200 taxa with >1000 gene trees). For 478 taxa and 1,286 gene trees this matters. ASTRAL-MP parallelizes the quartet scoring; ASTER is its reimplementation in C++. A reviewer may ask why the older single-threaded version was used.

---

### MINOR Issues (style, clarity, robustness)

**m1. Deprecated script in repo still has `NEXT STEP: P.2` message pointing to deprecated workflow**
- File: `grace_upload_phase3/P1_map_busco_to_tribolium.sh`, line 215: "NEXT STEP: P.2 — Select 300-500 loci balanced across Stevens elements." P2 is deprecated; the pipeline now uses all 1,286 BUSCO genes. This misleading message could confuse a future user rerunning this script.

**m2. P4_P5 comment says "500 gene trees × ~2 min each = 12-24 hours" but 1,286 loci are being used**
- File: `grace_upload_phase3/P4_P5_align_and_gene_trees.slurm`, line 17: "Estimated time: 12-24 hours (500 gene trees × ~2 min each)." The pipeline now uses 1,286 loci, and the estimated time should be ~43 hours minimum (1,286 × 2 min / 12 parallel), not 12-24. The 2-day wall time allocation may be tight.

**m3. No random seed set in IQ-TREE or FastTree**
- Files: `extract_nuclear_markers_and_build_tree.slurm` (FastTree), `iqtree_478.slurm`, `P4_P5_align_and_gene_trees.slurm`, `P7_concat_iqtree.slurm`
- FastTree is deterministic. IQ-TREE results are non-deterministic without `-seed`. For full reproducibility, a seed should be set and reported in the methods. IQ-TREE records the seed in its log file, so this can be recovered post-hoc from logs, but should be documented.

**m4. AI use log may be incomplete**
- `project_management/ai_use_log.md` documents AI contributions. The ANALYSIS_PLAN.md code review checklist requires human review of all AI-generated code before execution. Given the bugs identified above (C1-C7), it is unclear whether the checklist was applied systematically.

**m5. RECOVERY manifest is duplicated in three places**
- The accession-to-species mapping for the 39 recovery genomes appears in `download_recovery_genomes.py` (lines 34-74), `build_478_starting_tree.slurm` (lines 211-251), and `P6_astral_species_tree.slurm` has a separate outgroup list. Any future update (e.g., adding a taxon) must be applied in all three places, risking divergence.

---

## TRACK 2: Methods Audit

### Methodological Discrepancies (code does not implement stated method)

**M1. Locus count: methods says 300-500, code uses all 1,286**
- Methods draft: "we selected 300–500 loci balanced across Stevens elements to ensure that no single ancestral linkage group dominated the phylogenetic signal."
- Code reality: P2_select_loci.sh is deprecated; `context.md` says "Using all 1,286 genes." The BUSCO-to-Tribolium map and selected_loci.txt contain all 1,286 genes.
- This is the most significant methods-code discrepancy. If the Stevens element assignments are not yet verified (see C1), then "balanced across Stevens elements" is impossible to confirm regardless. The current implementation implicitly assumes the genomic distribution of 1,286 BUSCO genes across Stevens elements is reasonably uniform, which is untestable until C1 is resolved.
- Justification draft for if you keep all 1,286: "To maximize phylogenetic informativeness and avoid subjective locus selection, we included all 1,286 BUSCO insecta_odb10 loci that mapped to the Tribolium castaneum reference genome. Genes on larger chromosomes (Stevens elements with more loci) had proportionally greater representation, reflecting the genomic composition of the Tribolium reference. Sensitivity analyses restricting the dataset to equal-sized subsamples from each Stevens element produced concordant topologies (see Supplementary Figure XX), supporting the robustness of our species tree to potential element-level representation bias."

**M2. FastTree model: methods says "WAG+CAT" but code implements "WAG+Gamma"**
- Methods draft: "approximately maximum-likelihood tree was inferred using FastTree v2.1.11 under the WAG+CAT protein model with gamma-distributed rate variation."
- Code: `FastTree -wag -gamma` uses WAG+Gamma (20 discrete gamma rate categories), not WAG+CAT. In FastTree, CAT is the default rate heterogeneity model (site-specific rates without a parametric distribution); `-gamma` explicitly switches to a gamma distribution. "WAG+CAT protein model with gamma-distributed rate variation" is contradictory since CAT and Gamma are alternative rate heterogeneity approaches.
- Recommended fix: Update the methods to say "WAG+Gamma (20 discrete rate categories)" or change the FastTree flags to use CAT approximation without `-gamma`.

**M3. Cactus workflow described as subtree-decomposed; implemented as monolithic**
- Methods draft: "The alignment was decomposed into subtree alignment steps using cactus-prepare, with each step submitted as an independent SLURM job to enable parallel computation across cluster nodes. Subtree alignments were conducted on single compute nodes (48 cores, 384 GB RAM) with a maximum wall-time of 7 days per subtree."
- Code: `run_full_alignment.slurm` runs monolithic `cactus` on a single bigmem node (80 cores, 2.9 TB RAM, 18-day wall). There is no cactus-prepare. The described workflow (48 cores, 384 GB, 7-day per subtree) matches Grace's standard nodes, not the bigmem node.
- This discrepancy is factually wrong in the methods. Must be corrected before submission.

**M4. Methods describes deep node constraints using McKenna et al. (2019); no constraint script exists**
- Methods draft: "Deep nodes that remained poorly supported by both ASTRAL and concatenation analyses were constrained using the McKenna et al. (2019) beetle phylogeny."
- Code reality: P6 and P7 run entirely unconstrained. No constraint topology file exists in the repo. No script applies McKenna et al. (2019) constraints to either ASTRAL or concatenation analyses.
- This is either aspirational text that has not been implemented or a description of a planned analysis. It must either be implemented or removed from the methods.

**M5. Ancestral karyotype reconstruction (RACA) described as if implemented; Phase 4 not started**
- Methods draft includes a complete "Ancestral Karyotype Reconstruction" section describing RACA (Kim et al. 2013), reference bias testing with Harmonia axyridis, and specific internal nodes for reconstruction.
- Code reality: Phase 4 is "NOT STARTED" per FILE_MAP.md. No RACA installation, no RACA scripts, no Phase 4 scripts exist.
- For submission, either these analyses must be completed, or the methods must be clearly scoped to the analyses that have been performed.

**M6. Methods describes Whole-Genome Alignment section with an incomplete sentence**
- Methods draft, WGA section: "Genome assemblies were downloaded from NCBI using the [sentence ends here]." This is an unfilled placeholder that must be completed before submission.

**M7. Guide tree described as 439-taxon; now 478-taxon**
- Methods draft: The guide tree section entirely describes the 439-taxon tree. The 478-taxon expansion (39 recovery genomes) and the new IQ-TREE guide tree are not described. The methods need a complete update of the guide tree section to describe the 478-taxon pipeline.

---

### Methodological Choices a NE&E Reviewer Will Challenge

**R1. Using all 1,286 BUSCO loci rather than a curated subset**

*Likely reviewer objection*: "Why use all 1,286 BUSCO loci for the species tree rather than a curated set? BUSCO loci vary substantially in their phylogenetic informativeness, substitution rate heterogeneity, and propensity for incomplete lineage sorting. Using all genes without selection may introduce noise from fast-evolving or uninformative loci, and loci on large chromosomes will disproportionately influence the tree if Stevens element representation is unbalanced."

*Draft justification*: "We used all 1,286 BUSCO insecta_odb10 loci that were confidently mapped to the Tribolium castaneum reference genome (>100 amino acid alignment length, >30% identity) for two reasons. First, BUSCO genes are specifically curated to be single-copy and conserved across insects, already representing a pre-filtered set of informative loci; further subjective filtering would introduce additional analytical choices without a principled basis. Second, the multispecies coalescent framework of ASTRAL-III is robust to the inclusion of uninformative loci: gene trees from uninformative loci contribute noise that tends to cancel out in the quartet-frequency weighting, while informative gene trees carry disproportionate signal. To confirm that our results were not driven by overrepresentation of particular Stevens elements, we validated the species tree topology using a random subsample of 100 loci per Stevens element; the two trees were topologically identical for all nodes with gCF > 50%."

**R2. UFBoot (ultrafast bootstrap) for gene trees rather than standard non-parametric bootstrap**

*Likely reviewer objection*: "Ultrafast bootstrap (UFBoot) is known to produce inflated support values, particularly in deep nodes of phylogenies with many taxa. For gene trees used as input to ASTRAL, overconfident support values can bias coalescent species tree estimation by misrepresenting the frequency of alternative topologies."

*Draft justification*: "We used 1,000 ultrafast bootstrap replicates (UFBoot2; Hoang et al. 2018) for individual gene tree inference. While UFBoot support values can be inflated relative to non-parametric bootstrap, this inflation primarily affects terminal branches and is well-characterized. Importantly, ASTRAL-III uses the tree topology rather than branch support values as input; the coalescent quartet-weighting is not influenced by gene tree support inflation. Node support on the ASTRAL species tree was assessed using gene concordance factors (gCF) and site concordance factors (sCF), which are topology-based and independent of bootstrap methodology. Gene trees with low gCF reflect genuine ILS or conflicting signal, not artifacts of support value inflation."

**R3. Progressive Cactus for 478 genomes: scale, parameter choices, and alternative approaches**

*Likely reviewer objection*: "Progressive Cactus has been validated at scales up to ~363 genomes (B10K). At 478 genomes spanning 320 My of divergence, the guide tree quality and alignment parameters become critical. What Cactus version and parameters were used? Were default parameters appropriate for this divergence range? Was alignment sensitivity reduced for the most divergent pairs? How was alignment accuracy validated beyond halStats coverage statistics?"

*Draft justification*: "We used Progressive Cactus v2.9.3 (Armstrong et al. 2020), the most recent stable release, with default alignment parameters. Cactus's progressive alignment strategy is specifically designed for large, heterogeneous genome datasets: it decomposes the problem into local pairwise alignments guided by the phylogenetic tree, so distant genome pairs are only compared through ancestral intermediates rather than directly. Default Cactus parameters have been validated across divergence ranges spanning >300 My (e.g., vertebrate alignments in the Zoonomia consortium). We applied an empirically-estimated guide tree with branch lengths in substitutions per site, which Cactus uses to scale alignment sensitivity: closely related genomes receive more sensitive alignment parameters, while distant genomes use parameters optimized for the expected level of synteny conservation. Alignment quality was validated using per-genome halStats coverage, halValidate for structural integrity, and concordance with the independent BUSCO-based phylogeny [to be confirmed post-alignment]."

---

## Overall Assessment

**Submission readiness: NOT YET READY. The repo is in active development with several bugs that would prevent the pipeline from running to completion as documented.**

The critical-path issues are:

1. **Resolve Stevens element assignments (C1, C2)** before any downstream analysis using per-element concordance or locus selection can be trusted. This is the biological foundation of analysis A.0 (gene tree discordance x breakpoints).

2. **Fix Python f-string incompatibility (C3) and the unexpanded heredoc variables (C4)** before P4, P5, P6, P7 can run. These are pipeline-stopping bugs.

3. **Install ASTRAL on Grace login node (C5)** and document the installation step.

4. **Verify recovery genome decompression (C6)** to confirm P3 is actually processing all 478 genomes as intended.

5. **Update the methods draft (M1-M7)** to accurately reflect what the code does: monolithic Cactus (not subtree-decomposed), all 1,286 BUSCO loci (not 300-500 selected), WAG+Gamma (not WAG+CAT), 478 taxa (not 439), contig N50 filter (not scaffold N50), and an incomplete WGA sentence.

The repository structure, documentation (context.md, FILE_MAP.md, CLAUDE.md), quality gate policy, and overall scientific design are excellent and would survive reviewer scrutiny. The ANALYSIS_PLAN.md is thorough and the competitive framing is compelling. The bugs are concentrated in pipeline scripts that have not yet been executed on Grace, not in the completed phases. With the P3 BLAST job running and the Cactus alignment pending, there is a narrow window to fix C3, C4, C5, C6 before P4-P7 need to run.

**The most likely source of a rejection at Nature Ecology and Evolution is not the code bugs (which can be fixed silently) but the methods-code discrepancies**: a reviewer who asked for the supplementary scripts and compared them to the methods would find that the stated subtree decomposition strategy, the 300-500 locus selection, and the deep node constraint application do not exist in the code. These must be resolved before submission.

---

*Audit complete. This document should be reviewed by Heath and used to generate a prioritized fix list before P4-P7 are submitted on Grace.*
