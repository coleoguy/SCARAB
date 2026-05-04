# Non-NCBI Coleoptera Genome Repository Survey

**Date:** 2026-05-03  
**Purpose:** Identify Coleoptera genome/transcriptome resources outside NCBI Assembly that may supplement the 1,105-assembly TOB inventory from E-utils.  
**Context:** NCBI query returned 1,105 Coleoptera + outgroup assemblies. This survey checks whether meaningful beetle data exist in parallel or pre-release repositories.

---

## 1. Darwin Tree of Life (DToL)

**URL:** https://www.darwintreeoflife.org/  
**Data Portal:** https://portal.darwintreeoflife.org/  
**Tracking:** https://portal.darwintreeoflife.org/tracking  
**GitHub interim data:** https://github.com/darwintreeoflife/darwintreeoflife.data  
**Genome Notes (Sanger):** https://www.sanger.ac.uk/data/genome-notes-darwin-tree-of-life/

### Scope
Aims to sequence all ~70,000 eukaryotic species in Britain and Ireland. Beetles are a major arthropod component. As of 2022, the project had passed 500 genome assemblies; the project has accelerated since. UK beetle fauna comprises several thousand species, making Coleoptera a large fraction of the target list.

### Relationship to NCBI
All DToL primary assemblies are submitted to ENA (EMBL-EBI) and subsequently mirrored to NCBI via INSDC daily exchange. **However**, DToL operates a pre-release pipeline:
- Raw reads and early-pass assemblies are deposited in the DToL portal before ENA submission.
- There is a lag—often weeks to months—between data appearing in the portal/ENA and being indexed in NCBI Assembly.
- NCBI Assembly occasionally lacks records for newly submitted ENA entries even after formal submission.

### Coleoptera-specific entries
Numerous published "Genome Notes" confirm beetle assemblies in 2024–2025, including:
- *Bruchidius siliquastri* (Bruchidae) — PRJEB65735
- *Taphrorychus bicolor* (Scolytinae, Curculionidae)
- *Anaspis maculata* (Scraptiidae)
- *Crepidodera aurea* (Chrysomelidae)
- *Hermaeophaga mercurialis* (Chrysomelidae)
- *Cantharis flavilabris* (Cantharidae)
- *Agrilus cyanescens* (Buprestidae)
- *Galeruca laticollis* (Chrysomelidae)
- *Rhagium mordax* (Cerambycidae)
- *Crioceris asparagi* (Chrysomelidae)
- *Neocrepidodera transversa* (Chrysomelidae)
- *Harpalus rufipes* (Carabidae)
- *Dorcus parallelipipedus* (Lucanidae)
- *Melolontha melolontha* (Scarabaeidae)
- *Malachius bipustulatus* (Malachiidae)
- *Nebria brevicollis* (Carabidae)
- *Elmis aenea* (Elmidae)
- *Lagria hirta* (Tenebrionidae)
- *Eledona agricola* (Tenebrionidae)
- *Malthinus seriepunctatus* (Cantharidae)
- *Colydium elongatum* (Zopheridae)

**Estimated count of DToL Coleoptera assemblies in portal:** ~40–60 species at various pipeline stages, with ~20+ having published Genome Notes (confirmed ENA/NCBI submissions). Some portal-stage assemblies may lag NCBI by weeks to months.

### Programmatic access
```bash
# DToL Portal API (species status tracking)
curl "https://portal.darwintreeoflife.org/api/v1/root?taxonomyFilter=Coleoptera" 

# GoaT API - cross-references DToL project status for any taxon
curl "https://goat.genomehubs.org/api/v2/search?query=tax_tree(Coleoptera)%20AND%20dtol_status%3Dsequenced&result=taxon&fields=dtol_status,assembly_span&limit=100"

# DToL GitHub interim data (CSV with all registered species + pipeline stage)
# https://github.com/darwintreeoflife/darwintreeoflife.data/blob/main/data/status.csv
```

