# SCARAB: Complete Script Manifest

**Project**: Whole-Genome Alignment & Rearrangement Analysis
**Created**: 2026-03-21
**Language**: R (scripts) + Bash (data packaging)
**Total Scripts**: 14

---

## PHASE 3: REARRANGEMENT ANALYSIS

### Phase 3.1: Breakpoint Calling
**File**: `phase4_rearrangements/PHASE_3.1_breakpoint_calling/call_breakpoints.R`

Identifies and classifies chromosomal rearrangement breakpoints by comparing synteny block order and orientation between extant and ancestral genomes.

**Key Features**:
- Detects fusions, fissions, inversions, translocations
- Annotates breakpoints with ±5kb confidence intervals
- Outputs: `rearrangements_raw.tsv`

**Student Customization Points**:
- Update input/output directories
- Adjust confidence interval range
- Modify species pair selection logic

---

### Phase 3.2: Rearrangement Filtering
**File**: `phase4_rearrangements/PHASE_3.2_filtering/filter_rearrangements.R`

Applies quality filters to distinguish confirmed, inferred, and artifact rearrangements.

**Key Features**:
- Multi-stage filtering (breakpoint quality, species support, artifact detection)
- Classifies as: confirmed (≥2 species), inferred (single species), artifact
- Outputs: `rearrangements_confirmed.tsv`, `rearrangements_inferred.tsv`, `rearrangements_artifact.tsv`, `filtering_criteria.txt`

**Student Customization Points**:
- Adjust quality thresholds (MIN_SUPPORTING_BLOCKS, MAX_CONFIDENCE_INTERVAL, etc.)
- Modify artifact detection criteria
- Set independent species support requirement

---

### Phase 3.3: Tree Mapping
**File**: `phase4_rearrangements/PHASE_3.3_tree_mapping/map_to_tree.R`

Assigns confirmed rearrangements to specific phylogenetic branches using parsimony.

**Key Features**:
- Maps rearrangements to ancestral → derived nodes
- Calculates parsimony scores
- Detects potential reversions
- Outputs: `rearrangements_mapped.tsv`

**Student Customization Points**:
- Tree parsing method (adapt for your tree format)
- Reversion detection logic
- Confidence assessment criteria

---

### Phase 3.4: Branch Statistics
**File**: `phase4_rearrangements/PHASE_3.4_branch_stats/branch_statistics.R`

Computes per-branch rearrangement counts and rates normalized by branch length.

**Key Features**:
- Per-branch counts by rearrangement type
- Calculates rates (rearrangements per Myr)
- Identifies hotspot branches (>2 SD above mean)
- Generates visualizations (histogram, tree coloring)
- Outputs: `rearrangements_per_branch.tsv`, `branch_stats.csv`, figures

**Student Customization Points**:
- Branch length extraction
- Clade definition for hierarchical analysis
- Hotspot threshold adjustment

---

### Phase 3.5: Literature Comparison
**File**: `phase4_rearrangements/PHASE_3.5_literature_comparison/compare_literature.R`

Validates inferred rearrangements against published karyotype data.

**Key Features**:
- Compares predictions to known karyotypes
- Calculates agreement rates
- Flags inconsistencies requiring manual review
- Outputs: `literature_comparison.csv`, `validation_report.txt`

**Student Customization Points**:
- Populate `published_karyotypes.csv` with known data
- Implement comparison logic (fusion → lower 2n, etc.)
- Adjust validation thresholds

---

### Phase 3.6: Ancestral Karyotype Reconstruction
**File**: `phase4_rearrangements/PHASE_3.6_ancestral_karyotypes/reconstruct_karyotypes.R`

Reconstructs ancestral chromosome complements for key phylogenetic nodes.

**Key Features**:
- Counts ancestral linkage groups from synteny blocks
- Infers chromosome numbers (2n)
- Characterizes ancestral chromosome structure
- Outputs: `ancestral_karyotypes.csv`, `ancestral_linkage_groups.csv`

**Student Customization Points**:
- Define major nodes to analyze
- Adjust linkage group identification criteria
- Add species-specific notes

---

### Phase 3.7: Integration & Signoff
**File**: `phase4_rearrangements/PHASE_3.7_integration_signoff/phase3_report.R`

Compiles comprehensive Phase 3 summary with statistics and figures.

**Key Features**:
- Aggregates all Phase 3 results
- Generates summary statistics
- Creates PDF report
- Completion checklist
- Outputs: `phase3_integration_report.pdf`, `phase3_summary_stats.txt`

