# Deprecated Phase 3 Scripts

## extract_coi_and_build_tree.slurm

**Superseded by**: `prepare_nuclear_markers.sh` + `extract_nuclear_markers_and_build_tree.slurm`

**Why deprecated**: COI is mitochondrial. Many genome assemblies are nuclear-only or exclude organellar contigs. BLAST found COI in only **182 of 439 genomes (41%)**, meaning 257 taxa (58%) had to be grafted by taxonomy alone. A guide tree where >50% of taxa lack molecular data is unacceptable.

**Replacement approach**: Multi-locus nuclear guide tree using 15 BUSCO insecta conserved single-copy proteins (tBLASTn). Expected hit rate: >90% per gene. With 15 genes, virtually every taxon will have data for multiple loci.

**Grace outputs from COI run (Job 18109716)**: Files in `$SCRATCH/scarab/coi_tree/` are superseded and should not be used for Cactus alignment.

**Date deprecated**: 2026-03-22
