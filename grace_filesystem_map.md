# Grace Filesystem Map — SCARAB Project

**Last updated**: 2026-03-27
**Base path**: `$SCRATCH/scarab` → `/scratch/user/blackmon/scarab`
**NetID**: blackmon

---

## Active Jobs
| Job ID | Name | Status | Notes |
|--------|------|--------|-------|
| 18175381 | scarab_P45_trees | RUNNING | MAFFT + IQ-TREE per-gene trees (1,286 loci), long partition, 48h wall |

---

## Directory Structure

```
$SCRATCH/scarab/
│
├── [ACTIVE SCRIPTS — run from here]
├── extract_nuclear_markers_and_build_tree.slurm  # DONE (job 18109716)
├── download_recovery_genomes.{py,sh,slurm}       # DONE (39/39 downloaded)
├── recovery_accessions.txt            # 39 recovery accession IDs
├── filter_genomes_for_alignment.R     # DONE: 478 → 466 taxa (12 excluded)
├── run_full_alignment.slurm           # BLOCKED: needs quota increase + quality gate approval
├── cactus_watchdog.sh                 # READY: run in tmux after submitting full alignment
├── test_alignment.slurm               # DONE (job 18117479, PASSED)
├── P3_blast_selected_loci.slurm       # DONE (job 18159931)
├── P4_P5_align_and_gene_trees.slurm   # RUNNING (job 18175381)
├── P6_astral_species_tree.slurm       # PENDING
├── P7_concat_iqtree.slurm             # PENDING
│
├── [SEQFILES]
├── cactus_seqfile.txt                 # Tree + 439 genome paths (original, reference only)
├── cactus_seqfile_478.txt             # IQ-TREE tree + 478 genome paths (pre-filter)
├── cactus_seqfile_filtered.txt        # IQ-TREE tree + 466 filtered genomes (PENDING QG approval)
├── guide_tree_filtered.nwk            # 466-tip pruned IQ-TREE tree (for run_full_alignment.slurm)
├── genome_filter_report.csv           # Per-genome filter report (12 excluded)
│
├── [CONTAINER]
├── cactus_v2.9.3.sif                  # Singularity container (~374 MB)
│
├── data/
│   ├── tree_tip_mapping.csv           # Accession → species → tip label (439 rows)
│   └── constraint_tree_calibrated.nwk # 439-tip tree with divergence times (Ma)
│
├── genomes/                           # 478 genome FASTA files (mixed formats)
│   ├── {ACC}/ncbi_dataset/data/{ACC}/*.fna  # Original 439 genomes
│   └── {ACC}_*_genomic.fna.gz         # Recovery genomes (flat format)
│
├── nuclear_markers/
│   ├── insecta_odb10/                 # BUSCO insecta database
│   │   ├── ancestral_variants         # FILE (not dir): 13,663 protein seqs (multi-FASTA)
│   │   └── ancestral                  # FILE (not dir): 1 representative per gene
│   ├── marker_genes.tsv               # 15 selected BUSCO genes (longest per gene)
│   ├── marker_proteins.fasta          # 15 query proteins for BLAST
│   ├── nuclear_guide_tree_439.nwk     # Unrooted FastTree (15 genes, 439 tips)
│   ├── nuclear_guide_tree_439_rooted.nwk  # Rooted on Neuropterida (439-taxon Cactus)
│   ├── nuclear_guide_tree_478_rooted.nwk  # 478-taxon grafted starting tree (IQ-TREE input)
│   ├── nuclear_guide_tree_478_iqtree.nwk  # 478-taxon IQ-TREE tree (REPORTED IN METHODS)
│   ├── reroot_tree.R                  # R script used to root 439-tip tree
│   ├── tree_build_18109816/           # 15-gene BLAST/alignment working dir
│   │   ├── blast_hits/                # Per-genome BLAST results (439 genomes)
│   │   ├── alignments/                # Per-gene MAFFT alignments (15 genes)
│   │   └── per_gene/                  # Per-gene extracted sequences
│   └── iqtree_478/                    # IQ-TREE 478-taxon output
│       ├── scarab_478.treefile        # Final IQ-TREE tree (same as nuclear_guide_tree_478_iqtree.nwk)
│       ├── scarab_478.iqtree          # Run report
│       ├── scarab_478.log             # IQ-TREE log
│       ├── scarab_478.ckp.gz          # Checkpoint
│       ├── scarab_478.contree         # Consensus tree
│       ├── scarab_478.splits.nex      # Splits
│       └── supermatrix_478.fasta      # Concatenated supermatrix (21MB)
│
├── phylogenomics/                     # 1,286-gene ASTRAL pipeline
│   ├── P1_map_busco_to_tribolium.{sh,slurm}  # DONE (job 18112279)
│   ├── P3_blast_1286_loci.slurm       # DONE (job 18159931)
│   ├── busco_tribolium_map.tsv        # 1,286 gene IDs → Tribolium chromosomes
│   ├── selected_loci.txt              # 1,286 BUSCO variant IDs
│   ├── selected_proteins.fasta        # 1,286 query protein sequences
│   ├── blast_dbs/                     # Per-genome BLAST databases (478 genomes, ~79 GB)
│   ├── per_gene_seqs/                 # 1,286 per-gene FASTAs (COMPLETE — P3 done)
│   ├── alignments/                    # Per-gene MAFFT alignments (GROWING — job 18175381)
│   ├── gene_trees/                    # Per-gene IQ-TREE trees (GROWING — job 18175381)
│   └── tcas_blastdb.*                 # Tribolium BLAST database files
│
├── hal_files/                         # Future: Cactus HAL output (~500 GB)
│
├── work/
│   └── test_alignment/
│       ├── test_seqfile.txt           # 5-genome test input
│       └── test_alignment.hal         # PASSED quality gate (241 MB)
│
├── logs/
│   └── archived/                      # Completed job logs
│       └── phylogenomics/             # P3 logs (18114486, 18122417, 18159931)
│
└── deprecated/
    ├── integrate_recovery_genomes.R   # Replaced by build_478_starting_tree.slurm
    └── fix_38_reblast_and_rebuild.slurm  # One-time repair, complete
```

