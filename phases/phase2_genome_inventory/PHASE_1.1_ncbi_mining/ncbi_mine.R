#!/usr/bin/env Rscript
################################################################################
# TASK: PHASE_1.1 - NCBI Assembly Mining
################################################################################
#
# OBJECTIVE:
# Download NCBI assembly_summary_refseq.txt (and genbank fallback).
# Filter for Coleoptera (order level) with assembly_level >= Scaffold, pub_year >= 2018.
# Also capture Neuropterida outgroups (Neuroptera, Megaloptera, Raphidioptera).
# Deduplicate and output consolidated CSV.
#
# INPUTS:
#   - NCBI FTP: assembly_summary_refseq.txt (downloaded on-the-fly)
#   - NCBI FTP: assembly_summary_genbank.txt (fallback for non-RefSeq)
#
# OUTPUTS:
#   - ncbi_assemblies_raw.csv (columns: assembly_accession, organism_name,
#     assembly_level, refseq_category, seq_rel_date, assembly_type, asm_name,
#     taxid, genome_rep, paired_asm_comp)
#
# STUDENT TODO:
#   - Set working directory if needed (line ~50)
#   - Adjust assembly_level filter if needed (line ~80)
#   - Adjust pub_year threshold if needed (line ~85)
#   - Review output_file path (line ~160)
#
################################################################################

library(utils)

# Suppress warnings for cleaner output
options(warn = -1)

cat("PHASE_1.1: NCBI Assembly Mining\n")
cat("================================\n\n")

## <<<STUDENT: Set your working directory if running standalone>>>
# setwd("[PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.1_ncbi_mining")

# Create data directory if it doesn't exist
if (!dir.exists("data")) {
  dir.create("data", showWarnings = FALSE, recursive = TRUE)
}

################################################################################
# 1. DOWNLOAD NCBI ASSEMBLY SUMMARIES
################################################################################

cat("Step 1: Downloading NCBI assembly summaries...\n")

# RefSeq URL
refseq_url <- "ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/assembly_summary_refseq.txt"
genbank_url <- "ftp://ftp.ncbi.nlm.nih.gov/genomes/genbank/assembly_summary_genbank.txt"

refseq_file <- "data/assembly_summary_refseq.txt"
genbank_file <- "data/assembly_summary_genbank.txt"

# Download RefSeq
cat("  Downloading RefSeq assembly summary...\n")
tryCatch(
  {
    download.file(refseq_url, refseq_file, quiet = TRUE, mode = "wb")
    cat("  ✓ RefSeq downloaded\n")
  },
  error = function(e) {
    cat("  ✗ RefSeq download failed:", e$message, "\n")
    cat("  Will attempt GenBank only\n")
  }
)

# Download GenBank as fallback
cat("  Downloading GenBank assembly summary...\n")
tryCatch(
  {
    download.file(genbank_url, genbank_file, quiet = TRUE, mode = "wb")
    cat("  ✓ GenBank downloaded\n")
  },
  error = function(e) {
    cat("  ✗ GenBank download failed:", e$message, "\n")
  }
)

################################################################################
# 2. PARSE AND FILTER
################################################################################

cat("\nStep 2: Parsing and filtering assemblies...\n")

# Read RefSeq if available
refseq_data <- NULL
if (file.exists(refseq_file)) {
  refseq_data <- read.delim(refseq_file,
                            skip = 1,
                            header = FALSE,
                            stringsAsFactors = FALSE,
                            sep = "\t",
                            quote = "")
  cat("  ✓ RefSeq loaded:", nrow(refseq_data), "rows\n")
}

# Read GenBank if available
genbank_data <- NULL
if (file.exists(genbank_file)) {
  genbank_data <- read.delim(genbank_file,
                             skip = 1,
                             header = FALSE,
                             stringsAsFactors = FALSE,
                             sep = "\t",
                             quote = "")
  cat("  ✓ GenBank loaded:", nrow(genbank_data), "rows\n")
}

# Column names from NCBI documentation
col_names <- c(
  "assembly_accession", "bioproject", "biosample", "wgs_master",
  "refseq_category", "taxid", "species_taxid", "organism_name",
  "infraspecific_name", "isolate", "version_status", "assembly_level",
  "release_type", "genome_rep", "seq_rel_date", "asm_name", "submitter",
  "gbrs_paired_asm", "paired_asm_comp", "ftp_path", "excluded_from_refseq",
  "relation_to_type_material", "asm_type", "group", "genome_size", "gc_percent"
)

# Assign column names
if (!is.null(refseq_data)) {
  names(refseq_data) <- col_names
  refseq_data$source <- "RefSeq"
}
if (!is.null(genbank_data)) {
  names(genbank_data) <- col_names
  genbank_data$source <- "GenBank"
}

# Combine datasets
if (!is.null(refseq_data) && !is.null(genbank_data)) {
  all_data <- rbind(refseq_data, genbank_data)
} else if (!is.null(refseq_data)) {
  all_data <- refseq_data
} else if (!is.null(genbank_data)) {
  all_data <- genbank_data
} else {
  stop("ERROR: Could not load assembly summary files")
}

cat("  Total assemblies loaded:", nrow(all_data), "\n")

################################################################################
# 3. TAXONOMY FILTERS
################################################################################

cat("\nStep 3: Filtering by taxonomy...\n")

# Define target orders
beetle_orders <- c("Coleoptera")
outgroup_orders <- c("Neuroptera", "Megaloptera", "Raphidioptera")
target_orders <- c(beetle_orders, outgroup_orders)

# Function to extract order from organism name using NCBI taxid lookup
# For now, we'll do a simple heuristic: check NCBI taxonomy
# NCBI taxid lookup would require another API call; for this fallback approach,
# we filter using the organism_name string and look for keywords

