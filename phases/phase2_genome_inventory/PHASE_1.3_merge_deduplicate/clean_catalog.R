#!/usr/bin/env Rscript
#===============================================================================
# Clean and deduplicate genome catalog
#===============================================================================
# Purpose: Process genome_catalog.csv to:
#   1. Identify and flag GCA/GCF duplicate pairs (GenBank vs RefSeq mirrors)
#   2. Select best assembly per species based on quality criteria
#   3. Add selection_status column to all rows
#   4. Output cleaned catalog and primary selections
#===============================================================================

# Set up paths relative to this script
script_dir <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE))))
if (length(script_dir) == 0 || script_dir == ".") {
  script_dir <- getwd()
}

data_dir <- file.path(script_dir, "../../../data/genomes")
input_file <- file.path(data_dir, "genome_catalog.csv")
output_cleaned <- file.path(script_dir, "genome_catalog_cleaned.csv")
output_primary <- file.path(script_dir, "genome_catalog_primary.csv")

# Check that input file exists
if (!file.exists(input_file)) {
  stop("Input file not found: ", input_file)
}

cat("Reading genome catalog from:", input_file, "\n")
cat("Output directory:", script_dir, "\n\n")

#===============================================================================
# Load and prepare data
#===============================================================================

genome_cat <- read.csv(input_file, stringsAsFactors = FALSE)
cat("Loaded", nrow(genome_cat), "rows and", ncol(genome_cat), "columns\n\n")

# Initialize columns for tracking
genome_cat$selection_status <- NA_character_
genome_cat$conflict_flag <- ifelse(is.na(genome_cat$conflict_flag), "", genome_cat$conflict_flag)

#===============================================================================
# Step 1: Identify GCA/GCF duplicate pairs
#===============================================================================

cat("STEP 1: Identifying GCA/GCF duplicate pairs...\n")

# Extract the accession prefix (GCA or GCF)
accession_prefix <- substr(genome_cat$assembly_accession, 1, 3)

# For each species, find pairs with same scaffold_N50 and genome_size_mb
gca_gcf_pairs <- 0

for (species in unique(genome_cat$species_name)) {
  species_idx <- which(genome_cat$species_name == species)

  if (length(species_idx) > 1) {
    # Check within this species for GCA/GCF pairs
    species_data <- genome_cat[species_idx, ]

    for (i in seq_along(species_idx)) {
      for (j in seq(i + 1, length(species_idx))) {
        idx_i <- species_idx[i]
        idx_j <- species_idx[j]

        # Check if same size and N50 (indicating mirrors)
        same_size <- species_data$genome_size_mb[i] == species_data$genome_size_mb[j]
        same_n50 <- species_data$scaffold_N50[i] == species_data$scaffold_N50[j]

        if (!is.na(same_size) && !is.na(same_n50) && same_size && same_n50) {
          prefix_i <- accession_prefix[idx_i]
          prefix_j <- accession_prefix[idx_j]

          # If one is GCA and other is GCF, mark GCA as duplicate
          if ((prefix_i == "GCA" && prefix_j == "GCF") ||
              (prefix_i == "GCF" && prefix_j == "GCA")) {
            if (prefix_i == "GCA") {
              genome_cat$conflict_flag[idx_i] <- paste(
                genome_cat$conflict_flag[idx_i],
                "GCA_GCF_duplicate",
                sep = ifelse(genome_cat$conflict_flag[idx_i] == "", "", ";")
              )
              gca_gcf_pairs <- gca_gcf_pairs + 1
            } else {
              genome_cat$conflict_flag[idx_j] <- paste(
                genome_cat$conflict_flag[idx_j],
                "GCA_GCF_duplicate",
                sep = ifelse(genome_cat$conflict_flag[idx_j] == "", "", ";")
              )
              gca_gcf_pairs <- gca_gcf_pairs + 1
            }
          }
        }
      }
    }
  }
}

cat("  Flagged", gca_gcf_pairs, "rows as GCA_GCF_duplicate\n\n")

#===============================================================================
# Step 2: Select best assembly per species
#===============================================================================

cat("STEP 2: Selecting best assembly per species...\n")

# Map assembly_level to numeric priority (higher = better)
assembly_level_priority <- function(level) {
  priority <- switch(tolower(as.character(level)),
    "chromosome" = 3,
    "scaffold" = 2,
    "contig" = 1,
    0  # Unknown or NA
  )
  return(priority)
}

# Map publication status to priority (higher = better)
publication_priority <- function(status) {
  priority <- switch(tolower(as.character(status)),
    "published_open" = 3,
    "check_ebp_dtol" = 2,
    "to_verify" = 1,
    0  # Unknown or NA
  )
  return(priority)
}

# Vectorize the priority functions
assembly_priority_vec <- vapply(genome_cat$assembly_level, assembly_level_priority, 0)
pub_priority_vec <- vapply(genome_cat$primary_source, publication_priority, 0)

