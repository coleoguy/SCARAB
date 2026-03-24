# HOWTO 1.1: Search Similar Projects & Competitive Landscape

**Phase:** Phase 1 - Literature Review
**Task:** 1.1 Systematic Search for Beetle/Insect Genome Projects
**Timeline:** Day 1-2
**Executor:** Team (parallel searches recommended)

---

## OBJECTIVE

Identify all published and in-progress beetle and insect whole-genome alignment, synteny, and ancestral karyotype projects. Assess scooping risk, document competitor methods, and capture all foundational references.

**Output acceptance criteria:** ≥20 relevant projects/papers reviewed and documented

---

## INPUT

**None.** This is the first data collection task. No prior outputs needed.

---

## OUTPUTS (Exact Filenames & Locations)

### Output 1: Competitive Landscape CSV
**Path:** `SCARAB/results/phase1_literature/competitive_landscape.csv`

**Format:** CSV with columns (in order):
```
project_name,taxa,scope,status,publication_status,url,threat_level,notes
```

**Column definitions:**
- `project_name` (string): Name of the project or paper (e.g., "Zoonomia", "i5k Insect Genomes")
- `taxa` (string): Organisms covered (e.g., "insects" or "beetles, 40+ species" or "Diptera")
- `scope` (string): What analysis (e.g., "synteny atlas", "whole-genome alignment", "karyotype reconstruction", "phylogenomic tree")
- `status` (string): Project stage (e.g., "published", "in-press", "bioRxiv preprint", "GitHub active", "inactive/stalled")
- `publication_status` (string): Peer-reviewed journal, preprint, or unpublished (e.g., "Nature 2024", "bioRxiv 2025", "NCBI BioProject only")
- `url` (string): PubMed ID, DOI, bioRxiv link, or GitHub repo URL
- `threat_level` (string): one of "HIGH", "MEDIUM", "LOW" (does this project directly compete with our Coleoptera angle?)
- `notes` (string): Key methods, any unexpected overlaps, publication timeline if in-progress

**Example rows:**
```
Zoonomia,mammals,whole-genome alignment & synteny atlas,published,Nature 2024,https://doi.org/10.1038/s41586-023-06457-y,MEDIUM,Methods directly applicable; bird variants exist
Avian Phylogenomics,birds,genome assembly + synteny atlas,published,Genome Res 2023,PMID:33333333,LOW,Different taxon but methods useful
i5k Consortium,insects,genome assembly + some synteny,ongoing,NCBI BioProject,https://i5k.nal.usda.gov,HIGH,Large insect effort; may include beetles
```

### Output 2: Key Papers Bibliography
**Path:** `SCARAB/results/phase1_literature/key_papers.bib`

**Format:** BibTeX (.bib file)

**What:** All papers identified in Task 1.1, formatted as valid BibTeX entries for import into reference management.

**Minimum fields per entry:**
- author, title, year, journal (or booktitle/publisher), volume, pages, doi (or url)

**Example:**
```bibtex
@article{Zoonomia2023,
  author = {Zoonomia Consortium},
  title = {Comparative genomics across the whole mammalian tree of life},
  journal = {Nature},
  year = {2024},
  volume = {620},
  pages = {123--135},
  doi = {10.1038/s41586-023-06457-y}
}

@article{i5k2013,
  author = {i5k Consortium},
  title = {The i5k Initiative: advancing arthropod genomics for knowledge, human health, and agriculture},
  journal = {Journal of Heredity},
  year = {2013},
  volume = {104},
  pages = {595--600},
  doi = {10.1093/jhered/est049}
}
```

---

## SEARCH STRATEGY & EXACT QUERIES

### 1. PubMed Search (NCBI)

**Search 1: Beetle synteny & genome alignment**
```
(Coleoptera OR beetle*) AND (synteny OR "whole genome alignment" OR "comparative genomics" OR "ancestral karyotype")
Filters: Last 10 years, English
```

