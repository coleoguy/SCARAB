# Bouchard 2024 ↔ NCBI Taxonomy Reconciliation Notes

**Date:** 2026-05-03  
**Authority:** Bouchard et al. 2024, ZooKeys 1194:1-981  
**ChecklistBank dataset:** 290628 (Coleoptera type genera and family-group names, v2.2)  
**NCBI taxonomy pull:** E-utils efetch/esearch, txid7041[subtree], db=taxonomy, 2026-05-03  

---

## Coverage Counts

| Category | Count |
|----------|-------|
| Bouchard 2024 accepted families | 231 |
| Bouchard 2024 accepted subfamilies | 560 |
| Bouchard 2024 family-level synonyms | 70 |
| NCBI Coleoptera family-rank taxa | 195 |
| NCBI Coleoptera subfamily-rank taxa | 345 |
| CSV rows (families + subfamilies combined) | 790 |

## Family-Level Match Status

| Status | Count | Description |
|--------|-------|-------------|
| exact | 176 | Bouchard name = NCBI accepted name |
| conflict | 6 | Bouchard family recognized as subfamily by NCBI (rank inflation) |
| missing | 49 | Bouchard family absent from NCBI entirely |

## Subfamily-Level Match Status

| Status | Count | Description |
|--------|-------|-------------|
| exact | 267 | Bouchard subfamily = NCBI accepted name |
| conflict | 6 | Parent family placement differs between authorities |
| missing | 286 | Bouchard subfamily absent from NCBI |

---

## Top Reconciliation Issues Requiring Manual Curation

### 1. Six Bouchard Families Demoted to Subfamilies in NCBI
NCBI lumps these into larger families; Bouchard 2024 restores family rank. All need a
`conflict` flag and will require explicit taxid remapping for any NCBI-based pipeline.

| Bouchard Family | NCBI Treatment | NCBI Parent taxid |
|-----------------|----------------|-------------------|
| Cicindelidae | Cicindelinae → Carabidae | 41064 |
| Colonidae | Coloninae → Leiodidae | 111502 |
| Disteniidae | Disteniinae → Cerambycidae | 51011 |
| Megalopodidae | Megalopodinae → Chrysomelidae | 7028 |
| Oxypeltidae | Oxypeltinae → Cerambycidae | 51011 |
| Sinopyrophoridae | Sinopyrophorinae → Elateridae | 7050 |

**Curation action:** For GenBank accession mining, these six need dual lookup: query both
the family name AND the subfamily name within the lumped family. Genomes deposited under
NCBI-lumped classifications will not retrieve under Bouchard family searches.

### 2. 16 NCBI Families Absent from Bouchard (NCBI Splits Bouchard Lumps)
NCBI recognizes these as independent families; Bouchard 2024 subsumes them.

| NCBI Family | NCBI taxid | Bouchard placement |
|-------------|------------|--------------------|
| Anischiidae | 445460 | Anischiinae within Eucnemidae |
| Apionidae | 122732 | Apioninae within Brentidae |
| Brachyceridae | 1049078 | Brachycerinae within Curculionidae |
| Cebrionidae | 1581409 | Within Elateridae/Cantharidae (subfamily unclear) |
| Cephaloidae | 433159 | Within Tenebrionidae |
| Endecatomidae | 186077 | Within Bostrichidae |
| Erirhinidae | 2878387 | Within Curculionidae |
| Ithyceridae | 122756 | Ithycerinae within Brentidae |
| Monommidae | 432754 | Within Tenebrionoidea (exact Bouchard placement needs verification) |
| Omalisidae | 195261 | Omalisinae within Elateridae |
| Plastoceridae | 195317 | Within Elateridae |
| Podabrocephalidae | 1605794 | Very recently described; Bouchard placement not confirmed |
| Silphidae | 57514 | Silphinae within Staphylinidae |
| Telegeusidae | 195318 | Telegeusinae within Omethidae |
| Trachelostenidae | 219436 | Within Anthicidae or Aderidae (needs verification) |
| Zeugophoridae | 131726 | Zeugophorinae within Megalopodidae |

**Curation action:** When querying NCBI by Bouchard family name for these 16, no results
will be returned. Must query the NCBI family name and then apply Bouchard subfamily filter.

### 3. Three Bouchard-Recognized Synonyms Still in NCBI as Accepted Families
NCBI has not yet updated these to reflect Bouchard 2024 synonymy.

