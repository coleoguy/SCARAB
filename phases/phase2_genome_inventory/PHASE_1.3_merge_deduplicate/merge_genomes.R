#!/usr/bin/env Rscript
################################################################################
# TASK: PHASE_1.3 - Merge and Deduplicate Genomes
################################################################################
#
# OBJECTIVE:
# Read NCBI + Ensembl assembly CSVs.
# Merge on assembly_accession.
# For species with multiple assemblies, select best based on priority:
#   1. RefSeq > GenBank
#   2. Chromosome > Scaffold > Contig > Complete Genome
#   3. Highest N50 (if available)
#   4. Most recent publication year
# Output single canonical genome per species.
#
# INPUTS:
#   - PHASE_1.1 output: ncbi_assemblies_raw.csv
#   - PHASE_1.2 output: ensembl_assemblies_raw.csv
#
# OUTPUTS:
#   - merged_genomes.csv (columns: species_name, assembly_accession,
#     assembly_name, assembly_level, source, seq_rel_date, asm_type, etc.)
#
# STUDENT TODO:
#   - Adjust working directory (line ~50)
#   - Review assembly priority order (lines ~100-110)
#   - Verify input file paths (lines ~85-90)
#   - Adjust assembly_level priority if needed (line ~100)
#   - Verify output path (line ~220)
#
################################################################################

library(base)

# Suppress warnings
options(warn = -1)

cat("PHASE_1.3: Merge and Deduplicate Genomes\n")
cat("========================================\n\n")

## <<<STUDENT: Set your working directory if running standalone>>>
# setwd("[PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.3_merge_deduplicate")

if (!dir.exists("data")) {
  dir.create("data", showWarnings = FALSE, recursive = TRUE)
}

################################################################################
# 1. LOAD INPUT DATA
################################################################################

cat("Step 1: Loading input data...\n")

## <<<STUDENT: Verify paths to input files>>>
ncbi_file <- "../PHASE_1.1_ncbi_mining/ncbi_assemblies_raw.csv"
ensembl_file <- "../PHASE_1.2_ensembl_mining/ensembl_assemblies_raw.csv"

if (!file.exists(ncbi_file)) {
  cat("  ✗ NCBI file not found:", ncbi_file, "\n")
  quit(status = 1)
}

ncbi_data <- read.csv(ncbi_file, stringsAsFactors = FALSE)
cat("  ✓ Loaded NCBI data:", nrow(ncbi_data), "assemblies\n")

# Ensembl is optional
ensembl_data <- NULL
if (file.exists(ensembl_file)) {
  ensembl_data <- read.csv(ensembl_file, stringsAsFactors = FALSE)
  cat("  ✓ Loaded Ensembl data:", nrow(ensembl_data), "assemblies\n")
} else {
  cat("  ⚠ Ensembl file not found; continuing with NCBI only\n")
}

################################################################################
# 2. STANDARDIZE COLUMN NAMES
################################################################################

cat("\nStep 2: Standardizing column names...\n")

# Ensure consistent columns for both sources
ncbi_data$species_name <- ncbi_data$organism_name
ncbi_data$source_db <- ifelse(is.na(ncbi_data$source), "NCBI", ncbi_data$source)

if (!is.null(ensembl_data)) {
  ensembl_data$source_db <- "Ensembl"
  # Ensure assembly_accession column exists
  if (!"assembly_accession" %in% names(ensembl_data)) {
    ensembl_data$assembly_accession <- NA
  }
}

cat("  ✓ Columns standardized\n")

################################################################################
# 3. MERGE DATASETS
################################################################################

cat("\nStep 3: Merging datasets...\n")

# Start with NCBI
merged <- ncbi_data[, c("assembly_accession", "species_name", "assembly_level",
                        "seq_rel_date", "asm_name", "source_db", "taxid", "order")]

# Add Ensembl data if available
if (!is.null(ensembl_data)) {
  ensembl_merge <- ensembl_data[, c("assembly_accession", "species_name",
                                     "assembly_level", "ensembl_release",
                                     "assembly_name", "source_db")]

  # Rename ensembl assembly_name to avoid conflict
  names(ensembl_merge)[5] <- "asm_name"

  # Full outer join on assembly_accession
  # (keeping all unique accessions)
  all_accessions <- unique(c(merged$assembly_accession, ensembl_merge$assembly_accession))

  merged <- merge(
    merged,
    ensembl_merge,
    by = c("assembly_accession", "species_name"),
    all = TRUE,
    suffixes = c(".ncbi", ".ensembl")
  )

  # Consolidate assembly_level (prefer non-NA)
  merged$assembly_level <- ifelse(
    !is.na(merged$assembly_level.ncbi),
    merged$assembly_level.ncbi,
    merged$assembly_level.ensembl
  )
  merged$assembly_level.ncbi <- NULL
  merged$assembly_level.ensembl <- NULL

  # Consolidate asm_name
  merged$asm_name <- ifelse(
    !is.na(merged$asm_name.x),
    merged$asm_name.x,
    merged$asm_name.y
  )
  if ("asm_name.x" %in% names(merged)) merged$asm_name.x <- NULL
  if ("asm_name.y" %in% names(merged)) merged$asm_name.y <- NULL

  # Consolidate source
  merged$source_db <- ifelse(
    !is.na(merged$source_db.x),
    merged$source_db.x,
    merged$source_db.y
  )
  merged$source_db.x <- NULL
  merged$source_db.y <- NULL
}

