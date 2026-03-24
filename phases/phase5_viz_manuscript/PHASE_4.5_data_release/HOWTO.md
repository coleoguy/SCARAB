# HOWTO 5.5: Package Complete Data Release

**Responsible Person:** Claude (AI), reviewed by Heath
**Input files:** All data/ and results/ from Phases 1–4
**Output files:**
- results/phase5_viz_manuscript/scarab_release/ (complete directory structure)
- results/phase5_viz_manuscript/scarab_release.tar.gz (compressed archive)

**Duration:** 0.5 day

---

## Overview

Package the entire SCARAB dataset for public release. The release includes all genomes, alignments, synteny data, rearrangement calls, ancestral reconstructions, code, and documentation. This enables reproduction of all results and reuse by the community.

---

## Release Directory Structure

Create the following structure in results/phase5_viz_manuscript/scarab_release/:

```
scarab_release/
├── README.md                          # Start here: overview, citing, contents
├── LICENSE                            # MIT or CC-BY-4.0 recommended
├── MANIFEST.md                        # File listing with descriptions and sizes
│
├── data/
│   ├── genomes/
│   │   ├── README_genomes.md
│   │   ├── constraint_tree.nwk        # Phylogenetic tree (Newick)
│   │   ├── genome_metadata.csv        # Genome statistics and source info
│   │   ├── fasta_urls.txt             # URLs for downloading complete FASTA files
│   │   └── md5_checksums.txt          # Checksums for verifying downloads
│   │
│   ├── synteny/
│   │   ├── README_synteny.md
│   │   ├── synteny_anchored.tsv       # Synteny anchor coordinates
│   │   └── synteny_stats_per_pair.csv # Summary statistics by species pair
│   │
│   ├── alignments/
│   │   ├── README_alignments.md
│   │   └── note: full alignment HAL files too large; link to Grace HPC storage
│   │       (or provide subset of representative species alignments)
│   │
│   ├── karyotypes/
│   │   ├── README_karyotypes.md
│   │   ├── ancestral_karyotypes.csv   # Ancestral state reconstructions
│   │   ├── rearrangements_mapped.tsv  # Rearrangement breakpoints and positions
│   │   └── literature_karyotypes.csv  # Published karyotypes used for validation
│   │
│   └── supplementary/
│       ├── README_supplementary.md
│       └── [any additional reference data]
│
├── results/
│   ├── README_results.md               # How results were generated
│   │
│   ├── phase1_literature/
│   │   ├── project_summary.md
│   │   └── [PDFs of reviewed papers or links]
│   │
│   ├── phase2_genomes/
│   │   ├── mining_summary.txt          # Number of genomes found per source
│   │   ├── quality_control_report.md   # Assembly quality metrics
│   │   └── genome_curation_log.txt     # Notes on selected vs. excluded genomes
│   │
│   ├── phase3_alignments/
│   │   ├── alignment_summary.md        # Methods, parameters, runtime
│   │   ├── ancestral_genome_sizes.txt  # Reconstructed ancestral genome sizes
│   │   └── synteny_extraction_log.txt  # Number of anchors extracted per pair
│   │
│   ├── phase4_rearrangements/
│   │   ├── rearrangements_per_branch.tsv  # Main results table
│   │   ├── rearrangement_rate_stats.csv   # Rates per branch
│   │   ├── hotspot_analysis.tsv          # Breakpoint clustering results
│   │   └── branch_summary.txt            # Summary of all branches analyzed
│   │
│   └── phase5_viz_manuscript/
│       ├── figures/                      # All publication figures (PDF)
│       │   ├── figure1_phylogeny_overview.pdf
│       │   ├── figure2_synteny_dotplots.pdf
│       │   ├── figure3_hotspots.pdf
│       │   ├── figure4_ancestral_karyotypes.pdf
│       │   └── supplementary_figures/
│       │
│       ├── beetle_tree_interactive.html   # Interactive visualization
│       │
│       └── preprint_v1.pdf                # Full manuscript PDF
│
├── scripts/
│   ├── README_scripts.md                  # How to run scripts
│   ├── requirements.txt                   # R/Python packages and versions
│   │
│   ├── phase1/
│   │   └── [scripts from phase 1]
│   │
│   ├── phase2/
│   │   └── [scripts from phase 2]
│   │
│   ├── phase3/
│   │   └── [scripts from phase 3]
│   │
│   ├── phase4/
│   │   └── [scripts from phase 4]
│   │
│   └── phase5/
│       ├── build_interactive_tree.R
│       ├── generate_dotplots.R
│       ├── hotspot_viz.R
│       ├── build_ancestral_karyotypes.R
│       └── [other analysis scripts]
│
├── docs/
│   ├── README_docs.md                     # Documentation overview
│   ├── methods.md                         # Detailed methods (100+ pages if needed)
│   ├── workflow_diagram.pdf               # Visual flow chart of analysis pipeline
│   ├── glossary.md                        # Definitions of key terms and abbreviations
│   ├── troubleshooting.md                 # FAQ and known issues
│   └── citation_guide.md                  # How to cite this work
│
├── metadata/
│   ├── README_metadata.md
│   ├── species_list.csv                   # Full species list with taxonomy
│   ├── assembly_metadata.csv              # Source, date, assembly accession per genome
│   ├── software_versions.txt              # Tools used (BLAST, HAL, etc.) and versions
│   ├── hardware_environment.txt           # HPC system used (Grace, node types, job params)
│   └── ai_code_provenance.md              # Which code was AI-generated (Claude) and reviewed
│
└── CHANGELOG.md                           # Version history and release notes
```

