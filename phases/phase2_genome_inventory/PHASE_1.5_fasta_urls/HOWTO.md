# HOWTO 2.5: Retrieve FASTA URLs & Validate Checksums

**Phase:** Phase 2 - Genome Inventory & QC
**Task:** 2.5 Retrieve and Validate FTP URLs for All Selected Genomes
**Timeline:** Day 5-6 (~1 full day, can run in parallel with Task 2.4 after Task 2.3 complete)
**Executor:** Team

---

## OBJECTIVE

For each genome marked include_yn="YES" in the curated inventory, retrieve the public FTP URL pointing to the genomic FASTA file (or full assembly bundle). Test all URLs for accessibility. Compute or download MD5/SHA256 checksums for data integrity verification. Create a manifest of FTP URLs and checksums for Phase 3 downloads.

**Output acceptance criteria:** All FTP URLs tested and accessible, all checksums present and validated, no errors or dead links

---

## INPUT

**From Task 2.4:** `SCARAB/data/genomes/curated_genomes.csv` (rows where include_yn="YES")

---

## OUTPUTS (Exact Filenames & Locations)

### Output 1: FASTA URLs Manifest
**Path:** `SCARAB/data/genomes/fasta_urls.csv`

**Format:** CSV with columns (in order):

```
organism,assembly_accession,source,ftp_url,file_type,total_bp,contig_count,checksum_type,checksum_value,url_status,last_verified
```

**Column definitions:**

- `organism` (string): Species name (e.g., "Tribolium castaneum")
- `assembly_accession` (string): NCBI RefSeq/GenBank or Ensembl accession
- `source` (string): "NCBI_RefSeq", "NCBI_GenBank", or "Ensembl"
- `ftp_url` (string): Complete FTP or HTTP URL to genome FASTA file
  - Example NCBI: `ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/GCF_000001825.4_Release_100_genomic.fna.gz`
  - Example Ensembl: `ftp://ftp.ensemblgenomes.org/pub/metazoa/release-60/fasta/tribolium_castaneum/dna/Tribolium_castaneum.TNAU.dna.toplevel.fa.gz`
- `file_type` (string): "genomic_fasta" or "dna_fasta" (both are acceptable)
- `total_bp` (integer): Total base pairs in genome (if available from metadata)
- `contig_count` (integer): Number of contigs/scaffolds (if available)
- `checksum_type` (string): "MD5" or "SHA256"
- `checksum_value` (string): Hex hash value (e.g., "abc123def456...")
- `url_status` (string): "ACCESSIBLE", "NOT_FOUND", or "TIMEOUT" (from testing)
- `last_verified` (date): Date URL was last tested (YYYY-MM-DD)

**Example rows:**

```
Tribolium castaneum,GCF_000001825.4,NCBI_RefSeq,ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/GCF_000001825.4_Release_100_genomic.fna.gz,genomic_fasta,139300000,16,MD5,a1b2c3d4e5f6...,ACCESSIBLE,2026-03-21
Dendroctonus ponderosae,GCA_000355325.1,NCBI_GenBank,ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/355/325/GCA_000355325.1_DendPond_1.0/GCA_000355325.1_DendPond_1.0_genomic.fna.gz,genomic_fasta,210500000,48,MD5,f6e5d4c3b2a1...,ACCESSIBLE,2026-03-21
```

---

### Output 2: Genome Checksums File
**Path:** `SCARAB/data/genomes/genome_checksums.txt`

**Format:** Plain text, one checksum per line, in format:
```
<checksum>  <filename>
```

**Example:**
```
a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4  Tribolium_castaneum_GCF_000001825.4.fna.gz
f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3  Dendroctonus_ponderosae_GCA_000355325.1.fna.gz
```

**Purpose:** Can be used with `md5sum -c genome_checksums.txt` to verify downloaded files

---

## WORKFLOW

### Step 1: Identify FTP URLs for NCBI RefSeq/GenBank Genomes

For each NCBI genome (assembly_accession starting with GCF or GCA):

**Method A: NCBI FTP Direct Construction (Fastest)**

NCBI follows a predictable FTP path structure:
```
ftp://ftp.ncbi.nlm.nih.gov/genomes/all/{GCF|GCA}/{prefix}/{middle}/{suffix}/
```

Where prefix, middle, suffix are derived from assembly accession:
- Accession: `GCF_000001825.4`
- GCF → `GCF`
- First 3 digits (000) → `000`
- Next 3 digits (001) → `001`
- Next 3 digits (825) → `825`
- Full version → `GCF_000001825.4_Release_100/` (or just `GCF_000001825.4_DendPond_1.0/` depending on assembly name)

**Full URL:**
```
ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/
```

