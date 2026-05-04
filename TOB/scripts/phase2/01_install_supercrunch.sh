#!/bin/bash
# ==============================================================================
# 01_install_supercrunch.sh — Install SuperCRUNCH on Grace (login node)
# ==============================================================================
# Run ONCE on the Grace login node. Requires internet access.
# Creates a conda env at $SCRATCH/tob/envs/supercrunch with all deps
# (BLAST+, MAFFT, trimAl) installed via bioconda to avoid GCC toolchain
# conflicts between Grace modules.
#
# Usage:
#   bash 01_install_supercrunch.sh
# ==============================================================================

set -euo pipefail

SCRATCH_TOB="${SCRATCH}/tob"
ENV_PATH="${SCRATCH_TOB}/envs/supercrunch"
SC_DIR="${SCRATCH_TOB}/SuperCRUNCH"

echo "TOB Phase 2 — SuperCRUNCH install"
echo "Target env: ${ENV_PATH}"
echo "SuperCRUNCH dir: ${SC_DIR}"
echo ""

# Load Anaconda
module purge
module load Anaconda3/2024.02-1

# Create base dirs
mkdir -p "${SCRATCH_TOB}/data"
mkdir -p "${SCRATCH_TOB}/envs"
mkdir -p "${SCRATCH_TOB}/logs"

# ----------------------------------------------------------------------------
# Create conda environment (fully bioconda-managed to avoid GCC conflicts)
# ----------------------------------------------------------------------------
if [ -d "${ENV_PATH}" ]; then
    echo "Conda env already exists at ${ENV_PATH}. Skipping creation."
else
    echo "Creating conda env..."
    conda create -p "${ENV_PATH}" \
        python=3.11 \
        biopython numpy pandas \
        -c bioconda -c conda-forge \
        blast mafft trimal \
        -y
    echo "Conda env created."
fi

# Activate
source activate "${ENV_PATH}"

# ----------------------------------------------------------------------------
# Clone SuperCRUNCH from GitHub
# ----------------------------------------------------------------------------
if [ -d "${SC_DIR}" ]; then
    echo "SuperCRUNCH already cloned. Pulling latest..."
    cd "${SC_DIR}"
    git pull
else
    echo "Cloning SuperCRUNCH..."
    cd "${SCRATCH_TOB}"
    git clone https://github.com/dportik/SuperCRUNCH.git
fi

# Install editable (so scripts are importable and entry points resolve)
cd "${SC_DIR}"
pip install -e . --quiet

SC_VER=$(git log --oneline -1)
echo "SuperCRUNCH version: ${SC_VER}"

# ----------------------------------------------------------------------------
# Smoke test
# ----------------------------------------------------------------------------
echo ""
echo "Running smoke tests..."

SC_SCRIPTS="${SC_DIR}/supercrunch/scripts"

python "${SC_SCRIPTS}/Parse_Loci.py" --help > /dev/null 2>&1 \
    && echo "  Parse_Loci.py: OK" \
    || echo "  Parse_Loci.py: FAILED"

python "${SC_SCRIPTS}/Cluster_Blast_Extract.py" --help > /dev/null 2>&1 \
    && echo "  Cluster_Blast_Extract.py: OK" \
    || echo "  Cluster_Blast_Extract.py: FAILED"

python "${SC_SCRIPTS}/Taxa_Assessment.py" --help > /dev/null 2>&1 \
    && echo "  Taxa_Assessment.py: OK" \
    || echo "  Taxa_Assessment.py: FAILED"

python -c "from Bio import SeqIO; print('  Biopython: OK')"

blastn -version 2>&1 | head -1 | sed 's/^/  BLAST+: /'
mafft --version 2>&1 | head -1 | sed 's/^/  MAFFT: /'
trimal --version 2>&1 | head -1 | sed 's/^/  trimAl: /'

echo ""
echo "Install complete. SuperCRUNCH scripts path:"
echo "  ${SC_SCRIPTS}"
echo ""
echo "In SLURM scripts, activate with:"
echo "  module load Anaconda3/2024.02-1"
echo "  source activate ${ENV_PATH}"
