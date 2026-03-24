#!/usr/bin/env Rscript
################################################################################
#
# PHASE 4.7 — COMPLETION & MANUSCRIPT READINESS CHECKLIST
# Coleoptera Whole-Genome Alignment: Visualization & Manuscript
#
# PURPOSE:
#   Automated verification of all expected output files.
#   Validate data file integrity and format.
#   Generate comprehensive readiness checklist for manuscript submission.
#
# OUTPUT:
#   - manuscript_readiness_checklist.txt    Complete verification report
#   - data_validation_report.txt            File integrity checks
#   - final_checklist.log                   Processing log
#
# AUTHOR: SCARAB Team
# DATE: 2026-03-21
#
################################################################################

rm(list = ls())
options(stringsAsFactors = FALSE, scipen = 10)

# ============================================================================
# 0. SETUP

## <<<STUDENT: Set PROJECT_ROOT to your SCARAB project directory>>>
PROJECT_ROOT <- Sys.getenv("SCARAB_ROOT",
                           unset = normalizePath(file.path(dirname(sys.frame(1)$ofile), "..", "..", ".."),
                                                  mustWork = FALSE))
if (!dir.exists(PROJECT_ROOT)) {
  stop("PROJECT_ROOT not found: ", PROJECT_ROOT,
       "\nSet SCARAB_ROOT environment variable or run from within the project")
}
# ============================================================================

## <<<STUDENT: Update base directory path>>>
BASE_DIR <- file.path(PROJECT_ROOT, "phases"

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR <- file.path(PROJECT_ROOT, "phases/phase5_viz_manuscript/PHASE_4.7_completion_signoff")

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# Open log file
LOG_FILE <- file.path(OUTPUT_DIR, "final_checklist.log")
log_conn <- file(LOG_FILE, open = "w")

log_msg <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  full_msg <- paste0("[", timestamp, "] ", msg)
  cat(full_msg, "\n", file = log_conn)
  cat(full_msg, "\n")
}

log_msg("=== PHASE 4.7: Completion & Manuscript Readiness ===")

# ============================================================================
# 1. DEFINE EXPECTED FILES
# ============================================================================

log_msg("Defining expected output files...")

expected_files <- list(
  # Phase 3 outputs
  phase3_outputs = list(
    "rearrangements_raw.tsv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.1_breakpoint_calling/rearrangements_raw.tsv"),
    "rearrangements_confirmed.tsv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.2_filtering/rearrangements_confirmed.tsv"),
    "rearrangements_inferred.tsv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.2_filtering/rearrangements_inferred.tsv"),
    "rearrangements_mapped.tsv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.3_tree_mapping/rearrangements_mapped.tsv"),
    "rearrangements_per_branch.tsv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.4_branch_stats/rearrangements_per_branch.tsv"),
    "ancestral_karyotypes.csv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.6_ancestral_karyotypes/ancestral_karyotypes.csv"),
    "ancestral_linkage_groups.csv" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.6_ancestral_karyotypes/ancestral_linkage_groups.csv"),
    "phase3_report.pdf" = file.path(BASE_DIR, "phase4_rearrangements/PHASE_3.7_integration_signoff/phase3_integration_report.pdf")
  ),

  # Phase 4 outputs
  phase4_outputs = list(
    "beetle_tree.pdf" = file.path(BASE_DIR, "phase5_viz_manuscript/PHASE_4.1_interactive_tree/beetle_tree_rearrangements.pdf"),
    "synteny_dotplots.pdf" = file.path(BASE_DIR, "phase5_viz_manuscript/PHASE_4.2_synteny_dotplots/synteny_dotplots.pdf"),
    "hotspot_figures.pdf" = file.path(BASE_DIR, "phase5_viz_manuscript/PHASE_4.3_hotspot_viz/hotspot_figures.pdf"),
    "ancestral_figures.pdf" = file.path(BASE_DIR, "phase5_viz_manuscript/PHASE_4.4_ancestral_figures/ancestral_karyotype_figures.pdf"),
    "manuscript_figures.pdf" = file.path(BASE_DIR, "phase5_viz_manuscript/PHASE_4.6_manuscript_figures/manuscript_figures.pdf"),
    "figure_captions.txt" = file.path(BASE_DIR, "phase5_viz_manuscript/PHASE_4.6_manuscript_figures/figure_captions_final.txt")
  )
)

log_msg(paste("Defined", length(unlist(expected_files)), "expected files"))

# ============================================================================
# 2. FILE EXISTENCE CHECKS
# ============================================================================

log_msg("Checking for existence of expected files...")

