# HOWTO 2.3: Merge & Deduplicate NCBI and Ensembl Assemblies

**Phase:** Phase 2 - Genome Inventory & QC
**Task:** 2.3 Consolidate Genome Inventory, Remove Redundancy, Rank by Quality
**Timeline:** Day 4 (~0.5 day)
**Executor:** Team

---

## OBJECTIVE

Combine NCBI and Ensembl genome lists into a single, deduplicated inventory. When the same species appears in both sources, retain the higher-quality assembly. Rank all genomes by quality (RefSeq > GenBank, better N50, better BUSCO). Output a single merged CSV with one row per unique species, plus a deduplication report.

**Output acceptance criteria:** ≥60 unique beetle species, no duplicate rows, quality ranking transparent and documented

---

## INPUT

**From Task 2.1:** `SCARAB/data/genomes/ncbi_assemblies_raw.csv`
**From Task 2.2:** `SCARAB/data/genomes/ensembl_assemblies_raw.csv`

---

## OUTPUTS (Exact Filenames & Locations)

### Output 1: Merged Deduplicated CSV
**Path:** `SCARAB/data/genomes/merged_genomes.csv`

**Format:** CSV with columns (in order):

```
source,BioProject_ID,organism,taxid,assembly_accession,assembly_level,N50_bp,BUSCO_completeness_percent,genome_size_mb,pub_year,DOI,quality_rank
```

**New column (compared to previous outputs):**
- `source` (string): "NCBI_RefSeq" OR "NCBI_GenBank" OR "Ensembl" (indicates where this genome came from)
- `quality_rank` (integer): 1 = highest quality in dataset, 2 = second best, etc.
  - Ranking prioritizes: assembly_level (chromosome > scaffold > contig), then N50 (higher better), then BUSCO (higher better)

**Example rows:**
```
NCBI_RefSeq,PRJNA123456,Tribolium castaneum,7070,GCF_000001825.4,Chromosome,1200000,98.5,139.3,2016,10.1371/journal.pbio.1001841,1
NCBI_GenBank,PRJNA234567,Dendroctonus ponderosae,166361,GCA_000355325.1,Scaffold,650000,94.2,210.5,2013,10.1038/nature12946,3
Ensembl,Ensembl,Lucicutis castaneipennis,47365,GCA_019391965.1,Scaffold,850000,91.2,165.4,2021,10.1093/nar/gky1193,2
```

---

### Output 2: Deduplication Report
**Path:** `SCARAB/results/phase2_genome_inventory/dedup_report.txt`

**Format:** Plain text report

**Sections to include:**

1. **Summary Statistics**
   ```
   Total genomes NCBI (raw): [N]
   Total genomes Ensembl (raw): [M]
   Duplicate species found: [K] (same organism in both, kept higher quality)
   Duplicate assembly accessions found: [L]
   Final unique species: [≥60]
   ```

2. **Deduplication Details**
   - For each species appearing in both NCBI and Ensembl:
     - Species name
     - NCBI version (assembly, N50, BUSCO, year)
     - Ensembl version (assembly, N50, BUSCO, year)
     - Decision: which one kept and why (quality reasoning)

3. **Quality Rank Distribution**
   - Number of genomes at each assembly level:
     ```
     Chromosome:  [N] genomes
     Scaffold:    [M] genomes
     Contig:      [L] genomes (if any)
     ```
   - N50 statistics:
     ```
     Mean N50:      [X] bp
     Median N50:    [Y] bp
     Min N50:       [Z] bp
     Max N50:       [W] bp
     ```
   - BUSCO completeness:
     ```
     Mean:   [X] %
     Min:    [Y] %
     Max:    [Z] %
     N/A:    [W] (not reported)
     ```

4. **Rejected Genomes**
   - List any genomes removed due to:
     - Duplicate species (kept higher quality)
     - Quality filters (N50 < 100kb, BUSCO < 85%, genome size outside range)
     - Data quality issues (missing N50, BUSCO, etc.)
   - For each: species name, reason, alternative used

5. **Notes & Caveats**
   - Any genomes with missing data (marked NA)
   - Any genomes below quality thresholds but included anyway (with justification)
   - Any unexpected observations

---

## WORKFLOW STEPS

### Step 1: Load and Inspect Both Files

```r
library(dplyr)
library(tidyr)

# Load raw files from Tasks 2.1 and 2.2
ncbi <- read.csv("SCARAB/data/genomes/ncbi_assemblies_raw.csv", stringsAsFactors = FALSE)
ensembl <- read.csv("SCARAB/data/genomes/ensembl_assemblies_raw.csv", stringsAsFactors = FALSE)

# Inspect dimensions
cat(paste("NCBI genomes:", nrow(ncbi), "\n"))
cat(paste("Ensembl genomes:", nrow(ensembl), "\n"))

# Check for obvious issues
cat("NCBI: missing values per column\n")
colSums(is.na(ncbi))

cat("Ensembl: missing values per column\n")
colSums(is.na(ensembl))
```

