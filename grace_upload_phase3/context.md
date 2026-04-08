# grace_upload_phase3/ -- Context

This folder contains all active Phase 3 scripts for Grace HPC. These are the canonical versions; Grace runs copies from $SCRATCH/scarab/ or directly from ~/SCARAB/grace_upload_phase3/.

## Deployment Workflow
Edit here (Mac/Cowork) -> git push from Mac -> git pull on Grace (~/SCARAB) -> cp to $SCRATCH/scarab/ as needed.

## Script Status (2026-03-30)

### Downloads
| Script | Status | Notes |
|--------|--------|-------|
| download_recovery_genomes.py | DONE | All 39/39 downloaded to $SCRATCH/scarab/genomes/ (2026-03-24 00:33) |
| download_recovery_genomes.slurm | DONE | SLURM wrapper for above; idempotent, transfer partition |

### Guide Tree (478 taxa)
| Script | Status | Notes |
|--------|--------|-------|
| build_478_starting_tree.slurm | DONE | Grafted 39 recovery taxa onto 439-taxon tree |
| iqtree_478.slurm | DONE | IQ-TREE LG+G4 on full 478-taxon supermatrix. Output: nuclear_guide_tree_478_iqtree.nwk |
| extract_nuclear_markers_and_build_tree.slurm | DONE | Built 439-taxon guide tree (FastTree, 15 BUSCO proteins) |

### Phylogenomics (1,286 loci)
| Script | Status | Notes |
|--------|--------|-------|
| P1_map_busco_to_tribolium.slurm | DONE | 1,286 genes mapped to 10 Tribolium chromosomes (job 18112279) |
| P3_blast_1286_loci.slurm | DONE | 1,286 per-gene FASTA files for 478 taxa |
| P4_P5_array.slurm | DONE | Original run. 420 completed, 328 failed, 122 timeout, 150 cancelled. |
| P4_P5_array_v2.slurm | DONE | Rerun with 24h wall, restricted --mset for large alignments. |
| P4_P5_array_v3.slurm | DONE | Batch 1: 316 completed, 342 failed (inode collateral), 242 cancelled. |
| P4_P5_array_v3b.slurm | SUPERSEDED | Replaced by v4 which covers all remaining loci. |
| P4_P5_array_v4a.slurm | RUNNING | Loci 1-381 of 472 (job 18207075). Split due to 500-job SLURM limit. |
| P4_P5_array_v4b.slurm | PENDING | Loci 382-472 of 472 (91 tasks). Submit when L1 tasks free slots. |
| P4_P5_rerun23.slurm | DONE | 23 large loci resubmitted with --mset (restricted ModelFinder) |
| P6_astral_species_tree.slurm | PENDING | wASTRAL + gCF/sCF. Depends on all gene trees completing. |
| P7_concat_iqtree.slurm | PENDING | LG+C60+F+R concatenation ML tree. Can run parallel with P6. |
| build_combined_blastdb.slurm | DONE | Single BLAST db for all 478 genomes (job 18199244). |

### Alignment (Cactus)
| Script | Status | Notes |
|--------|--------|-------|
| filter_genomes_for_alignment.R | DONE | 478 → 466 taxa. Output: cactus_seqfile_filtered.txt |
| run_cactus_decomposed.py | DONE | Decomposed into 465 sub-problems across 33 levels |
| Cactus preprocess | DONE | 15 batches, 466 masked genomes, 297 GB, 0 failures (2026-03-28) |
| Cactus L1 | RUNNING | Attempt 4 (2026-03-30). Jobs 18207057 (medium, 117 tasks) + 18207058 (long, tasks 2+22). 26/145 HALs complete. Fixed: EXIT trap `|| true`, HAL-exists skip check. Prior: attempt 3 (job 18202969, 26 done — 12 were false FAILED from trap bug), attempt 2 (job 18199217, 14 done, inodes), attempt 1 (job 18193705, 4 done, OOM+inodes). |
| test_alignment.slurm | DONE | Job 18117479 completed. 5 smallest genomes, 84 min, quality gate passed. |

### Seqfiles
| File | Status | Notes |
|------|--------|-------|
| cactus_seqfile.txt | DONE | 439 taxa, on Grace at $SCRATCH/scarab/ |
| cactus_seqfile_filtered.txt | DONE | 466 taxa, used for decomposed Cactus pipeline |

### Inode Management (2026-03-30)
- Root cause: Cactus Toil jobstores create ~6,500 files per task. Previous cleanup only ran on success — failed tasks leaked jobstores.
- Attempt 2 (job 18199217) hit inode wall again despite %20 throttle: 92K files accumulated from failed tasks.
- Attempt 3 fixes: EXIT trap cleanup, %10 throttle, 96G RAM.
- Attempt 3 bug: EXIT trap `&&` chain returned non-zero when Cactus already deleted its own jobstore (cleanup `[ -d "$JS_PATH" ]` was false → exit 1). 12 tasks falsely reported FAILED but had valid HALs.
- Attempt 4 fix: added `|| true` to cleanup function. Also added HAL-exists skip check so resubmissions don't redo completed work. Tasks 2+22 moved to `long` partition (7-day wall) after timing out at 12h.
- After cleanup: inodes dropped from 194K to 17K. Vast majority of files were jobstores.
- Inode quota increase to 500K requested from HPRC (email draft ready, 2026-03-29).

## Key Paths on Grace
- Genomes: $SCRATCH/scarab/genomes/
- Nuclear marker tree: $SCRATCH/scarab/nuclear_markers/
- Phylogenomics: $SCRATCH/scarab/phylogenomics/
- Combined BLAST db: $SCRATCH/scarab/blastdb/scarab_478
- Scripts repo: ~/SCARAB/grace_upload_phase3/
- Scratch quota: 7 TB (expanded from 1 TB). Current usage: ~960 GB / 7 TB, ~17K / 250K inodes (after jobstore cleanup 2026-03-30)

## Python Version Note
Grace runs Python 3.6. Use stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True instead of capture_output=True, text=True.

**Last Updated**: 2026-03-30
