#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.2 — REARRANGEMENT FILTERING
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Apply quality filters to raw rearrangement calls to distinguish:
#   - CONFIRMED: Rearrangements supported by ≥2 independent species
#   - INFERRED:  Single-species, inferred by synteny & parsimony
#   - ARTIFACT:  Small blocks, low identity, likely assembly errors
#
# INPUT:
#   - rearrangements_raw.tsv   Raw rearrangement calls from Phase 3.1
#
# OUTPUT:
#   - rearrangements_confirmed.tsv   High-confidence events
#   - rearrangements_inferred.tsv    Parsimony-supported (single species)
#   - rearrangements_artifact.tsv    Filtered-out artifacts
#   - filtering_criteria.txt         Documentation of thresholds
#   - filter_rearrangements.log      Processing log
#
# AUTHOR: SCARAB Team
# DATE: 2026-03-21
#
################################################################################

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 10)

# ============================================================================
# 0. CONFIGURATION & THRESHOLDS

## <<<STUDENT: Set PROJECT_ROOT to your SCARAB project directory>>>
PROJECT_ROOT <- Sys.getenv("SCARAB_ROOT",
                           unset = normalizePath(file.path(dirname(sys.frame(1)$ofile), "..", "..", ".."),
                                                  mustWork = FALSE))
if (!dir.exists(PROJECT_ROOT)) {
  stop("PROJECT_ROOT not found: ", PROJECT_ROOT,
       "\nSet SCARAB_ROOT environment variable or run from within the project")
}
# ============================================================================

## <<<STUDENT: Adjust filtering thresholds as needed for your dataset>>>

# Minimum supporting blocks to call a rearrangement
MIN_SUPPORTING_BLOCKS <- 2

# Minimum number of independent species supporting a confirmed rearrangement
MIN_INDEPENDENT_SPECIES <- 2

# Maximum confidence interval (in bp) - breakpoints beyond this are unreliable
MAX_CONFIDENCE_INTERVAL <- 20000

# Minimum synteny block size to consider (bp)
MIN_BLOCK_SIZE <- 1000

# ============================================================================
# 1. PATHS & SETUP
# ============================================================================

## <<<STUDENT: Update input directory>>>
INPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.1_breakpoint_calling")

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.2_filtering")

INPUT_FILE <- file.path(INPUT_DIR, "rearrangements_raw.tsv")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "filter_rearrangements.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.2: Rearrangement Filtering ===")

# ============================================================================
# 2. READ DATA
# ============================================================================

log_msg("Reading raw rearrangements...")
if (!file.exists(INPUT_FILE)) {
  log_msg(paste("ERROR: Input file not found:", INPUT_FILE))
  stop("Input file missing")
}

rearrangements <- read.delim(INPUT_FILE, header = TRUE, sep = "\t")
log_msg(paste("  Loaded", nrow(rearrangements), "raw rearrangements"))

initial_count <- nrow(rearrangements)

# ============================================================================
# 3. FILTERING STEP 1: Quality of breakpoint calls
# ============================================================================

log_msg("Filter 1: Quality of breakpoint calls...")

# Check for missing/invalid data
rearrangements$confidence_interval <- rearrangements$confidence_upper -
                                      rearrangements$confidence_lower

# Remove rearrangements with missing critical columns
before_filter <- nrow(rearrangements)
rearrangements <- rearrangements[!is.na(rearrangements$breakpoint_1) &
                                 !is.na(rearrangements$breakpoint_2) &
                                 !is.na(rearrangements$supporting_blocks), ]
after_filter <- nrow(rearrangements)

log_msg(paste("  Removed", before_filter - after_filter,
              "rearrangements with missing critical data"))

# Remove rearrangements with unreliable breakpoints (wide confidence intervals)
before_filter <- nrow(rearrangements)
rearrangements <- rearrangements[rearrangements$confidence_interval <= MAX_CONFIDENCE_INTERVAL, ]
after_filter <- nrow(rearrangements)

