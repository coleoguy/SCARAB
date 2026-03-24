#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.3 — MAPPING REARRANGEMENTS TO PHYLOGENETIC TREE
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Assign each confirmed rearrangement to a specific branch on the phylogenetic
#   tree using parsimony. Identify the ancestral → derived node for each event.
#   Flag potential reversions.
#
# INPUT:
#   - rearrangements_confirmed.tsv   High-confidence rearrangements
#   - constraint_tree.nwk            Phylogenetic tree with branch lengths
#
# OUTPUT:
#   - rearrangements_mapped.tsv      Rearrangements mapped to tree branches
#   - map_to_tree.log                Processing log
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
INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.2_filtering")

## <<<STUDENT: Update tree input directory>>>
TREE_DIR <- file.path(PROJECT_ROOT, "phases/phase3_alignment_synteny")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping")

INPUT_FILE <- file.path(INPUT_DIR, "rearrangements_confirmed.tsv")
TREE_FILE  <- file.path(TREE_DIR, "constraint_tree.nwk")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "map_to_tree.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.3: Mapping Rearrangements to Tree ===")

# ============================================================================
# 1. READ DATA
# ============================================================================

log_msg("Reading confirmed rearrangements...")
if (!file.exists(INPUT_FILE)) {
  log_msg(paste("ERROR: Input file not found:", INPUT_FILE))
  stop("Input file missing")
}

rearrangements <- read.delim(INPUT_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(rearrangements), "confirmed rearrangements"))

log_msg("Reading phylogenetic tree...")
if (!file.exists(TREE_FILE)) {
  log_msg(paste("ERROR: Tree file not found:", TREE_FILE))
  stop("Tree file missing")
}

tree_str <- readLines(TREE_FILE)
log_msg(paste("  Tree file loaded"))

# ============================================================================
# 2. PARSE TREE STRUCTURE
# ============================================================================

log_msg("Parsing tree structure...")

## <<<STUDENT: Uncomment below if using ape package; otherwise adapt to your tree format>>>
# library(ape)
# tree <- read.tree(text = tree_str)
# log_msg(paste("  Tips (species):", length(tree$tip.label)))
# log_msg(paste("  Internal nodes:", tree$Nnode))

# For this template, we'll work with node/species mappings
# Extract species list
unique_species <- unique(c(rearrangements$species, rearrangements$ancestral_node))
log_msg(paste("  Unique species/nodes in rearrangements:",
              length(unique_species)))

# ============================================================================
# 3. INITIALIZE MAPPING RESULTS DATAFRAME
# ============================================================================

log_msg("Initializing rearrangement mapping...")

rearrangements$ancestral_node_branch <- NA_character_
rearrangements$derived_node_branch <- NA_character_
rearrangements$branch_id <- NA_character_
rearrangements$is_reversion <- FALSE
rearrangements$parsimony_score <- NA_numeric_
rearrangements$confidence_mapping <- "low"

# ============================================================================
# 4. ASSIGN REARRANGEMENTS TO BRANCHES
# ============================================================================

log_msg("Assigning rearrangements to branches (parsimony)...")

for (i in seq_len(nrow(rearrangements))) {
  rearr <- rearrangements[i, ]

  rearr_type <- rearr$type
  species <- rearr$species
  ancestral_node <- rearr$ancestral_node

  log_msg(paste("Processing REARR_", i, ": ", rearr_type,
                " in ", species, sep = ""))

  # ========================================================================
  # Assign branch: ancestral_node → species
  # ========================================================================

  branch_id <- paste(ancestral_node, "->", species, sep = "")
  rearrangements$branch_id[i] <- branch_id
  rearrangements$ancestral_node_branch[i] <- ancestral_node
  rearrangements$derived_node_branch[i] <- species

  # ========================================================================
  # Parsimony score: count lineages that exhibit similar rearrangements
  # ========================================================================

  # Events supported by multiple species in same clade likely predate divergence
  related_events <- subset(rearrangements,
                          rearr_type == rearrangements$type[i] &
                          ancestral_node == rearrangements$ancestral_node[i])

  parsimony_score <- nrow(related_events)
  rearrangements$parsimony_score[i] <- parsimony_score

  # High parsimony = event likely occurred once at common ancestor
  if (parsimony_score >= 2) {
    rearrangements$confidence_mapping[i] <- "high"
  } else if (parsimony_score == 1) {
    rearrangements$confidence_mapping[i] <- "medium"
  }

  # ========================================================================
  # Reversion detection: same type of rearrangement in lineage descendants
  # ========================================================================

  # Check if any lineage shows reversal of this rearrangement
  # E.g., fusion in ancestor, fission in descendant = potential reversion

  potential_reversion <- FALSE

  if (rearr_type == "fusion") {
    # Look for fission events that might reverse fusion
    fission_events <- subset(rearrangements,
                            type == "fission" &
                            species != rearrangements$species[i])
    if (nrow(fission_events) > 0) {
      potential_reversion <- TRUE
    }
  } else if (rearr_type == "inversion") {
    # Look for second inversion on same chromosome
    inv_events <- subset(rearrangements,
                        type == "inversion" &
                        chr_involved == rearrangements$chr_involved[i] &
                        species != rearrangements$species[i])
    if (nrow(inv_events) > 0) {
      potential_reversion <- TRUE
    }
  }

  rearrangements$is_reversion[i] <- potential_reversion
}

log_msg(paste("Assigned", nrow(rearrangements), "rearrangements to branches"))

# ============================================================================
# 5. SUMMARY STATISTICS
# ============================================================================

log_msg("Summary of branch assignments:")
log_msg(paste("  High confidence mappings:",
              sum(rearrangements$confidence_mapping == "high")))
log_msg(paste("  Medium confidence mappings:",
              sum(rearrangements$confidence_mapping == "medium")))
log_msg(paste("  Low confidence mappings:",
              sum(rearrangements$confidence_mapping == "low")))
log_msg(paste("  Potential reversions flagged:",
              sum(rearrangements$is_reversion)))

# ============================================================================
# 6. WRITE OUTPUT
# ============================================================================

log_msg("Writing output files...")

output_file <- file.path(OUTPUT_DIR, "rearrangements_mapped.tsv")
write.table(rearrangements, file = output_file, sep = "\t",
            row.names = FALSE, quote = FALSE)
log_msg(paste("  Wrote:", output_file))

# ============================================================================
# 7. COMPLETION
# ============================================================================

log_msg("=== PHASE 3.3 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 3.3 complete. Check log at:", LOG_FILE, "\n")
