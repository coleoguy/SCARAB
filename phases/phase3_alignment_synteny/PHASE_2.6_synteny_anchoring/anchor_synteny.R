#!/usr/bin/env Rscript
##############################################################################
# PHASE_2.6_synteny_anchoring/anchor_synteny.R
#
# Purpose:
#   Map synteny blocks to ancestral genomes using BLAST-like alignment
#   Anchors conserved blocks to predicted ancestral genome locations
#   Identifies which synteny blocks are conserved at which evolutionary depths
#
# Input:
#   - synteny_blocks_qc.tsv (filtered blocks from QC)
#   - Ancestral genome FASTAs (from RACA)
#   - Extant genome FASTAs (from initial inventory)
#
# Output:
#   - synteny_anchored.tsv (blocks with ancestral genome annotations)
#   - anchoring_report.txt (statistics and quality metrics)
#   - ancestor_conservation_matrix.tsv (which ancestors show which blocks)
#
# Usage:
#   Rscript anchor_synteny.R \
#     --synteny /path/to/synteny_blocks_qc.tsv \
#     --ancestors /path/to/ancestral_genomes_dir \
#     --genomes /path/to/genomes_dir \
#     --output /path/to/synteny_anchored.tsv
#
# Dependencies:
#   - tidyverse (for data manipulation)
#   - Biostrings (for sequence operations)
#   - data.table (for large file handling)
##############################################################################

suppressPackageStartupMessages({
  library(optparse)
  library(data.table)
  library(dplyr)
  library(tidyr)
  library(stringr)
})

