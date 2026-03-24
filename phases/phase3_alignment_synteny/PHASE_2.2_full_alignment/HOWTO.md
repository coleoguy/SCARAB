# HOWTO 3.2: Full 439-Genome Alignment on Grace

**Task Goal:** Run ProgressiveCactus on all 439 beetle and outgroup genomes to produce a HAL-format whole-genome alignment. This is the primary compute job for SCARAB.

**Timeline:** Days 8–28 (estimated 1–3 weeks wall-clock time)
**Resource Allocation:** 200,000 SUs
**Responsible Person:** Heath (submits and monitors on Grace)

---

## Prerequisites

All must be complete before submitting the full alignment:

- [ ] **HOWTO 3.1 complete:** setup_phase3.sh ran successfully (container pulled, seqFile built, cactus-prepare ran)
- [ ] **Nuclear guide tree built:** `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439.nwk` exists with 439 tips, ≥90% molecular data (via `extract_nuclear_markers_and_build_tree.slurm`)
- [ ] **Test alignment passed:** `test_alignment.slurm` produced a valid HAL for 5 small genomes
- [ ] **seqFile validated:** `$SCRATCH/scarab/cactus_seqfile.txt` has 439 genome entries, all FASTA paths accessible

---

## Inputs

| File | Location on Grace | Description |
|------|-------------------|-------------|
| `cactus_seqfile.txt` | `$SCRATCH/scarab/` | Line 1: Nuclear BUSCO marker guide tree (Newick); Lines 2+: `tip_label /path/to/genome.fna` × 439 |
| `cactus_v2.9.3.sif` | `$SCRATCH/scarab/` | Singularity container with Cactus, halStats, halValidate |

---

## Outputs

1. **`$SCRATCH/scarab/hal_files/scarab.hal`** — the primary deliverable (~50–100 GB)
2. **`scarab_full_<JOBID>.log`** — SLURM stdout log
3. **`scarab_full_<JOBID>.err`** — SLURM stderr log

---

## Acceptance Criteria

- [ ] HAL file exists at `$SCRATCH/scarab/hal_files/scarab.hal`
- [ ] HAL file size ≥ 50 GB
- [ ] `halStats` shows all 439 genomes aligned
- [ ] `halValidate` passes structural integrity checks
- [ ] SLURM job exit code = 0
- [ ] No fatal errors in stderr log

---

## Alignment Strategy

We offer two approaches, depending on available resources and queue scheduling:

### Approach A: Monolithic Single-Node (Recommended)

Run the entire alignment as one large job on an `xlong` queue bigmem node. Cactus internally decomposes the alignment along the guide tree. This is simpler to manage and supports automatic resume from a Toil jobStore.

**Script:** `grace_upload_phase3/run_full_alignment.slurm`

**SLURM parameters:**
- Partition: `xlong` (21-day limit)
- Nodes: 1
- CPUs: 80
- Memory: 2,900 GB (2.9 TB)
- Estimated runtime: 7–21 days

### Approach B: Hierarchical Subtree Decomposition (Alternative)

Split the alignment into subtrees using `cactus-prepare`, run subtrees in parallel on separate nodes, align a backbone tree, then merge with `halAppendSubtree`. Faster wall-clock time but more complex to manage.

**Scripts (in this directory):**
- `submit_all.sh` — Master submission script with SLURM dependency chains
- `submit_subtree.slurm` — Align individual subtrees (long queue, 48 cores, 384 GB)
- `submit_backbone.slurm` — Align backbone (bigmem queue, 80 cores, 3 TB)
- `merge_subtrees.slurm` — Merge subtree HALs with halAppendSubtree (medium queue)

**Expected timeline:** ~7 days total (subtrees 1–4 days → backbone 1–2 days → merge < 1 day)

**To use:** Edit `NETID` and `NUM_SUBTREES` in `submit_all.sh`, then run `bash submit_all.sh`.

---

## Step-by-Step Instructions (Approach A — Monolithic)

### Step 1: Final Pre-Flight Checks

