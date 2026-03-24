#!/usr/bin/env Rscript
################################################################################
# TASK: PHASE_1.4 - Phylogenetic Placement of Taxa
################################################################################
#
# OBJECTIVE:
# Read merged_genomes.csv.
# For each species, look up taxonomic lineage using NCBI Taxonomy database.
# Classify into major beetle clades and suborders.
# Flag QC issues (missing taxonomy, uncertain placement, etc.).
# Output curated genome list with phylogenetic metadata.
#
# INPUTS:
#   - PHASE_1.3 output: merged_genomes.csv
#   - NCBI Taxonomy database (downloaded or queried)
#
# OUTPUTS:
#   - curated_genomes.csv (columns: species_name, assembly_accession,
#     assembly_level, source, family, subfamily, order_type,
#     clade_assignment, qc_flags, notes)
#
# STUDENT TODO:
#   - Set working directory (line ~60)
#   - Provide family assignments for beetle taxa (lines ~150-200)
#   - Define clade membership rules (lines ~250-280)
#   - Set NCBI taxonomy database path or query method (line ~120)
#   - Review and customize QC flags (lines ~350-370)
#   - Verify output path (line ~400)
#
# NOTES:
#   - This script uses static taxonomy lookup tables as fallback
#   - For production, integrate with ete3 or taxonkit
#   - Some species may require manual family/subfamily assignment
#
################################################################################

library(base)

# Suppress warnings
options(warn = -1)

cat("PHASE_1.4: Phylogenetic Placement of Taxa\n")
cat("==========================================\n\n")

## <<<STUDENT: Set your working directory if running standalone>>>
# setwd("[PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.4_phylogenetic_placement")

if (!dir.exists("data")) {
  dir.create("data", showWarnings = FALSE, recursive = TRUE)
}

################################################################################
# 1. LOAD INPUT DATA
################################################################################

cat("Step 1: Loading input data...\n")

## <<<STUDENT: Verify path to input file>>>
input_file <- "../PHASE_1.3_merge_deduplicate/merged_genomes.csv"

if (!file.exists(input_file)) {
  cat("  ✗ Input file not found:", input_file, "\n")
  quit(status = 1)
}

genomes <- read.csv(input_file, stringsAsFactors = FALSE)
cat("  ✓ Loaded", nrow(genomes), "genomes\n")

################################################################################
# 2. TAXONOMY LOOKUP TABLES
################################################################################

cat("\nStep 2: Setting up taxonomy lookup tables...\n")

# Major beetle families (Coleoptera taxonomy simplified)
# This is a curated list; production would use full NCBI Taxonomy database
## <<<STUDENT: Expand and verify family assignments for your dataset>>>

family_lookup <- data.frame(
  genus_pattern = c(
    "Tribolium", "Dendroctonus", "Ips", "Agrilus", "Chrysomela",
    "Drosophila",  # outgroup (Diptera)
    "Anopheles",  # outgroup (Diptera)
    "Heliconius",  # outgroup (Lepidoptera)
    "Bombyx",  # outgroup (Lepidoptera)
    "Tenebrio", "Alphus", "Staphylococcus"  # More beetles
  ),
  family = c(
    "Tenebrionidae", "Curculionidae", "Scolytidae", "Buprestidae", "Chrysomelidae",
    "Drosophilidae", "Culicidae", "Nymphalidae", "Bombycidae",
    "Tenebrionidae", "Cerambycidae", "Cerambycidae"
  ),
  subfamily = c(
    "Triboliinae", NA, NA, NA, "Chrysomelinae",
    NA, NA, NA, NA,
    "Tenebrioidinae", NA, NA
  ),
  clade = c(
    "Polyphaga", "Polyphaga", "Polyphaga", "Polyphaga", "Polyphaga",
    "Insecta", "Insecta", "Insecta", "Insecta",
    "Polyphaga", "Polyphaga", "Polyphaga"
  ),
  suborder = c(
    "Cucujiformia", "Cucujiformia", "Cucujiformia", "Elateriformia", "Cucujiformia",
    NA, NA, NA, NA,
    "Cucujiformia", "Cerambycoidea", "Cerambycoidea"
  ),
  stringsAsFactors = FALSE
)

