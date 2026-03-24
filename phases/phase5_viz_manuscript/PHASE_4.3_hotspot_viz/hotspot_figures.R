#!/usr/bin/env Rscript
################################################################################
#
# PHASE 4.3 — HOTSPOT VISUALIZATION
# Coleoptera Whole-Genome Alignment: Visualization & Manuscript
#
# PURPOSE:
#   Generate circular tree with rearrangement heatmap.
#   Create genome-wide rearrangement density plots.
#   Visualize hotspot branches and high-rate regions.
#
# INPUT:
#   - rearrangements_per_branch.tsv    Branch statistics
#   - rearrangements_mapped.tsv        Individual rearrangements
#   - constraint_tree.nwk              Phylogenetic tree
#
# OUTPUT:
#   - hotspot_figures.pdf              Multi-page visualization
#   - hotspot_figures.log              Processing log
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
STATS_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.4_branch_stats")
REARR_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping")
TREE_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase3_alignment_synteny")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.3_hotspot_viz")

STATS_FILE <- file.path(STATS_INPUT_DIR, "rearrangements_per_branch.tsv")
REARR_FILE <- file.path(REARR_INPUT_DIR, "rearrangements_mapped.tsv")
TREE_FILE <- file.path(TREE_INPUT_DIR, "constraint_tree.nwk")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "hotspot_figures.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 4.3: Hotspot Visualization ===")

# ============================================================================
# 1. READ DATA
# ============================================================================

log_msg("Reading branch statistics...")
if (!file.exists(STATS_FILE)) {
  log_msg(paste("ERROR: Stats file not found:", STATS_FILE))
  stop("Stats file missing")
}

branch_stats <- read.delim(STATS_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(branch_stats), "branch statistics"))

log_msg("Reading rearrangements...")
if (!file.exists(REARR_FILE)) {
  log_msg(paste("ERROR: Rearrangement file not found:", REARR_FILE))
  stop("Rearrangement file missing")
}

rearrangements <- read.delim(REARR_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(rearrangements), "rearrangements"))

log_msg("Reading tree...")
if (!file.exists(TREE_FILE)) {
  log_msg(paste("WARNING: Tree file not found:", TREE_FILE))
} else {
  tree_str <- readLines(TREE_FILE)
  log_msg("  Tree file loaded")
}

# ============================================================================
# 2. IDENTIFY HOTSPOT BRANCHES
# ============================================================================

log_msg("Identifying hotspot branches...")

hotspots <- subset(branch_stats, is_hotspot == TRUE)
log_msg(paste("  Found", nrow(hotspots), "hotspot branches"))

if (nrow(hotspots) > 0) {
  for (i in seq_len(min(nrow(hotspots), 5))) {
    hs <- hotspots[i, ]
    log_msg(paste("    ", hs$branch_id, "- rate =", round(hs$rearrangement_rate, 4)))
  }
}

# ============================================================================
# 3. SUMMARIZE BY REARRANGEMENT TYPE
# ============================================================================

log_msg("Summarizing rearrangements by type and species...")

# Create matrix: species × rearrangement_type
species_list <- unique(rearrangements$species)
type_list <- unique(rearrangements$type)

heatmap_data <- matrix(0, nrow = length(species_list),
                       ncol = length(type_list))
rownames(heatmap_data) <- species_list
colnames(heatmap_data) <- type_list

for (sp in species_list) {
  for (tp in type_list) {
    count <- sum(rearrangements$species == sp & rearrangements$type == tp)
    heatmap_data[sp, tp] <- count
  }
}

log_msg("Heatmap data prepared:")
log_msg(paste("  Dimensions:", nrow(heatmap_data), "species ×",
              ncol(heatmap_data), "types"))

# ============================================================================
# 4. GENERATE FIGURES
# ============================================================================

log_msg("Generating figures...")

