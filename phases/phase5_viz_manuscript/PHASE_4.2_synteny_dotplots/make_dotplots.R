#!/usr/bin/env Rscript
################################################################################
#
# PHASE 4.2 — SYNTENY DOTPLOT GENERATION
# Coleoptera Whole-Genome Alignment: Visualization & Manuscript
#
# PURPOSE:
#   Generate comparative genomics dotplots showing synteny between species.
#   X-axis: species A chromosomes, Y-axis: species B chromosomes.
#   Points colored by block orientation (forward/reverse).
#
# INPUT:
#   - synteny_anchored.tsv     Synteny blocks with all coordinates
#
# OUTPUT:
#   - synteny_dotplots.pdf     Multi-page figure (one per species pair)
#   - make_dotplots.log        Processing log
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

## <<<STUDENT: Update input directory>>>
SYNTENY_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase3_alignment_synteny")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.2_synteny_dotplots")

SYNTENY_FILE <- file.path(SYNTENY_INPUT_DIR, "synteny_anchored.tsv")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "make_dotplots.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 4.2: Synteny Dotplot Generation ===")

# ============================================================================
# 1. READ DATA
# ============================================================================

log_msg("Reading synteny blocks...")
if (!file.exists(SYNTENY_FILE)) {
  log_msg(paste("ERROR: Synteny file not found:", SYNTENY_FILE))
  stop("Synteny file missing")
}

synteny <- read.delim(SYNTENY_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(synteny), "synteny blocks"))

# ============================================================================
# 2. IDENTIFY REPRESENTATIVE SPECIES PAIRS
# ============================================================================

log_msg("Identifying species pairs for dotplots...")

## <<<STUDENT: Select which species pairs to visualize>>>
# Strategy: Choose diverse representatives from different beetle families
# Example: Show comparisons across major clades

# Get all unique species pairs
species_pairs <- unique(synteny[, c("extant_species", "ancestral_species")])
log_msg(paste("  Total possible species pairs:", nrow(species_pairs)))

# For demonstration, select top pairs by number of synteny blocks
pair_counts <- aggregate(block_id ~ extant_species + ancestral_species,
                        data = synteny, FUN = length)
pair_counts <- pair_counts[order(pair_counts$block_id, decreasing = TRUE), ]

## <<<STUDENT: Set how many pairs to visualize (default: top 6)>>>
N_PAIRS_TO_PLOT <- min(6, nrow(pair_counts))

selected_pairs <- pair_counts[seq_len(N_PAIRS_TO_PLOT), ]
log_msg(paste("  Selected", N_PAIRS_TO_PLOT, "representative pairs for plotting"))

for (i in seq_len(nrow(selected_pairs))) {
  sp_pair <- selected_pairs[i, ]
  log_msg(paste("    ", sp_pair$extant_species, "vs",
                sp_pair$ancestral_species, "(", sp_pair$block_id, "blocks)"))
}

# ============================================================================
# 3. GENERATE DOTPLOTS
# ============================================================================

log_msg("Generating dotplots...")