# Convert submission_date to Date type for comparison
if ("submission_date" %in% names(genome_cat)) {
  submission_dates <- as.Date(genome_cat$submission_date, format = "%Y-%m-%d")
} else {
  submission_dates <- rep(as.Date("1970-01-01"), nrow(genome_cat))
}

# Convert gene_annotation_available to numeric (yes/TRUE = 1, no/FALSE = 0)
has_annotation <- as.numeric(
  tolower(genome_cat$gene_annotation_available) %in% c("yes", "true", "y", "1")
)

# Process each species
species_list <- unique(genome_cat$species_name)
n_species <- length(species_list)
primary_count <- 0
alternate_count <- 0

for (species in species_list) {
  species_idx <- which(genome_cat$species_name == species)

  if (length(species_idx) == 1) {
    # Only one assembly for this species
    genome_cat$selection_status[species_idx] <- "primary"
    primary_count <- primary_count + 1
  } else {
    # Multiple assemblies for this species
    # Build scoring matrix
    n_rows <- length(species_idx)

    scores <- data.frame(
      idx = species_idx,
      assembly_priority = assembly_priority_vec[species_idx],
      scaffold_n50 = genome_cat$scaffold_N50[species_idx],
      has_annotation = has_annotation[species_idx],
      submission_date = submission_dates[species_idx],
      pub_priority = pub_priority_vec[species_idx],
      stringsAsFactors = FALSE
    )

    # Normalize scaffold_N50 to 0-1 range (within this species)
    max_n50 <- max(scores$scaffold_n50, na.rm = TRUE)
    if (max_n50 > 0) {
      scores$scaffold_n50_norm <- scores$scaffold_n50 / max_n50
    } else {
      scores$scaffold_n50_norm <- 0
    }

    # Normalize submission_date to 0-1 range (within this species)
    max_date <- max(scores$submission_date, na.rm = TRUE)
    min_date <- min(scores$submission_date, na.rm = TRUE)
    if (max_date > min_date) {
      scores$date_norm <- as.numeric(scores$submission_date - min_date) /
                         as.numeric(max_date - min_date)
    } else {
      scores$date_norm <- 0.5
    }

    # Calculate composite score
    # Weighted: 40% assembly level, 30% scaffold N50, 15% annotation, 10% publication, 5% date
    scores$composite <- (
      0.40 * scores$assembly_priority +
      0.30 * scores$scaffold_n50_norm +
      0.15 * scores$has_annotation +
      0.10 * scores$pub_priority +
      0.05 * scores$date_norm
    )

    # Find best assembly (highest score)
    best_idx <- scores$idx[which.max(scores$composite)]
    genome_cat$selection_status[best_idx] <- "primary"
    primary_count <- primary_count + 1

    # Mark others as alternate
    alt_idx <- species_idx[species_idx != best_idx]
    genome_cat$selection_status[alt_idx] <- "alternate"
    alternate_count <- alternate_count + length(alt_idx)
  }
}

cat("  Primary assemblies:", primary_count, "\n")
cat("  Alternate assemblies:", alternate_count, "\n\n")

#===============================================================================
# Step 3: Summary statistics
#===============================================================================

cat("SUMMARY STATISTICS:\n")
cat("==================\n")
cat("Total rows:", nrow(genome_cat), "\n")
cat("Total species:", n_species, "\n")
cat("Selection status breakdown:\n")
print(table(genome_cat$selection_status, useNA = "ifany"))
cat("\n")

conflict_flags <- genome_cat$conflict_flag[genome_cat$conflict_flag != ""]
cat("Rows with conflict flags:", length(conflict_flags), "\n")
if (length(conflict_flags) > 0) {
  cat("  Flag types:\n")
  all_flags <- unlist(strsplit(conflict_flags, ";"))
  print(table(all_flags))
}
cat("\n")

# Assembly level distribution for primary selections
primary_levels <- genome_cat$assembly_level[genome_cat$selection_status == "primary"]
cat("Primary selections by assembly level:\n")
print(table(primary_levels, useNA = "ifany"))
cat("\n")

# Gene annotation availability in primary selections
primary_annot <- genome_cat$gene_annotation_available[genome_cat$selection_status == "primary"]
cat("Gene annotation in primary selections:\n")
print(table(primary_annot, useNA = "ifany"))
cat("\n")

#===============================================================================
# Step 4: Write output files
#===============================================================================

cat("Writing output files...\n")

# Write cleaned catalog (all rows with selection_status)
write.csv(genome_cat, file = output_cleaned, row.names = FALSE)
cat("  Written:", output_cleaned, "\n")
cat("    Size:", nrow(genome_cat), "rows\n")

# Write primary selections only
primary_rows <- genome_cat[genome_cat$selection_status == "primary", ]
write.csv(primary_rows, file = output_primary, row.names = FALSE)
cat("  Written:", output_primary, "\n")
cat("    Size:", nrow(primary_rows), "rows\n\n")

cat("COMPLETE!\n")
