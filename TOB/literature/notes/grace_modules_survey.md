# Grace Module Survey — TOB Phase 1 Tool Stack

Survey date: 2026-05-03  
Surveyed by: Claude Code (claude-sonnet-4-6)  
Method: `module spider <tool>` on login node; load-tested key tools

---

## Tool-by-Tool Status

### BUSCO
- **Status**: AVAILABLE (module)
- **Versions**: 5.7.1, 6.0.0
- **Recommended**: 5.7.1 (insecta_odb10 compatibility; 6.0.0 is a candidate but untested against existing dbs)
- **module load**: `module load GCC/12.2.0 OpenMPI/4.1.4 BUSCO/5.7.1`
- **Dependency chain**: GCC/12.2.0, OpenMPI/4.1.4
- **Confirmed**: `busco --version` → `BUSCO 5.7.1`
- **Notes**: BUSCO 6.0.0 available via `GCC/12.3.0 OpenMPI/4.1.5`; stick with 5.7.1 for odb10 compatibility until tested

### MAFFT
- **Status**: AVAILABLE (module)
- **Versions**: 7.505, 7.520, 7.526
- **Recommended**: 7.520 (matches existing SCARAB scripts); 7.526 is available if needed
- **module load**: `module load GCC/12.3.0 MAFFT/7.520-with-extensions`
- **Dependency chain**: GCC/12.3.0
- **Notes**: 7.526 uses GCC/13.2.0 — a different toolchain from the IQ-TREE stack; use 7.520 to stay on GCC/12.3.0

### TrimAl
- **Status**: AVAILABLE (module)
- **Version**: 1.4.1 (rev15, built 2013-12-17) — only version present
- **module load**: `module load GCCcore/12.3.0 trimAl/1.4.1`
- **Dependency chain**: GCCcore/11.3.0 OR GCCcore/12.3.0
- **Confirmed**: `trimal --version` → `trimAl v1.4.rev15 build[2013-12-17]`
- **Notes**: Lmod description erroneously says "EVB, FEP and LIE simulator" — that is a metadata bug in the module file; the binary is the correct trimAl. Use GCCcore/12.3.0 to align with the rest of Phase 1 stack.

### IQ-TREE
- **Status**: AVAILABLE (module)
- **Versions**: 1.6.12, 2.2.2.3, 2.3.5, 2.3.6
- **Recommended**: 2.3.6
- **module load**: `module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6`
- **Dependency chain**: GCC/12.3.0, OpenMPI/4.1.5
- **Notes**: Also loadable with GCC/13.2.0 OpenMPI/4.1.6; GCC/12.3.0 stack preferred for toolchain consistency. GHOST-tree feature is built into IQ-TREE 2.x (`-m GHOST`) — not a separate tool.

### ASTER (includes wASTRAL, ASTRAL, ASTRAL-Pro, CASTER)
- **Status**: AVAILABLE (module)
- **Version**: 1.20.4
- **module load**: `module load ASTER/1.20.4`
- **Dependency chain**: none (loads directly)
- **Confirmed binaries**: `astral`, `astral4`, `astral-pro`, `astral-pro3`, `wastral`, `waster-site`, `caster-pair`, `caster-site`, `astral-hybrid`
- **Install path**: `/sw/hprc/sw/bio/ASTER/1.20.4/bin/`
- **Notes**: ASTER supersedes standalone ASTRAL-III; `wastral` is the weighted ASTRAL variant used in the existing SCARAB wASTRAL species tree. No Java required — ASTER is a native C++ reimplementation.

### Java / OpenJDK
- **Status**: AVAILABLE (module) — but NOT needed for ASTER
- **Versions**: 1.8.0_292-OpenJDK, 11.0.2, 11.0.20, 11.0.27, 17.0.4, 17.0.6, 21.0.2
- **module load**: `module load Java/21.0.2` (loads directly, no deps)
- **Notes**: Only needed if using a legacy ASTRAL .jar. The ASTER module replaces that use case.

### treePL
- **Status**: NOT INSTALLED as a loadable module
- **EasyBuild recipe exists**: `/sw/eb/ebfiles_repo/ada/treePL/treePL-1.0-gompi-2020a.eb` (recipe only, not built for current Grace stack)
- **Install path**: not present under `/sw/hprc/sw/`
- **module load**: N/A
- **Alternative available**: PAML 4.10.7 (`GCCcore/13.2.0 PAML/4.10.7`) includes `mcmctree` for Bayesian divergence dating. MCMCtree is a common alternative to treePL for large trees.
- **Install options**:
  1. Request HPRC staff build it (EasyBuild recipe already written by TAMU staff)
  2. Conda install in a dedicated env (`conda install -c bioconda treepl`)
  3. Compile from source (`github.com/blackrim/treePL`) in `$SCRATCH`

