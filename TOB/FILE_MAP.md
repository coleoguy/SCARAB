# TOB — File Map

Stub. Populate as the project takes shape.

## Local repo (this directory)

```
TOB/
├── context.md            # project status, strategy, data inventory — read this first
├── FILE_MAP.md           # this file
├── data/                 # taxonomy, sample manifests, accession lists, BUSCO maps
├── literature/           # PDFs of key papers
│   └── notes/            # written summaries / synthesis of read papers
├── scripts/              # local analysis scripts (R, Python) — Mac side
└── results/              # downloaded outputs from Grace, plots, summary tables
```

## Grace (TBD)

To be created at `$SCRATCH/tob/` when first Grace job is staged. Mirror structure expected:

```
$SCRATCH/tob/
├── genomes/              # symlinks to SCARAB genomes + new TOB-only ones
├── transcriptomes/       # downloaded TSAs, DIY-assembled Sphaerius
├── orthologs/            # BUSCO output per taxon
├── alignments/           # per-locus and concatenated
├── trees/                # backbone, family, synthesis, dated
├── scripts/              # SLURM submission scripts
└── logs/                 # SLURM output + run logs
```

## Cross-reference to SCARAB

Tier-1 genome inputs come from SCARAB. See repo root:
- `data/genomes/genome_catalog_primary.csv` — 478-genome master catalog
- `data/genomes/tree_tip_mapping.csv` — current tip → species → assembly mapping
- `nuclear_markers/` (on Grace) — BUSCO ancestral variants and protein FASTAs already extracted

SCARAB itself is paused at git tag `scarab-pause-2026-05-03`.
