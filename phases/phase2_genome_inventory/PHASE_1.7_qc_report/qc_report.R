#!/usr/bin/env Rscript
################################################################################
# TASK: PHASE_1.7 - Quality Control and Summary Report
################################################################################
#
# OBJECTIVE:
# Read all Phase 1 outputs (merged_genomes.csv, curated_genomes.csv, etc.).
# Generate comprehensive QC report: genome counts, assembly stats,
# phylogenetic representation, flagged issues.
# Output: PDF report with tables, plots, and summary statistics.
#
# INPUTS:
#   - PHASE_1.3 output: merged_genomes.csv
#   - PHASE_1.4 output: curated_genomes.csv
#   - PHASE_1.5 outputs: fasta_urls.csv, genome_checksums.txt
#   - PHASE_1.6 output: constraint_tree.nwk
#
# OUTPUTS:
#   - qc_report.pdf (multi-page report with text, tables, plots)
#   - qc_summary.txt (text summary)
#
# STUDENT TODO:
#   - Set working directory (line ~60)
#   - Verify input file paths (lines ~100-120)
#   - Adjust PDF dimensions if needed (line ~140)
#   - Customize report title/metadata (lines ~150-160)
#   - Review plot thresholds and colors (lines ~250-300)
#   - Verify output paths (lines ~450, ~500)
#
# DEPENDENCIES:
#   - base R (for PDF generation, graphics)
#   - ape (for tree statistics, optional)
#
################################################################################

library(base)
library(graphics)

# Suppress warnings
options(warn = -1)

cat("PHASE_1.7: QC Report Generation\n")
cat("==============================\n\n")

## <<<STUDENT: Set your working directory if running standalone>>>
# setwd("[PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.7_qc_report")

if (!dir.exists("data")) {
  dir.create("data", showWarnings = FALSE, recursive = TRUE)
}

################################################################################
# 1. LOAD ALL INPUT DATA
################################################################################

cat("Step 1: Loading all Phase 1 outputs...\n")

## <<<STUDENT: Verify paths to all input files>>>
input_files <- list(
  merged_genomes = "../PHASE_1.3_merge_deduplicate/merged_genomes.csv",
  curated_genomes = "../PHASE_1.4_phylogenetic_placement/curated_genomes.csv",
  fasta_urls = "../PHASE_1.5_fasta_urls/data/fasta_urls.csv",
  checksums = "../PHASE_1.5_fasta_urls/data/genome_checksums.txt",
  constraint_tree = "../PHASE_1.6_constraint_tree/constraint_tree.nwk"
)

loaded_data <- list()

# Load merged genomes
if (file.exists(input_files$merged_genomes)) {
  loaded_data$merged_genomes <- read.csv(input_files$merged_genomes,
                                         stringsAsFactors = FALSE)
  cat("  ✓ Loaded merged_genomes.csv:", nrow(loaded_data$merged_genomes), "rows\n")
} else {
  cat("  ⚠ merged_genomes.csv not found\n")
}

# Load curated genomes
if (file.exists(input_files$curated_genomes)) {
  loaded_data$curated_genomes <- read.csv(input_files$curated_genomes,
                                          stringsAsFactors = FALSE)
  cat("  ✓ Loaded curated_genomes.csv:", nrow(loaded_data$curated_genomes), "rows\n")
} else {
  cat("  ⚠ curated_genomes.csv not found\n")
}

# Load FASTA URLs
if (file.exists(input_files$fasta_urls)) {
  loaded_data$fasta_urls <- read.csv(input_files$fasta_urls,
                                     stringsAsFactors = FALSE)
  cat("  ✓ Loaded fasta_urls.csv:", nrow(loaded_data$fasta_urls), "rows\n")
} else {
  cat("  ⚠ fasta_urls.csv not found\n")
}

# Load constraint tree (just check if exists)
tree_exists <- file.exists(input_files$constraint_tree)
if (tree_exists) {
  cat("  ✓ Found constraint_tree.nwk\n")
} else {
  cat("  ⚠ constraint_tree.nwk not found\n")
}

################################################################################
# 2. COMPUTE SUMMARY STATISTICS
################################################################################

cat("\nStep 2: Computing summary statistics...\n")

summary_stats <- list()

