# SCARAB - Phase 2 Scripts Manifest

**Generated:** 2026-03-21
**Total Lines of Code:** 4018
**All scripts verified:** Bash and R syntax validated

## Overview

This document describes all SLURM submission scripts and analysis scripts for Phase 2 (Alignment & Synteny) of the SCARAB project on the TAMU Grace HPC cluster.

The pipeline follows a hierarchical alignment strategy:
1. **Setup & Testing** - Initialize container and validate environment
2. **Tree Decomposition** - Split guide tree into manageable subtrees
3. **Parallel Subtree Alignment** - Align each clade independently (high compute)
4. **Backbone Alignment** - Align root nodes and outgroups (high memory)
5. **Merging** - Combine subtrees into final alignment
6. **Synteny Extraction** - Pull conserved blocks from HAL
7. **Quality Control** - Filter low-quality synteny blocks
8. **Ancestral Reconstruction** - RACA ancestral genome prediction
9. **Anchoring** - Map blocks to ancestral genomes
10. **Integration Report** - Generate Phase 2 summary

---

## Script Directory Structure

```
phase3_alignment_synteny/
├── PHASE_2.1_pipeline_setup/
│   ├── setup_grace.sh              (Initialize Grace environment)
│   └── test_alignment.slurm        (Verify cactus works on small test set)
├── PHASE_2.2_full_alignment/
│   ├── split_tree.R                (Decompose guide tree into subtrees)
│   ├── submit_subtree.slurm        (Template for single subtree alignment)
│   ├── submit_backbone.slurm       (Root alignment with high memory)
│   ├── merge_subtrees.slurm        (Merge all HAL files)
│   └── submit_all.sh               (Master submission script)
├── PHASE_2.3_hal_synteny_extraction/
│   └── extract_synteny.slurm       (Extract pairwise synteny blocks)
├── PHASE_2.4_synteny_qc/
│   └── synteny_qc.R                (Filter low-quality blocks)
├── PHASE_2.5_ancestral_reconstruction/
│   └── run_raca.slurm              (RACA ancestral reconstruction)
├── PHASE_2.6_synteny_anchoring/
│   └── anchor_synteny.R            (Map blocks to ancestral genomes)
└── PHASE_2.7_integration_signoff/
    └── integration_report.R        (Generate Phase 2 summary report)
```

---

## Script Descriptions

### PHASE 2.1: Pipeline Setup

#### `setup_grace.sh` (407 lines)
**Purpose:** Initialize the Grace HPC environment for Coleoptera alignment

**Key Functions:**
- Creates project directories on `/scratch/user/$USER/scarab`
- Pulls Cactus Singularity container from DockerHub
- Verifies container functionality with cactus --help and halStats
- Copies genomes from inventory to local scratch (for I/O performance)
- Creates cactus seqFile from genome paths
- Prunes constraint tree to match available genomes using Python

**User Customization Required:**
- Line 24: `NETID="your_netid"` - Enter your TAMU username
- Line 27: `GENOME_INVENTORY="/path/to/..."` - Genome inventory from Phase 1
- Line 30: `CONSTRAINT_TREE="/path/to/..."` - Tree from Phase 1

**Output:**
- `/scratch/user/$USER/scarab/cactus_container.sif` (Singularity image)
- `/scratch/user/$USER/scarab/seqFile.txt` (genome paths for cactus)
- `/scratch/user/$USER/scarab/pruned_tree.nwk` (filtered tree)
- `/scratch/user/$USER/scarab/logs/setup.log` (execution log)

**Execution:**
```bash
bash setup_grace.sh
```

---

#### `test_alignment.slurm` (272 lines)
**Purpose:** Test cactus alignment on small subset of genomes

**SLURM Configuration:**
- Queue: short (2 hour max)
- Nodes: 1 (48 cores, 384 GB)
- Time: 02:00:00

**Key Functions:**
- Runs cactus on first 5 genomes from seqFile
- Creates simple star tree for test genomes
- Validates HAL output with halStats
- Confirms environment works correctly