**Student Customization Points**:
- Customize report styling
- Add additional analyses
- Modify checklist items

---

## PHASE 4: VISUALIZATION & MANUSCRIPT

### Phase 4.1: Interactive Tree Visualization
**File**: `phase5_viz_manuscript/PHASE_4.1_interactive_tree/plot_tree.R`

Generates publication-quality phylogenetic tree with branch coloring by rearrangement rate.

**Key Features**:
- Tree with rate-based branch coloring (blue → red gradient)
- Node labels showing ancestral 2n
- Tip labels with family names
- Color scale legend
- Outputs: `beetle_tree_rearrangements.pdf`, `figure_caption.txt`

**Student Customization Points**:
- Tree parsing method (ape vs. alternative)
- Color palette and scale
- Species metadata (families, common names)
- Label customization

---

### Phase 4.2: Synteny Dotplots
**File**: `phase5_viz_manuscript/PHASE_4.2_synteny_dotplots/make_dotplots.R`

Generates comparative genomics dotplots between representative species pairs.

**Key Features**:
- X = species A chromosomes, Y = species B chromosomes
- Points colored by orientation (forward/reverse)
- Multiple species pairs on single PDF
- Base R + optional ggplot2 versions
- Outputs: `synteny_dotplots.pdf`, `figure_captions.txt`

**Student Customization Points**:
- Select representative species pairs
- Adjust number of plots
- Customize coloring scheme
- Modify axis labels

---

### Phase 4.3: Hotspot Visualization
**File**: `phase5_viz_manuscript/PHASE_4.3_hotspot_viz/hotspot_figures.R`

Creates circular tree with rearrangement heatmap and genome-wide density analysis.

**Key Features**:
- Branch rate distribution histogram
- Species × rearrangement type heatmap
- Rearrangement type pie chart
- Hotspot identification and ranking
- Outputs: `hotspot_figures.pdf`, enhanced figures with ggplot2

**Student Customization Points**:
- Heatmap normalization method
- Hotspot ranking criteria
- Color palettes
- Figure layout

---

### Phase 4.4: Ancestral Karyotype Figures
**File**: `phase5_viz_manuscript/PHASE_4.4_ancestral_figures/ancestral_karyotype_figures.R`

Creates schematic chromosome diagrams for major ancestral nodes.

**Key Features**:
- Chromosome pair diagrams with color coding
- Before/after rearrangement transitions
- Summary tables
- Integration of rearrangement annotations
- Outputs: `ancestral_karyotype_figures.pdf`, `ancestral_karyotypes_summary.txt`

**Student Customization Points**:
- Select key nodes for display
- Chromosome coloring scheme
- Diagram layout and proportions
- Additional annotations

---

### Phase 4.5: Data Release Packaging
**File**: `phase5_viz_manuscript/PHASE_4.5_data_release/package_release.sh`

Bash script to create structured, release-ready package for data deposition.

**Key Features**:
- Organized directory structure (data/, figures/, scripts/, docs/)
- Manifest with checksums
- Comprehensive README.md
- Data dictionary
- tar.gz compression
- Outputs: `scarab_release/` directory + `.tar.gz` archive

**Student Customization Points**:
- Update file paths
- Customize README content
- Adjust directory organization
- Modify manifest entries

---

### Phase 4.6: Manuscript Figures Compilation
**File**: `phase5_viz_manuscript/PHASE_4.6_manuscript_figures/compile_figures.R`

Assembles final publication figures with consistent styling.

**Key Features**:
- Title page and figure list
- Figure captions with detailed descriptions
- Methods summary page
- Publication-quality PDF
- Figure quality checklist
- Outputs: `manuscript_figures.pdf`, `figure_captions_final.txt`, `figure_checklist.txt`

**Student Customization Points**:
- Figure styling parameters (DPI, fonts, colors)
- Journal-specific formatting
- Caption length and detail
- Color palette choices

---

### Phase 4.7: Completion & Manuscript Readiness
**File**: `phase5_viz_manuscript/PHASE_4.7_completion_signoff/final_checklist.R`

Automated verification of all expected outputs and manuscript readiness assessment.

**Key Features**:
- File existence and integrity checks
- Data validity validation (missing values, structure)
- Manuscript requirements checklist
- Pre-submission verification
- Outputs: `manuscript_readiness_checklist.txt`, `data_validation_report.txt`