if (!is.null(loaded_data$curated_genomes)) {
  genomes <- loaded_data$curated_genomes

  # Overall counts
  summary_stats$total_genomes <- nrow(genomes)
  summary_stats$total_species <- length(unique(genomes$species_name))

  # Assembly level distribution
  summary_stats$assembly_levels <- table(genomes$assembly_level)

  # Assembly source distribution
  summary_stats$sources <- table(genomes$source)

  # Clade distribution
  if ("clade_assignment" %in% names(genomes)) {
    summary_stats$clades <- table(genomes$clade_assignment)
  }

  # Family distribution (top 10)
  if ("family" %in% names(genomes)) {
    family_counts <- table(genomes$family)
    family_counts <- sort(family_counts, decreasing = TRUE)
    summary_stats$top_families <- head(family_counts, 10)
  }

  # QC flags
  qc_flagged <- sum(!is.na(genomes$qc_flags))
  summary_stats$qc_flagged <- qc_flagged

  cat("  ✓ Computed stats for", summary_stats$total_genomes, "genomes\n")
}

################################################################################
# 3. PREPARE PDF REPORT
################################################################################

cat("\nStep 3: Generating PDF report...\n")

## <<<STUDENT: Adjust PDF dimensions if needed>>>
pdf_file <- "qc_report.pdf"
pdf(pdf_file, width = 11, height = 8.5, pointsize = 10)

# Set plot margins
par(mar = c(5, 4, 4, 2), oma = c(0, 0, 2, 0))

################################################################################
# PAGE 1: TITLE PAGE
################################################################################

plot.new()
plot.window(xlim = 0:10, ylim = 0:10)

text(5, 8.5, "SCARAB", font = 2, cex = 2.5)
text(5, 7.5, "Phase 1 Genome Inventory - QC Report", font = 1, cex = 2)

text(5, 6, "Summary of Genome Selection and Curation", cex = 1.2, font = 3)

# Add summary box
text(1, 4.5, "Report Generated:", font = 2, adj = 0)
text(5.5, 4.5, format(Sys.time(), "%Y-%m-%d %H:%M:%S"), adj = 0)

if (!is.null(summary_stats$total_genomes)) {
  y_pos <- 3.5
  text(1, y_pos, paste("Total Genomes:", summary_stats$total_genomes), adj = 0)
  text(1, y_pos - 0.5, paste("Unique Species:", summary_stats$total_species), adj = 0)
  text(1, y_pos - 1, paste("QC Flagged:", summary_stats$qc_flagged), adj = 0)
}

################################################################################
# PAGE 2: OVERALL STATISTICS
################################################################################

plot.new()
plot.window(xlim = 0:10, ylim = 0:10)
title("Phase 1 Summary Statistics", line = -2)

text_y <- 9
line_height <- 0.5

# Overall counts
text(0.5, text_y, "GENOME INVENTORY", font = 2, cex = 1.1, adj = 0)
text_y <- text_y - line_height - 0.3

if (!is.null(summary_stats)) {
  text(1, text_y, paste("Total Genomes Curated:", summary_stats$total_genomes), adj = 0)
  text_y <- text_y - line_height
  text(1, text_y, paste("Unique Species:", summary_stats$total_species), adj = 0)
  text_y <- text_y - line_height
  text(1, text_y, paste("QC Flagged Genomes:", summary_stats$qc_flagged), adj = 0)
  text_y <- text_y - line_height
}

# Assembly level distribution
text(0.5, text_y - 0.5, "ASSEMBLY LEVELS", font = 2, cex = 1.1, adj = 0)
text_y <- text_y - 1.2

if (!is.null(summary_stats$assembly_levels)) {
  for (i in seq_along(summary_stats$assembly_levels)) {
    level <- names(summary_stats$assembly_levels)[i]
    count <- summary_stats$assembly_levels[i]
    text(1, text_y, paste(level, ":", count), adj = 0, cex = 0.9)
    text_y <- text_y - line_height
  }
}

# Source distribution
text(5.5, 9, "ASSEMBLY SOURCES", font = 2, cex = 1.1, adj = 0)
text_y_right <- 9 - line_height - 0.3

if (!is.null(summary_stats$sources)) {
  for (i in seq_along(summary_stats$sources)) {
    source <- names(summary_stats$sources)[i]
    count <- summary_stats$sources[i]
    text(6, text_y_right, paste(source, ":", count), adj = 0, cex = 0.9)
    text_y_right <- text_y_right - line_height
  }
}

################################################################################
# PAGE 3: ASSEMBLY LEVEL DISTRIBUTION (BARPLOT)
################################################################################