---

## Key Files Quick Reference

| What | Path |
|------|------|
| Genome FASTA pattern (original) | `$SCRATCH/scarab/genomes/{ACC}/ncbi_dataset/data/{ACC}/*.fna` |
| Genome FASTA pattern (recovery) | `$SCRATCH/scarab/genomes/{ACC}_*_genomic.fna.gz` |
| Rooted guide tree (439, reference) | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439_rooted.nwk` |
| IQ-TREE guide tree (478, methods) | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_478_iqtree.nwk` |
| Cactus seqfile (478, pre-filter) | `$SCRATCH/scarab/cactus_seqfile_478.txt` |
| Cactus seqfile (466, filtered) | `$SCRATCH/scarab/cactus_seqfile_filtered.txt` |
| Filtered guide tree (466 tips) | `$SCRATCH/scarab/guide_tree_filtered.nwk` |
| Filter report | `$SCRATCH/scarab/genome_filter_report.csv` |
| Tip mapping | `$SCRATCH/scarab/data/tree_tip_mapping.csv` |
| BUSCO protein variants | `$SCRATCH/scarab/nuclear_markers/insecta_odb10/ancestral_variants` (single file) |
| 15-gene marker proteins | `$SCRATCH/scarab/nuclear_markers/marker_proteins.fasta` |
| BUSCO→Tribolium map | `$SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv` |
| 1,286 selected proteins | `$SCRATCH/scarab/phylogenomics/selected_proteins.fasta` |
| Per-gene FASTAs (complete) | `$SCRATCH/scarab/phylogenomics/per_gene_seqs/` (1,286 .fasta files) |
| P4/P5 active log | `$SCRATCH/scarab/scarab_P45_trees_18175381.log` |
| Cactus container | `$SCRATCH/scarab/cactus_v2.9.3.sif` |
| Test HAL (passed) | `$SCRATCH/scarab/work/test_alignment/test_alignment.hal` |

---

## Module Load Commands

```bash
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0              # tBLASTn
module load GCC/12.3.0 MAFFT/7.520-with-extensions               # MAFFT only
module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6              # IQ-TREE only
module load GCC/12.3.0 OpenMPI/4.1.5 MAFFT/7.520-with-extensions IQ-TREE/2.3.6  # P4/P5
module purge && module load GCC/13.3.0 R/4.4.2                   # R (needs purge first)
module load GCC/12.2.0 FastTree/2.1.11                           # FastTree
```

**Note**: R packages not in system library: install to `$HOME/R/library` and load with `R_LIBS_USER=$HOME/R/library`.

## Disk Usage

| Location | Size | Notes |
|----------|------|-------|
| `genomes/` | ~296 GB | 478 FASTA assemblies |
| `cactus_v2.9.3.sif` | ~374 MB | Container |
| `phylogenomics/blast_dbs/` | ~79 GB | BLAST databases (478 genomes) |
| `nuclear_markers/insecta_odb10/` | ~2 GB | BUSCO database |
| **Total used** | **~377 GB** | Of 1 TB quota (7 TB requested, pending) |
| **Needed for full alignment** | ~500 GB additional | HAL files + working dirs |
