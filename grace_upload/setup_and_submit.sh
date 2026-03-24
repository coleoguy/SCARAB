#!/bin/bash
#
# setup_and_submit.sh
# ============================================================================
# DEPRECATED — The SLURM download approach does not work on Grace because
# compute nodes have no internet access (curl exit code 7).
#
# USE INSTEAD:
#   nohup bash $SCRATCH/scarab/scripts/download_login.sh \
#       > $SCRATCH/scarab/scripts/download_output.log 2>&1 &
#
# This script is kept for reference only.
# ============================================================================
#
# Original purpose: Create directory structure, check datasets CLI, submit
# download_genomes.slurm as a SLURM array job.
#
# Usage:  bash setup_and_submit.sh
#

set -e

echo ""
echo "========================================="
echo "  SCARAB — Grace Setup & Download Submit"
echo "========================================="
echo ""

# Where are we?
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Step 1: Create directories
# ---------------------------------------------------------------------------

echo "[1/4] Creating directories..."
mkdir -p "${SCRATCH}/scarab/genomes"
mkdir -p "${SCRIPT_DIR}/logs"
echo "  Genome dir: ${SCRATCH}/scarab/genomes"
echo "  Log dir:    ${SCRIPT_DIR}/logs"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Verify accession file is here
# ---------------------------------------------------------------------------

echo "[2/4] Checking accession file..."
if [ ! -f "${SCRIPT_DIR}/accessions_to_download.txt" ]; then
    echo "  ERROR: accessions_to_download.txt not found in ${SCRIPT_DIR}"
    echo "  Make sure you uploaded it alongside this script."
    exit 1
fi
NUM_ACC=$(wc -l < "${SCRIPT_DIR}/accessions_to_download.txt")
echo "  Found ${NUM_ACC} accessions. OK."
echo ""

# ---------------------------------------------------------------------------
# Step 3: Check for NCBI datasets CLI
# ---------------------------------------------------------------------------

echo "[3/4] Checking for NCBI datasets CLI..."

# Try loading common module names
module load NCBI-Datasets-CLI 2>/dev/null || \
module load ncbi-datasets-cli 2>/dev/null || \
module load ncbi_datasets 2>/dev/null || true

if command -v datasets &> /dev/null; then
    echo "  datasets CLI found: $(which datasets)"
    datasets --version 2>/dev/null || true
    echo ""
else
    echo ""
    echo "  WARNING: 'datasets' command not found."
    echo "  The download script has a curl fallback, so it will still work."
    echo "  But the datasets CLI is faster and more reliable."
    echo ""
    echo "  To install it (optional), run:"
    echo "    conda install -c conda-forge ncbi-datasets-cli"
    echo ""
    read -p "  Continue anyway? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "  Aborting. Install datasets CLI and re-run."
        exit 1
    fi
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 4: Submit the SLURM job
# ---------------------------------------------------------------------------

echo "[4/4] Submitting download job..."
cd "${SCRIPT_DIR}"
JOB_ID=$(sbatch --parsable download_genomes.slurm)

echo ""
echo "========================================="
echo "  SUBMITTED! Job ID: ${JOB_ID}"
echo "========================================="
echo ""
echo "  438 genomes, 20 downloading at a time."
echo "  Expected time: ~20-25 hours."
echo ""
echo "  Useful commands:"
echo "    squeue -u \$USER              # check job status"
echo "    tail -f logs/download_*.out   # watch live progress"
echo "    sacct -j ${JOB_ID} --format=JobID,State,ExitCode  # check when done"
echo ""
echo "  When all jobs finish, run:"
echo "    bash ${SCRIPT_DIR}/validate_downloads.sh"
echo ""
