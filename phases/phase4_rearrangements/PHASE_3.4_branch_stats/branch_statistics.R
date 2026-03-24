#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.4 — BRANCH STATISTICS
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Compute per-branch rearrangement counts and rates. Normalize by branch
#   length (Myr). Identify hotspot branches (>2 SD above mean rate).
#   Generate summary statistics and visualization figures.
#
# INPUT:
#   - rearrangements_mapped.tsv    Mapped rearrangements with branch assignments
#   - constraint_tree.nwk          Phylogenetic tree with branch lengths
#
# OUTPUT:
#   - rearrangements_per_branch.tsv   Per-branch counts and rates
#   - branch_stats.csv                Clade-level summaries
#   - branch_statistics.log           Processing log
#   - branch_rate_histogram.pdf       Visualization (requires ggplot2)
#   - tree_with_rates.pdf             Tree colored by branch rates
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
REARR_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping")
TREE_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase3_alignment_synteny")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.4_branch_stats")

REARR_FILE <- file.path(REARR_INPUT_DIR, "rearrangements_mapped.tsv")
TREE_FILE <- file.path(TREE_INPUT_DIR, "constraint_tree.nwk")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "branch_statistics.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.4: Branch Statistics ===")

# ============================================================================
# 1. READ DATA
# ============================================================================

log_msg("Reading mapped rearrangements...")
if (!file.exists(REARR_FILE)) {
  log_msg(paste("ERROR: Rearrangement file not found:", REARR_FILE))
  stop("Rearrangement file missing")
}

rearrangements <- read.delim(REARR_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(rearrangements), "mapped rearrangements"))

log_msg("Reading phylogenetic tree...")
if (!file.exists(TREE_FILE)) {
  log_msg(paste("ERROR: Tree file not found:", TREE_FILE))
  stop("Tree file missing")
}

tree_str <- readLines(TREE_FILE)
log_msg("  Tree file loaded")

## <<<STUDENT: Uncomment below if using ape; adapt if using different tree format>>>
# library(ape)
# tree <- read.tree(text = tree_str)

# For now, we'll work with branch data derived from rearrangement assignments
# In a full implementation, extract branch lengths from the tree object

# ============================================================================
# 2. COUNT REARRANGEMENTS PER BRANCH
# ============================================================================

log_msg("Computing per-branch rearrangement counts...")

# Initialize data frame for branch statistics
branch_stats_detail <- data.frame(
  branch_id = character(),
  ancestral_node = character(),
  derived_node = character(),
  fusions = numeric(),
  fissions = numeric(),
  inversions = numeric(),
  translocations = numeric(),
  total_rearrangements = numeric(),
  supporting_species = numeric(),
  branch_length_myr = numeric(),
  rearrangement_rate = numeric(),
  is_hotspot = logical(),
  stringsAsFactors = FALSE
)

# Get unique branches
unique_branches <- unique(rearrangements$branch_id)

for (branch in unique_branches) {
  branch_rearrs <- subset(rearrangements, branch_id == branch)

  if (nrow(branch_rearrs) == 0) next

  # Extract ancestral and derived nodes from first record
  anc_node <- branch_rearrs$ancestral_node_branch[1]
  der_node <- branch_rearrs$derived_node_branch[1]

  # Count by type
  n_fusion <- sum(branch_rearrs$type == "fusion")
  n_fission <- sum(branch_rearrs$type == "fission")
  n_inversion <- sum(branch_rearrs$type == "inversion")
  n_translocation <- sum(branch_rearrs$type == "translocation")
  n_total <- nrow(branch_rearrs)

  # Count supporting species (unique)
  n_species <- length(unique(branch_rearrs$species))

  # Initialize branch length (will be updated from tree if available)
  ## <<<STUDENT: If using ape tree, extract branch lengths: extract_branch_length(tree, anc_node, der_node)>>>
  branch_length_myr <- NA_numeric_

  branch_stats_detail <- rbind(branch_stats_detail, data.frame(
    branch_id = branch,
    ancestral_node = anc_node,
    derived_node = der_node,
    fusions = n_fusion,
    fissions = n_fission,
    inversions = n_inversion,
    translocations = n_translocation,
    total_rearrangements = n_total,
    supporting_species = n_species,
    branch_length_myr = branch_length_myr,
    rearrangement_rate = NA_numeric_,
    is_hotspot = NA,
    stringsAsFactors = FALSE
  ))
}

log_msg(paste("Computed statistics for", nrow(branch_stats_detail), "branches"))

# ============================================================================
# 3. CALCULATE RATES (NORMALIZED BY BRANCH LENGTH)
# ============================================================================

log_msg("Calculating rearrangement rates...")

# For branches with known length, normalize rate
# Rate = rearrangements per Myr

for (i in seq_len(nrow(branch_stats_detail))) {
  if (!is.na(branch_stats_detail$branch_length_myr[i]) &&
      branch_stats_detail$branch_length_myr[i] > 0) {
    rate <- branch_stats_detail$total_rearrangements[i] /
            branch_stats_detail$branch_length_myr[i]
    branch_stats_detail$rearrangement_rate[i] <- rate
  }
}

# ============================================================================
# 4. IDENTIFY HOTSPOT BRANCHES
# ============================================================================

log_msg("Identifying hotspot branches...")

