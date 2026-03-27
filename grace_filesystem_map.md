# Grace Filesystem Map — SCARAB Project

**Last updated**: 2026-03-25
**Base path**: `$SCRATCH/scarab` → `/scratch/user/blackmon/scarab`
**NetID**: blackmon

---

## Active Jobs
| Job ID | Name | Status | Notes |
|--------|------|--------|-------|
| 18152861 | scarab_P3 | RUNNING | tBLASTn 1,286 × 478 genomes, ~22h remaining (2026-03-25) |

---

## Directory Structure

```
$SCRATCH/scarab/
│
├── [ACTIVE SCRIPTS — run from here]
├── build_478_starting_tree.slurm      # READY: graft 39 recovery → 439-tree → IQ-TREE starting topology
├── iqtree_478.slurm                   # PENDING: 478-taxon IQ-TREE guide tree (reported in methods)
├── extract_nuclear_markers_and_build_tree.slurm  # DONE (job 18109716)
├── download_recovery_genomes.{py,sh,slurm}       # DONE (39/39 downloaded)
├── recovery_accessions.txt            # 39 recovery accession IDs
├── filter_genomes_for_alignment.R     # DONE: QC filter N50/scaffold count
├── run_full_alignment.slurm           # BLOCKED: needs quota increase + guide tree
├── cactus_watchdog.sh                 # READY: run in tmux after submitting full alignment
├── test_alignment.slurm               # DONE (job 18117479, PASSED)
├── P3_blast_selected_loci.slurm       # RUNNING (job 18152861)
├── P4_P5_align_and_gene_trees.slurm   # PENDING
├── P6_astral_species_tree.slurm       # PENDING
├── P7_concat_iqtree.slurm             # PENDING
│
├── [SEQFILES]
├── cactus_seqfile.txt                 # Tree + 439 genome paths (original)
├── cactus_seqfile_478.txt             # Tree + 478 genome paths (current)
│
├── [CONTAINER]
├── cactus_v2.9.3.sif                  # Singularity container (~12 GB)
│
├── data/
│   ├── tree_tip_mapping.csv           # Accession → species → tip label (439 rows)
│   └── constraint_tree_calibrated.nwk # 439-tip tree with divergence times (Ma)
│
├── genomes/                           # 478 genome FASTA files
│   └── {ACCESSION}/ncbi_dataset/data/{ACCESSION}/*.fna
│
├── nuclear_markers/
│   ├── insecta_odb10/                 # BUSCO insecta database
│   │   ├── ancestral_variants         # FILE (not dir): 13,663 protein seqs (multi-FASTA)
│   │   └── ancestral                  # FILE (not dir): 1 representative per gene
│   ├── marker_genes.tsv               # 15 selected BUSCO genes (longest per gene)
│   ├── marker_proteins.fasta          # 15 query proteins for BLAST
│   ├── nuclear_guide_tree_439.nwk     # Unrooted FastTree (15 genes, 439 tips)
│   ├── nuclear_guide_tree_439_rooted.nwk  # Rooted on Neuropterida (Cactus input)
│   ├── nuclear_guide_tree_478_rooted.nwk  # 478-taxon grafted starting tree (IQ-TREE input)
│   ├── reroot_tree.R                  # R script used to root 439-tip tree
│   ├── tree_build_18109816/           # 15-gene BLAST/alignment working dir
│   │   ├── blast_hits/                # Per-genome BLAST results (439 genomes)
│   │   ├── alignments/                # Per-gene MAFFT alignments (15 genes)
│   │   └── per_gene/                  # Per-gene extracted sequences
│   └── iqtree_478/                    # IQ-TREE 478-taxon output
│       ├── scarab_478.treefile        # Final IQ-TREE tree
│       ├── scarab_478.iqtree          # Run report
│       ├── scarab_478.log             # IQ-TREE log
│       └── supermatrix_478.fasta      # Concatenated supermatrix used for tree
│
├── phylogenomics/                     # 1,286-gene ASTRAL pipeline
│   ├── P3_blast_1286_loci.slurm       # Reference copy of running script
│   ├── busco_tribolium_map.tsv        # 1,286 gene IDs → Tribolium chromosomes
│   ├── selected_loci.txt              # 1,286 BUSCO variant IDs
│   ├── selected_proteins.fasta        # 1,286 query protein sequences
│   ├── blast_dbs/                     # Per-genome BLAST databases (478 genomes)
│   ├── per_gene_seqs/                 # Per-gene FASTAs (GROWING — job 18152861)
│   │                                  # ~2,571+ files, one per locus
│   └── scarab_P3_18152861.{log,err}   # Active job log
│
├── hal_files/                         # Future: Cactus HAL output (~500 GB)
│
├── work/
│   └── test_alignment/
│       ├── test_seqfile.txt           # 5-genome test input
│       └── test_alignment.hal         # PASSED quality gate
│
├── logs/
│   └── archived/                      # Completed job logs
│       └── phylogenomics/             # Archived phylogenomics job logs
│
└── deprecated/
    ├── integrate_recovery_genomes.R   # Replaced by build_478_starting_tree.slurm
    └── fix_38_reblast_and_rebuild.slurm  # One-time repair, complete
```

---

## Key Files Quick Reference

| What | Path |
|------|------|
| Genome FASTA pattern | `$SCRATCH/scarab/genomes/{ACC}/ncbi_dataset/data/{ACC}/*.fna` |
| Rooted guide tree (439, Cactus) | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439_rooted.nwk` |
| Rooted guide tree (478, for IQ-TREE) | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_478_rooted.nwk` |
| Cactus seqfile (478) | `$SCRATCH/scarab/cactus_seqfile_478.txt` |
| Tip mapping | `$SCRATCH/scarab/data/tree_tip_mapping.csv` |
| BUSCO protein variants | `$SCRATCH/scarab/nuclear_markers/insecta_odb10/ancestral_variants` (single file) |
| 15-gene marker proteins | `$SCRATCH/scarab/nuclear_markers/marker_proteins.fasta` |
| BUSCO→Tribolium map | `$SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv` |
| 1,286 selected proteins | `$SCRATCH/scarab/phylogenomics/selected_proteins.fasta` |
| Per-gene FASTAs (growing) | `$SCRATCH/scarab/phylogenomics/per_gene_seqs/` |
| Active P3 log | `$SCRATCH/scarab/phylogenomics/scarab_P3_18152861.log` |
| Cactus container | `$SCRATCH/scarab/cactus_v2.9.3.sif` |
| Test HAL (passed) | `$SCRATCH/scarab/work/test_alignment/test_alignment.hal` |

---

## Module Load Commands

```bash
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0     # tBLASTn
module load GCC/12.2.0 MAFFT/7.520-with-extensions       # MAFFT
module purge && module load GCC/13.3.0 R/4.4.2           # R
module load GCC/12.2.0 OpenMPI/4.1.4 IQ-TREE/2.2.2.7    # IQ-TREE
module load GCC/12.2.0 FastTree/2.1.11                   # FastTree
```

## Disk Usage

| Location | Size | Notes |
|----------|------|-------|
| `genomes/` | ~296 GB | 478 FASTA assemblies |
| `cactus_v2.9.3.sif` | ~12 GB | Container |
| `phylogenomics/blast_dbs/` | ~20 GB | BLAST databases |
| `nuclear_markers/insecta_odb10/` | ~2 GB | BUSCO database |
| **Total used** | **~330 GB** | Of 1 TB quota (7 TB requested) |
| **Needed for full alignment** | ~500 GB additional | HAL files + working dirs |