```bash
ssh grace
cd $SCRATCH/scarab

# Verify seqFile has 439 genomes
tail -n +2 cactus_seqfile.txt | wc -l
# Expected: 439

# Spot-check a few FASTA paths are valid
tail -n +2 cactus_seqfile.txt | head -3 | while read tip path; do
  echo "$tip: $(ls -lh $path 2>&1 | head -1)"
done

# Verify container
singularity exec --cleanenv \
  -B $SCRATCH/scarab:$SCRATCH/scarab \
  cactus_v2.9.3.sif \
  cactus --version
# Expected: 2.9.3

# Check scratch quota
showquota
# Ensure ≥ 500 GB free (HAL ~50-100 GB + temp files)
```

---

### Step 2: Submit Full Alignment

```bash
cd $SCRATCH/scarab

# Ensure scripts are executable
chmod +x scripts/run_full_alignment.slurm

# Submit
sbatch scripts/run_full_alignment.slurm
```

Save the job ID (e.g., `Submitted batch job 18200001`).

**What the script does:**
1. Validates seqFile (≥ 400 genomes) and container existence
2. Checks for existing jobStore (if found, resumes; otherwise starts fresh)
3. Runs `cactus` via Singularity with:
   - `--maxCores 80` — use all available cores
   - `--maxMemory 2900000M` — ~2.9 TB RAM ceiling
   - `--defaultMemory 8G` — per-job default
   - `--maxDisk 2000G` — disk limit for Toil
   - `--restart` — if jobStore exists (automatic resume)
4. Validates output HAL with `halStats`

---

### Step 3: Monitor Progress

#### Quick status check:
```bash
squeue -u $USER
# Or filter for SCARAB jobs:
squeue -u $USER --name=scarab_cactus
```

#### Watch live output:
```bash
tail -f $SCRATCH/scarab/scarab_full_*.log
```

#### Check for errors:
```bash
tail -20 $SCRATCH/scarab/scarab_full_*.err
```

#### Resource usage:
```bash
sacct -j <JOBID> --format=JobID,State,Elapsed,MaxRSS,MaxVMSize
```

#### Disk usage:
```bash
du -sh $SCRATCH/scarab/work/full_jobstore/
du -sh $SCRATCH/scarab/hal_files/
showquota
```

### Monitoring Checklist (During 1–3 Week Alignment)

**Daily:**
- [ ] Job still running: `squeue -u $USER`
- [ ] No error messages: `tail -20 scarab_full_*.err`
- [ ] Scratch usage below 90% quota: `showquota`
- [ ] JobStore growing: `du -sh work/full_jobstore/`

**Weekly:**
- [ ] Estimate progress from log output (Cactus logs sub-problems being solved)
- [ ] Check no hung nodes: `sinfo -p xlong`

---

### Step 4: Handle Failures / Resume

Cactus supports **automatic resume** via its Toil jobStore. If the job dies (walltime, OOM, node failure):

```bash
# The jobStore is preserved at $SCRATCH/scarab/work/full_jobstore/
# Simply resubmit the same script — it detects the jobStore and resumes:
sbatch scripts/run_full_alignment.slurm
```

The script auto-detects the existing jobStore and adds `--restart`.

**To force a fresh start** (discards all progress):
```bash
rm -rf $SCRATCH/scarab/work/full_jobstore
sbatch scripts/run_full_alignment.slurm
```

**Common failure modes:**

| Failure | Log Message | Fix |
|---------|-------------|-----|
| Walltime exceeded | `TIMEOUT` in sacct | Resubmit — Cactus resumes from checkpoint |
| Out of memory | `MemoryError` or OOM killer | Check `MaxRSS` with sacct; if close to 2.9 TB, request bigmem node with more RAM |
| Disk full | `No space left on device` | Clear jobStore temp files: `find work/full_jobstore -name "*.tmp" -delete`; check quota |
| FASTA file error | `FileNotFoundError` or `Corrupt FASTA` | Verify the specific genome; re-download if needed |
| Container error | `singularity: command not found` | Add `module load Singularity` to script preamble |

---

### Step 5: Validate Completed Alignment

After the SLURM job shows `COMPLETED`:

