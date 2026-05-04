# TOB Phase 5 — Fossil-Calibrated Divergence Dating (treePL)

All compute scripts run on Grace bigmem partition (treePL is single-node, high-RAM).
All scripts expect the Phase 1 IQ-TREE backbone tree and 100 bootstrap trees to exist.

## Prerequisites

- Phase 1 complete: dated backbone tree at `$SCRATCH/tob/phylogenomics/concat/tob_concat.treefile`
- Phase 1 bootstrap trees at `$SCRATCH/tob/phylogenomics/concat/tob_concat.ufboot` (100-tree file, IQ-TREE UFBoot format)
- `tob-treepl` conda env installed per `scripts/setup/install_treepl_grace.sh`
- Cai 2022 calibrations at `$SCRATCH/tob/dating/cai2022_calibrations.csv` (committed to repo, copy there)
- MRCA tip-label mapping at `$SCRATCH/tob/dating/mrca_mapping.csv` (Heath must supply — see below)

## Order of operations

1. **`01_calibs_to_treepl_config.py`** — login node. Reads calibrations CSV + MRCA mapping CSV,
   writes a treePL config file to `$SCRATCH/tob/dating/treepl_cv.config`.
   Run with: `python 01_calibs_to_treepl_config.py`. ~5 sec.

2. **`02_treepl_cv.slurm`** — bigmem partition. Cross-validation grid search over smoothing
   parameter (log-spaced values 1–1000). Produces `$SCRATCH/tob/dating/cv/cv_results.txt`.
   Submit: `sbatch 02_treepl_cv.slurm`. Wall: up to 24 hr.

3. **Inspect CV results.** Pick optimal smoothing (lowest CV score). Update
   `SMOOTHING=<value>` in `03_treepl_dating.slurm` and `04_bootstrap_array.slurm`.
   **Do not proceed until Heath approves.**

4. **`03_treepl_dating.slurm`** — bigmem. Final dated tree run. Output:
   `$SCRATCH/tob/dating/tob_dated.tre`. Submit: `sbatch 03_treepl_dating.slurm`. Wall: ~6–12 hr.

5. **`04_bootstrap_array.slurm`** — bigmem SLURM array (100 tasks). One treePL run per
   IQ-TREE bootstrap tree. Outputs in `$SCRATCH/tob/dating/bootstrap/dated_bs_{1..100}.tre`.
   Submit: `sbatch 04_bootstrap_array.slurm`. Wall per task: ~3–6 hr.

6. **`05_jackknife_calibrations.slurm`** — bigmem SLURM array (one task per calibration node).
   Drop-one fossil, re-date. Outputs in `$SCRATCH/tob/dating/jackknife/`.
   Submit: `sbatch 05_jackknife_calibrations.slurm`. Wall per task: ~6–12 hr.

7. **`06_burmese_amber_sensitivity.slurm`** — bigmem. Two treePL runs: with and without all
   9 Burmese amber calibrations. Outputs in `$SCRATCH/tob/dating/amber_sensitivity/`.
   Submit: `sbatch 06_burmese_amber_sensitivity.slurm`. Wall: up to 24 hr.

8. **`07_summarize_dates.R`** — any node. Takes bootstrap trees, jackknife trees, amber
   sensitivity trees; computes 95% HPD intervals, per-node sensitivity diagnostics.
   Run: `Rscript 07_summarize_dates.R`. Output in `$SCRATCH/tob/dating/summary/`.

## On completion

`$SCRATCH/tob/dating/` contains:
- `treepl_cv.config` — treePL config used for cross-validation
- `treepl_dated.config` — final dated-run config
- `cv/cv_results.txt` — CV scores across smoothing values
- `tob_dated.tre` — primary dated tree
- `bootstrap/dated_bs_*.tre` — 100 bootstrap dated trees
- `jackknife/*.tre` — drop-one calibration dated trees
- `amber_sensitivity/dated_with_amber.tre`, `dated_without_amber.tre`
- `summary/tob_dated_hpd.tre` — consensus tree with 95% HPD on nodes
- `summary/node_sensitivity.csv` — per-node fossil sensitivity table
- `logs/*.log` — timestamped logs

## Items requiring Heath's input before Step 1

### MRCA mapping CSV (REQUIRED)

`01_calibs_to_treepl_config.py` needs a file `mrca_mapping.csv` with columns:

```
node_num,tip1,tip2
```

where `tip1` and `tip2` are two TOB tip labels that together define the MRCA of each
calibration node. These must match exactly the tip labels in the IQ-TREE tree file.
Without this file the config generator cannot run.

Example row:
```
2,Priacma_serrata,Dytiscus_marginalis
```
(Node 2 = crown Coleoptera root; the two tips must bracket the full Coleoptera crown.)

### Smoothing parameter (Step 3)

After CV, Heath must choose the smoothing value and confirm before running Steps 4–7.

### Bootstrap tree extraction

The script assumes IQ-TREE wrote 100 separate ultrafast bootstrap trees into the `.ufboot`
file (one Newick per line). If Phase 1 used `-B 1000` the file contains 1000 trees — adjust
`TOTAL_BS` in `04_bootstrap_array.slurm` accordingly and re-read instructions.

## Grace constraints (carry-over from CLAUDE.md)

- Python 3.6 only on Grace — no f-strings, no `capture_output`, no walrus operator.
- `$SCRATCH` = `/scratch/user/blackmon/` (TOB working dir is `$SCRATCH/tob/`).
- bigmem partition: max 2-day wall, 4 nodes, 192 cores. treePL is single-threaded — 1 core per run.
- Scratch quota 7 TB; 100 bootstrap runs × ~GB each: monitor with `du -sh $SCRATCH/tob/dating/`.

## Safety

Every script writes timestamped logs to `$SCRATCH/tob/logs/`. Scripts are resume-safe where
possible (output-exists check before running). Do not advance to each next step until Heath
has reviewed outputs per the SCARAB Quality Gate Policy.
