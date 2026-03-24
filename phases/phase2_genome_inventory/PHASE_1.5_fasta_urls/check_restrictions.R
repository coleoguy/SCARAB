#!/usr/bin/env Rscript
#
# Script: check_restrictions.R
# Purpose: Audit and update genome restriction status based on EBP/DToL affiliation
#
# Logic:
#   1. Reads genome_catalog.csv
#   2. For genomes with restriction_status == "check_ebp_dtol" or "to_verify":
#      - Checks BioProject accession (PRJEB = likely EBP/DToL)
#      - Flags known umbrella projects (PRJEB43743 = DToL, PRJEB40665 = EBP)
#      - Checks for publication DOI
#      - Updates restriction_status accordingly
#   3. Outputs restriction_audit.csv with updated status
#   4. Prints summary statistics
#
# Output: restriction_audit.csv (in script's directory)
#
# Usage: Rscript check_restrictions.R

# =============================================================================
# CONFIGURATION
# =============================================================================

# Relative path from script location to catalog
CATALOG_RELATIVE_PATH <- "../../../data/genomes/genome_catalog.csv"

# Output directory (same as script directory)
OUTPUT_DIR <- dirname(normalizePath(thisfile()))

# Known EBP/DToL umbrella projects
EBP_DTOL_PROJECTS <- c(
  "PRJEB43743",  # DToL (Darwin Tree of Life)
  "PRJEB40665"   # EBP (Earth Biogenome Project)
)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get the directory of the currently running script
thisfile <- function() {
  cmdArgs <- commandArgs(trailingOnly = FALSE)
  needle <- "--file="
  match <- grep(needle, cmdArgs)
  if (length(match) > 0) {
    return(normalizePath(sub(needle, "", cmdArgs[match])))
  } else {
    return(normalizePath(sys.frames()[[1]]$ofile))
  }
}

# Resolve relative path from script location
resolve_path <- function(relative_path, from_file) {
  script_dir <- dirname(normalizePath(from_file))
  normalizePath(file.path(script_dir, relative_path))
}

# Detect if a BioProject accession is from EBP/DToL
# Returns one of: "dtol", "ebp", "ebp_dtol_other", NA
detect_ebp_dtol <- function(bioproject) {
  if (is.na(bioproject) || bioproject == "") {
    return(NA_character_)
  }

  # Check for known umbrella projects
  if (bioproject == "PRJEB43743") {
    return("dtol")
  }
  if (bioproject == "PRJEB40665") {
    return("ebp")
  }

  # Check if it's a PRJEB accession (Europe, often EBP/DToL affiliated)
  if (grepl("^PRJEB", bioproject)) {
    return("ebp_dtol_other")
  }

  return(NA_character_)
}

# Check if a DOI string is non-empty and valid
has_valid_doi <- function(doi) {
  !is.na(doi) && nchar(trimws(doi)) > 0
}

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading genome catalog...\n")
catalog_path <- resolve_path(CATALOG_RELATIVE_PATH, thisfile())

if (!file.exists(catalog_path)) {
  stop("Catalog not found at: ", catalog_path)
}

catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)
cat("  Loaded", nrow(catalog), "records\n\n")

# =============================================================================
# INITIALIZE AUDIT COLUMNS
# =============================================================================

# Create audit output with key columns
audit <- data.frame(
  assembly_accession = catalog$assembly_accession,
  species_name = catalog$species_name,
  ncbi_bioproject = catalog$ncbi_bioproject,
  publication_doi = catalog$publication_doi,
  restriction_status_original = catalog$restriction_status,
  ebp_dtol_type = NA_character_,
  has_doi = NA,
  restriction_status_updated = catalog$restriction_status,
  change_reason = NA_character_,
  stringsAsFactors = FALSE
)

# =============================================================================
# AUDIT LOGIC
# =============================================================================

cat("Auditing restriction status...\n")

# Identify rows that need checking
needs_check <- audit$restriction_status_original %in% c("check_ebp_dtol", "to_verify")
cat("  Genomes to audit:", sum(needs_check), "\n")

# Process each genome that needs checking
for (i in which(needs_check)) {
  bioproject <- audit$ncbi_bioproject[i]
  doi <- audit$publication_doi[i]
  current_status <- audit$restriction_status_original[i]

  # Detect EBP/DToL affiliation
  ebp_dtol_type <- detect_ebp_dtol(bioproject)
  audit$ebp_dtol_type[i] <- if (is.na(ebp_dtol_type)) "" else ebp_dtol_type

  # Check for valid DOI
  has_doi <- has_valid_doi(doi)
  audit$has_doi[i] <- has_doi

  # Update restriction status based on evidence
  if (has_doi) {
    # Has DOI - likely published and open
    audit$restriction_status_updated[i] <- "published_open"
    audit$change_reason[i] <- "Has publication DOI"
  } else if (!is.na(ebp_dtol_type) && ebp_dtol_type != "") {
    # From EBP/DToL but no DOI - likely prepublication
    audit$restriction_status_updated[i] <- "check_ebp_dtol_prepub"
    audit$change_reason[i] <- paste("EBP/DToL-affiliated (", ebp_dtol_type, ") without DOI", sep = "")
  } else {
    # No clear EBP/DToL affiliation, no DOI
    # Keep original status for manual review
    audit$change_reason[i] <- "Needs manual review (no EBP/DToL/DOI evidence)"
  }
}

