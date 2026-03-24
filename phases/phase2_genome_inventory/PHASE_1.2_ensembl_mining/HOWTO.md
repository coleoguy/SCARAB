# HOWTO 2.2: Ensembl Metazoa Mining for Additional Coleoptera

**Phase:** Phase 2 - Genome Inventory & QC
**Task:** 2.2 Query Ensembl Metazoa for Beetle Genomes Not in NCBI Set
**Timeline:** Day 4 (~0.5 day, can run in parallel with Task 2.1)
**Executor:** Team

---

## OBJECTIVE

Query Ensembl Metazoa for Coleoptera genomes that may not yet be in NCBI RefSeq (e.g., newer submissions, alternative assemblies with better annotations). Identify ≥10 non-redundant genomes to augment the NCBI list. Deduplicate against Task 2.1 results.

**Output acceptance criteria:** ≥10 additional unique genomes, deduplicated against NCBI set, all columns present

---

## INPUT

**From Task 2.1:** `SCARAB/data/genomes/ncbi_assemblies_raw.csv`

Use this to identify which species are already captured from NCBI, so you can find complementary Ensembl entries.

---

## OUTPUTS (Exact Filenames & Locations)

### Output: Ensembl Assemblies Raw CSV
**Path:** `SCARAB/data/genomes/ensembl_assemblies_raw.csv`

**Format:** CSV with SAME columns as NCBI output for easy merging:

```
BioProject_ID,organism,taxid,assembly_accession,assembly_level,N50_bp,BUSCO_completeness_percent,genome_size_mb,pub_year,DOI
```

**Column definitions:** (Identical to Task 2.1)

- `BioProject_ID`: Ensembl project or NCBI BioProject ID (if available)
- `organism`: Full species name
- `taxid`: NCBI Taxonomy ID
- `assembly_accession`: Ensembl assembly accession or GenBank accession
- `assembly_level`: Scaffold, Chromosome, or Contig (apply same filters)
- `N50_bp`: N50 in base pairs
- `BUSCO_completeness_percent`: BUSCO score %
- `genome_size_mb`: Genome size in megabases
- `pub_year`: Year of assembly
- `DOI`: DOI or publication info

**Example row:**
```
Ensembl,Lucicutis castaneipennis,47365,GCA_019391965.1,Scaffold,850000,91.2,165.4,2021,10.1093/nar/gky1193
```

---

## ENSEMBL METAZOA DATABASES

Ensembl Metazoa hosts genomes for non-vertebrate animals, including insects and beetles.

**Main resource:** http://metazoa.ensembl.org/

**Related resources:**
- Ensembl REST API: https://rest.ensembl.org/ (programmatic access)
- Ensembl FTP: ftp://ftp.ensemblgenomes.org/pub/metazoa/ (direct file downloads)

---

## METHOD 1: WEB BROWSER SEARCH (Simplest for Small Numbers)

### Steps:

1. **Visit Ensembl Metazoa:** http://metazoa.ensembl.org/

2. **Search for Coleoptera:**
   - Click "Search" (top menu)
   - Enter "Coleoptera" or "beetle" in search box
   - Or browse species tree: Home → Species Tree → Coleoptera

3. **Browse Coleoptera species list:**
   - Click on any Coleoptera link to view available genomes
   - Record: species name, assembly version, assembly level

4. **For each species, click on genome link:**
   - Check assembly information page
   - Record: assembly accession, N50, BUSCO (if available)
   - Look for DOI link (associated publication)

5. **Compile into spreadsheet** (manual entry)

**Pros:** No programming required, interactive browsing
**Cons:** Tedious for many genomes, error-prone manual entry
**Recommended:** Use this if you prefer visual browsing and expect <10 genomes

---

## METHOD 2: ENSEMBL REST API (Programmatic, Recommended)

Ensembl provides a REST API for programmatic queries.

**API documentation:** https://rest.ensembl.org/

