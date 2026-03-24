#!/usr/bin/env Rscript
################################################################################
# TASK: PHASE_1.2 - Ensembl Genome Mining
################################################################################
#
# OBJECTIVE:
# Query Ensembl REST API for Coleoptera genomes.
# Extract key metadata: species, assembly name, accession, N50.
# De-duplicate and cross-reference against NCBI results.
# Output canonical Ensembl genome list.
#
# INPUTS:
#   - Ensembl REST API: (dynamically queried)
#   - Optional: PHASE_1.1 output (ncbi_assemblies_raw.csv) for comparison
#
# OUTPUTS:
#   - ensembl_assemblies_raw.csv (columns: species_name, assembly_name,
#     assembly_accession, assembly_level, seq_region_count, seq_region_length,
#     karyotype, ensembl_release)
#
# STUDENT TODO:
#   - Set Ensembl REST API endpoint if needed (line ~50)
#   - Adjust working directory if running standalone (line ~55)
#   - Review filtering criteria for assembly_level (line ~100)
#   - Add any additional Ensembl divisions if needed (line ~70-75)
#   - Verify output path (line ~180)
#
# NOTES:
#   - Ensembl REST API has rate limits (~15 requests/sec)
#   - Script includes delay between requests
#   - Some species may not be in Ensembl (Vertebrates, Plants, Fungi only)
#
################################################################################

library(httr)
library(jsonlite)

# Suppress warnings
options(warn = -1)

cat("PHASE_1.2: Ensembl Genome Mining\n")
cat("=================================\n\n")

## <<<STUDENT: Set your working directory if running standalone>>>
# setwd("[PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.2_ensembl_mining")

if (!dir.exists("data")) {
  dir.create("data", showWarnings = FALSE, recursive = TRUE)
}

################################################################################
# 1. ENSEMBL API SETUP
################################################################################

cat("Step 1: Initializing Ensembl REST API connection...\n")

## <<<STUDENT: Change API endpoint if needed (production/testing)>>>
ensembl_base <- "https://rest.ensembl.org"

# Create delay function for API rate limiting (15 req/sec = ~66ms minimum)
rate_limit_delay <- function() {
  Sys.sleep(0.1)  # 100ms delay to be conservative
}

# Helper function to query Ensembl REST API
query_ensembl <- function(endpoint, params = list()) {
  url <- paste0(ensembl_base, endpoint)

  tryCatch(
    {
      response <- GET(url,
                      query = params,
                      add_headers("Content-Type" = "application/json"),
                      timeout(30))

      if (status_code(response) != 200) {
        cat("  ⚠ API error for", endpoint, ":", status_code(response), "\n")
        return(NULL)
      }

      content(response, as = "parsed", type = "application/json")
    },
    error = function(e) {
      cat("  ⚠ Request failed:", e$message, "\n")
      return(NULL)
    }
  )
}

cat("  ✓ Ensembl API initialized\n")

################################################################################
# 2. QUERY ENSEMBL FOR COLEOPTERA
################################################################################

cat("\nStep 2: Querying Ensembl for Coleoptera genomes...\n")

# Ensembl's Metazoa division includes insects
# Query available species in the Metazoa division
cat("  Fetching species list from Ensembl Metazoa...\n")

species_list <- query_ensembl("/info/species", list(division = "ensembl"))

if (is.null(species_list)) {
  cat("  ✗ Failed to fetch species list. Exiting.\n")
  quit(status = 1)
}

# Extract species info
species_data <- species_list$species
cat("  ✓ Found", length(species_data), "species in Ensembl\n")

# Function to check if species is Coleoptera using taxonomy
is_coleoptera <- function(species_obj) {
  if (is.null(species_obj$taxonomy)) return(FALSE)

  taxonomy <- tolower(paste(species_obj$taxonomy, collapse = "|"))
  grepl("coleoptera", taxonomy)
}

# Filter for Coleoptera
coleoptera_species <- list()
for (i in seq_along(species_data)) {
  sp <- species_data[[i]]
  rate_limit_delay()

  # Check taxonomy
  if (is_coleoptera(sp)) {
    coleoptera_species[[length(coleoptera_species) + 1]] <- sp
  }
}

cat("  ✓ Found", length(coleoptera_species), "Coleoptera species in Ensembl\n")

################################################################################
# 3. EXTRACT METADATA FOR EACH SPECIES
################################################################################

cat("\nStep 3: Extracting genome metadata...\n")

ensembl_results <- list()

