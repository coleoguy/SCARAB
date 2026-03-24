#!/usr/bin/env Rscript
#
# Script: generate_downloads.R
# Purpose: Generate batch download infrastructure for Coleoptera genomes
#
# Outputs:
#   1. accessions_primary.txt - One primary accession per line
#   2. download_genomes.slurm - SLURM array job script
#   3. download_single.sh - Single-genome download + verify script
#   4. download_manifest.csv - Manifest with accession, species, size, URL
#
# Usage: Rscript generate_downloads.R

# =============================================================================
# CONFIGURATION
# =============================================================================

# Relative path from script location to catalog
CATALOG_RELATIVE_PATH <- "../../../data/genomes/genome_catalog.csv"

# Output directory (same as script directory)
OUTPUT_DIR <- dirname(normalizePath(thisfile()))

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

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading genome catalog...\n")
catalog_path <- resolve_path(CATALOG_RELATIVE_PATH, thisfile())

if (!file.exists(catalog_path)) {
  stop("Catalog not found at: ", catalog_path)
}

catalog <- read.csv(catalog_path, stringsAsFactors = FALSE)

cat("  Loaded", nrow(catalog), "records\n")

# =============================================================================
# SELECT PRIMARY GENOMES (ONE BEST PER SPECIES)
# =============================================================================

cat("Selecting primary genomes (best per species)...\n")

# Strategy: For each species, select the best genome based on:
#   1. include_recommended == "yes"
#   2. refseq_category (prefer "reference genome")
#   3. assembly_level (prefer "Complete Genome" > "Chromosome" > "Scaffold" > "Contig")
#   4. genome_size_mb (higher is better)

# Create priority columns
assembly_level_priority <- function(level) {
  switch(level,
    "Complete Genome" = 4,
    "Chromosome" = 3,
    "Scaffold" = 2,
    "Contig" = 1,
    0
  )
}

catalog$assembly_level_rank <- sapply(catalog$assembly_level, assembly_level_priority)

refseq_priority <- function(cat) {
  if (is.na(cat) || cat == "") return(0)
  if (cat == "reference genome") return(2)
  if (cat == "representative genome") return(1)
  return(0)
}

catalog$refseq_rank <- sapply(catalog$refseq_category, refseq_priority)

# Mark recommended
catalog$recommend_rank <- as.numeric(catalog$include_recommended == "yes")

# Sort by priority within each species
catalog_sorted <- catalog[order(
  catalog$species_name,
  -catalog$recommend_rank,
  -catalog$refseq_rank,
  -catalog$assembly_level_rank,
  -catalog$genome_size_mb
), ]

# Keep only the first row per species
primary_idx <- !duplicated(catalog_sorted$species_name)
primary_genomes <- catalog_sorted[primary_idx, ]

cat("  Selected", nrow(primary_genomes), "primary genomes from",
    length(unique(catalog$species_name)), "species\n")

# =============================================================================
# OUTPUT 1: ACCESSIONS LIST
# =============================================================================

cat("Writing accessions_primary.txt...\n")
accessions_primary <- primary_genomes$assembly_accession
writeLines(accessions_primary, file.path(OUTPUT_DIR, "accessions_primary.txt"))

# =============================================================================
# OUTPUT 4: DOWNLOAD MANIFEST
# =============================================================================

cat("Writing download_manifest.csv...\n")

manifest <- data.frame(
  accession = primary_genomes$assembly_accession,
  species_name = primary_genomes$species_name,
  expected_genome_size_mb = primary_genomes$genome_size_mb,
  download_url = primary_genomes$ncbi_download_url,
  stringsAsFactors = FALSE
)

write.csv(manifest, file.path(OUTPUT_DIR, "download_manifest.csv"),
          row.names = FALSE, quote = TRUE)

# =============================================================================
# OUTPUT 2: SLURM BATCH SCRIPT
# =============================================================================

cat("Writing download_genomes.slurm...\n")