tryCatch({
  pdf_file <- file.path(OUTPUT_DIR, "synteny_dotplots.pdf")

  pdf(pdf_file, width = 10, height = 10, pointsize = 10)

  for (i in seq_len(nrow(selected_pairs))) {
    sp_pair <- selected_pairs[i, ]
    extant_sp <- sp_pair$extant_species
    ancestral_sp <- sp_pair$ancestral_species

    log_msg(paste("  Plotting:", extant_sp, "vs", ancestral_sp))

    # Get synteny blocks for this pair
    pair_synteny <- subset(synteny,
                          extant_species == extant_sp &
                          ancestral_species == ancestral_sp)

    # Get chromosome information
    extant_chrs <- sort(unique(pair_synteny$extant_chr))
    ancestral_chrs <- sort(unique(pair_synteny$ancestral_chr))

    # Prepare coordinates for plotting
    # Need to convert chromosome IDs to numeric positions on axes

    # Create numeric x-axis (species A chromosomes)
    x_mapping <- setNames(seq_along(extant_chrs), extant_chrs)
    pair_synteny$x_pos <- x_mapping[as.character(pair_synteny$extant_chr)]
    pair_synteny$x_coord <- pair_synteny$x_pos +
                            (pair_synteny$extant_start / max(pair_synteny$extant_end))

    # Create numeric y-axis (species B chromosomes)
    y_mapping <- setNames(seq_along(ancestral_chrs), ancestral_chrs)
    pair_synteny$y_pos <- y_mapping[as.character(pair_synteny$ancestral_chr)]
    pair_synteny$y_coord <- pair_synteny$y_pos +
                            (pair_synteny$ancestral_start / max(pair_synteny$ancestral_end))

    # Assign colors by orientation
    pair_synteny$point_color <- ifelse(
      pair_synteny$orientation %in% c("+", "forward"),
      "steelblue",
      "coral"
    )

    # Create plot
    plot(pair_synteny$x_coord, pair_synteny$y_coord,
         type = "p", pch = 16, cex = 1.5,
         col = pair_synteny$point_color,
         xlim = c(0.5, length(extant_chrs) + 0.5),
         ylim = c(0.5, length(ancestral_chrs) + 0.5),
         xlab = paste(extant_sp, "- Chromosome"),
         ylab = paste(ancestral_sp, "- Chromosome"),
         main = paste("Synteny Comparison:", extant_sp, "vs", ancestral_sp),
         axes = FALSE)

    # Add chromosome labels on axes
    axis(1, at = seq_along(extant_chrs), labels = extant_chrs)
    axis(2, at = seq_along(ancestral_chrs), labels = ancestral_chrs)
    box()

    # Add grid
    abline(v = seq(1, length(extant_chrs)), lty = 3, col = "lightgray")
    abline(h = seq(1, length(ancestral_chrs)), lty = 3, col = "lightgray")

    # Add legend
    legend("topright", legend = c("Forward (+)", "Reverse (-)"),
           pch = 16, col = c("steelblue", "coral"), cex = 1.0)

    # Add summary statistics
    n_blocks <- nrow(pair_synteny)
    n_forward <- sum(pair_synteny$orientation %in% c("+", "forward"))
    n_reverse <- sum(pair_synteny$orientation %in% c("-", "reverse"))

    text(0.5, -0.05, paste("Synteny blocks:", n_blocks,
                          "| Forward:", n_forward,
                          "| Reverse:", n_reverse),
         xpd = TRUE, cex = 0.9)
  }

  dev.off()

  log_msg(paste("  Wrote:", pdf_file))

}, error = function(e) {
  log_msg(paste("  ERROR generating dotplots:", e$message))
  # Still try to create a simple version
  log_msg("  Attempting fallback visualization...")
})

# ============================================================================
# 4. ATTEMPT GGPLOT2 ENHANCED VERSION
# ============================================================================

log_msg("Attempting to generate enhanced dotplots with ggplot2...")

