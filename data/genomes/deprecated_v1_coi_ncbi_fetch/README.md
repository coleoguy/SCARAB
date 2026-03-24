# Deprecated: v1 COI Guide Tree (NCBI GenBank fetch)

**Superseded**: 2026-03-21

These files are from an early attempt at building a guide tree using COI sequences fetched from NCBI GenBank (found 235/439). The remaining 204 taxa were grafted with arbitrary branch lengths.

**Why deprecated**: COI is mitochondrial and absent from many nuclear-only assemblies. Both COI approaches (GenBank fetch and BLAST extraction) produced unacceptably low hit rates.

**Replaced by**: Nuclear BUSCO marker approach (`extract_nuclear_markers_and_build_tree.slurm`) using 15 conserved insecta proteins via tBLASTn.

## Files
- `coi_sequences.fasta` — 235 COI sequences from NCBI GenBank
- `coi_aligned.fasta` — MAFFT alignment of the 235 sequences
- `coi_ml_tree.nwk` — FastTree ML tree (235 tips, unrooted)
- `coi_ml_rooted.nwk` — Rooted on Conwentzia_psociformis
- `coi_guide_tree_439.nwk` — Final tree with 204 grafted taxa (the problematic one)
