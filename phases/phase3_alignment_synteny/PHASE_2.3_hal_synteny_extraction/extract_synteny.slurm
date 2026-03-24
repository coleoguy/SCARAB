#!/bin/bash
##############################################################################
# PHASE_2.3_hal_synteny_extraction/extract_synteny.slurm
#
# Purpose:
#   Extract pairwise synteny blocks from the merged HAL alignment
#   Uses halSynteny to identify conserved genome segments across species
#   Produces raw synteny block coordinates for all species pairs
#
# Queue:  medium (1 day, 128 nodes available)
# Nodes:  1 (single standard node: 48 cores, 384 GB RAM)
# Runtime: Typically 4-12 hours depending on number of genomes
#
# Submission:
#   sbatch extract_synteny.slurm
#
# Prerequisites:
#   - Final merged HAL file (from PHASE_2.2 merge_subtrees.slurm)
#   - All genome alignments complete
#
# Output:
#   - synteny_blocks_raw.tsv (TAB format with all pairwise blocks)
#   - synteny_stats.txt (summary statistics)
#
# Monitoring:
#   squeue -u $USER
#   tail -f extract_synteny_%j.log
##############################################################################

#SBATCH --job-name=scarab_synteny
#SBATCH --partition=medium
#SBATCH --time=1-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=48
#SBATCH --cpus-per-task=1
#SBATCH --mem=384G
#SBATCH --output=extract_synteny_%j.log
#SBATCH --error=extract_synteny_%j.err

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
WORK_DIR="${PROJECT_DIR}/work/synteny"
OUTPUT_DIR="${PROJECT_DIR}/synteny"
SYNTENY_OUTPUT="${OUTPUT_DIR}/synteny_blocks_raw.tsv"
STATS_OUTPUT="${OUTPUT_DIR}/synteny_stats.txt"

# Create working directories
mkdir -p "${WORK_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo "============================================================"
echo "Coleoptera Synteny Extraction"
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
echo "  Output:       ${SYNTENY_OUTPUT}"
echo "  Work Dir:     ${WORK_DIR}"
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
  echo "Please ensure merge_subtrees.slurm completed successfully"
  exit 1
fi

echo "  ✓ HAL file: $(du -h "${FINAL_HAL}" | cut -f1)"
echo ""

# ============================================================================
# Get genome list from HAL file
# ============================================================================
echo "[$(date)] Extracting genome list from HAL..."

GENOME_LIST_FILE="${WORK_DIR}/genomes.txt"

singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  halStats "${FINAL_HAL}" --printGenomes > "${GENOME_LIST_FILE}"

GENOME_COUNT=$(wc -l < "${GENOME_LIST_FILE}")

echo "  ✓ Found ${GENOME_COUNT} genomes:"
head -10 "${GENOME_LIST_FILE}" | sed 's/^/    /'
if [ ${GENOME_COUNT} -gt 10 ]; then
  echo "    ... ($(( GENOME_COUNT - 10 )) more)"
fi
echo ""

# ============================================================================
# Extract synteny blocks using halSynteny
# ============================================================================
echo "[$(date)] Extracting synteny blocks..."
echo ""

## <<<STUDENT: halSynteny parameters>>>
## --outDupes: Include duplications/paralogs
## --minSizeFilter N: Minimum block size in bp (default varies)
## --maxScore N: Maximum sequence divergence score
## --cigarOutput: Include CIGAR format alignment

TEMP_OUTPUT="${WORK_DIR}/synteny_raw_temp.txt"

if singularity exec \
  -B "${PROJECT_DIR}:${PROJECT_DIR}" \
  "${CONTAINER}" \
  halSynteny \
  "${FINAL_HAL}" \
  "${TEMP_OUTPUT}"; then

  echo "✓ halSynteny extraction completed"
else
  echo "✗ ERROR: halSynteny failed"
  exit 1
fi

echo ""

# ============================================================================
# Parse and format synteny output
# ============================================================================
echo "[$(date)] Formatting synteny output..."

## <<<STUDENT: Custom parsing script for synteny blocks>>>
## This converts halSynteny output to a structured TSV with:
## - Query genome
## - Target genome
## - Query coordinates (start, end, strand)
## - Target coordinates (start, end, strand)
## - Sequence identity
## - Block size

python3 - "${TEMP_OUTPUT}" "${SYNTENY_OUTPUT}" <<'PYTHON_EOF'
import sys
import re

input_file = sys.argv[1]
output_file = sys.argv[2]

# Read halSynteny output and parse blocks
# halSynteny outputs in a custom format; adjust parsing as needed

