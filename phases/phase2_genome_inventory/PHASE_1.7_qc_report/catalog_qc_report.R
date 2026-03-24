#!/usr/bin/env Rscript
################################################################################
# SCARAB: Genome Inventory QC Report
#
# This script generates a comprehensive multi-page PDF QC report from the
# genome_catalog.csv file. It includes assembly-level summaries, quality
# metrics, family coverage analysis, and outgroup assessment.
#
# Usage: Rscript catalog_qc_report.R
################################################################################

# Set working directory to script location
script.dir <- dirname(normalizePath(ifelse(interactive(), "", commandArgs(trailingOnly=FALSE)[1])))
if (!grepl("^/", script.dir)) {
  script.dir <- getwd()
}
setwd(script.dir)

# Load genome catalog
catalog_path <- "../../../data/genomes/genome_catalog.csv"
if (!file.exists(catalog_path)) {
  stop("Genome catalog not found at: ", catalog_path)
}

cat("Reading genome catalog...\n")
catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)

# Data preprocessing and validation
cat("Processing catalog data...\n")

# Convert numeric columns
catalog$genome_size_mb <- as.numeric(catalog$genome_size_mb)
catalog$scaffold_N50 <- as.numeric(catalog$scaffold_N50)
catalog$contig_N50 <- as.numeric(catalog$contig_N50)
catalog$number_of_scaffolds <- as.numeric(catalog$number_of_scaffolds)
catalog$gc_percent <- as.numeric(catalog$gc_percent)

# Handle missing values
catalog$genome_size_mb[is.na(catalog$genome_size_mb)] <- 0
catalog$scaffold_N50[is.na(catalog$scaffold_N50) | catalog$scaffold_N50 <= 0] <- 1
catalog$contig_N50[is.na(catalog$contig_N50) | catalog$contig_N50 <= 0] <- 1
catalog$gc_percent[is.na(catalog$gc_percent)] <- 0

# Summary statistics
n_assemblies <- nrow(catalog)
n_species <- length(unique(catalog$species_name))
date_generated <- format(Sys.Date(), "%B %d, %Y")

cat("Dataset summary:\n")
cat("  Assemblies:", n_assemblies, "\n")
cat("  Species:", n_species, "\n")

# Create output PDF
output_pdf <- "qc_report.pdf"
cat("Creating PDF report:", output_pdf, "\n")

# PDF dimensions and setup
pdf(output_pdf, width = 11, height = 8.5, pointsize = 10)

################################################################################
# PAGE 1: TITLE PAGE
################################################################################
cat("Creating title page...\n")
par(mar = c(0, 0, 0, 0), xaxs = "i", yaxs = "i")
plot(0, 0, xlim = c(0, 1), ylim = c(0, 1), type = "n", axes = FALSE, xlab = "", ylab = "")

# Background color
rect(0, 0, 1, 1, col = "#f5f5f5", border = NA)

# Title
text(0.5, 0.75, "SCARAB",
     cex = 3.5, font = 2, adj = 0.5)
text(0.5, 0.65, "Genome Inventory QC Report",
     cex = 3, font = 1, adj = 0.5)

# Divider line
segments(0.15, 0.60, 0.85, 0.60, lwd = 2, col = "#2c3e50")

# Key statistics
text(0.5, 0.45, paste("Report Generated:", date_generated),
     cex = 1.2, adj = 0.5)
text(0.5, 0.38, paste("Total Assemblies:", n_assemblies),
     cex = 1.3, font = 2, adj = 0.5)
text(0.5, 0.31, paste("Unique Species:", n_species),
     cex = 1.3, font = 2, adj = 0.5)

# Footer
text(0.5, 0.08, "This report provides quality control assessment of genome assemblies",
     cex = 1, adj = 0.5, col = "#555555")
text(0.5, 0.02, "in the SCARAB project",
     cex = 1, adj = 0.5, col = "#555555")

