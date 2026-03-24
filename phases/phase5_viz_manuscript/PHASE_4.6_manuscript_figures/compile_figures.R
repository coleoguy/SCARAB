#!/usr/bin/env Rscript
################################################################################
#
# PHASE 4.6 — COMPILE MANUSCRIPT FIGURES
# Coleoptera Whole-Genome Alignment: Visualization & Manuscript
#
# PURPOSE:
#   Assemble final publication figures (Fig 1-4 + supplementary).
#   Ensure consistent styling, font sizes, and color palettes.
#   Generate high-resolution PDF suitable for manuscript submission.
#
# INPUT:
#   - beetle_tree_rearrangements.pdf   Tree figure
#   - synteny_dotplots.pdf             Dotplot figure
#   - hotspot_figures.pdf              Hotspot analysis
#   - ancestral_karyotype_figures.pdf  Karyotype diagrams
#
# OUTPUT:
#   - manuscript_figures.pdf           Combined publication-quality PDF
#   - compile_figures.log              Processing log
#   - figure_captions_final.txt        Publication captions
#
# AUTHOR: SCARAB Team
# DATE: 2026-03-21
#
################################################################################

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 10)

# ============================================================================
# 0. PATHS & SETUP
# ============================================================================

## <<<STUDENT: Update figure input directories>>>
FIG_DIR <- list(
  tree = file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.1_interactive_tree"),
  dotplots = file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.2_synteny_dotplots"),
  hotspot = file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.3_hotspot_viz"),
  ancestral = file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.4_ancestral_figures")
)

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.6_manuscript_figures")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "compile_figures.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 4.6: Compile Manuscript Figures ===")

# ============================================================================
# 1. DEFINE FIGURE SPECIFICATIONS
# ============================================================================

log_msg("Defining manuscript figure specifications...")

## <<<STUDENT: Adjust styling parameters for your journal>>>

figure_specs <- list(
  dpi = 300,               # Resolution (dpi)
  width_single = 85,       # Single-column width (mm)
  width_double = 170,      # Double-column width (mm)
  height = 120,            # Standard height (mm)
  font_family = "serif",   # Font family
  font_main = "Arial",     # Main title font
  cex_main = 1.4,          # Main title size
  cex_lab = 1.1,           # Axis label size
  cex_axis = 0.9,          # Axis text size
  color_palette = c(
    "fusion" = "#1f77b4",
    "fission" = "#ff7f0e",
    "inversion" = "#2ca02c",
    "translocation" = "#d62728"
  ),
  margin = 0.1             # Margin (inches)
)

log_msg(paste("  DPI:", figure_specs$dpi))
log_msg(paste("  Column widths:", figure_specs$width_single, "x",
              figure_specs$width_double, "mm"))

# ============================================================================
# 2. CREATE FIGURE TITLE PAGE
# ============================================================================

log_msg("Creating figure compilation...")

