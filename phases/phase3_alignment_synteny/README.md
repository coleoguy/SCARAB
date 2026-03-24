# SCARAB - Phase 2: Alignment & Synteny Scripts

## Quick Start

1. **Read the manifest**: Open `SCRIPTS_MANIFEST.md` (comprehensive reference)
2. **Customize**: Find `<<<STUDENT: xxx>>>` markers in each script
3. **Setup**: Run `bash PHASE_2.1_pipeline_setup/setup_grace.sh`
4. **Submit**: Run `bash PHASE_2.2_full_alignment/submit_all.sh`
5. **Monitor**: Watch `squeue -u $USER | grep coleoptera`

## Contents

| Phase | Script | Purpose |
|-------|--------|---------|
| 2.1 | setup_grace.sh | Initialize Grace environment |
| 2.1 | test_alignment.slurm | Validate environment on test set |
| 2.2 | split_tree.R | Decompose guide tree into subtrees |
| 2.2 | submit_all.sh | **Master orchestrator** (START HERE) |
| 2.2 | submit_subtree.slurm | Align single subtree (template) |
| 2.2 | submit_backbone.slurm | Align backbone (high memory) |
| 2.2 | merge_subtrees.slurm | Merge all HAL files |
| 2.3 | extract_synteny.slurm | Extract synteny blocks from HAL |
| 2.4 | synteny_qc.R | Quality-control filter blocks |
| 2.5 | run_raca.slurm | Ancestral genome reconstruction |
| 2.6 | anchor_synteny.R | Map blocks to ancestral genomes |
| 2.7 | integration_report.R | Generate Phase 2 summary |

## Directory Structure

```
phase3_alignment_synteny/
├── PHASE_2.1_pipeline_setup/
├── PHASE_2.2_full_alignment/
├── PHASE_2.3_hal_synteny_extraction/
├── PHASE_2.4_synteny_qc/
├── PHASE_2.5_ancestral_reconstruction/
├── PHASE_2.6_synteny_anchoring/
├── PHASE_2.7_integration_signoff/
├── SCRIPTS_MANIFEST.md          (← Read this first!)
└── README.md                    (← You are here)
```

## Workflow

```
setup_grace.sh
      ↓
test_alignment.slurm
      ↓
split_tree.R
      ↓
submit_all.sh (orchestrates all below)
  ├─ submit_subtree.slurm (x N in parallel)
  ├─ submit_backbone.slurm (after subtrees)
  └─ merge_subtrees.slurm (after backbone)
      ↓
extract_synteny.slurm
      ↓
synteny_qc.R
      ↓
run_raca.slurm
      ↓
anchor_synteny.R
      ↓
integration_report.R
```

## Key Files

- **SCRIPTS_MANIFEST.md** - Complete 1070-line reference (read first!)
- **submit_all.sh** - Master script that manages all dependencies
- **setup_grace.sh** - Environment initialization
- **split_tree.R** - Tree decomposition (must customize for your clades!)

## Before Running

1. Edit each script and find `<<<STUDENT: xxx>>>` markers
2. Replace with:
   - Your TAMU NetID (username)
   - Email address
   - Paths from Phase 1
   - Clade boundaries for your phylogeny

3. Test: `bash PHASE_2.1_pipeline_setup/setup_grace.sh`

## Execution

```bash
# 1. Setup
bash PHASE_2.1_pipeline_setup/setup_grace.sh

# 2. Test (optional)
sbatch PHASE_2.1_pipeline_setup/test_alignment.slurm

# 3. Split tree
Rscript PHASE_2.2_full_alignment/split_tree.R \
  --tree /scratch/user/$NETID/scarab/pruned_tree.nwk \
  --seqfile /scratch/user/$NETID/scarab/seqFile.txt \
  --output-dir /scratch/user/$NETID/scarab/split_trees \
  --num-subtrees 5

# 4. Run entire pipeline
bash PHASE_2.2_full_alignment/submit_all.sh

# 5. Monitor
watch 'squeue -u $USER | grep coleoptera'
```

## Output

- **Final alignment**: `/scratch/user/$NETID/scarab/results/scarab_final.hal`
- **Synteny blocks**: `/scratch/user/$NETID/scarab/synteny/`
- **Ancestral genomes**: `/scratch/user/$NETID/scarab/ancestral/`
- **Reports**: Various `.txt` and `.tsv` files in work directories

## Resources

- Scripts: 12 files, 4018 lines
- Estimated runtime: 7-21 days
- Queue usage: short, long, medium, bigmem
- Parallelization: Up to N subtree jobs in parallel

## Support

- Check `SCRIPTS_MANIFEST.md` for troubleshooting
- Review logs in `/scratch/user/$NETID/scarab/logs/`
- Contact: hpc@tamu.edu (include job ID and script name)

---

**Status**: Production Ready  
**Validation**: All scripts verified (bash syntax, R syntax, SLURM headers)  
**Last Updated**: 2026-03-21
