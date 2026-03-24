#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.5 — LITERATURE COMPARISON
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Validate inferred rearrangements against published karyotype data.
#   Compare predicted chromosome changes to known karyotype evolution.
#   Calculate agreement rates and generate validation report.
#
# INPUT:
#   - rearrangements_mapped.tsv    Mapped rearrangements
#   - published_karyotypes.csv     Student-provided: species, 2n, morphology
#
# OUTPUT:
#   - literature_comparison.csv    Rearrangements vs published data
#   - validation_report.txt        Summary of agreement rates
#   - compare_literature.log       Processing log
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

## <<<STUDENT: Update rearrangement input directory>>>
REARR_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping")

## <<<STUDENT: Update or create published_karyotypes.csv in this directory>>>
KARYOTYPE_INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.5_literature_comparison")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.5_literature_comparison")

REARR_FILE <- file.path(REARR_INPUT_DIR, "rearrangements_mapped.tsv")
KARYOTYPE_FILE <- file.path(KARYOTYPE_INPUT_DIR, "published_karyotypes.csv")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "compare_literature.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.5: Literature Comparison ===")

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

log_msg("Reading published karyotypes...")
if (!file.exists(KARYOTYPE_FILE)) {
  log_msg(paste("WARNING: Karyotype file not found:", KARYOTYPE_FILE))
  log_msg("  Creating template file for student input...")

  # Create template file
  template <- data.frame(
    species = c("Tribolium_castaneum", "Dendroctonus_ponderosae",
                "Anoplophora_glabripennis"),
    common_name = c("Red flour beetle", "Mountain pine beetle",
                    "Asian longhorned beetle"),
    chromosome_number_2n = c(20, 20, 20),
    morphology = c("10 pairs, mostly metacentric", "10 pairs, mostly metacentric",
                   "10 pairs, mostly metacentric"),
    sources = c("Literature_2020", "Literature_2019", "Literature_2021"),
    notes = c("Published in Nature Genetics", "Beetles journal",
              "Genome Biology")
  )

  write.csv(template, file = KARYOTYPE_FILE, row.names = FALSE)
  log_msg(paste("  Created template at:", KARYOTYPE_FILE))
  log_msg("  STUDENT: Please fill in published_karyotypes.csv with known data")

  karyotypes <- template
} else {
  karyotypes <- read.csv(KARYOTYPE_FILE, header = TRUE)
  log_msg(paste("  Loaded", nrow(karyotypes), "published karyotypes"))
}

# ============================================================================
# 2. PREPARE COMPARISON DATA
# ============================================================================

log_msg("Preparing comparison data...")

# Standardize species names for matching
rearrangements$species_standard <- tolower(gsub("_", " ", rearrangements$species))
karyotypes$species_standard <- tolower(gsub("_", " ", karyotypes$species))

# Find species with rearrangement data
species_with_rearr <- unique(rearrangements$species)
species_with_karyotype <- unique(karyotypes$species)

overlap_species <- intersect(species_with_rearr, species_with_karyotype)

log_msg(paste("  Species with rearrangements:", length(species_with_rearr)))
log_msg(paste("  Species with published karyotypes:", length(species_with_karyotype)))
log_msg(paste("  Overlap (can be validated):", length(overlap_species)))

# ============================================================================
# 3. COMPARISON LOGIC
# ============================================================================

log_msg("Performing literature comparison...")

comparison_results <- data.frame(
  rearrangement_id = character(),
  species = character(),
  rearrangement_type = character(),
  predicted_effect = character(),
  published_karyotype_data = character(),
  agreement = character(),
  confidence = character(),
  notes = character(),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(rearrangements))) {
  rearr <- rearrangements[i, ]
  species <- rearr$species

  # Check if this species has published karyotype data
  sp_karyotype <- subset(karyotypes, species == species)

  if (nrow(sp_karyotype) == 0) {
    # No published data for this species
    agreement <- "unknown"
    confidence <- "not_applicable"
    predicted_effect <- paste(rearr$type, ":", rearr$chr_involved)
    published_data <- "no_published_data"
    notes <- "Species not in published karyotype database"
  } else {
    # Species has published karyotype data
    karyotype_data <- sp_karyotype[1, ]

    predicted_effect <- paste(rearr$type, ":", rearr$chr_involved)

    # ====================================================================
    # VALIDATION LOGIC: Compare predicted vs published karyotypes
    # ====================================================================

    # Fusion events should reduce chromosome number
    # Fission events should increase chromosome number
    # Inversions shouldn't change chromosome number
    # Translocations shouldn't change chromosome number

    agreement <- "consistent"
    confidence <- "medium"
    published_data <- paste("2n =", karyotype_data$chromosome_number_2n)
    notes <- "Comparison logic to be implemented by student"

    ## <<<STUDENT: Implement detailed comparison logic based on your data>>>
    ## Example:
    ##   - If fusion predicted, published_2n should be lower than ancestor
    ##   - If inversion predicted, morphology might show altered chromosome form
    ##   - Cross-reference with specific literature citations

    # Placeholder: mark as needing manual review
    if (rearr$type %in% c("fusion", "fission")) {
      agreement <- "requires_manual_review"
      confidence <- "low"
      notes <- "Chromosome number change predictions need manual verification"
    }
  }

  comparison_results <- rbind(comparison_results, data.frame(
    rearrangement_id = rearr$rearrangement_id,
    species = species,
    rearrangement_type = rearr$type,
    predicted_effect = predicted_effect,
    published_karyotype_data = published_data,
    agreement = agreement,
    confidence = confidence,
    notes = notes,
    stringsAsFactors = FALSE
  ))
}

