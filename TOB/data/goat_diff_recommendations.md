# GoaT Coleoptera Inventory Diff Report

**GoaT index:** `taxon--ncbi--goat--2026.04.20`  
**TOB inventory:** `ncbi_inventory_refresh_2026-05.csv` (1105 accessions)  
**Query:** `tax_tree(Coleoptera) AND assembly_span>0` (assembly endpoint) + sequencing_status pipeline taxa

## Key Finding

GoaT's assembly endpoint (955 records across 568 species) is **fully covered** by the TOB inventory.
TOB has 150 assemblies that GoaT does not track (likely non-EBP submissions).
The real gap is **in-pipeline species** (121 taxa) that DToL/ERGA have sampled but not yet deposited to INSDC.

## Summary Counts

| Metric | Count |
|--------|-------|
| GoaT Coleoptera assembly records (all versions) | 955 |
| Unique Coleoptera species with assemblies in GoaT | 568 |
| Primary assemblies (non-alternate-haplotype) | 739 |
| Alternate haplotype assemblies | 216 |
| GoaT assemblies already in TOB (exact accession) | 955 |
| GoaT assemblies in TOB (version mismatch) | 0 |
| GoaT GCA_ assemblies NOT in TOB | 0 |
| TOB assemblies not tracked by GoaT | 150 |
| **In-pipeline taxa (no GCA_ yet)** | **121** |
| -- sample_collected | 78 |
| -- sample_acquired | 31 |
| -- in_progress | 12 |

## New GCA_ Assemblies NOT in TOB

**None.** All 955 GoaT assembly records (all accession versions) are already present in TOB.