---

### Step 2: Identify Duplicates

```r
# Method 1: Find exact species name matches (case-insensitive)
ncbi_organisms <- tolower(unique(ncbi$organism))
ensembl_organisms <- tolower(unique(ensembl$organism))

species_in_both <- intersect(ncbi_organisms, ensembl_organisms)
cat(paste("Species appearing in both sources:", length(species_in_both), "\n"))

# Method 2: Find assembly accession matches
ncbi_accessions <- na.omit(unique(ncbi$assembly_accession))
ensembl_accessions <- na.omit(unique(ensembl$assembly_accession))

accession_in_both <- intersect(ncbi_accessions, ensembl_accessions)
cat(paste("Assemblies appearing in both sources:", length(accession_in_both), "\n"))

# Print duplicates for manual review
if (length(species_in_both) > 0) {
  cat("\nSpecies duplicates:\n")
  print(species_in_both)
}
```

---

### Step 3: Resolve Duplicates by Keeping Higher Quality

```r
# For each duplicate species, identify which has better quality
# Quality ranking: RefSeq > GenBank, then by assembly_level, then N50, then BUSCO

get_source_type <- function(assembly_accession) {
  # RefSeq starts with GCF, GenBank with GCA
  if (grepl("^GCF", assembly_accession)) {
    return("NCBI_RefSeq")
  } else if (grepl("^GCA", assembly_accession)) {
    return("NCBI_GenBank")
  } else {
    return("Ensembl")
  }
}

assembly_level_rank <- function(level) {
  # Chromosome (best) > Scaffold > Contig (worst)
  case_when(
    level == "Chromosome" ~ 3,
    level == "Scaffold" ~ 2,
    level == "Contig" ~ 1,
    TRUE ~ 0
  )
}

# Add source type and quality scores
ncbi <- ncbi %>%
  mutate(
    source = sapply(assembly_accession, get_source_type),
    level_rank = sapply(assembly_level, assembly_level_rank)
  )

ensembl <- ensembl %>%
  mutate(
    source = "Ensembl",
    level_rank = sapply(assembly_level, assembly_level_rank)
  )

# For each duplicate species, keep the highest quality version
# Strategy: add a quality score and keep top entry per species
merged <- rbind(ncbi, ensembl) %>%
  mutate(
    # Quality score: prioritize RefSeq, then assembly level, then N50, then BUSCO
    quality_score = case_when(
      source == "NCBI_RefSeq" ~ 1000,
      source == "NCBI_GenBank" ~ 500,
      source == "Ensembl" ~ 200,
      TRUE ~ 0
    ) + level_rank * 100 + (N50_bp / 100000) + (BUSCO_completeness_percent / 10)
  ) %>%
  group_by(tolower(organism)) %>%
  arrange(desc(quality_score)) %>%
  slice(1) %>%  # Keep only top quality per species
  ungroup() %>%
  select(-quality_score)

# Verify no species duplicates remain
duplicated_species <- merged %>%
  group_by(tolower(organism)) %>%
  filter(n() > 1) %>%
  select(organism)

if (nrow(duplicated_species) > 0) {
  cat("ERROR: Still have duplicates!\n")
  print(duplicated_species)
} else {
  cat("SUCCESS: All duplicates removed, one genome per species\n")
}
```

---

### Step 4: Add Quality Rank

```r
# Assign quality rank across all genomes
# Rank by: assembly_level (chromosome best), then N50, then BUSCO

merged <- merged %>%
  arrange(
    desc(level_rank),  # Chromosome first
    desc(N50_bp),      # Then higher N50
    desc(BUSCO_completeness_percent)  # Then higher BUSCO
  ) %>%
  mutate(quality_rank = row_number())

# View top quality genomes
cat("Top 10 quality genomes:\n")
print(merged %>% arrange(quality_rank) %>% head(10) %>% select(organism, source, assembly_level, N50_bp, BUSCO_completeness_percent, quality_rank))
```

---

### Step 5: Reorder and Select Final Columns

```r
# Ensure exact column order for output
merged_final <- merged %>%
  select(
    source, BioProject_ID, organism, taxid, assembly_accession,
    assembly_level, N50_bp, BUSCO_completeness_percent,
    genome_size_mb, pub_year, DOI, quality_rank
  )

# Final count
cat(paste("Final merged inventory:", nrow(merged_final), "unique species\n"))

# Save
write.csv(
  merged_final,
  "SCARAB/data/genomes/merged_genomes.csv",
  row.names = FALSE
)
```