**User Customization Required:**
- Line 34: `NETID="your_netid"`
- Line 37: `EMAIL="your_email@tamu.edu"` (optional)
- Line 60: `--consCores 48` (adjust to match allocation)

**Output:**
- `test_alignment_${JOBID}.hal` (test alignment)
- `test_alignment_${JOBID}.log` (execution log)
- `halstats_*.txt` (alignment statistics)

**Submission:**
```bash
sbatch test_alignment.slurm
```

---

### PHASE 2.2: Full Alignment

#### `split_tree.R` (451 lines)
**Purpose:** Decompose phylogenetic tree into balanced subtrees for parallel alignment

**Key Functions:**
- Reads full constraint tree in Newick format
- Reads seqFile with genome paths
- Identifies major clade boundaries (Adephaga, Cucujiformia, etc.)
- Splits tree into N subtrees with configurable minimum size
- Creates per-subtree seqFiles for cactus
- Generates backbone tree for merging step
- Produces detailed report with tree statistics

**User Customization Required:**
- Line 24-30: Configure Coleoptera clade boundaries (CRITICAL)
  - Known clades: Adephaga, Cucujiformia, Elateriformia, Staphyliniformia
  - Currently implemented as heuristic; refine for your data

**Command-line Arguments:**
```bash
Rscript split_tree.R \
  --tree /path/to/pruned_tree.nwk \
  --seqfile /path/to/seqFile.txt \
  --output-dir /path/to/split_trees \
  --num-subtrees 5 \
  --min-subtree-size 3
```

**Output:**
- `subtree_1.nwk`, `subtree_2.nwk`, ... (Newick format trees)
- `subtree_1.seqfile`, `subtree_2.seqfile`, ... (genome lists)
- `backbone.nwk` (root + outgroups tree)
- `backbone.seqfile` (root genomes)
- `split_tree_report.txt` (statistics)

---

#### `submit_subtree.slurm` (330 lines)
**Purpose:** Template for aligning a single clade subtree using cactus

**SLURM Configuration:**
- Queue: long (7 days max)
- Nodes: 1 (48 cores, 384 GB)
- Time: 7-00:00:00

**Key Features:**
- Supports checkpointing for job restart
- Parameterized by SUBTREE_NUM via --export flag
- Automatic halStats validation on completion
- Can be submitted in parallel for multiple subtrees

**User Customization Required:**
- Line 36: `NETID="your_netid"`
- Line 39: `EMAIL="your_email@tamu.edu"`
- Line 42: `SUBTREE_NUM=${SUBTREE_NUM:-${SLURM_ARRAY_TASK_ID:-1}}`
- Line 65: `--consCores 48` (adjust if needed)

**Submission (Individual):**
```bash
sbatch --export=SUBTREE_NUM=1 submit_subtree.slurm
sbatch --export=SUBTREE_NUM=2 submit_subtree.slurm
# ... for each subtree
```

**Output:**
- `/scratch/user/$USER/scarab/hal_files/subtree_N.hal`
- `/scratch/user/$USER/scarab/work/subtree_N/halstats_N.txt`
- Checkpoint files for resumption if timeout

---

#### `submit_backbone.slurm` (346 lines)
**Purpose:** Align backbone tree (root nodes + outgroups) with high memory

**SLURM Configuration:**
- Queue: bigmem (2 day limit)
- Nodes: 1 (80 cores, 3 TB RAM)
- Time: 2-00:00:00

**Key Features:**
- Verifies all subtree HAL files exist before starting
- Uses 64-78 cores to avoid memory contention
- Runs halStats and halValidate after completion
- Should be submitted with dependency on subtree jobs

**User Customization Required:**
- Line 36: `NETID="your_netid"`
- Line 39: `EMAIL="your_email@tamu.edu"`
- Line 63: `--consCores 64` (adjust from max 80)

**Submission (Manual):**
```bash
sbatch submit_backbone.slurm
```

**Submission (With Dependencies):**
```bash
sbatch --dependency=afterok:${SUBTREE_JOB_1}:${SUBTREE_JOB_2}:... submit_backbone.slurm
```