tryCatch({
  pdf_file <- file.path(OUTPUT_DIR, "hotspot_figures.pdf")

  pdf(pdf_file, width = 11, height = 8.5, pointsize = 10)

  # ========================================================================
  # Page 1: Branch rate distribution with hotspots highlighted
  # ========================================================================

  log_msg("  Creating branch rate histogram...")

  valid_rates <- branch_stats$rearrangement_rate[!is.na(branch_stats$rearrangement_rate)]

  if (length(valid_rates) > 0) {
    hist(valid_rates, breaks = 10, col = "steelblue", alpha = 0.7,
         xlab = "Rearrangement Rate (per Myr)",
         ylab = "Number of Branches",
         main = "Distribution of Rearrangement Rates Across Branches",
         cex.main = 1.3)

    # Mark hotspot threshold
    if (nrow(hotspots) > 0) {
      max_rate <- max(valid_rates)
      abline(v = min(hotspots$rearrangement_rate, na.rm = TRUE),
             col = "red", lwd = 2, lty = 2)
      legend("topright", "Hotspot threshold", col = "red", lty = 2, lwd = 2)
    }
  }

  # ========================================================================
  # Page 2: Heatmap of rearrangements by species and type
  # ========================================================================

  log_msg("  Creating heatmap (species × type)...")

  # Simple heatmap using color intensity
  # For better quality, use heatmap() or gplots::heatmap.2 if available

  # Normalize for color scale
  heatmap_normalized <- heatmap_data / apply(heatmap_data, 1, max)

  # Create color palette
  colors <- colorRampPalette(c("white", "lightblue", "steelblue", "darkblue"))(100)

  # Plot heatmap manually
  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "",
       main = "Rearrangement Heatmap: Species × Type")

  # Draw grid with colors
  n_sp <- nrow(heatmap_data)
  n_type <- ncol(heatmap_data)

  cell_width <- 1 / (n_type + 1)
  cell_height <- 1 / (n_sp + 2)

  for (i in seq_len(n_sp)) {
    for (j in seq_len(n_type)) {
      # Determine color based on value
      value <- heatmap_normalized[i, j]
      color_idx <- ceiling(value * 100)
      color <- colors[max(1, min(100, color_idx))]

      # Draw cell
      x0 <- j * cell_width
      y0 <- 1 - (i + 1) * cell_height
      x1 <- (j + 1) * cell_width
      y1 <- 1 - i * cell_height

      rect(x0, y0, x1, y1, col = color, border = "black")

      # Add count text
      count <- heatmap_data[i, j]
      if (count > 0) {
        text((x0 + x1) / 2, (y0 + y1) / 2, as.character(count),
             cex = 0.8)
      }
    }
  }

  # Add labels
  for (j in seq_len(n_type)) {
    x_mid <- (j + 0.5) * cell_width
    text(x_mid, 1 - cell_height / 2, colnames(heatmap_data)[j],
         cex = 0.9, adj = 0.5)
  }

  for (i in seq_len(n_sp)) {
    y_mid <- 1 - (i + 0.5) * cell_height
    text(0.02, y_mid, rownames(heatmap_data)[i],
         cex = 0.7, adj = 0, srt = 0)
  }

  # Add scale legend
  text(0.95, 0.05, "Color: White (0) → Blue (max)",
       cex = 0.9, adj = 1)

  # ========================================================================
  # Page 3: Top rearrangement hotspots
  # ========================================================================

  log_msg("  Creating top hotspots figure...")

  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "",
       main = "Rearrangement Hotspots")

  # Display top 10 hottest branches
  if (nrow(branch_stats) > 0) {
    top_hotspots <- head(branch_stats[order(branch_stats$total_rearrangements,
                                            decreasing = TRUE), ], 10)

    y_pos <- 0.95
    text(0.5, y_pos, "Top 10 Branches by Rearrangement Count",
         cex = 1.2, font = 2, hjust = 0.5)
    y_pos <- y_pos - 0.08

    for (i in seq_len(nrow(top_hotspots))) {
      row <- top_hotspots[i, ]

      branch_label <- paste(i, ". ", row$branch_id, ": ",
                           row$total_rearrangements, " events",
                           sep = "")

      text(0.1, y_pos, branch_label, cex = 0.95, hjust = 0, font = 1)

      # Add bar
      bar_width <- row$total_rearrangement / max(branch_stats$total_rearrangements)
      rect(0.5, y_pos - 0.02, 0.5 + bar_width * 0.4, y_pos + 0.02,
           col = "steelblue")

      y_pos <- y_pos - 0.07
    }
  }

  # ========================================================================
  # Page 4: Rearrangement type distribution
  # ========================================================================

  log_msg("  Creating type distribution pie chart...")

  type_counts <- table(rearrangements$type)

  plot(NULL, xlim = -1.2:1.2, ylim = -1.2:1.2, axes = FALSE,
       xlab = "", ylab = "", main = "Rearrangement Type Distribution",
       asp = 1)

  # Pie chart
  pie_colors <- c("fusion" = "#1f77b4", "fission" = "#ff7f0e",
                  "inversion" = "#2ca02c", "translocation" = "#d62728")

  pie(type_counts, labels = names(type_counts),
      col = pie_colors[names(type_counts)],
      main = "")

  text(-1.2, -1.2, paste("Total:", sum(type_counts), "rearrangements"),
       cex = 0.9)

  dev.off()

  log_msg(paste("  Wrote:", pdf_file))

}, error = function(e) {
  log_msg(paste("  ERROR generating figures:", e$message))
})

# ============================================================================
# 5. ATTEMPT GGPLOT2 ENHANCED VERSION
# ============================================================================

log_msg("Attempting enhanced visualization with ggplot2...")

tryCatch({
  library(ggplot2)

  # Create data frame for type distribution
  type_dist <- data.frame(
    type = names(type_counts),
    count = as.numeric(type_counts)
  )

  # Type distribution plot
  p_type <- ggplot(type_dist, aes(x = reorder(type, -count), y = count,
                                  fill = type)) +
    geom_bar(stat = "identity") +
    scale_fill_manual(values = c("fusion" = "#1f77b4", "fission" = "#ff7f0e",
                                 "inversion" = "#2ca02c",
                                 "translocation" = "#d62728")) +
    labs(title = "Rearrangement Type Distribution",
         x = "Type",
         y = "Count",
         fill = "Type") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          plot.title = element_text(hjust = 0.5, size = 14, face = "bold"))

  gg_file <- file.path(OUTPUT_DIR, "hotspot_ggplot.pdf")

  pdf(gg_file, width = 8, height = 6)
  print(p_type)
  dev.off()

  log_msg(paste("  Wrote ggplot version:", gg_file))

}, error = function(e) {
  log_msg(paste("  ggplot2 not available:", e$message))
})

# ============================================================================
# 6. COMPLETION
# ============================================================================

log_msg("=== PHASE 4.3 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 4.3 complete. Check log at:", LOG_FILE, "\n")
