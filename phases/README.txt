================================================================================
SCARAB: WHOLE-GENOME ALIGNMENT PROJECT
================================================================================

START HERE: Welcome to the complete analysis pipeline for ~50 beetle genomes.

This directory contains all R and Bash scripts needed for rearrangement 
analysis and manuscript preparation.

================================================================================
QUICK START
================================================================================

1. READ THIS FIRST:
   - DELIVERY_SUMMARY.txt (overview of what was delivered)
   - SCRIPTS_MANIFEST.md (detailed description of each script)

2. CUSTOMIZE YOUR SETUP:
   - Update file paths in each script (look for ## <<<STUDENT: sections)
   - Adjust parameters for your dataset

3. RUN THE ANALYSIS:
   Phase 3 (Sequential):
     phase4_rearrangements/PHASE_3.1_breakpoint_calling/call_breakpoints.R
     phase4_rearrangements/PHASE_3.2_filtering/filter_rearrangements.R
     phase4_rearrangements/PHASE_3.3_tree_mapping/map_to_tree.R
     phase4_rearrangements/PHASE_3.4_branch_stats/branch_statistics.R
     phase4_rearrangements/PHASE_3.5_literature_comparison/compare_literature.R
     phase4_rearrangements/PHASE_3.6_ancestral_karyotypes/reconstruct_karyotypes.R
     phase4_rearrangements/PHASE_3.7_integration_signoff/phase3_report.R

   Phase 4 (Can run in parallel):
     phase5_viz_manuscript/PHASE_4.1_interactive_tree/plot_tree.R
     phase5_viz_manuscript/PHASE_4.2_synteny_dotplots/make_dotplots.R
     phase5_viz_manuscript/PHASE_4.3_hotspot_viz/hotspot_figures.R
     phase5_viz_manuscript/PHASE_4.4_ancestral_figures/ancestral_karyotype_figures.R
     phase5_viz_manuscript/PHASE_4.5_data_release/package_release.sh
     phase5_viz_manuscript/PHASE_4.6_manuscript_figures/compile_figures.R
     phase5_viz_manuscript/PHASE_4.7_completion_signoff/final_checklist.R

4. VERIFY COMPLETION:
   phase5_viz_manuscript/PHASE_4.7_completion_signoff/final_checklist.R

================================================================================
DIRECTORY STRUCTURE
================================================================================

phases/
├── phase3_alignment_synteny/     (Previous phase outputs - input data)
├── phase4_rearrangements/        (Phase 3 scripts and outputs)
│   ├── PHASE_3.1_breakpoint_calling/
│   ├── PHASE_3.2_filtering/
│   ├── PHASE_3.3_tree_mapping/
│   ├── PHASE_3.4_branch_stats/
│   ├── PHASE_3.5_literature_comparison/
│   ├── PHASE_3.6_ancestral_karyotypes/
│   └── PHASE_3.7_integration_signoff/
└── phase5_viz_manuscript/        (Phase 4 scripts and outputs)
    ├── PHASE_4.1_interactive_tree/
    ├── PHASE_4.2_synteny_dotplots/
    ├── PHASE_4.3_hotspot_viz/
    ├── PHASE_4.4_ancestral_figures/
    ├── PHASE_4.5_data_release/
    ├── PHASE_4.6_manuscript_figures/
    └── PHASE_4.7_completion_signoff/

================================================================================
KEY FILES
================================================================================

DELIVERY_SUMMARY.txt   - Overview of all 14 scripts and features
SCRIPTS_MANIFEST.md    - Detailed description of each script
README.txt            - This file

================================================================================
WHAT'S INCLUDED
================================================================================

PHASE 3: REARRANGEMENT ANALYSIS (7 R scripts)
- Breakpoint calling and classification
- Quality filtering with multi-stage validation
- Phylogenetic tree mapping (parsimony)
- Branch-level statistics and hotspot identification
- Literature comparison and validation
- Ancestral karyotype reconstruction
- Integration report generation

PHASE 4: VISUALIZATION & MANUSCRIPT (7 Scripts)
- Phylogenetic tree with rate-based coloring
- Synteny dotplots (comparative genomics)
- Hotspot analysis and heatmaps
- Ancestral karyotype diagrams
- Data release packaging (tar.gz)
- Manuscript figure compilation
- Final completeness verification

================================================================================
FEATURES
================================================================================

✓ 4,939 lines of well-documented code
✓ Comprehensive inline comments
✓ Student customization markers (## <<<STUDENT:)
✓ Detailed logging (.log files)
✓ Error handling and validation
✓ Base R preferred (minimal dependencies)
✓ Graceful fallback for optional packages
✓ Multi-page PDF outputs
✓ Publication-ready figures

================================================================================
DEPENDENCIES
================================================================================

REQUIRED:
  - R ≥ 3.6.0
  - Base R packages (built-in)

OPTIONAL (gracefully handled):
  - ape (phylogenetic analysis)
  - ggplot2 (enhanced visualizations)
  - gridExtra (multi-panel plots)

EXTERNAL (Phase 4.5):
  - tar, md5sum (Unix/Linux standard)

================================================================================
SUPPORT
================================================================================

Each script generates a detailed .log file with timestamped progress.

For script-specific issues:
  1. Check the <script_name>.log file
  2. Look for STUDENT markers requiring customization
  3. Review inline comments for parameter ranges

For overview:
  - SCRIPTS_MANIFEST.md has detailed descriptions
  - DELIVERY_SUMMARY.txt has feature summaries

For validation:
  - Run final_checklist.R after Phase 3 and 4

================================================================================
GETTING STARTED
================================================================================

Step 1: Read DELIVERY_SUMMARY.txt
Step 2: Read SCRIPTS_MANIFEST.md
Step 3: Locate all STUDENT customization markers
Step 4: Update file paths in Section 0 of each script
Step 5: Prepare input data files
Step 6: Run Phase 3 scripts sequentially
Step 7: Run Phase 4 scripts (parallel or sequential)
Step 8: Run final_checklist.R for verification

================================================================================
STATUS
================================================================================

All scripts complete and ready for use.
Total: 14 scripts, ~5,000 lines of documented code
Created: 2026-03-21

For questions: See inline documentation and .log files
For updates: Maintain consistency with marked customization points

================================================================================