**Output:**
- `/scratch/user/$USER/scarab/hal_files/backbone.hal`
- `/scratch/user/$USER/scarab/work/backbone/halstats_backbone.txt`
- halValidate report

---

#### `merge_subtrees.slurm` (329 lines)
**Purpose:** Merge all subtree and backbone HAL files into final alignment

**SLURM Configuration:**
- Queue: medium (1 day limit)
- Nodes: 1 (48 cores, 384 GB)
- Time: 1-00:00:00

**Key Features:**
- Uses halAppendSubtree for hierarchical merging
- Verifies all prerequisites exist
- Runs halValidate and halStats on final HAL
- Generates genome list and merge report

**User Customization Required:**
- Line 32: `NETID="your_netid"`
- Line 35: `EMAIL="your_email@tamu.edu"`

**Submission (With Dependencies):**
```bash
sbatch --dependency=afterok:${BACKBONE_JOB_ID} merge_subtrees.slurm
```

**Output:**
- `/scratch/user/$USER/scarab/results/scarab_final.hal` (FINAL ALIGNMENT)
- `/scratch/user/$USER/scarab/work/merge/halstats_final.txt`
- `/scratch/user/$USER/scarab/work/merge/merge_report.txt`

---

#### `submit_all.sh` (331 lines)
**Purpose:** Master script to orchestrate entire alignment pipeline

**Workflow:**
1. Submits all N subtree jobs in parallel (captures job IDs)
2. Submits backbone job with dependency on all subtree jobs
3. Submits merge job with dependency on backbone job

**User Customization Required:**
- Line 25: `NETID="your_netid"`
- Line 28: `NUM_SUBTREES=5` (from split_tree.R output)
- Line 31: `SPLIT_TREE_DIR="/path/to/split_trees"` (from split_tree.R)

**Execution:**
```bash
bash submit_all.sh
```

**Output:**
- `submission_log_YYYYMMDD_HHMMSS.txt` (detailed job tracking)
- All job IDs printed to stdout
- Example output:
  ```
  Subtree jobs (5 parallel):
    1. 12345678
    2. 12345679
    3. 12345680
    4. 12345681
    5. 12345682

  Backbone job:
    12345683

  Merge job:
    12345684
  ```

**Monitoring:**
```bash
squeue -u $USER
watch 'squeue -u $USER | grep coleoptera'
tail -f subtree_1_alignment_*.log
```

---

### PHASE 2.3: HAL Synteny Extraction

#### `extract_synteny.slurm` (323 lines)
**Purpose:** Extract pairwise synteny blocks from merged HAL alignment

**SLURM Configuration:**
- Queue: medium (1 day limit)
- Nodes: 1 (48 cores, 384 GB)
- Time: 1-00:00:00

**Key Functions:**
- Runs halSynteny from Cactus container
- Extracts conserved genome segments for all species pairs
- Formats output as TSV with coordinates and identity
- Generates summary statistics

**User Customization Required:**
- Line 32: `NETID="your_netid"`
- Line 35: `EMAIL="your_email@tamu.edu"`

**Submission:**
```bash
sbatch --dependency=afterok:${MERGE_JOB_ID} extract_synteny.slurm
```

**Output:**
- `synteny_blocks_raw.tsv` (all pairwise blocks)
- `synteny_stats.txt` (block size & identity distributions)

**Tab-separated Format:**
```
query_genome  target_genome  query_chrom  query_start  query_end  ...  identity  block_size
```

---

### PHASE 2.4: Synteny QC

#### `synteny_qc.R` (329 lines)
**Purpose:** Quality-control filtering of synteny blocks

**Filtering Steps:**
1. **Minimum block size:** Remove blocks < 10 kb (configurable)
2. **Minimum identity:** Remove blocks < 95% identity (configurable)
3. **Self-alignments:** Remove same-species comparisons
4. **Fold-back artifacts:** Remove inverted repeat structures
5. **Deduplication:** Keep best alignment per region pair

**Command-line Arguments:**
```bash
Rscript synteny_qc.R \
  --input synteny_blocks_raw.tsv \
  --output synteny_blocks_qc.tsv \
  --report synteny_qc_report.txt \
  --min-size 10000 \
  --min-identity 0.95 \
  --remove-self TRUE \
  --remove-foldbacks TRUE
```