tryCatch({
  pdf_file <- file.path(OUTPUT_DIR, "manuscript_figures.pdf")

  pdf(pdf_file, width = 8.5, height = 11, pointsize = 10)

  # ========================================================================
  # Title Page
  # ========================================================================

  log_msg("  Creating title page...")

  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")

  text(0.5, 0.85, "SUPPLEMENTARY FIGURES",
       cex = 2.0, font = 2, hjust = 0.5)

  text(0.5, 0.75, "Chromosomal Rearrangements in Coleoptera",
       cex = 1.3, hjust = 0.5)

  text(0.5, 0.65, "A Whole-Genome Synteny Analysis",
       cex = 1.2, hjust = 0.5, font = 3)

  # Add figure list
  y_pos <- 0.55

  text(0.05, y_pos, "Contents:", cex = 1.0, font = 2, hjust = 0)
  y_pos <- y_pos - 0.06

  figures_list <- c(
    "Figure S1: Phylogenetic tree with rearrangement rates",
    "Figure S2: Synteny dotplots (selected species pairs)",
    "Figure S3: Rearrangement hotspot analysis",
    "Figure S4: Ancestral karyotype reconstruction"
  )

  for (fig in figures_list) {
    text(0.1, y_pos, fig, cex = 0.95, hjust = 0)
    y_pos <- y_pos - 0.05
  }

  # Add figure statistics
  y_pos <- y_pos - 0.06

  text(0.05, y_pos, "Data Summary:", cex = 1.0, font = 2, hjust = 0)
  y_pos <- y_pos - 0.05

  ## <<<STUDENT: Fill in actual statistics>>>
  stats_text <- c(
    "Rearrangement calls: [STUDENT: update]",
    "Confirmed events: [STUDENT: update]",
    "Ancestral nodes analyzed: [STUDENT: update]",
    "Species examined: ~50 beetle genomes"
  )

  for (stat in stats_text) {
    text(0.1, y_pos, stat, cex = 0.9, hjust = 0)
    y_pos <- y_pos - 0.04
  }

  # ========================================================================
  # Figure Captions Page
  # ========================================================================

  log_msg("  Creating captions page...")

  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")

  text(0.5, 0.98, "FIGURE CAPTIONS", cex = 1.5, font = 2, hjust = 0.5)

  caption_text <- c(
    "Figure S1: Phylogenetic tree of beetle genomes with branch coloring by",
    "rearrangement rate. Branch colors indicate the number of chromosomal",
    "rearrangements (fusions, fissions, inversions, translocations) per",
    "million years. Blue indicates low rearrangement rates, red indicates",
    "high rates (>2 standard deviations above the mean). Node labels show",
    "inferred ancestral chromosome numbers (2n). Tree topology is based on",
    "conserved synteny blocks.",
    "",
    "Figure S2: Synteny dotplots comparing representative species pairs.",
    "X-axis and Y-axis represent chromosomes of two species. Each point",
    "represents an aligned synteny block. Blue points indicate blocks in",
    "forward orientation; orange points indicate reverse orientation.",
    "Diagonal or off-diagonal patterns reveal syntenic relationships and",
    "chromosomal rearrangements.",
    "",
    "Figure S3: Analysis of rearrangement hotspots. Top panel: Distribution",
    "of rearrangement rates across phylogenetic branches. Middle panel:",
    "Heatmap showing rearrangement counts by species and type (fusion,",
    "fission, inversion, translocation). Bottom panel: Pie chart of",
    "rearrangement types across all branches.",
    "",
    "Figure S4: Ancestral karyotype reconstruction. Schematic diagrams of",
    "ancestral chromosome complements for major beetle clades. Each pair",
    "represents a pair of homologous chromosomes, colored to show distinct",
    "linkage groups. Ancestral chromosome numbers (2n) are inferred from",
    "synteny block distributions across extant species."
  )

  y_pos <- 0.92

  for (line in caption_text) {
    if (line == "") {
      y_pos <- y_pos - 0.02
    } else {
      text(0.05, y_pos, line, cex = 0.85, hjust = 0, adj = c(0, 1))
      y_pos <- y_pos - 0.03
    }
  }

  # ========================================================================
  # Methods Summary
  # ========================================================================

  log_msg("  Creating methods summary page...")

  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")

  text(0.5, 0.98, "METHODS SUMMARY", cex = 1.5, font = 2, hjust = 0.5)

  methods_text <- c(
    "REARRANGEMENT DETECTION:",
    "Synteny blocks were aligned across ~50 beetle genomes using conserved",
    "genomic regions. Block order and orientation were compared between",
    "extant and ancestral genomes to identify:",
    "  • Fusions: Multiple ancestral chromosomes joined in extant species",
    "  • Fissions: Single ancestral chromosome split in extant species",
    "  • Inversions: Blocks reversed in orientation",
    "  • Translocations: Blocks moved to different chromosomes",
    "",
    "FILTERING AND CLASSIFICATION:",
    "Rearrangement calls were classified as:",
    "  • Confirmed: Supported by ≥2 independent species",
    "  • Inferred: Single species, supported by synteny and parsimony",
    "  • Artifact: Likely assembly errors or low-quality calls",
    "",
    "TREE MAPPING:",
    "Rearrangements were assigned to specific branches of the phylogenetic",
    "tree using parsimony optimization.",
    "",
    "ANCESTRAL RECONSTRUCTION:",
    "Chromosome numbers (2n) and structures were inferred for ancestral",
    "nodes by counting linkage groups (synteny blocks) and analyzing",
    "rearrangement patterns in descendant lineages."
  )

  y_pos <- 0.92

  for (line in methods_text) {
    if (line == "") {
      y_pos <- y_pos - 0.02
    } else if (grepl("^  •", line)) {
      text(0.1, y_pos, line, cex = 0.8, hjust = 0)
      y_pos <- y_pos - 0.025
    } else if (grepl("^[A-Z]", line)) {
      text(0.05, y_pos, line, cex = 0.85, font = 2, hjust = 0)
      y_pos <- y_pos - 0.03
    } else {
      text(0.05, y_pos, line, cex = 0.8, hjust = 0)
      y_pos <- y_pos - 0.025
    }
  }

  dev.off()

  log_msg(paste("  Wrote:", pdf_file))

}, error = function(e) {
  log_msg(paste("  ERROR creating manuscript figures:", e$message))
})