Then list directory for `*_genomic.fna.gz` file.

```bash
# Example: Get FTP URL for assembly GCF_000001825.4
prefix=$(echo "GCF_000001825.4" | cut -d_ -f2 | cut -c1-3)  # 000
middle=$(echo "GCF_000001825.4" | cut -d_ -f2 | cut -c4-6)  # 001
suffix=$(echo "GCF_000001825.4" | cut -d_ -f2 | cut -c7-9)  # 825
version=$(echo "GCF_000001825.4")

# Construct base URL
base_url="ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/$prefix/$middle/$suffix/${version}_*/"

# List directory (requires lftp or curl)
lftp -e "ls $base_url; quit" | grep "_genomic.fna.gz"
```

**Method B: Query NCBI Assembly Metadata Programmatically (More Robust)**

```r
library(httr)
library(jsonlite)
library(dplyr)

get_ncbi_ftp_url <- function(assembly_accession) {
  # Fetch assembly metadata from NCBI
  url <- paste0("https://www.ncbi.nlm.nih.gov/genomes/all/",
                strsplit(assembly_accession, "_")[[1]][1], "/")

  # Construct path from accession
  parts <- strsplit(assembly_accession, "_")[[1]]
  prefix <- substr(parts[2], 1, 3)
  middle <- substr(parts[2], 4, 6)
  suffix <- substr(parts[2], 7, 9)
  version <- assembly_accession

  base_url <- paste0("ftp://ftp.ncbi.nlm.nih.gov/genomes/all/",
                     strsplit(assembly_accession, "_")[[1]][1], "/",
                     prefix, "/", middle, "/", suffix, "/")

  # Use curl to list directory
  cmd <- paste0("curl -s -l '", base_url, "' | grep '_genomic.fna.gz' | head -1")
  filename <- system(cmd, intern = TRUE)

  if (length(filename) > 0 && filename != "") {
    return(paste0(base_url, filename))
  } else {
    return(NA)
  }
}

# Test
url <- get_ncbi_ftp_url("GCF_000001825.4")
print(url)
```

---

### Step 2: Identify FTP URLs for Ensembl Genomes

For each Ensembl genome:

**Method: Ensembl FTP Structure**

Ensembl organizes genomes by species:
```
ftp://ftp.ensemblgenomes.org/pub/metazoa/release-{N}/fasta/{species_name}/dna/
```

Where:
- `{N}` is release number (e.g., 60)
- `{species_name}` is lowercase with underscores (e.g., `tribolium_castaneum`)
- Files: `*_dna_toplevel.fa.gz` or `*_dna.toplevel.fa.gz`

**Example:**
```
ftp://ftp.ensemblgenomes.org/pub/metazoa/release-60/fasta/tribolium_castaneum/dna/Tribolium_castaneum.TNAU.dna.toplevel.fa.gz
```

**How to find:**
1. Extract organism name from curated_genomes.csv
2. Convert to lowercase and replace spaces with underscores
3. Construct FTP URL pattern
4. Use curl/wget to test accessibility

```bash
# Example
species="Tribolium castaneum"
species_lower=$(echo "$species" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
base_url="ftp://ftp.ensemblgenomes.org/pub/metazoa/release-60/fasta/${species_lower}/dna/"

# List directory
curl -s -l "$base_url" | grep "_dna.toplevel.fa.gz"
```

---

### Step 3: Test URL Accessibility

For each URL, test that it exists and is accessible:

```bash
# Simple test with curl (returns HTTP status)
curl -I -s "$ftp_url" | head -1

# Or use wget
wget --spider "$ftp_url" 2>&1 | grep -q "HTTP" && echo "ACCESSIBLE" || echo "NOT_FOUND"
```

**R version:**

```r
test_url_accessibility <- function(url) {
  tryCatch({
    response <- HEAD(url, timeout(5))
    if (status_code(response) == 200) {
      return("ACCESSIBLE")
    } else {
      return(paste0("HTTP_", status_code(response)))
    }
  }, error = function(e) {
    return("TIMEOUT")
  })
}

# Test all URLs
fasta_urls$url_status <- sapply(fasta_urls$ftp_url, test_url_accessibility)
```

---

### Step 4: Retrieve Checksums

For each genome, retrieve the checksum file:

**NCBI:** Checksum files are in same directory as genome FASTA

```bash
# NCBI checksum file (usually md5checksums.txt)
# URL: same FTP directory as genome FASTA, file = "md5checksums.txt"
# Example:
# ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/md5checksums.txt

curl -s "ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/md5checksums.txt" | \
  grep "_genomic.fna.gz"
```

**Ensembl:** Checksum files available on Ensembl FTP