with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
    # Write header
    f_out.write("query_genome\ttarget_genome\tquery_chrom\tquery_start\tquery_end\t"
                "query_strand\ttarget_chrom\ttarget_start\ttarget_end\ttarget_strand\t"
                "identity\tblock_size\n")

    # Parse blocks
    current_query = None
    current_target = None
    block_count = 0

    for line in f_in:
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        # Simple parsing; adjust based on actual halSynteny output format
        fields = line.split('\t')

        if len(fields) >= 8:
            try:
                query_genome = fields[0]
                target_genome = fields[1]
                query_start = int(fields[2])
                query_end = int(fields[3])
                target_start = int(fields[4])
                target_end = int(fields[5])
                query_strand = fields[6] if len(fields) > 6 else '+'
                target_strand = fields[7] if len(fields) > 7 else '+'
                identity = float(fields[8]) if len(fields) > 8 else 1.0

                block_size = abs(query_end - query_start)

                # Output as TSV
                f_out.write(f"{query_genome}\t{target_genome}\t.\t{query_start}\t{query_end}\t"
                           f"{query_strand}\t.\t{target_start}\t{target_end}\t{target_strand}\t"
                           f"{identity:.3f}\t{block_size}\n")
                block_count += 1
            except (ValueError, IndexError):
                continue

print(f"Parsed {block_count} synteny blocks")
PYTHON_EOF

echo "  ✓ Synteny blocks formatted"
echo ""

# ============================================================================
# Generate summary statistics
# ============================================================================
echo "[$(date)] Generating summary statistics..."

BLOCK_COUNT=$(tail -n +2 "${SYNTENY_OUTPUT}" | wc -l)
TOTAL_BP=$(tail -n +2 "${SYNTENY_OUTPUT}" | awk '{sum += $NF} END {print sum}')

cat > "${STATS_OUTPUT}" <<EOF
COLEOPTERA SYNTENY EXTRACTION STATISTICS
================================================================================
Generated: $(date)
Input HAL:  ${FINAL_HAL}
Output:     ${SYNTENY_OUTPUT}

GENOME STATISTICS:
  Total genomes analyzed:  ${GENOME_COUNT}

SYNTENY STATISTICS:
  Total blocks extracted:  ${BLOCK_COUNT}
  Total base pairs:        ${TOTAL_BP}
  Average block size:      $(( TOTAL_BP / BLOCK_COUNT ))

TOP 10 LARGEST BLOCKS:
$(tail -n +2 "${SYNTENY_OUTPUT}" | sort -t$'\t' -k12 -rn | head -10 | \
  awk '{printf "  %s-%s: %d bp (%.1f%% identity)\n", $1, $2, $NF, ($11*100)}')

BLOCK SIZE DISTRIBUTION:
$(tail -n +2 "${SYNTENY_OUTPUT}" | awk '{print $NF}' | \
  awk 'BEGIN {bins[0]=0; bins[1]=0; bins[2]=0; bins[3]=0; bins[4]=0}
       {if ($1 < 10000) bins[0]++;
        else if ($1 < 50000) bins[1]++;
        else if ($1 < 100000) bins[2]++;
        else if ($1 < 500000) bins[3]++;
        else bins[4]++}
       END {printf "  < 10 kb:    %d\n  10-50 kb:   %d\n  50-100 kb:  %d\n  100-500 kb: %d\n  > 500 kb:   %d\n",
           bins[0], bins[1], bins[2], bins[3], bins[4]}')

IDENTITY DISTRIBUTION:
$(tail -n +2 "${SYNTENY_OUTPUT}" | awk '{print $11}' | \
  awk 'BEGIN {bins[0]=0; bins[1]=0; bins[2]=0; bins[3]=0}
       {if ($1 < 0.85) bins[0]++;
        else if ($1 < 0.95) bins[1]++;
        else if ($1 < 0.99) bins[2]++;
        else bins[3]++}
       END {printf "  < 85%:     %d\n  85-95%:    %d\n  95-99%:    %d\n  > 99%:     %d\n",
           bins[0], bins[1], bins[2], bins[3]}')

NEXT STEPS:
  1. QC filtering (remove low-quality blocks)
  2. Ancestral genome reconstruction
  3. Synteny visualization

================================================================================
EOF

echo "  Statistics file: ${STATS_OUTPUT}"
cat "${STATS_OUTPUT}" | head -30 | sed 's/^/  /'

echo ""

# ============================================================================
# Backup and cleanup
# ============================================================================
echo "[$(date)] Finalizing outputs..."

if [ -f "${SYNTENY_OUTPUT}" ]; then
  LINES=$(wc -l < "${SYNTENY_OUTPUT}")
  SIZE=$(du -h "${SYNTENY_OUTPUT}" | cut -f1)
  echo "  ✓ Synteny output: ${SIZE} (${LINES} lines)"
fi

# Compress intermediate files
if [ -f "${TEMP_OUTPUT}" ]; then
  gzip "${TEMP_OUTPUT}"
  echo "  ✓ Compressed temporary files"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "============================================================"
echo "Synteny Extraction Complete!"
echo "============================================================"
echo ""
echo "Output files:"
echo "  Raw blocks:  ${SYNTENY_OUTPUT}"
echo "  Statistics:  ${STATS_OUTPUT}"
echo ""
echo "Summary:"
echo "  Blocks:      ${BLOCK_COUNT}"
echo "  Total bp:    ${TOTAL_BP}"
echo "  Avg size:    $(( TOTAL_BP / BLOCK_COUNT )) bp"
echo ""
echo "Next steps:"
echo "  1. Review synteny_stats.txt for quality assessment"
echo "  2. Run synteny_qc.R to filter low-quality blocks"
echo "  3. Proceed with ancestral reconstruction"
echo ""
echo "Finished: $(date)"
echo "============================================================"