################################################################################
# PAGE 2: ASSEMBLY LEVEL OVERVIEW
################################################################################
cat("Creating assembly level overview...\n")

# Create layout for two plots
layout(matrix(c(1, 2), nrow = 1, ncol = 2), widths = c(1, 1))

# Left plot: Overall assembly level distribution
assembly_counts <- table(catalog$assembly_level)
assembly_counts <- assembly_counts[c("Chromosome", "Scaffold", "Contig")]
assembly_counts <- assembly_counts[!is.na(assembly_counts)]

par(mar = c(4, 5, 3, 2))
colors_assembly <- c("Chromosome" = "#2ecc71", "Scaffold" = "#3498db", "Contig" = "#e74c3c")
barplot(assembly_counts,
        col = colors_assembly[names(assembly_counts)],
        main = "Assemblies by Level\n(All Genomes)",
        ylab = "Count", xlab = "",
        cex.names = 0.9, cex.main = 1.2, cex.axis = 0.9, cex.lab = 1)
box(lwd = 1)

# Right plot: Assembly level by role
assembly_by_role <- table(catalog$assembly_level, catalog$role)
assembly_by_role <- assembly_by_role[c("Chromosome", "Scaffold", "Contig"), , drop = FALSE]
assembly_by_role <- assembly_by_role[apply(assembly_by_role, 1, sum) > 0, , drop = FALSE]

par(mar = c(4, 5, 3, 2))
barplot(assembly_by_role,
        col = c("Chromosome" = "#2ecc71", "Scaffold" = "#3498db", "Contig" = "#e74c3c")[rownames(assembly_by_role)],
        main = "Assembly Level by Role\n(Ingroup vs Outgroup)",
        ylab = "Count", xlab = "",
        legend.text = rownames(assembly_by_role),
        args.legend = list(x = "topright", cex = 0.9),
        beside = TRUE, cex.names = 0.9, cex.main = 1.2, cex.axis = 0.9, cex.lab = 1)
box(lwd = 1)

layout(1)  # Reset layout

################################################################################
# PAGE 3: FAMILY COVERAGE
################################################################################
cat("Creating family coverage analysis...\n")

par(mar = c(4, 12, 3, 2))

# Get top 30 families by count
family_counts <- sort(table(catalog$family), decreasing = TRUE)
family_counts <- family_counts[1:min(30, length(family_counts))]

# Get suborder information for each family
family_colors <- sapply(names(family_counts), function(f) {
  suborders <- unique(catalog$suborder[catalog$family == f])
  suborders <- suborders[suborders != ""]
  if ("Polyphaga" %in% suborders) {
    "#3498db"  # Blue
  } else if ("Adephaga" %in% suborders) {
    "#e74c3c"  # Red
  } else if ("Archostemata" %in% suborders) {
    "#f39c12"  # Orange
  } else {
    "#95a5a6"  # Gray
  }
})

# Horizontal barplot
barplot(rev(family_counts),
        horiz = TRUE,
        col = rev(family_colors),
        main = "Top 30 Families by Assembly Count",
        xlab = "Number of Assemblies",
        cex.names = 0.75, cex.main = 1.2, cex.axis = 0.95, cex.lab = 1,
        las = 1)
box(lwd = 1)

# Add legend for suborders
legend("bottomright",
       legend = c("Polyphaga", "Adephaga", "Archostemata"),
       fill = c("#3498db", "#e74c3c", "#f39c12"),
       cex = 0.9, bty = "o", bg = "white")

################################################################################
# PAGE 4: QUALITY METRICS
################################################################################
cat("Creating quality metrics page...\n")

layout(matrix(c(1, 2, 3, 3), nrow = 2, ncol = 2, byrow = TRUE))

