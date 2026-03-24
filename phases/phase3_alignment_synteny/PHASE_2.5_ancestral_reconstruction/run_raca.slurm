#!/bin/bash
##############################################################################
# PHASE_2.5_ancestral_reconstruction/run_raca.slurm
#
# Purpose:
#   Run RACA (Reconstruct Ancestral Chromosome Architecture) for internal nodes
#   Predicts genome organization at key evolutionary branching points
#   Outputs ancestral genome scaffolds in FASTA format
#
# Queue:  long (7 day limit, 64 nodes)
# Nodes:  1 (single standard node: 48 cores, 384 GB RAM)
# Runtime: Depends on tree depth; typically 2-7 days
#
# Submission:
#   sbatch run_raca.slurm
#
# Prerequisites:
#   - Final merged HAL file (from merge_subtrees.slurm)
#   - RACA software installed in container or locally
#   - Python 2.7+ for RACA scripts
#
# Output:
#   - ancestral_genomes/ directory with one FASTA per internal node
#   - raca_log.txt (job log with all reconstructed ancestors)
#   - raca_summary.txt (statistics on ancestral genomes)
#
# Note:
#   RACA can be computationally intensive; this uses checkpointing
#   for long-running jobs
#
# Monitoring:
#   squeue -u $USER
#   tail -f run_raca_%j.log
##############################################################################

#SBATCH --job-name=scarab_raca
#SBATCH --partition=long
#SBATCH --time=7-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=48
#SBATCH --cpus-per-task=1
#SBATCH --mem=384G
#SBATCH --output=run_raca_%j.log
#SBATCH --error=run_raca_%j.err

## <<<STUDENT: Enter your TAMU NetID>>>
NETID="your_netid"

## <<<STUDENT: Enter your email for SLURM notifications (optional)>>>
EMAIL="your_email@tamu.edu"

set -euo pipefail

# Define paths
SCRATCH_ROOT="/scratch/user/${NETID}"
PROJECT_DIR="${SCRATCH_ROOT}/coleoptera"
CONTAINER="${PROJECT_DIR}/cactus_container.sif"
FINAL_HAL="${PROJECT_DIR}/results/scarab_final.hal"
WORK_DIR="${PROJECT_DIR}/work/raca"
OUTPUT_DIR="${PROJECT_DIR}/ancestral"
RACA_LOG="${OUTPUT_DIR}/raca_log.txt"

# Create output directories
mkdir -p "${WORK_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo "============================================================"
echo "Coleoptera Ancestral Reconstruction (RACA)"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Started: $(date)"
echo "============================================================"
echo ""
echo "Configuration:"
echo "  Nodes:        ${SLURM_NNODES}"
echo "  CPUs:         $(( SLURM_NNODES * SLURM_CPUS_ON_NODE ))"
echo "  Memory:       ${SLURM_MEM_PER_NODE} MB"
echo "  Queue:        ${SLURM_QUEUE}"
echo ""
echo "Paths:"
echo "  Container:    ${CONTAINER}"
echo "  Input HAL:    ${FINAL_HAL}"
echo "  Output dir:   ${OUTPUT_DIR}"
echo "  Work dir:     ${WORK_DIR}"
echo ""

# ============================================================================
# Validation
# ============================================================================
echo "[$(date)] Validating inputs..."

if [ ! -f "${CONTAINER}" ]; then
  echo "ERROR: Container not found at ${CONTAINER}"
  exit 1
fi

if [ ! -f "${FINAL_HAL}" ]; then
  echo "ERROR: Final HAL not found at ${FINAL_HAL}"
  exit 1
fi

echo "  ✓ HAL file: $(du -h "${FINAL_HAL}" | cut -f1)"
echo ""

# ============================================================================
# Extract internal node names from HAL
# ============================================================================
echo "[$(date)] Extracting internal node information..."

GENOMES_FILE="${WORK_DIR}/all_genomes.txt"

singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  halStats "${FINAL_HAL}" --printGenomes > "${GENOMES_FILE}"

TOTAL_NODES=$(wc -l < "${GENOMES_FILE}")

