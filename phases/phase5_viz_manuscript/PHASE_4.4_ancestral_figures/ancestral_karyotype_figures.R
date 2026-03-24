#!/usr/bin/env Rscript
################################################################################
#
# PHASE 4.4 — ANCESTRAL KARYOTYPE FIGURES
# Coleoptera Whole-Genome Alignment: Visualization & Manuscript
#
# PURPOSE:
#   Create schematic chromosome diagrams for major ancestral nodes.
#   Show chromosome pairs with synteny block coloring.
#   Overlay rearrangements between adjacent nodes in tree.
#
# INPUT:
#   - ancestral_linkage_groups.csv    Ancestral chromosome characteristics
#   - ancestral_karyotypes.csv        Inferred 2n and structure
#   - rearrangements_mapped.tsv       Rearrangement events
#
# OUTPUT:
#   - ancestral_karyotype_figures.pdf Schematic chromosome diagrams
#   - ancestral_figures.log           Processing log
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

## <<<STUDENT: Update input directories>>>
KARYOTYPE_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.6_ancestral_karyotypes")
REARR_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.4_ancestral_figures")

KARYOTYPE_FILE <- file.path(KARYOTYPE_INPUT_DIR, "ancestral_karyotypes.csv")
LINKAGE_FILE <- file.path(KARYOTYPE_INPUT_DIR, "ancestral_linkage_groups.csv")
REARR_FILE <- file.path(REARR_INPUT_DIR, "rearrangements_mapped.tsv")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "ancestral_figures.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 4.4: Ancestral Karyotype Figures ===")

# ============================================================================
# 1. READ DATA
# ============================================================================

log_msg("Reading ancestral karyotype data...")
if (!file.exists(KARYOTYPE_FILE)) {
  log_msg(paste("ERROR: Karyotype file not found:", KARYOTYPE_FILE))
  stop("Karyotype file missing")
}

karyotypes <- read.csv(KARYOTYPE_FILE, header = TRUE)
log_msg(paste("  Loaded", nrow(karyotypes), "ancestral karyotypes"))

log_msg("Reading linkage group details...")
if (!file.exists(LINKAGE_FILE)) {
  log_msg(paste("WARNING: Linkage file not found:", LINKAGE_FILE))
  linkage_groups <- NULL
} else {
  linkage_groups <- read.csv(LINKAGE_FILE, header = TRUE)
  log_msg(paste("  Loaded", nrow(linkage_groups), "linkage groups"))
}

log_msg("Reading rearrangements...")
if (!file.exists(REARR_FILE)) {
  log_msg(paste("WARNING: Rearrangement file not found:", REARR_FILE))
  rearrangements <- NULL
} else {
  rearrangements <- read.delim(REARR_FILE, header = TRUE, sep = "\t")
  log_msg(paste("  Loaded", nrow(rearrangements), "rearrangements"))
}

# ============================================================================
# 2. SELECT KEY NODES FOR VISUALIZATION
# ============================================================================

log_msg("Selecting key ancestral nodes for visualization...")

## <<<STUDENT: Select which nodes to show (e.g., MRCA of major clades)>>>
# Strategy: Show phylogenetically important nodes

# Use top nodes by coverage or select specific clades
key_nodes <- head(karyotypes$ancestral_node, 4)

log_msg(paste("  Selected", length(key_nodes), "nodes for detailed diagrams"))

# ============================================================================
# 3. GENERATE CHROMOSOME DIAGRAMS
# ============================================================================

log_msg("Generating chromosome diagrams...")