**Search 2: Insect Zoonomia-like projects**
```
(insect* OR arthropod*) AND ("genome alignment" OR "synteny atlas" OR "phylogenomic") AND (assembly OR sequencing)
Filters: Last 10 years
```

**Search 3: Large-scale genome consortia**
```
("i5k" OR "10k genomes" OR "Earth BioGenome" OR "Vertebrate Genomes") AND (synteny OR alignment OR phylogenomic)
```

**Search 4: Ancestral karyotype reconstruction in insects**
```
(insect* OR arthropod*) AND ("ancestral karyotype" OR "chromosome evolution" OR "synteny block")
```

**How to run:**
1. Go to https://pubmed.ncbi.nlm.nih.gov/
2. Paste each search string into the search box
3. Apply filters (date range, language)
4. Export results (select all, "Send to" → File → CSV format)
5. Document count and record top 5-10 most relevant papers

---

### 2. bioRxiv Search (Cold Spring Harbor)

**Search 1: Beetle genomics**
```
site:biorxiv.org "Coleoptera" OR "beetle" genome alignment synteny
```

**Search 2: Insect genome projects**
```
site:biorxiv.org "insect" "whole genome" alignment synteny phylogenomic
```

**Search 3: Recent preprints on phylogenomic methods**
```
site:biorxiv.org "synteny" "comparative genomics" arthropod OR insect
(sort by: date, newest first)
```

**How to run:**
1. Go to https://www.biorxiv.org/ or use Google Scholar
2. For bioRxiv-specific: go to bioRxiv.org and use their search
3. For broad: use Google Scholar (scholar.google.com) with site filters
4. Record preprint date, authors, and stage (some may be published since posting)

---

### 3. Google Scholar Advanced Search

**Query 1:** "beetle genome" OR "Coleoptera genome" synteny alignment
**Query 2:** insect phylogenomics "synteny atlas"
**Query 3:** "ancestral genome" reconstruction arthropod OR insect

**Tips:**
- Use "Cited by" links to find citing papers (forward citations)
- Sort by: recent first, then by citation count for foundational works
- Check "Full text" links to find preprints/OA versions

---

### 4. NCBI BioProject Search

**URL:** https://www.ncbi.nlm.nih.gov/bioproject

**Search filters:**
- Organism: Coleoptera
- Project Type: genome sequencing, comparative genomics
- Status: active, completed

**What to document:**
- Project ID, PI/contact info, number of genomes/species
- Assembly accessions included
- Publication status, DOI

