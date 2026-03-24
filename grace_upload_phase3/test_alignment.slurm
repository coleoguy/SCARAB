#!/bin/bash
# ============================================================================
# test_alignment.slurm — Test Cactus on 5 small beetle genomes
# ============================================================================
#
# Validates the pipeline before committing 200K SUs to the full alignment.
# Selects 5 small genomes, builds a mini seqFile, runs Cactus, checks output.
#
# Queue: medium (1 day limit; short queue is only 2 hrs)
# Resources: 1 node, 48 cores, 384 GB RAM
# Expected runtime: ~30-90 min
#
# Usage:
#   sbatch test_alignment.slurm
# ============================================================================

#SBATCH --job-name=scarab_test
#SBATCH --partition=medium
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=360G
#SBATCH --output=scarab_test_%j.log
#SBATCH --error=scarab_test_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
CONTAINER="${PROJECT_DIR}/cactus_v2.9.3.sif"
FULL_SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"

TEST_DIR="${PROJECT_DIR}/work/test_alignment"
TEST_SEQFILE="${TEST_DIR}/test_seqfile.txt"
TEST_JOBSTORE="${TEST_DIR}/jobstore"
TEST_HAL="${TEST_DIR}/test_alignment.hal"

SING="singularity exec --cleanenv \
  -B ${PROJECT_DIR}:${PROJECT_DIR} \
  -B /tmp:/tmp \
  ${CONTAINER}"

# ============================================================================
# SETUP
# ============================================================================

echo "============================================================"
echo "SCARAB — Test Alignment"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${SLURM_CPUS_PER_TASK:-48}"
echo "============================================================"
echo ""

# Clean previous test
rm -rf "${TEST_DIR}"
mkdir -p "${TEST_DIR}"

# ============================================================================
# SELECT 5 SMALL GENOMES
# ============================================================================

echo "[1/4] Selecting 5 small test genomes..."

# Get all genome entries from seqFile (skip tree line)
# Pick 5 with smallest FASTA files for speed
# We want taxonomic diversity: pick from different families if possible

# Strategy: find the 5 smallest .fna files across all genomes, then
# match them to seqFile entries
declare -A SIZE_MAP
while IFS=' ' read -r tip_label fasta_path; do
    [ -z "$fasta_path" ] && continue
    [ ! -f "$fasta_path" ] && continue
    size=$(stat --printf='%s' "$fasta_path" 2>/dev/null || echo "999999999999")
    SIZE_MAP["$tip_label"]="$size $fasta_path"
done < <(tail -n +2 "$FULL_SEQFILE")

# Sort by size, take 5 smallest
# NOTE: pipe through head causes SIGPIPE on sort under pipefail — write to tmpfile instead
TMPSELECT=$(mktemp)
for tip in "${!SIZE_MAP[@]}"; do
    echo "${SIZE_MAP[$tip]} $tip"
done | sort -n > "$TMPSELECT"
SELECTED=$(head -5 "$TMPSELECT")
rm -f "$TMPSELECT"

echo "Selected genomes:"
echo "$SELECTED" | while read size path tip; do
    size_mb=$((size / 1048576))
    echo "  ${tip}: ${size_mb} MB"
done
echo ""

# ============================================================================
# BUILD MINI SEQFILE
# ============================================================================

echo "[2/4] Building test seqFile (with pruned tree)..."

# Collect selected tip names into a file
TIPFILE=$(mktemp)
echo "$SELECTED" | while read size path tip; do
    echo "$tip"
done > "$TIPFILE"

# Prune the full tree to just the selected tips using Python
# IMPORTANT: Cactus requires a BINARY (bifurcating) tree — no multifurcations.
# We build a ladder tree: ((((A,B):bl,C):bl,D):bl,E):bl
FULL_TREE=$(head -1 "$FULL_SEQFILE")
PRUNED_TREE=$(python3 - "$FULL_TREE" "$TIPFILE" << 'PYEOF'
import sys, re

tree_str = sys.argv[1]
with open(sys.argv[2]) as f:
    keep = [line.strip() for line in f if line.strip()]

# Extract branch lengths for kept tips from the full tree
tip_bls = {}
for tip in keep:
    m = re.search(re.escape(tip) + r':([0-9.eE+-]+)', tree_str)
    tip_bls[tip] = m.group(1) if m else '0.1'

# Build a BINARY ladder tree: ((((A:bl,B:bl):int,C:bl):int,D:bl):int,E:bl)
# Internal branch lengths set to average of adjacent tip branches
if len(keep) == 1:
    pruned = f'{keep[0]}:{tip_bls[keep[0]]};'
elif len(keep) == 2:
    pruned = f'({keep[0]}:{tip_bls[keep[0]]},{keep[1]}:{tip_bls[keep[1]]});'
else:
    # Start with first two as a cherry
    result = f'({keep[0]}:{tip_bls[keep[0]]},{keep[1]}:{tip_bls[keep[1]]})'
    # Ladder on remaining tips
    for i in range(2, len(keep)):
        int_bl = '0.01'  # short internal branch
        result = f'({result}:{int_bl},{keep[i]}:{tip_bls[keep[i]]})'
    pruned = result + ';'

print(pruned)
PYEOF
)
rm -f "$TIPFILE"

echo "  Pruned tree: ${PRUNED_TREE}"

# Write pruned tree + selected genome paths
echo "$PRUNED_TREE" > "${TEST_SEQFILE}"
echo "$SELECTED" | while read size path tip; do
    echo "${tip} ${path}" >> "${TEST_SEQFILE}"
done

NTEST=$(tail -n +2 "${TEST_SEQFILE}" | grep -c . || true)
echo "  Test seqFile: ${NTEST} genomes"
echo ""

# ============================================================================
# RUN CACTUS
# ============================================================================

echo "[3/4] Running Cactus test alignment..."
echo "  seqFile: ${TEST_SEQFILE}"
echo "  jobStore: ${TEST_JOBSTORE}"
echo "  output: ${TEST_HAL}"
echo ""

${SING} cactus \
    "${TEST_JOBSTORE}" \
    "${TEST_SEQFILE}" \
    "${TEST_HAL}" \
    --maxCores ${SLURM_CPUS_PER_TASK:-48} \
    --maxMemory ${SLURM_MEM_PER_NODE:-360000}M \
    2>&1 && CACTUS_EXIT=0 || CACTUS_EXIT=$?

echo ""
echo "Cactus exit code: ${CACTUS_EXIT}"
echo ""

# ============================================================================
# VALIDATE
# ============================================================================

echo "[4/4] Validating output..."

if [ $CACTUS_EXIT -ne 0 ]; then
    echo "FAILED: Cactus returned exit code ${CACTUS_EXIT}"
    echo "Check log above for errors."
    exit 1
fi

if [ ! -f "${TEST_HAL}" ]; then
    echo "FAILED: HAL file not produced"
    exit 1
fi

HAL_SIZE=$(stat --printf='%s' "${TEST_HAL}")
echo "HAL file size: ${HAL_SIZE} bytes ($((HAL_SIZE / 1048576)) MB)"

# Run halStats
echo ""
echo "halStats output:"
${SING} halStats "${TEST_HAL}" 2>&1 || echo "WARNING: halStats failed"

echo ""
echo "============================================================"
echo "TEST PASSED"
echo "============================================================"
echo ""
echo "HAL file: ${TEST_HAL}"
echo "Size: $((HAL_SIZE / 1048576)) MB"
echo ""
echo "The pipeline works. You can now submit the full alignment:"
echo "  sbatch run_full_alignment.slurm"
echo ""
echo "Finished: $(date)"