```bash
# Check exit code
sacct -j <JOBID> --format=JobID,JobName,ExitCode,State
# Expected: ExitCode 0:0, State COMPLETED

# Verify HAL file exists and has reasonable size
ls -lh $SCRATCH/scarab/hal_files/scarab.hal
# Expected: 50-100 GB

# Run halStats
singularity exec --cleanenv \
  -B $SCRATCH/scarab:$SCRATCH/scarab \
  $SCRATCH/scarab/cactus_v2.9.3.sif \
  halStats $SCRATCH/scarab/hal_files/scarab.hal
# Expected: lists all 439 genomes with base counts

# Run halValidate (structural integrity)
singularity exec --cleanenv \
  -B $SCRATCH/scarab:$SCRATCH/scarab \
  $SCRATCH/scarab/cactus_v2.9.3.sif \
  halValidate --genome Tribolium_castaneum \
  $SCRATCH/scarab/hal_files/scarab.hal
# Expected: no errors

# Count genomes in HAL
singularity exec --cleanenv \
  -B $SCRATCH/scarab:$SCRATCH/scarab \
  $SCRATCH/scarab/cactus_v2.9.3.sif \
  halStats --genomes $SCRATCH/scarab/hal_files/scarab.hal | tr ' ' '\n' | wc -l
# Expected: 439 (plus ancestral nodes)
```

---

### Step 6: Document Results

```bash
cat > $SCRATCH/scarab/results/ALIGNMENT_COMPLETE.txt << 'EOF'
PHASE 3 TASK 3.2: FULL 439-GENOME CACTUS ALIGNMENT
=====================================================

Submission Date: [DATE]
Completion Date: [DATE]
Job ID: [SLURM JOB ID]

INPUTS:
- Genomes: 439 FASTA files
- Guide tree: Nuclear BUSCO marker tree (nuclear_guide_tree_439.nwk)
- Container: cactus_v2.9.3.sif

OUTPUTS:
- HAL file: hal_files/scarab.hal
- HAL size: [SIZE] GB

SLURM STATISTICS:
- Partition: xlong
- Cores: 80
- Memory: 2,900 GB
- Wall-time used: [TIME]
- Exit code: 0

ACCEPTANCE CRITERIA:
[✓] HAL file exists
[✓] HAL file size ≥ 50 GB
[✓] All 439 genomes in HAL (halStats)
[✓] halValidate passes
[✓] No SLURM errors

NOTES:
- [Any issues encountered and how they were resolved]
EOF
```

---

### Step 7: Backup HAL File

The HAL file is expensive to recreate (~200,000 SUs). Back it up:

```bash
# Option 1: Copy to $HOME (persistent, but check quota)
cp $SCRATCH/scarab/hal_files/scarab.hal $HOME/scarab_alignment/

# Option 2: Transfer off Grace via sftp (from local machine)
sftp grace
get /scratch/user/blackmon/scarab/hal_files/scarab.hal
# NOTE: 50-100 GB transfer; may take several hours

# Option 3: Keep on $SCRATCH and proceed with Phase 3.3 directly on Grace
# (recommended — avoids large data transfer)
```

**Important:** Grace `/scratch` has a 90-day purge policy for untouched files. Touch the HAL file periodically or move to a persistent location.

---

## Grace HPC Queue Reference

| Partition | Max Wall-Time | Max Nodes | Max RAM/Node | Notes |
|-----------|--------------|-----------|--------------|-------|
| `short` | 2 hours | 16 | 360 GB | Too short for SCARAB |
| `medium` | 1 day | 16 | 360 GB | Nuclear tree, test alignment |
| `long` | 7 days | 16 | 360 GB | Subtree alignments (Approach B) |
| `xlong` | 21 days | 4 | 360 GB | Full alignment (Approach A) |
| `bigmem` | 2 days | 1 | 3,000 GB | Backbone alignment (Approach B) |

**Key reminders:**
- Compute nodes have **NO internet** — all downloads must happen on login nodes
- Use `sftp` (not `scp`) for file transfers due to Duo 2FA
- Container: Singularity with `--cleanenv` flag; bind project directory with `-B`
- Email notifications: set `--mail-user=coleoguy@gmail.com` in SLURM scripts

---

## Next Steps

Once HAL file is validated and acceptance criteria met:
1. Proceed to **HOWTO 3.3** (HAL Synteny Extraction) — can run on Grace directly
2. HAL can remain on Grace `/scratch` for downstream analysis
3. Update `ai_use_log.md` with completion status
4. Consider cleaning up jobStore to reclaim disk: `rm -rf $SCRATCH/scarab/work/full_jobstore`
