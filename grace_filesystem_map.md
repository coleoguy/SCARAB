# Grace Filesystem Map — SCARAB Project

**Last updated:** 2026-03-23 (P3 BLAST running, Cactus test running)
**Base path:** `$SCRATCH/scarab` → `/scratch/user/blackmon/scarab`
**NetID:** blackmon

## Active Jobs
| Job ID | Name | Status | Submitted | Notes |
|--------|------|--------|-----------|-------|
| 18114486 | scarab_P3 (BLAST 1,286×439) | RUNNING | 2026-03-23 08:54 | long partition, 48 cores, 128GB |
| 18117479 | scarab_test (Cactus 5 genomes) | RUNNING | 2026-03-23 12:25 | medium partition, 48 cores, 360GB |

---

## Directory Structure

```
$SCRATCH/scarab/
├── cactus_seqfile.txt              # Cactus input: rooted tree (line 1) + 439 genome paths
├── coi_tree/                       # DEPRECATED — COI-based tree attempt (only 182/439 hits)
│   ├── blastdb/
│   └── hits/
├── data/
│   ├── tree_tip_mapping.csv        # accession → species → tip_label mapping (439 rows)
│   └── phase3/
├── genomes/                        # 439 genome assemblies (GCA_*/GCF_* accessions)
│   └── GCA_XXXXXXXXX.V/           # Each genome has:
│       └── ncbi_dataset/
│           └── data/
│               └── GCA_XXXXXXXXX.V/
│                   └── *.fna       # FASTA assembly file
├── hal_files/                      # Future: Cactus HAL output
├── logs/
├── nuclear_markers/
│   ├── insecta_odb10/              # BUSCO insecta database (1,367 gene profiles)
│   │   ├── ancestral              # FILE (not dir): all ancestral protein seqs
│   │   ├── ancestral_variants     # FILE (not dir): 13,663 protein variants (multi-FASTA)
│   │   ├── dataset.cfg
│   │   ├── hmms/                  # HMM profiles per BUSCO gene
│   │   ├── info/
│   │   ├── lengths_cutoff
│   │   ├── links_to_ODB10.txt
│   │   ├── prfl/                  # Profile data
│   │   ├── refseq_db.faa.gz      # RefSeq protein database
│   │   ├── refseq_db.faa.gz.md5
│   │   └── scores_cutoff
│   ├── marker_genes.tsv            # 15 selected BUSCO genes (longest) used for guide tree
│   ├── marker_proteins.fasta       # 15 concatenated query proteins for guide tree BLAST
│   ├── nuclear_guide_tree_439.nwk           # UNROOTED FastTree (15 genes, 439 tips)
│   ├── nuclear_guide_tree_439_rooted.nwk    # ROOTED on Neuropterida (for Cactus)
│   ├── reroot_tree.R                        # R script used to root the tree
│   └── tree_build_18109816/       # Working dir from guide tree build (job 18109816)
│       ├── alignments/            # Per-gene MAFFT protein alignments (15 genes)
│       ├── blast_hits/            # Per-genome BLAST results (439 genomes)
│       └── per_gene/              # Per-gene extracted sequences
├── phylogenomics/                 # 1,286-locus ASTRAL pipeline working directory
│   ├── P1_map_busco_to_tribolium.slurm  # P.1 script (DONE — job 18112279)
│   ├── P3_blast_1286_loci.slurm         # P.3 script (RUNNING — job 18114486)
│   ├── blast_one.sh                     # Wrapper for xargs parallel BLAST
│   ├── busco_tribolium_map.tsv          # 1,286 genes → Tcas chromosomes mapping
│   ├── selected_loci.txt                # 1,286 variant IDs
│   ├── selected_proteins.fasta          # 1,286 protein sequences for BLAST
│   ├── blast_dbs/                       # Per-genome BLAST databases (building via P3)
│   │   └── {ACCESSION}.{ndb,nhr,nin,nsq,...}  # ~439 genomes
│   └── per_gene_fasta/                  # Per-gene multi-FASTA (building via P3)
│       └── {BUSCO_ID}.fasta             # One file per gene with hits from all genomes
├── prepared/                      # Cactus-prepared genome data
├── results/                       # Future: Cactus results
├── scripts/
│   ├── logs/
│   └── phase3/
├── tmp/
└── work/
    └── test_alignment/            # Cactus test run (job 18117479 RUNNING)
        ├── test_seqfile.txt       # 5 smallest genomes + pruned ladder tree
        ├── jobstore/              # Toil jobstore (created fresh — prev was corrupted)
        └── test_alignment.hal     # Output HAL (pending)
```

## Key Files Quick Reference

| What | Path |
|------|------|
| Rooted guide tree (for Cactus) | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439_rooted.nwk` |
| Unrooted FastTree | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk` |
| Cactus seqfile | `$SCRATCH/scarab/cactus_seqfile.txt` |
| Tip mapping | `$SCRATCH/scarab/data/tree_tip_mapping.csv` |
| All BUSCO proteins (13,663 variants) | `$SCRATCH/scarab/nuclear_markers/insecta_odb10/ancestral_variants` |
| 15 guide tree query proteins | `$SCRATCH/scarab/nuclear_markers/marker_proteins.fasta` |
| 15-gene BLAST results | `$SCRATCH/scarab/nuclear_markers/tree_build_18109816/blast_hits/` |
| 15-gene alignments | `$SCRATCH/scarab/nuclear_markers/tree_build_18109816/alignments/` |
| Phylogenomics workdir | `$SCRATCH/scarab/phylogenomics/` |
| BUSCO→Tribolium mapping (1,286 genes) | `$SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv` |
| Selected protein sequences (1,286) | `$SCRATCH/scarab/phylogenomics/selected_proteins.fasta` |
| Cactus test alignment script | `$SCRATCH/scarab/scripts/phase3/test_alignment.slurm` |
| Cactus full alignment script | `$SCRATCH/scarab/scripts/phase3/run_full_alignment.slurm` |

## Genome Path Pattern

Each genome FASTA follows this pattern:
```
$SCRATCH/scarab/genomes/{ACCESSION}/ncbi_dataset/data/{ACCESSION}/*.fna
```
Example:
```
$SCRATCH/scarab/genomes/GCA_964197645.1/ncbi_dataset/data/GCA_964197645.1/GCA_964197645.1_icAbaPara2.1_genomic.fna
```

The seqfile maps tip labels to these paths (439 lines after the tree line).

## BUSCO Database Notes

- `insecta_odb10/ancestral_variants` is a **single multi-FASTA file** (not a directory)
- Contains 13,663 protein sequences (multiple variants per BUSCO gene)
- `insecta_odb10/ancestral` is also a **single file** (one representative per gene)
- Individual genes are NOT in separate .faa files — they're all in these concatenated files
- BUSCO gene IDs look like: `66690at50557_0`, `755at50557`, `1621at50557`
- The `_0`, `_1`, `_2` suffixes are ancestral variants of the same gene

## Module Load Commands

```bash
# For R (re-rooting, analysis)
module purge && module load GCC/13.3.0 R/4.4.2

# For BLAST (tBLASTn) — NOTE: requires OpenMPI too
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

# For MAFFT
module load GCC/12.2.0 MAFFT/7.520-with-extensions

# ape package location: ~/  (installed with lib=Sys.getenv("HOME"))
```

## Disk Quotas

- **$SCRATCH:** 1 TB (used ~296 GB as of 2026-03-22, ~700 GB free)
- **Need:** 5 TB for full Cactus run → email help@hprc.tamu.edu to request increase