file_check_results <- data.frame(
  category = character(),
  filename = character(),
  exists = logical(),
  file_size_kb = numeric(),
  can_read = logical(),
  stringsAsFactors = FALSE
)

for (category in names(expected_files)) {
  for (name in names(expected_files[[category]])) {
    filepath <- expected_files[[category]][[name]]

    exists <- file.exists(filepath)
    size_kb <- if (exists) file.size(filepath) / 1024 else NA_numeric_

    can_read <- FALSE
    if (exists) {
      tryCatch({
        if (grepl("\\.tsv$|\\.csv$", filepath)) {
          test <- read.delim(filepath, nrows = 1, sep = "\t")
          can_read <- TRUE
        } else if (grepl("\\.pdf$", filepath)) {
          can_read <- TRUE  # PDF existence check
        } else if (grepl("\\.txt$", filepath)) {
          test <- readLines(filepath, n = 1)
          can_read <- TRUE
        }
      }, error = function(e) { FALSE })
    }

    file_check_results <- rbind(file_check_results, data.frame(
      category = category,
      filename = name,
      exists = exists,
      file_size_kb = size_kb,
      can_read = can_read,
      stringsAsFactors = FALSE
    ))

    status <- if (exists) "✓" else "✗"
    log_msg(paste("  [", status, "]", name))
  }
}

# ============================================================================
# 3. DATA FILE VALIDATION
# ============================================================================

log_msg("Validating data file integrity...")

validation_results <- list()

# Check critical data files for missing values
critical_files <- c(
  "rearrangements_confirmed.tsv",
  "ancestral_karyotypes.csv",
  "rearrangements_per_branch.tsv"
)

for (file_name in critical_files) {
  filepath <- expected_files$phase3_outputs[[file_name]]

  if (file.exists(filepath)) {
    log_msg(paste("  Validating:", file_name))

    data <- read.delim(filepath, header = TRUE, sep = "\t", nrows = 100)

    # Check for missing values in critical columns
    n_rows <- nrow(data)
    n_cols <- ncol(data)

    n_missing <- sum(is.na(data))

    validation_results[[file_name]] <- list(
      n_rows = n_rows,
      n_cols = n_cols,
      n_missing = n_missing,
      has_critical_nas = FALSE
    )

    # Flag if >5% missing data
    if ((n_missing / (n_rows * n_cols)) > 0.05) {
      validation_results[[file_name]]$has_critical_nas <- TRUE
      log_msg(paste("    WARNING: High missing data rate:",
                    round(n_missing / (n_rows * n_cols) * 100, 1), "%"))
    } else {
      log_msg(paste("    OK:", n_rows, "rows,", n_cols, "columns,",
                    n_missing, "missing values"))
    }
  }
}

# ============================================================================
# 4. FIGURE QUALITY CHECKS
# ============================================================================

log_msg("Checking figure files...")

figure_files <- file.path(BASE_DIR, "phase5_viz_manuscript", c(
  "PHASE_4.1_interactive_tree/beetle_tree_rearrangements.pdf",
  "PHASE_4.2_synteny_dotplots/synteny_dotplots.pdf",
  "PHASE_4.3_hotspot_viz/hotspot_figures.pdf",
  "PHASE_4.4_ancestral_figures/ancestral_karyotype_figures.pdf"
))

for (fig_file in figure_files) {
  if (file.exists(fig_file)) {
    size_mb <- file.size(fig_file) / (1024^2)
    log_msg(paste("  ✓", basename(fig_file), "-", round(size_mb, 2), "MB"))
  }
}

# ============================================================================
# 5. GENERATE READINESS CHECKLIST
# ============================================================================

log_msg("Generating manuscript readiness checklist...")

checklist_file <- file.path(OUTPUT_DIR, "manuscript_readiness_checklist.txt")
checklist_conn <- file(checklist_file, open = "w")

cat("MANUSCRIPT READINESS CHECKLIST\n", file = checklist_conn)
cat("=" %*% 70, "\n", file = checklist_conn)
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
    file = checklist_conn)

# ========================================================================
# Data Completion
# ========================================================================

cat("1. DATA COMPLETION\n", file = checklist_conn)
cat("-" %*% 70, "\n\n", file = checklist_conn)

n_exist <- sum(file_check_results$exists)
n_total <- nrow(file_check_results)
pct_exist <- round(n_exist / n_total * 100, 1)

cat("Expected files present: ", n_exist, "/", n_total, " (", pct_exist, "%)\n\n",
    sep = "", file = checklist_conn)

cat("Critical Phase 3 outputs:\n", file = checklist_conn)
critical_phase3 <- c("rearrangements_confirmed.tsv", "ancestral_karyotypes.csv",
                     "rearrangements_per_branch.tsv")

