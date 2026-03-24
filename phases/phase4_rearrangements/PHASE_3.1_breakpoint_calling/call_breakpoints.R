#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.1 — BREAKPOINT CALLING
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Identify and classify chromosomal rearrangement breakpoints by comparing
#   synteny block order and orientation between extant species and ancestral
#   genomes. Classify events as fusions, fissions, inversions, or translocations.
#   Annotate breakpoints with confidence intervals.
#
# INPUT:
#   - synteny_anchored.tsv     Synteny blocks with chr/position/orientation
#   - constraint_tree.nwk      Phylogenetic tree with branch lengths
#
# OUTPUT:
#   - rearrangements_raw.tsv   All detected rearrangements with breakpoint coords
#   - call_breakpoints.log     Processing log
#
# AUTHOR: SCARAB Team
# DATE: 2026-03-21
#
################################################################################

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 10)

# ============================================================================
# 0. CONFIGURATION & PATHS

## <<<STUDENT: Set PROJECT_ROOT to your SCARAB project directory>>>
PROJECT_ROOT <- Sys.getenv("SCARAB_ROOT",
                           unset = normalizePath(file.path(dirname(sys.frame(1)$ofile), "..", "..", ".."),
                                                  mustWork = FALSE))
if (!dir.exists(PROJECT_ROOT)) {
  stop("PROJECT_ROOT not found: ", PROJECT_ROOT,
       "\nSet SCARAB_ROOT environment variable or run from within the project")
}
# ============================================================================

## <<<STUDENT: Update path to Phase 3 input directory>>>
PHASE3_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase3_alignment_synteny")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.1_breakpoint_calling")

# Expected input files
SYNTENY_FILE <- file.path(PHASE3_INPUT_DIR, "synteny_anchored.tsv")
TREE_FILE    <- file.path(PHASE3_INPUT_DIR, "constraint_tree.nwk")

# Create output directory if needed
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "call_breakpoints.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.1: Breakpoint Calling ===")

# ============================================================================
# 1. READ DATA
# ============================================================================

log_msg("Reading synteny file...")
if (!file.exists(SYNTENY_FILE)) {
  log_msg(paste("ERROR: Synteny file not found:", SYNTENY_FILE))
  stop("Synteny file missing")
}

synteny <- read.delim(SYNTENY_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(synteny), "synteny blocks"))
log_msg(paste("  Columns:", paste(colnames(synteny), collapse = ", ")))

log_msg("Reading phylogenetic tree...")
if (!file.exists(TREE_FILE)) {
  log_msg(paste("ERROR: Tree file not found:", TREE_FILE))
  stop("Tree file missing")
}