TOB has 150 accessions that GoaT does not track — these are non-EBP affiliated assemblies
submitted independently to NCBI (captured by NCBI Datasets but not GoaT's curated list).

## In-Pipeline Taxa by Suborder

| Suborder | Tracked by GoaT |
|----------|----------------|
| Polyphaga | 88 |
| Adephaga | 33 |

## In-Pipeline Taxa by Family (top 15)

| Family | Count | Status breakdown |
|--------|-------|-----------------|
| Carabidae | 21 | sample_collected:11, sample_acquired:8, in_progress:2 |
| Hydrophilidae | 21 | sample_collected:17, sample_acquired:4 |
| Chrysomelidae | 20 | sample_collected:12, sample_acquired:5, in_progress:3 |
| Curculionidae | 10 | sample_collected:8, sample_acquired:2 |
| Scarabaeidae | 7 | sample_collected:4, sample_acquired:3 |
| Cerambycidae | 7 | sample_collected:4, sample_acquired:3 |
| Dytiscidae | 6 | sample_collected:6 |
| Tenebrionidae | 5 | sample_acquired:3, sample_collected:1, in_progress:1 |
| Gyrinidae | 4 | sample_collected:4 |
| Geotrupidae | 4 | sample_collected:2, sample_acquired:2 |
| Coccinellidae | 3 | sample_collected:2, sample_acquired:1 |
| Dermestidae | 3 | in_progress:3 |
| Haliplidae | 2 | sample_collected:2 |
| Helophoridae | 1 | sample_collected:1 |
| Leiodidae | 1 | sample_collected:1 |

## In-Pipeline Species List

These taxa are being sequenced by EBP-affiliated projects (primarily DToL/ERGA) but have no INSDC accession yet.
Monitor GoaT to detect when status advances to 'published'.

### in_progress (actively being assembled, highest priority)

- *Cantharis pellucida* (Cantharidae) — Polyphaga
- *Carabus intricatus* (Carabidae) — Adephaga
- *Amara aulica* (Carabidae) — Adephaga
- *Diabrotica cristata* (Chrysomelidae) — Polyphaga
- *Acalymma vittatum* (Chrysomelidae) — Polyphaga
- *Xanthogaleruca luteola* (Chrysomelidae) — Polyphaga
- *Trogoderma inclusum* (Dermestidae) — Polyphaga
- *Trogoderma variabile* (Dermestidae) — Polyphaga
- *Dermestes maculatus* (Dermestidae) — Polyphaga
- *Lasioderma serricorne* (Ptinidae) — Polyphaga
- *Oryzaephilus mercator* (Silvanidae) — Polyphaga
- *Tribolium brevicornis* (Tenebrionidae) — Polyphaga

### sample_acquired (sample in hand, sequencing imminent)

- *Cicindela hybrida* (Carabidae) — Adephaga
- *Calosoma inquisitor* (Carabidae) — Adephaga
- *Cychrus caraboides* (Carabidae) — Adephaga
- *Harpalus attenuatus* (Carabidae) — Adephaga
- *Anisodactylus binotatus* (Carabidae) — Adephaga
- *Stomis pumicatus* (Carabidae) — Adephaga
- *Bembidion lampros* (Carabidae) — Adephaga
- *Agonum muelleri* (Carabidae) — Adephaga
- *Mallodon dasystomus* (Cerambycidae) — Polyphaga
- *Tetrops praeustus* (Cerambycidae) — Polyphaga
- *Pogonocherus hispidus* (Cerambycidae) — Polyphaga
- *Phratora vulgatissima* (Chrysomelidae) — Polyphaga
- *Chaetocnema concinna* (Chrysomelidae) — Polyphaga
- *Psylliodes marcidus* (Chrysomelidae) — Polyphaga
- *Cassida viridis* (Chrysomelidae) — Polyphaga
- *Cryptocephalus hypochaeridis* (Chrysomelidae) — Polyphaga
- *Coccidula scutellata* (Coccinellidae) — Polyphaga
- *Sciaphilus asperatus* (Curculionidae) — Polyphaga
- *Pissodes castaneus* (Curculionidae) — Polyphaga
- *Geotrupes mutator* (Geotrupidae) — Polyphaga
- *Geotrupes stercorarius* (Geotrupidae) — Polyphaga
- *Cercyon melanocephalus* (Hydrophilidae) — Polyphaga
- *Cercyon impressus* (Hydrophilidae) — Polyphaga
- *Enochrus quadripunctatus* (Hydrophilidae) — Polyphaga
- *Helochares punctatus* (Hydrophilidae) — Polyphaga
- *Aphodius pedellus* (Scarabaeidae) — Polyphaga
- *Aphodius pusillus* (Scarabaeidae) — Polyphaga
- *Acrossus luridus* (Scarabaeidae) — Polyphaga
- *Pimelia cribra* (Tenebrionidae) — Polyphaga
- *Pimelia interjecta* (Tenebrionidae) — Polyphaga
- *Pimelia modesta* (Tenebrionidae) — Polyphaga

### sample_collected (earliest stage)

- *Rhopalapion longirostre* (Apionidae) — Polyphaga
- *Carabus arvensis* (Carabidae) — Adephaga
- *Amara similata* (Carabidae) — Adephaga
- *Pterostichus melanarius* (Carabidae) — Adephaga
- *Bembidion minimum* (Carabidae) — Adephaga
- *Bembidion iricolor* (Carabidae) — Adephaga
- *Bembidion lunulatum* (Carabidae) — Adephaga
- *Trechus obtusus* (Carabidae) — Adephaga
- *Trechus quadristriatus* (Carabidae) — Adephaga
- *Limodromus assimilis* (Carabidae) — Adephaga
- *Agonum ericeti* (Carabidae) — Adephaga
- *Demetrias imperialis* (Carabidae) — Adephaga
- *Prionus coriarius* (Cerambycidae) — Polyphaga
- *Obrium brunneum* (Cerambycidae) — Polyphaga
- *Leiopus nebulosus* (Cerambycidae) — Polyphaga
- *Saperda populnea* (Cerambycidae) — Polyphaga
- *Chrysolina varians* (Chrysomelidae) — Polyphaga
- *Timarcha goettingensis* (Chrysomelidae) — Polyphaga
- *Crepidodera plutus* (Chrysomelidae) — Polyphaga
- *Podagrica fuscipes* (Chrysomelidae) — Polyphaga
- *Phyllotreta astrachanica* (Chrysomelidae) — Polyphaga
- *Longitarsus ballotae* (Chrysomelidae) — Polyphaga
- *Longitarsus succineus* (Chrysomelidae) — Polyphaga
- *Longitarsus melanocephalus* (Chrysomelidae) — Polyphaga
- *Sermylassa halensis* (Chrysomelidae) — Polyphaga
- *Donacia clavipes* (Chrysomelidae) — Polyphaga
- *Donacia vulgaris* (Chrysomelidae) — Polyphaga
- *Cryptocephalus bipunctatus* (Chrysomelidae) — Polyphaga
- *Chilocorus bipustulatus* (Coccinellidae) — Polyphaga
- *Rhyzobius lophanthae* (Coccinellidae) — Polyphaga
- *Sitona suturalis* (Curculionidae) — Polyphaga
- *Barynotus squamosus* (Curculionidae) — Polyphaga
- *Otiorhynchus salicicola* (Curculionidae) — Polyphaga
- *Otiorhynchus raucus* (Curculionidae) — Polyphaga
- *Otiorhynchus pseudonothus* (Curculionidae) — Polyphaga
- *Phyllobius maculicornis* (Curculionidae) — Polyphaga
- *Rhinusa antirrhini* (Curculionidae) — Polyphaga
- *Scolytus rugulosus* (Curculionidae) — Polyphaga
- *Dytiscus marginalis* (Dytiscidae) — Adephaga
- *Scarodytes halensis* (Dytiscidae) — Adephaga
- *Agabus affinis* (Dytiscidae) — Adephaga
- *Agabus nebulosus* (Dytiscidae) — Adephaga
- *Ilybius fuliginosus* (Dytiscidae) — Adephaga
- *Ilybius montanus* (Dytiscidae) — Adephaga
- *Typhaeus typhoeus* (Geotrupidae) — Polyphaga
- *Trypocopris vernalis* (Geotrupidae) — Polyphaga
- *Gyrinus suffriani* (Gyrinidae) — Adephaga
- *Gyrinus paykulli* (Gyrinidae) — Adephaga
- *Gyrinus caspius* (Gyrinidae) — Adephaga
- *Gyrinus distinctus* (Gyrinidae) — Adephaga
- *Haliplus confinis* (Haliplidae) — Adephaga
- *Haliplus flavicollis* (Haliplidae) — Adephaga
- *Helophorus minutus* (Helophoridae) — Polyphaga
- *Cercyon analis* (Hydrophilidae) — Polyphaga
- *Cercyon haemorrhoidalis* (Hydrophilidae) — Polyphaga
- *Cercyon marinus* (Hydrophilidae) — Polyphaga
- *Cercyon tristis* (Hydrophilidae) — Polyphaga
- *Cercyon ustulatus* (Hydrophilidae) — Polyphaga
- *Enochrus coarctatus* (Hydrophilidae) — Polyphaga
- *Enochrus halophilus* (Hydrophilidae) — Polyphaga
- *Enochrus affinis* (Hydrophilidae) — Polyphaga
- *Enochrus bicolor* (Hydrophilidae) — Polyphaga
- *Enochrus fuscipennis* (Hydrophilidae) — Polyphaga
- *Anacaena bipustulata* (Hydrophilidae) — Polyphaga
- *Anacaena lutescens* (Hydrophilidae) — Polyphaga
- *Laccobius sinuatus* (Hydrophilidae) — Polyphaga
- *Laccobius ytenensis* (Hydrophilidae) — Polyphaga
- *Hydrophilus piceus* (Hydrophilidae) — Polyphaga
- *Helochares lividus* (Hydrophilidae) — Polyphaga
- *Helochares obscurus* (Hydrophilidae) — Polyphaga
- *Cryptolestes ferrugineus* (Laemophloeidae) — Polyphaga
- *Leiodes politus* (Leiodidae) — Polyphaga
- *Lucanus cervus* (Lucanidae) — Polyphaga
- *Trichius fasciatus* (Scarabaeidae) — Polyphaga
- *Trichius gallicus* (Scarabaeidae) — Polyphaga
- *Aphodius lapponum* (Scarabaeidae) — Polyphaga
- *Planolinoides borealis* (Scarabaeidae) — Polyphaga
- *Pimelia elevata* (Tenebrionidae) — Polyphaga

## Accessions to Add to Next Pull

**No new accessions to add from GoaT.** TOB inventory is more comprehensive than GoaT for assembled Coleoptera.

**Recommended action:** Set up periodic GoaT monitoring (monthly) to detect species
advancing from 'in_progress' to 'published'. Priority watch list: 12 in_progress + 31 sample_acquired taxa.

## Notes

- Assembly name prefixes used for project inference: ic/il/id/ia/iy=DToL; dr/ds/bge/xb=ERGA; ag/aag=Ag100Pest
- GoaT sequencing_status values queried: published, sample_collected, sample_acquired, in_progress
- GoaT does NOT expose ENA-only (PRJEB) records separately in the assembly endpoint; all 955 records have GCA_ accessions
- Version mismatches (0 records): GoaT accession version differs from TOB entry; treated as covered.
- GoaT index date: 2026.04.20