log_msg(paste("  Removed", before_filter - after_filter,
              "rearrangements with confidence_interval >", MAX_CONFIDENCE_INTERVAL, "bp"))

# Remove rearrangements with too few supporting blocks
before_filter <- nrow(rearrangements)
rearrangements <- rearrangements[rearrangements$supporting_blocks >= MIN_SUPPORTING_BLOCKS, ]
after_filter <- nrow(rearrangements)

log_msg(paste("  Removed", before_filter - after_filter,
              "rearrangements with < ", MIN_SUPPORTING_BLOCKS, " supporting blocks"))

# ============================================================================
# 4. FILTERING STEP 2: Independent species support
# ============================================================================

log_msg("Filter 2: Independent species support...")

# Count how many species support each rearrangement type at each location
rearrangements$event_key <- paste(rearrangements$type,
                                  rearrangements$ancestral_node,
                                  rearrangements$chr_involved,
                                  sep = "|")

species_support <- tapply(rearrangements$species,
                         rearrangements$event_key,
                         function(x) length(unique(x)))

rearrangements$species_support_count <- species_support[rearrangements$event_key]

# Classify as confirmed vs inferred
rearrangements$support_status <- ifelse(
  rearrangements$species_support_count >= MIN_INDEPENDENT_SPECIES,
  "confirmed",
  "inferred"
)

log_msg(paste("  Confirmed (≥", MIN_INDEPENDENT_SPECIES, " species):",
              sum(rearrangements$support_status == "confirmed")))
log_msg(paste("  Inferred (single species, parsimony):",
              sum(rearrangements$support_status == "inferred")))

# ============================================================================
# 5. FILTERING STEP 3: Artifact detection
# ============================================================================

log_msg("Filter 3: Artifact detection...")

# Flag potential assembly artifacts:
# - Very small rearrangements (< 1 kb)
# - Single block supporting event
# - Isolated inversions on small regions

rearrangements$is_artifact <- FALSE

# Small rearrangements
before_artifact <- sum(rearrangements$is_artifact)
rearrangement_size <- rearrangements$breakpoint_2 - rearrangements$breakpoint_1
rearrangements$is_artifact[rearrangement_size < MIN_BLOCK_SIZE] <- TRUE
after_artifact <- sum(rearrangements$is_artifact)

log_msg(paste("  Marked", after_artifact - before_artifact,
              "as potential artifacts (size <", MIN_BLOCK_SIZE, "bp)"))

# Single block supporting a breakpoint (high false positive rate)
before_artifact <- sum(rearrangements$is_artifact)
rearrangements$is_artifact[rearrangements$supporting_blocks == 1] <- TRUE
after_artifact <- sum(rearrangements$is_artifact)

log_msg(paste("  Marked", after_artifact - before_artifact,
              "as potential artifacts (single supporting block)"))

# ============================================================================
# 6. SPLIT OUTPUT INTO THREE CATEGORIES
# ============================================================================

log_msg("Splitting rearrangements into categories...")

confirmed <- subset(rearrangements,
                   support_status == "confirmed" &
                   is_artifact == FALSE)

inferred <- subset(rearrangements,
                  support_status == "inferred" &
                  is_artifact == FALSE)

artifact <- subset(rearrangements,
                  is_artifact == TRUE)

log_msg(paste("FINAL COUNTS:"))
log_msg(paste("  Confirmed:", nrow(confirmed)))
log_msg(paste("  Inferred:", nrow(inferred)))
log_msg(paste("  Artifacts:", nrow(artifact)))
log_msg(paste("  Total (all categories):", nrow(confirmed) + nrow(inferred) + nrow(artifact)))
log_msg(paste("  Filtered out (non-artifacts):", initial_count - nrow(confirmed) - nrow(inferred) - nrow(artifact)))

# ============================================================================
# 7. WRITE OUTPUT FILES
# ============================================================================

log_msg("Writing output files...")