**Also check:**
- NCBI Genome (https://www.ncbi.nlm.nih.gov/genome) for large taxon-level summaries
- NCBI Assembly (https://www.ncbi.nlm.nih.gov/assembly) for consortium efforts

---

### 5. Ensembl Metazoa Project Pages

**URL:** http://metazoa.ensembl.org

**Search:** Browse species tree, look for Coleoptera subtree
**What to document:**
- Which beetles have Ensembl gene annotation
- Any linked synteny or alignment projects
- Contact info for Ensembl Metazoa team

---

### 6. GitHub / Open Science Repositories

**Search queries:**
```
site:github.com "beetle" OR "Coleoptera" genome synteny alignment
site:github.com "insect" phylogenomics "whole genome"
```

**Also check:**
- Zenodo (https://zenodo.org) for data releases
- Open Science Framework (https://osf.io) for preregistered projects
- GitHub trending: search "genomics" + "comparative" + "insects"

---

### 7. Grey Literature & Consortium Pages

**Check manually:**
- **i5k Consortium:** https://i5k.nal.usda.gov (ongoing insect genome effort)
- **Earth BioGenome Project:** https://www.earthbiogenome.org (includes arthropods)
- **Genome 10K Project:** https://genome10k.soe.ucsc.edu (historical but foundational)
- **Zoonomia project:** https://zoonomia.sanger.ac.uk (mammal reference, but methods apply)

---

## WHAT TO LOOK FOR

When reviewing each project/paper, record:

1. **Direct competitors (HIGH threat):**
   - Published or preprint Coleoptera synteny atlas
   - Active beetle whole-genome alignment project
   - In-progress ancestral karyotype work on beetles
   - Publication date within last 2 years or in-press

2. **Related efforts (MEDIUM threat):**
   - Large insect genome projects (i5k, Diptera, Lepidoptera) with alignment/synteny methods
   - Non-insect arthropod synteny (crustaceans, arachnids) showing feasibility
   - Mammal/bird Zoonomia projects publishing methods/data we can adapt

3. **Foundational references (LOW threat but HIGH value):**
   - Method papers on synteny detection, multi-genome alignment
   - Tool papers (eg., progressiveCactus, LASTZ, HAL)
   - Ancestral karyotype reconstruction algorithms
   - Coleoptera phylogenetics papers (inform tree topology)

---

## SPREADSHEET WORKFLOW

### How to populate `competitive_landscape.csv`:

1. **Create a blank CSV** with headers in your tool of choice (R, Python, Excel)
   ```r
   # R example
   df <- data.frame(
     project_name = character(),
     taxa = character(),
     scope = character(),
     status = character(),
     publication_status = character(),
     url = character(),
     threat_level = character(),
     notes = character()
   )
   ```

2. **For each search result:**
   - Read title and abstract
   - Extract project name, taxa, scope, and status
   - Assign threat level (HIGH if direct beetle competitor, MEDIUM if insect methods, LOW if methods-only)
   - Note publication status and URL/DOI
   - Add 1-2 sentence note about relevance or methods

3. **Deduplication:**
   - Multiple references to same project = one row
   - If same paper published in preprint + journal, pick most recent/complete version but note both URLs

4. **Save as CSV** (comma-separated, UTF-8 encoding)

---

## CODE EXAMPLE: PubMed Query via R

If you want to automate PubMed downloads (optional):

```r
# Install packages if needed
# install.packages("rentrez")
library(rentrez)

# Example: search PubMed for beetle genome projects
result <- entrez_search(
  db = "pubmed",
  term = '(Coleoptera OR beetle*) AND (synteny OR "whole genome alignment")',
  retmax = 100,
  use_history = TRUE
)

# Fetch article summaries
summaries <- entrez_summary(db = "pubmed", web_history = result$web_history, rettype = "xml")

# Parse and extract data
# (This requires XML parsing; consult rentrez vignette for full example)
```

---

## CODE EXAMPLE: bioRxiv via API

If you want to query bioRxiv programmatically (optional):

```r
library(httr)
library(jsonlite)

# bioRxiv API endpoint for recent preprints
url <- "https://api.biorxiv.org/details/biorxiv/2023-01-01/2026-12-31/0"
response <- GET(url)
data <- fromJSON(content(response, "text"))

# Filter for beetle/insect keyword mentions
results <- data$collection %>%
  filter(grepl("beetle|Coleoptera|insect.*genome", title, ignore.case = TRUE))

# Extract key info and write to CSV
write.csv(results, "biorxiv_results.csv", row.names = FALSE)
```

---

## ACCEPTANCE CRITERIA

Task 1.1 is complete when:

- [ ] ≥20 unique projects/papers documented in `competitive_landscape.csv`
- [ ] All entries have complete columns (no NAs in critical fields: project_name, taxa, scope, threat_level)
- [ ] At least 1 HIGH threat project identified (or documented as "none found")
- [ ] BibTeX file `key_papers.bib` contains ≥15 entries with valid syntax
- [ ] All URLs tested and confirmed accessible (or noted as "unavailable")
- [ ] Threat levels justified in notes (peer reviewer should understand why HIGH/MEDIUM/LOW)
- [ ] Files saved in exact paths:
  - `SCARAB/results/phase1_literature/competitive_landscape.csv`
  - `SCARAB/results/phase1_literature/key_papers.bib`

---

## NEXT STEP

Once Task 1.1 is complete, proceed to **HOWTO_02_zoonomia_landscape.md** (Task 1.2).

---

*HOWTO 1.1 | Phase 1 Task 1 | SCARAB | Draft: 2026-03-21*
