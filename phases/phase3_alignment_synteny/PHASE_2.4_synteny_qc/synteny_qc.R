#!/usr/bin/env Rscript
##############################################################################
# PHASE_2.4_synteny_qc/synteny_qc.R
#
# Purpose:
#   Quality control filtering of synteny blocks
#   Removes blocks that fail quality thresholds:
#   - Block size < 10 kb (too small, likely noise)
#   - Sequence identity < 95% (too divergent)
#   - Self-alignments (same species)
#   - Fold-back artifacts (inverted repeats)
#   - Duplicate filtering (keep best alignments)
#
# Input:
#   - synteny_blocks_raw.tsv (from extract_synteny.slurm)
#   - Configuration: filtering thresholds
#
# Output:
#   - synteny_blocks_qc.tsv (filtered, high-quality blocks)
#   - qc_report.txt (summary statistics and filtering ratios)
#   - qc_filters_applied.log (detailed filtering log)
#
# Usage:
#   Rscript synteny_qc.R \
#     --input /path/to/synteny_blocks_raw.tsv \
#     --output /path/to/synteny_blocks_qc.tsv \
#     --min-size 10000 \
#     --min-identity 0.95
#
# Dependencies:
#   - tidyverse (for data manipulation)
#   - data.table (for large file handling)
##############################################################################

suppressPackageStartupMessages({
  library(optparse)
  library(data.table)
  library(dplyr)
  library(tidyr)
})

# Command-line argument parsing
option_list <- list(
  make_option(
    c("-i", "--input"),
    type = "character",
    default = NULL,
    help = "Input synteny blocks file (TSV) [REQUIRED]"
  ),
  make_option(
    c("-o", "--output"),
    type = "character",
    default = "synteny_blocks_qc.tsv",
    help = "Output filtered synteny blocks [default: %default]"
  ),
  make_option(
    c("-r", "--report"),
    type = "character",
    default = "synteny_qc_report.txt",
    help = "QC report file [default: %default]"
  ),
  make_option(
    c("--min-size"),
    type = "integer",
    default = 10000,
    help = "Minimum block size in bp [default: %default]"
  ),
  make_option(
    c("--min-identity"),
    type = "double",
    default = 0.95,
    help = "Minimum sequence identity (0-1) [default: %default]"
  ),
  make_option(
    c("--remove-self"),
    type = "logical",
    default = TRUE,
    help = "Remove self-alignments (same species) [default: %default]"
  ),
  make_option(
    c("--remove-foldbacks"),
    type = "logical",
    default = TRUE,
    help = "Remove fold-back artifacts [default: %default]"
  ),
  make_option(
    c("--verbose"),
    type = "logical",
    default = TRUE,
    help = "Verbose output [default: %default]"
  )
)

parser <- OptionParser(option_list = option_list)
args <- parse_args(parser, positional_arguments = 0)

# Validate required arguments
if (is.null(args$input)) {
  print_help(parser)
  cat("\nERROR: --input is required\n", file = stderr())
  quit(status = 1)
}

input_file <- args$input
output_file <- args$output
report_file <- args$report
min_size <- args$"min-size"
min_identity <- args$"min-identity"
remove_self <- args$"remove-self"
remove_foldbacks <- args$"remove-foldbacks"
verbose <- args$verbose

# Helper function for verbose logging
vlog <- function(msg) {
  if (verbose) {
    cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
  }
}

vlog("Synteny QC pipeline started")
vlog(sprintf("Input file:      %s", input_file))
vlog(sprintf("Output file:     %s", output_file))
vlog(sprintf("Report file:     %s", report_file))
vlog(sprintf("Min size:        %d bp", min_size))
vlog(sprintf("Min identity:    %.1f%%", min_identity * 100))
vlog("")

# ============================================================================
# 1. Read synteny blocks
# ============================================================================
vlog("Reading synteny blocks...")

if (!file.exists(input_file)) {
  stop(sprintf("ERROR: Input file not found: %s", input_file))
}

# Read with data.table for efficiency with large files
synteny <- fread(input_file, header = TRUE, sep = "\t")

vlog(sprintf("  ✓ Read %d blocks", nrow(synteny)))
vlog(sprintf("  Columns: %s", paste(names(synteny), collapse = ", ")))
vlog("")

# Store original count for reporting
n_original <- nrow(synteny)

