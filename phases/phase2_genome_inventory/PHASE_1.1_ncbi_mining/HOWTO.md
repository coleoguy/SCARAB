# HOWTO 2.1: NCBI Mining for Coleoptera Assemblies

**Phase:** Phase 2 - Genome Inventory & QC
**Task:** 2.1 Query NCBI for High-Quality Coleoptera Genomes
**Timeline:** Day 3-4 (~1 full day)
**Executor:** Team

---

## OBJECTIVE

Query NCBI Entrez (Genome and Assembly databases) for all Coleoptera (beetle) genome assemblies. Apply strict quality filters (assembly level, N50, BUSCO, publication year). Compile into a single CSV inventory of ≥50 high-quality genomes for downstream analysis.

**Output acceptance criteria:** ≥50 unique Coleoptera genomes, all mandatory columns present, quality filters documented

---

## INPUT

**None.** This is the first genome data collection task.

---

## OUTPUTS (Exact Filenames & Locations)

### Output: NCBI Assemblies Raw CSV
**Path:** `SCARAB/data/genomes/ncbi_assemblies_raw.csv`

**Format:** CSV with columns (in order, exact column names):

```
BioProject_ID,organism,taxid,assembly_accession,assembly_level,N50_bp,BUSCO_completeness_percent,genome_size_mb,pub_year,DOI
```

**Column definitions:**

- `BioProject_ID` (string): NCBI BioProject ID (e.g., "PRJNA123456")
- `organism` (string): Full species name with subspecies/strain if available (e.g., "Tribolium castaneum")
- `taxid` (integer): NCBI Taxonomy ID
- `assembly_accession` (string): RefSeq or GenBank assembly accession (e.g., "GCF_000000000.1" or "GCA_000000000.1")
- `assembly_level` (string): Level from NCBI (one of: "Chromosome", "Scaffold", "Contig")
- `N50_bp` (integer): N50 value in base pairs (e.g., 500000)
- `BUSCO_completeness_percent` (float): BUSCO score as percentage (e.g., 92.5)
- `genome_size_mb` (float): Total genome size in megabases (e.g., 139.5)
- `pub_year` (integer): Year of publication or assembly deposit (e.g., 2023)
- `DOI` (string): DOI if published, or "Not published" or "In prep"

**Example rows:**

```
PRJNA123456,Tribolium castaneum,7070,GCF_000001825.4,Chromosome,1200000,98.5,139.3,2016,10.1371/journal.pbio.1001841
PRJNA234567,Dendroctonus ponderosae,166361,GCF_000355325.1,Scaffold,650000,94.2,210.5,2013,10.1038/nature12946
PRJNA345678,Anoplophora glabripennis,39519,GCF_000390285.2,Scaffold,120000,87.3,185.8,2020,Not published
```

---

## QUALITY FILTERS

Apply these filters when selecting genomes:

| Filter | Requirement | Justification |
|--------|-------------|---------------|
| **Organism** | Must be Order Coleoptera (beetles) | Taxonomic scope |
| **Assembly level** | Scaffold OR Chromosome (NO contigs only) | Minimum contiguity for alignment |
| **N50** | ≥100,000 bp (100 kb) | Sufficient contig length for synteny detection |
| **BUSCO completeness** | ≥85% | Most core genes present |
| **Genome size** | 100-600 Mb | Typical Coleoptera range; filter extreme outliers |
| **Publication year** | ≥2018 | Modern sequencing/assembly standards |
| **Sequence available** | Must be public (NCBI) | Accessible for download |

**How to apply:**
- Start with all Coleoptera assemblies in NCBI
- Filter to Assembly level ≥ Scaffold
- Remove entries with N50 < 100 kb
- Remove entries with BUSCO < 85% (if available)
- Remove entries with pub_year < 2018
- Remove entries with genome size outside 100-600 Mb range
- Perform manual review of remaining entries

---

## SEARCH QUERIES FOR NCBI

### Method 1: NCBI Assembly Database Web Interface (Easiest)

**URL:** https://www.ncbi.nlm.nih.gov/assembly/

**Steps:**
1. Click "Advanced" search (or use search box)
2. In search box, enter query:
   ```
   ("Coleoptera"[Organism] OR "beetle"[Organism]) AND ("Scaffold"[Assembly Level] OR "Chromosome"[Assembly Level])
   ```
3. Click "Search"
4. Filter results by:
   - Year: 2018 to present (right panel)
   - Assembly level: Keep Scaffold and Chromosome only (deselect Contig)
5. Click "Send to" → "File" → "CSV" to download all results
6. Save as `ncbi_assemblies_raw_full.txt` or similar

**Note:** NCBI web interface may not provide all fields (N50, BUSCO, genome size). You'll need to manually augment using Method 2 or 3 below.

---

### Method 2: NCBI Entrez E-Utilities via Command Line (Recommended)

**Required:** NCBI Entrez Direct tools (edirect)
**Install:** See https://www.ncbi.nlm.nih.gov/books/NBK179288/

**Search for Coleoptera assemblies:**

