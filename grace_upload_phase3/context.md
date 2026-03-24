# grace_upload_phase3/ -- Context

This folder contains all active Phase 3 scripts for Grace HPC. These are the canonical versions; Grace runs copies from $SCRATCH/scarab/ or directly from ~/SCARAB/grace_upload_phase3/.

## Deployment Workflow
Edit here (Mac/Cowork) -> git push from Mac -> git pull on Grace (~/SCARAB) -> cp to $SCRATCH/scarab/ as needed.

## Script Status (2026-03-24)

### Downloads
| Script | Status | Notes |
|--------|--------|-------|
| download_recovery_genomes.py | DONE | All 39/39 downloaded to $SCRATCH/scarab/genomes/ (2026-03-24 00:33) |
| download_recovery_genomes.slurm | READY | SLURM wrapper for above; idempotent, transfer partition |

### Guide Tree (478 taxa)
| Script | Status | Notes |
|--------|--------|-------|
| build_478_starting_tree.slurm | READY TO SUBMIT | BLASTs 15 marker proteins against 39 recovery genomes; finds nearest neighbor by shared gene count; grafts onto 439-taxon tree. ~30 min. |
| iqtree_478.slurm | PENDING | Depends on build_478_starting_tree.slurm. IQ-TREE LG+G4 on full 478-taxon supermatrix, starting tree = grafted tree. 48h wall. |
| integrate_recovery_genomes.R | DEPRECATED | Replaced by data-driven build_478_starting_tree.slurm approach |
| extract_nuclear_markers_and_build_tree.slurm | DONE | Built 439-taxon guide tree (FastTree, 15 BUSCO proteins). |
| fix_38_reblast_and_rebuild.slurm | DONE | Fixed silent OOM kills for 38 genomes in original BLAST. |

### Phylogenomics (1,286 loci)
| Script | Status | Notes |
|--------|--------|-------|
| P1_map_busco_to_tribolium.slurm | DONE | 1,286 genes mapped to 10 Tribolium chromosomes (job 18112279) |
| P3_blast_1286_loci.slurm | RUNNING | Job 18114486, 439 original taxa, ~31h remaining |
| P3_blast_recovery_taxa.slurm | RUNNING | Job 18122417, 39 recovery taxa, ~2h estimated |
| P4_P5_align_and_gene_trees.slurm | PENDING | MAFFT + IQ-TREE gene trees. Depends on P3. |
| P6_astral_species_tree.slurm | PENDING | ASTRAL-III + gCF/sCF. Depends on P5. |
| P7_concat_iqtree.slurm | PENDING | Partitioned concatenation ML tree. Depends on P4. |

### Alignment (Cactus)
| Script | Status | Notes |
|--------|--------|-------|
| filter_genomes_for_alignment.R | READY | Run on Grace after 478-taxon seqfile is ready. |
| run_full_alignment.slurm | READY | Bigmem node, xlong queue, 18-day wall with --restart. BLOCKED on: quota increase + IQ-TREE guide tree. |
| cactus_watchdog.sh | READY | Run in tmux on login node; auto-resubmits Cactus after each 18-day cycle. |
| test_alignment.slurm | DONE | Job 18117479 completed. 5 smallest genomes, 84 min, quality gate passed. |

### Seqfiles
| File | Status | Notes |
|------|--------|-------|
| cactus_seqfile.txt | DONE | 439 taxa, on Grace at $SCRATCH/scarab/ |
| cactus_seqfile_478.txt | PENDING | After IQ-TREE 478-taxon tree complete |
| cactus_seqfile_filtered.txt | PENDING | After filter_genomes_for_alignment.R runs on 478-taxon seqfile |

## Key Paths on Grace
- Genomes: $SCRATCH/scarab/genomes/
- Nuclear marker tree: $SCRATCH/scarab/nuclear_markers/
- Phylogenomics: $SCRATCH/scarab/phylogenomics/
- Scripts repo: ~/SCARAB/grace_upload_phase3/
- Scratch quota: 1 TB current; 7 TB requested (account 02-133547-00003, email sent 2026-03-24)

## Python Version Note
Grace runs Python 3.6. Use stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True instead of capture_output=True, text=True.

**Last Updated**: 2026-03-24