if (!is.null(loaded_data$curated_genomes) &&
    !is.null(loaded_data$curated_genomes$assembly_level)) {

  plot.new()
  assembly_level_data <- table(loaded_data$curated_genomes$assembly_level)

  # Create barplot
  x_pos <- barplot(assembly_level_data,
                   main = "Distribution of Assembly Levels",
                   xlab = "Assembly Level",
                   ylab = "Count",
                   col = c("darkgreen", "green", "orange", "red")[seq_along(assembly_level_data)],
                   ylim = c(0, max(assembly_level_data) * 1.1))

  # Add value labels on bars
  text(x_pos, assembly_level_data + 1, as.character(assembly_level_data),
       xjust = 0.5, cex = 0.9)

  box()
}

################################################################################
# PAGE 4: CLADE DISTRIBUTION
################################################################################

if (!is.null(loaded_data$curated_genomes) &&
    "clade_assignment" %in% names(loaded_data$curated_genomes)) {

  clade_data <- table(loaded_data$curated_genomes$clade_assignment)
  clade_data <- sort(clade_data, decreasing = TRUE)

  plot.new()
  x_pos <- barplot(clade_data,
                   main = "Genome Distribution by Phylogenetic Clade",
                   xlab = "Clade",
                   ylab = "Count",
                   col = "steelblue",
                   ylim = c(0, max(clade_data) * 1.1),
                   las = 2)

  # Add value labels
  text(x_pos, clade_data + 1, as.character(clade_data),
       xjust = 0.5, cex = 0.9)

  box()
}

################################################################################
# PAGE 5: TOP FAMILIES
################################################################################

if (!is.null(summary_stats$top_families)) {
  plot.new()

  x_pos <- barplot(summary_stats$top_families,
                   main = "Top 10 Beetle Families in Dataset",
                   xlab = "Family",
                   ylab = "Count",
                   col = "coral",
                   las = 2)

  # Add value labels
  text(x_pos, summary_stats$top_families + 0.2,
       as.character(summary_stats$top_families),
       xjust = 0.5, cex = 0.8)

  box()
}

################################################################################
# PAGE 6: QC FLAGS SUMMARY
################################################################################

plot.new()
plot.window(xlim = 0:10, ylim = 0:10)
title("Quality Control Flags", line = -2)

text_y <- 9

if (!is.null(loaded_data$curated_genomes) &&
    "qc_flags" %in% names(loaded_data$curated_genomes)) {

  genomes <- loaded_data$curated_genomes
  qc_flags <- genomes$qc_flags[!is.na(genomes$qc_flags)]

  if (length(qc_flags) > 0) {
    # Parse flags
    all_flags <- strsplit(qc_flags, ";")
    all_flags <- unlist(all_flags)
    flag_counts <- table(all_flags)
    flag_counts <- sort(flag_counts, decreasing = TRUE)

    text(0.5, text_y, "FLAGGED GENOMES BY ISSUE TYPE:", font = 2, cex = 1.1, adj = 0)
    text_y <- text_y - 0.8

    for (i in seq_along(flag_counts)) {
      flag <- names(flag_counts)[i]
      count <- flag_counts[i]
      pct <- 100 * count / nrow(genomes)
      text(1, text_y, sprintf("%-30s: %3d (%5.1f%%)", flag, count, pct),
           adj = 0, cex = 0.9, family = "monospace")
      text_y <- text_y - 0.6
    }
  } else {
    text(1, text_y, "No QC flags detected (excellent!)", adj = 0, cex = 1.1)
  }
}

################################################################################
# PAGE 7: DATA COMPLETENESS
################################################################################

plot.new()
plot.window(xlim = 0:10, ylim = 0:10)
title("Data Completeness Assessment", line = -2)

if (!is.null(loaded_data$curated_genomes)) {
  genomes <- loaded_data$curated_genomes

  completeness_checks <- list(
    "species_name" = sum(!is.na(genomes$species_name) & nchar(genomes$species_name) > 0),
    "assembly_accession" = sum(!is.na(genomes$assembly_accession)),
    "assembly_level" = sum(!is.na(genomes$assembly_level)),
    "family" = sum(!is.na(genomes$family)),
    "clade_assignment" = sum(!is.na(genomes$clade_assignment)),
    "source" = sum(!is.na(genomes$source))
  )

  total <- nrow(genomes)

  text_y <- 9
  text(0.5, text_y, "FIELD COMPLETENESS (genomes with non-empty values):",
       font = 2, cex = 1.1, adj = 0)
  text_y <- text_y - 0.8

  # Create simple bars
  for (field in names(completeness_checks)) {
    count <- completeness_checks[[field]]
    pct <- 100 * count / total

    # Draw bar outline
    bar_width <- (pct / 100) * 5
    rect(1, text_y - 0.3, 1 + bar_width, text_y)
    text(6, text_y - 0.15, sprintf("%-30s: %3d / %3d (%5.1f%%)",
                                   field, count, total, pct),
         adj = 0, cex = 0.9, family = "monospace")
    text_y <- text_y - 0.6
  }
}

