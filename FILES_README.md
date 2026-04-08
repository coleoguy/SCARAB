# SCARAB — Script and File Index

## Active Scripts

### grace_upload_phase3/ — Production HPC Scripts (Grace)

| Script | Description |
|--------|-------------|
| `build_seqfile.sh` | Build Cactus seqFile mapping tree tip labels to genome FASTA paths |
| `cactus_watchdog.sh` | Auto-resubmit Cactus alignment jobs that hit wall time (runs in tmux on login node) |
| `download_recovery_genomes.py` | Download 39 recovery genomes from NCBI FTP with resume support (Python 3.6) |
| `download_recovery_genomes.sh` | SLURM wrapper to download recovery genomes on Grace transfer partition |
| `download_rnaseq.sh` | Download RNA-seq FASTQs from ENA for 65 species (4 parallel wget, login node) |
| `filter_genomes_for_alignment.R` | Apply contig N50 and scaffold count thresholds; produce filtered seqfile and pruned tree |
| `P1_map_busco_to_tribolium.sh` | Map 1,367 BUSCO insecta proteins to Tribolium; assign Stevens ancestral elements |
| `prepare_nuclear_markers.sh` | Download BUSCO insecta marker genes for guide tree construction |
| `run_cactus_decomposed.py` | Level-by-level Cactus alignment with inter-level QC gates; submits SLURM array jobs |
| `setup_phase3.sh` | One-step setup: create directories, pull Cactus container, build seqFile, run cactus-prepare |

### scripts/phase2/ — Genome Inventory and Tree Calibration (Local)

| Script | Description |
|--------|-------------|
| `calibrate_tree.py` | Assign divergence-time branch lengths using McKenna et al. (2019) beetle phylogeny |
| `calibrate_tree.R` | R version of branch-length calibration for the SCARAB constraint tree |
| `download_genomes.sh` | Deprecated standalone genome download script |
| `download_login.sh` | Download 438 genomes from NCBI on Grace login node (4 parallel curl) |
| `validate_downloads.sh` | Verify all genomes downloaded with valid FASTA content |

### scripts/phase3/ — RNA-seq and Phylogenomics (Local)

| Script | Description |
|--------|-------------|
| `query_sra_rnaseq.py` | Survey NCBI SRA for male/female RNA-seq across all 478 species (Entrez E-utilities) |
| `query_sra_runs_detailed.py` | Fetch per-run SRR metadata (sex, tissue, spots, layout) for 53 both-sex species |
| `query_sra_singlesex.py` | Fetch per-run SRR metadata for 47 male-only and female-only species |
| `select_rnaseq_runs.py` | Select best RNA-seq runs per species; construct ENA download URLs; 3 tiers |
| `sensitivity_subsample.R` | Test species tree robustness by subsampling equal loci per Stevens element |
| `summarize_gcf.R` | Summarize gene concordance factors: distribution, discordance symmetry, top/bottom branches |

### scripts/phase4/ — Rearrangement Analysis (Local)

| Script | Description |
|--------|-------------|
| `discordance_x_breakpoints.R` | Test correlation between gene tree discordance and chromosomal breakpoints |

### scripts/phase4/exploratory/ — Preliminary Discordance and Topology Analyses

| Script | Description |
|--------|-------------|
| `rf_analysis.R` | Robinson-Foulds discordance between gene trees and species tree, by Stevens element |
| `rf_along_chrom.R` | Plot RF discordance along Tribolium chromosomal coordinates with loess smoothing |
| `topology_along_genome.R` | Sliding-window topology proportions along genome for contested nodes |
| `real_contentious.R` | Quartet topology scoring at 5 contested beetle nodes with per-element breakdowns |
| `scan_contentious_nodes.R` | Automated scan for nodes with high gene tree conflict in species tree |
| `deep_backbone.R` | Quartet analysis focused on deep Polyphaga backbone relationships |
| `check_contested_nodes.R` | Quick check of support for specific contested relationships |

## Phase Pipeline Scripts

### phases/phase2_genome_inventory/ — Genome Catalog Assembly

| Script | Description |
|--------|-------------|
| `PHASE_1.1_ncbi_mining/ncbi_mine.R` | Download NCBI assembly_summary; filter Coleoptera scaffold+ from 2018+; capture Neuropterida |
| `PHASE_1.2_ensembl_mining/ensembl_mine.R` | Query Ensembl REST API for Coleoptera genomes; extract metadata |
| `PHASE_1.3_merge_deduplicate/merge_genomes.R` | Merge NCBI + Ensembl assemblies; select best per species (RefSeq > GenBank) |
| `PHASE_1.3_merge_deduplicate/clean_catalog.R` | Identify GCA/GCF duplicate pairs; select best per species; add selection_status |
| `PHASE_1.4_phylogenetic_placement/place_taxa.R` | Look up taxonomic lineage per species; classify into beetle clades |
| `PHASE_1.5_fasta_urls/generate_downloads.R` | Generate batch download infrastructure: accession lists, SLURM scripts, manifest |
| `PHASE_1.5_fasta_urls/compile_urls.sh` | Construct NCBI FTP paths; test URLs with curl; download checksums |
| `PHASE_1.5_fasta_urls/check_restrictions.R` | Audit genome restriction status (EBP/DToL affiliation, BioProject accessions) |
| `PHASE_1.6_constraint_tree/build_constraint_tree.R` | Build Coleoptera constraint tree with Neuropterida outgroups (McKenna topology) |
| `PHASE_1.6_constraint_tree/build_tree.R` | Graft genome species onto backbone with family/subfamily constraints |
| `PHASE_1.7_qc_report/catalog_qc_report.R` | Multi-page PDF QC report: assembly stats, quality metrics, family coverage |
| `PHASE_1.7_qc_report/catalog_summary_figures.R` | Publication-quality summary figures from genome_catalog.csv |
| `PHASE_1.7_qc_report/qc_report.R` | Comprehensive Phase 1 QC report: genome counts, assembly stats, phylogenetic coverage |