```bash
# Ensembl checksum file pattern:
# ftp://ftp.ensemblgenomes.org/pub/metazoa/release-60/fasta/{species}/dna/CHECKSUMS

curl -s "ftp://ftp.ensemblgenomes.org/pub/metazoa/release-60/fasta/tribolium_castaneum/dna/CHECKSUMS" | \
  grep "_dna.toplevel.fa.gz"
```

---

### Step 5: Build Manifest (R Workflow)

```r
library(dplyr)
library(tidyr)
library(httr)

# Load curated genomes (include_yn = YES only)
curated <- read.csv("SCARAB/data/genomes/curated_genomes.csv", stringsAsFactors = FALSE)
selected <- curated %>% filter(include_yn == "YES")

cat(paste("Processing", nrow(selected), "selected genomes\n"))

# Initialize output dataframe
fasta_urls <- data.frame(
  organism = selected$organism,
  assembly_accession = selected$assembly_accession,
  source = selected$source,
  ftp_url = NA_character_,
  file_type = NA_character_,
  total_bp = NA_integer_,
  contig_count = NA_integer_,
  checksum_type = NA_character_,
  checksum_value = NA_character_,
  url_status = NA_character_,
  last_verified = Sys.Date(),
  stringsAsFactors = FALSE
)

# For each genome, populate FTP URL and checksum
for (i in 1:nrow(fasta_urls)) {
  cat(paste("[", i, "/", nrow(fasta_urls), "] Processing", fasta_urls$organism[i], "\n"))

  accession <- fasta_urls$assembly_accession[i]
  source <- fasta_urls$source[i]

  if (source == "NCBI_RefSeq" || source == "NCBI_GenBank") {
    # NCBI URL construction
    prefix <- substr(accession, 5, 7)
    middle <- substr(accession, 8, 10)
    suffix <- substr(accession, 11, 13)

    base_url <- paste0("ftp://ftp.ncbi.nlm.nih.gov/genomes/all/",
                       substr(accession, 1, 3), "/",
                       prefix, "/", middle, "/", suffix, "/")

    # List directory and find genomic FASTA
    cmd <- paste0("curl -s -l '", base_url, "' 2>/dev/null | grep '_genomic.fna.gz' | head -1")
    filename <- system(cmd, intern = TRUE)

    if (length(filename) > 0 && filename != "") {
      fasta_urls$ftp_url[i] <- paste0(base_url, filename)
      fasta_urls$file_type[i] <- "genomic_fasta"
      fasta_urls$url_status[i] <- "PENDING"  # Will test below

      # Get checksum
      cmd_checksum <- paste0("curl -s '", base_url, "md5checksums.txt' 2>/dev/null | grep '", filename, "'")
      checksum_line <- system(cmd_checksum, intern = TRUE)
      if (length(checksum_line) > 0 && checksum_line != "") {
        parts <- strsplit(checksum_line, "\\s+")[[1]]
        fasta_urls$checksum_value[i] <- parts[1]
        fasta_urls$checksum_type[i] <- "MD5"
      }
    }
  } else if (source == "Ensembl") {
    # Ensembl URL construction
    species_lower <- tolower(gsub(" ", "_", fasta_urls$organism[i]))

    base_url <- paste0("ftp://ftp.ensemblgenomes.org/pub/metazoa/release-60/fasta/",
                       species_lower, "/dna/")

    # List directory and find dna FASTA
    cmd <- paste0("curl -s -l '", base_url, "' 2>/dev/null | grep '_dna.toplevel.fa.gz' | head -1")
    filename <- system(cmd, intern = TRUE)

    if (length(filename) > 0 && filename != "") {
      fasta_urls$ftp_url[i] <- paste0(base_url, filename)
      fasta_urls$file_type[i] <- "dna_fasta"
      fasta_urls$url_status[i] <- "PENDING"

      # Get checksum
      cmd_checksum <- paste0("curl -s '", base_url, "CHECKSUMS' 2>/dev/null | grep '", filename, "'")
      checksum_line <- system(cmd_checksum, intern = TRUE)
      if (length(checksum_line) > 0 && checksum_line != "") {
        parts <- strsplit(trimws(checksum_line), "\\s+")[[1]]
        # Ensembl CHECKSUMS format varies; common: "hash filename"
        if (length(parts) >= 2) {
          fasta_urls$checksum_value[i] <- parts[1]
          fasta_urls$checksum_type[i] <- "SHA256"  # Often SHA256 for Ensembl
        }
      }
    }
  }
}

# Test URL accessibility
cat("Testing URL accessibility...\n")
for (i in which(!is.na(fasta_urls$ftp_url))) {
  url <- fasta_urls$ftp_url[i]
  status <- tryCatch({
    response <- HEAD(url, timeout(5))
    if (status_code(response) %in% c(200, 226)) {  # 226 = FTP success
      "ACCESSIBLE"
    } else {
      paste0("HTTP_", status_code(response))
    }
  }, error = function(e) {
    "TIMEOUT"
  })
  fasta_urls$url_status[i] <- status
  cat(paste("  ", i, "/", nrow(fasta_urls), ": ", status, "\n"))
}

# Save FASTA URLs CSV
write.csv(fasta_urls, "SCARAB/data/genomes/fasta_urls.csv", row.names = FALSE)

# Save checksums file
checksum_file <- fasta_urls %>%
  filter(!is.na(checksum_value)) %>%
  mutate(formatted_line = paste(checksum_value, "  ",
                                 sub(".*/", "", ftp_url)))

write.table(checksum_file$formatted_line,
            "SCARAB/data/genomes/genome_checksums.txt",
            quote = FALSE,
            row.names = FALSE,
            col.names = FALSE)

# Summary
cat("\n=== SUMMARY ===\n")
cat(paste("Total genomes processed:", nrow(fasta_urls), "\n"))
cat(paste("URLs found:", sum(!is.na(fasta_urls$ftp_url)), "\n"))
cat(paste("URLs accessible:", sum(fasta_urls$url_status == "ACCESSIBLE", na.rm = TRUE), "\n"))
cat(paste("Checksums retrieved:", sum(!is.na(fasta_urls$checksum_value)), "\n"))

# Report any issues
issues <- fasta_urls %>% filter(is.na(ftp_url) | url_status != "ACCESSIBLE")
if (nrow(issues) > 0) {
  cat(paste("\nWARNING:", nrow(issues), "genomes have issues:\n"))
  print(issues %>% select(organism, assembly_accession, ftp_url, url_status))
}
```