cat("  ✓ Merged:", nrow(merged), "total assembly records\n")

################################################################################
# 4. PARSE AND SCORE ASSEMBLIES
################################################################################

cat("\nStep 4: Scoring assemblies for selection...\n")

# Define priority scores
# Higher score = better
source_priority <- c("RefSeq" = 100, "Ensembl" = 50, "NCBI" = 25, "GenBank" = 10)
assembly_level_priority <- c(
  "Complete Genome" = 40,
  "Chromosome" = 30,
  "Scaffold" = 20,
  "Contig" = 10
)

# Parse sequence release date
merged$seq_rel_year <- as.numeric(substr(merged$seq_rel_date, 1, 4))
merged$seq_rel_year <- ifelse(is.na(merged$seq_rel_year), 2000, merged$seq_rel_year)

# Assign scores
merged$source_score <- sapply(merged$source_db, function(x) {
  source_priority[x] %||% 0
})

merged$assembly_level_score <- sapply(merged$assembly_level, function(x) {
  assembly_level_priority[x] %||% 0
})

# Combined score (source + assembly_level + recency)
merged$combined_score <- (
  merged$source_score +
  merged$assembly_level_score +
  (merged$seq_rel_year - 2000) * 0.5  # Small boost for recent years
)

cat("  ✓ Scores assigned\n")

################################################################################
# 5. SELECT BEST ASSEMBLY PER SPECIES
################################################################################

cat("\nStep 5: Selecting best assembly per species...\n")

# Remove rows with missing species name or assembly accession
merged_clean <- merged[
  !is.na(merged$species_name) & nchar(as.character(merged$species_name)) > 0 &
  !is.na(merged$assembly_accession) & nchar(as.character(merged$assembly_accession)) > 0,
  ]

cat("  ✓ After removing incomplete records:", nrow(merged_clean), "\n")

# Sort by combined_score (descending) and species name
merged_clean <- merged_clean[
  order(merged_clean$species_name,
        -merged_clean$combined_score,
        merged_clean$assembly_accession),
  ]

# Keep only best per species (first occurrence after sort)
best_per_species <- merged_clean[!duplicated(merged_clean$species_name), ]

cat("  ✓ Selected best assembly per species:", nrow(best_per_species), "species\n")

################################################################################
# 6. SELECT OUTPUT COLUMNS AND CLEAN
################################################################################

cat("\nStep 6: Finalizing output...\n")

# Select final columns
final_columns <- c(
  "species_name", "assembly_accession", "asm_name", "assembly_level",
  "source_db", "seq_rel_date", "seq_rel_year", "taxid", "order"
)

# Keep only columns that exist
final_columns <- final_columns[final_columns %in% names(best_per_species)]

output_df <- best_per_species[, final_columns]

# Rename source_db to source for consistency
names(output_df)[names(output_df) == "source_db"] <- "source"

# Sort by order, then species name
if ("order" %in% names(output_df)) {
  output_df <- output_df[order(output_df$order, output_df$species_name), ]
}

cat("  ✓ Output prepared:", nrow(output_df), "species\n")

################################################################################
# 7. QUALITY CHECKS
################################################################################

cat("\nStep 7: Running quality checks...\n")

# Check for duplicates
dup_count <- sum(duplicated(output_df$assembly_accession))
if (dup_count > 0) {
  cat("  ⚠ Found", dup_count, "duplicate assembly accessions\n")
}

# Check for missing critical fields
missing_accession <- sum(is.na(output_df$assembly_accession))
missing_species <- sum(is.na(output_df$species_name))
cat("  Missing assembly_accession:", missing_accession, "\n")
cat("  Missing species_name:", missing_species, "\n")

cat("  ✓ Quality checks complete\n")

################################################################################
# 8. OUTPUT
################################################################################

cat("\nStep 8: Writing output...\n")

## <<<STUDENT: Adjust output file path if needed>>>
output_file <- "merged_genomes.csv"

write.csv(output_df, output_file, row.names = FALSE, quote = TRUE)
cat("  ✓ Output written to:", output_file, "\n")

# Summary statistics
cat("\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("SUMMARY\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("Total genomes (1 best per species):", nrow(output_df), "\n")

if ("order" %in% names(output_df)) {
  cat("By order:\n")
  print(table(output_df$order))
}

if ("assembly_level" %in% names(output_df)) {
  cat("By assembly level:\n")
  print(table(output_df$assembly_level))
}

if ("source" %in% names(output_df)) {
  cat("By source:\n")
  print(table(output_df$source))
}

cat("\nFile saved:", output_file, "\n")

################################################################################
# END OF SCRIPT
################################################################################