tree_str <- readLines(TREE_FILE)
log_msg(paste("  Tree loaded (", nchar(tree_str), "chars)")

# ============================================================================
# 2. VALIDATE DATA STRUCTURE
# ============================================================================

log_msg("Validating synteny data structure...")

required_cols <- c("block_id", "extant_species", "extant_chr", "extant_start",
                   "extant_end", "ancestral_species", "ancestral_chr",
                   "ancestral_start", "ancestral_end", "orientation")

missing_cols <- setdiff(required_cols, colnames(synteny))
if (length(missing_cols) > 0) {
  log_msg(paste("WARNING: Missing expected columns:", paste(missing_cols, collapse = ", ")))
}

# Ensure numeric columns
numeric_cols <- c("extant_start", "extant_end", "ancestral_start",
                  "ancestral_end")
for (col in numeric_cols) {
  if (col %in% colnames(synteny)) {
    synteny[[col]] <- as.numeric(synteny[[col]])
  }
}

# ============================================================================
# 3. PARSE TREE TO IDENTIFY SPECIES RELATIONSHIPS
# ============================================================================

log_msg("Parsing phylogenetic tree structure...")

## <<<STUDENT: If using ape package, uncomment below. Otherwise update to match your tree format>>>
# library(ape)
# tree <- read.tree(text = tree_str)
# species_nodes <- tree$tip.label
# log_msg(paste("  Found", length(species_nodes), "species tips"))

# For now, extract species list from synteny data
extant_species <- unique(synteny$extant_species)
log_msg(paste("  Species in synteny data:", paste(extant_species, collapse = ", ")))

# ============================================================================
# 4. CLASSIFY REARRANGEMENTS
# ============================================================================

log_msg("Classifying rearrangements...")

rearrangements <- data.frame(
  rearrangement_id = character(),
  type = character(),
  species = character(),
  ancestral_node = character(),
  chr_involved = character(),
  breakpoint_1 = numeric(),
  breakpoint_2 = numeric(),
  confidence_lower = numeric(),
  confidence_upper = numeric(),
  supporting_blocks = numeric(),
  stringsAsFactors = FALSE
)

counter <- 0

# Process each species pair vs ancestor
species_pairs <- unique(synteny[, c("extant_species", "ancestral_species")])

for (i in seq_len(nrow(species_pairs))) {
  sp_pair <- species_pairs[i, ]
  extant_sp <- sp_pair$extant_species
  ancestral_sp <- sp_pair$ancestral_species

  log_msg(paste("  Processing:", extant_sp, "vs", ancestral_sp))

  # Subset synteny blocks for this species pair
  sp_synteny <- subset(synteny, extant_species == extant_sp &
                               ancestral_species == ancestral_sp)

  # Get unique chromosomes
  extant_chrs <- unique(sp_synteny$extant_chr)
  ancestral_chrs <- unique(sp_synteny$ancestral_chr)

  # ========================================================================
  # 4A. FUSION: Multiple ancestral chromosomes map to single extant chromosome
  # ========================================================================

  for (ext_chr in extant_chrs) {
    blocks_on_chr <- subset(sp_synteny, extant_chr == ext_chr)
    anc_chrs_on_ext <- unique(blocks_on_chr$ancestral_chr)

    if (length(anc_chrs_on_ext) > 1) {
      # Potential fusion
      counter <- counter + 1

      # Find breakpoint: boundary between blocks from different ancestral chrs
      anc_chr_groups <- split(blocks_on_chr, blocks_on_chr$ancestral_chr)

      # Approximate breakpoint as gap between consecutive blocks on extant chr
      extant_positions <- sort(unique(c(blocks_on_chr$extant_start,
                                        blocks_on_chr$extant_end)))

      breakpoint_1 <- extant_positions[1]
      breakpoint_2 <- extant_positions[length(extant_positions)]

      ## <<<STUDENT: Adjust confidence interval as needed (±5kb is default)>>>
      confidence_range <- 5000

      rearrangements <- rbind(rearrangements, data.frame(
        rearrangement_id = paste0("REARR_", counter),
        type = "fusion",
        species = extant_sp,
        ancestral_node = ancestral_sp,
        chr_involved = paste(sort(anc_chrs_on_ext), collapse = "+"),
        breakpoint_1 = breakpoint_1,
        breakpoint_2 = breakpoint_2,
        confidence_lower = breakpoint_1 - confidence_range,
        confidence_upper = breakpoint_2 + confidence_range,
        supporting_blocks = nrow(blocks_on_chr),
        stringsAsFactors = FALSE
      ))
    }
  }

  # ========================================================================
  # 4B. FISSION: Single ancestral chromosome maps to multiple extant chromosomes
  # ========================================================================

  for (anc_chr in ancestral_chrs) {
    blocks_on_anc <- subset(sp_synteny, ancestral_chr == anc_chr)
    ext_chrs_on_anc <- unique(blocks_on_anc$extant_chr)

    if (length(ext_chrs_on_anc) > 1) {
      # Potential fission
      counter <- counter + 1

      extant_positions <- sort(unique(c(blocks_on_anc$extant_start,
                                        blocks_on_anc$extant_end)))

      breakpoint_1 <- extant_positions[1]
      breakpoint_2 <- extant_positions[length(extant_positions)]

      ## <<<STUDENT: Adjust confidence interval as needed>>>
      confidence_range <- 5000

      rearrangements <- rbind(rearrangements, data.frame(
        rearrangement_id = paste0("REARR_", counter),
        type = "fission",
        species = extant_sp,
        ancestral_node = ancestral_sp,
        chr_involved = paste(sort(ext_chrs_on_anc), collapse = "/"),
        breakpoint_1 = breakpoint_1,
        breakpoint_2 = breakpoint_2,
        confidence_lower = breakpoint_1 - confidence_range,
        confidence_upper = breakpoint_2 + confidence_range,
        supporting_blocks = nrow(blocks_on_anc),
        stringsAsFactors = FALSE
      ))
    }
  }

  # ========================================================================
  # 4C. INVERSION: Blocks in reverse orientation
  # ========================================================================

  reversed_blocks <- subset(sp_synteny, orientation == "-" | orientation == "reverse")

  if (nrow(reversed_blocks) > 0) {
    for (ext_chr in unique(reversed_blocks$extant_chr)) {
      chr_reversed <- subset(reversed_blocks, extant_chr == ext_chr)

      # Group consecutive reversed blocks
      chr_reversed <- chr_reversed[order(chr_reversed$extant_start), ]

      if (nrow(chr_reversed) > 0) {
        counter <- counter + 1

        bp1 <- min(chr_reversed$extant_start)
        bp2 <- max(chr_reversed$extant_end)

        ## <<<STUDENT: Adjust confidence interval>>>
        confidence_range <- 5000

        rearrangements <- rbind(rearrangements, data.frame(
          rearrangement_id = paste0("REARR_", counter),
          type = "inversion",
          species = extant_sp,
          ancestral_node = ancestral_sp,
          chr_involved = as.character(ext_chr),
          breakpoint_1 = bp1,
          breakpoint_2 = bp2,
          confidence_lower = bp1 - confidence_range,
          confidence_upper = bp2 + confidence_range,
          supporting_blocks = nrow(chr_reversed),
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # ========================================================================
  # 4D. TRANSLOCATION: Block moves to different chromosome
  # (Partial blocks on non-contiguous chromosomes)
  # ========================================================================

  # For each block, check if it has a split mapping pattern
  for (block_id in unique(sp_synteny$block_id)) {
    block_records <- subset(sp_synteny, block_id == block_id)

    if (nrow(block_records) > 1) {
      # Single block mapping to multiple locations (possible translocation)
      ext_chrs <- unique(block_records$extant_chr)

      if (length(ext_chrs) > 1) {
        counter <- counter + 1

        bp1 <- min(block_records$extant_start)
        bp2 <- max(block_records$extant_end)

        ## <<<STUDENT: Adjust confidence interval>>>
        confidence_range <- 5000

        rearrangements <- rbind(rearrangements, data.frame(
          rearrangement_id = paste0("REARR_", counter),
          type = "translocation",
          species = extant_sp,
          ancestral_node = ancestral_sp,
          chr_involved = paste(sort(unique(block_records$ancestral_chr)),
                              collapse = "->"),
          breakpoint_1 = bp1,
          breakpoint_2 = bp2,
          confidence_lower = bp1 - confidence_range,
          confidence_upper = bp2 + confidence_range,
          supporting_blocks = nrow(block_records),
          stringsAsFactors = FALSE
        ))
      }
    }
  }
}

log_msg(paste("Identified", nrow(rearrangements), "total rearrangements"))
log_msg(paste("  By type:"))
for (type in unique(rearrangements$type)) {
  count <- sum(rearrangements$type == type)
  log_msg(paste("    ", type, ":", count))
}

# ============================================================================
# 5. WRITE OUTPUT
# ============================================================================

log_msg("Writing output files...")

output_file <- file.path(OUTPUT_DIR, "rearrangements_raw.tsv")
write.table(rearrangements, file = output_file, sep = "\t",
            row.names = FALSE, quote = FALSE)
log_msg(paste("  Wrote:", output_file))

log_msg("=== PHASE 3.1 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 3.1 complete. Check log at:", LOG_FILE, "\n")