### BaCoCa
- **Status**: NOT INSTALLED (no module, not found in `/sw`)
- **module load**: N/A
- **Notes**: BaCoCa is an R script, not a compiled binary. Install route: download `BaCoCa.R` from GitHub (n-gontier/BaCoCa or similar fork), place in `$SCRATCH/scarab/tools/`. Requires R with `ape` and `seqinr`. Grace has R/4.4.2 via `GCC/13.3.0 R/4.4.2`.

### GHOST
- **Status**: NOT a separate tool — built into IQ-TREE 2.x
- **Usage**: `iqtree2 -m GHOST+... ` or specify GHOST subtree models inline
- **No separate install needed**

### Python 3.7+
- **Status**: AVAILABLE (module) — many versions above 3.6
- **Versions available**: 3.8.6, 3.9.5, 3.9.6, 3.10.4, 3.10.8, 3.11.3, 3.11.5, 3.12.3, 3.13.1, 3.13.5
- **Recommended**: 3.11.5 (stable, well-supported)
- **module load**: `module load GCCcore/13.2.0 Python/3.11.5`
- **Dependency chain**: GCCcore/13.2.0
- **Notes**: System default on Grace login node is 3.6 — always load a module explicitly. BUSCO 5.7.1 bundles its own Python; standalone Python module needed for custom scripts.

### Conda / Anaconda
- **Status**: AVAILABLE (module)
- **Versions**:
  - Anaconda3: 2021.05, 2021.11, 2023.09-0, 2024.02-1
  - Miniconda3: 4.9.2, 4.12.0, 22.11.1-1, 23.5.2-0, 23.9.0-0, 23.10.0-1, 24.11.1
- **Recommended**: `module load Miniconda3/24.11.1` (loads directly, no deps)
- **Notes**: After loading, use `conda create -n <env>` in `$SCRATCH` to avoid home-dir quota issues. Set `conda config --set env_prompt ({name})` to avoid long prompts in SLURM logs.

### HMMER
- **Status**: AVAILABLE (module) — BUSCO dependency
- **Versions**: 3.3.2, 3.4, 3.4-ips5
- **Recommended**: 3.4 (matches GCC/12.3.0 stack)
- **module load**: `module load GCC/12.3.0 OpenMPI/4.1.5 HMMER/3.4`
- **Dependency chain**: GCC/12.3.0, OpenMPI/4.1.5
- **Notes**: BUSCO/5.7.1 loads HMMER internally via its own bundled call; no need to load HMMER separately unless running hmmsearch/hmmbuild standalone.

### BLAST+ 2.14.0
- **Status**: AVAILABLE (module) — confirmed
- **Versions**: 2.13.0, 2.14.0, 2.14.1, 2.16.0
- **module load**: `module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0`
- **Dependency chain**: GCC/12.2.0, OpenMPI/4.1.4
- **Notes**: Matches existing SCARAB CLAUDE.md recipe exactly. 2.16.0 also available if needed.

### AUGUSTUS
- **Status**: AVAILABLE (module) — BUSCO genome-mode dep
- **Version**: 3.5.0 (only version)
- **module load**: `module load GCC/12.2.0 OpenMPI/4.1.4 AUGUSTUS/3.5.0`
- **Dependency chain**: GCC/12.2.0, OpenMPI/4.1.4 (or GCC/12.3.0 OpenMPI/4.1.5)
- **Notes**: Required only if running BUSCO in `--mode genome` with AUGUSTUS gene prediction. For protein-mode BUSCO (Phase 1 use case), not needed.

### MetaEuk
- **Status**: AVAILABLE (module) — alternative BUSCO genome-mode dep
- **Version**: 6 (only version)
- **module load**: `module load GCC/12.3.0 MetaEuk/6`
- **Dependency chain**: GCC/12.2.0 or GCC/12.3.0
- **Notes**: MetaEuk is the recommended alternative to AUGUSTUS in BUSCO ≥5.4 for genome mode. BUSCO 5.7.1 auto-detects it if loaded. Not needed for protein-mode.

---

## Summary Table

| Tool | Status | Version | Needs Install? |
|------|--------|---------|---------------|
| BUSCO | Module | 5.7.1, 6.0.0 | No |
| MAFFT | Module | 7.505 / 7.520 / 7.526 | No |
| TrimAl | Module | 1.4.1 | No |
| IQ-TREE | Module | 2.3.6 | No |
| ASTER/wASTRAL | Module | 1.20.4 | No |
| Java | Module | 8 / 11 / 17 / 21 | No (not needed) |
| treePL | **NOT INSTALLED** | — | **YES** |
| BaCoCa | **NOT INSTALLED** | — | **YES (R script)** |
| GHOST | Built into IQ-TREE | N/A | No |
| Python 3.7+ | Module | 3.8–3.13 | No |
| Conda | Module | Miniconda3/24.11.1 | No |
| HMMER | Module | 3.4 | No |
| BLAST+ 2.14.0 | Module | 2.14.0 | No |
| AUGUSTUS | Module | 3.5.0 | No |
| MetaEuk | Module | 6 | No |