for (i in seq_along(coleoptera_species)) {
  sp <- coleoptera_species[[i]]
  species_name <- sp$name

  cat("  Processing:", species_name, "\n")

  # Query genome info for this species
  rate_limit_delay()
  genome_info <- query_ensembl(
    paste0("/info/assembly/", species_name)
  )

  if (is.null(genome_info)) {
    cat("    ⚠ Could not fetch genome info\n")
    next
  }

  # Extract key fields
  record <- list(
    species_name = species_name,
    assembly_name = genome_info$assembly_name %||% NA,
    assembly_accession = genome_info$assembly_accession %||% NA,
    assembly_level = genome_info$assembly_level %||% NA,
    seq_region_count = as.numeric(genome_info$top_level_count %||% NA),
    seq_region_length = as.numeric(genome_info$top_level_length %||% NA),
    karyotype = paste(genome_info$karyotype, collapse = ";") %||% NA,
    ensembl_release = genome_info$ensembl_release %||% NA,
    genebuild_last_update = genome_info$genebuild_last_update %||% NA
  )

  ensembl_results[[length(ensembl_results) + 1]] <- record

  if (i %% 10 == 0) {
    cat("    Progress:", i, "/", length(coleoptera_species), "\n")
  }
}

cat("  ✓ Processed", length(ensembl_results), "species\n")

################################################################################
# 4. CONVERT TO DATA FRAME
################################################################################

cat("\nStep 4: Converting to data frame...\n")

# Convert list of lists to data frame
ensembl_df <- do.call(rbind, lapply(ensembl_results, function(x) {
  data.frame(
    species_name = x$species_name %||% NA,
    assembly_name = x$assembly_name %||% NA,
    assembly_accession = x$assembly_accession %||% NA,
    assembly_level = x$assembly_level %||% NA,
    seq_region_count = x$seq_region_count %||% NA,
    seq_region_length = x$seq_region_length %||% NA,
    karyotype = x$karyotype %||% NA,
    ensembl_release = x$ensembl_release %||% NA,
    genebuild_last_update = x$genebuild_last_update %||% NA,
    stringsAsFactors = FALSE
  )
}))

if (nrow(ensembl_df) == 0) {
  cat("  ✗ No Coleoptera genomes found in Ensembl\n")
  # Create empty data frame with correct columns
  ensembl_df <- data.frame(
    species_name = character(),
    assembly_name = character(),
    assembly_accession = character(),
    assembly_level = character(),
    seq_region_count = numeric(),
    seq_region_length = numeric(),
    karyotype = character(),
    ensembl_release = numeric(),
    genebuild_last_update = character(),
    stringsAsFactors = FALSE
  )
} else {
  cat("  ✓ Extracted metadata for", nrow(ensembl_df), "genomes\n")
}

################################################################################
# 5. CLEAN AND DEDUPLICATE
################################################################################

cat("\nStep 5: Cleaning and deduplicating...\n")

# Remove rows with missing assembly accessions
ensembl_df <- ensembl_df[!is.na(ensembl_df$assembly_accession) &
                         nchar(ensembl_df$assembly_accession) > 0, ]

cat("  ✓ After removing incomplete records:", nrow(ensembl_df), "genomes\n")

# Sort by species and Ensembl release (keep most recent)
ensembl_df <- ensembl_df[
  order(ensembl_df$species_name,
        -ensembl_df$ensembl_release),
  ]

# Remove duplicates (keep first = most recent)
ensembl_df <- ensembl_df[!duplicated(ensembl_df$species_name), ]

cat("  ✓ After deduplication:", nrow(ensembl_df), "genomes\n")

################################################################################
# 6. OPTIONAL: COMPARE WITH NCBI RESULTS
################################################################################

cat("\nStep 6: Cross-referencing with NCBI (if available)...\n")

ncbi_file <- "../PHASE_1.1_ncbi_mining/ncbi_assemblies_raw.csv"
if (file.exists(ncbi_file)) {
  ncbi_data <- read.csv(ncbi_file, stringsAsFactors = FALSE)
  cat("  ✓ Loaded NCBI results:", nrow(ncbi_data), "assemblies\n")

  # Find Ensembl accessions in NCBI
  in_ncbi <- ensembl_df$assembly_accession %in% ncbi_data$assembly_accession
  cat("  ✓", sum(in_ncbi), "Ensembl genomes also in NCBI\n")
  cat("  ✓", sum(!in_ncbi), "Ensembl genomes NOT in NCBI (likely older versions)\n")

  ensembl_df$in_ncbi <- in_ncbi
} else {
  cat("  ⚠ NCBI results not found; skipping cross-reference\n")
}

################################################################################
# 7. OUTPUT
################################################################################

cat("\nStep 7: Writing output...\n")

## <<<STUDENT: Adjust output file path if needed>>>
output_file <- "ensembl_assemblies_raw.csv"

write.csv(ensembl_df, output_file, row.names = FALSE, quote = TRUE)
cat("  ✓ Output written to:", output_file, "\n")

# Summary statistics
cat("\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("SUMMARY\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("Total Coleoptera genomes in Ensembl:", nrow(ensembl_df), "\n")

if (!is.null(ensembl_df$assembly_level)) {
  cat("By assembly level:\n")
  print(table(ensembl_df$assembly_level))
}

if ("in_ncbi" %in% names(ensembl_df)) {
  cat("Cross-reference with NCBI:\n")
  print(table(ensembl_df$in_ncbi))
}

cat("\nFile saved:", output_file, "\n")

################################################################################
# END OF SCRIPT
################################################################################