# Plot 1: Histogram of scaffold N50 (log10 scale)
par(mar = c(4, 4, 3, 2))
scaffold_n50_valid <- catalog$scaffold_N50[catalog$scaffold_N50 > 0]
hist(log10(scaffold_n50_valid),
     main = "Distribution of Scaffold N50\n(log10 scale)",
     xlab = "log10(Scaffold N50 bp)",
     ylab = "Frequency",
     col = "#3498db",
     border = "white",
     breaks = 20,
     cex.main = 1.1, cex.axis = 0.9, cex.lab = 1)
box(lwd = 1)
grid(nx = NA, ny = NULL, col = "#cccccc", lty = "dotted")

# Plot 2: Histogram of genome size
par(mar = c(4, 4, 3, 2))
genome_size_valid <- catalog$genome_size_mb[catalog$genome_size_mb > 0]
hist(genome_size_valid,
     main = "Distribution of Genome Size",
     xlab = "Genome Size (Mb)",
     ylab = "Frequency",
     col = "#2ecc71",
     border = "white",
     breaks = 25,
     cex.main = 1.1, cex.axis = 0.9, cex.lab = 1)
box(lwd = 1)
grid(nx = NA, ny = NULL, col = "#cccccc", lty = "dotted")

# Plot 3: Scatter plot (larger, spans both columns)
par(mar = c(4, 4, 3, 2))
plot(catalog$genome_size_mb, catalog$scaffold_N50,
     log = "xy",
     main = "Genome Size vs Scaffold N50\n(log-log scale, colored by assembly level)",
     xlab = "Genome Size (Mb, log scale)",
     ylab = "Scaffold N50 (bp, log scale)",
     col = NA,
     type = "n",
     cex.main = 1.1, cex.axis = 0.9, cex.lab = 1,
     xlim = c(100, 5000), ylim = c(1e4, 3e8))

# Add points colored by assembly level
colors_scatter <- c("Chromosome" = "#2ecc71", "Scaffold" = "#3498db", "Contig" = "#e74c3c")
for (level in c("Contig", "Scaffold", "Chromosome")) {
  idx <- catalog$assembly_level == level
  points(catalog$genome_size_mb[idx], catalog$scaffold_N50[idx],
         col = colors_scatter[level], pch = 19, cex = 1.2, alpha = 0.6)
}

box(lwd = 1)
grid(nx = NULL, ny = NULL, col = "#cccccc", lty = "dotted")
legend("topleft",
       legend = c("Chromosome", "Scaffold", "Contig"),
       col = c("#2ecc71", "#3498db", "#e74c3c"),
       pch = 19, cex = 0.95, bty = "o", bg = "white")

layout(1)  # Reset layout

################################################################################
# PAGE 5: QUALITY HEURISTIC BREAKDOWN
################################################################################
cat("Creating quality heuristic breakdown...\n")

layout(matrix(c(1, 2), nrow = 1, ncol = 2), widths = c(1.5, 1))

# Left plot: include_recommended by family (top 20)
par(mar = c(4, 12, 3, 2))

top_families <- names(sort(table(catalog$family), decreasing = TRUE))[1:20]
quality_by_family <- table(catalog$family[catalog$family %in% top_families],
                           catalog$include_recommended[catalog$family %in% top_families])

# Ensure all categories exist
for (cat in c("yes", "conditional", "no")) {
  if (!(cat %in% colnames(quality_by_family))) {
    quality_by_family <- cbind(quality_by_family, "0" = 0)
    colnames(quality_by_family)[ncol(quality_by_family)] <- cat
  }
}
quality_by_family <- quality_by_family[, c("yes", "conditional", "no"), drop = FALSE]
quality_by_family[is.na(quality_by_family)] <- 0

barplot(t(quality_by_family),
        horiz = FALSE,
        col = c("yes" = "#2ecc71", "conditional" = "#f39c12", "no" = "#e74c3c"),
        main = "Recommendation Status\n(Top 20 Families)",
        ylab = "Count",
        xlab = "",
        legend.text = c("Recommended (yes)", "Conditional", "Not Recommended (no)"),
        args.legend = list(x = "topright", cex = 0.85),
        beside = TRUE, cex.names = 0.7, cex.main = 1.1, cex.axis = 0.9, cex.lab = 1,
        las = 2)
