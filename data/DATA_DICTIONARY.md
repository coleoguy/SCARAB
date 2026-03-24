# SCARAB Data Dictionary

Column definitions for all primary data files. Each section describes one CSV/NWK file and its columns.

---

## data/genomes/genome_catalog.csv

The master genome catalog. 1,121 rows (all assemblies found), 43+ columns.

| Column | Type | Description |
|--------|------|-------------|
| `accession` | string | NCBI assembly accession (GCA_/GCF_) |
| `species_name` | string | Binomial species name |
| `taxid` | integer | NCBI Taxonomy ID |
| `organism_name` | string | Full organism name from NCBI |
| `assembly_level` | string | Chromosome, Scaffold, Contig, or Complete Genome |
| `scaffold_n50` | integer | Scaffold N50 in bp |
| `contig_n50` | integer | Contig N50 in bp |
| `total_sequence_length` | integer | Total assembly size in bp |
| `number_of_scaffolds` | integer | Total scaffold count |
| `gc_percent` | float | GC content (%) |
| `assembly_type` | string | Haploid, diploid, etc. |
| `refseq_category` | string | RefSeq status (representative genome, etc.) |
| `submitter` | string | Submitting organization |
| `submission_date` | date | Assembly submission date |
| `bioproject` | string | NCBI BioProject accession |
| `biosample` | string | NCBI BioSample accession |
| `order` | string | Taxonomic order (Coleoptera, Neuroptera, etc.) |
| `suborder` | string | Taxonomic suborder |
| `family` | string | Taxonomic family |
| `superfamily` | string | Taxonomic superfamily |
| `is_primary` | boolean | Selected as best assembly per species |
| `quality_approved` | string | yes/conditional/no — passes quality filtering |
| `include_recommended` | boolean | Recommended for inclusion in alignment |
| `composite_score` | float | Quality score for best-per-species ranking |
| `restriction_status` | string | Data use restriction level (low/check_ebp_dtol/high) |

*Note: Not all columns listed — see CSV header for full list. Additional columns include duplicate tracking, annotation status, and publication metadata.*

---

## data/genomes/genome_catalog_primary.csv

Subset of genome_catalog.csv containing only the 687 primary selections (best assembly per species after deduplication). Same column schema.

---

## data/genomes/genome_catalog_scored.csv

genome_catalog.csv with additional scoring columns used for quality ranking. Same base columns plus:

| Column | Type | Description |
|--------|------|-------------|
| `score_assembly_level` | float | Points for chromosome > scaffold > contig |
| `score_n50` | float | Points for scaffold N50 |
| `score_refseq` | float | Points for RefSeq status |
| `score_annotation` | float | Points for gene annotation availability |

---

## data/genomes/tree_tip_mapping.csv

Maps phylogenetic tree tip labels to genome metadata. 439 rows.

| Column | Type | Description |
|--------|------|-------------|
| `tip_label` | string | Tree tip label (Genus_species format, underscores) |
| `species_name` | string | Binomial species name |
| `accession` | string | NCBI assembly accession |
| `family` | string | Taxonomic family |
| `clade` | string | Major clade (Coleoptera, Neuroptera, etc.) |
| `role` | string | `ingroup` or `outgroup` |

---

## data/genomes/constraint_tree.nwk

439-tip Newick tree based on McKenna et al. (2019) backbone topology. Branch lengths = 1.0 (uniform, non-calibrated). Used as initial constraint; superseded by calibrated tree.

---

## data/genomes/constraint_tree_calibrated.nwk

439-tip Newick tree with branch lengths in millions of years (Ma). Calibrated using 29 fossil calibration points from McKenna et al. (2019), Zhang et al. (2018), Hunt et al. (2007), Misof et al. (2014). Root age: 320 Ma. See `TREE_CALIBRATION_NOTES.md` for details.

---

## data/karyotypes/literature_karyotypes.csv

Karyotype data for all 439 SCARAB species compiled from Blackmon & Demuth database. 439 rows, 14 columns.

| Column | Type | Description |
|--------|------|-------------|
| `species` | string | Binomial species name |
| `tip_label` | string | Tree tip label matching tree_tip_mapping.csv |
| `family` | string | Taxonomic family |
| `order` | string | Taxonomic order |
| `role` | string | ingroup/outgroup |
| `match_level` | string | `species`, `genus`, or `none` — how the karyotype was matched |
| `diploid_number_2n` | integer | Diploid chromosome number (2n) |
| `sex_chromosome_system` | string | XY, Xyp, XO, NeoXY, etc. |
| `meioformula` | string | Meiotic chromosome formula |
| `n_records` | integer | Number of independent cytogenetic records |
| `diploid_range` | string | Range of reported 2n values if variable |
| `notes` | string | Additional cytogenetic notes |
| `citation` | string | Literature citation(s) |
| `source` | string | Database source (blackmon_db, literature, etc.) |

---

## data/karyotypes/coleoptera_karyotypes_full.csv

Complete Blackmon & Demuth Coleoptera Karyotype Database (4,958 records). Downloaded from github.com/coleoguy/coleochroms.

| Column | Type | Description |
|--------|------|-------------|
| `Order` | string | Taxonomic order |
| `Suborder` | string | Taxonomic suborder |
| `Family` | string | Taxonomic family |
| `Genus` | string | Genus name |
| `species` | string | Species epithet |
| `Reproductive.mode` | string | Sexual, parthenogenetic, etc. |
| `B.chromosomes` | string | Presence of B chromosomes |
| `Ploidy.level` | string | Diploid, polyploid, etc. |
| `Sex.chromosome.system` | string | XY, Xyp, XO, NeoXY, etc. |
| `Meioformula` | string | Meiotic chromosome formula |
| `Diploid.number` | integer | Diploid chromosome number (2n) |

*See database documentation at github.com/coleoguy/coleochroms for full column list.*

---

## data/karyotypes/scarab_species_list.csv

Simple species list extracted from the 439 SCARAB genomes. Used as input for karyotype matching.