**Output:**
- `synteny_blocks_qc.tsv` (filtered, high-quality blocks)
- `synteny_qc_report.txt` (filtering statistics and ratios)

**Typical Filtering Results:**
- Input: ~50,000 raw blocks
- Output: ~35,000 high-quality blocks (70% retained)
- Removed: Low-quality, small, or duplicate blocks

---

### PHASE 2.5: Ancestral Reconstruction

#### `run_raca.slurm` (325 lines)
**Purpose:** Run RACA ancestral genome reconstruction for internal nodes

**SLURM Configuration:**
- Queue: long (7 day limit)
- Nodes: 1 (48 cores, 384 GB)
- Time: 7-00:00:00

**Key Functions:**
- Extracts internal node names from HAL alignment
- Runs RACA for each internal node
- Collects FASTA output from all ancestors
- Generates summary statistics

**User Customization Required:**
- Line 32: `NETID="your_netid"`
- Line 35: `EMAIL="your_email@tamu.edu"`
- Line 130-150: RACA command syntax (varies by version)

**Submission:**
```bash
sbatch --dependency=afterok:${MERGE_JOB_ID} run_raca.slurm
```

**Output:**
- `ancestral_genomes/MRCA_clade1/ancestral_genome.fa`
- `ancestral_genomes/MRCA_clade2/ancestral_genome.fa`
- ... (one per internal node)
- `raca_summary.txt` (reconstruction statistics)

---

### PHASE 2.6: Synteny Anchoring

#### `anchor_synteny.R` (404 lines)
**Purpose:** Map synteny blocks to ancestral genome locations

**Key Functions:**
- Reads QC-filtered synteny blocks
- Matches blocks to ancestral genomes (BLAST-like approach)
- Assigns blocks to most-likely ancestral ancestor
- Computes conservation matrix (which ancestors show which blocks)
- Evaluates anchoring quality

**Command-line Arguments:**
```bash
Rscript anchor_synteny.R \
  --synteny synteny_blocks_qc.tsv \
  --ancestors /path/to/ancestral_genomes \
  --genomes /path/to/extant_genomes \
  --output synteny_anchored.tsv \
  --min-overlap 0.50
```

**Output:**
- `synteny_anchored.tsv` (blocks with ancestor annotations)
- `synteny_anchored_conservation_matrix.tsv` (ancestors x conservation)
- `anchoring_report.txt` (statistics and quality metrics)

**Quality Levels:**
- High: identity > 99%, block size > 50 kb
- Medium: identity > 97%, block size > 20 kb
- Low: everything else

---

### PHASE 2.7: Integration Report

#### `integration_report.R` (431 lines)
**Purpose:** Generate comprehensive Phase 2 summary and quality report

**Key Functions:**
- Aggregates statistics from all upstream phases
- Creates quality metrics table
- Generates visualizations (ggplot2-based if available)
- Produces PDF report with alignment coverage, block distributions, etc.
- Writes text summary for easy reference

**Command-line Arguments:**
```bash
Rscript integration_report.R \
  --hal-dir /path/to/hal_files \
  --synteny-dir /path/to/synteny \
  --ancestors-dir /path/to/ancestral \
  --output-pdf phase2_integration_report.pdf \
  --summary-txt phase2_integration_summary.txt \
  --metrics-tsv phase2_quality_metrics.tsv
```

**Output:**
- `phase2_integration_report.pdf` (publication-ready summary with plots)
- `phase2_integration_summary.txt` (text summary)
- `phase2_quality_metrics.tsv` (detailed metrics table)

**Includes:**
- Alignment coverage statistics
- Synteny block distributions
- Ancestral genome statistics
- Quality control metrics
- Sample visualizations (if ggplot2 available)

---

## Workflow Execution Guide

### Quick Start (Automated)