box(lwd = 1)

# Right plot: Overall quality pie chart
par(mar = c(2, 2, 3, 2))

quality_overall <- table(catalog$include_recommended)
quality_overall <- quality_overall[c("yes", "conditional", "no")]
quality_overall <- quality_overall[!is.na(quality_overall)]

colors_pie <- c("yes" = "#2ecc71", "conditional" = "#f39c12", "no" = "#e74c3c")
pie(quality_overall,
    labels = paste(names(quality_overall), "\n(n =", quality_overall, ")"),
    main = "Overall Quality Distribution",
    col = colors_pie[names(quality_overall)],
    cex = 1.05, cex.main = 1.1)

layout(1)  # Reset layout

################################################################################
# PAGE 6: RESTRICTION STATUS
################################################################################
cat("Creating restriction status analysis...\n")

layout(matrix(c(1, 2), nrow = 2, ncol = 1), heights = c(1, 1.2))

# Top: Bar chart of restriction status
par(mar = c(4, 4, 3, 2))

restriction_counts <- table(catalog$restriction_status)
restriction_counts <- sort(restriction_counts, decreasing = TRUE)

colors_restriction <- c("published_open" = "#2ecc71",
                        "published_restricted" = "#f39c12",
                        "embargo" = "#e74c3c",
                        "restricted" = "#c0392b")
colors_use <- colors_restriction[names(restriction_counts)]
colors_use[is.na(colors_use)] <- "#95a5a6"

barplot(restriction_counts,
        col = colors_use,
        main = "Restriction Status of Assemblies",
        ylab = "Count",
        xlab = "",
        cex.names = 0.9, cex.main = 1.2, cex.axis = 0.95, cex.lab = 1,
        las = 2)
box(lwd = 1)
grid(nx = NA, ny = NULL, col = "#cccccc", lty = "dotted")

# Bottom: Table of restricted/embargo genomes
par(mar = c(1, 1, 2, 1))

restricted_genomes <- catalog[catalog$restriction_status %in% c("embargo", "restricted", "published_restricted"),
                              c("species_name", "family", "assembly_level", "restriction_status", "restriction_notes")]

if (nrow(restricted_genomes) > 0) {
  plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "",
       xlim = c(0, 1), ylim = c(0, 1))

  table_text <- paste("Flagged Genomes (", nrow(restricted_genomes), " total):", sep = "")
  text(0.05, 0.95, table_text, adj = 0, cex = 1, font = 2)

  # Create formatted table output
  y_pos <- 0.85
  for (i in 1:min(15, nrow(restricted_genomes))) {
    row <- restricted_genomes[i, ]
    line <- sprintf("%s | %s | %s | %s",
                    substr(row$species_name, 1, 25),
                    substr(row$family, 1, 20),
                    row$restriction_status,
                    substr(row$restriction_notes, 1, 30))
    text(0.05, y_pos, line, adj = 0, cex = 0.75, family = "mono")
    y_pos <- y_pos - 0.06
  }

  if (nrow(restricted_genomes) > 15) {
    text(0.05, y_pos, sprintf("... and %d more", nrow(restricted_genomes) - 15),
         adj = 0, cex = 0.75, font = 3)
  }
} else {
  plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "",
       xlim = c(0, 1), ylim = c(0, 1))
  text(0.5, 0.5, "No restricted or embargoed genomes",
       adj = 0.5, cex = 1.3, col = "#2ecc71", font = 2)
}

layout(1)  # Reset layout

################################################################################
# PAGE 7: MULTI-ASSEMBLY SPECIES
################################################################################
cat("Creating multi-assembly species analysis...\n")

par(mar = c(2, 2, 3, 2))