# ============================================================================
# 2. Filter 1: Remove blocks below minimum size
# ============================================================================
vlog("FILTER 1: Minimum block size")

n_before <- nrow(synteny)
synteny <- synteny[block_size >= min_size, ]
n_removed <- n_before - nrow(synteny)

vlog(sprintf("  Removed: %d (< %d bp)", n_removed, min_size))
vlog(sprintf("  Retained: %d (%.1f%%)", nrow(synteny), 100 * nrow(synteny) / n_original))
vlog("")

# ============================================================================
# 3. Filter 2: Remove blocks below minimum identity
# ============================================================================
vlog("FILTER 2: Minimum sequence identity")

n_before <- nrow(synteny)
synteny <- synteny[identity >= min_identity, ]
n_removed <- n_before - nrow(synteny)

vlog(sprintf("  Removed: %d (< %.1f%% identity)", n_removed, min_identity * 100))
vlog(sprintf("  Retained: %d (%.1f%%)", nrow(synteny), 100 * nrow(synteny) / n_original))
vlog("")

# ============================================================================
# 4. Filter 3: Remove self-alignments (if enabled)
# ============================================================================
if (remove_self) {
  vlog("FILTER 3: Remove self-alignments")

  n_before <- nrow(synteny)
  synteny <- synteny[query_genome != target_genome, ]
  n_removed <- n_before - nrow(synteny)

  vlog(sprintf("  Removed: %d self-alignments", n_removed))
  vlog(sprintf("  Retained: %d (%.1f%%)", nrow(synteny), 100 * nrow(synteny) / n_original))
  vlog("")
}

# ============================================================================
# 5. Filter 4: Remove fold-back artifacts (if enabled)
# ============================================================================
if (remove_foldbacks) {
  vlog("FILTER 4: Remove fold-back artifacts")

  # Fold-backs occur when query and target strands are opposite AND
  # coordinates overlap or invert in a suspicious pattern

  n_before <- nrow(synteny)

  # Create unique block identifiers for deduplication
  synteny <- synteny %>%
    mutate(
      query_range = sprintf("%s:%d-%d", query_chrom, query_start, query_end),
      target_range = sprintf("%s:%d-%d", target_chrom, target_start, target_end),
      pair_id = ifelse(
        query_genome < target_genome,
        sprintf("%s_%s", query_genome, target_genome),
        sprintf("%s_%s", target_genome, query_genome)
      )
    )

  # Check for suspicious strand combinations
  synteny <- synteny %>%
    filter(!(query_strand != target_strand & abs(query_end - query_start) < 5000))

  n_removed <- n_before - nrow(synteny)
  vlog(sprintf("  Removed: %d fold-back artifacts", n_removed))
  vlog(sprintf("  Retained: %d (%.1f%%)", nrow(synteny), 100 * nrow(synteny) / n_original))
  vlog("")
}

# ============================================================================
# 6. Filter 5: Deduplication (keep best alignment per region pair)
# ============================================================================
vlog("FILTER 5: Deduplication")

n_before <- nrow(synteny)

# For each unique pair of blocks, keep only the best (highest identity)
synteny <- synteny %>%
  group_by(query_genome, target_genome, query_range, target_range) %>%
  slice(which.max(identity)) %>%
  ungroup()

n_removed <- n_before - nrow(synteny)
vlog(sprintf("  Removed: %d duplicates", n_removed))
vlog(sprintf("  Retained: %d (%.1f%%)", nrow(synteny), 100 * nrow(synteny) / n_original))
vlog("")

# ============================================================================
# 7. Summary statistics
# ============================================================================
vlog("SUMMARY STATISTICS")
vlog("")

# By genome pair
genome_pairs <- synteny %>%
  group_by(query_genome, target_genome) %>%
  summarise(
    n_blocks = n(),
    total_bp = sum(block_size),
    avg_identity = mean(identity),
    .groups = "drop"
  ) %>%
  arrange(desc(n_blocks))

vlog("Top 10 genome pairs by block count:")
print(as.data.frame(genome_pairs[1:min(10, nrow(genome_pairs)), ]), n = 10)
vlog("")

# Block size distribution
vlog("Block size statistics:")
vlog(sprintf("  Min:    %d bp", min(synteny$block_size)))
vlog(sprintf("  Q1:     %d bp", quantile(synteny$block_size, 0.25)))
vlog(sprintf("  Median: %d bp", median(synteny$block_size)))
vlog(sprintf("  Q3:     %d bp", quantile(synteny$block_size, 0.75)))
vlog(sprintf("  Max:    %d bp", max(synteny$block_size)))
vlog(sprintf("  Mean:   %d bp", round(mean(synteny$block_size))))
vlog("")