### Standout assemblies not confirmed in NCBI
- Any assemblies currently at "assembled" or "curated" stage in the portal that have not yet been submitted to ENA. Check the portal tracking page and compare ENA accessions against NCBI Assembly.
- Pre-release assemblies: DToL explicitly states that early-pass assemblies are posted before ENA submission for community use.

**Priority: HIGH** — active pipeline producing chromosome-level beetle genomes weekly; portal pre-release data represents the highest-value gap.

---

## 2. BAT1K Consortium

**URL:** https://bat1k.com/  
**GenomeArk:** https://www.genomeark.org/bat1k-all/

### Scope
BAT1K is exclusively a bat (Chiroptera) genome project targeting ~1,450 bat species. It has no Coleoptera component whatsoever. Genome data are hosted on GenomeArk (also used by the Vertebrate Genomes Project, VGP), which is similarly restricted to vertebrates.

### Coleoptera entries
**Zero.** BAT1K and GenomeArk/VGP cover vertebrates only. No beetle data exist here.

### Verdict
**NOT RELEVANT** — eliminate from consideration.

---

## 3. i5K Initiative / i5K Workspace@NAL

**URL:** https://i5k.nal.usda.gov/  
**GitHub species list:** http://i5k.github.io/arthropod_genomes_at_ncbi  
**Ag100Pest sub-initiative:** http://i5k.github.io/ag100pest  
**Primary NCBI BioProject:** PRJNA163993

### Scope
Community initiative to sequence 5,000 arthropod genomes. The i5K Workspace@NAL (USDA/NAL) hosts genome browsers, annotation tracks, and analysis tools for newly sequenced arthropod genomes. Data are submitted to NCBI but the workspace hosts annotations, gene models, and community resources that are NOT on NCBI.

