# HOWTO 3.1: Pipeline Setup & Validation on Grace

**Task Goal:** Set up the ProgressiveCactus alignment pipeline on TAMU Grace HPC, build a multi-locus nuclear guide tree from BUSCO insecta marker genes, and validate with a 5-genome test alignment before committing 200,000 SUs.

**Timeline:** Days 7–8
**Responsible Person:** Heath (runs commands on Grace); Claude (writes/maintains scripts)

---

## Prerequisites

Before starting, confirm:
- [ ] Phase 2 complete: 439 genomes downloaded via `datasets` to `$SCRATCH/scarab/genomes/` (each in NCBI Datasets directory structure: `GCA_XXX/ncbi_dataset/data/GCA_XXX/*.fna`)
- [ ] `tree_tip_mapping.csv` uploaded to `$SCRATCH/scarab/data/` (maps 439 tip labels → accessions → FASTA paths)
- [ ] `constraint_tree_calibrated.nwk` uploaded to `$SCRATCH/scarab/data/` (439-tip binary Newick tree, branch lengths in Ma)
- [ ] SU allocation: 200,000 SUs approved for the full alignment

---

## Inputs

| File | Location on Grace | Description |
|------|-------------------|-------------|
| `tree_tip_mapping.csv` | `$SCRATCH/scarab/data/` | Columns: `tip_label,species_name,accession,family,clade,role` |
| `constraint_tree_calibrated.nwk` | `$SCRATCH/scarab/data/` | 439-tip binary tree; used as fallback if nuclear guide tree not yet built |
| 439 genome FASTAs | `$SCRATCH/scarab/genomes/GCA_*/ncbi_dataset/data/GCA_*/*.fna` | Downloaded via NCBI Datasets in Phase 2 |

---

## Outputs

1. **Singularity container:** `$SCRATCH/scarab/cactus_v2.9.3.sif`
2. **Cactus seqFile:** `$SCRATCH/scarab/cactus_seqfile.txt` (tree + 439 genome paths)
3. **Nuclear guide tree:** `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk`
4. **Test HAL file:** `$SCRATCH/scarab/work/test_alignment/test_alignment.hal`
5. **Prepared decomposition:** `$SCRATCH/scarab/prepared/steps.sh` (cactus-prepare output)

---

## Acceptance Criteria

- [ ] Cactus Singularity container (v2.9.3) pulled and verified on Grace
- [ ] seqFile contains 439 genome entries, all FASTA paths valid
- [ ] Nuclear guide tree has 439 tips, is binary, all branch lengths > 0 and ≤ 25.0 subs/site
- [ ] ≥90% of taxa (≥395/439) have molecular data (not taxonomy-grafted) — **QUALITY GATE**
- [ ] Test alignment of 5 small genomes produces a valid HAL file
- [ ] `halStats` on test HAL shows all 5 genomes aligned
- [ ] No errors in SLURM logs

---

## Canonical Scripts

All scripts live in `grace_upload_phase3/` in the project root. This is the **single source of truth** — older copies in `scripts/phase3/` are deprecated.

| Script | Purpose | Run on |
|--------|---------|--------|
| `setup_phase3.sh` | Creates directories, pulls Cactus container, builds seqFile, runs `cactus-prepare` | Login node (bash) |
| `build_seqfile.sh` | Maps tree tip labels to FASTA paths; auto-selects nuclear tree or calibrated fallback | Called by setup_phase3.sh |
| `prepare_nuclear_markers.sh` | Downloads BUSCO insecta_odb10 data, selects 15 conserved marker proteins | Login node (bash) |
| `extract_nuclear_markers_and_build_tree.slurm` | tBLASTn 15 BUSCO proteins × 439 genomes → supermatrix → FastTree → validate (quality gate: ≥90% molecular data) | SLURM (medium queue) |
| `test_alignment.slurm` | Selects 5 smallest genomes, runs Cactus, validates HAL output | SLURM (medium queue) |
| `run_full_alignment.slurm` | Full 439-genome Cactus alignment with resume support | SLURM (xlong queue) |
| `deprecated/extract_coi_and_build_tree.slurm` | ~~COI approach~~ — DEPRECATED (41% hit rate). Do not use. | — |

---

## Step-by-Step Instructions

### Step 1: Upload Scripts to Grace

Grace uses Duo 2FA, so `scp` does not work for direct file transfer. Use `sftp` instead:

```bash
# From your local machine — interactive sftp session
sftp grace

# Once connected:
cd /scratch/user/blackmon/scarab
mkdir scripts
put -r grace_upload_phase3/* scripts/

# Or upload individual scripts:
put grace_upload_phase3/setup_phase3.sh scripts/
put grace_upload_phase3/build_seqfile.sh scripts/
put grace_upload_phase3/prepare_nuclear_markers.sh scripts/
put grace_upload_phase3/extract_nuclear_markers_and_build_tree.slurm scripts/
put grace_upload_phase3/test_alignment.slurm scripts/
put grace_upload_phase3/run_full_alignment.slurm scripts/
exit
```