---

### Step 6: Generate Deduplication Report

```r
# Open file for writing
report_file <- "SCARAB/results/phase2_genome_inventory/dedup_report.txt"
sink(report_file)

cat("=== DEDUPLICATION REPORT ===\n")
cat(paste("Generated:", Sys.time(), "\n\n"))

# Summary statistics
cat("SUMMARY STATISTICS\n")
cat("==================\n")
cat(paste("Total genomes NCBI (raw):", nrow(ncbi), "\n"))
cat(paste("Total genomes Ensembl (raw):", nrow(ensembl), "\n"))
cat(paste("Duplicate species resolved:", length(species_in_both), "\n"))
cat(paste("Duplicate assemblies resolved:", length(accession_in_both), "\n"))
cat(paste("Final unique species:", nrow(merged_final), "\n\n"))

# Assembly level distribution
cat("ASSEMBLY LEVEL DISTRIBUTION\n")
cat("===========================\n")
level_dist <- table(merged_final$assembly_level)
print(level_dist)
cat("\n")

# N50 statistics
cat("N50 STATISTICS (bp)\n")
cat("==================\n")
n50_stats <- summary(merged_final$N50_bp, na.rm = TRUE)
print(n50_stats)
cat(paste("Missing N50 values:", sum(is.na(merged_final$N50_bp)), "\n\n"))

# BUSCO statistics
cat("BUSCO COMPLETENESS STATISTICS (%)\n")
cat("==================================\n")
busco_stats <- summary(merged_final$BUSCO_completeness_percent, na.rm = TRUE)
print(busco_stats)
cat(paste("Missing BUSCO values:", sum(is.na(merged_final$BUSCO_completeness_percent)), "\n\n"))

# Genome size distribution
cat("GENOME SIZE STATISTICS (Mb)\n")
cat("===========================\n")
size_stats <- summary(merged_final$genome_size_mb, na.rm = TRUE)
print(size_stats)
cat(paste("Missing genome size values:", sum(is.na(merged_final$genome_size_mb)), "\n\n"))

# Source distribution
cat("SOURCE DISTRIBUTION\n")
cat("===================\n")
source_dist <- table(merged_final$source)
print(source_dist)
cat("\n")

# Deduplication decisions (for species in both sources)
if (length(species_in_both) > 0) {
  cat("DEDUPLICATION DECISIONS\n")
  cat("=======================\n")
  cat(paste("Species appearing in both NCBI and Ensembl:", length(species_in_both), "\n\n"))

  for (sp in species_in_both[1:min(10, length(species_in_both))]) {  # Print first 10
    ncbi_sp <- ncbi %>% filter(tolower(organism) == sp)
    ensembl_sp <- ensembl %>% filter(tolower(organism) == sp)
    merged_sp <- merged_final %>% filter(tolower(organism) == sp)

    cat(paste("Species:", sp, "\n"))
    if (nrow(ncbi_sp) > 0) {
      cat(paste("  NCBI:", ncbi_sp$assembly_accession[1], "N50:", ncbi_sp$N50_bp[1], "BUSCO:", ncbi_sp$BUSCO_completeness_percent[1], "\n"))
    }
    if (nrow(ensembl_sp) > 0) {
      cat(paste("  Ensembl:", ensembl_sp$assembly_accession[1], "N50:", ensembl_sp$N50_bp[1], "BUSCO:", ensembl_sp$BUSCO_completeness_percent[1], "\n"))
    }
    cat(paste("  KEPT:", merged_sp$source[1], merged_sp$assembly_accession[1], "\n\n"))
  }

  if (length(species_in_both) > 10) {
    cat(paste("... and", length(species_in_both) - 10, "more species\n\n"))
  }
}

# Quality rank top 20
cat("TOP 20 QUALITY-RANKED GENOMES\n")
cat("=============================\n")
top20 <- merged_final %>% arrange(quality_rank) %>% head(20)
for (i in 1:nrow(top20)) {
  row <- top20[i, ]
  cat(sprintf("%2d. %s (%s): %s, N50=%s, BUSCO=%s%%\n",
    row$quality_rank,
    row$organism,
    row$source,
    row$assembly_level,
    row$N50_bp,
    row$BUSCO_completeness_percent
  ))
}
cat("\n")

# Missing data summary
cat("MISSING DATA SUMMARY\n")
cat("====================\n")
missing_summary <- data.frame(
  Column = colnames(merged_final),
  Missing_Count = colSums(is.na(merged_final)),
  Missing_Percent = round(100 * colSums(is.na(merged_final)) / nrow(merged_final), 1)
)
print(missing_summary)
cat("\n")

cat("=== END OF REPORT ===\n")

sink()  # Close file
cat(paste("Report written to:", report_file, "\n"))
```