# =============================================================================
# STATISTICS
# =============================================================================

cat("\nRestriction Status Summary:\n")
cat("-" %,% rep("-", 50) %,% "-\n")

# Summary of original status
original_counts <- table(audit$restriction_status_original)
cat("\nOriginal Status Distribution:\n")
for (status in names(original_counts)) {
  cat("  ", status, ": ", original_counts[[status]], "\n", sep = "")
}

# Summary of updated status
updated_counts <- table(audit$restriction_status_updated)
cat("\nUpdated Status Distribution:\n")
for (status in names(updated_counts)) {
  cat("  ", status, ": ", updated_counts[[status]], "\n", sep = "")
}

# Changes made
cat("\nChanges Made:\n")
changes <- audit$restriction_status_original != audit$restriction_status_updated
cat("  Genomes with status changed:", sum(changes), "\n")

if (sum(changes) > 0) {
  cat("\n  Breakdown of changes:\n")
  change_table <- table(
    paste(audit$restriction_status_original[changes], "->", audit$restriction_status_updated[changes])
  )
  for (change in names(change_table)) {
    cat("    ", change, ": ", change_table[[change]], "\n", sep = "")
  }
}

# EBP/DToL breakdown
cat("\nEBP/DToL Affiliation (for audited genomes):\n")
has_ebp_dtol <- audit$ebp_dtol_type != "" & !is.na(audit$ebp_dtol_type)
cat("  With EBP/DToL affiliation:", sum(has_ebp_dtol), "\n")

if (sum(has_ebp_dtol) > 0) {
  ebp_dtol_breakdown <- table(audit$ebp_dtol_type[has_ebp_dtol])
  for (type in names(ebp_dtol_breakdown)) {
    cat("    ", type, ": ", ebp_dtol_breakdown[[type]], "\n", sep = "")
  }
}

# DOI availability
cat("\nDOI Availability:\n")
has_doi <- audit$has_doi == TRUE
cat("  With publication DOI:", sum(has_doi), "\n")
cat("  Without DOI:", sum(!has_doi | is.na(audit$has_doi)), "\n")

cat("\n" %,% rep("-", 50) %,% "-\n")

# =============================================================================
# OUTPUT AUDIT FILE
# =============================================================================

cat("\nWriting restriction_audit.csv...\n")

write.csv(audit, file.path(OUTPUT_DIR, "restriction_audit.csv"),
          row.names = FALSE, quote = TRUE)

cat("  Written to:", file.path(OUTPUT_DIR, "restriction_audit.csv"), "\n")

# =============================================================================
# OPTIONAL: UPDATE ORIGINAL CATALOG
# =============================================================================

# Create an updated version of the catalog with new restriction_status
catalog_updated <- catalog
catalog_updated$restriction_status <- audit$restriction_status_updated

cat("\nWriting updated genome_catalog_restrictions_updated.csv...\n")
write.csv(catalog_updated,
          file.path(OUTPUT_DIR, "genome_catalog_restrictions_updated.csv"),
          row.names = FALSE, quote = TRUE)

cat("  Written to:", file.path(OUTPUT_DIR, "genome_catalog_restrictions_updated.csv"), "\n")

# =============================================================================
# COMPLETION
# =============================================================================

cat("\n" %,% rep("=", 70) %,% "=\n")
cat("AUDIT COMPLETE\n")
cat("=" %,% rep("=", 70) %,% "=\n")

cat("\nOutputs created:\n")
cat("  1. restriction_audit.csv\n")
cat("     - Detailed audit with all intermediate columns\n")
cat("     - Use for verification and manual review\n\n")
cat("  2. genome_catalog_restrictions_updated.csv\n")
cat("     - Full catalog with updated restriction_status column\n")
cat("     - Ready to merge back into main catalog if approved\n\n")

cat("Next steps:\n")
cat("  1. Review restriction_audit.csv for accuracy\n")
cat("  2. Verify change_reason column for each changed entry\n")
cat("  3. If approved, replace restriction_status in original catalog\n")
cat("     with values from genome_catalog_restrictions_updated.csv\n\n")