# Identity distribution
vlog("Identity statistics:")
vlog(sprintf("  Min:    %.1f%%", min(synteny$identity) * 100))
vlog(sprintf("  Q1:     %.1f%%", quantile(synteny$identity, 0.25) * 100))
vlog(sprintf("  Median: %.1f%%", median(synteny$identity) * 100))
vlog(sprintf("  Q3:     %.1f%%", quantile(synteny$identity, 0.75) * 100))
vlog(sprintf("  Max:    %.1f%%", max(synteny$identity) * 100))
vlog(sprintf("  Mean:   %.1f%%", mean(synteny$identity) * 100))
vlog("")

# ============================================================================
# 8. Write output files
# ============================================================================
vlog("Writing output files...")

# Write filtered synteny blocks
output_cols <- c("query_genome", "target_genome", "query_chrom", "query_start",
                "query_end", "query_strand", "target_chrom", "target_start",
                "target_end", "target_strand", "identity", "block_size")

synteny_output <- synteny[, ..output_cols]
fwrite(synteny_output, file = output_file, sep = "\t", quote = FALSE)

vlog(sprintf("  ✓ Filtered blocks: %s (%d blocks)", output_file, nrow(synteny)))

# ============================================================================
# 9. Generate detailed report
# ============================================================================
vlog("Generating report...")

report_text <- sprintf(
  "COLEOPTERA SYNTENY QC REPORT
================================================================================
Generated: %s

INPUT:
  File:         %s
  Total blocks: %d

FILTERING PARAMETERS:
  Minimum size:       %d bp
  Minimum identity:   %.1f%%
  Remove self:        %s
  Remove foldbacks:   %s

FILTERING RESULTS:
  Input blocks:       %d (100%%)
  Output blocks:      %d (%.1f%%)
  Blocks removed:     %d
  Filtering ratio:    %.1f%%

QUALITY STATISTICS (Post-QC):

  Block size:
    Min:              %d bp
    Median:           %d bp
    Mean:             %d bp
    Max:              %d bp
    Total bp:         %d

  Sequence identity:
    Min:              %.1f%%
    Median:           %.1f%%
    Mean:             %.1f%%
    Max:              %.1f%%

  Genome pairs:       %d
  Top pair:           %s (%d blocks)

OUTPUT:
  Filtered blocks:    %s

NEXT STEPS:
  1. Review filtered block statistics
  2. Perform synteny anchoring to ancestral genomes
  3. Generate synteny visualizations (dot plots, circos)
  4. Assess conservation patterns

================================================================================",
  Sys.time(),
  input_file,
  n_original,
  min_size,
  min_identity * 100,
  remove_self,
  remove_foldbacks,
  n_original,
  nrow(synteny),
  100 * nrow(synteny) / n_original,
  n_original - nrow(synteny),
  100 * (n_original - nrow(synteny)) / n_original,
  min(synteny$block_size),
  median(synteny$block_size),
  round(mean(synteny$block_size)),
  max(synteny$block_size),
  sum(synteny$block_size),
  min(synteny$identity) * 100,
  median(synteny$identity) * 100,
  mean(synteny$identity) * 100,
  max(synteny$identity) * 100,
  nrow(genome_pairs),
  sprintf("%s-%s", genome_pairs$query_genome[1], genome_pairs$target_genome[1]),
  genome_pairs$n_blocks[1],
  output_file
)

write(report_text, file = report_file)

vlog(sprintf("  ✓ Report: %s", report_file))
vlog("")

# ============================================================================
# 10. Success message
# ============================================================================
vlog("Synteny QC pipeline completed successfully!")
vlog("")
vlog("SUMMARY:")
vlog(sprintf("  Input:   %d blocks", n_original))
vlog(sprintf("  Output:  %d blocks (%.1f%% retained)", nrow(synteny), 100 * nrow(synteny) / n_original))
vlog(sprintf("  Removed: %d blocks (%.1f%%)", n_original - nrow(synteny), 100 * (n_original - nrow(synteny)) / n_original))
vlog("")
vlog(sprintf("Output files:"))
vlog(sprintf("  %s", output_file))
vlog(sprintf("  %s", report_file))