**Alternatively**, if scripts are on GitHub, clone directly on the Grace login node (login nodes have internet; compute nodes do not).

---

### Step 2: Run Phase 3 Setup

SSH into Grace and run the setup script:

```bash
ssh grace
cd $SCRATCH/scarab

# Make scripts executable
chmod +x scripts/*.sh scripts/*.slurm

# Run setup (pulls container, builds seqFile, runs cactus-prepare)
# NOTE: Container pull takes ~15-30 min. Use nohup if needed.
bash scripts/setup_phase3.sh
```

**What this does (4 steps):**

1. **Creates directory structure:** `data/`, `work/`, `hal_files/`, `prepared/`, `logs/`, `results/`, `tmp/`
2. **Pulls Cactus Singularity container:** Downloads `quay.io/comparative-genomics-toolkit/cactus:v2.9.3` (~2 GB). Skips if `cactus_v2.9.3.sif` already exists.
3. **Builds seqFile:** Runs `build_seqfile.sh`, which:
   - Reads `tree_tip_mapping.csv` to map each of 439 tip labels to its FASTA path
   - Selects guide tree: prefers nuclear BUSCO tree (`nuclear_markers/nuclear_guide_tree_439.nwk`), falls back to calibrated tree
   - Writes `cactus_seqfile.txt` (line 1 = Newick tree; lines 2+ = `tip_label /path/to/genome.fna`)
4. **Runs `cactus-prepare`:** Decomposes the alignment into steps → `prepared/steps.sh`

**Expected output:**
```
============================================================
SCARAB — Phase 3 Setup
============================================================

[1/4] Creating directory structure...
  Done: /scratch/user/blackmon/scarab/

[2/4] Pulling Cactus Singularity container...
  Image: quay.io/comparative-genomics-toolkit/cactus:v2.9.3
  ...
  Pull complete.
  cactus: 2.9.3
  halStats: halStats ...

[3/4] Building Cactus seqFile...
  WARNING: Nuclear tree not found, falling back to calibrated tree
  seqFile: .../cactus_seqfile.txt
  Entries: 439 genomes mapped to tree tips

[4/4] Running cactus-prepare (decomposition)...
  cactus-prepare generated N steps
  ...

Setup Complete
```

**Verify:**
```bash
# Check seqFile has 439 entries
tail -n +2 $SCRATCH/scarab/cactus_seqfile.txt | wc -l
# Expected: 439

# Check container works
singularity exec --cleanenv \
  -B $SCRATCH/scarab:$SCRATCH/scarab \
  $SCRATCH/scarab/cactus_v2.9.3.sif \
  cactus --version
# Expected: 2.9.3
```

---

### Step 3: Build Nuclear Guide Tree (Required)

The calibrated constraint tree has branch lengths in Ma — crude conversion to subs/site is unreliable. We build an empirical guide tree from 15 conserved BUSCO insecta proteins extracted from all 439 genomes via tBLASTn.

> **Note:** A previous COI-based approach only achieved 41% hit rate because COI is mitochondrial and many assemblies are nuclear-only. That approach is deprecated. See `grace_upload_phase3/deprecated/`.

**Step 3a: Prepare marker proteins (login node):**
```bash
cd $SCRATCH/scarab
bash scripts/prepare_nuclear_markers.sh
```

This downloads BUSCO insecta_odb10 (~130 MB), selects the 15 longest conserved single-copy protein sequences, and writes `nuclear_markers/marker_proteins.fasta`. Takes ~2 minutes. Requires internet (login node only).

**Step 3b: Submit the tree-building job:**
```bash
sbatch scripts/extract_nuclear_markers_and_build_tree.slurm
```

**SLURM parameters:**
- Partition: `medium` (6-hour limit)
- Resources: 1 node, 48 cores, 64 GB RAM
- Expected runtime: 2–3 hours

**What this does (8 steps):**

1. Verifies marker proteins and genome inputs
2. tBLASTn: queries 15 BUSCO proteins against each of 439 genomes (48 parallel)
3. Parses BLAST hits into per-gene protein FASTAs (filters: ≥100 aa, ≥30% identity)
4. **Quality gate**: aborts if <395/439 taxa (90%) have molecular data for ≥1 gene
5. MAFFT-aligns each gene separately
6. Concatenates into protein supermatrix (missing genes → gaps)
7. Builds ML tree with FastTree (WAG+CAT protein model)
8. Roots on Neuropterida, grafts only taxa with zero hits across all 15 genes, validates, rebuilds seqFile

