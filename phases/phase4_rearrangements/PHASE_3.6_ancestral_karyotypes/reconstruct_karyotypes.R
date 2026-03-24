#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.6 — ANCESTRAL KARYOTYPE RECONSTRUCTION
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Reconstruct ancestral chromosome complements (karyotypes) for key nodes.
#   Count ancestral linkage groups from synteny blocks.
#   Infer chromosome number (2n) and morphology.
#
# INPUT:
#   - synteny_anchored.tsv         Synteny blocks with ancestral genome coords
#   - rearrangements_mapped.tsv    Mapped rearrangements for context
#
# OUTPUT:
#   - ancestral_karyotypes.csv     Inferred 2n and chromosome structure
#   - reconstruct_karyotypes.log   Processing log
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
SYNTENY_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase3_alignment_synteny")
REARR_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.6_ancestral_karyotypes")

SYNTENY_FILE <- file.path(SYNTENY_INPUT_DIR, "synteny_anchored.tsv")
REARR_FILE <- file.path(REARR_INPUT_DIR, "rearrangements_mapped.tsv")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "reconstruct_karyotypes.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.6: Ancestral Karyotype Reconstruction ===")

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

log_msg("Reading rearrangements...")
if (!file.exists(REARR_FILE)) {
  log_msg(paste("WARNING: Rearrangement file not found:", REARR_FILE))
  log_msg("  Continuing with synteny data alone")
  rearrangements <- NULL
} else {
  rearrangements <- read.delim(REARR_FILE, header = TRUE, sep = "\t")
  log_msg(paste("  Loaded", nrow(rearrangements), "rearrangements"))
}

# ============================================================================
# 2. IDENTIFY KEY ANCESTRAL NODES
# ============================================================================

log_msg("Identifying key ancestral nodes...")

## <<<STUDENT: Define major nodes based on your tree structure>>>
# Examples:
#   - MRCA_Coleoptera (most recent common ancestor of all beetles)
#   - MRCA_Adephaga (adephagan suborder)
#   - MRCA_Polyphaga (polyphagan suborder)
#   - MRCA_major_families (e.g., Carabidae, Cerambycidae, etc.)

key_nodes <- unique(synteny$ancestral_species)

# Filter for meaningful nodes (those with substantial synteny coverage)
node_coverage <- table(synteny$ancestral_species)
key_nodes <- names(node_coverage[node_coverage >= 10])

log_msg(paste("  Identified", length(key_nodes), "ancestral nodes with >10 synteny blocks"))

# ============================================================================
# 3. RECONSTRUCT KARYOTYPES FOR EACH NODE
# ============================================================================

log_msg("Reconstructing karyotypes for ancestral nodes...")

ancestral_karyotypes <- data.frame(
  ancestral_node = character(),
  n_linkage_groups = numeric(),
  inferred_2n = numeric(),
  n_species_supporting = numeric(),
  avg_block_size_kb = numeric(),
  notes = character(),
  stringsAsFactors = FALSE
)

for (node in key_nodes) {
  log_msg(paste("  Processing node:", node))

  # Get all synteny blocks for this ancestral node
  node_synteny <- subset(synteny, ancestral_species == node)

  # Count unique chromosomes in ancestral genome
  n_chr <- length(unique(node_synteny$ancestral_chr))

  log_msg(paste("    Linkage groups (chromosomes):", n_chr))

  # Inferred 2n: number of chromosome pairs
  # For beetles, the ancestral state was likely 2n = 20 (10 pairs)
  # But we can infer from the data
  inferred_2n <- n_chr * 2

  # Count species mapping to this node
  n_species <- length(unique(node_synteny$extant_species))

  # Average block size
  node_synteny$block_size <- node_synteny$ancestral_end - node_synteny$ancestral_start
  avg_block_size_kb <- mean(node_synteny$block_size, na.rm = TRUE) / 1000

  notes <- ""

  # Check for fusions/fissions at this node (indicate ancestral karyotype changes)
  if (!is.null(rearrangements)) {
    node_rearrs <- subset(rearrangements, ancestral_node == node)
    if (nrow(node_rearrs) > 0) {
      n_fusions <- sum(node_rearrs$type == "fusion")
      n_fissions <- sum(node_rearrs$type == "fission")

      if (n_fusions > 0 || n_fissions > 0) {
        notes <- paste("Inferred changes: ", n_fusions, " fusions, ",
                      n_fissions, " fissions", sep = "")
      }
    }
  }

  ancestral_karyotypes <- rbind(ancestral_karyotypes, data.frame(
    ancestral_node = node,
    n_linkage_groups = n_chr,
    inferred_2n = inferred_2n,
    n_species_supporting = n_species,
    avg_block_size_kb = round(avg_block_size_kb, 2),
    notes = notes,
    stringsAsFactors = FALSE
  ))
}