tryCatch({
  pdf_file <- file.path(OUTPUT_DIR, "ancestral_karyotype_figures.pdf")

  pdf(pdf_file, width = 11, height = 8.5, pointsize = 10)

  for (node in key_nodes) {
    log_msg(paste("  Drawing diagram for node:", node))

    # Get karyotype info
    node_kary <- subset(karyotypes, ancestral_node == node)

    if (nrow(node_kary) == 0) {
      log_msg(paste("    WARNING: No karyotype data for", node))
      next
    }

    kary <- node_kary[1, ]

    # Get linkage groups for this node
    node_linkage <- NULL
    if (!is.null(linkage_groups)) {
      node_linkage <- subset(linkage_groups, ancestral_node == node)
    }

    # Get rearrangements involving this node
    node_rearrs <- NULL
    if (!is.null(rearrangements)) {
      node_rearrs <- subset(rearrangements,
                           ancestral_node == node |
                           ancestral_node_branch == node)
    }

    # ====================================================================
    # Draw page with chromosome diagrams
    # ====================================================================

    plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")

    # Title
    title_text <- paste("Ancestral Karyotype: ", node,
                       " (2n = ", kary$inferred_2n, ")", sep = "")
    text(0.5, 0.95, title_text, cex = 1.5, font = 2, hjust = 0.5)

    # Draw chromosome pairs
    n_chrs <- kary$n_linkage_groups
    n_pairs <- ceiling(n_chrs / 2)

    chr_width <- 0.08
    chr_height <- 0.3
    margin_x <- 0.05
    margin_y <- 0.15

    chr_colors <- hcl.colors(n_chrs, "Set 3")

    chr_idx <- 1

    for (pair_idx in seq_len(n_pairs)) {
      # Position of this pair
      col <- (pair_idx - 1) %% 5
      row <- floor((pair_idx - 1) / 5)

      x_base <- margin_x + col * 0.18
      y_base <- 0.7 - row * 0.35

      # Draw first chromosome of pair
      if (chr_idx <= n_chrs) {
        # Draw as vertical rectangle
        rect(x_base, y_base - chr_height / 2,
             x_base + chr_width, y_base + chr_height / 2,
             col = chr_colors[chr_idx], border = "black", lwd = 2)

        # Label
        text(x_base + chr_width / 2, y_base + chr_height / 2 + 0.05,
             paste("Chr", chr_idx), cex = 0.8, adj = 0.5, hjust = 0.5)

        chr_idx <- chr_idx + 1
      }

      # Draw second chromosome of pair
      if (chr_idx <= n_chrs) {
        # Draw as vertical rectangle
        rect(x_base + chr_width + 0.02, y_base - chr_height / 2,
             x_base + 2 * chr_width + 0.02, y_base + chr_height / 2,
             col = chr_colors[chr_idx], border = "black", lwd = 2)

        # Label
        text(x_base + chr_width + 0.02 + chr_width / 2,
             y_base + chr_height / 2 + 0.05,
             paste("Chr", chr_idx), cex = 0.8, adj = 0.5, hjust = 0.5)

        chr_idx <- chr_idx + 1
      }
    }

    # Add summary information
    y_info <- 0.1

    text(0.05, y_info, "Summary:", cex = 1.0, font = 2, hjust = 0)
    y_info <- y_info - 0.04

    text(0.05, y_info, paste("Chromosome pairs (n):", kary$n_linkage_groups),
         cex = 0.9, hjust = 0)
    y_info <- y_info - 0.03

    text(0.05, y_info, paste("Inferred 2n:", kary$inferred_2n),
         cex = 0.9, hjust = 0)
    y_info <- y_info - 0.03

    text(0.05, y_info, paste("Species support:", kary$n_species_supporting),
         cex = 0.9, hjust = 0)
    y_info <- y_info - 0.03

    if (!is.null(node_rearrs) && nrow(node_rearrs) > 0) {
      n_fusion <- sum(node_rearrs$type == "fusion")
      n_fission <- sum(node_rearrs$type == "fission")
      n_inversion <- sum(node_rearrs$type == "inversion")
      n_translocation <- sum(node_rearrs$type == "translocation")

      rearr_text <- paste("Rearrangements: ", nrow(node_rearrs),
                         " (fusions:", n_fusion,
                         ", fissions:", n_fission,
                         ", inversions:", n_inversion,
                         ", translocations:", n_translocation, ")", sep = "")

      text(0.05, y_info, rearr_text, cex = 0.9, hjust = 0)
    }

    if (kary$notes != "") {
      y_info <- y_info - 0.03
      text(0.05, y_info, paste("Notes:", kary$notes),
           cex = 0.85, hjust = 0, style = "italic")
    }
  }

  dev.off()

  log_msg(paste("  Wrote:", pdf_file))

}, error = function(e) {
  log_msg(paste("  ERROR generating diagrams:", e$message))
})

