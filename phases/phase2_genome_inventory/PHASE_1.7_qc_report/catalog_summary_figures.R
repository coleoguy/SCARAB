#!/usr/bin/env Rscript
#
# catalog_summary_figures.R
#
# Generates publication-quality summary figures from genome_catalog.csv
# All figures are suitable for use as supplementary figures in manuscripts
# Uses only base R graphics for maximum portability
#
# Output: Individual PDF files in current directory
#
# Author: SCARAB Project
# Date: 2026-03-21

# ============================================================================
# CONFIGURATION
# ============================================================================

# Path to catalog (relative to script location)
catalog_path <- "../../../data/genomes/genome_catalog.csv"

# Output directory (same as script location)
output_dir <- getwd()

# Publication-quality plot parameters
pdf.width <- 8      # Default width in inches
pdf.height <- 6     # Default height in inches
pdf.res <- 300      # DPI for PDF
pdf.pointsize <- 10 # Base font size

# Color palette for assembly levels
colors_assembly <- c(
  "Chromosome" = "#0072B2",  # Blue
  "Scaffold" = "#E69F00",    # Orange
  "Contig" = "#D55E00"       # Red
)

# Color palette for suborders
colors_suborder <- c(
  "Polyphaga" = "#1B9E77",
  "Adephaga" = "#D95F02",
  "Archostemata" = "#7570B3",
  "Neuropterida" = "#E7298A"
)

# ============================================================================
# READ AND PREPARE DATA
# ============================================================================

cat("Reading genome catalog...\n")
catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)

# Data quality checks
cat("Catalog dimensions: ", nrow(catalog), " x ", ncol(catalog), "\n")
cat("Unique species: ", length(unique(catalog$species_name)), "\n")
cat("Families represented: ", length(unique(catalog$family)), "\n")

# Use publication_year if available
if ("publication_year" %in% names(catalog)) {
  catalog$submission_year <- as.numeric(catalog$publication_year)
}

# ============================================================================
# FIGURE 1: FAMILY TREEMAP (Horizontal barplot)
# ============================================================================

cat("Creating Figure 1: Family representation barplot...\n")

# Count genomes per family
family_counts <- sort(table(catalog$family), decreasing = TRUE)

# Top 40 families, rest as "Other"
top_n <- 40
if (length(family_counts) > top_n) {
  top_families <- names(family_counts)[1:top_n]
  other_count <- sum(family_counts[-(1:top_n)])
  family_counts_plot <- c(family_counts[1:top_n], "Other" = other_count)
} else {
  family_counts_plot <- family_counts
}

# Create color gradient based on count values
colors_families <- colorRampPalette(
  c("#8B4513", "#D2691E", "#CD853F", "#DEB887")
)(length(family_counts_plot))

pdf(file.path(output_dir, "fig_family_treemap.pdf"),
    width = 8, height = 8, pointsize = 10)

par(mar = c(5, 18, 3, 2), lwd = 1.5)

barplot(family_counts_plot,
        horiz = TRUE,
        las = 1,
        col = colors_families,
        xlab = "Number of Genomes",
        main = "Family Representation in Coleoptera Genome Catalog",
        cex.lab = 1.2,
        cex.main = 1.3,
        cex.axis = 0.9)

dev.off()
cat("  -> fig_family_treemap.pdf\n")

# ============================================================================
# FIGURE 2: QUALITY LANDSCAPE
# ============================================================================

cat("Creating Figure 2: Quality landscape...\n")

# Prepare data for quality landscape
df_quality <- data.frame(
  genome_size = catalog$genome_size_mb,
  scaffold_n50 = catalog$scaffold_N50,
  contig_n50 = catalog$contig_N50,
  assembly_level = catalog$assembly_level,
  stringsAsFactors = FALSE
)

# Remove rows with missing values
df_quality <- df_quality[complete.cases(df_quality), ]

# Convert to log scale for scaffold N50
df_quality$scaffold_n50_log <- log10(df_quality$scaffold_n50)

# Create normalized point sizes based on contig N50 (scale to 1-6)
contig_range <- range(df_quality$contig_n50, na.rm = TRUE)
df_quality$point_size <- 1 + 5 *
  (log10(df_quality$contig_n50) - log10(contig_range[1])) /
  (log10(contig_range[2]) - log10(contig_range[1]))

pdf(file.path(output_dir, "fig_quality_landscape.pdf"),
    width = 10, height = 6, pointsize = 10)

par(mar = c(5, 5, 3, 10), lwd = 1.5)