**Module dependencies on Grace:**
```
# BLAST phase:
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

# MAFFT + FastTree phase (swapped after BLAST completes):
module load GCC/12.3.0 MAFFT/7.520-with-extensions FastTree/2.1.11
```

**Monitor:**
```bash
squeue -u $USER
tail -f scarab_nuc_tree_*.log
```

**After completion, verify:**
```bash
# Check the quality gate passed (script exits 1 if it fails)
sacct -j JOBID --format=State,ExitCode

# Check tree exists and has 439 tips
grep -oP '[A-Za-z_][A-Za-z0-9_]*(?=:)' $SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk | wc -l
# Expected: 439

# Check how many taxa have molecular data vs. grafted
cat $SCRATCH/scarab/nuclear_markers/tree_build_*/blast_summary.tsv
# taxa_with_data should be ≥395
```

---

### Step 4: Test Alignment (5 Genomes)

Validate the pipeline before committing 200,000 SUs:

```bash
sbatch scripts/test_alignment.slurm
```

**SLURM parameters:**
- Partition: `medium` (1-day limit; short is only 2 hrs, too tight)
- Resources: 1 node, 48 cores, 360 GB RAM
- Expected runtime: 30–90 min

**What this does:**

1. Selects 5 smallest genomes from the seqFile (by filesize)
2. Prunes the guide tree to just those 5 tips (builds binary ladder tree)
3. Creates a mini seqFile (`work/test_alignment/test_seqfile.txt`)
4. Runs `cactus` via Singularity on the mini seqFile
5. Validates the HAL output with `halStats`

**Monitor:**
```bash
squeue -u $USER
tail -f scarab_test_*.log
```

**After completion, verify:**
```bash
# Check HAL exists
ls -lh $SCRATCH/scarab/work/test_alignment/test_alignment.hal

# Run halStats
singularity exec --cleanenv \
  -B $SCRATCH/scarab:$SCRATCH/scarab \
  $SCRATCH/scarab/cactus_v2.9.3.sif \
  halStats $SCRATCH/scarab/work/test_alignment/test_alignment.hal
```

**Expected:** HAL file ≥ 10 MB, halStats shows all 5 genomes aligned, log ends with "TEST PASSED".

---

### Step 5: Review and Proceed

If the test passes:

```bash
# Submit the full 439-genome alignment
sbatch scripts/run_full_alignment.slurm
```

This is covered in detail in **HOWTO 3.2 (Full Alignment)**.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `sftp` hangs or fails | Grace Duo 2FA timeout | Authenticate quickly after password prompt; use MobaXterm or FileZilla for GUI-based SFTP |
| `singularity pull` fails | No internet on compute nodes | Container must be pulled on **login node** (has internet). Use `nohup` for long pulls. |
| `module load BLAST+/2.14.0` fails | Missing prerequisites | Load `GCC/12.2.0` and `OpenMPI/4.1.4` first. Check `module avail BLAST` for exact version. |
| seqFile has < 439 entries | Missing `.fna` files in genome directories | Check `find $SCRATCH/scarab/genomes/ -name "*.fna" \| wc -l`. Re-download missing accessions. |
| Quality gate fails (<395 taxa) | Too many genomes lack BUSCO hits | Check `blast_summary.tsv` per-gene counts. Consider relaxing `MIN_HIT_LENGTH_AA` or adding more marker genes. |
| Test alignment OOM | Genome(s) too large for 360 GB | Increase `--mem` in test_alignment.slurm, or manually select smaller genomes. |
| `cactus: command not found` | Not using Singularity exec | All Cactus commands run **inside** the container: `singularity exec --cleanenv ... cactus ...` |
| Tree has multifurcations | Grafting created polytomies | Check `nuclear_guide_tree_439.nwk` validation output. Cactus requires strictly binary trees. |

---

## Grace HPC Quick Reference

| Partition | Max Wall-Time | Max Nodes | Notes |
|-----------|--------------|-----------|-------|
| `short` | 2 hours | 16 | Too short for most SCARAB jobs |
| `medium` | 1 day | 16 | Nuclear tree building, test alignment |
| `long` | 7 days | 16 | Medium-duration jobs |
| `xlong` | 21 days | 4 | Full alignment |
| `bigmem` | 2 days | 1 | High-memory nodes (up to 3 TB) |

**Key facts:**
- Compute nodes have **NO internet access** — download everything on login nodes first
- File transfer: Use `sftp` (not `scp`) due to Duo 2FA
- Scratch: `/scratch/user/${USER}/` — no backup, 90-day purge policy
- Container: Singularity (not Docker) — always use `--cleanenv` flag

---

## Next Steps

Once test validation passes:
1. Human reviews all scripts for correctness
2. Proceed to **HOWTO 3.2** (Full Alignment on Grace)
3. Update `ai_use_log.md` with completion status