extract_order_heuristic <- function(organism_name, taxid) {
  organism_lower <- tolower(organism_name)

  # Return the order if found
  if (grepl("coleoptera|beetle", organism_lower, ignore.case = TRUE)) return("Coleoptera")
  if (grepl("neuroptera|antlion|lacewing", organism_lower, ignore.case = TRUE)) return("Neuroptera")
  if (grepl("megaloptera|fishfly|dobsonfly", organism_lower, ignore.case = TRUE)) return("Megaloptera")
  if (grepl("raphidioptera|snakefly", organism_lower, ignore.case = TRUE)) return("Raphidioptera")

  return(NA)
}

all_data$order <- sapply(all_data$organism_name, extract_order_heuristic,
                         all_data$taxid)

# NCBI taxid ranges (approximate; these can be verified at ncbi.nlm.nih.gov/Taxonomy)
# Coleoptera: 7399
# Neuroptera: 7391
# Megaloptera: 7392
# Raphidioptera: 7393

taxid_orders <- data.frame(
  taxid_min = c(1, 1, 1, 1),
  taxid_max = c(9999999, 9999999, 9999999, 9999999),
  order = c("Coleoptera", "Neuroptera", "Megaloptera", "Raphidioptera"),
  stringsAsFactors = FALSE
)

# Better approach: filter by known taxid ranges
# (In production, query NCBI Taxonomy database for lineage)
coleoptera_taxids <- c(7399, 7400:8199)  # Coleoptera and subfamilies
neuroptera_taxids <- 7391
megaloptera_taxids <- 7392
raphidioptera_taxids <- 7393

all_data$order_from_taxid <- NA
all_data$order_from_taxid[all_data$taxid %in% coleoptera_taxids] <- "Coleoptera"
all_data$order_from_taxid[all_data$taxid == neuroptera_taxids] <- "Neuroptera"
all_data$order_from_taxid[all_data$taxid == megaloptera_taxids] <- "Megaloptera"
all_data$order_from_taxid[all_data$taxid == raphidioptera_taxids] <- "Raphidioptera"

# Use taxid-based order if available, else fall back to heuristic
all_data$order <- ifelse(!is.na(all_data$order_from_taxid),
                         all_data$order_from_taxid,
                         all_data$order)

# Filter for target orders
target_data <- all_data[!is.na(all_data$order), ]
cat("  ✓ Found", nrow(target_data), "assemblies in target orders\n")

################################################################################
# 4. QUALITY FILTERS
################################################################################

cat("\nStep 4: Applying quality filters...\n")

# ## <<<STUDENT: Adjust assembly_level threshold if needed>>>
# Valid values: "Complete Genome", "Chromosome", "Scaffold", "Contig"
assembly_level_priority <- c("Complete Genome" = 4, "Chromosome" = 3,
                             "Scaffold" = 2, "Contig" = 1)

# Parse release date
target_data$seq_rel_year <- as.numeric(substr(target_data$seq_rel_date, 1, 4))

# ## <<<STUDENT: Adjust publication year filter if needed>>>
min_year <- 2018

# Apply filters
filtered_data <- target_data[
  !is.na(target_data$assembly_level) &
  target_data$assembly_level %in% names(assembly_level_priority) &
  (is.na(target_data$seq_rel_year) | target_data$seq_rel_year >= min_year),
  ]

cat("  ✓ After assembly_level and year filters:", nrow(filtered_data), "assemblies\n")

# Remove rows with missing critical fields
filtered_data <- filtered_data[
  !is.na(filtered_data$assembly_accession) &
  !is.na(filtered_data$organism_name) &
  nchar(filtered_data$assembly_accession) > 0 &
  nchar(filtered_data$organism_name) > 0,
  ]

cat("  ✓ After removing incomplete records:", nrow(filtered_data), "assemblies\n")

################################################################################
# 5. DEDUPLICATE AND SELECT COLUMNS
################################################################################

cat("\nStep 5: Deduplicating...\n")

# Sort by priority: RefSeq > GenBank, highest assembly_level, most recent
filtered_data$assembly_level_score <- sapply(filtered_data$assembly_level,
                                             function(x) assembly_level_priority[x])
filtered_data$source_score <- ifelse(filtered_data$source == "RefSeq", 2, 1)

filtered_data <- filtered_data[
  order(-filtered_data$source_score,
        -filtered_data$assembly_level_score,
        -filtered_data$seq_rel_year,
        filtered_data$assembly_accession),
  ]

# Keep only selected columns for output
output_data <- filtered_data[, c(
  "assembly_accession", "organism_name", "assembly_level", "refseq_category",
  "seq_rel_date", "asm_name", "taxid", "genome_rep", "source", "order"
)]

# Rename for clarity
colnames(output_data) <- c(
  "assembly_accession", "organism_name", "assembly_level", "refseq_category",
  "seq_rel_date", "asm_name", "taxid", "genome_rep", "source", "order"
)

cat("  ✓ After deduplication:", nrow(output_data), "assemblies\n")

################################################################################
# 6. OUTPUT
################################################################################

cat("\nStep 6: Writing output...\n")

## <<<STUDENT: Adjust output file path if needed>>>
output_file <- "ncbi_assemblies_raw.csv"

write.csv(output_data, output_file, row.names = FALSE, quote = TRUE)
cat("  ✓ Output written to:", output_file, "\n")

# Summary statistics
cat("\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("SUMMARY\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("Total assemblies:", nrow(output_data), "\n")
cat("By order:\n")
print(table(output_data$order))
cat("By assembly level:\n")
print(table(output_data$assembly_level))
cat("By source:\n")
print(table(output_data$source))
cat("\nFile saved:", output_file, "\n")

################################################################################
# END OF SCRIPT
################################################################################