cat("  ✓ Family lookup table created\n")

# Major clade definitions for Coleoptera
# (Based on standard beetle phylogeny: Adephaga, Polyphaga)
clade_definitions <- data.frame(
  clade = c("Adephaga", "Polyphaga", "Polyphaga"),
  suborder = c("Adephaga", "Cucujiformia", "Elateriformia"),
  description = c(
    "Ground beetles, water beetles (Carabidae, Dytiscidae)",
    "Leaf beetles, grain beetles, weevils",
    "Click beetles, bark lice"
  ),
  stringsAsFactors = FALSE
)

cat("  ✓ Clade definitions created\n")

################################################################################
# 3. EXTRACT FAMILY FROM SPECIES NAME
################################################################################

cat("\nStep 3: Extracting taxonomy from species names...\n")

# Extract genus (first word)
genomes$genus <- sapply(strsplit(genomes$species_name, " "), function(x) {
  if (length(x) > 0) x[1] else NA
})

# Look up family for each genus
genomes$family <- NA
genomes$subfamily <- NA
genomes$clade <- NA
genomes$suborder <- NA

for (i in seq_len(nrow(genomes))) {
  genus <- genomes$genus[i]

  # Try exact match first
  match_idx <- which(family_lookup$genus_pattern == genus)

  # Try partial match (genus contains pattern)
  if (length(match_idx) == 0) {
    match_idx <- which(grepl(paste0("^", genus), family_lookup$genus_pattern))
  }

  if (length(match_idx) > 0) {
    # Use first match
    idx <- match_idx[1]
    genomes$family[i] <- family_lookup$family[idx]
    genomes$subfamily[i] <- family_lookup$subfamily[idx]
    genomes$clade[i] <- family_lookup$clade[idx]
    genomes$suborder[i] <- family_lookup$suborder[idx]
  }
}

cat("  ✓ Extracted family/subfamily for", sum(!is.na(genomes$family)),
    "of", nrow(genomes), "species\n")

################################################################################
# 4. CLADE ASSIGNMENT
################################################################################

cat("\nStep 4: Assigning phylogenetic clades...\n")

# Define clade assignment rules
# (In practice, this would query NCBI or use published phylogenies)
assign_clade <- function(order, family, suborder) {
  if (is.na(order)) return(NA)

  order_lower <- tolower(order)

  # Check if Coleoptera
  if (!grepl("coleoptera", order_lower)) {
    return("Non-Coleoptera")
  }

  # For Coleoptera, use suborder or family hints
  if (!is.na(suborder)) {
    if (grepl("Adephaga", suborder, ignore.case = TRUE)) {
      return("Adephaga")
    } else if (grepl("Polyphaga", suborder, ignore.case = TRUE)) {
      return("Polyphaga")
    } else if (grepl("Archostemata", suborder, ignore.case = TRUE)) {
      return("Archostemata")
    } else {
      return("Polyphaga (unspecified)")
    }
  }

  # Fallback: guess from family
  if (!is.na(family)) {
    adephagan_families <- c("Carabidae", "Dytiscidae", "Gyrinidae", "Rhysodidae")
    if (family %in% adephagan_families) {
      return("Adephaga")
    } else {
      return("Polyphaga (inferred)")
    }
  }

  return("Coleoptera (unspecified)")
}

genomes$clade_assignment <- mapply(
  assign_clade,
  genomes$order,
  genomes$family,
  genomes$suborder
)

cat("  ✓ Clade assignments complete\n")

################################################################################
# 5. QC FLAGS
################################################################################

cat("\nStep 5: Flagging QC issues...\n")

genomes$qc_flags <- ""

# Flag missing taxonomy
missing_family <- is.na(genomes$family) | nchar(genomes$family) == 0
genomes$qc_flags[missing_family] <- paste0(
  genomes$qc_flags[missing_family],
  "MISSING_FAMILY;"
)

# Flag uncertain placement
uncertain_clade <- grepl("unspecified|inferred", genomes$clade_assignment)
genomes$qc_flags[uncertain_clade] <- paste0(
  genomes$qc_flags[uncertain_clade],
  "UNCERTAIN_CLADE;"
)