# Find species with multiple assemblies
species_counts <- table(catalog$species_name)
multi_assembly_species <- names(species_counts[species_counts > 2])

plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "",
     xlim = c(0, 1), ylim = c(0, 1))

title_text <- sprintf("Species with >2 Assemblies (%d species)", length(multi_assembly_species))
text(0.5, 0.98, title_text, adj = 0.5, cex = 1.3, font = 2)

if (length(multi_assembly_species) > 0) {
  # Create a summary table
  y_pos <- 0.92

  # Header
  header_line <- sprintf("%-35s %5s %20s", "Species", "Count", "Best Assembly Level")
  text(0.05, y_pos, header_line, adj = 0, cex = 0.8, font = 2, family = "mono")
  y_pos <- y_pos - 0.04

  # Separator
  segments(0.05, y_pos, 0.95, y_pos, lwd = 1, col = "#cccccc")
  y_pos <- y_pos - 0.04

  for (species in sort(multi_assembly_species)) {
    species_data <- catalog[catalog$species_name == species, ]
    count <- nrow(species_data)

    # Determine best assembly level
    best_level <- if ("Chromosome" %in% species_data$assembly_level) {
      "Chromosome"
    } else if ("Scaffold" %in% species_data$assembly_level) {
      "Scaffold"
    } else {
      "Contig"
    }

    line <- sprintf("%-35s %5d %20s", substr(species, 1, 35), count, best_level)
    text(0.05, y_pos, line, adj = 0, cex = 0.8, family = "mono")
    y_pos <- y_pos - 0.04

    if (y_pos < 0.05) break
  }

  if (length(multi_assembly_species) > 18) {
    text(0.05, y_pos, sprintf("... and %d more species", length(multi_assembly_species) - 18),
         adj = 0, cex = 0.8, font = 3, family = "mono")
  }

  # Recommendations section
  y_pos <- 0.15
  text(0.05, y_pos, "Recommendations:", adj = 0, cex = 1, font = 2)
  y_pos <- y_pos - 0.05

  recommendations <- c(
    "- Consider genome assembly dedupe for ingroup species with identical or near-identical sequences",
    "- Prioritize Chromosome-level assemblies for downstream analysis",
    "- Document rationale for including multiple versions of same species"
  )

  for (rec in recommendations) {
    text(0.05, y_pos, rec, adj = 0, cex = 0.8)
    y_pos <- y_pos - 0.04
  }
} else {
  text(0.5, 0.5, "All species have ≤2 assemblies", adj = 0.5, cex = 1.2, col = "#2ecc71")
}

################################################################################
# PAGE 8: OUTGROUP SUMMARY
################################################################################
cat("Creating outgroup summary page...\n")

par(mar = c(2, 2, 3, 2))

# Filter for outgroup genomes (Neuropterida)
outgroup <- catalog[catalog$role == "outgroup", ]

plot(0, 0, type = "n", axes = FALSE, xlab = "", ylab = "",
     xlim = c(0, 1), ylim = c(0, 1))

text(0.5, 0.98, sprintf("Outgroup Summary - Neuropterida (%d assemblies)", nrow(outgroup)),
     adj = 0.5, cex = 1.3, font = 2)