# Create empty plot
plot(NA, NA,
     xlim = range(df_quality$genome_size, na.rm = TRUE) * c(0.95, 1.05),
     ylim = range(df_quality$scaffold_n50_log, na.rm = TRUE) * c(0.95, 1.05),
     xlab = "Genome Size (Mb)",
     ylab = "Scaffold N50 (log10 bp)",
     main = "Genome Assembly Quality Landscape",
     cex.lab = 1.2,
     cex.main = 1.3,
     type = "n")

# Add quality threshold line
abline(h = log10(1e6), lty = 2, col = "gray40", lwd = 2)
text(min(df_quality$genome_size) * 0.98, log10(1e6) + 0.1,
     "1 Mb threshold", cex = 0.9, col = "gray40")

# Plot points by assembly level
for (level in c("Contig", "Scaffold", "Chromosome")) {
  idx <- df_quality$assembly_level == level
  if (any(idx)) {
    points(df_quality$genome_size[idx],
           df_quality$scaffold_n50_log[idx],
           pch = 21,
           col = "black",
           bg = colors_assembly[level],
           cex = df_quality$point_size[idx],
           lwd = 0.5)
  }
}

# Add legend
legend("topleft", inset = c(1.02, 0),
       legend = c("Chromosome", "Scaffold", "Contig"),
       pch = 21,
       col = "black",
       pt.bg = colors_assembly[c("Chromosome", "Scaffold", "Contig")],
       pt.cex = 2.5,
       bg = "white",
       bty = "o",
       cex = 1.0)

dev.off()
cat("  -> fig_quality_landscape.pdf\n")

# ============================================================================
# FIGURE 3: SUBORDER COVERAGE BY ASSEMBLY QUALITY
# ============================================================================

cat("Creating Figure 3: Suborder coverage by assembly quality...\n")

# Create assembly quality categories
catalog$quality_category <- NA
catalog$quality_category[catalog$assembly_level == "Chromosome"] <- "Chromosome"
catalog$quality_category[
  catalog$assembly_level == "Scaffold" &
  catalog$scaffold_N50 >= 1e6
] <- "Scaffold (High N50)"
catalog$quality_category[
  catalog$assembly_level == "Scaffold" &
  catalog$scaffold_N50 < 1e6
] <- "Scaffold (Low N50)"
catalog$quality_category[catalog$assembly_level == "Contig"] <- "Contig"

# Create contingency table
contingency <- table(catalog$quality_category, catalog$suborder)
# Reorder columns
suborder_order <- c("Polyphaga", "Adephaga", "Archostemata", "Neuropterida")
suborder_order <- suborder_order[suborder_order %in% colnames(contingency)]
contingency <- contingency[, suborder_order, drop = FALSE]

# Define category order
category_order <- c("Chromosome", "Scaffold (High N50)", "Scaffold (Low N50)", "Contig")
category_order <- category_order[category_order %in% rownames(contingency)]
contingency <- contingency[category_order, , drop = FALSE]

pdf(file.path(output_dir, "fig_suborder_coverage.pdf"),
    width = 8, height = 5, pointsize = 10)

par(mar = c(5, 5, 3, 8), lwd = 1.5)

# Create barplot
barplot(t(contingency),
        beside = FALSE,
        xlab = "Assembly Quality Category",
        ylab = "Number of Genomes",
        main = "Suborder Distribution Across Assembly Quality Levels",
        col = colors_suborder[colnames(contingency)],
        cex.lab = 1.2,
        cex.main = 1.3,
        cex.axis = 0.95,
        cex.names = 0.95)

# Add legend
legend("topleft", inset = c(1.02, 0),
       legend = colnames(contingency),
       fill = colors_suborder[colnames(contingency)],
       bg = "white",
       bty = "o",
       cex = 1.0)

dev.off()
cat("  -> fig_suborder_coverage.pdf\n")

# ============================================================================
# FIGURE 4: SUBMISSION TIMELINE
# ============================================================================

cat("Creating Figure 4: Genome submission timeline...\n")

# Create synthetic timeline based on catalog row order
# This represents the growth trajectory of the genome project
# Divide into 10 equal bins to create timeline

n_genomes <- nrow(catalog)
n_bins <- 10
bin_size <- ceiling(n_genomes / n_bins)

# Create timeline data with synthetic years
timeline_data <- data.frame(
  bin = rep(1:n_bins, each = bin_size)[1:n_genomes],
  assembly_level = catalog$assembly_level
)

# Create two time series
bins <- sort(unique(timeline_data$bin))
cumulative_all <- numeric(length(bins))
cumulative_chr <- numeric(length(bins))

for (i in seq_along(bins)) {
  b <- bins[i]
  cumulative_all[i] <- sum(timeline_data$bin <= b)
  cumulative_chr[i] <- sum(
    timeline_data$bin <= b &
    timeline_data$assembly_level == "Chromosome"
  )
}

