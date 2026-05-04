# TOB — File Map

Stub. Populate as the project takes shape.

## Local repo (this directory)

```
TOB/
├── context.md                            # project status, strategy, data inventory — read first
├── workflow_v1.md                        # locked-in methodology + 5-phase pipeline
├── TOB_methods.Rmd                       # chronological methods notebook — every step,
│                                         # every command, every decision; knit to HTML/PDF
├── FILE_MAP.md                           # this file
├── data/
│   ├── ncbi_inventory_refresh_2026-05.csv     # 1,105 NCBI assemblies + tob_recommendation
│   └── ncbi_inventory_refresh_notes.md        # inventory summary
├── literature/
│   └── notes/                            # 8 written sub-agent reviews
│       ├── 01_recent_coleoptera_phylogenomics.md
│       ├── 02_genbank_mining_tools.md
│       ├── 03_coleoptera_fossil_calibrations.md
│       ├── 04_large_scale_dating_methods.md
│       ├── 05_coleoptera_taxonomy.md
│       ├── 06_backbone_grafting_methods.md
│       ├── 07_outgroup_strepsiptera.md
│       └── 08_megaphylogeny_lessons.md
├── scripts/
│   ├── ncbi_inventory_refresh.py         # the agent's reproducible inventory query
│   └── phase0/                           # Grace deployment scripts for Phase 0
│       ├── 00_README.md                  # runbook (read first before deploying)
│       ├── 01_setup_tob_scratch.sh       # login-node — create $SCRATCH/tob/, install datasets CLI
│       ├── 02_pull_new_genomes.sh        # login-node — 546 new NCBI genomes
│       ├── 03_pull_transcriptomes.sh     # login-node — 4 ancient-suborder TSAs
│       ├── 04_pull_hymenoptera_anchors.sh # login-node — 3 Hymenoptera reference genomes
│       ├── 05_pull_sphaerius_reads.sh    # login-node — 2 raw WGS SRA accessions
│       ├── 06_assemble_sphaerius.slurm   # bigmem compute — SPAdes DIY assemblies
│       └── 07_link_scarab_genomes.sh     # any-node — symlink 478 SCARAB genomes into TOB tree
└── results/                              # downloaded outputs from Grace, plots, summary tables
```

## Grace working directory

Created by `scripts/phase0/01_setup_tob_scratch.sh` at `$SCRATCH/tob/`:

```
$SCRATCH/tob/
├── genomes/
│   ├── ncbi_dataset/data/{ACC}/*.fna     # 546 new pulls (NCBI Datasets layout)
│   ├── scarab_existing/{ACC}/            # symlinks to $SCRATCH/scarab/genomes/{ACC}/
│   └── new_accessions.txt                # working accession list
├── transcriptomes/
│   └── *.fasta.gz                        # 4 TSA WGS pulls
├── outgroups/
│   └── hymenoptera/ncbi_dataset/data/{ACC}/   # 3 anchor genomes
├── sphaerius/
│   ├── reads/SRR*.fastq.gz               # raw paired-end reads
│   └── assemblies/{species}/contigs.fasta # SPAdes DIY drafts
├── orthologs/                            # (Phase 1) BUSCO output per taxon
├── alignments/                           # (Phase 1) per-locus and concatenated
├── trees/                                # (Phase 1+) backbone, family, synthesis, dated
├── scripts/                              # SLURM scripts staged on Grace
└── logs/                                 # timestamped per-script logs
```

## Cross-reference to SCARAB

Tier-1 genome inputs come from SCARAB. See repo root:
- `data/genomes/genome_catalog_primary.csv` — 478-genome master catalog
- `data/genomes/tree_tip_mapping.csv` — current tip → species → assembly mapping
- `nuclear_markers/` (on Grace) — BUSCO ancestral variants and protein FASTAs already extracted

SCARAB itself is paused at git tag `scarab-pause-2026-05-03`.
