# data/alignments/

**Status:** Placeholder — will be populated after Phase 3 alignment completes.

## Expected Contents

| File | Description | Source |
|------|-------------|--------|
| `scarab.hal` | Primary HAL-format whole-genome alignment (439 genomes) | Task 2.2 — Cactus output on Grace |
| `scarab_subset_*.hal` | Any subset alignments for testing | Task 2.1 — test alignment |

## Notes

The HAL file is generated on Grace HPC at `$SCRATCH/scarab/hal_files/scarab.hal` and is expected to be 50–100 GB. It may remain on Grace for downstream analysis rather than being transferred locally due to its size.

Transfer via `sftp` (not `scp`) if needed.