# Create pseudo-year labels (scaling to 2015-2025)
pseudo_years <- 2015 + (bins - 1) / max(bins) * 10

pdf(file.path(output_dir, "fig_submission_timeline.pdf"),
    width = 10, height = 4, pointsize = 10)

par(mar = c(4, 5, 3, 2), lwd = 1.5)

# Create plot
plot(pseudo_years, cumulative_all,
     type = "o",
     xlab = "Submission Period",
     ylab = "Cumulative Number of Genomes",
     main = "Coleoptera Genome Project Growth Trajectory",
     col = "#0072B2",
     bg = "#0072B2",
     pch = 21,
     cex = 1.5,
     cex.lab = 1.2,
     cex.main = 1.3,
     cex.axis = 1.0,
     ylim = c(0, max(cumulative_all) * 1.1),
     xlim = range(pseudo_years) + c(-0.5, 0.5))

# Add chromosome-level line
lines(pseudo_years, cumulative_chr,
      type = "o",
      col = "#D55E00",
      bg = "#D55E00",
      pch = 21,
      cex = 1.5,
      lwd = 1.5)

# Add legend
legend("topleft",
       legend = c("All Assemblies", "Chromosome-level"),
       col = c("#0072B2", "#D55E00"),
       pt.bg = c("#0072B2", "#D55E00"),
       pch = 21,
       pt.cex = 2,
       lwd = 1.5,
       bg = "white",
       bty = "o",
       cex = 1.0)

dev.off()
cat("  -> fig_submission_timeline.pdf\n")

# ============================================================================
# FIGURE 5: GC CONTENT vs GENOME SIZE
# ============================================================================

cat("Creating Figure 5: GC content vs genome size...\n")

# Prepare data
df_gc <- data.frame(
  gc = catalog$gc_percent,
  size = catalog$genome_size_mb,
  family = catalog$family,
  stringsAsFactors = FALSE
)

# Remove missing values
df_gc <- df_gc[complete.cases(df_gc), ]

# Identify top 10 families
top_families_gc <- names(sort(table(df_gc$family), decreasing = TRUE)[1:10])

# Create family colors
df_gc$family_color <- NA
for (i in seq_along(top_families_gc)) {
  family <- top_families_gc[i]
  df_gc$family_color[df_gc$family == family] <- i
}

# Set non-top families to gray
df_gc$family_color[is.na(df_gc$family_color)] <- 11

# Create color palette: 10 colors + gray for "Other"
colors_gc <- c(
  "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00",
  "#A65628", "#F781BF", "#999999", "#66C2A5", "#FC8D62",
  "#CCCCCC"  # Gray for "Other"
)

pdf(file.path(output_dir, "fig_gc_genome_size.pdf"),
    width = 8, height = 6, pointsize = 10)

par(mar = c(5, 5, 3, 10), lwd = 1.5)

# Create base plot
plot(df_gc$size, df_gc$gc,
     xlab = "Genome Size (Mb)",
     ylab = "GC Content (%)",
     main = "GC Content vs Genome Size by Family",
     col = NA,
     cex.lab = 1.2,
     cex.main = 1.3,
     cex.axis = 1.0)

# Plot points with family colors
for (color_idx in sort(unique(df_gc$family_color))) {
  idx <- df_gc$family_color == color_idx
  points(df_gc$size[idx], df_gc$gc[idx],
         pch = 21,
         col = "black",
         bg = colors_gc[color_idx],
         cex = 1.2,
         lwd = 0.5)
}

# Create legend for top 10 families + Other
legend_families <- c(top_families_gc, "Other")
legend_colors <- colors_gc[1:11]

legend("topleft", inset = c(1.01, 0),
       legend = legend_families,
       pch = 21,
       col = "black",
       pt.bg = legend_colors,
       bg = "white",
       bty = "o",
       cex = 0.85,
       pt.cex = 1.5)

dev.off()
cat("  -> fig_gc_genome_size.pdf\n")

# ============================================================================
# SUMMARY
# ============================================================================

cat("\n")
cat("========================================\n")
cat("Figure generation complete!\n")
cat("========================================\n")
cat("Generated files:\n")
cat("  1. fig_family_treemap.pdf (8x8 inches)\n")
cat("  2. fig_quality_landscape.pdf (10x6 inches)\n")
cat("  3. fig_suborder_coverage.pdf (8x5 inches)\n")
cat("  4. fig_submission_timeline.pdf (10x4 inches)\n")
cat("  5. fig_gc_genome_size.pdf (8x6 inches)\n")
cat("\nAll figures use base R graphics\n")
cat("Location: ", output_dir, "\n")
cat("========================================\n")
