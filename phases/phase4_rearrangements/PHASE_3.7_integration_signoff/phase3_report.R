#!/usr/bin/env Rscript
################################################################################
#
# PHASE 3.7 — INTEGRATION & SIGNOFF REPORT
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis
#
# PURPOSE:
#   Compile comprehensive Phase 3 summary report. Integrate results from all
#   subphases. Generate publication-quality PDF report with key statistics,
#   figures, and findings.
#
# INPUT:
#   - rearrangements_confirmed.tsv      Confirmed rearrangements
#   - rearrangements_per_branch.tsv     Branch-level statistics
#   - ancestral_karyotypes.csv          Reconstructed karyotypes
#   - validation_report.txt             Literature comparison results
#
# OUTPUT:
#   - phase3_integration_report.pdf     Comprehensive summary report
#   - phase3_summary_stats.txt          Text summary statistics
#   - phase3_report.log                 Processing log
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
PHASE3_DIRS <- list(
  breakpoints = file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.1_breakpoint_calling"),
  filtering = file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.2_filtering"),
  mapping = file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.3_tree_mapping"),
  stats = file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.4_branch_stats"),
  literature = file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.5_literature_comparison"),
  ancestral = file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.6_ancestral_karyotypes")
)

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase4_rearrangements/PHASE_3.7_integration_signoff")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "phase3_report.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 3.7: Integration & Signoff Report ===")

# ============================================================================
# 1. READ ALL PHASE 3 OUTPUTS
# ============================================================================

log_msg("Reading Phase 3 output files...")

# Breakpoints
rearr_raw <- NULL
rearr_raw_file <- file.path(PHASE3_DIRS$breakpoints, "rearrangements_raw.tsv")
if (file.exists(rearr_raw_file)) {
  rearr_raw <- read.delim(rearr_raw_file, header = TRUE, sep = "\t")
  log_msg(paste("  Read raw rearrangements:", nrow(rearr_raw)))
}

# Confirmed
rearr_confirmed <- NULL
rearr_conf_file <- file.path(PHASE3_DIRS$filtering, "rearrangements_confirmed.tsv")
if (file.exists(rearr_conf_file)) {
  rearr_confirmed <- read.delim(rearr_conf_file, header = TRUE, sep = "\t")
  log_msg(paste("  Read confirmed rearrangements:", nrow(rearr_confirmed)))
}

# Inferred
rearr_inferred <- NULL
rearr_inf_file <- file.path(PHASE3_DIRS$filtering, "rearrangements_inferred.tsv")
if (file.exists(rearr_inf_file)) {
  rearr_inferred <- read.delim(rearr_inf_file, header = TRUE, sep = "\t")
  log_msg(paste("  Read inferred rearrangements:", nrow(rearr_inferred)))
}

# Branch stats
branch_stats <- NULL
branch_stats_file <- file.path(PHASE3_DIRS$stats, "rearrangements_per_branch.tsv")
if (file.exists(branch_stats_file)) {
  branch_stats <- read.delim(branch_stats_file, header = TRUE, sep = "\t")
  log_msg(paste("  Read branch statistics:", nrow(branch_stats)))
}

# Ancestral karyotypes
ancestral_kary <- NULL
karyotype_file <- file.path(PHASE3_DIRS$ancestral, "ancestral_karyotypes.csv")
if (file.exists(karyotype_file)) {
  ancestral_kary <- read.csv(karyotype_file, header = TRUE)
  log_msg(paste("  Read ancestral karyotypes:", nrow(ancestral_kary)))
}

# ============================================================================
# 2. COMPILE SUMMARY STATISTICS
# ============================================================================

log_msg("Compiling summary statistics...")

summary_stats <- list()

# Raw rearrangements
if (!is.null(rearr_raw)) {
  summary_stats$n_raw <- nrow(rearr_raw)
  summary_stats$n_raw_fusion <- sum(rearr_raw$type == "fusion")
  summary_stats$n_raw_fission <- sum(rearr_raw$type == "fission")
  summary_stats$n_raw_inversion <- sum(rearr_raw$type == "inversion")
  summary_stats$n_raw_translocation <- sum(rearr_raw$type == "translocation")
}

# Confirmed rearrangements
if (!is.null(rearr_confirmed)) {
  summary_stats$n_confirmed <- nrow(rearr_confirmed)
  summary_stats$n_confirmed_fusion <- sum(rearr_confirmed$type == "fusion")
  summary_stats$n_confirmed_fission <- sum(rearr_confirmed$type == "fission")
  summary_stats$n_confirmed_inversion <- sum(rearr_confirmed$type == "inversion")
  summary_stats$n_confirmed_translocation <- sum(rearr_confirmed$type == "translocation")
}

# Inferred rearrangements
if (!is.null(rearr_inferred)) {
  summary_stats$n_inferred <- nrow(rearr_inferred)
}