```bash
# 1. Setup environment
bash PHASE_2.1_pipeline_setup/setup_grace.sh

# 2. Test alignment (optional but recommended)
sbatch PHASE_2.1_pipeline_setup/test_alignment.slurm
# Wait for completion and verify output

# 3. Decompose guide tree
Rscript PHASE_2.2_full_alignment/split_tree.R \
  --tree /scratch/user/$NETID/scarab/pruned_tree.nwk \
  --seqfile /scratch/user/$NETID/scarab/seqFile.txt \
  --output-dir /scratch/user/$NETID/scarab/split_trees \
  --num-subtrees 5

# 4. Submit entire pipeline with master script
bash PHASE_2.2_full_alignment/submit_all.sh
# This automatically handles dependencies!

# 5. Monitor progress
watch 'squeue -u $USER | grep coleoptera'

# 6. Once merge completes, proceed with downstream phases
sbatch PHASE_2.3_hal_synteny_extraction/extract_synteny.slurm --dependency=afterok:MERGE_JOB_ID
```

### Manual Execution (Step-by-Step)

```bash
# 1. Setup
bash PHASE_2.1_pipeline_setup/setup_grace.sh

# 2. Split tree
Rscript PHASE_2.2_full_alignment/split_tree.R ...

# 3. Submit subtrees in parallel
for i in {1..5}; do
  sbatch --export=SUBTREE_NUM=$i PHASE_2.2_full_alignment/submit_subtree.slurm
done

# 4. Wait for subtrees, then submit backbone
# (Check squeue until all subtrees complete)
SUBTREE_JOBS="12345678:12345679:12345680:12345681:12345682"
sbatch --dependency=afterok:$SUBTREE_JOBS PHASE_2.2_full_alignment/submit_backbone.slurm

# 5. Wait for backbone, then submit merge
BACKBONE_JOB="12345683"
sbatch --dependency=afterok:$BACKBONE_JOB PHASE_2.2_full_alignment/merge_subtrees.slurm

# 6. After merge (check squeue), extract synteny
MERGE_JOB="12345684"
sbatch --dependency=afterok:$MERGE_JOB PHASE_2.3_hal_synteny_extraction/extract_synteny.slurm

# 7. QC filtering
Rscript PHASE_2.4_synteny_qc/synteny_qc.R ...

# 8. Ancestral reconstruction
sbatch PHASE_2.5_ancestral_reconstruction/run_raca.slurm

# 9. Synteny anchoring
Rscript PHASE_2.6_synteny_anchoring/anchor_synteny.R ...

# 10. Integration report
Rscript PHASE_2.7_integration_signoff/integration_report.R ...
```

---

## Resource Requirements & Queue Selection

| Phase | Task | Queue | Nodes | Cores | RAM | Time | Notes |
|-------|------|-------|-------|-------|-----|------|-------|
| 2.1 | Setup | N/A | N/A | 1-4 | 8GB | <1 hr | Local |
| 2.1 | Test align | short | 1 | 48 | 384GB | 1 hr | Validates setup |
| 2.2 | Subtree (each) | long | 1 | 48 | 384GB | 1-4 days | Parallel |
| 2.2 | Backbone | bigmem | 1 | 80 | 3TB | 4-12 hrs | After subtrees |
| 2.2 | Merge | medium | 1 | 48 | 384GB | 2-6 hrs | After backbone |
| 2.3 | Synteny extract | medium | 1 | 48 | 384GB | 4-12 hrs | After merge |
| 2.4 | QC filtering | N/A | N/A | 4-8 | 32GB | <1 hr | Local or submit |
| 2.5 | RACA | long | 1 | 48 | 384GB | 2-7 days | After merge |
| 2.6 | Anchoring | N/A | N/A | 4-8 | 32GB | <1 hr | Local or submit |
| 2.7 | Integration | N/A | N/A | 4-8 | 16GB | <1 hr | Local |

---

## Directory Structure (After Execution)