if (nrow(outgroup) > 0) {
  y_pos <- 0.92

  # Summary statistics
  summary_stats <- c(
    sprintf("Total outgroup assemblies: %d", nrow(outgroup)),
    sprintf("Unique outgroup species: %d", length(unique(outgroup$species_name))),
    sprintf("Unique outgroup families: %d", length(unique(outgroup$family))),
    sprintf("Chromosome-level: %d", sum(outgroup$assembly_level == "Chromosome")),
    sprintf("Scaffold-level: %d", sum(outgroup$assembly_level == "Scaffold")),
    sprintf("Contig-level: %d", sum(outgroup$assembly_level == "Contig"))
  )

  for (stat in summary_stats) {
    text(0.05, y_pos, stat, adj = 0, cex = 0.95, family = "mono")
    y_pos <- y_pos - 0.05
  }

  # Table of outgroup genomes
  y_pos <- y_pos - 0.03
  text(0.05, y_pos, "Outgroup Assemblies:", adj = 0, cex = 1, font = 2)
  y_pos <- y_pos - 0.04

  # Header
  header <- sprintf("%-30s %-20s %15s %15s", "Species", "Family", "Assembly Level", "Scaffold N50")
  text(0.05, y_pos, header, adj = 0, cex = 0.75, font = 2, family = "mono")
  y_pos <- y_pos - 0.03

  # Separator
  segments(0.05, y_pos, 0.95, y_pos, lwd = 1, col = "#cccccc")
  y_pos <- y_pos - 0.03

  # Sort outgroup by family then species
  outgroup_sorted <- outgroup[order(outgroup$family, outgroup$species_name), ]

  for (i in 1:min(25, nrow(outgroup_sorted))) {
    row <- outgroup_sorted[i, ]
    n50_str <- if (row$scaffold_N50 > 0) {
      sprintf("%.2e", row$scaffold_N50)
    } else {
      "NA"
    }

    line <- sprintf("%-30s %-20s %15s %15s",
                    substr(row$species_name, 1, 30),
                    substr(row$family, 1, 20),
                    row$assembly_level,
                    n50_str)
    text(0.05, y_pos, line, adj = 0, cex = 0.7, family = "mono")
    y_pos <- y_pos - 0.03
  }

  if (nrow(outgroup_sorted) > 25) {
    text(0.05, y_pos, sprintf("... and %d more outgroup genomes", nrow(outgroup_sorted) - 25),
         adj = 0, cex = 0.75, font = 3, family = "mono")
    y_pos <- y_pos - 0.03
  }

  # Assessment
  y_pos <- y_pos - 0.03
  text(0.05, y_pos, "Assessment:", adj = 0, cex = 1, font = 2)
  y_pos <- y_pos - 0.04

  chrom_pct <- round(100 * sum(outgroup$assembly_level == "Chromosome") / nrow(outgroup), 1)
  assessment <- if (chrom_pct >= 50) {
    "Excellent outgroup coverage with majority Chromosome-level assemblies"
  } else if (chrom_pct >= 30) {
    "Good outgroup coverage with mixed assembly quality levels"
  } else {
    "Outgroup coverage adequate but could benefit from higher-quality assemblies"
  }

  text(0.05, y_pos, assessment, adj = 0, cex = 0.9, style = "italic")

} else {
  text(0.5, 0.5, "No outgroup genomes present in catalog",
       adj = 0.5, cex = 1.2, col = "#e74c3c")
}

# Close PDF
dev.off()
cat("PDF report saved to:", output_pdf, "\n")

################################################################################
# GENERATE TEXT SUMMARY
################################################################################
cat("Generating text summary...\n")

summary_file <- "qc_summary.txt"
sink(summary_file)

cat("================================================================================\n")
cat("SCARAB - GENOME INVENTORY QC SUMMARY\n")
cat("================================================================================\n")
cat("Report Generated:", date_generated, "\n")
cat("================================================================================\n\n")

# Dataset Overview
cat("DATASET OVERVIEW\n")
cat("-" %*% 80, "\n", sep = "")
cat(sprintf("Total Assemblies:                %d\n", n_assemblies))
cat(sprintf("Unique Species:                  %d\n", n_species))
cat(sprintf("Unique Families:                 %d\n", length(unique(catalog$family))))
cat(sprintf("Unique Superfamilies:            %d\n", length(unique(catalog$superfamily))))
cat("\n")

# Role breakdown
cat("Role Distribution:\n")
role_counts <- table(catalog$role)
for (role in names(role_counts)) {
  cat(sprintf("  %-20s %4d assemblies (%5.1f%%)\n",
              role, role_counts[role], 100 * role_counts[role] / n_assemblies))
}
cat("\n")