tryCatch({
  library(ggplot2)
  library(gridExtra)

  # Create list to store plots
  plot_list <- list()

  for (i in seq_len(min(nrow(selected_pairs), 3))) {
    sp_pair <- selected_pairs[i, ]
    extant_sp <- sp_pair$extant_species
    ancestral_sp <- sp_pair$ancestral_species

    pair_synteny <- subset(synteny,
                          extant_species == extant_sp &
                          ancestral_species == ancestral_sp)

    # Prepare data
    extant_chrs <- sort(unique(pair_synteny$extant_chr))
    ancestral_chrs <- sort(unique(pair_synteny$ancestral_chr))

    x_mapping <- setNames(seq_along(extant_chrs), extant_chrs)
    y_mapping <- setNames(seq_along(ancestral_chrs), ancestral_chrs)

    plot_data <- data.frame(
      extant_chr = pair_synteny$extant_chr,
      ancestral_chr = pair_synteny$ancestral_chr,
      x_pos = x_mapping[as.character(pair_synteny$extant_chr)],
      y_pos = y_mapping[as.character(pair_synteny$ancestral_chr)],
      orientation = ifelse(pair_synteny$orientation %in% c("+", "forward"),
                           "Forward", "Reverse")
    )

    # Create ggplot
    p <- ggplot(plot_data, aes(x = x_pos, y = y_pos, color = orientation)) +
      geom_point(size = 2.5, alpha = 0.7) +
      scale_color_manual(values = c("Forward" = "#1f77b4", "Reverse" = "#ff7f0e")) +
      scale_x_continuous(breaks = seq_along(extant_chrs),
                        labels = extant_chrs,
                        limits = c(0.5, length(extant_chrs) + 0.5)) +
      scale_y_continuous(breaks = seq_along(ancestral_chrs),
                        labels = ancestral_chrs,
                        limits = c(0.5, length(ancestral_chrs) + 0.5)) +
      labs(title = paste(extant_sp, "vs", ancestral_sp),
           x = paste(extant_sp, "Chromosome"),
           y = paste(ancestral_sp, "Chromosome"),
           color = "Orientation") +
      theme_minimal() +
      theme(plot.title = element_text(size = 12, hjust = 0.5, face = "bold"),
            axis.title = element_text(size = 10),
            panel.grid.major = element_line(color = "lightgray", size = 0.3),
            legend.position = "bottomright")

    plot_list[[i]] <- p
  }

  # Save combined plot
  if (length(plot_list) > 0) {
    combined_file <- file.path(OUTPUT_DIR, "synteny_dotplots_ggplot.pdf")

    pdf(combined_file, width = 12, height = 4 * ceiling(length(plot_list) / 2))

    if (length(plot_list) == 1) {
      print(plot_list[[1]])
    } else {
      grid_plot <- do.call(gridExtra::grid.arrange,
                          c(plot_list, list(ncol = 2)))
      print(grid_plot)
    }

    dev.off()

    log_msg(paste("  Wrote enhanced version:", combined_file))
  }

}, error = function(e) {
  log_msg(paste("  ggplot2 not available or error:", e$message))
})

# ============================================================================
# 5. GENERATE FIGURE CAPTIONS
# ============================================================================

log_msg("Creating figure captions...")

caption_file <- file.path(OUTPUT_DIR, "figure_captions.txt")
caption_conn <- file(caption_file, open = "w")

cat("SYNTENY DOTPLOTS\n\n", file = caption_conn)

for (i in seq_len(nrow(selected_pairs))) {
  sp_pair <- selected_pairs[i, ]
  pair_synteny <- subset(synteny,
                        extant_species == sp_pair$extant_species &
                        ancestral_species == sp_pair$ancestral_species)
  n_blocks <- nrow(pair_synteny)

  cat("FIGURE:", paste(sp_pair$extant_species, "vs", sp_pair$ancestral_species),
      "\n", file = caption_conn)
  cat("Dotplot showing synteny blocks between", sp_pair$extant_species,
      "and", sp_pair$ancestral_species, ".\n", file = caption_conn)
  cat("X-axis: chromosomes of", sp_pair$extant_species, ".\n",
      file = caption_conn)
  cat("Y-axis: chromosomes of", sp_pair$ancestral_species, ".\n",
      file = caption_conn)
  cat("Points represent aligned synteny blocks (n =", n_blocks, ").\n",
      file = caption_conn)
  cat("Blue = forward orientation; Orange = reverse orientation.\n\n",
      file = caption_conn)
}

close(caption_conn)
log_msg(paste("  Wrote:", caption_file))

# ============================================================================
# 6. COMPLETION
# ============================================================================

log_msg("=== PHASE 4.2 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 4.2 complete. Check log at:", LOG_FILE, "\n")