# ============================================================================
# 3. ATTEMPT TO COMPILE INDIVIDUAL FIGURE PDFS
# ============================================================================

log_msg("Attempting to compile individual figure PDFs...")

## <<<STUDENT: If you have converted individual figures to PDFs,
## uncomment and adapt the following code>>>

# tryCatch({
#   library(pdftools)
#
#   figure_files <- c(
#     file.path(FIG_DIR$tree, "beetle_tree_rearrangements.pdf"),
#     file.path(FIG_DIR$dotplots, "synteny_dotplots.pdf"),
#     file.path(FIG_DIR$hotspot, "hotspot_figures.pdf"),
#     file.path(FIG_DIR$ancestral, "ancestral_karyotype_figures.pdf")
#   )
#
#   # Filter to existing files
#   figure_files <- figure_files[file.exists(figure_files)]
#
#   if (length(figure_files) > 0) {
#     log_msg(paste("  Found", length(figure_files), "component PDFs to merge"))
#
#     combined_pdf <- file.path(OUTPUT_DIR, "manuscript_all_figures.pdf")
#
#     # Merge PDFs
#     pdf_combine(figure_files, output = combined_pdf)
#
#     log_msg(paste("  Merged figures into:", combined_pdf))
#   }
#
# }, error = function(e) {
#   log_msg(paste("  Could not merge PDFs:", e$message))
# })

# ============================================================================
# 4. GENERATE FIGURE CAPTIONS FILE
# ============================================================================

log_msg("Creating captions file for manuscript submission...")

captions_file <- file.path(OUTPUT_DIR, "figure_captions_final.txt")
captions_conn <- file(captions_file, open = "w")

cat("FIGURE CAPTIONS FOR MANUSCRIPT\n", file = captions_conn)
cat("=" %*% 70, "\n\n", file = captions_conn)

cat("Figure 1: Phylogenetic tree of Coleoptera genomes with rearrangement rates\n\n",
    file = captions_conn)

cat("Phylogenetic tree of ~50 beetle (Coleoptera) genomes constructed from\n",
    file = captions_conn)
cat("conserved synteny blocks. Branches are colored according to chromosomal\n",
    file = captions_conn)
cat("rearrangement rates (rearrangements per million years). Blue indicates\n",
    file = captions_conn)
cat("low rearrangement rates; red indicates high rates (>2 standard deviations\n",
    file = captions_conn)
cat("above the mean). Node labels indicate inferred ancestral chromosome\n",
    file = captions_conn)
cat("numbers (2n). Branch lengths are proportional to evolutionary time.\n\n",
    file = captions_conn)

cat("---\n\n", file = captions_conn)

cat("Figure 2: Synteny dotplots between representative beetle species\n\n",
    file = captions_conn)

cat("Comparative dotplots showing synteny relationships between representative\n",
    file = captions_conn)
cat("species pairs. X-axis: chromosomes of species A; Y-axis: chromosomes of\n",
    file = captions_conn)
cat("species B. Each point represents an aligned synteny block. Blue points\n",
    file = captions_conn)
cat("indicate blocks in forward orientation; orange points indicate reverse\n",
    file = captions_conn)
cat("orientation. Diagonal patterns indicate normal synteny; off-diagonal\n",
    file = captions_conn)
