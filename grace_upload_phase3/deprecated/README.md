# Deprecated Scripts — grace_upload_phase3

These scripts have been superseded. Keep for reference/reproducibility; do not run.

---

## extract_coi_and_build_tree.slurm
**Deprecated**: 2026-03-22
**Superseded by**: `prepare_nuclear_markers.sh` + `extract_nuclear_markers_and_build_tree.slurm`
**Why**: COI is mitochondrial. BLAST found COI in only 182/439 genomes (41%) — unacceptable hit rate. Replaced with 15-gene nuclear BUSCO approach (>90% hit rate).

---

## integrate_recovery_genomes.R
**Deprecated**: 2026-03-24
**Superseded by**: `build_478_starting_tree.slurm`
**Why**: Used hardcoded taxonomic order assignments to graft 39 recovery genomes onto the 439-taxon tree. Replaced with data-driven approach: BLAST 15 marker proteins against recovery genomes, find nearest neighbor by shared gene count, graft programmatically.

---

## fix_38_reblast_and_rebuild.slurm
**Deprecated**: 2026-03-23 (completed, one-time repair)
**Why**: Production repair script. 38 genomes silently got zero BLAST hits due to OOM kills in job 18109816. This script re-ran BLAST for those 38 genomes and rebuilt the guide tree. Task complete — final guide tree is `nuclear_guide_tree_439_rooted.nwk`.

---

## P2_select_loci.sh
**Deprecated**: 2026-03-23
**Why**: Plan was to select 300-500 BUSCO loci balanced across Stevens elements. Decision changed: use all 1,286 loci that mapped to the 10 Tribolium chromosomes. More data, no downside given compute budget.

---

## P3_blast_recovery_taxa.slurm
**Deprecated**: 2026-03-25
**Why**: Submitted as a dedicated recovery BLAST job (job 18146566), but the main P3 BLAST job (18152861) already included the 39 recovery genomes as its remaining work and writes to the unified `per_gene_seqs/` output. Running both was redundant. Job 18146566 was cancelled. The main P3 job (18152861) is the canonical run.