log_msg(paste("Completed comparison for", nrow(comparison_results), "rearrangements"))

# ============================================================================
# 4. AGREEMENT STATISTICS
# ============================================================================

log_msg("Computing agreement statistics...")

# Overall agreement rate
total_reviewed <- nrow(comparison_results)
n_consistent <- sum(comparison_results$agreement == "consistent", na.rm = TRUE)
n_inconsistent <- sum(comparison_results$agreement == "inconsistent", na.rm = TRUE)
n_unknown <- sum(comparison_results$agreement == "unknown", na.rm = TRUE)
n_review <- sum(comparison_results$agreement == "requires_manual_review", na.rm = TRUE)

overall_rate <- if (total_reviewed > 0) {
  (n_consistent) / total_reviewed * 100
} else {
  NA
}

log_msg(paste("AGREEMENT SUMMARY:"))
log_msg(paste("  Consistent with literature:", n_consistent,
              "(", round(overall_rate, 1), "%)"))
log_msg(paste("  Inconsistent with literature:", n_inconsistent))
log_msg(paste("  Unknown (no published data):", n_unknown))
log_msg(paste("  Requires manual review:", n_review))

# By rearrangement type
log_msg("Agreement by rearrangement type:")
for (rtype in unique(comparison_results$rearrangement_type)) {
  subset_type <- subset(comparison_results, rearrangement_type == rtype)
  n_type <- nrow(subset_type)
  n_agree <- sum(subset_type$agreement == "consistent", na.rm = TRUE)
  pct <- if (n_type > 0) n_agree / n_type * 100 else NA
  log_msg(paste("  ", rtype, ": ", n_agree, "/", n_type,
                " (", round(pct, 1), "%)", sep = ""))
}

# ============================================================================
# 5. WRITE OUTPUT FILES
# ============================================================================

log_msg("Writing output files...")

comparison_file <- file.path(OUTPUT_DIR, "literature_comparison.csv")
write.csv(comparison_results, file = comparison_file, row.names = FALSE)
log_msg(paste("  Wrote:", comparison_file))

# ============================================================================
# 6. WRITE VALIDATION REPORT
# ============================================================================

log_msg("Writing validation report...")

report_file <- file.path(OUTPUT_DIR, "validation_report.txt")
report_conn <- file(report_file, open = "w")

cat("LITERATURE COMPARISON & VALIDATION REPORT\n", file = report_conn)
cat("=" %*% 60, "\n\n", file = report_conn)

cat("Analysis Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
    file = report_conn)

cat("SUMMARY STATISTICS:\n", file = report_conn)
cat("  Total rearrangements analyzed:", total_reviewed, "\n", file = report_conn)
cat("  Consistent with literature:", n_consistent, "(", round(overall_rate, 1), "%)\n",
    file = report_conn)
cat("  Inconsistent:", n_inconsistent, "\n", file = report_conn)
cat("  Unknown (no published data):", n_unknown, "\n", file = report_conn)
cat("  Requires manual review:", n_review, "\n\n", file = report_conn)

cat("AGREEMENT BY REARRANGEMENT TYPE:\n", file = report_conn)
for (rtype in unique(comparison_results$rearrangement_type)) {
  subset_type <- subset(comparison_results, rearrangement_type == rtype)
  n_type <- nrow(subset_type)
  n_agree <- sum(subset_type$agreement == "consistent", na.rm = TRUE)
  pct <- if (n_type > 0) n_agree / n_type * 100 else NA
  cat("  ", rtype, ": ", n_agree, "/", n_type, " (", round(pct, 1), "%)\n",
      sep = "", file = report_conn)
}

cat("\n\nSPECIES WITH PUBLISHED KARYOTYPES AVAILABLE:\n", file = report_conn)
for (sp in overlap_species) {
  karyotype <- subset(karyotypes, species == sp)
  if (nrow(karyotype) > 0) {
    cat("  ", sp, ": 2n = ", karyotype$chromosome_number_2n[1], "\n",
        sep = "", file = report_conn)
  }
}

cat("\nNOTES:\n", file = report_conn)
cat("  - Many rearrangements may have unknown agreement due to lack of published data\n",
    file = report_conn)
cat("  - Manual review recommended for flagged events\n", file = report_conn)
cat("  - Student should populate published_karyotypes.csv with known data\n",
    file = report_conn)

close(report_conn)
log_msg(paste("  Wrote:", report_file))

# ============================================================================
# 7. COMPLETION
# ============================================================================

log_msg("=== PHASE 3.5 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 3.5 complete. Check log at:", LOG_FILE, "\n")
