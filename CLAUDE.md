# SCARAB — Claude Code Context

SCARAB = 478-beetle whole-genome alignment (ProgressiveCactus) to map chromosomal rearrangements across Coleoptera. PI: Heath Blackmon, TAMU.

**Before writing any script, read `context.md` for current project status, `FILE_MAP.md` for the full repo + Grace structure, and `grace_filesystem_map.md` for Grace paths.**

## Grace HPC Constraints

- **Python 3.6 ONLY** — no f-strings, no `capture_output=True`, no walrus `:=`, no `pathlib` conveniences. Use `subprocess.Popen` or `subprocess.run(..., stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)`.
- **Compute nodes have NO internet** — all downloads must happen on login node or transfer partition.
- **File transfer: sftp only** (not scp — Duo 2FA causes timeouts).
- **$SCRATCH** = `/scratch/user/blackmon/scarab`
- **NetID**: blackmon

## Grace Resource Limits (per user, verified 2026-03-27)

| Limit | Value | Source |
|-------|-------|--------|
| Max submitted jobs (all queues) | 500 | QOS "normal" MaxSubmitJobs |
| Max concurrent cores (all queues) | 6,144 | QOS "normal" MaxTRESPU |
| Max SLURM array size | 1,001 (0-1000) | scontrol MaxArraySize |
| Scratch quota (space) | 7 TB (expanded from 1 TB) | Approved 2026-03 |
| Scratch quota (files) | 500,000+ inodes | Approved 2026-03; exceeded 500K without enforcement |

### Partition Limits

| Partition | Max Wall | Max Nodes | Max Cores | Notes |
|-----------|----------|-----------|-----------|-------|
| short | 2 hr | 32 | 1,536 | Default partition |
| medium | 1 day | 128 | 6,144 | Gene trees, Cactus preprocess |
| long | 7 days | 64 | 3,072 | Deeper Cactus alignment levels |
| xlong | 21 days | 32 | 1,536 | Single-node Cactus (fallback) |
| bigmem | 2 days | 4 | 192 | 3 TB RAM nodes |
| gpu | 4 days | 32 | 1,536 | A100, RTX 6000, T4 GPUs |

### Practical Implications for SCARAB

- SLURM arrays >1000 tasks must be split into multiple submissions
- At 4 cores/gene-tree job: max ~500 concurrent gene jobs (job slot limited, not core limited)
- Cactus decomposed levels: leaf levels use medium (1-day wall); deep levels use long (7-day wall)
- Low-priority queue (if SUs exceeded): max 50 jobs, 500 cores, preemptible

## Key Paths on Grace

| What | Path |
|------|------|
| Project root | `$SCRATCH/scarab/` |
| Genomes | `$SCRATCH/scarab/genomes/{ACCESSION}/ncbi_dataset/data/{ACCESSION}/*.fna` |
| Rooted guide tree (439-taxon) | `$SCRATCH/scarab/nuclear_markers/nuclear_guide_tree_439_rooted.nwk` |
| Cactus seqfile | `$SCRATCH/scarab/cactus_seqfile.txt` |
| Tip mapping CSV | `$SCRATCH/scarab/data/tree_tip_mapping.csv` |
| BUSCO proteins (13,663 variants) | `$SCRATCH/scarab/nuclear_markers/insecta_odb10/ancestral_variants` (single file, not dir) |
| 15 guide-tree query proteins | `$SCRATCH/scarab/nuclear_markers/marker_proteins.fasta` |
| Phylogenomics workdir | `$SCRATCH/scarab/phylogenomics/` |
| 1,286 selected proteins | `$SCRATCH/scarab/phylogenomics/selected_proteins.fasta` |
| BUSCO→Tribolium map | `$SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv` |
| HAL output (future) | `$SCRATCH/scarab/hal_files/` |
| Cactus test workdir | `$SCRATCH/scarab/work/test_alignment/` |

## Genome FASTA Pattern

```
$SCRATCH/scarab/genomes/{ACCESSION}/ncbi_dataset/data/{ACCESSION}/*.fna
```
Example: `$SCRATCH/scarab/genomes/GCA_964197645.1/ncbi_dataset/data/GCA_964197645.1/GCA_964197645.1_icAbaPara2.1_genomic.fna`

## Module Load Commands

```bash
# BLAST (tBLASTn)
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

# MAFFT
module load GCC/12.2.0 MAFFT/7.520-with-extensions

# R
module purge && module load GCC/13.3.0 R/4.4.2

# IQ-TREE (also works for MAFFT together: module load GCC/12.3.0 OpenMPI/4.1.5 MAFFT/7.520-with-extensions IQ-TREE/2.3.6)
module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6

# FastTree
module load GCC/12.2.0 FastTree/2.1.11
```

## Script Locations

- **Canonical HPC scripts**: `grace_upload_phase3/` — this is the ONLY active script directory.
- **DEPRECATED**: `grace_upload/` — old scripts, do not use or modify.
- **Local analysis scripts**: `scripts/phase2/`, `scripts/phase3/deprecated/`

## Grace SSH Access (ControlMaster)

SSH ControlMaster is configured in `~/.ssh/config`. At the start of each work session, run this once in your terminal and approve the Duo push:

```bash
ssh -fN blackmon@grace.hprc.tamu.edu
```

After that, Claude Code can run Grace commands directly via the Bash tool (no Duo prompts):

```bash
ssh blackmon@grace.hprc.tamu.edu "squeue -u blackmon"
ssh blackmon@grace.hprc.tamu.edu "cat /scratch/user/blackmon/scarab/logs/somejob.log | tail -50"
```

The connection stays alive for 8 hours. To check if it's active: `ssh -O check blackmon@grace.hprc.tamu.edu`

## Workflow

Edit on Mac → `git push` → `git pull` on Grace → `cp` files to `$SCRATCH/scarab/`

## Quality Gate Policy (MANDATORY)

1. **Every pipeline output must be examined before it becomes input.** Download/transfer results so Heath can see them. Quantitatively evaluate. Visually inspect. Get explicit approval.
2. **If acceptance criteria fail, STOP.** Do not rationalize. Flag the problem and propose alternatives.
3. **Never assume success.** Even if SLURM exits 0 and QC says PASSED, walk through the output with Heath.
4. **NEVER suggest submitting the next job while checking the current one.** Present results first. Wait for approval. Only then discuss next steps.

## BUSCO Database Notes

- `insecta_odb10/ancestral_variants` is a **single multi-FASTA file**, not a directory
- `insecta_odb10/ancestral` is also a **single file** (one representative per gene)
- Gene IDs: `66690at50557_0`, `755at50557`, `1621at50557` (suffixes `_0`, `_1` are variants)