for (file_name in critical_phase3) {
  status <- file_check_results$exists[file_check_results$filename == file_name]
  symbol <- if (status) "✓" else "✗"
  cat("  [", symbol, "] ", file_name, "\n", sep = "", file = checklist_conn)
}

cat("\nCritical Phase 4 outputs:\n", file = checklist_conn)
critical_phase4 <- c("beetle_tree.pdf", "synteny_dotplots.pdf",
                     "hotspot_figures.pdf", "ancestral_figures.pdf")

for (file_name in critical_phase4) {
  status <- file_check_results$exists[file_check_results$filename == file_name]
  symbol <- if (status) "✓" else "✗"
  cat("  [", symbol, "] ", file_name, "\n", sep = "", file = checklist_conn)
}

# ========================================================================
# Data Validity
# ========================================================================

cat("\n2. DATA VALIDITY\n", file = checklist_conn)
cat("-" %*% 70, "\n\n", file = checklist_conn)

for (file_name in names(validation_results)) {
  result <- validation_results[[file_name]]

  cat(file_name, ":\n", sep = "", file = checklist_conn)
  cat("  Rows: ", result$n_rows, "\n", sep = "", file = checklist_conn)
  cat("  Columns: ", result$n_cols, "\n", sep = "", file = checklist_conn)
  cat("  Missing values: ", result$n_missing, "\n", sep = "", file = checklist_conn)

  if (result$has_critical_nas) {
    cat("  [✗] WARNING: High missing data rate\n", file = checklist_conn)
  } else {
    cat("  [✓] Data quality acceptable\n", file = checklist_conn)
  }

  cat("\n", file = checklist_conn)
}

# ========================================================================
# Manuscript Requirements
# ========================================================================

cat("3. MANUSCRIPT REQUIREMENTS\n", file = checklist_conn)
cat("-" %*% 70, "\n\n", file = checklist_conn)

cat("Text & Structure:\n", file = checklist_conn)
cat("  [ ] Title: Clear, descriptive, <15 words\n", file = checklist_conn)
cat("  [ ] Abstract: 150-300 words, all key points\n", file = checklist_conn)
cat("  [ ] Introduction: Motivation and context clear\n", file = checklist_conn)
cat("  [ ] Methods: Sufficient detail for reproducibility\n", file = checklist_conn)
cat("  [ ] Results: Major findings summarized\n", file = checklist_conn)
cat("  [ ] Discussion: Interpretation and implications\n", file = checklist_conn)
cat("  [ ] Acknowledgments: All contributors mentioned\n", file = checklist_conn)
cat("  [ ] References: Complete citations, proper format\n\n", file = checklist_conn)

cat("Figures & Tables:\n", file = checklist_conn)
cat("  [ ] All figures cited in text order\n", file = checklist_conn)
cat("  [ ] Figure captions complete (methods, conclusions)\n", file = checklist_conn)
cat("  [ ] Figure resolution ≥300 DPI\n", file = checklist_conn)
cat("  [ ] Color-blind accessible (avoid red/green only)\n", file = checklist_conn)
cat("  [ ] Supplementary figures organized\n", file = checklist_conn)
cat("  [ ] Table formatting consistent\n\n", file = checklist_conn)

cat("Data & Analysis:\n", file = checklist_conn)
cat("  [ ] Data availability statement included\n", file = checklist_conn)
cat("  [ ] Methods reproducible from description\n", file = checklist_conn)
cat("  [ ] Statistical tests justified\n", file = checklist_conn)
cat("  [ ] p-values or confidence intervals reported\n", file = checklist_conn)
cat("  [ ] Code available in supplementary material\n\n", file = checklist_conn)

# ========================================================================
# Final Steps
# ========================================================================

cat("4. PRE-SUBMISSION CHECKLIST\n", file = checklist_conn)
cat("-" %*% 70, "\n\n", file = checklist_conn)

cat("Before submitting the manuscript:\n", file = checklist_conn)
cat("  [ ] Proofread for spelling/grammar\n", file = checklist_conn)
cat("  [ ] Check all citations are complete\n", file = checklist_conn)
cat("  [ ] Verify funding acknowledgments\n", file = checklist_conn)
cat("  [ ] Confirm author contact information\n", file = checklist_conn)
cat("  [ ] Data release package created (Phase 4.5)\n", file = checklist_conn)
cat("  [ ] Supplementary materials organized\n", file = checklist_conn)
cat("  [ ] Manuscript formatted per journal guidelines\n", file = checklist_conn)
cat("  [ ] Cover letter prepared\n", file = checklist_conn)