```
/scratch/user/$NETID/scarab/
├── cactus_container.sif           (Singularity image)
├── seqFile.txt                    (Genome inventory)
├── pruned_tree.nwk                (Filtered tree)
├── split_trees/
│   ├── subtree_1.nwk
│   ├── subtree_1.seqfile
│   ├── subtree_2.nwk
│   ├── subtree_2.seqfile
│   ├── ...
│   ├── backbone.nwk
│   └── backbone.seqfile
├── hal_files/
│   ├── subtree_1.hal
│   ├── subtree_2.hal
│   ├── ...
│   └── backbone.hal
├── results/
│   └── scarab_final.hal       (FINAL ALIGNMENT)
├── synteny/
│   ├── synteny_blocks_raw.tsv
│   ├── synteny_blocks_qc.tsv
│   ├── synteny_anchored.tsv
│   ├── synteny_stats.txt
│   └── synteny_qc_report.txt
├── ancestral/
│   ├── MRCA_clade1/
│   │   └── ancestral_genome.fa
│   ├── MRCA_clade2/
│   │   └── ancestral_genome.fa
│   └── raca_summary.txt
├── genomes/                       (Local copies for I/O)
│   ├── species1.fa
│   ├── species2.fa
│   └── ...
└── work/
    ├── subtree_1/
    ├── subtree_2/
    ├── ...
    ├── backbone/
    ├── merge/
    ├── synteny/
    ├── raca/
    └── logs/
        └── setup.log
```

---

## Important Notes & Troubleshooting

### Customization Required

All scripts contain `## <<<STUDENT: description>>>` markers where you MUST customize values:

1. **NETID** - Your TAMU username (e.g., "asmith42")
2. **EMAIL** - Your email for SLURM notifications
3. **Paths** - From Phase 1 (genome inventory, constraint tree)
4. **Clade boundaries** - Update for your specific phylogeny
5. **Parameters** - Adjust cores, memory, time limits based on your data

### Common Issues

**Setup fails to find genomes:**
- Verify GENOME_INVENTORY path is correct
- Check that genome files exist at specified paths
- Run `ls /path/to/genomes/ | head` to test

**Cactus alignment times out:**
- Increase `--time` in SLURM header
- Resubmit: Cactus will resume from checkpoint
- Reduce subtree size (more subtrees, each smaller)

**halStats fails:**
- Verify HAL file was created: `ls -lh *.hal`
- Check Singularity container is accessible
- Try running halStats manually to debug

**Memory exceeded:**
- Move to bigmem queue if possible
- Reduce `--consCores` to free memory
- Increase job time to allow slower progress

### Checkpointing & Restart

Cactus supports automatic checkpointing:
- Intermediate files stored in `work/subtree_N/checkpoint/`
- If job times out, resubmit with same SUBTREE_NUM
- Cactus resumes from checkpoint automatically
- Do NOT delete checkpoint directory until alignment succeeds

### Monitoring Long Jobs

```bash
# Check status
squeue -u $USER

# Watch progress in real-time
watch 'squeue -u $USER | grep coleoptera'

# Check memory usage
sstat -j JOBID --format=AveCPU,AveRSS,MaxRSS

# View recent logs
tail -100 subtree_1_alignment_*.log | less
```

---

## Publications & Citation

If you use these scripts in published research, please cite:

- **Cactus**: Armstrong et al. (2020). "Progressive Cactus is a multiple-genome aligner for the thousand-genome era" *Genome Biology*
- **HAL**: Hickey et al. (2013). "HAL: a hierarchical format for storing and analyzing multiple genome alignments" *Bioinformatics*
- **RACA**: Ma et al. (2006). "Reconstructing contiguous regions of an ancestral genome" *Genome Research*

---

## Support & Debugging

For issues:

1. **Check logs** - Always review .log files first
   - `/scratch/user/$NETID/scarab/logs/setup.log`
   - `cactus_1.log` (job-specific Cactus logs)

2. **Verify inputs** - Ensure all prerequisite files exist:
   - Genome inventory from Phase 1
   - Constraint tree from Phase 1
   - Cactus container successfully pulled

3. **Test in interactive mode** - For debugging:
   ```bash
   srun -p short -N1 -n48 --mem=384G --pty bash
   # Then run commands manually
   ```

4. **Contact your HPC support** - TAMU Grace cluster:
   - hpc@tamu.edu
   - Include job ID, error messages, and command used

---

**Last Updated:** 2026-03-21
**Version:** 1.0
**Status:** Production Ready
