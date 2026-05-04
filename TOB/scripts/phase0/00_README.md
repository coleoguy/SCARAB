# TOB Phase 0 — Data Acquisition

All scripts run on Grace. Most pull from the internet, so they need to run on the **login node** (compute nodes have no internet per CLAUDE.md). Only the *Sphaerius* SPAdes assembly itself runs on a compute node (bigmem partition).

## Prerequisites

- SSH ControlMaster open to Grace (run `ssh -fN blackmon@grace.hprc.tamu.edu` once locally; approve Duo).
- Repo cloned on Grace at `~/SCARAB` (adjust `REPO_ROOT` env var in scripts if elsewhere).
- `git pull` on Grace to get the latest TOB inventory CSV.

## Order of operations

1. **`01_setup_tob_scratch.sh`** — login node. Creates `$SCRATCH/tob/` directory tree; installs NCBI Datasets CLI to `~/bin/`. Run once. ~2 min.
2. **`02_pull_new_genomes.sh`** — login node. Pulls all 546 new Coleoptera/Strepsiptera/Neuropterida assemblies from NCBI Datasets. Reads accession list from `TOB/data/ncbi_inventory_refresh_2026-05.csv` filtering on `in_scarab_catalog == "no"`. Includes everything (per Heath 2026-05-03 — BUSCO completeness will be the real filter, not assembly metadata). Estimated time: 4–8 hr depending on NCBI throughput. Disk: ~100–200 GB.
3. **`03_pull_transcriptomes.sh`** — login node. Pulls 4 verified Tier-2 TSAs for ancient suborders (*Priacma*, *Micromalthus*, *Hydroscapha*, *Lepicerus*). 5–15 min. <100 MB.
4. **`04_pull_hymenoptera_anchors.sh`** — login node. Pulls 3 Hymenoptera reference genomes (*Apis*, *Nasonia*, *Athalia*) for deep outgroup anchoring. 10–30 min. ~1 GB.
5. **`05_pull_sphaerius_reads.sh`** — login node. Pulls 2 raw WGS read sets (SRR21231095, SRR21231096) via SRA Toolkit prefetch + fasterq-dump. 1–3 hr per accession. ~30 GB compressed FASTQ.
6. **`06_assemble_sphaerius.slurm`** — bigmem compute partition. SLURM array (2 tasks) → SPAdes draft assemblies. Submit with `sbatch 06_assemble_sphaerius.slurm`. 32 cores, 300 GB RAM, 24–48 h wall per task.
7. **`07_link_scarab_genomes.sh`** — any node. Symlinks the 478 existing SCARAB genomes from `$SCRATCH/scarab/genomes/` into `$SCRATCH/tob/genomes/scarab_existing/` so Phase 1 can treat them uniformly with the new pull. ~30 sec.

## On completion

`$SCRATCH/tob/` contains:
- `genomes/ncbi_dataset/data/{ACC}/*.fna` — 546 new assemblies
- `genomes/scarab_existing/{ACC}/` — 478 SCARAB genomes (symlinks)
- `transcriptomes/*.fasta.gz` — 4 TSAs
- `outgroups/hymenoptera/ncbi_dataset/data/{ACC}/*.fna` — 3 anchors
- `sphaerius/reads/SRR*.fastq.gz` — raw reads
- `sphaerius/assemblies/{species}/contigs.fasta` — DIY drafts
- `logs/*.log` — timestamped logs of every script

Total: ~1,030 Coleoptera assemblies + ~10 outgroup genomes + 4 transcriptomes + 2 *Sphaerius* drafts. Ready for Phase 1 BUSCO extraction.

## Grace constraints (carry over from CLAUDE.md)

- Python 3.6 only on Grace — no f-strings, no `capture_output=True`, no walrus operator. Scripts here comply.
- File transfer: sftp only (not scp — Duo timeouts).
- `$SCRATCH` = `/scratch/user/blackmon/` (TOB working dir is `$SCRATCH/tob/`).
- Module load conventions documented in CLAUDE.md.

## Safety

Every script writes to `$SCRATCH/tob/logs/` with a timestamped filename. Re-running a script does NOT clobber prior logs. NCBI Datasets and SRA prefetch are both resumable — re-running after a failure picks up where it left off.

**Do not advance to Phase 1 until Heath has reviewed the Phase 0 outputs** per the SCARAB Quality Gate Policy.