log_msg(paste("Reconstructed karyotypes for", nrow(ancestral_karyotypes), "nodes"))

# ============================================================================
# 4. DETAILED LINKAGE GROUP CHARACTERIZATION
# ============================================================================

log_msg("Characterizing ancestral linkage groups...")

linkage_group_detail <- data.frame(
  ancestral_node = character(),
  chromosome_id = character(),
  n_synteny_blocks = numeric(),
  total_length_mb = numeric(),
  n_extant_species_mapping = numeric(),
  description = character(),
  stringsAsFactors = FALSE
)

for (node in key_nodes) {
  node_synteny <- subset(synteny, ancestral_species == node)

  for (chr in unique(node_synteny$ancestral_chr)) {
    chr_blocks <- subset(node_synteny, ancestral_chr == chr)

    n_blocks <- nrow(chr_blocks)
    total_length_bp <- max(chr_blocks$ancestral_end, na.rm = TRUE) -
                       min(chr_blocks$ancestral_start, na.rm = TRUE)
    total_length_mb <- total_length_bp / 1e6
    n_species <- length(unique(chr_blocks$extant_species))

    description <- paste("Ancestral chromosome", chr, "in", node)

    linkage_group_detail <- rbind(linkage_group_detail, data.frame(
      ancestral_node = node,
      chromosome_id = chr,
      n_synteny_blocks = n_blocks,
      total_length_mb = round(total_length_mb, 2),
      n_extant_species_mapping = n_species,
      description = description,
      stringsAsFactors = FALSE
    ))
  }
}

log_msg(paste("Characterized", nrow(linkage_group_detail), "ancestral linkage groups"))

# ============================================================================
# 5. WRITE OUTPUT FILES
# ============================================================================

log_msg("Writing output files...")

karyotype_file <- file.path(OUTPUT_DIR, "ancestral_karyotypes.csv")
write.csv(ancestral_karyotypes, file = karyotype_file, row.names = FALSE)
log_msg(paste("  Wrote:", karyotype_file))

linkage_file <- file.path(OUTPUT_DIR, "ancestral_linkage_groups.csv")
write.csv(linkage_group_detail, file = linkage_file, row.names = FALSE)
log_msg(paste("  Wrote:", linkage_file))

# ============================================================================
# 6. SUMMARY STATISTICS
# ============================================================================

log_msg("ANCESTRAL KARYOTYPE SUMMARY:")

for (i in seq_len(nrow(ancestral_karyotypes))) {
  row <- ancestral_karyotypes[i, ]
  log_msg(paste("  Node:", row$ancestral_node))
  log_msg(paste("    Inferred 2n:", row$inferred_2n,
                "(n =", row$n_linkage_groups, "pairs)"))
  log_msg(paste("    Species support:", row$n_species_supporting))
  log_msg(paste("    Mean block size:", row$avg_block_size_kb, "kb"))
  if (row$notes != "") {
    log_msg(paste("    Notes:", row$notes))
  }
}

# ============================================================================
# 7. COMPLETION
# ============================================================================

log_msg("=== PHASE 3.6 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 3.6 complete. Check log at:", LOG_FILE, "\n")