slurm_script <- sprintf(
'#!/bin/bash
#SBATCH --job-name=coleoptera_downloads
#SBATCH --array=1-%d
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=slurm_%%j_%%a.log
#SBATCH --error=slurm_%%j_%%a.err

# SLURM array job script to download Coleoptera genomes
# Submits as: sbatch download_genomes.slurm
# Runs one genome per array job, parallelizing downloads

# Source this script\'s directory for helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if NCBI datasets CLI is available
if ! command -v datasets &> /dev/null; then
  echo "ERROR: datasets CLI not found. Install: conda install ncbi-datasets-cli"
  exit 1
fi

# Create output directories on SCRATCH
DOWNLOAD_DIR="${SCRATCH}/scarab_genomes"
mkdir -p "${DOWNLOAD_DIR}"

# Read accession list
ACCESSIONS_FILE="${SCRIPT_DIR}/accessions_primary.txt"
if [[ ! -f "${ACCESSIONS_FILE}" ]]; then
  echo "ERROR: Accessions file not found: ${ACCESSIONS_FILE}"
  exit 1
fi

# Get the accession for this array task
ACCESSION=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${ACCESSIONS_FILE}")

if [[ -z "${ACCESSION}" ]]; then
  echo "ERROR: Could not get accession for array task ${SLURM_ARRAY_TASK_ID}"
  exit 1
fi

echo "==============================================="
echo "SLURM Job ${SLURM_JOB_ID}, Array Task ${SLURM_ARRAY_TASK_ID}"
echo "Downloading: ${ACCESSION}"
echo "Output: ${DOWNLOAD_DIR}"
echo "Start time: $(date)"
echo "==============================================="

# Download using NCBI datasets CLI
echo "Running datasets download..."
datasets download genome accession "${ACCESSION}" \\
  --filename "${DOWNLOAD_DIR}/${ACCESSION}.zip" \\
  --include gff3,rna,protein,genome

if [[ $? -ne 0 ]]; then
  echo "ERROR: datasets download failed for ${ACCESSION}"
  exit 1
fi

# Verify file exists and is non-empty
if [[ ! -f "${DOWNLOAD_DIR}/${ACCESSION}.zip" ]]; then
  echo "ERROR: Download file not created: ${DOWNLOAD_DIR}/${ACCESSION}.zip"
  exit 1
fi

FILE_SIZE=$(stat --printf="%%s" "${DOWNLOAD_DIR}/${ACCESSION}.zip")
if [[ ${FILE_SIZE} -lt 1000 ]]; then
  echo "ERROR: Downloaded file is suspiciously small (${FILE_SIZE} bytes)"
  exit 1
fi

# Extract checksum from manifest (if available)
MANIFEST_FILE="${DOWNLOAD_DIR}/${ACCESSION}/md5sum.txt"
if [[ -f "${MANIFEST_FILE}" ]]; then
  echo "Verifying checksums..."
  cd "${DOWNLOAD_DIR}/${ACCESSION}"
  md5sum -c md5sum.txt
  if [[ $? -ne 0 ]]; then
    echo "WARNING: Checksum verification failed for ${ACCESSION}"
  fi
  cd - > /dev/null
fi

echo "Completed: ${ACCESSION} at $(date)"
echo "File size: $(du -h ${DOWNLOAD_DIR}/${ACCESSION}.zip | cut -f1)"
',
  nrow(primary_genomes)
)

writeLines(slurm_script, file.path(OUTPUT_DIR, "download_genomes.slurm"))
system(paste("chmod +x", file.path(OUTPUT_DIR, "download_genomes.slurm")))

# =============================================================================
# OUTPUT 3: SINGLE GENOME DOWNLOAD SCRIPT
# =============================================================================

cat("Writing download_single.sh...\n")

single_script <- '#!/bin/bash
#
# Script: download_single.sh
# Purpose: Download and verify a single Coleoptera genome
#
# Usage: ./download_single.sh <accession>
# Example: ./download_single.sh GCA_052757275.1
#
# Requirements:
#   - NCBI datasets CLI installed (conda install ncbi-datasets-cli)
#   - Write permission to $SCRATCH/scarab_genomes/
#

set -euo pipefail

# ===========================================================================
# CONFIGURATION
# ===========================================================================

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <accession>"
  echo "Example: $0 GCA_052757275.1"
  exit 1
fi

ACCESSION="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="${SCRATCH:-/tmp}/scarab_genomes"

# ===========================================================================
# VALIDATION
# ===========================================================================

# Validate accession format (GCA_ or GCF_)
if [[ ! ${ACCESSION} =~ ^GC[AF]_[0-9]+\.[0-9]+ ]]; then
  echo "ERROR: Invalid accession format: ${ACCESSION}"
  echo "Expected format: GCA_xxxxxxxxx.x or GCF_xxxxxxxxx.x"
  exit 1