**Example: Get all Coleoptera species:**

```bash
# Fetch all species in Coleoptera order
curl -s "http://rest.ensembl.org/info/species?division=ensembl_metazoa" | \
  jq '.[] | select(.taxonomy.order == "Coleoptera") | {name, assembly, assembly_accession}'
```

**Or in R:**

```r
library(httr)
library(jsonlite)

# Get all Metazoa species
response <- GET("http://rest.ensembl.org/info/species?division=ensembl_metazoa")
species_list <- fromJSON(content(response, "text"))

# Filter for Coleoptera
coleoptera <- species_list %>%
  lapply(function(x) {
    if (!is.null(x$taxonomy$order) && x$taxonomy$order == "Coleoptera") {
      return(data.frame(
        organism = x$display_name,
        assembly = x$assembly,
        assembly_accession = ifelse(is.null(x$assembly_accession), NA, x$assembly_accession),
        stringsAsFactors = FALSE
      ))
    } else {
      return(NULL)
    }
  }) %>%
  do.call(rbind, .)

# View results
head(coleoptera)
```

---

## METHOD 3: ENSEMBL FTP DIRECTORY LISTING (For Bulk Access)

Ensembl hosts all genomes on FTP server.

**URL:** ftp://ftp.ensemblgenomes.org/pub/metazoa/

**Steps:**

1. **Browse FTP structure:**
   ```
   ftp://ftp.ensemblgenomes.org/pub/metazoa/
   ├── fasta/
   │   ├── coleoptera/  (or organized by genus, species)
   │   └── ...
   └── ...
   ```

2. **List Coleoptera directories:**
   ```bash
   # Via command line
   lftp ftp://ftp.ensemblgenomes.org/pub/metazoa/fasta/ -e "ls -la | grep -i coleoptera; quit"
   ```

3. **For each genome, download FASTA and parse metadata:**
   - FASTA files usually include assembly accession in filename
   - Example: `drosophila_melanogaster.BDGP6.28.dna.toplevel.fa.gz`

---

## QUALITY FILTERS (Same as NCBI)

Apply same filters as Task 2.1:
- Assembly level ≥ Scaffold
- N50 ≥ 100 kb (if available)
- BUSCO ≥ 85% (if available)
- Genome size 100-600 Mb
- Pub year ≥ 2018 (if available)

---

## DEDUPLICATION AGAINST NCBI SET

**Important:** Before finalizing `ensembl_assemblies_raw.csv`, deduplicate:

1. **Load both files:**
   ```r
   ncbi <- read.csv("SCARAB/data/genomes/ncbi_assemblies_raw.csv")
   ensembl_raw <- read.csv("ensembl_assemblies_raw_temp.csv")
   ```

2. **Find duplicates by species name and/or assembly accession:**
   ```r
   # Species duplicates
   species_in_both <- intersect(ncbi$organism, ensembl_raw$organism)

   # Assembly accession duplicates
   acc_in_both <- intersect(ncbi$assembly_accession, ensembl_raw$assembly_accession)

   # Remove rows that appear in both (prefer NCBI RefSeq if duplicate)
   ensembl_filtered <- ensembl_raw %>%
     filter(!(organism %in% species_in_both)) %>%
     filter(!(assembly_accession %in% acc_in_both))

   # Count new genomes added
   cat(paste("New unique genomes from Ensembl:", nrow(ensembl_filtered), "\n"))
   ```

3. **Save deduplicated Ensembl set:**
   ```r
   write.csv(
     ensembl_filtered,
     "SCARAB/data/genomes/ensembl_assemblies_raw.csv",
     row.names = FALSE
   )
   ```

---

## EXAMPLE WORKFLOW (R)

Complete R script:

```r
library(httr)
library(jsonlite)
library(dplyr)

# === Step 1: Fetch Ensembl Metazoa species list ===
cat("Fetching Ensembl Metazoa species...\n")

response <- GET("http://rest.ensembl.org/info/species?division=ensembl_metazoa")
all_species <- fromJSON(content(response, "text"))

# Filter for Coleoptera
coleoptera_from_api <- lapply(all_species, function(x) {
  order <- if (!is.null(x$taxonomy$order)) x$taxonomy$order else NA
  if (!is.na(order) && order == "Coleoptera") {
    data.frame(
      BioProject_ID = "Ensembl",
      organism = x$display_name,
      taxid = if (!is.null(x$taxonomy$id)) x$taxonomy$id else NA,
      assembly_accession = if (!is.null(x$assembly_accession)) x$assembly_accession else NA,
      assembly_level = NA,  # Not available from this API endpoint
      N50_bp = NA,
      BUSCO_completeness_percent = NA,
      genome_size_mb = NA,
      pub_year = NA,
      DOI = NA,
      stringsAsFactors = FALSE
    )
  } else {
    NULL
  }
}) %>%
  do.call(rbind, .)

# === Step 2: Augment with assembly details (manual or API) ===
# For each species, you may need to query additional info:
# - Assembly level, N50, genome size from genome details API
# - DOI from linked publications

# Example: Get assembly details for one species
get_assembly_info <- function(species_name) {
  url <- paste0("http://rest.ensembl.org/info/assembly/", gsub(" ", "_", species_name))
  response <- GET(url)
  if (status_code(response) == 200) {
    return(fromJSON(content(response, "text")))
  } else {
    return(NULL)
  }
}

# Apply to all species (may be slow due to API rate limiting)
# Simplified: just save what we have and fill in manually

# === Step 3: Load NCBI set and deduplicate ===
ncbi <- read.csv("SCARAB/data/genomes/ncbi_assemblies_raw.csv")

# Species already in NCBI
species_in_ncbi <- unique(tolower(ncbi$organism))

# Filter Ensembl to remove duplicates
coleoptera_unique <- coleoptera_from_api %>%
  filter(!(tolower(organism) %in% species_in_ncbi))

# === Step 4: Save ===
write.csv(
  coleoptera_unique,
  "SCARAB/data/genomes/ensembl_assemblies_raw.csv",
  row.names = FALSE
)

cat(paste("Ensembl Coleoptera genomes (unique, not in NCBI):", nrow(coleoptera_unique), "\n"))
```

---

## MANUAL AUGMENTATION

After the initial API queries, you will likely need to **manually fill in**:
- N50, BUSCO, genome_size, DOI for each Ensembl genome
- Approach:
  1. Visit Ensembl genome page for each species
  2. Download FASTA header to estimate genome size
  3. Search for associated publication (DOI)
  4. Check supplementary tables for N50, BUSCO

**Tool:** Use spreadsheet (Excel, Google Sheets) to fill in blanks collaboratively

---

## ACCEPTANCE CRITERIA

Task 2.2 is complete when:

- [ ] ≥10 unique Coleoptera genomes identified from Ensembl (not already in NCBI)
- [ ] All genomes pass quality filters:
  - Assembly level ≥ Scaffold
  - N50 ≥ 100 kb (or noted if unavailable)
  - Genome size 100-600 Mb
  - Pub year ≥ 2018 (or noted if unavailable)
- [ ] All 10 columns populated (NAs acceptable for unavailable fields; document reason)
- [ ] No species duplicates with NCBI set (verified via comparison)
- [ ] No assembly accession duplicates with NCBI set
- [ ] File saved in exact path: `SCARAB/data/genomes/ensembl_assemblies_raw.csv`
- [ ] File is valid CSV (readable in R/Python without errors)

---

## NEXT STEP

Once Task 2.2 is complete, proceed to **HOWTO_03_merge_deduplicate.md** (Task 2.3).

---

*HOWTO 2.2 | Phase 2 Task 2 | SCARAB | Draft: 2026-03-21*