# Drop working columns before output
drop_cols <- c("event_key", "species_support_count", "support_status",
               "is_artifact", "confidence_interval")

confirmed_out <- confirmed[, setdiff(colnames(confirmed), drop_cols)]
inferred_out <- inferred[, setdiff(colnames(inferred), drop_cols)]
artifact_out <- artifact[, setdiff(colnames(artifact), drop_cols)]

confirmed_file <- file.path(OUTPUT_DIR, "rearrangements_confirmed.tsv")
write.table(confirmed_out, file = confirmed_file, sep = "\t",
            row.names = FALSE, quote = FALSE)
log_msg(paste("  Wrote:", confirmed_file))

inferred_file <- file.path(OUTPUT_DIR, "rearrangements_inferred.tsv")
write.table(inferred_out, file = inferred_file, sep = "\t",
            row.names = FALSE, quote = FALSE)
log_msg(paste("  Wrote:", inferred_file))

artifact_file <- file.path(OUTPUT_DIR, "rearrangements_artifact.tsv")
write.table(artifact_out, file = artifact_file, sep = "\t",
            row.names = FALSE, quote = FALSE)
log_msg(paste("  Wrote:", artifact_file))

# ============================================================================
# 8. WRITE FILTERING CRITERIA DOCUMENTATION
# ============================================================================

log_msg("Writing filtering criteria documentation...")

criteria_file <- file.path(OUTPUT_DIR, "filtering_criteria.txt")
criteria_conn <- file(criteria_file, open = "w")

cat("REARRANGEMENT FILTERING CRITERIA\n", file = criteria_conn)
cat("=" %*% 60, "\n\n", file = criteria_conn)

cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n", file = criteria_conn)

cat("THRESHOLDS USED:\n", file = criteria_conn)
cat("  MIN_SUPPORTING_BLOCKS:", MIN_SUPPORTING_BLOCKS, "(minimum synteny blocks per rearrangement)\n", file = criteria_conn)
cat("  MIN_INDEPENDENT_SPECIES:", MIN_INDEPENDENT_SPECIES, "(for confirmed classification)\n", file = criteria_conn)
cat("  MAX_CONFIDENCE_INTERVAL:", MAX_CONFIDENCE_INTERVAL, "bp (maximum allowed)\n", file = criteria_conn)
cat("  MIN_BLOCK_SIZE:", MIN_BLOCK_SIZE, "bp (minimum rearrangement size)\n\n", file = criteria_conn)

cat("CLASSIFICATION RULES:\n", file = criteria_conn)
cat("  CONFIRMED: Rearrangements meeting quality filters AND supported by >=", MIN_INDEPENDENT_SPECIES, "species\n", file = criteria_conn)
cat("  INFERRED:  Rearrangements meeting quality filters BUT single-species (parsimony argument)\n", file = criteria_conn)
cat("  ARTIFACT:  Rearrangements failing quality filters OR flagged as likely assembly errors\n\n", file = criteria_conn)

cat("ARTIFACT FLAGS:\n", file = criteria_conn)
cat("  - Rearrangement size < ", MIN_BLOCK_SIZE, " bp\n", file = criteria_conn)
cat("  - Single synteny block supporting the call\n\n", file = criteria_conn)

cat("SUMMARY STATISTICS:\n", file = criteria_conn)
cat("  Initial raw calls:", initial_count, "\n", file = criteria_conn)
cat("  After quality filters:\n", file = criteria_conn)
cat("    - Confirmed:", nrow(confirmed), "\n", file = criteria_conn)
cat("    - Inferred:", nrow(inferred), "\n", file = criteria_conn)
cat("    - Artifacts:", nrow(artifact), "\n", file = criteria_conn)

close(criteria_conn)
log_msg(paste("  Wrote:", criteria_file))

# ============================================================================
# 9. COMPLETION
# ============================================================================

log_msg("=== PHASE 3.2 COMPLETE ===")
close(log_conn)

cat("\n✓ Phase 3.2 complete. Check log at:", LOG_FILE, "\n")