# Hotspots: branches with rate > 2 SD above mean
valid_rates <- branch_stats_detail$rearrangement_rate[
  !is.na(branch_stats_detail$rearrangement_rate)
]

if (length(valid_rates) > 0) {
  mean_rate <- mean(valid_rates)
  sd_rate <- sd(valid_rates)
  threshold <- mean_rate + 2 * sd_rate

  branch_stats_detail$is_hotspot[!is.na(branch_stats_detail$rearrangement_rate)] <-
    branch_stats_detail$rearrangement_rate[!is.na(branch_stats_detail$rearrangement_rate)] > threshold

  n_hotspots <- sum(branch_stats_detail$is_hotspot, na.rm = TRUE)

  log_msg(paste("  Mean rate:", round(mean_rate, 4), "rearr/Myr"))
  log_msg(paste("  SD:", round(sd_rate, 4)))
  log_msg(paste("  Hotspot threshold:", round(threshold, 4), "rearr/Myr"))
  log_msg(paste("  Identified", n_hotspots, "hotspot branches"))

  if (n_hotspots > 0) {
    hotspot_branches <- branch_stats_detail$branch_id[branch_stats_detail$is_hotspot]
    for (hb in hotspot_branches) {
      hb_data <- subset(branch_stats_detail, branch_id == hb)
      log_msg(paste("    HOTSPOT:", hb, "- rate =", round(hb_data$rearrangement_rate, 4)))
    }
  }
}

# ============================================================================
# 5. CLADE-LEVEL SUMMARIES
# ============================================================================

log_msg("Computing clade-level statistics...")

## <<<STUDENT: Define clade membership based on your tree structure>>>
# Example: Adephaga vs Polyphaga suborders
# This requires parsing tree/taxonomy - adapt to your actual tree structure

clade_stats <- data.frame(
  clade = character(),
  n_branches = numeric(),
  n_rearrangements = numeric(),
  n_fusions = numeric(),
  n_fissions = numeric(),
  n_inversions = numeric(),
  n_translocations = numeric(),
  mean_rate_per_branch = numeric(),
  mean_rate_per_myr = numeric(),
  stringsAsFactors = FALSE
)

# For now, simple summary by rearrangement type
type_summary <- aggregate(total_rearrangements ~ NA,
                         data = branch_stats_detail,
                         FUN = sum)

log_msg(paste("Total branches:", nrow(branch_stats_detail)))
log_msg(paste("Total rearrangements:", sum(branch_stats_detail$total_rearrangements)))
log_msg(paste("  Fusions:", sum(branch_stats_detail$fusions)))
log_msg(paste("  Fissions:", sum(branch_stats_detail$fissions)))
log_msg(paste("  Inversions:", sum(branch_stats_detail$inversions)))
log_msg(paste("  Translocations:", sum(branch_stats_detail$translocations)))

# ============================================================================
# 6. WRITE OUTPUT FILES
# ============================================================================

log_msg("Writing output files...")

# Per-branch statistics
per_branch_file <- file.path(OUTPUT_DIR, "rearrangements_per_branch.tsv")
write.table(branch_stats_detail, file = per_branch_file, sep = "\t",
            row.names = FALSE, quote = FALSE)
log_msg(paste("  Wrote:", per_branch_file))

# Clade statistics (if computed)
if (nrow(clade_stats) > 0) {
  clade_file <- file.path(OUTPUT_DIR, "branch_stats.csv")
  write.csv(clade_stats, file = clade_file, row.names = FALSE)
  log_msg(paste("  Wrote:", clade_file))
}

# ============================================================================
# 7. GENERATE FIGURES (if ggplot2 available)
# ============================================================================

log_msg("Attempting to generate visualization figures...")

tryCatch({
  library(ggplot2)
  library(gridExtra)

  # Histogram of rearrangement rates
  valid_rate_data <- branch_stats_detail[!is.na(branch_stats_detail$rearrangement_rate), ]

  if (nrow(valid_rate_data) > 0) {
    log_msg("  Generating rate histogram...")

    p_histogram <- ggplot(valid_rate_data, aes(x = rearrangement_rate)) +
      geom_histogram(bins = 10, fill = "steelblue", alpha = 0.7) +
      geom_vline(aes(xintercept = mean(rearrangement_rate)),
                 linetype = "dashed", color = "red", size = 1) +
      labs(title = "Distribution of Rearrangement Rates Across Branches",
           x = "Rearrangements per Million Years",
           y = "Number of Branches") +
      theme_minimal() +
      theme(axis.text = element_text(size = 11),
            axis.title = element_text(size = 12),
            plot.title = element_text(size = 14, hjust = 0.5))

    hist_file <- file.path(OUTPUT_DIR, "branch_rate_histogram.pdf")
    pdf(hist_file, width = 8, height = 6)
    print(p_histogram)
    dev.off()
    log_msg(paste("  Wrote:", hist_file))
  }

}, error = function(e) {
  log_msg(paste("  WARNING: Could not generate figures. ggplot2 may not be installed."))
  log_msg(paste("  Error:", e$message))
})

# ============================================================================
# 8. COMPLETION
# ============================================================================

log_msg("=== PHASE 3.4 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 3.4 complete. Check log at:", LOG_FILE, "\n")