**Student Customization Points**:
- Expected file paths
- Data quality thresholds
- Validation criteria
- Journal-specific requirements

---

## DIRECTORY STRUCTURE

```
phases/
├── phase4_rearrangements/
│   ├── PHASE_3.1_breakpoint_calling/
│   │   └── call_breakpoints.R
│   ├── PHASE_3.2_filtering/
│   │   └── filter_rearrangements.R
│   ├── PHASE_3.3_tree_mapping/
│   │   └── map_to_tree.R
│   ├── PHASE_3.4_branch_stats/
│   │   └── branch_statistics.R
│   ├── PHASE_3.5_literature_comparison/
│   │   └── compare_literature.R
│   ├── PHASE_3.6_ancestral_karyotypes/
│   │   └── reconstruct_karyotypes.R
│   └── PHASE_3.7_integration_signoff/
│       └── phase3_report.R
└── phase5_viz_manuscript/
    ├── PHASE_4.1_interactive_tree/
    │   └── plot_tree.R
    ├── PHASE_4.2_synteny_dotplots/
    │   └── make_dotplots.R
    ├── PHASE_4.3_hotspot_viz/
    │   └── hotspot_figures.R
    ├── PHASE_4.4_ancestral_figures/
    │   └── ancestral_karyotype_figures.R
    ├── PHASE_4.5_data_release/
    │   └── package_release.sh
    ├── PHASE_4.6_manuscript_figures/
    │   └── compile_figures.R
    └── PHASE_4.7_completion_signoff/
        └── final_checklist.R
```

---

## USAGE & EXECUTION ORDER

### Phase 3 (Sequential)
1. **call_breakpoints.R** - Generate raw rearrangement calls
2. **filter_rearrangements.R** - Apply quality filters
3. **map_to_tree.R** - Assign to phylogenetic branches
4. **branch_statistics.R** - Compute branch-level metrics
5. **compare_literature.R** - Validate against published data
6. **reconstruct_karyotypes.R** - Infer ancestral karyotypes
7. **phase3_report.R** - Generate integration report

### Phase 4 (Can be parallelized)
- **plot_tree.R** - Generate phylogenetic tree figure
- **make_dotplots.R** - Generate synteny comparisons
- **hotspot_figures.R** - Analyze rearrangement hotspots
- **ancestral_karyotype_figures.R** - Draw chromosome diagrams
- **package_release.sh** - Create data release package
- **compile_figures.R** - Assemble manuscript figures
- **final_checklist.R** - Verify completeness

---

## KEY CONVENTIONS

All scripts follow these conventions:

- **Logging**: Each script writes a detailed `.log` file
- **Student Markers**: `## <<<STUDENT: ...>>>` comments mark customization points
- **Path Configuration**: Update paths at top of each script (section 0)
- **Error Handling**: Try/catch blocks for optional dependencies (ggplot2, ape)
- **Base R Preferred**: Uses base R with minimal external dependencies
- **Documentation**: Extensive inline comments explaining logic

---

## DEPENDENCIES

### Required
- R (≥3.6.0)
- Base R packages: stats, utils, graphics

### Optional (gracefully handled)
- ape (phylogenetic analysis)
- ggplot2 (enhanced visualization)
- gridExtra (multi-panel plots)

### External (for Phase 4.5 only)
- tar command (Unix/Linux)
- md5sum (checksums)

---

## OUTPUT FILES SUMMARY

### Phase 3 Outputs (~20 files)
- Rearrangement tables (raw, confirmed, inferred, mapped)
- Branch statistics
- Ancestral karyotypes
- Validation reports
- Integration report PDF

### Phase 4 Outputs (~15 files)
- Publication figures (PDF)
- Figure captions
- Data release package
- Manuscript readiness checklist

---

## TOTAL LINES OF CODE

- **Phase 3 scripts**: ~6,000 lines
- **Phase 4 scripts**: ~4,500 lines
- **Total**: ~10,500 lines of well-commented R/Bash code

---

## NOTES FOR STUDENTS

1. **Start with Phase 3.1**: Understand the data structure before modifying
2. **Test locally**: Run on small subset first
3. **Check logs**: Every script generates detailed logs
4. **Customization required**: All STUDENT markers must be addressed
5. **Validation**: Run final_checklist.R to verify completeness

---

**Project Complete**: All 14 scripts ready for Coleoptera whole-genome analysis!