# Flag non-Coleoptera in dataset
non_beetle <- grepl("Non-Coleoptera", genomes$clade_assignment)
genomes$qc_flags[non_beetle] <- paste0(
  genomes$qc_flags[non_beetle],
  "NON_COLEOPTERA;"
)

# Flag low-quality assemblies
## <<<STUDENT: Adjust assembly_level threshold if needed>>>
low_quality <- genomes$assembly_level %in% c("Contig", NA)
genomes$qc_flags[low_quality] <- paste0(
  genomes$qc_flags[low_quality],
  "LOW_ASSEMBLY_QUALITY;"
)

# Clean up trailing semicolons
genomes$qc_flags <- gsub(";$", "", genomes$qc_flags)
genomes$qc_flags[nchar(genomes$qc_flags) == 0] <- NA

cat("  ✓ QC flags assigned\n")
cat("    ", sum(!is.na(genomes$qc_flags)), "genomes have QC flags\n")

################################################################################
# 6. NOTES FIELD
################################################################################

cat("\nStep 6: Adding notes...\n")

genomes$notes <- ""

# Add notes for flagged genomes
for (i in seq_len(nrow(genomes))) {
  notes <- c()

  if (!is.na(genomes$qc_flags[i])) {
    flags <- strsplit(genomes$qc_flags[i], ";")[[1]]

    if ("MISSING_FAMILY" %in% flags) {
      notes <- c(notes, "Genus not in reference taxonomy; requires manual curation")
    }

    if ("NON_COLEOPTERA" %in% flags) {
      notes <- c(notes, "Outgroup species (Neuroptera/Megaloptera/Raphidioptera)")
    }

    if ("LOW_ASSEMBLY_QUALITY" %in% flags) {
      notes <- c(notes, "Low assembly quality (contig-level); use with caution")
    }
  }

  genomes$notes[i] <- paste(notes, collapse = "; ")
}

genomes$notes[nchar(genomes$notes) == 0] <- NA

cat("  ✓ Notes added\n")

################################################################################
# 7. SELECT OUTPUT COLUMNS
################################################################################

cat("\nStep 7: Preparing output...\n")

# Select and order columns
output_cols <- c(
  "species_name", "assembly_accession", "asm_name", "assembly_level", "source",
  "genus", "family", "subfamily", "clade_assignment", "suborder",
  "qc_flags", "notes"
)

output_cols <- output_cols[output_cols %in% names(genomes)]

output_df <- genomes[, output_cols]

# Sort by clade, family, species
output_df <- output_df[
  order(output_df$clade_assignment,
        output_df$family,
        output_df$species_name),
  ]

cat("  ✓ Output prepared:", nrow(output_df), "genomes\n")

################################################################################
# 8. OUTPUT
################################################################################

cat("\nStep 8: Writing output...\n")

## <<<STUDENT: Adjust output file path if needed>>>
output_file <- "curated_genomes.csv"

write.csv(output_df, output_file, row.names = FALSE, quote = TRUE)
cat("  ✓ Output written to:", output_file, "\n")

# Summary statistics
cat("\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("SUMMARY\n" %s+% strrep("=", 50) %s+% "\n", sep = "")
cat("Total genomes:", nrow(output_df), "\n")

if ("clade_assignment" %in% names(output_df)) {
  cat("By clade:\n")
  print(table(output_df$clade_assignment))
}

if ("assembly_level" %in% names(output_df)) {
  cat("By assembly level:\n")
  print(table(output_df$assembly_level))
}

qc_flagged <- sum(!is.na(output_df$qc_flags))
cat("\nQC flagged:", qc_flagged, "genomes\n")

if (qc_flagged > 0) {
  cat("QC flag breakdown:\n")
  all_flags <- strsplit(output_df$qc_flags[!is.na(output_df$qc_flags)], ";")
  all_flags <- unlist(all_flags)
  print(table(all_flags))
}

cat("\nFile saved:", output_file, "\n")

################################################################################
# END OF SCRIPT
################################################################################
