# Coleoptera Taxonomy: Classification Authority and Programmatic Resources

*Notes for TOB (Tree of Beetles) — compiled 2026-05-03*

---

## 1. Classification Authority Hierarchy

### Primary authority: Bouchard et al. 2011

Bouchard P, Bousquet Y, Davies AE, Alonso-Zarazaga MA, Lawrence JF, Lyal CHC, Newton AF, Reid CAM, Schmitt M, Slipinski A, Smith ABT (2011) Family-group names in Coleoptera (Insecta). *ZooKeys* 88: 1–972.

Comprehensive nomenclatural catalogue: 4,887 family-group names (4,763 extant + 124 fossil) from 4,707 type genera. Recognized **211 families, 24 superfamilies, 541 subfamilies, 1,663 tribes, 740 subtribes** as valid. Standard citation for Coleoptera higher classification; baseline used by Catalogue of Life and GBIF.

### Update: Bouchard & Bousquet 2020

*ZooKeys* 922: 65–139. Addendum only — not a replacement. Added 59 available family-group names omitted from 2011; reclassified 21 previously listed unavailable names as available. No restructuring of family-level taxonomy.

### Nomenclatural update: Bouchard & Bousquet 2024

*ZooKeys* 1194. Reassesses the type genus underlying each of the >4,700 available family-group names; provides author, year, page, and current validity for each. Includes new nomenclatural acts (e.g., replacement name *Basorus* for *Sobarus* Harold in Cerambycidae). **Catalogue of Life updated its Coleoptera classification to this treatment.** This is now the most current nomenclatural authority.

### Companion references

**Slipinski A, Leschen RAB, Lawrence JF (2011)** Order Coleoptera. *Zootaxa* 3148: 203–208. Concise family-level outline with species counts, same authorship as Bouchard et al. 2011, fully consistent; useful compact reference.

**Beutel RG & Leschen RAB (eds.) Handbook of Zoology — Arthropoda: Insecta: Coleoptera** (De Gruyter): Vol. 1 (2005; 2nd ed. 2016, Archostemata–Polyphaga *partim*, 684 pp.); Vol. 2 (2010, Elateroidea–Cucujiformia *partim*, 786 pp.); Vol. 3 (2014, Phytophaga, 43 chapters). Authoritative morphological and phylogenetic treatments per suborder/superfamily. Not nomenclatural authorities — they do not supersede Bouchard 2011+ on family-group names.

### Current counts (2024–2025)

- Described extant species: ~**400,000–410,000** (up to 440,000 cited in some sources, reflecting pending descriptions)
- Extant families recognized: **~186–211** depending on treatment; Bouchard 2011 recognized 211; phylogenomic studies sample ~186; CoL currently accepts ~166–200 after synonymy
- New species described annually: ~3,000–5,000 (documented in *Biodiversity Science* annual Coleoptera compilations, 2020–2024)

---

## 2. Queryable Databases and APIs

| Database | Coleoptera coverage | Freshness | API | Notes |
|---|---|---|---|---|
| **Catalogue of Life** | Full; follows Bouchard 2024 | Monthly releases | ChecklistBank REST (`api.checklistbank.org`); JSON; no auth | Best for name reconciliation |
| **GBIF Backbone** | Synthetic; CoL as primary source above family | Annual | `api.gbif.org/v1/species/match`; `rgbif::name_backbone()` in R | Good cross-check; backbone conflicts possible |
| **NCBI Taxonomy** | Sequence-linked; Coleoptera TaxID 7041 | Continuous | E-utilities; `taxonomizr` R pkg (local SQLite) | Essential for GenBank record linkage; not a nomenclatural authority |
| **ITIS** | North American emphasis; incomplete globally | Irregular | REST + SPARQL at `itis.gov` | Inadequate for global pipeline |
| **ZooBank** | Nomenclatural acts only; pre-2012 incomplete | Near real-time | REST at `zoobank.org` | Validates name availability; not a classification database |

**Catalogue of Life detail**: ChecklistBank API returns accepted name, synonyms, and full classification to family for any queried name. JSON, no authentication for read queries. IDs are stable within a release but can change between annual releases — reconciliation tables should key on accepted name strings, not numeric IDs.

**NCBI Taxonomy detail**: Taxon IDs are embedded directly in GenBank records, making them the natural entry point for mining. The E-utilities `efetch` on TaxID 7041 traverses the tree; `taxonomizr` provides a local SQLite dump for fast bulk operations. NCBI nomenclature lags the literature and should not be used as the classification standard.

---

## 3. TOB Recommendation

**Adopted authority**: Bouchard 2011+ — the three-paper series (*ZooKeys* 88, 922, 1194). The Catalogue of Life Coleoptera section is a live implementation of this authority updated monthly.

**Recommended GenBank mining pipeline**:

1. Extract organism name and NCBI TaxID from each record via E-utilities or local `taxonomizr` dump.
2. Walk NCBI taxonomy to retrieve family/superfamily as a first-pass placement.
3. Submit family name (and ambiguous genus-level names) to the **CoL ChecklistBank API** for authoritative resolution: accepted family, synonyms, and Bouchard 2011+ placement.
4. Flag CoL non-matches or synonym redirects for manual review against ZooKeys 88, 922, or 1194.
5. Cache a local NCBI TaxID → CoL accepted family → Bouchard 2011+ family mapping table to ensure reproducibility and minimize API calls.

GBIF (`name_backbone()`) serves as a fast secondary check. ITIS and ZooBank are not in the primary path.