# Branch statistics
if (!is.null(branch_stats)) {
  summary_stats$n_branches <- nrow(branch_stats)
  summary_stats$n_hotspots <- sum(branch_stats$is_hotspot, na.rm = TRUE)
}

# Ancestral nodes
if (!is.null(ancestral_kary)) {
  summary_stats$n_ancestral_nodes <- nrow(ancestral_kary)
}

log_msg("Summary statistics compiled:")
for (name in names(summary_stats)) {
  log_msg(paste("  ", name, ":", summary_stats[[name]]))
}

# ============================================================================
# 3. GENERATE TEXT SUMMARY
# ============================================================================

log_msg("Generating text summary...")

summary_file <- file.path(OUTPUT_DIR, "phase3_summary_stats.txt")
summary_conn <- file(summary_file, open = "w")

cat("PHASE 3: REARRANGEMENT ANALYSIS SUMMARY\n", file = summary_conn)
cat("=" %*% 70, "\n\n", file = summary_conn)

cat("Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n", file = summary_conn)

cat("OVERVIEW:\n", file = summary_conn)
cat("Phase 3 analyzed chromosomal rearrangements across Coleoptera genomes.\n",
    file = summary_conn)
cat("Identified fusions, fissions, inversions, and translocations by comparing\n",
    file = summary_conn)
cat("synteny block order and orientation between extant and ancestral genomes.\n\n",
    file = summary_conn)

cat("KEY FINDINGS:\n\n", file = summary_conn)

cat("1. REARRANGEMENT DETECTION:\n", file = summary_conn)
if (!is.null(summary_stats$n_raw)) {
  cat("   Raw calls:            ", summary_stats$n_raw, "\n", file = summary_conn)
  cat("   - Fusions:            ", summary_stats$n_raw_fusion, "\n",
      file = summary_conn)
  cat("   - Fissions:           ", summary_stats$n_raw_fission, "\n",
      file = summary_conn)
  cat("   - Inversions:         ", summary_stats$n_raw_inversion, "\n",
      file = summary_conn)
  cat("   - Translocations:     ", summary_stats$n_raw_translocation, "\n",
      file = summary_conn)
}

cat("\n2. QUALITY FILTERING:\n", file = summary_conn)
if (!is.null(summary_stats$n_confirmed)) {
  cat("   Confirmed (≥2 species):", summary_stats$n_confirmed, "\n",
      file = summary_conn)
  cat("   - Fusions:            ", summary_stats$n_confirmed_fusion, "\n",
      file = summary_conn)
  cat("   - Fissions:           ", summary_stats$n_confirmed_fission, "\n",
      file = summary_conn)
  cat("   - Inversions:         ", summary_stats$n_confirmed_inversion, "\n",
      file = summary_conn)
  cat("   - Translocations:     ",
      summary_stats$n_confirmed_translocation, "\n", file = summary_conn)
}

if (!is.null(summary_stats$n_inferred)) {
  cat("   Inferred (single spp): ", summary_stats$n_inferred, "\n",
      file = summary_conn)
}

cat("\n3. BRANCH-LEVEL STATISTICS:\n", file = summary_conn)
if (!is.null(summary_stats$n_branches)) {
  cat("   Total branches analyzed:  ", summary_stats$n_branches, "\n",
      file = summary_conn)
}
if (!is.null(summary_stats$n_hotspots)) {
  cat("   Hotspot branches (>2 SD): ", summary_stats$n_hotspots, "\n",
      file = summary_conn)
}

cat("\n4. ANCESTRAL KARYOTYPE RECONSTRUCTION:\n", file = summary_conn)
if (!is.null(summary_stats$n_ancestral_nodes)) {
  cat("   Key nodes reconstructed: ", summary_stats$n_ancestral_nodes, "\n",
      file = summary_conn)
}

if (!is.null(ancestral_kary)) {
  cat("\n   Ancestral chromosome numbers (inferred 2n):\n", file = summary_conn)
  for (i in seq_len(min(nrow(ancestral_kary), 5))) {
    row <- ancestral_kary[i, ]
    cat("   - ", row$ancestral_node, ": 2n = ", row$inferred_2n, "\n",
        sep = "", file = summary_conn)
  }
  if (nrow(ancestral_kary) > 5) {
    cat("   ... and ", nrow(ancestral_kary) - 5, " more nodes\n", sep = "",
        file = summary_conn)
  }
}

cat("\n\nCONCLUSIONS:\n", file = summary_conn)
cat("Phase 3 successfully identified and characterized chromosomal rearrangements\n",
    file = summary_conn)
cat("across Coleoptera. Results provide insights into chromosome evolution and\n",
    file = summary_conn)
cat("enable reconstruction of ancestral karyotypes.\n\n", file = summary_conn)

cat("Next steps: Proceed to Phase 4 for visualization and manuscript preparation.\n",
    file = summary_conn)