# ============================================================================
# 4. CREATE COMPARISON DIAGRAMS (ADJACENT NODES)
# ============================================================================

log_msg("Attempting to create rearrangement overlay diagrams...")

tryCatch({
  pdf_file <- file.path(OUTPUT_DIR, "ancestral_karyotype_transitions.pdf")

  pdf(pdf_file, width = 11, height = 8.5, pointsize = 10)

  # For each rearrangement, show before/after karyotype
  for (i in seq_len(min(nrow(rearrangements), 4))) {
    rearr <- rearrangements[i, ]

    anc_node <- rearr$ancestral_node_branch
    der_node <- rearr$derived_node_branch
    rtype <- rearr$type

    # Get karyotypes
    anc_kary <- subset(karyotypes, ancestral_node == anc_node)
    der_kary <- subset(karyotypes, ancestral_node == der_node)

    if (nrow(anc_kary) == 0 || nrow(der_kary) == 0) {
      next
    }

    anc <- anc_kary[1, ]
    der <- der_kary[1, ]

    # Create comparison diagram
    plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")

    title_text <- paste("Rearrangement:", rtype, "(",
                       anc_node, "→", der_node, ")")
    text(0.5, 0.95, title_text, cex = 1.3, font = 2, hjust = 0.5)

    # Ancestral karyotype on left
    text(0.25, 0.85, paste(anc_node, "(2n =", anc$inferred_2n, ")"),
         cex = 1.0, font = 2, hjust = 0.5)

    # Draw simple chromosome representation
    rect(0.15, 0.4, 0.35, 0.8, col = "lightblue", border = "black")
    text(0.25, 0.55, "Ancestral", cex = 0.9, hjust = 0.5, font = 1)

    # Arrow
    arrows(0.4, 0.6, 0.6, 0.6, length = 0.1, lwd = 2)

    # Derived karyotype on right
    text(0.75, 0.85, paste(der_node, "(2n =", der$inferred_2n, ")"),
         cex = 1.0, font = 2, hjust = 0.5)

    # Draw simple chromosome representation
    rect(0.65, 0.4, 0.85, 0.8, col = "lightcoral", border = "black")
    text(0.75, 0.55, "Derived", cex = 0.9, hjust = 0.5, font = 1)

    # Describe rearrangement
    y_desc <- 0.35

    text(0.5, y_desc, paste("Type:", rtype), cex = 0.95, hjust = 0.5)
    y_desc <- y_desc - 0.05

    if (!is.na(rearr$chr_involved)) {
      text(0.5, y_desc, paste("Chromosomes:", rearr$chr_involved),
           cex = 0.95, hjust = 0.5)
    }
  }

  dev.off()

  log_msg(paste("  Wrote transition diagrams:", pdf_file))

}, error = function(e) {
  log_msg(paste("  Could not create transition diagrams:", e$message))
})

# ============================================================================
# 5. SUMMARY TABLE
# ============================================================================

log_msg("Creating summary table...")

summary_file <- file.path(OUTPUT_DIR, "ancestral_karyotypes_summary.txt")
summary_conn <- file(summary_file, open = "w")

cat("ANCESTRAL KARYOTYPE SUMMARY\n", file = summary_conn)
cat("=" %*% 60, "\n\n", file = summary_conn)

for (i in seq_len(nrow(karyotypes))) {
  kary <- karyotypes[i, ]

  cat("Node:", kary$ancestral_node, "\n", file = summary_conn)
  cat("  Inferred 2n:", kary$inferred_2n, "\n", file = summary_conn)
  cat("  Linkage groups (n):", kary$n_linkage_groups, "\n",
      file = summary_conn)
  cat("  Species support:", kary$n_species_supporting, "\n",
      file = summary_conn)
  cat("  Average block size:", round(kary$avg_block_size_kb, 1), "kb\n",
      file = summary_conn)

  if (kary$notes != "") {
    cat("  Notes:", kary$notes, "\n", file = summary_conn)
  }

  cat("\n", file = summary_conn)
}

close(summary_conn)
log_msg(paste("  Wrote:", summary_file))

# ============================================================================
# 6. COMPLETION
# ============================================================================

log_msg("=== PHASE 4.4 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 4.4 complete. Check log at:", LOG_FILE, "\n")