---

## ACCEPTANCE CRITERIA

Task 2.5 is complete when:

- [ ] `fasta_urls.csv` contains one row per selected genome (≥50 rows)
- [ ] All 11 columns populated (no critical NAs)
- [ ] All FTP URLs tested: `url_status` = "ACCESSIBLE" for ≥99% of genomes
- [ ] All checksums present: `checksum_value` populated for ≥90% of genomes
- [ ] `url_status` is one of: "ACCESSIBLE", "NOT_FOUND", "TIMEOUT"
- [ ] `checksum_type` is "MD5" or "SHA256"
- [ ] `genome_checksums.txt` contains one checksum per line (format: `hash  filename`)
- [ ] Files saved in exact paths:
  - `SCARAB/data/genomes/fasta_urls.csv`
  - `SCARAB/data/genomes/genome_checksums.txt`
- [ ] Any URLs with status != "ACCESSIBLE" are documented (reason noted if known)

---

---

## WHAT ACTUALLY HAPPENED (2026-03-21)

The original workflow above (FTP URL retrieval + checksum validation) was designed before we had the full genome list. In practice, we used the **NCBI Datasets API v2** to download genomes directly, bypassing FTP URL construction.

### Actual Download Method

**Script used:** `scripts/phase2/download_login.sh`

Instead of building a manifest of FTP URLs and downloading later, we:
1. Generated `accessions_to_download.txt` (438 accessions from genome_catalog_primary.csv)
2. Used the NCBI Datasets REST API v2 endpoint to download zip bundles containing FASTA + GFF
3. Ran downloads on Grace **login node** (not compute nodes — see note below)

### Key Discovery: Grace Compute Nodes Have No Internet

- **SLURM array job** (`download_genomes.slurm`) was attempted first (Jobs 18105136, 18105710)
- All 438 tasks failed with `curl exit code 7` (connection refused)
- **Root cause:** Grace compute nodes are isolated from the internet
- **Solution:** `download_login.sh` runs on the login node with 4 parallel curl processes, staying within the 8-core login node limit
- Backgrounded with `nohup` (screen and tmux not available on Grace)

### Downloads API Endpoint

```
https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/{ACC}/download?include_annotation_type=GENOME_FASTA,GENOME_GFF&filename={ACC}.zip
```

### Validation

After downloads complete, run: `bash $SCRATCH/scarab/scripts/validate_downloads.sh`

This produces:
- `download_status.tsv` — per-accession status (OK, MISSING, NO_FASTA)
- `failed_accessions.txt` — list for retry
- `download_summary.txt` — human-readable summary

---

## NEXT STEP

Once Task 2.5 is complete, proceed to **HOWTO_06_constraint_tree.md** (Task 2.6, can run in parallel with Task 2.5 completion).

---

*HOWTO 2.5 | Phase 2 Task 5 | SCARAB | Draft: 2026-03-21 | Updated: 2026-03-21 (actual download method documented)*