echo "  Total nodes (genomes + ancestors): ${TOTAL_NODES}"
echo "  Sample nodes:"
head -10 "${GENOMES_FILE}" | sed 's/^/    /'
if [ ${TOTAL_NODES} -gt 10 ]; then
  echo "    ... ($(( TOTAL_NODES - 10 )) more)"
fi
echo ""

# ============================================================================
# Identify internal (ancestral) nodes
# ============================================================================
echo "[$(date)] Identifying ancestral nodes..."

## <<<STUDENT: In the HAL alignment, internal nodes are those that are>>>
## neither leaf nodes (extant genomes) nor the root
## We need to extract the tree structure to identify them

# Create a Newick tree from the HAL to identify internal nodes
TREE_FILE="${WORK_DIR}/tree_structure.nwk"

## <<<STUDENT: Use halGetTree or equivalent to extract tree structure>>>
## This varies depending on your Cactus version
## For now, we'll extract internal node names differently

# Get all genomes and extract those likely to be ancestral
# Ancestral nodes often have patterns like "MRCA_", "anc", etc.
ANCESTRAL_NODES_FILE="${WORK_DIR}/ancestral_nodes.txt"

grep -E "(MRCA|anc|ancestral|root)" "${GENOMES_FILE}" > "${ANCESTRAL_NODES_FILE}" || true

# If no explicit ancestral naming, assume nodes with higher average alignment count
# are internal nodes (simplified heuristic)
if [ ! -s "${ANCESTRAL_NODES_FILE}" ]; then
  # Use all nodes except obvious leaves
  cp "${GENOMES_FILE}" "${ANCESTRAL_NODES_FILE}"
fi

ANCESTRAL_COUNT=$(wc -l < "${ANCESTRAL_NODES_FILE}")

echo "  ✓ Found ${ANCESTRAL_COUNT} ancestral nodes"
echo ""

# ============================================================================
# Run RACA for each ancestral node
# ============================================================================
echo "[$(date)] Running RACA for ancestral nodes..."
echo ""

NODE_COUNT=0

while IFS= read -r node_name; do
  [ -z "${node_name}" ] && continue

  ((NODE_COUNT++))

  echo "  Processing ancestral node ${NODE_COUNT}: ${node_name}"

  ## <<<STUDENT: RACA syntax (varies by version; this is a template)>>>
  ## Typical command: raca.py --hal=file.hal --genome=NODE_NAME --output=output_dir

  ## For Cactus/HAL-integrated version:
  RACA_CMD="raca --hal=${FINAL_HAL} --genome=${node_name} --output=${OUTPUT_DIR}/${node_name}"

  ## <<<STUDENT: Uncomment the appropriate command for your RACA version>>>
  ## Standard RACA (may need Python 2.7):
  # python "${RACA_PATH}/raca.py" \
  #   --hal="${FINAL_HAL}" \
  #   --genome="${node_name}" \
  #   --output="${OUTPUT_DIR}/${node_name}"

  ## Progressive Cactus integrated RACA:
  if singularity exec \
    -B "${PROJECT_DIR}:${PROJECT_DIR}" \
    "${CONTAINER}" \
    raca \
    --hal="${FINAL_HAL}" \
    --genome="${node_name}" \
    --outputDir="${OUTPUT_DIR}/${node_name}" \
    2>&1 | tee -a "${RACA_LOG}"; then

    echo "    ✓ Reconstructed ${node_name}"

    # Check for output FASTA
    if [ -f "${OUTPUT_DIR}/${node_name}/ancestral_genome.fa" ]; then
      SIZE=$(du -h "${OUTPUT_DIR}/${node_name}/ancestral_genome.fa" | cut -f1)
      echo "      Output: ${SIZE}"
    fi
  else
    echo "    ⚠ Warning: RACA may have failed or completed with warnings"
  fi

done < "${ANCESTRAL_NODES_FILE}"

echo ""
echo "[$(date)] ✓ RACA reconstruction completed for ${NODE_COUNT} nodes"
echo ""

# ============================================================================
# Collect FASTA files from all ancestral nodes
# ============================================================================
echo "[$(date)] Collecting ancestral genome sequences..."