# Assembly level distribution
cat("Assembly Level Distribution:\n")
assembly_level_counts <- table(catalog$assembly_level)
assembly_order <- c("Chromosome", "Scaffold", "Contig")
for (level in assembly_order) {
  if (level %in% names(assembly_level_counts)) {
    count <- assembly_level_counts[level]
    pct <- 100 * count / n_assemblies
    cat(sprintf("  %-20s %4d assemblies (%5.1f%%)\n", level, count, pct))
  }
}
cat("\n")

# Quality metrics
cat("QUALITY METRICS\n")
cat("-" %*% 80, "\n", sep = "")

genome_sizes <- catalog$genome_size_mb[catalog$genome_size_mb > 0]
if (length(genome_sizes) > 0) {
  cat("Genome Size (Mb):\n")
  cat(sprintf("  Mean:                         %.2f\n", mean(genome_sizes)))
  cat(sprintf("  Median:                       %.2f\n", median(genome_sizes)))
  cat(sprintf("  Range:                        %.2f - %.2f\n", min(genome_sizes), max(genome_sizes)))
  cat("\n")
}

scaffold_n50s <- catalog$scaffold_N50[catalog$scaffold_N50 > 0]
if (length(scaffold_n50s) > 0) {
  cat("Scaffold N50 (bp):\n")
  cat(sprintf("  Mean:                         %.2e\n", mean(scaffold_n50s)))
  cat(sprintf("  Median:                       %.2e\n", median(scaffold_n50s)))
  cat(sprintf("  Range:                        %.2e - %.2e\n", min(scaffold_n50s), max(scaffold_n50s)))
  cat("\n")
}

# Recommendation breakdown
cat("QUALITY RECOMMENDATIONS\n")
cat("-" %*% 80, "\n", sep = "")

quality_dist <- table(catalog$include_recommended)
for (status in c("yes", "conditional", "no")) {
  if (status %in% names(quality_dist)) {
    count <- quality_dist[status]
    pct <- 100 * count / n_assemblies
    status_label <- switch(status,
                           "yes" = "Recommended",
                           "conditional" = "Conditionally Recommended",
                           "no" = "Not Recommended")
    cat(sprintf("%-30s %4d assemblies (%5.1f%%)\n", status_label, count, pct))
  }
}
cat("\n")

# Restriction status
cat("RESTRICTION STATUS\n")
cat("-" %*% 80, "\n", sep = "")

restriction_dist <- table(catalog$restriction_status)
for (status in sort(names(restriction_dist), decreasing = TRUE)) {
  count <- restriction_dist[status]
  pct <- 100 * count / n_assemblies
  cat(sprintf("%-30s %4d assemblies (%5.1f%%)\n", status, count, pct))
}
cat("\n")

# Top families
cat("TOP 20 FAMILIES BY ASSEMBLY COUNT\n")
cat("-" %*% 80, "\n", sep = "")

top_fams <- sort(table(catalog$family), decreasing = TRUE)[1:20]
for (i in seq_along(top_fams)) {
  family <- names(top_fams)[i]
  count <- top_fams[i]
  cat(sprintf("%2d. %-35s %3d assemblies\n", i, family, count))
}
cat("\n")

# Multi-assembly species
cat("MULTI-ASSEMBLY SPECIES (>2 assemblies)\n")
cat("-" %*% 80, "\n", sep = "")