```bash
# Query NCBI Assembly database for Coleoptera with good assembly level
esearch -db assembly -query '("Coleoptera"[Organism]) AND ("Scaffold"[Assembly Level] OR "Chromosome"[Assembly Level]) AND 2018:2026[PDAT]' | \
efetch -format docsum | \
xtract -pattern DocumentSummary -element AccessionType,AssemblyName,Organism,TaxID,AssemblyLevel,RefSeqCategory,SubmissionDate > coleoptera_assemblies.txt
```

**Then parse the output** (see R/Python example below)

---

### Method 3: NCBI Entrez via R (Recommended for Data Compilation)

**Install packages:**
```r
# install.packages("rentrez")
library(rentrez)
```

**Query example:**

```r
# Search NCBI Assembly for Coleoptera genomes
result <- entrez_search(
  db = "assembly",
  term = '("Coleoptera"[Organism] OR "beetle"[Organism]) AND ("Scaffold"[Assembly Level] OR "Chromosome"[Assembly Level]) AND 2018:2026[PDAT]',
  retmax = 1000,
  use_history = TRUE
)

# Fetch summaries
summaries <- entrez_summary(
  db = "assembly",
  web_history = result$web_history,
  rettype = "xml"
)

# Parse XML and extract key info
# (You will need to parse the XML structure; rentrez does not auto-flatten)

# Example parsing (simplified):
parsed_data <- data.frame(
  assembly_accession = character(),
  organism = character(),
  taxid = integer(),
  assembly_level = character(),
  stringsAsFactors = FALSE
)

# Append results from summaries (complex XML parsing, consult rentrez vignette)
```

---

### Method 4: NCBI FTP Direct Listing

**URL:** ftp://ftp.ncbi.nlm.nih.gov/genomes/

**Steps:**
1. Navigate to `ftp://ftp.ncbi.nlm.nih.gov/genomes/all/` (or `genbank/` or `refseq/`)
2. Download `assembly_summary.txt` (contains metadata for all genomes)
3. Filter locally for Coleoptera

**Example R code to parse assembly_summary.txt:**

```r
# Download NCBI assembly summary
download.file(
  "ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.txt",
  "assembly_summary_refseq.txt"
)

# Read (skip header lines)
summary <- read.csv(
  "assembly_summary_refseq.txt",
  sep = "\t",
  skip = 1,
  header = FALSE,
  stringsAsFactors = FALSE
)

# Parse column names (see NCBI documentation)
colnames(summary) <- c(
  "assembly_accession", "bioproject", "biosample", "wgs_master",
  "refseq_category", "taxid", "organism_name", "infraspecific_name",
  "isolate", "version_status", "assembly_level", "release_type",
  "genome_rep", "seq_rel_date", "asm_name", "submitter", "gbrs_paired_asm",
  "paired_asm_comp", "ftp_path", "excluded_from_refseq", "relation_to_type_material"
)

# Filter for Coleoptera
coleoptera <- summary %>%
  filter(grepl("Coleoptera", organism_name, ignore.case = TRUE)) %>%
  filter(assembly_level %in% c("Scaffold", "Chromosome")) %>%
  filter(substring(seq_rel_date, 1, 4) >= 2018)

# View results
head(coleoptera)
```

---

## DATA AUGMENTATION: N50, BUSCO, GENOME SIZE

Most NCBI queries will not directly return N50, BUSCO completeness, or genome size. You must augment by:

### Option A: Parse from NCBI Genome Report

For each assembly, fetch the detailed report:

```bash
# Example: for assembly GCF_000001825.4
curl -s "https://www.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/assembly_data_report.jsonld" | \
jq . | grep -i "n50\|genome_size\|busco"
```

**But:** NCBI genome reports are inconsistent; N50 and BUSCO may not always be present.

### Option B: Get from Published Paper's Supplementary

If assembly is from peer-reviewed paper (DOI available), check supplementary table for:
- N50
- BUSCO completeness
- Genome size
- GenBank vs RefSeq status

**Search:** Google Scholar with DOI, or PubMed

### Option C: Estimate Genome Size from FTP File Listing

If FTP path available, download and measure FASTA:

```bash
# Example: download genome FASTA and measure
wget -q -O - ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/001/825/GCF_000001825.4_Release_100/GCF_000001825.4_Release_100_genomic.fna.gz | \
zcat | \
grep -v "^>" | \
tr -d '\n' | wc -c
```

---

## WORKFLOW: BUILDING THE NCBI_ASSEMBLIES_RAW.CSV

### Step 1: Initial Query
Use Method 3 or 4 above to get a list of all Coleoptera assemblies (RefSeq preferred, but GenBank OK)

### Step 2: Initial Filtering
Apply hard filters:
- Assembly level ≥ Scaffold
- Organism = Coleoptera (or family-level if needed)
- Publication year ≥ 2018

### Step 3: Manual Curation
For each remaining assembly (~100-200 entries):
1. Check NCBI Assembly page (e.g., `https://www.ncbi.nlm.nih.gov/assembly/GCF_000001825.4/`)
2. Record:
   - Assembly accession
   - Organism (full species name)
   - Assembly level
   - N50 (if available on page, or in linked paper)
   - BUSCO (if available)
   - Genome size (calculate from FASTA or from paper)
   - Publication year
   - DOI (if published)