### phases/phase3_alignment_synteny/ — Whole-Genome Alignment and Synteny

| Script | Description |
|--------|-------------|
| `PHASE_2.2_full_alignment/split_tree.R` | Decompose phylogeny at clade boundaries; generate per-subtree seqFiles |
| `PHASE_2.2_full_alignment/submit_all.sh` | Master submission for entire alignment pipeline; chain subtree jobs with dependencies |
| `PHASE_2.4_synteny_qc/synteny_qc.R` | QC filter synteny blocks (size >= 10 kb, identity >= 95%, remove self-alignments) |
| `PHASE_2.6_synteny_anchoring/anchor_synteny.R` | Map synteny blocks to ancestral genomes; anchor to predicted ancestral locations |
| `PHASE_2.7_integration_signoff/integration_report.R` | Phase 2 integration report with publication-ready alignment and synteny statistics |

### phases/phase4_rearrangements/ — Rearrangement Analysis

| Script | Description |
|--------|-------------|
| `PHASE_3.1_breakpoint_calling/call_breakpoints.R` | Identify and classify chromosomal breakpoints (fusions, fissions, inversions, translocations) |
| `PHASE_3.2_filtering/filter_rearrangements.R` | Quality filters to distinguish CONFIRMED (>=2 species) vs INFERRED rearrangements |
| `PHASE_3.3_tree_mapping/map_to_tree.R` | Assign rearrangements to branches using parsimony; identify ancestral-to-derived transitions |
| `PHASE_3.4_branch_stats/branch_statistics.R` | Per-branch rearrangement counts and rates normalized by branch length; hotspot detection |
| `PHASE_3.5_literature_comparison/compare_literature.R` | Validate inferred rearrangements against published karyotype data |
| `PHASE_3.6_ancestral_karyotypes/reconstruct_karyotypes.R` | Reconstruct ancestral chromosome complements from synteny blocks |
| `PHASE_3.7_integration_signoff/phase3_report.R` | Phase 3 summary report with publication-quality PDF |

### phases/phase5_viz_manuscript/ — Visualization and Manuscript

| Script | Description |
|--------|-------------|
| `PHASE_4.1_interactive_tree/plot_tree.R` | Phylogenetic tree colored by rearrangement rate with node labels |
| `PHASE_4.2_synteny_dotplots/make_dotplots.R` | Comparative genomics dotplots for species pairs |
| `PHASE_4.3_hotspot_viz/hotspot_figures.R` | Circular tree with rearrangement heatmap and genome-wide density plots |
| `PHASE_4.4_ancestral_figures/ancestral_karyotype_figures.R` | Schematic chromosome diagrams for ancestral nodes with synteny block coloring |
| `PHASE_4.5_data_release/package_release.sh` | Structured release package for public distribution with manifest |
| `PHASE_4.6_manuscript_figures/compile_figures.R` | Assemble final publication figures (Fig 1-4 + supplementary) |
| `PHASE_4.7_completion_signoff/final_checklist.R` | Automated verification of all expected outputs; data integrity check |

## Key Data Files

### results/

| File | Description |
|------|-------------|
| `sra_rnaseq_survey.csv` | Per-species SRA survey: 439 rows with has_male, has_female, has_both_sexes, tissues |
| `sra_rnaseq_runs_detailed.csv` | Per-run metadata for 53 both-sex species (4,860 rows with SRR accessions) |
| `sra_rnaseq_runs_singlesex.csv` | Per-run metadata for 47 single-sex species (920 rows) |
| `selected_rnaseq_runs.csv` | Final RNA-seq selection: 297 runs across 65 species with ENA download URLs |
| `rnaseq_selection_summary.txt` | Per-species summary of RNA-seq selection (tissue, replicates, est. size) |
| `rnaseq_download_manifest.txt` | One ENA URL per line for wget bulk download |

### results/species_tree/

| File | Description |
|------|-------------|
| `wastral_species_tree_rooted.nwk` | Rooted wASTRAL species tree (478 taxa, Newick) |
| `concordance_gcf.cf.stat` | Per-branch gCF, gDF1, gDF2, gDFP from IQ-TREE |
| `concordance_gcf.cf.tree` | Species tree with gCF annotations (Newick) |
| `concordance_gcf.cf.tree.nex` | Species tree with gCF annotations (Nexus, for FigTree) |
| `gcf_summary.txt` | Summary statistics: distribution, discordance symmetry, top/bottom branches |
| `gcf_results_draft.txt` | Draft results text for manuscript |

### data/genomes/

| File | Description |
|------|-------------|
| `genome_catalog.csv` | Master catalog of 1,121 Coleoptera + Neuropterida genome assemblies |
| `genome_catalog_primary.csv` | 687 best-per-species selections with quality scores |
| `tree_tip_mapping.csv` | Maps species names to tree tip labels, families, and clades |

## Deprecated

| Directory | Note |
|-----------|------|
| `grace_upload/` | Early Phase 3 download scripts; superseded by `grace_upload_phase3/` |
| `scripts/phase3/deprecated/` | Old versions of Cactus setup scripts |
| `grace_upload_phase3/deprecated/` | Old locus selection and recovery integration scripts |
