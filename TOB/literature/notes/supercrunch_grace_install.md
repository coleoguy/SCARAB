# SuperCRUNCH on Grace — Install Plan

**Reference:** Portik & Wiens (2020) MEE 11:763  
**GitHub:** https://github.com/dportik/SuperCRUNCH  
**Checked:** 2026-05-03

---

## 1. Availability Summary

SuperCRUNCH is **not installed** on Grace as a module.

| Check | Result |
|-------|--------|
| `module spider supercrunch` | "Unable to find: supercrunch" |
| `module avail supercrunch` | No modules found |
| conda (bioconda, defaults) | PackagesNotFoundError |
| PyPI (`pip install supercrunch`) | No matching distribution |

SuperCRUNCH is distributed **only via GitHub** (clone + pip install -e or direct script invocation). The install path is: **Conda env + pip install from GitHub clone**.

---

## 2. Dependencies — Grace Coverage

| Dependency | Required | Grace module | Notes |
|-----------|----------|--------------|-------|
| Python | ≥3.7 | `Anaconda3/2024.02-1` → Python 3.11.7; or `GCC/13.3.0 Python/3.12.3` | Both confirmed available |
| Biopython | ≥1.70 | `GCC/13.3.0 Biopython/1.84` as module; or `pip install biopython` in conda env | Module path confirmed |
| BLAST+ (blastn, makeblastdb, tblastn) | required | `GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0` | Already used in SCARAB |
| MAFFT | required | `GCC/12.3.0 MAFFT/7.520-with-extensions` | Already used in SCARAB |
| trimAl | required | `GCCcore/12.3.0 trimAl/1.4.1` | Module confirmed; v1.4.rev15 |
| GBlocks | optional (alternative to trimAl) | **Not on Grace** | Not needed if trimAl is used |
| numpy, pandas | indirect | included in Anaconda3 base; or conda install | Standard packages |

**BLAST+ note:** BLAST+/2.14.0 requires `GCC/12.2.0 OpenMPI/4.1.4`. MAFFT/7.520 requires `GCC/12.3.0`. These use different GCC toolchains — load them in **separate job steps** or use the module `BLAST+/2.16.0` (check prereqs) for possible compatibility. Safest approach: load BLAST+ in the BLAST step, reload MAFFT for the alignment step, load trimAl for the trimming step (Grace supports `module purge` + reload between pipeline stages).

**GBlocks:** Not available on Grace. Not needed; SuperCRUNCH supports trimAl as the trimming backend and that is the preferred option anyway.

---

## 3. Recommended Install Command Sequence

Run the following **once on the login node** (internet access required). This creates a persistent conda env at `$SCRATCH`.

```bash
# Step 1: Load Anaconda
module load Anaconda3/2024.02-1

# Step 2: Create conda env in scratch (keeps it off home quota)
conda create -p /scratch/user/blackmon/tob/envs/supercrunch \
    python=3.11 biopython numpy pandas -y

# Step 3: Activate
conda activate /scratch/user/blackmon/tob/envs/supercrunch

# Step 4: Clone SuperCRUNCH to scratch
cd /scratch/user/blackmon/tob/
git clone https://github.com/dportik/SuperCRUNCH.git

# Step 5: Install (editable so scripts are importable)
cd SuperCRUNCH
pip install -e .
```

**In SLURM job scripts**, the module preamble for a SuperCRUNCH job looks like:

```bash
#!/bin/bash
#SBATCH --partition=medium
#SBATCH --time=1-00:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G

module purge
module load Anaconda3/2024.02-1
conda activate /scratch/user/blackmon/tob/envs/supercrunch

# Load BLAST+ for steps that call blastn/tblastn
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

# Load MAFFT for alignment steps (different GCC; load after BLAST step)
# module load GCC/12.3.0 MAFFT/7.520-with-extensions

# Load trimAl for trimming steps
# module load GCCcore/12.3.0 trimAl/1.4.1

SUPERCRUNCH=/scratch/user/blackmon/tob/SuperCRUNCH/supercrunch/scripts
```

**Toolchain conflict mitigation:** Because BLAST+ (GCC/12.2.0) and MAFFT (GCC/12.3.0) use different compiler modules, wrap each SuperCRUNCH stage in its own `srun` or sub-script with `module purge` + correct load, or use the Anaconda-packaged versions of both (`conda install -c bioconda blast mafft` in the env) to sidestep the conflict entirely. The Anaconda route is simpler for a pure-conda pipeline.

### Alternative: fully Conda-managed deps (avoids toolchain conflicts)

```bash
conda create -p /scratch/user/blackmon/tob/envs/supercrunch \
    python=3.11 biopython numpy pandas \
    -c bioconda -c conda-forge \
    blast mafft trimal -y
```

This installs BLAST+ (~2.14), MAFFT, and trimAl entirely inside the conda env — no Grace module loading needed for those tools. Cleaner for scripting.

---

## 4. Smoke Test Plan (~5 minutes)

After install, run the following on a login node (light workload, acceptable for testing):

```bash
module load Anaconda3/2024.02-1
conda activate /scratch/user/blackmon/tob/envs/supercrunch

# 4a. Check SuperCRUNCH entry points resolve
python /scratch/user/blackmon/tob/SuperCRUNCH/supercrunch/scripts/Parse_Loci.py --help
python /scratch/user/blackmon/tob/SuperCRUNCH/supercrunch/scripts/Cluster_Blast_Extract.py --help

# 4b. Check Biopython import
python -c "from Bio import SeqIO; print('Biopython OK')"

# 4c. Check BLAST+ in PATH (if loaded via module or conda)
blastn -version
makeblastdb -version

# 4d. Check MAFFT
mafft --version

# 4e. Check trimAl
trimal --version

# 4f. Minimal end-to-end: parse a small multi-FASTA
# Requires a test FASTA + locus list; use any 10-seq subset from TOB GenBank pulls
# python Parse_Loci.py -i test.fasta -l loci.txt -o test_out/ --onlyinclude
```

Expected: all `--help` flags print usage without ImportError. BLAST/MAFFT/trimAl version lines confirm dep resolution.

---

## Notes

- SuperCRUNCH v1.3.2 is the current release as of knowledge cutoff; confirm version after clone with `git log --oneline -1`.
- Grace compute nodes have no internet; the clone must happen on the login node, then the installed env persists on `$SCRATCH`.
- The conda env path (`-p /scratch/...`) rather than a named env avoids home-directory quota issues.
- GBlocks is absent from Grace but is not required; trimAl is SuperCRUNCH's recommended trimmer.
