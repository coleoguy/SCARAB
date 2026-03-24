# data/synteny/

**Status:** Placeholder — will be populated after Phase 3 synteny extraction (Task 2.3).

## Expected Contents

| File | Description | Source |
|------|-------------|--------|
| `pairwise_synteny_blocks.tsv` | Pairwise synteny blocks from halSynteny | Task 2.3 |
| `multiway_synteny_calls.tsv` | Consensus synteny blocks across all species | Task 2.3 |
| `synteny_anchored.tsv` | Synteny blocks with chromosomal assignments | Task 2.6 |

## Generation

Synteny blocks are extracted from the HAL alignment using `halSynteny` (bundled in the Cactus Singularity container). See `phases/phase3_alignment_synteny/PHASE_2.3_hal_synteny_extraction/HOWTO.md`.