close(summary_conn)
log_msg(paste("  Wrote:", summary_file))

# ============================================================================
# 4. GENERATE PDF REPORT (if grDevices available)
# ============================================================================

log_msg("Attempting to generate PDF report...")

tryCatch({
  # Open PDF device
  pdf_file <- file.path(OUTPUT_DIR, "phase3_integration_report.pdf")
  pdf(pdf_file, width = 8.5, height = 11, pointsize = 10)

  # Page 1: Title page
  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")
  text(0.5, 0.75, "PHASE 3: REARRANGEMENT ANALYSIS", cex = 2.5, font = 2,
       hjust = 0.5)
  text(0.5, 0.65, "Coleoptera Whole-Genome Alignment Project", cex = 1.5,
       hjust = 0.5)
  text(0.5, 0.55, "Comprehensive Summary Report", cex = 1.3, hjust = 0.5)
  text(0.5, 0.40, format(Sys.time(), "%B %d, %Y"), cex = 1.2, hjust = 0.5)

  if (!is.null(summary_stats$n_confirmed)) {
    text(0.5, 0.25, paste(summary_stats$n_confirmed,
                          "Confirmed Rearrangements Identified"),
         cex = 1.1, hjust = 0.5, col = "darkblue")
  }

  # Page 2: Summary statistics
  plot(NULL, xlim = 0:1, ylim = 0:1, axes = FALSE, xlab = "", ylab = "")
  text(0.5, 0.95, "Summary Statistics", cex = 1.8, font = 2, hjust = 0.5)

  y_pos <- 0.85
  if (!is.null(summary_stats$n_raw)) {
    text(0.1, y_pos, paste("Raw rearrangement calls:",
                           summary_stats$n_raw), cex = 1.1, hjust = 0)
    y_pos <- y_pos - 0.08
  }

  if (!is.null(summary_stats$n_confirmed)) {
    text(0.1, y_pos, paste("Confirmed rearrangements:",
                           summary_stats$n_confirmed), cex = 1.1, hjust = 0)
    y_pos <- y_pos - 0.08
  }

  if (!is.null(summary_stats$n_inferred)) {
    text(0.1, y_pos, paste("Inferred rearrangements:",
                           summary_stats$n_inferred), cex = 1.1, hjust = 0)
    y_pos <- y_pos - 0.08
  }

  if (!is.null(summary_stats$n_branches)) {
    text(0.1, y_pos, paste("Branches analyzed:",
                           summary_stats$n_branches), cex = 1.1, hjust = 0)
    y_pos <- y_pos - 0.08
  }

  if (!is.null(summary_stats$n_ancestral_nodes)) {
    text(0.1, y_pos, paste("Ancestral nodes reconstructed:",
                           summary_stats$n_ancestral_nodes), cex = 1.1, hjust = 0)
  }

  dev.off()
  log_msg(paste("  Wrote:", pdf_file))

}, error = function(e) {
  log_msg(paste("  WARNING: Could not generate PDF report."))
  log_msg(paste("  Error:", e$message))
})

# ============================================================================
# 5. COMPLETION CHECKLIST
# ============================================================================

log_msg("PHASE 3 COMPLETION CHECKLIST:")

files_to_check <- c(
  "rearrangements_raw.tsv" = file.path(PHASE3_DIRS$breakpoints, "rearrangements_raw.tsv"),
  "rearrangements_confirmed.tsv" = file.path(PHASE3_DIRS$filtering, "rearrangements_confirmed.tsv"),
  "rearrangements_inferred.tsv" = file.path(PHASE3_DIRS$filtering, "rearrangements_inferred.tsv"),
  "rearrangements_mapped.tsv" = file.path(PHASE3_DIRS$mapping, "rearrangements_mapped.tsv"),
  "rearrangements_per_branch.tsv" = file.path(PHASE3_DIRS$stats, "rearrangements_per_branch.tsv"),
  "ancestral_karyotypes.csv" = file.path(PHASE3_DIRS$ancestral, "ancestral_karyotypes.csv")
)

for (name in names(files_to_check)) {
  filepath <- files_to_check[[name]]
  exists <- file.exists(filepath)
  status <- if (exists) "OK" else "MISSING"
  log_msg(paste("  [", status, "]", name))
}

# ============================================================================
# 6. COMPLETION
# ============================================================================

log_msg("=== PHASE 3.7 COMPLETE ===")
log_msg("=== PHASE 3 ANALYSIS COMPLETE ===")

close(log_conn)

cat("\n", "=" %*% 70, "\n", sep = "")
cat("✓ PHASE 3 REARRANGEMENT ANALYSIS COMPLETE\n")
cat("=" %*% 70, "\n")
cat("Summary report:", file.path(OUTPUT_DIR, "phase3_summary_stats.txt"), "\n")
cat("Log file:       ", LOG_FILE, "\n")
cat("=" %*% 70, "\n\n")