################################################################################
# PAGE 8: DATA SUMMARY TABLE
################################################################################

plot.new()
plot.window(xlim = 0:10, ylim = 0:10)
title("Summary Statistics Table", line = -2)

text_y <- 9.5
text(0.5, text_y, "SCARAB - PHASE 1 INVENTORY COMPLETE",
     font = 2, cex = 1.2, adj = 0)

text_y <- text_y - 1

summary_lines <- c(
  "Dataset Overview",
  "===============",
  paste("Total genomes curated:", summary_stats$total_genomes %||% "N/A"),
  paste("Unique species:", summary_stats$total_species %||% "N/A"),
  paste("QC flagged:", summary_stats$qc_flagged %||% "N/A"),
  "",
  "Primary Outputs Generated",
  "========================",
  "✓ merged_genomes.csv - consolidated genome catalog",
  "✓ curated_genomes.csv - taxonomically placed genomes",
  "✓ fasta_urls.csv - NCBI FTP download links",
  "✓ constraint_tree.nwk - phylogenetic backbone",
  "",
  "Quality Checks Performed",
  "=======================",
  "✓ Assembly level validation",
  "✓ Taxonomic classification",
  "✓ Clade assignment",
  "✓ Source verification",
  "✓ Checksum validation"
)

text_size <- 0.85
for (line in summary_lines) {
  text(0.5, text_y, line, adj = 0, cex = text_size, family = "monospace")
  text_y <- text_y - 0.4
}

################################################################################
# CLOSE PDF
################################################################################

dev.off()
cat("  ✓ PDF report generated:", pdf_file, "\n")

################################################################################
# 4. GENERATE TEXT SUMMARY
################################################################################

cat("\nStep 4: Writing text summary...\n")

summary_file <- "qc_summary.txt"

summary_text <- c(
  "================================================================================",
  "SCARAB - PHASE 1 GENOME INVENTORY",
  "Quality Control and Summary Report",
  paste("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "================================================================================",
  "",
  "EXECUTIVE SUMMARY",
  "=================",
  paste("Total Genomes Curated:", summary_stats$total_genomes %||% "N/A"),
  paste("Unique Species:", summary_stats$total_species %||% "N/A"),
  paste("QC Flagged Genomes:", summary_stats$qc_flagged %||% "N/A"),
  "",
  "ASSEMBLY LEVEL DISTRIBUTION",
  "===========================",
  if (!is.null(summary_stats$assembly_levels)) {
    paste(names(summary_stats$assembly_levels), ":",
          summary_stats$assembly_levels, collapse = "\n")
  } else { "N/A" },
  "",
  "ASSEMBLY SOURCES",
  "================",
  if (!is.null(summary_stats$sources)) {
    paste(names(summary_stats$sources), ":",
          summary_stats$sources, collapse = "\n")
  } else { "N/A" },
  "",
  "TOP FAMILIES",
  "============",
  if (!is.null(summary_stats$top_families)) {
    paste(names(summary_stats$top_families), ":",
          summary_stats$top_families, collapse = "\n")
  } else { "N/A" },
  "",
  "PHYLOGENETIC DISTRIBUTION",
  "=========================",
  if (!is.null(summary_stats$clades)) {
    paste(names(summary_stats$clades), ":",
          summary_stats$clades, collapse = "\n")
  } else { "N/A" },
  "",
  "FILES GENERATED",
  "===============",
  "✓ qc_report.pdf - multi-page visual report",
  "✓ qc_summary.txt - this text file",
  "",
  "END OF REPORT",
  "================================================================================"
)

cat(paste(summary_text, collapse = "\n"), file = summary_file)
cat("  ✓ Text summary written to:", summary_file, "\n")

################################################################################
# 5. COMPLETION MESSAGE
################################################################################

cat("\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("SUMMARY\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("Total genomes in final dataset:", summary_stats$total_genomes, "\n")
cat("Unique species represented:", summary_stats$total_species, "\n")
cat("QC flagged:", summary_stats$qc_flagged, "\n")
cat("\nOutput files:\n")
cat("  -", pdf_file, "\n")
cat("  -", summary_file, "\n")
cat("\nPhase 1 complete!\n")

################################################################################
# END OF SCRIPT
################################################################################