cat("patterns reveal chromosomal rearrangements such as translocations.\n\n",
    file = captions_conn)

cat("---\n\n", file = captions_conn)

cat("Figure 3: Rearrangement hotspot analysis\n\n",
    file = captions_conn)

cat("(Top) Distribution of rearrangement rates across phylogenetic branches.\n",
    file = captions_conn)
cat("Red dashed line indicates the hotspot threshold (mean + 2 SD). (Middle)\n",
    file = captions_conn)
cat("Heatmap showing the number of each rearrangement type (fusion, fission,\n",
    file = captions_conn)
cat("inversion, translocation) in each beetle family or clade. Darker blue\n",
    file = captions_conn)
cat("indicates higher counts. (Bottom) Pie chart showing the proportion of\n",
    file = captions_conn)
cat("rearrangement types across all identified events.\n\n",
    file = captions_conn)

cat("---\n\n", file = captions_conn)

cat("Figure 4: Ancestral karyotype reconstruction\n\n",
    file = captions_conn)

cat("Schematic chromosome diagrams for major ancestral nodes in Coleoptera.\n",
    file = captions_conn)
cat("Each rectangle represents a pair of homologous chromosomes. Different\n",
    file = captions_conn)
cat("colors indicate distinct ancestral linkage groups. Numbers indicate\n",
    file = captions_conn)
cat("inferred ancestral chromosome numbers (2n). Diagrams are based on the\n",
    file = captions_conn)
cat("distribution of synteny blocks across extant species and parsimonious\n",
    file = captions_conn)
cat("reconstruction of rearrangement history.\n\n",
    file = captions_conn)

close(captions_conn)
log_msg(paste("  Wrote:", captions_file))

# ============================================================================
# 5. CREATE FIGURE CHECKLIST
# ============================================================================

log_msg("Creating figure quality checklist...")

checklist_file <- file.path(OUTPUT_DIR, "figure_checklist.txt")
checklist_conn <- file(checklist_file, open = "w")

cat("FIGURE COMPILATION CHECKLIST\n", file = checklist_conn)
cat("=" %*% 60, "\n\n", file = checklist_conn)

cat("Resolution & Format:\n", file = checklist_conn)
cat("  [ ] All figures at ≥300 DPI for print\n", file = checklist_conn)
cat("  [ ] Figures in PDF format (or suitable for journal)\n", file = checklist_conn)
cat("  [ ] Color space appropriate for journal (RGB/CMYK)\n\n", file = checklist_conn)

cat("Typography & Styling:\n", file = checklist_conn)
cat("  [ ] Consistent font sizes across figures\n", file = checklist_conn)
cat("  [ ] Axis labels legible (≥10pt)\n", file = checklist_conn)
cat("  [ ] Figure titles clear and descriptive\n", file = checklist_conn)
cat("  [ ] Color palette consistent and colorblind-friendly\n\n", file = checklist_conn)

cat("Data Representation:\n", file = checklist_conn)
cat("  [ ] All axes labeled with units\n", file = checklist_conn)
cat("  [ ] Error bars or confidence intervals shown where applicable\n", file = checklist_conn)
cat("  [ ] Statistics reported in captions or figure\n", file = checklist_conn)
cat("  [ ] Legend present and clear\n\n", file = checklist_conn)

cat("Supplementary Material:\n", file = checklist_conn)
cat("  [ ] Figure captions complete and informative\n", file = checklist_conn)
cat("  [ ] Methods section describes analysis\n", file = checklist_conn)
cat("  [ ] All figures cited in main text\n\n", file = checklist_conn)

cat("Quality Control:\n", file = checklist_conn)
cat("  [ ] Figures proofread for accuracy\n", file = checklist_conn)
cat("  [ ] File sizes reasonable for submission\n", file = checklist_conn)
cat("  [ ] Figures open correctly in multiple viewers\n", file = checklist_conn)

close(checklist_conn)
log_msg(paste("  Wrote:", checklist_file))

# ============================================================================
# 6. COMPLETION
# ============================================================================

log_msg("=== PHASE 4.6 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 4.6 complete. Check log at:", LOG_FILE, "\n")