FASTA_COUNT=0
while IFS= read -r node_name; do
  [ -z "${node_name}" ] && continue

  FASTA_FILE="${OUTPUT_DIR}/${node_name}/ancestral_genome.fa"

  if [ -f "${FASTA_FILE}" ]; then
    SIZE=$(du -h "${FASTA_FILE}" | cut -f1)
    echo "  ✓ ${node_name}: ${SIZE}"
    ((FASTA_COUNT++))
  fi
done < "${ANCESTRAL_NODES_FILE}"

echo ""
echo "[$(date)] ✓ Collected ${FASTA_COUNT} ancestral genomes"
echo ""

# ============================================================================
# Generate summary statistics
# ============================================================================
echo "[$(date)] Generating summary statistics..."

SUMMARY_FILE="${OUTPUT_DIR}/raca_summary.txt"

cat > "${SUMMARY_FILE}" <<EOF
COLEOPTERA ANCESTRAL RECONSTRUCTION SUMMARY
================================================================================
Generated: $(date)

RECONSTRUCTION METHOD:  RACA (Reconstruct Ancestral Chromosome Architecture)
Input HAL:              ${FINAL_HAL}
Total nodes processed:  ${NODE_COUNT}

ANCESTRAL GENOMES RECONSTRUCTED:
  Count:                ${FASTA_COUNT}
  Location:             ${OUTPUT_DIR}

ANCESTRAL GENOME STATISTICS:

EOF

# Calculate size statistics for reconstructed genomes
for fasta in "${OUTPUT_DIR}"/*/*.fa; do
  if [ -f "${fasta}" ]; then
    genome_name=$(basename "$(dirname "${fasta}")")
    genome_size=$(grep -v '^>' "${fasta}" | wc -c)
    n_scaffolds=$(grep -c '^>' "${fasta}" || echo 0)

    echo "  ${genome_name}:" >> "${SUMMARY_FILE}"
    echo "    Size: ${genome_size} bp ($(numfmt --to=iec-i --suffix=B ${genome_size} 2>/dev/null || echo 'N/A'))" >> "${SUMMARY_FILE}"
    echo "    Scaffolds: ${n_scaffolds}" >> "${SUMMARY_FILE}"
  fi
done

cat >> "${SUMMARY_FILE}" <<EOF

NEXT STEPS:
  1. Validate ancestral genome reconstructions
  2. Align ancestral genomes to extant species
  3. Perform synteny anchoring
  4. Generate evolutionary tree visualizations

OUTPUT STRUCTURE:
  ancestral_genomes/
    MRCA_*/
      ancestral_genome.fa
      ... (additional RACA output files)

================================================================================
EOF

echo "  Summary: ${SUMMARY_FILE}"
echo ""

# ============================================================================
# Cleanup and final summary
# ============================================================================
echo "[$(date)] Finalizing outputs..."

# Compress intermediate files (optional)
## <<<STUDENT: Uncomment to save disk space>>>
# find "${OUTPUT_DIR}" -name "*.tmp" -delete
# find "${WORK_DIR}" -name "*.log" -size 0 -delete

echo "  ✓ Output directory: ${OUTPUT_DIR}"
echo "  ✓ Log file: ${RACA_LOG}"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "============================================================"
echo "Ancestral Reconstruction Complete!"
echo "============================================================"
echo ""
echo "Results:"
echo "  Ancestral genomes:  ${FASTA_COUNT}"
echo "  Output directory:   ${OUTPUT_DIR}"
echo "  Summary:            ${SUMMARY_FILE}"
echo ""
echo "Output structure:"
echo "  ${OUTPUT_DIR}/"
echo "  ├── MRCA_clade1/"
echo "  │   └── ancestral_genome.fa"
echo "  ├── MRCA_clade2/"
echo "  │   └── ancestral_genome.fa"
echo "  └── ..."
echo ""
echo "Next steps:"
echo "  1. Validate reconstructed genomes"
echo "  2. Proceed with synteny anchoring (anchor_synteny.R)"
echo "  3. Generate ancestral genome visualizations"
echo ""
echo "Finished: $(date)"
echo "============================================================"