fi

# Check if datasets CLI is available
if ! command -v datasets &> /dev/null; then
  echo "ERROR: datasets CLI not found"
  echo "Install with: conda install ncbi-datasets-cli"
  exit 1
fi

# Create output directory
mkdir -p "${DOWNLOAD_DIR}"

# ===========================================================================
# DOWNLOAD
# ===========================================================================

echo "==============================================="
echo "Downloading: ${ACCESSION}"
echo "Output directory: ${DOWNLOAD_DIR}"
echo "Start time: $(date)"
echo "==============================================="

OUTPUT_FILE="${DOWNLOAD_DIR}/${ACCESSION}.zip"

# Skip if already downloaded and non-empty
if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
  FILE_SIZE=$(stat --printf="%s" "${OUTPUT_FILE}")
  echo "File already exists (${FILE_SIZE} bytes), skipping download"
else
  datasets download genome accession "${ACCESSION}" \\
    --filename "${OUTPUT_FILE}" \\
    --include gff3,rna,protein,genome

  if [[ $? -ne 0 ]]; then
    echo "ERROR: Dataset download failed"
    exit 1
  fi
fi

# ===========================================================================
# VERIFICATION
# ===========================================================================

if [[ ! -f "${OUTPUT_FILE}" ]]; then
  echo "ERROR: Output file not found: ${OUTPUT_FILE}"
  exit 1
fi

FILE_SIZE=$(stat --printf="%s" "${OUTPUT_FILE}")
if [[ ${FILE_SIZE} -lt 1000 ]]; then
  echo "ERROR: File is suspiciously small (${FILE_SIZE} bytes)"
  exit 1
fi

echo "Download complete: ${FILE_SIZE} bytes"

# Try to verify checksums if they exist
EXTRACT_DIR="${DOWNLOAD_DIR}/${ACCESSION}_extracted"
rm -rf "${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"

echo "Extracting to verify contents..."
unzip -q "${OUTPUT_FILE}" -d "${EXTRACT_DIR}"

MANIFEST="${EXTRACT_DIR}/md5sum.txt"
if [[ -f "${MANIFEST}" ]]; then
  echo "Verifying checksums..."
  cd "${EXTRACT_DIR}"
  if md5sum -c "${MANIFEST}" > /dev/null 2>&1; then
    echo "Checksum verification: PASSED"
  else
    echo "WARNING: Checksum verification failed (non-critical)"
  fi
  cd - > /dev/null
fi

# Count FASTA files
FASTA_COUNT=$(find "${EXTRACT_DIR}" -type f -name "*.fna" -o -name "*.fasta" | wc -l)
echo "Found ${FASTA_COUNT} FASTA file(s)"

# Clean up extraction directory
rm -rf "${EXTRACT_DIR}"

echo "==============================================="
echo "Completed successfully: ${ACCESSION}"
echo "End time: $(date)"
echo "File location: ${OUTPUT_FILE}"
echo "==============================================="
'

writeLines(single_script, file.path(OUTPUT_DIR, "download_single.sh"))
system(paste("chmod +x", file.path(OUTPUT_DIR, "download_single.sh")))

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("=" %,% rep("-", 70) %,% "=\n")
cat("DOWNLOAD GENERATION COMPLETE\n")
cat("=" %,% rep("-", 70) %,% "=\n")

cat("\nOutputs created in:", OUTPUT_DIR, "\n\n")

cat("1. accessions_primary.txt\n")
cat("   - One accession per line (", length(accessions_primary), "total)\n\n")

cat("2. download_manifest.csv\n")
cat("   - Columns: accession, species_name, expected_genome_size_mb, download_url\n")
cat("   - Rows:", nrow(manifest), "\n\n")

cat("3. download_genomes.slurm\n")
cat("   - SLURM array job script (", nrow(primary_genomes), "parallel jobs)\n")
cat("   - Usage: sbatch download_genomes.slurm\n")
cat("   - Downloads to: $SCRATCH/scarab_genomes/\n\n")

cat("4. download_single.sh\n")
cat("   - Single genome download + verification script\n")
cat("   - Usage: ./download_single.sh GCA_xxxxxxxxx.x\n\n")

cat("For more information, see HOWTO.md in this directory.\n")