### Coleoptera-specific content
- **Ag100Pest:** USDA-ARS initiative targeting 100 US agricultural pest arthropods; ~50 Coleoptera targets. As of 2021 publication, 22 contig-level coleopteran assemblies generated; ongoing work through 2024–2025 (e.g., *Tribolium confusum* genome sequenced 2024). Many assemblies already deposited to NCBI, but some may be in USDA Ag Data Commons before formal NCBI submission.
- **i5K Workspace:** Hosts annotation data, Apollo annotation browsers, gene predictions, and transcriptome data for sequenced species that may not appear as separate NCBI Assembly records. Includes species from families: Chrysomelidae, Curculionidae, Scarabaeidae, Cerambycidae, Tenebrionidae.
- The i5K arthropod NCBI list (http://i5k.github.io/arthropod_genomes_at_ncbi) is the most actionable cross-reference: it maps species to NCBI BioProjects and flags pipeline stages.

### Programmatic access
```bash
# Query NCBI BioProject for all i5K submissions
curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=bioproject&term=PRJNA163993[BioProject]&retmax=1000&retmode=json"

# i5K Workspace species list (curated TSV on GitHub)
curl -L "https://raw.githubusercontent.com/i5k/i5k.github.io/master/_data/arthropod_genomes_at_ncbi.tsv"

# Ag Data Commons (USDA) for pre-publication datasets
# https://data.nal.usda.gov/i5k
```

### Standout assemblies
- *Tribolium confusum* (Tenebrionidae) — 2024 Ag100Pest genome, may precede NCBI submission
- Curculionid weevil genomes from Ag100Pest pipeline
- Annotation-only resources (gene models, transcriptomes) for species already in NCBI but with richer annotation in the workspace

**Priority: MEDIUM** — most assemblies eventually reach NCBI, but the USDA Ag Data Commons pre-publication deposits and i5K workspace annotation resources are worth checking. The i5K GitHub species list provides a direct diff tool against the TOB NCBI inventory.

---

## 4. InsectBase 3.0

**URL:** https://insect-genome.com/ (v3) / https://v2.insect-genome.com/ (v2 archive)  
**Download center:** https://www.insect-genome.com/tools/download  
**Publication:** InsectBase 3.0, *Nucleic Acids Research* 54:D1143–D1151 (2026); DOI: 10.1093/nar/gkaf1248  
**PubMed:** 41263103

### Scope
Chinese-hosted aggregator of insect genomes and multi-omics data. InsectBase 3.0 (published Nov 2025, covers data to mid-2025) contains:
- 3,020 species across 24 insect orders
- 1,651 chromosome-level assemblies
- 61,353 curated transcriptomes
- 474,300 predicted protein structure models
- Transposable element libraries
- Genome resequencing / variant data
- 3D morphological reconstructions

### Coleoptera-specific content
The per-order breakdown is not publicly tabulated in the paper abstract, but given Coleoptera's species richness (~25% of insects) and the rapid growth of beetle genome sequencing, a rough estimate is **200–400 Coleoptera genome entries** in InsectBase 3.0. The key added value over NCBI is:
1. **Curated transcriptomes** — InsectBase holds 61,353 transcriptomes, many of which are species not represented in NCBI Assembly. Beetle transcriptomes from non-model species are commonly deposited here.
2. **Protein structure predictions** — AlphaFold-derived models for beetle proteomes not mirrored to NCBI.
3. **TE libraries** — curated transposable element annotations specific to individual beetle assemblies.
4. **Aggregated annotation** — some assemblies have updated annotations in InsectBase that are more current than NCBI RefSeq.

### Key limitation
InsectBase aggregates from NCBI, ENA, and direct submissions. The assemblies themselves are typically mirrored from NCBI/ENA, so the primary genomes are NOT exclusive. However, **transcriptome datasets and species without nuclear genome assemblies** (transcriptome-only entries) may include Coleoptera species entirely absent from NCBI Assembly.

### Programmatic access
No documented REST API as of 2025. Data access is primarily via:
```bash
# Bulk download from InsectBase download center (requires web navigation)
# https://www.insect-genome.com/tools/download
# Genome FASTA, GFF, protein FASTA per species

# Web search interface
# https://insect-genome.com/ — search by order "Coleoptera"
```

**Priority: MEDIUM** — most genome assemblies are NCBI-sourced, but the transcriptome catalog (61K entries) is the largest non-NCBI resource for beetle sequence data. Worth a targeted check for beetle species with transcriptome-only entries.

---

## 5. ENA (European Nucleotide Archive)

**URL:** https://www.ebi.ac.uk/ena/browser/  
**Portal API docs:** https://ena-docs.readthedocs.io/en/latest/retrieval/programmatic-access.html  
**Advanced search:** https://www.ebi.ac.uk/ena/browser/search

### Scope
One of three INSDC partners (ENA, NCBI/GenBank, DDBJ). Daily bidirectional exchange of sequence data ensures that data submitted to ENA is mirrored to NCBI and vice versa. **However**, the exchange is not instantaneous:
- ENA → NCBI lag: typically days to weeks for assemblies.
- Some ENA records (especially rapidly-submitted DToL data) may appear in ENA search before the corresponding NCBI Assembly record is indexed.
- ERGA (European Reference Genome Atlas) submissions go to ENA first; NCBI indexing may lag.

### Coleoptera-specific gap
ENA's full portal contains 500,000+ genome assemblies total (2025). The ENA is the primary submission point for DToL, ERGA, and many European insect genome projects. Notable ERGA Coleoptera examples:
- *Carabus granulatus* (icCarGran1)
- *Carabus intricatus* (icCarIntr1)
- *Leptodirus hochenwarti* (icLepHoch2)
- *Dendarus foraminosus* (Tenebrionidae, Crete)

These likely have NCBI records but may have more recent assembly versions or raw read data in ENA.

### Programmatic access
```bash
# ENA Portal API — all Coleoptera genome assemblies
curl "https://www.ebi.ac.uk/ena/portal/api/search?result=assembly&query=tax_tree(7041)&fields=accession,assembly_name,tax_id,scientific_name,study_accession,submission_date,last_updated&format=tsv&limit=10000" > ena_coleoptera_assemblies.tsv

# Compare accession list against NCBI assembly accessions
# ENA accessions: GCA_* (GenBank) or ERZ* / PRJEB* (ENA-primary)
# PRJEB* bioprojects = ENA-primary submissions (check for NCBI mirror delay)

# ENA taxon API
curl "https://www.ebi.ac.uk/ena/browser/api/xml/7041" | grep -c "entry"

# Filter for ERGA umbrella project
curl "https://www.ebi.ac.uk/ena/portal/api/search?result=assembly&query=tax_tree(7041)%20AND%20study_accession=PRJEB47820&format=tsv"
```

### Practical approach to find ENA-only entries
```python
# Pseudocode — Python 3.6 compatible (for Grace HPC)
import urllib2
import json

# Fetch ENA Coleoptera assemblies
url = "https://www.ebi.ac.uk/ena/portal/api/search?result=assembly&query=tax_tree(7041)&fields=accession,submission_date&format=json&limit=10000"
response = urllib2.urlopen(url)
ena_assemblies = json.load(response)

# Compare against NCBI accessions from E-utils inventory
# Flag any ENA accession that starts with ERZ* (ENA-native) rather than GCA/GCF
# Also flag GCA accessions submitted within last 90 days (NCBI indexing lag window)
```

**Priority: MEDIUM-HIGH** — the ENA API query above is the single most actionable step: a 30-minute script run against NCBI's 1,105-assembly list can identify every beetle assembly in ENA not yet indexed by NCBI.

---

## 6. BIPAA (BioInformatics Platform for Agroecosystem Arthropods)

**URL:** https://bipaa.genouest.org/is/  
**Galaxy instance:** https://galaxy.genouest.org/

### Scope
INRAE (French agricultural research) platform hosting genome browsers and annotation data for agriculturally relevant arthropods. BIPAA manages three species-specific databases:
- **AphidBase** — aphids (Hemiptera; not relevant)
- **LepidoDB** — Lepidoptera (not relevant)
- **ParWaspDB** — parasitoid wasps (not relevant)

### Coleoptera-specific content
BIPAA does not maintain a Coleoptera-specific sub-database. The platform focuses on aphids, Lepidoptera, and parasitoids. Any beetle data present would be incidental.

**Verdict: LOW PRIORITY** — no dedicated Coleoptera resource. Skip unless a specific INRAE beetle project is identified.

---

## 7. ERGA (European Reference Genome Atlas)

**URL:** https://www.erga-biodiversity.eu/  
**ENA umbrella project:** PRJEB47820  
**Data portal:** https://projects.ensembl.org/erga-bge/  
**Community Genome Reports:** https://riojournal.com/topical_collection/280/

### Scope
Pan-European initiative targeting all ~200,000 eukaryotic species across European biogeographic regions. ERGA is the European node of the Earth BioGenome Project (EBP). Officially became EBP's first regional node in May 2025. All ERGA assemblies are submitted to ENA and tagged under PRJEB47820.

### Coleoptera-specific content
ERGA has produced confirmed Coleoptera assemblies:
- *Carabus granulatus* (Carabidae)
- *Carabus intricatus* (Carabidae)
- *Leptodirus hochenwarti* (Carabidae — cave beetle, IUCN Vulnerable)
- *Dendarus foraminosus* (Tenebrionidae, Crete)

ERGA Community Genome Reports (published in RIO Journal) represent a growing series. Multiple Coleoptera are in pipeline. These assemblies are submitted to ENA first; NCBI mirroring may lag by days to weeks.

### Programmatic access
```bash
# All ERGA assemblies via ENA (includes Coleoptera)
curl "https://www.ebi.ac.uk/ena/portal/api/search?result=assembly&query=tax_tree(7041)%20AND%20study_accession=PRJEB47820&fields=accession,scientific_name,submission_date&format=tsv"

# GoaT tracks ERGA project status per taxon
curl "https://goat.genomehubs.org/api/v2/search?query=tax_tree(Coleoptera)%20AND%20erga_status%3Dsequenced&result=taxon&fields=erga_status&limit=500"
```

**Priority: MEDIUM** — emerging source; NCBI catches most ERGA data but with lag. Specifically worth checking for the cave/endemic European beetle assemblies unlikely to appear in the US-centric i5K/Ag100Pest lists.

---

## 8. GoaT (Genomes on a Tree) — Cross-Repository Aggregator

**URL:** https://goat.genomehubs.org/  
**API docs:** https://goat.genomehubs.org/api-docs/  
**CLI:** https://github.com/genomehubs/goat-cli  
**Publication:** *Wellcome Open Research* 8:24; PMC9971660

### Scope
GoaT is not itself a genome repository but an Elasticsearch-powered aggregator of sequencing project metadata for ~1.5 million eukaryotic species. It tracks:
- Assembly status (sequenced, assembled, chromosome-level, annotated)
- Project affiliations (DToL, ERGA, EBP, Ag100Pest, etc.)
- Genome size estimates
- Chromosome counts

GoaT is **the single best cross-repository discovery tool** for finding beetle genomes in any EBP-affiliated project regardless of which repository they were deposited to.

### Programmatic access
```bash
# Count of Coleoptera with assemblies in any EBP-affiliated project
curl "https://goat.genomehubs.org/api/v2/count?query=tax_tree(Coleoptera)%20AND%20assembly_span%3E0&result=taxon"

# Coleoptera targeted by DToL but not yet assembled
curl "https://goat.genomehubs.org/api/v2/search?query=tax_tree(Coleoptera)%20AND%20dtol_status%3Dtarget&result=taxon&fields=dtol_status,scientific_name&limit=500"

# All Coleoptera with assemblies, with project metadata
curl "https://goat.genomehubs.org/api/v2/search?query=tax_tree(Coleoptera)%20AND%20assembly_span%3E0&result=assembly&fields=accession,scientific_name,assembly_span,project&limit=2000&offset=0" > goat_coleoptera_assemblies.json
```

**Priority: HIGH (as discovery tool)** — run the GoaT API against the TOB NCBI inventory to identify beetle assemblies in EBP-affiliated projects that are post-NCBI-query and thus missing from the 1,105-assembly list.

---

## Summary Table

| Repository | Beetle Entries | Non-NCBI Gap | Programmatic Access | Priority |
|-----------|---------------|--------------|--------------------|----|
| DToL Portal | ~40–60 assembled; 20+ Genome Notes published | Pre-release assemblies (weeks lag before NCBI) | Portal API + GoaT + GitHub CSV | HIGH |
| BAT1K | 0 | None | N/A | NONE |
| i5K Workspace@NAL | ~50+ Coleoptera (Ag100Pest targets) | Annotation data; some pre-submission Ag Data Commons deposits | GitHub species TSV; NCBI BioProject PRJNA163993 | MEDIUM |
| InsectBase 3.0 | ~200–400 est. genome entries; 61K transcriptomes | Transcriptome-only species; value-added annotation | Download center (no API) | MEDIUM |
| ENA | All NCBI assemblies + ENA-primary | PRJEB* accessions with NCBI lag; ENA-native ERZ* records | Portal REST API (tax_tree=7041) | MEDIUM-HIGH |
| BIPAA | 0 relevant | None | N/A | NONE |
| ERGA | ~10+ Coleoptera confirmed; growing | European endemic beetles; ENA-first lag | ENA API filter PRJEB47820; GoaT | MEDIUM |
| GoaT (aggregator) | Cross-references all above | Discovery tool, not a repository | REST API + CLI | HIGH (tool) |

---

## Recommended Actions

Actions are ordered by expected yield / effort ratio.

### Action 1 — GoaT API sweep (immediate, high yield)
Run a GoaT API query for all Coleoptera assemblies and compare against the TOB NCBI inventory. GoaT aggregates DToL, ERGA, Ag100Pest, and other EBP projects and includes assemblies in any pipeline stage. Expected to surface 50–150 beetle assemblies that post-date the E-utils query or are in EBP projects not yet indexed by NCBI.

```bash
# Pull all Coleoptera assemblies known to GoaT
curl "https://goat.genomehubs.org/api/v2/search?query=tax_tree(Coleoptera)%20AND%20assembly_span%3E0&result=assembly&fields=accession,scientific_name,tax_id,assembly_span,contig_n50&limit=2000&format=tsv" > goat_coleoptera.tsv

# Diff against TOB NCBI accession list
```

### Action 2 — ENA Portal API query (1 day, targeted)
Query ENA for all Coleoptera assemblies (tax_tree=7041, result=assembly) and extract the TSV. Cross-reference against NCBI accessions. Flag:
- Accessions beginning with ERZ* (ENA-native, may not be in NCBI)
- GCA/GCF accessions with submission_date within 90 days of the E-utils query date (NCBI indexing lag window)
- Accessions under ERGA umbrella (PRJEB47820) or DToL (PRJEB40665)

Expected yield: 20–50 assemblies not in the NCBI 1,105-assembly list.

### Action 3 — DToL Portal tracking page (1 hour, manual/semi-automated)
Visit https://portal.darwintreeoflife.org/tracking and filter by Coleoptera. Download the CSV of species at "assembled," "curated," or "annotation" stages. Compare against published Genome Notes and NCBI accessions. Species at "assembled" or "curated" stage may have data in the portal but not yet in ENA/NCBI.

Alternatively, use the darwintreeoflife.data GitHub repo status CSV:
```bash
curl -L "https://raw.githubusercontent.com/darwintreeoflife/darwintreeoflife.data/main/data/status.csv" | grep -i "coleoptera"
```

### Action 4 — InsectBase transcriptome catalog (targeted, medium effort)
Navigate InsectBase 3.0 to list all Coleoptera entries. Extract species with transcriptome-only records (no corresponding genome assembly). These represent beetle species with expressed-gene data but no whole-genome assembly in NCBI — useful for TOB if transcriptome-based phylogenomics is a fallback strategy. Not actionable for whole-genome alignment but relevant for gene tree bootstrapping.

### Action 5 — i5K GitHub species list diff (30 minutes)
Download the i5K arthropod genome status TSV from GitHub and filter for Coleoptera. Cross-reference against TOB NCBI list. Flag species with "in progress" or "sequenced but not submitted" status.

```bash
curl -L "http://i5k.github.io/arthropod_genomes_at_ncbi" | grep -i "coleoptera"
# Or the raw data file if available
```

### Action 6 — ERGA beetle assemblies (low effort, worth checking)
Filter ENA for ERGA Coleoptera (PRJEB47820 + tax_tree 7041). The European endemic cave and montane beetles (e.g., *Leptodirus hochenwarti*) are unlikely to appear in the TOB E-utils query if submitted recently. Small yield but phylogenetically interesting.

---

## Notes on BAT1K and BIPAA

Both can be definitively excluded:
- **BAT1K** is a bat-only project; no insect data exist in GenomeArk under this initiative.
- **BIPAA** covers aphids, Lepidoptera, and parasitoid wasps only; no Coleoptera-specific database exists.

Researcher time should not be spent on these.

---

*Survey compiled from web sources, published database papers, and API documentation. All assembly counts are estimates based on available metadata; exact counts require direct API queries against each repository.*