| NCBI Accepted | Bouchard Status | Bouchard Accepted Name |
|---------------|-----------------|------------------------|
| Metaxinidae (taxid 1718915) | synonym | Chaetosomatidae |
| Perimylopidae (taxid 219434) | synonym | Promecheilidae |
| Propalticidae (taxid 196985) | synonym | Laemophloeidae |

**Curation action:** Genomes deposited under Metaxinidae/Perimylopidae/Propalticidae in
NCBI must be remapped to Bouchard accepted names before TOB tree tip assignment.

### 4. Six Subfamily-Level Placement Conflicts
The same family-rank split/lump disagreements propagate to subfamilies:

| Bouchard Subfamily | Bouchard Parent | NCBI Parent |
|--------------------|-----------------|-------------|
| Anoplodermatinae | Vesperidae | Cerambycidae |
| Brachycerinae | Curculionidae | Brachyceridae |
| Megalopodinae | Megalopodidae | Chrysomelidae |
| Silphinae | Staphylinidae | Silphidae |
| Sphindociinae | Tetratomidae | Ciidae |
| Vesperinae | Vesperidae | Cerambycidae |

**Curation action:** Vesperidae is a consistent conflict node — Bouchard elevates it as a
distinct family; NCBI places its subfamilies in Cerambycidae. Sphindociinae placement in
Tetratomidae vs. Ciidae is a genuine taxonomic dispute.

### 5. 49 Bouchard Families Absent from NCBI Entirely
- ~35 are Mesozoic/Paleozoic fossil families (Ponomarenko, Rohdendorf, Tillyard, etc.
  authors) that NCBI does not record because no sequences exist.
- ~14 are recently described or very rare extant families that NCBI taxonomy has not yet
  incorporated:
  - Akalyptoischiidae (Lord et al. 2010)
  - Cimberididae (Gozis, 1882) — NCBI places Cimberidinae in Nemonychidae
  - Crowsoniellidae (Iablokoff-Khnzorian, 1983)
  - Eupsilobiidae (Casey, 1895)
  - Euxestidae (Grouvelle, 1908)
  - Ischaliidae (Blair, 1920)
  - Lagrioididae (Abdullah 1968) — NCBI uses Lagriidae as synonym of Tenebrionidae
  - Lamingtoniidae (Sen Gupta & Crowson, 1969)
  - Murmidiidae (Jacquelin du Val, 1858)
  - Tasmosalpingidae (Lawrence & Britton, 1991)
  - Teredidae (Seidlitz, 1888) — NCBI uses Lymexylidae

**Curation action:** Fossil families can be excluded from Tier-3 GenBank mining but must
remain in the Bouchard classification anchor. Extant missing families require GenBank
name-synonym searches or CoL lookup of type genera to find deposited sequences.

---

## API Queries Used

### ChecklistBank (open, no auth)
```
# Dataset discovery
GET https://api.checklistbank.org/dataset?q=Bouchard&limit=20
GET https://api.checklistbank.org/dataset/290628

# Family-rank names
GET https://api.checklistbank.org/dataset/290628/nameusage/search?rank=family&limit=100&offset={N}
# (4 pages, 301 total including synonyms; 231 accepted)

# Subfamily-rank names
GET https://api.checklistbank.org/dataset/290628/nameusage/search?rank=subfamily&limit=100&offset={N}
# (8 pages, 734 total; 560 accepted)
```

### NCBI E-utils (open, no auth; User-Agent header used for politeness)
```
# Family taxids under Coleoptera
GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=taxonomy&term=txid7041[subtree]+AND+family[rank]&retmax=5000&retmode=json
# → 195 family taxids

# Fetch family records in batches of 50
GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id={ids}&retmode=xml

# Subfamily taxids under Coleoptera  
GET https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=taxonomy&term=txid7041[subtree]+AND+subfamily[rank]&retmax=5000&retmode=json
# → 345 subfamily taxids
```

---

## Output File

`bouchard2024_ncbi_reconciliation.csv` — 790 rows, columns:  
`bouchard_family, bouchard_subfamily, bouchard_authority, bouchard_superfamily, ncbi_taxid, ncbi_primary_name, ncbi_synonyms, match_status, notes`

`match_status` values: `exact` | `conflict` | `missing`