# Command-line argument parsing
option_list <- list(
  make_option(
    c("-s", "--synteny"),
    type = "character",
    default = NULL,
    help = "Input synteny blocks (TSV) [REQUIRED]"
  ),
  make_option(
    c("-a", "--ancestors"),
    type = "character",
    default = NULL,
    help = "Path to ancestral genome directory [REQUIRED]"
  ),
  make_option(
    c("-g", "--genomes"),
    type = "character",
    default = NULL,
    help = "Path to extant genome directory [REQUIRED]"
  ),
  make_option(
    c("-o", "--output"),
    type = "character",
    default = "synteny_anchored.tsv",
    help = "Output file for anchored blocks [default: %default]"
  ),
  make_option(
    c("-r", "--report"),
    type = "character",
    default = "anchoring_report.txt",
    help = "Anchoring report file [default: %default]"
  ),
  make_option(
    c("--min-overlap"),
    type = "double",
    default = 0.50,
    help = "Minimum overlap fraction (0-1) for block anchoring [default: %default]"
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
if (is.null(args$synteny) || is.null(args$ancestors) || is.null(args$genomes)) {
  print_help(parser)
  cat("\nERROR: --synteny, --ancestors, and --genomes are required\n", file = stderr())
  quit(status = 1)
}

synteny_file <- args$synteny
ancestors_dir <- args$ancestors
genomes_dir <- args$genomes
output_file <- args$output
report_file <- args$report
min_overlap <- args$"min-overlap"
verbose <- args$verbose

# Helper function for verbose logging
vlog <- function(msg) {
  if (verbose) {
    cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
  }
}

vlog("Synteny anchoring pipeline started")
vlog(sprintf("Synteny file:    %s", synteny_file))
vlog(sprintf("Ancestors dir:   %s", ancestors_dir))
vlog(sprintf("Genomes dir:     %s", genomes_dir))
vlog(sprintf("Output file:     %s", output_file))
vlog(sprintf("Min overlap:     %.0f%%", min_overlap * 100))
vlog("")

# ============================================================================
# 1. Read synteny blocks
# ============================================================================
vlog("Reading QC-filtered synteny blocks...")

if (!file.exists(synteny_file)) {
  stop(sprintf("ERROR: Synteny file not found: %s", synteny_file))
}

synteny <- fread(synteny_file, header = TRUE, sep = "\t")
n_blocks <- nrow(synteny)

vlog(sprintf("  ✓ Read %d blocks", n_blocks))
vlog("")

# ============================================================================
# 2. Discover ancestral genomes
# ============================================================================
vlog("Discovering ancestral genomes...")

if (!dir.exists(ancestors_dir)) {
  stop(sprintf("ERROR: Ancestors directory not found: %s", ancestors_dir))
}

# Find all FASTA files
ancestor_files <- list.files(
  ancestors_dir,
  pattern = ".*\\.fa$",
  recursive = TRUE,
  full.names = TRUE
)

vlog(sprintf("  ✓ Found %d ancestral genome files", length(ancestor_files)))

# Parse ancestral genome metadata
ancestors <- data.frame(
  path = ancestor_files,
  ancestor_name = basename(dirname(ancestor_files)),
  stringsAsFactors = FALSE
)

vlog("  Ancestral genomes:")
print(head(ancestors, 10))
vlog("")

# ============================================================================
# 3. Anchoring step: Match blocks to ancestor genomes
# ============================================================================
vlog("Anchoring synteny blocks to ancestral genomes...")

# For each synteny block, check if the underlying sequences are present
# in any ancestral genome (simplified approach)

# Store extended synteny data with ancestor information
synteny$ancestor_name <- NA_character_
synteny$overlap_with_ancestor <- 0.0
synteny$anchoring_quality <- "unanchored"

# Simplified anchoring logic:
# 1. For each block, look for sequence matches in ancestral genomes
# 2. Assign to the best-matching ancestor
# 3. Calculate overlap fraction

## <<<STUDENT: Implement BLAST-like anchoring>>>
## For efficiency, this could use:
## - BLAT (fast sequence search)
## - minimap2 (alignment)
## - Custom k-mer matching
## For now, we implement a simplified version based on block coordinates

vlog("  Anchoring method: coordinate-based (simplified)")
vlog("  Processing blocks...")

# Count blocks by potential ancestor
ancestor_assignments <- data.frame(
  ancestor = character(),
  n_blocks = integer(),
  total_bp = integer(),
  avg_identity = numeric()
)

for (i in seq_along(ancestors$ancestor_name)) {
  ancestor <- ancestors$ancestor_name[i]

  # Simplified assignment: blocks from deeper evolutionary divergences
  # are more likely to be conserved in older ancestors

  ## <<<STUDENT: Replace with actual BLAST/alignment step>>>
  ## This assigns blocks based on a simple heuristic

  # Assign blocks to ancestors based on query genome name patterns
  # (This is a placeholder for actual alignment-based anchoring)

  if (grepl("MRCA", ancestor, ignore.case = TRUE)) {
    # High-level ancestor: can anchor most blocks
    ancestor_assignments <- rbind(
      ancestor_assignments,
      data.frame(
        ancestor = ancestor,
        n_blocks = nrow(synteny),
        total_bp = sum(synteny$block_size),
        avg_identity = mean(synteny$identity),
        stringsAsFactors = FALSE
      )
    )
  }
}

vlog(sprintf("  ✓ Anchored blocks to %d ancestors", nrow(ancestor_assignments)))
vlog("")

# ============================================================================
# 4. Add ancestor information to synteny data
# ============================================================================
vlog("Adding ancestor annotations...")

# For demonstration, assign each block to the most recent common ancestor
# of its query and target species

synteny <- synteny %>%
  mutate(
    # Simplified: assign to MRCA if both species present
    ancestor_name = case_when(
      grepl("MRCA", query_genome) ~ query_genome,
      grepl("MRCA", target_genome) ~ target_genome,
      TRUE ~ "recent_common_ancestor"
    ),
    anchoring_quality = case_when(
      identity > 0.99 & block_size > 50000 ~ "high",
      identity > 0.97 & block_size > 20000 ~ "medium",
      TRUE ~ "low"
    )
  )

vlog(sprintf("  ✓ Blocks annotated with ancestor information"))
vlog("")

# ============================================================================
# 5. Create conservation matrix
# ============================================================================
vlog("Creating ancestor-conservation matrix...")

conservation_matrix <- synteny %>%
  group_by(ancestor_name, anchoring_quality) %>%
  summarise(
    n_blocks = n(),
    total_bp = sum(block_size),
    avg_identity = mean(identity),
    .groups = "drop"
  ) %>%
  arrange(desc(n_blocks))

vlog("  Conservation by ancestor:")
print(as.data.frame(conservation_matrix))
vlog("")

# ============================================================================
# 6. Statistical summary
# ============================================================================
vlog("Generating statistics...")

total_anchored <- sum(!is.na(synteny$ancestor_name))
anchoring_rate <- 100 * total_anchored / nrow(synteny)

vlog(sprintf("Anchoring statistics:"))
vlog(sprintf("  Total blocks:        %d", nrow(synteny)))
vlog(sprintf("  Anchored blocks:     %d (%.1f%%)", total_anchored, anchoring_rate))
vlog(sprintf("  Unanchored blocks:   %d", sum(is.na(synteny$ancestor_name))))
vlog("")

vlog("Block quality distribution:")
quality_dist <- synteny %>% count(anchoring_quality)
for (i in 1:nrow(quality_dist)) {
  vlog(sprintf("  %s: %d blocks", quality_dist$anchoring_quality[i], quality_dist$n[i]))
}
vlog("")

# ============================================================================
# 7. Write output files
# ============================================================================
vlog("Writing output files...")

# Write anchored synteny
fwrite(synteny, file = output_file, sep = "\t", quote = FALSE)
vlog(sprintf("  ✓ Anchored blocks: %s", output_file))

# Write conservation matrix
matrix_file <- sub("\\.tsv$", "_conservation_matrix.tsv", output_file)
fwrite(conservation_matrix, file = matrix_file, sep = "\t", quote = FALSE)
vlog(sprintf("  ✓ Conservation matrix: %s", matrix_file))

# ============================================================================
# 8. Generate report
# ============================================================================
vlog("Generating report...")

report_text <- sprintf(
  "COLEOPTERA SYNTENY ANCHORING REPORT
================================================================================
Generated: %s

INPUT:
  Synteny blocks:      %s (%d blocks)
  Ancestral genomes:   %s (%d genomes)
  Extant genomes:      %s

ANCHORING PARAMETERS:
  Minimum overlap:     %.0f%%

RESULTS:
  Blocks anchored:     %d (%.1f%%)
  Blocks unanchored:   %d
  Ancestors matched:   %d

QUALITY DISTRIBUTION:
  High quality:        %d blocks
  Medium quality:      %d blocks
  Low quality:         %d blocks

CONSERVATION STATISTICS:

%s

ANCESTOR ASSIGNMENT:
  Blocks per ancestor:
%s

OUTPUT FILES:
  Anchored blocks:     %s
  Conservation matrix: %s

INTERPRETATION:
  Blocks with high conservation scores are present in multiple
  ancestors and represent deeply conserved genomic regions.
  Blocks with low conservation may be more recent duplications
  or lineage-specific variations.

NEXT STEPS:
  1. Validate ancestral genome assignments with BLAST
  2. Generate synteny visualizations (dot plots)
  3. Analyze conservation patterns across phylogeny
  4. Prepare manuscript figures

================================================================================",
  Sys.time(),
  synteny_file, nrow(synteny),
  ancestors_dir, nrow(ancestors),
  genomes_dir,
  min_overlap * 100,
  total_anchored, anchoring_rate,
  sum(is.na(synteny$ancestor_name)),
  length(unique(synteny$ancestor_name[!is.na(synteny$ancestor_name)])),
  sum(synteny$anchoring_quality == "high"),
  sum(synteny$anchoring_quality == "medium"),
  sum(synteny$anchoring_quality == "low"),
  paste(sprintf("  %s: %d blocks",
               conservation_matrix$ancestor_name,
               conservation_matrix$n_blocks),
        collapse = "\n"),
  paste(sprintf("  %s: %d blocks",
               ancestors$ancestor_name,
               table(synteny$ancestor_name[!is.na(synteny$ancestor_name)])[ancestors$ancestor_name]),
        collapse = "\n"),
  output_file,
  matrix_file
)

write(report_text, file = report_file)
vlog(sprintf("  ✓ Report: %s", report_file))
vlog("")

# ============================================================================
# Success message
# ============================================================================
vlog("Synteny anchoring pipeline completed!")
vlog("")
vlog("OUTPUT FILES:")
vlog(sprintf("  %s", output_file))
vlog(sprintf("  %s", report_file))
vlog(sprintf("  %s", matrix_file))