species_counts_multi <- species_counts[species_counts > 2]
if (length(species_counts_multi) > 0) {
  cat(sprintf("Total species with >2 assemblies: %d\n\n", length(species_counts_multi)))

  species_multi_sorted <- sort(species_counts_multi, decreasing = TRUE)
  for (i in seq_along(species_multi_sorted)) {
    species <- names(species_multi_sorted)[i]
    count <- species_multi_sorted[i]

    species_data <- catalog[catalog$species_name == species, ]
    best_level <- if ("Chromosome" %in% species_data$assembly_level) {
      "Chromosome"
    } else if ("Scaffold" %in% species_data$assembly_level) {
      "Scaffold"
    } else {
      "Contig"
    }

    cat(sprintf("%2d. %-40s %d assemblies (best: %s)\n", i, species, count, best_level))
  }

  cat("\nRECOMMENDATIONS:\n")
  cat("- Consider genome assembly deduplication for species with identical sequences\n")
  cat("- Prioritize Chromosome-level assemblies for phylogenetic analyses\n")
  cat("- Document selection rationale in project metadata\n")
} else {
  cat("All species have ≤2 assemblies - no conflict resolution needed\n")
}
cat("\n")

# Outgroup summary
cat("OUTGROUP SUMMARY (Neuropterida)\n")
cat("-" %*% 80, "\n", sep = "")

outgroup_summary <- catalog[catalog$role == "outgroup", ]
if (nrow(outgroup_summary) > 0) {
  cat(sprintf("Total outgroup assemblies:        %d\n", nrow(outgroup_summary)))
  cat(sprintf("Unique outgroup species:          %d\n", length(unique(outgroup_summary$species_name))))
  cat(sprintf("Unique outgroup families:         %d\n", length(unique(outgroup_summary$family))))
  cat("\n")

  outgroup_level <- table(outgroup_summary$assembly_level)
  cat("Outgroup by assembly level:\n")
  for (level in c("Chromosome", "Scaffold", "Contig")) {
    if (level %in% names(outgroup_level)) {
      count <- outgroup_level[level]
      pct <- 100 * count / nrow(outgroup_summary)
      cat(sprintf("  %-20s %3d (%5.1f%%)\n", level, count, pct))
    }
  }
  cat("\n")

  # Suborder breakdown
  cat("Outgroup by suborder:\n")
  outgroup_suborder <- table(outgroup_summary$suborder[outgroup_summary$suborder != ""])
  for (suborder in sort(names(outgroup_suborder), decreasing = TRUE)) {
    count <- outgroup_suborder[suborder]
    cat(sprintf("  %-30s %3d assemblies\n", suborder, count))
  }
  cat("\n")

  chrom_pct <- round(100 * sum(outgroup_summary$assembly_level == "Chromosome") / nrow(outgroup_summary), 1)

  cat("OUTGROUP ASSESSMENT:\n")
  if (chrom_pct >= 50) {
    cat("EXCELLENT - Majority of outgroup genomes are Chromosome-level assemblies\n")
  } else if (chrom_pct >= 30) {
    cat("GOOD - Mixed assembly quality with adequate coverage\n")
  } else {
    cat("ADEQUATE - Would benefit from higher-quality assemblies\n")
  }
  cat(sprintf("Chromosome-level genomes: %5.1f%%\n", chrom_pct))
} else {
  cat("No outgroup genomes present\n")
}
cat("\n")

# Data availability
cat("DATA AVAILABILITY\n")
cat("-" %*% 80, "\n", sep = "")

has_annotation <- sum(catalog$gene_annotation_available == "yes", na.rm = TRUE)
cat(sprintf("Genomes with gene annotation:    %d (%5.1f%%)\n",
            has_annotation, 100 * has_annotation / n_assemblies))

has_publication <- sum(catalog$publication_year > 0, na.rm = TRUE)
cat(sprintf("Genomes with publication DOI:    %d (%5.1f%%)\n",
            has_publication, 100 * has_publication / n_assemblies))

cat("\n")
cat("================================================================================\n")
cat("End of Report\n")
cat("================================================================================\n")

sink()

cat("Text summary saved to:", summary_file, "\n")
cat("\n=== QC REPORT GENERATION COMPLETE ===\n")
cat("Output files:\n")
cat("  -", output_pdf, "\n")
cat("  -", summary_file, "\n")
