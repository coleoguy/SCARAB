# HOWTO 2.4: Phylogenetic Placement & PI Curation

**Phase:** Phase 2 - Genome Inventory & QC
**Task:** 2.4 Taxonomic Assignment and QC Review by Heath
**Timeline:** Day 5 (~0.5 day)
**Executor:** Heath Blackmon (PI, manual curation)

---

## OBJECTIVE

Heath Blackmon (PI) reviews the merged genome inventory, assigns each species to a specific Coleoptera clade (family, tribe, subfamily), flags any quality concerns, and marks each genome as "include" or "exclude" for downstream alignment. Output is a curated inventory ready for FASTA retrieval and tree building.

**Output acceptance criteria:** All genomes taxonomically placed, QC flags documented, ≥50 marked for inclusion

---

## INPUT

**From Task 2.3:** `SCARAB/data/genomes/merged_genomes.csv`

---

## OUTPUTS (Exact Filename & Location)

### Output: Curated Genomes CSV
**Path:** `SCARAB/data/genomes/curated_genomes.csv`

**Format:** CSV with columns (in order):

```
source,BioProject_ID,organism,taxid,assembly_accession,assembly_level,N50_bp,BUSCO_completeness_percent,genome_size_mb,pub_year,DOI,quality_rank,family,tribe,subfamily,clade_position,QC_flags,include_yn
```

**New columns added by Heath:**

- `family` (string): Coleoptera family name (e.g., "Carabidae", "Curculionidae", "Chrysomelidae")
- `tribe` (string): Tribe within family if known (e.g., "Carabini", or "Unknown" if not assigned)
- `subfamily` (string): Subfamily if applicable (e.g., "Polyphaginae", or "NA" if not formally recognized)
- `clade_position` (string): Brief clade assignment for phylogenetic purposes:
  - e.g., "Adephaga", "Polyphaga_Staphylinomorpha", "Polyphaga_Scarabaeoidea"
  - Used later in Task 2.6 to build constraint tree
- `QC_flags` (string): Notes on quality concerns or special cases:
  - e.g., "NA" (no flags), "Low BUSCO (82%)", "Fragmented assembly", "Recently published, limited citations", "Potential contamination (check)"
  - Comma-separated if multiple flags
- `include_yn` (string): "YES" or "NO"
  - "YES" = include in alignment
  - "NO" = exclude (reason goes in QC_flags)

**Example rows:**

```
NCBI_RefSeq,PRJNA123456,Tribolium castaneum,7070,GCF_000001825.4,Chromosome,1200000,98.5,139.3,2016,10.1371/journal.pbio.1001841,1,Tenebrionidae,Tribolini,NA,Polyphaga_Cucujoidea,NA,YES
NCBI_GenBank,PRJNA234567,Dendroctonus ponderosae,166361,GCA_000355325.1,Scaffold,650000,94.2,210.5,2013,10.1038/nature12946,3,Curculionidae,Unknown,Scolytinae,Polyphaga_Curculionoidea,Older assembly,YES
Ensembl,Ensembl,Lucicutis castaneipennis,47365,GCA_019391965.1,Scaffold,850000,91.2,165.4,2021,10.1093/nar/gky1193,2,Lampyridae,Unknown,NA,Polyphaga_Elateroidea,NA,YES
NCBI_RefSeq,PRJNA999999,Crappy_species_X,99999,GCF_999999999.1,Contig,50000,75.0,400.0,2022,In prep,150,Unknown,Unknown,NA,Uncertain,Below quality threshold,NO
```

---

## CURATION WORKFLOW (For Heath)

### Step 1: Load Merged File
```r
library(dplyr)

merged <- read.csv("SCARAB/data/genomes/merged_genomes.csv", stringsAsFactors = FALSE)

# Review dimensions
cat(paste("Genomes to curate:", nrow(merged), "\n"))
```

### Step 2: Taxonomic Placement

For each species, assign:

**Family:** Consult:
- NCBI Taxonomy database (https://www.ncbi.nlm.nih.gov/taxonomy)
- Taxon name in assembly metadata or linked paper
- Coleoptera taxonomic references (e.g., Slipinski comprehensive beetle family-level phylogeny)

**Subfamily / Tribe:** Optional, useful if known from literature

**Clade position:** Assign to major Coleoptera clade:
- **Archaeorhyncha** (basal)
- **Myxophaga** (basal, aquatic)
- **Adephaga** (ground beetles, diving beetles)
- **Polyphaga** (vast majority of beetles):
  - **Staphylinomorpha** (rove beetles, silphids)
  - **Scarabaeoidea** (dung beetles, rhinoceros beetles)
  - **Curculionoidea** (weevils)
  - **Elateroidea** (click beetles, fireflies)
  - **Cucujoidea** (various small beetles)
  - **Other Polyphaga**

Cite clade position to phylogenetic literature (e.g., Crowson, recent phylogenomic papers).

### Step 3: QC Review

For each genome, check:

**Red flags (consider exclude = "NO"):**
- N50 < 100 kb (fragmented)
- BUSCO < 85% (incomplete)
- Genome size > 600 Mb or < 100 Mb (outlier)
- Contig-level assembly (no gaps spanned)
- Retracted or flagged publication
- Species name uncertain or strain mismatch

**Yellow flags (include = "YES" but document):**
- BUSCO 85-90% (acceptable but lower)
- N50 100-200 kb (acceptable but low)
- Recent preprint, not yet peer-reviewed
- Limited publication history (few citations, new assembly)

**Green flags (no concerns):**
- N50 > 500 kb
- BUSCO > 95%
- Chromosome or high-quality scaffold
- Published in peer-reviewed journal

### Step 4: Inclusion Decision

For each genome, decide: **include_yn = YES or NO**

**Criteria for YES:**
- Quality thresholds passed (N50 ≥ 100 kb, BUSCO ≥ 85% if available, assembly_level ≥ Scaffold)
- Taxonomically identifiable (species name not uncertain)
- No retracted/flagged status
- Goal: ≥50 genomes marked YES

**Criteria for NO:**
- Fails quality thresholds
- Species identity uncertain
- Assembly flagged by NCBI or journal (e.g., retracted)
- Redundant species (prefer already-selected genome of same species)

### Step 5: Export Curated File

```r
# Add curation columns (manual fill-in as data frame, or read from spreadsheet)
curated <- merged %>%
  mutate(
    family = NA_character_,         # MANUAL INPUT
    tribe = NA_character_,          # MANUAL INPUT
    subfamily = NA_character_,      # MANUAL INPUT
    clade_position = NA_character_, # MANUAL INPUT
    QC_flags = NA_character_,       # MANUAL INPUT
    include_yn = NA_character_      # MANUAL INPUT
  )

# [HEATH FILLS IN ALL COLUMNS ABOVE]

# Save
write.csv(
  curated,
  "SCARAB/data/genomes/curated_genomes.csv",
  row.names = FALSE
)

cat(paste("Curated inventory saved. Include count:", sum(curated$include_yn == "YES", na.rm = TRUE), "\n"))
```

---

## CURATION PROCESS (Recommended Approach for Heath)

### Option A: Manual in Spreadsheet (Fastest for ~60-80 genomes)

1. Export merged_genomes.csv to Excel or Google Sheets
2. Add columns: family, tribe, subfamily, clade_position, QC_flags, include_yn
3. Sort by organism name alphabetically (easier to work through)
4. For each row:
   - Open NCBI Taxonomy page for organism
   - Assign family, tribe, clade
   - Review assembly quality (check QC_flags)
   - Decide include YES/NO
5. Save as CSV

**Tools:** Excel, Google Sheets, or LibreOffice Calc

---

### Option B: R Interactive (If Familiar with R)

```r
# Start with merged file
curated <- read.csv("SCARAB/data/genomes/merged_genomes.csv", stringsAsFactors = FALSE)

# Add empty curation columns
curated <- curated %>%
  mutate(
    family = "",
    tribe = "",
    subfamily = "",
    clade_position = "",
    QC_flags = "",
    include_yn = ""
  )

# Manual workflow: for each species, populate columns
# Example entry (you fill in rest):
curated[curated$organism == "Tribolium castaneum", "family"] <- "Tenebrionidae"
curated[curated$organism == "Tribolium castaneum", "clade_position"] <- "Polyphaga_Cucujoidea"
curated[curated$organism == "Tribolium castaneum", "include_yn"] <- "YES"

# ... repeat for all species

# Verify counts
cat(paste("Genomes marked YES:", sum(curated$include_yn == "YES"), "\n"))
cat(paste("Genomes marked NO:", sum(curated$include_yn == "NO"), "\n"))

# Save
write.csv(curated, "SCARAB/data/genomes/curated_genomes.csv", row.names = FALSE)
```

---

### Option C: Hybrid (Spreadsheet + R for Processing)

1. Manual curation in spreadsheet (Excel)
2. Save as CSV
3. Use R to validate, compute summary stats, export final version

---

## REFERENCE RESOURCES FOR HEATH

**For Coleoptera taxonomy:**
- NCBI Taxonomy Browser: https://www.ncbi.nlm.nih.gov/taxonomy
- Slipinski et al. (2011) Comprehensive phylogeny of Beetles: Zool. Scr. 40:472-476
- Crowson (1981) Biology of Coleoptera (monograph, older but foundational)
- McKenna et al. (2015) Phylogeny of Coleoptera phylogenomic study
- Recent papers in Systematic Entomology, Molecular Phylogenetics & Evolution

**For assembly quality standards:**
- NCBI Assembly guidelines (https://www.ncbi.nlm.nih.gov/assembly/docs/submission_objects/)
- BUSCO benchmarking paper (https://academic.oup.com/bioinformatics/article/31/19/3210/211866)
- Zoonomia methods (from Phase 1 literature review)

---

## QUALITY ASSURANCE CHECKS

Before finalizing, verify:

```r
# Check completeness
missing_data <- curated %>%
  filter(include_yn == "YES") %>%
  summarise(
    missing_family = sum(is.na(family) | family == ""),
    missing_clade = sum(is.na(clade_position) | clade_position == ""),
    missing_include = sum(is.na(include_yn) | include_yn == "")
  )

if (max(missing_data) > 0) {
  cat("WARNING: Some genomes missing critical fields!\n")
  print(missing_data)
}

# Count by clade
cat("\nGenomes by clade (include=YES only):\n")
print(table(curated$clade_position[curated$include_yn == "YES"]))

# Check that no single family dominates
cat("\nGenomes by family (include=YES only):\n")
family_dist <- sort(table(curated$family[curated$include_yn == "YES"]), decreasing = TRUE)
print(head(family_dist, 10))

# Verify ≥50 genomes included
included_count <- sum(curated$include_yn == "YES", na.rm = TRUE)
cat(paste("\nTotal genomes for alignment:", included_count, "\n"))
if (included_count < 50) {
  cat("WARNING: Fewer than 50 genomes selected. Reconsider quality thresholds.\n")
}
```

---

## EXAMPLE QC_FLAGS ENTRIES

- **"NA"** — No concerns
- **"Low BUSCO (82%)"** — Below 85% but acceptable given other merits
- **"Fragmented assembly, N50 85 kb"** — Low N50 but still useful
- **"Preprint, limited citations"** — Recent, not yet widely validated
- **"Potential contamination"** — Check NCBI Assembly page for reports
- **"Older assembly (2015), good quality"** — Timestamp concern but still solid
- **"Uncertain species ID, check literature"** — Subspecies or strain unclear

---

## FINAL DELIVERABLES

**File:** `SCARAB/data/genomes/curated_genomes.csv`

**Must contain:**
- All rows from merged_genomes.csv
- All original 12 columns (source through quality_rank)
- 6 new columns (family through include_yn)
- ≥50 rows with include_yn = "YES"
- All critical fields populated (no NAs in family, clade_position, include_yn for include_yn=YES rows)

---

## ACCEPTANCE CRITERIA

Task 2.4 is complete when:

- [ ] All ≥60 genomes assigned to family and clade_position
- [ ] All genomes marked include_yn = "YES" or "NO"
- [ ] ≥50 genomes marked "YES" (for Phase 3 alignment)
- [ ] QC_flags documented for all genomes with concerns
- [ ] Clade representation is reasonable (not dominated by one family or clade)
- [ ] File saved in exact path: `SCARAB/data/genomes/curated_genomes.csv`
- [ ] Heath approves taxonomic assignments (spot-check at least 10 entries against NCBI Taxonomy)

---

## NOTES FOR HEATH

- **Time estimate:** 0.5-1 FTE day for ~60 genomes (10-15 min per genome)
- **No parallel processing needed:** This is serial, expertise-dependent work (your domain knowledge is critical)
- **Blocking downstream tasks:** Task 2.5 (FASTA retrieval) can start once this is done; doesn't need to wait for Tasks 2.6-2.7
- **QC is not re-done:** Once you mark include_yn="YES", that decision is locked for Phase 3

---

## NEXT STEP

Once Task 2.4 is complete, proceed to **HOWTO_05_fasta_urls.md** (Task 2.5).

---

*HOWTO 2.4 | Phase 2 Task 4 | SCARAB | Draft: 2026-03-21*