---

## Detailed Steps

### Step 1: Organize Files

From the working project directory (SCARAB/), copy the following directories into the release structure:

1. **data/genomes/** → Include all metadata, tree file, genome list
   - Exclude actual FASTA sequences (too large; provide URLs instead)
   - Include md5_checksums.txt for validation

2. **data/synteny/** → Include synteny_anchored.tsv and summary stats

3. **data/karyotypes/** → Include all CSVs and TSVs from Phase 4 analysis

4. **results/phase*/** → Copy all result tables, logs, and summaries
   - Exclude intermediate working files
   - Include summary reports and QC metrics

5. **scripts/** → Copy all reproducible analysis scripts
   - Include commented R/Python code
   - Include requirements.txt or equivalent dependency list

### Step 2: Create README Files

For the top-level README.md, include:

```markdown
# SCARAB: Genome-wide Rearrangement Dynamics in Beetles

## Quick Start

1. Read this file for an overview
2. See `MANIFEST.md` for a complete file listing
3. See `docs/methods.md` for detailed methods
4. Start with data/genomes/README_genomes.md to understand data organization

## Citation

If you use this dataset, please cite:
Blackmon et al. (20XX). SCARAB: ... [full citation when preprint is ready]

## Data Contents

- **Genomes:** X species from Y sources
- **Alignments:** Multiple sequence alignments (subset; see docs/methods.md for full HAL file access)
- **Synteny:** N synteny anchor pairs across M species pairs
- **Rearrangements:** K structural variants identified across the phylogeny
- **Ancestral reconstructions:** Karyotypes and genome organization at X major nodes

## License

[Choose: MIT, CC-BY-4.0, or another open license]

## Contact & Issues

[Heath Blackmon, TAMU]
[email, website, GitHub]

## Reproducibility

All scripts are provided in scripts/ directory. See scripts/README_scripts.md for dependencies and instructions.
```

### Step 3: Create MANIFEST.md

List every file in the release with:
- Path
- Description (1 line)
- File size
- Format (CSV, TSV, Newick, PDF, etc.)

Example:
```
| File | Description | Size | Format |
|------|-------------|------|--------|
| data/genomes/constraint_tree.nwk | Phylogenetic tree of 50 beetles | 12 KB | Newick |
| data/synteny/synteny_anchored.tsv | Synteny blocks across all species pairs | 45 MB | TSV |
| results/phase4_rearrangements/rearrangements_per_branch.tsv | Main results: rearrangement counts by branch | 156 KB | TSV |
```

### Step 4: Create Domain-Specific READMEs

For each major data directory (data/genomes/, data/synteny/, etc.), create a README with:
- File descriptions
- Column definitions for tabular data
- Example usage
- Known limitations or caveats

### Step 5: Create Software Documentation

**scripts/requirements.txt:**
```
# R packages (install via install.packages() or renv)
ggplot2==3.4.0
ggtree==3.8.2
igraph==1.5.0
pheatmap==1.0.12
data.table==1.14.8
...

# Python packages (install via pip)
biopython==1.81
pandas==1.5.3
numpy==1.24.3
...

# External tools
BLAST==2.14.0
minimap2==2.26
HAL==2.1.0 (from UCSC Genome Browser project)
```

**metadata/software_versions.txt:**
```
Analysis completed with:
- R 4.3.0
- Python 3.11.4
- BLAST 2.14.0
- minimap2 2.26
- HAL 2.1.0

See scripts/requirements.txt for exact package versions.
Grace HPC: [node type, job submission system]
```

### Step 6: Create AI Provenance Document

**metadata/ai_code_provenance.md:**
```
# AI-Generated Code Provenance

This project used Claude (Anthropic) AI assistant to generate analysis scripts.
All AI-generated code was reviewed by Heath Blackmon before use.

## AI-Generated Files

| Script | AI Role | Human Reviewer | Review Status | Notes |
|--------|---------|----------------|---------------|-------|
| scripts/phase3/extract_synteny_blocks.R | Generated | Heath Blackmon | Approved | Tested on 5 test species pairs |
| scripts/phase4/call_rearrangements.R | Generated | Heath Blackmon | Approved | Validated against manual calls |
| scripts/phase5/build_interactive_tree.R | Generated | Heath Blackmon | Approved | Interactive features tested in Chrome/Firefox |
...

## Attribution

The use of AI for code generation is disclosed in the Methods section of the preprint.
Code quality was maintained through review procedures documented in project_management/ai_code_review_checklist.md
```

### Step 7: Create Changelog

**CHANGELOG.md:**
```
# SCARAB Release Changelog

## v1.0 - Initial Release (2026-03-21)

### Added
- Complete dataset for 438 beetle and outgroup genomes
- Synteny analysis across 200+ species pairs
- Rearrangement predictions for all branches
- Ancestral karyotype reconstructions
- Interactive phylogenetic tree visualization
- Publication-quality figures (4 main figures + supplementary)

### Known Issues
- HAL alignment files not included (available upon request from TAMU HPC)
- Some satellite DNA regions not annotated due to assembly gaps

### Citation
Blackmon et al. (20XX). SCARAB.
```

### Step 8: Create Tar Archive

```bash
cd results/phase5_viz_manuscript/
tar -czf scarab_release.tar.gz scarab_release/

# Verify
tar -tzf scarab_release.tar.gz | head -20
ls -lh scarab_release.tar.gz
```

### Step 9: Create Download Instructions

Create a file results/phase5_viz_manuscript/DOWNLOAD_AND_VERIFY.md with instructions:

```markdown
# Download and Verify Data Release

## Download

Download from [repository URL]:
- scarab_release.tar.gz (X GB)

## Verify Integrity

Compute MD5 checksum and compare to published value:
```bash
md5sum scarab_release.tar.gz
# Expected: [MD5 value]
```

## Decompress

```bash
tar -xzf scarab_release.tar.gz
cd scarab_release
```

## Explore

Start with README.md, then browse data/ and results/.
```

---

## Quality Checklist (Human Review)

- [ ] All Phase 1–4 results files are present and not corrupted
- [ ] README files are clear and self-contained (no broken links)
- [ ] MANIFEST.md is complete and accurate (spot-check 10 file listings)
- [ ] All scripts have proper headers with usage instructions
- [ ] requirements.txt lists all dependencies with versions
- [ ] Metadata files document tool versions and HPC environment
- [ ] No sensitive information (passwords, API keys, email addresses) in any file
- [ ] Archive decompresses correctly and directory structure is intact
- [ ] Archive size is reasonable given content (not bloated)
- [ ] File permissions are preserved (scripts remain executable)

---

## Reproducibility Notes

- This release is intended to be a complete snapshot of the project
- Users should be able to reproduce all analyses by running scripts/ on data/
- Document any environment-specific parameters (e.g., number of threads, memory) in script headers
- Consider hosting on Zenodo or Dryad for long-term archival and DOI
