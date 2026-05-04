#!/bin/bash
# TOB / Phase 5 prep — install treePL on Grace via Conda.
# One-time setup. Verified working 2026-05-03 23:25 CDT.
#
# Why this is non-trivial:
#   - treePL is NOT in bioconda (despite what some references claim).
#   - The genomedk Anaconda channel provides treepl-2.6.3.
#   - genomedk's package puts the binary at the env ROOT, not in bin/.
#   - genomedk's recipe pulls nlopt (latest, currently 2.10.1), but
#     treePL was compiled against the older libnlopt.so.0 ABI which
#     ships with nlopt < 2.8 (e.g. 2.7.1).
#
# Final verified recipe below.
set -euo pipefail

ENV_NAME="tob-treepl"

module purge
module load Anaconda3/2024.02-1
source "$EBROOTANACONDA3/etc/profile.d/conda.sh"

# Idempotent: if env exists, remove first.
if conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
    echo "Removing existing $ENV_NAME env to start clean..."
    conda env remove -y -n "$ENV_NAME"
fi

# Create env. Pin nlopt<2.8 so we get libnlopt.so.0 (treePL requires it).
echo "Creating $ENV_NAME with treepl + nlopt<2.8..."
conda create -y -n "$ENV_NAME" \
    -c genomedk -c conda-forge \
    treepl "nlopt<2.8"

# genomedk's package installs the binary at the env ROOT instead of bin/.
# Symlink so it's on PATH when the env is activated.
ENV_PREFIX="$(conda env list | awk -v n="$ENV_NAME" '$1==n {print $NF}')"
if [ -x "$ENV_PREFIX/treePL" ] && [ ! -e "$ENV_PREFIX/bin/treePL" ]; then
    ln -sf "$ENV_PREFIX/treePL" "$ENV_PREFIX/bin/treePL"
    echo "Symlinked $ENV_PREFIX/treePL into bin/."
fi

# Smoke test.
conda activate "$ENV_NAME"
echo ""
echo "treePL version test:"
treePL 2>&1 | head -2
echo ""
echo "Install complete. Activate with:"
echo "  module load Anaconda3/2024.02-1"
echo "  source \$EBROOTANACONDA3/etc/profile.d/conda.sh"
echo "  conda activate $ENV_NAME"