---

## Tools Needing Install

### 1. treePL
- **Route A (preferred)**: Ask HPRC to build the existing EasyBuild recipe (`treePL-1.0-gompi-2020a.eb` is already in the repo at `/sw/eb/ebfiles_repo/ada/treePL/`). Email hprc@tamu.edu referencing that path.
- **Route B**: Conda env — `module load Miniconda3/24.11.1 && conda create -n treepl -c bioconda treepl -y`
- **Route C**: Compile from source into `$SCRATCH/scarab/tools/treePL/`
- **Dependencies**: NLopt, ADOL-C (both in the EasyBuild recipe)

### 2. BaCoCa
- **Route**: Download R script from GitHub, place in `$SCRATCH/scarab/tools/BaCoCa.R`
- **R deps**: `ape`, `seqinr` — install via `module load GCC/13.3.0 R/4.4.2` + `R -e "install.packages(c('ape','seqinr'), repos='...')" `
- **No module request needed** — it is an R script, not a compiled binary

---

## Phase 1 Canonical Module-Load Recipe

Use this block at the top of every Phase 1 SLURM script. Activate only the sections relevant to the specific job step to avoid module conflicts.

```bash
#!/bin/bash
#SBATCH ...

# ---------------------------------------------------------------
# TOB Phase 1 — canonical module block (2026-05-03)
# Load ONLY the section(s) needed for this job step.
# Do NOT load all sections simultaneously — GCC versions conflict.
# ---------------------------------------------------------------

# --- BUSCO (genome or protein mode) ----------------------------
# module load GCC/12.2.0 OpenMPI/4.1.4 BUSCO/5.7.1
# Includes: HMMER, MetaEuk, AUGUSTUS accessible via separate loads

# --- BLAST+ (tBLASTn, marker search) ---------------------------
# module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

# --- MAFFT (MSA) + TrimAl (trim) + IQ-TREE (gene trees) --------
# module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6
# module load GCC/12.3.0 MAFFT/7.520-with-extensions
# module load GCCcore/12.3.0 trimAl/1.4.1
# NOTE: MAFFT and trimAl load with GCCcore/12.3.0 subordinate
#       to GCC/12.3.0 — load IQ-TREE first, then MAFFT, trimAl.

# --- ASTER / wASTRAL (species tree) ----------------------------
# module load ASTER/1.20.4
# Provides: astral, wastral, astral-pro, caster-pair, caster-site

# --- Python 3.11 (custom scripts) ------------------------------
# module load GCCcore/13.2.0 Python/3.11.5
# NOTE: use a separate job step / script if mixing with GCC/12.x tools

# --- Conda (BaCoCa env, treePL env) ----------------------------
# module load Miniconda3/24.11.1
# conda activate treepl    # after env is created

# --- R (BaCoCa, summary stats) ---------------------------------
# module purge && module load GCC/13.3.0 R/4.4.2

# --- AUGUSTUS or MetaEuk (BUSCO genome mode only) --------------
# module load GCC/12.2.0 OpenMPI/4.1.4 AUGUSTUS/3.5.0
# module load GCC/12.3.0 MetaEuk/6
# ---------------------------------------------------------------
```

### Recommended combined load for the core MSA→gene-tree step

```bash
module purge
module load GCC/12.3.0 OpenMPI/4.1.5 IQ-TREE/2.3.6
module load GCC/12.3.0 MAFFT/7.520-with-extensions
module load GCCcore/12.3.0 trimAl/1.4.1
```

### Recommended load for species-tree step

```bash
module purge
module load ASTER/1.20.4
```

### Recommended load for BUSCO + BLAST step

```bash
module purge
module load GCC/12.2.0 OpenMPI/4.1.4 BUSCO/5.7.1
# or for BLAST alone:
module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0
```

---

## Licensing / Quota Notes

- No tools in this stack require a separate license module load on Grace.
- AUGUSTUS requires species-specific parameter directories; the default Grace install at `/sw/hprc/sw/bio/AUGUSTUS/3.5.0/config/species/` may lack custom beetle models — verify before use.
- Conda envs created under `$HOME` count against home-dir quota (20 GB). Always create envs in `$SCRATCH`: `conda create -p /scratch/user/blackmon/scarab/conda_envs/<name>`.
- BUSCO downloads databases to `$HOME/.busco` by default; override with `--download_path $SCRATCH/scarab/busco_downloads/`.
