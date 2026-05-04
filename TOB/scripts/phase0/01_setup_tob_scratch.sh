#!/bin/bash
# TOB Phase 0 / Step 1 — set up working dir on Grace + install NCBI Datasets CLI.
# Run on Grace LOGIN NODE (needs internet to fetch the datasets binary).
set -euo pipefail

TOB_ROOT="/scratch/user/blackmon/tob"
LOG="$TOB_ROOT/logs/01_setup_tob_scratch_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$TOB_ROOT"/{genomes,transcriptomes,sphaerius/reads,sphaerius/assemblies,outgroups/hymenoptera,orthologs,alignments,trees,logs,scripts}
echo "[$(date)] TOB scratch tree:" | tee "$LOG"
ls -la "$TOB_ROOT" | tee -a "$LOG"

# Install NCBI Datasets CLI to ~/bin if not already on PATH.
mkdir -p "$HOME/bin"
if ! command -v datasets >/dev/null 2>&1 && [ ! -x "$HOME/bin/datasets" ]; then
    echo "[$(date)] Installing NCBI Datasets CLI to ~/bin/" | tee -a "$LOG"
    curl -sLo "$HOME/bin/datasets"   'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets'
    curl -sLo "$HOME/bin/dataformat" 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/dataformat'
    chmod +x "$HOME/bin/datasets" "$HOME/bin/dataformat"
fi

# Add ~/bin to PATH for this session if not already there.
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ; echo "Note: add 'export PATH=\$HOME/bin:\$PATH' to ~/.bashrc to persist." | tee -a "$LOG" ;;
esac

echo "[$(date)] datasets version:" | tee -a "$LOG"
"$HOME/bin/datasets" --version | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "[$(date)] Phase 0 / Step 1 complete." | tee -a "$LOG"