3. Apply secondary filters:
   - N50 ≥ 100 kb (remove low-N50 assemblies)
   - BUSCO ≥ 85% (if available; may skip if not reported)
   - Genome size 100-600 Mb
   - Remove obvious outliers (very small, very large, low complexity)

### Step 4: De-duplication by Species
If multiple assemblies of same species:
- Keep RefSeq version if available (GCF prefix)
- Otherwise keep GenBank (GCA prefix)
- Only keep one per species at this stage

### Step 5: Output CSV
Save final curated list as `ncbi_assemblies_raw.csv` with all 10 columns

---

## EXAMPLE R WORKFLOW

Here's a complete R script to help:

```r
library(dplyr)
library(tidyr)

# Download assembly summary (RefSeq)
download.file(
  "ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.txt",
  "assembly_summary_refseq.txt"
)

# Read and parse
colnames_list <- c(
  "assembly_accession", "bioproject", "biosample", "wgs_master",
  "refseq_category", "taxid", "organism_name", "infraspecific_name",
  "isolate", "version_status", "assembly_level", "release_type",
  "genome_rep", "seq_rel_date", "asm_name", "submitter", "gbrs_paired_asm",
  "paired_asm_comp", "ftp_path", "excluded_from_refseq", "relation_to_type_material"
)

summary_refseq <- read.csv(
  "assembly_summary_refseq.txt",
  sep = "\t",
  skip = 1,
  header = FALSE,
  colnames = colnames_list,
  stringsAsFactors = FALSE
)

# Extract year from date
summary_refseq <- summary_refseq %>%
  mutate(
    pub_year = as.integer(substring(seq_rel_date, 1, 4))
  )

# Filter for Coleoptera
coleoptera <- summary_refseq %>%
  filter(grepl("Coleoptera", organism_name, ignore.case = TRUE)) %>%
  filter(assembly_level %in% c("Scaffold", "Chromosome")) %>%
  filter(pub_year >= 2018) %>%
  filter(excluded_from_refseq == "na") %>%  # Include only valid genomes
  select(
    assembly_accession, bioproject, taxid, organism_name,
    assembly_level, pub_year, ftp_path
  )

# Manual step: For each entry, fetch additional metadata
# This requires parsing NCBI Genome pages or linked papers
# For now, add placeholder columns:

coleoptera <- coleoptera %>%
  mutate(
    N50_bp = NA_integer_,
    BUSCO_completeness_percent = NA_real_,
    genome_size_mb = NA_real_,
    DOI = "Not published"
  ) %>%
  rename(
    BioProject_ID = bioproject,
    organism = organism_name,
    assembly_accession = assembly_accession
  ) %>%
  select(
    BioProject_ID, organism, taxid, assembly_accession,
    assembly_level, N50_bp, BUSCO_completeness_percent,
    genome_size_mb, pub_year, DOI
  )

# MANUAL CURATION REQUIRED:
# For each row, fill in N50, BUSCO, genome size by:
# 1. Visiting NCBI Assembly page
# 2. Checking linked publication (DOI)
# 3. Downloading FASTA and computing metrics if needed

# Save intermediate file
write.csv(
  coleoptera,
  "SCARAB/data/genomes/ncbi_assemblies_raw.csv",
  row.names = FALSE
)

# Count final genomes
cat(paste("Total Coleoptera genomes identified:", nrow(coleoptera), "\n"))
```

---

## NCBI ASSEMBLY PAGE EXAMPLE

To find N50 and other metrics, visit NCBI Assembly page:

**URL pattern:** `https://www.ncbi.nlm.nih.gov/assembly/[ASSEMBLY_ACCESSION]/`

**Example:** https://www.ncbi.nlm.nih.gov/assembly/GCF_000001825.4/

**On this page, look for:**
- Accession: top of page
- Organism name
- Assembly level
- Statistics table (scroll down) showing N50
- Link to published paper (if any)

---

## ACCEPTANCE CRITERIA

Task 2.1 is complete when:

- [ ] ≥50 unique Coleoptera assemblies identified (no duplicates by species)
- [ ] All assemblies pass quality filters:
  - Assembly level ≥ Scaffold
  - N50 ≥ 100 kb
  - BUSCO ≥ 85% (if available)
  - Genome size 100-600 Mb
  - Pub year ≥ 2018
- [ ] All 10 columns populated (no critical NAs)
- [ ] No missing DOIs (marked "Not published" or "In prep" if applicable)
- [ ] File saved in exact path: `SCARAB/data/genomes/ncbi_assemblies_raw.csv`
- [ ] File is valid CSV (readable in Excel, R, Python without errors)
- [ ] Filtering logic documented (which searches used, filters applied)

---

## NEXT STEP

Once Task 2.1 is complete, proceed to **HOWTO_02_ensembl_mining.md** (Task 2.2, can run in parallel).

---

*HOWTO 2.1 | Phase 2 Task 1 | SCARAB | Draft: 2026-03-21*