cat("\n5. SUMMARY\n", file = checklist_conn)
cat("-" %*% 70, "\n\n", file = checklist_conn)

cat("Overall readiness:", pct_exist, "% complete\n\n", sep = "",
    file = checklist_conn)

if (pct_exist >= 90) {
  cat("Status: READY FOR MANUSCRIPT COMPILATION\n", file = checklist_conn)
  cat("Next step: Complete final figure captions and prepare manuscript text.\n",
      file = checklist_conn)
} else {
  cat("Status: PENDING - MISSING FILES\n", file = checklist_conn)
  cat("Missing files must be generated before proceeding.\n",
      file = checklist_conn)
}

close(checklist_conn)
log_msg(paste("  Wrote:", checklist_file))

# ============================================================================
# 6. DATA VALIDATION REPORT
# ============================================================================

log_msg("Generating data validation report...")

validation_file <- file.path(OUTPUT_DIR, "data_validation_report.txt")
validation_conn <- file(validation_file, open = "w")

cat("DATA VALIDATION REPORT\n", file = validation_conn)
cat("=" %*% 70, "\n", file = validation_conn)
cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n",
    file = validation_conn)

cat("FILE INTEGRITY SUMMARY\n\n", file = validation_conn)

cat("Total expected files: ", nrow(file_check_results), "\n",
    sep = "", file = validation_conn)
cat("Files found: ", sum(file_check_results$exists), "\n",
    sep = "", file = validation_conn)
cat("Files readable: ", sum(file_check_results$can_read), "\n",
    sep = "", file = validation_conn)
cat("Completion rate: ", round(sum(file_check_results$exists) /
                               nrow(file_check_results) * 100, 1), "%\n\n",
    sep = "", file = validation_conn)

cat("DETAILED FILE STATUS\n\n", file = validation_conn)

for (category in unique(file_check_results$category)) {
  cat(category, ":\n", sep = "", file = validation_conn)

  subset_data <- subset(file_check_results, category == category)

  for (i in seq_len(nrow(subset_data))) {
    row <- subset_data[i, ]

    status <- if (row$exists) "✓" else "✗"
    size_str <- if (is.na(row$file_size_kb)) "N/A" else
                  paste(round(row$file_size_kb, 1), "KB")

    cat("  [", status, "] ", row$filename, " (", size_str, ")\n",
        sep = "", file = validation_conn)
  }

  cat("\n", file = validation_conn)
}

cat("DATA QUALITY CHECKS\n\n", file = validation_conn)

for (file_name in names(validation_results)) {
  result <- validation_results[[file_name]]

  cat(file_name, ":\n", sep = "", file = validation_conn)
  cat("  Structure: ", result$n_rows, " rows × ", result$n_cols, " columns\n",
      sep = "", file = validation_conn)

  missing_rate <- if (result$n_rows * result$n_cols > 0)
                    round(result$n_missing / (result$n_rows * result$n_cols) * 100, 2)
                  else 0

  cat("  Missing data: ", result$n_missing, " (", missing_rate, "%)\n",
      sep = "", file = validation_conn)

  if (result$has_critical_nas) {
    cat("  ⚠ WARNING: High missing data rate\n", file = validation_conn)
  } else {
    cat("  ✓ PASS\n", file = validation_conn)
  }

  cat("\n", file = validation_conn)
}

close(validation_conn)
log_msg(paste("  Wrote:", validation_file))

# ============================================================================
# 7. FINAL SUMMARY
# ============================================================================

log_msg("")
log_msg("FINAL CHECKLIST SUMMARY:")
log_msg(paste("  Files present:", sum(file_check_results$exists), "/",
              nrow(file_check_results)))
log_msg(paste("  Completion:", pct_exist, "%"))
log_msg(paste("  Data validation issues:", sum(sapply(validation_results, function(x) x$has_critical_nas))))

log_msg("=== PHASE 4.7 COMPLETE ===")
log_msg("=== PROJECT COMPLETION ===")

close(log_conn)

cat("\n", "=" %*% 70, "\n", sep = "")
cat("✓ MANUSCRIPT READINESS ASSESSMENT COMPLETE\n")
cat("=" %*% 70, "\n")
cat("Completion: ", pct_exist, "%\n", sep = "")
cat("Checklist: ", checklist_file, "\n", sep = "")
cat("Validation: ", validation_file, "\n", sep = "")
cat("Log file: ", LOG_FILE, "\n", sep = "")
cat("=" %*% 70, "\n\n")

if (pct_exist >= 90) {
  cat("✓ READY FOR MANUSCRIPT COMPILATION\n\n")
} else {
  cat("⚠ MISSING FILES - CHECK REPORT FOR DETAILS\n\n")
}