---

## COMPLETE R SCRIPT

Here's a full script combining all steps:

```r
library(dplyr)
library(tidyr)

# ===== LOAD =====
ncbi <- read.csv("SCARAB/data/genomes/ncbi_assemblies_raw.csv", stringsAsFactors = FALSE)
ensembl <- read.csv("SCARAB/data/genomes/ensembl_assemblies_raw.csv", stringsAsFactors = FALSE)

cat(paste("Loaded", nrow(ncbi), "NCBI and", nrow(ensembl), "Ensembl genomes\n\n"))

# ===== IDENTIFY DUPLICATES =====
species_in_both <- intersect(tolower(unique(ncbi$organism)), tolower(unique(ensembl$organism)))
cat(paste("Species in both sources:", length(species_in_both), "\n\n"))

# ===== ASSIGN SOURCE AND RANK =====
get_source_type <- function(acc) {
  if (grepl("^GCF", acc)) "NCBI_RefSeq" else if (grepl("^GCA", acc)) "NCBI_GenBank" else "Ensembl"
}

level_rank <- function(level) {
  dplyr::case_when(level == "Chromosome" ~ 3, level == "Scaffold" ~ 2, level == "Contig" ~ 1, TRUE ~ 0)
}

ncbi$source <- sapply(ncbi$assembly_accession, get_source_type)
ncbi$level_rank <- sapply(ncbi$assembly_level, level_rank)
ensembl$source <- "Ensembl"
ensembl$level_rank <- sapply(ensembl$assembly_level, level_rank)

# ===== MERGE AND DEDUPLICATE =====
merged <- rbind(ncbi, ensembl) %>%
  mutate(quality_score = case_when(
    source == "NCBI_RefSeq" ~ 1000,
    source == "NCBI_GenBank" ~ 500,
    source == "Ensembl" ~ 200,
    TRUE ~ 0
  ) + level_rank * 100 + (N50_bp / 100000) + (BUSCO_completeness_percent / 10)) %>%
  group_by(tolower(organism)) %>%
  arrange(desc(quality_score)) %>%
  slice(1) %>%
  ungroup() %>%
  select(-quality_score, -level_rank)

# ===== ADD QUALITY RANK =====
merged <- merged %>%
  arrange(desc(level_rank), desc(N50_bp), desc(BUSCO_completeness_percent)) %>%
  mutate(quality_rank = row_number()) %>%
  select(source, BioProject_ID, organism, taxid, assembly_accession, assembly_level, N50_bp, BUSCO_completeness_percent, genome_size_mb, pub_year, DOI, quality_rank)

# ===== SAVE MERGED =====
write.csv(merged, "SCARAB/data/genomes/merged_genomes.csv", row.names = FALSE)
cat(paste("Saved merged inventory:", nrow(merged), "species\n"))

# ===== GENERATE REPORT (simplified) =====
sink("SCARAB/results/phase2_genome_inventory/dedup_report.txt")
cat("=== DEDUPLICATION REPORT ===\n\n")
cat(paste("NCBI (raw):", nrow(ncbi), "\n"))
cat(paste("Ensembl (raw):", nrow(ensembl), "\n"))
cat(paste("Final unique species:", nrow(merged), "\n\n"))
cat("Assembly level distribution:\n")
print(table(merged$assembly_level))
cat("\nN50 summary (bp):\n")
print(summary(merged$N50_bp, na.rm = TRUE))
cat("\nBUSCO summary (%):\n")
print(summary(merged$BUSCO_completeness_percent, na.rm = TRUE))
sink()

cat("Done!\n")
```

---

## ACCEPTANCE CRITERIA

Task 2.3 is complete when:

- [ ] Merged file contains ≥60 unique beetle species
- [ ] No duplicate species (verified: same species should appear only once)
- [ ] All 12 columns present with no formatting errors
- [ ] Quality ranking is transparent (RefSeq preferred, then by assembly level & N50 & BUSCO)
- [ ] Deduplication report explains all decisions
- [ ] Files saved in exact paths:
  - `SCARAB/data/genomes/merged_genomes.csv`
  - `SCARAB/results/phase2_genome_inventory/dedup_report.txt`
- [ ] Both files are readable and well-formatted

---

## NEXT STEP

Once Task 2.3 is complete, proceed to **HOWTO_04_phylogenetic_placement.md** (Task 2.4).

---

*HOWTO 2.3 | Phase 2 Task 3 | SCARAB | Draft: 2026-03-21*
