#!/bin/bash
##############################################################################
# PHASE_2.1_pipeline_setup/setup_grace.sh
#
# Purpose:
#   Initialize the Grace HPC environment for SCARAB whole-genome alignment
#   using ProgressiveCactus v2.x (Singularity container).
#
#   Steps:
#     1. Create project directory structure on $SCRATCH
#     2. Pull Cactus Singularity container from quay.io
#     3. Verify cactus, cactus-prepare, halStats are functional
#     4. Build Cactus seqFile from downloaded genomes + constraint tree
#     5. Run cactus-prepare to decompose the alignment into steps
#     6. Print next-step instructions
#
# Requirements:
#   - Downloaded genome FASTAs in $GENOME_DIR (from Phase 1.5 download scripts)
#   - Constraint tree: data/genomes/constraint_tree.nwk
#   - Run this on a login node (no SLURM needed for setup)
#
# Usage:
#   bash setup_grace.sh
#
# After running:
#   - Review the cactus-prepare output steps
#   - Submit test_alignment.slurm to verify on 5 small genomes
#   - Then submit full alignment via submit_prepared.sh
##############################################################################

set -euo pipefail

# ============================================================================
# USER CONFIGURATION — edit these before running
# ============================================================================

## Your TAMU NetID (used for scratch path)
NETID="${USER}"

## Path to directory containing downloaded genome FASTAs (.fa or .fa.gz)
## These should have been downloaded by scripts/phase2/download_genomes.slurm
GENOME_DIR="/scratch/user/${NETID}/scarab/genomes"

## Path to constraint tree from Phase 1.6
CONSTRAINT_TREE="/scratch/user/${NETID}/scarab/data/constraint_tree.nwk"

## Path to primary catalog CSV (genome_catalog_primary.csv)
## Used to map accessions to species names for tip labels
PRIMARY_CATALOG="/scratch/user/${NETID}/scarab/data/genome_catalog_primary.csv"

## Cactus container version
CACTUS_VERSION="v2.9.3"
CACTUS_IMAGE="quay.io/comparative-genomics-toolkit/cactus:${CACTUS_VERSION}"

# ============================================================================
# DERIVED PATHS — generally don't need to edit
# ============================================================================

PROJECT_DIR="/scratch/user/${NETID}/scarab"
CONTAINER="${PROJECT_DIR}/cactus_${CACTUS_VERSION}.sif"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"
PREPARED_DIR="${PROJECT_DIR}/prepared"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"

# ============================================================================
# MAIN SETUP
# ============================================================================

mkdir -p "${LOG_DIR}"

{
echo "============================================================"
echo "SCARAB — Grace Pipeline Setup"
echo "Started: $(date)"
echo "User: ${NETID}"
echo "============================================================"
echo ""

# ---- 1. Create directory structure ----
echo "[1/6] Creating directory structure..."
for d in genomes data work hal_files prepared logs results tmp; do
    mkdir -p "${PROJECT_DIR}/${d}"
done
echo "  Done: ${PROJECT_DIR}/"
echo ""

# ---- 2. Pull Cactus Singularity container ----
echo "[2/6] Pulling Cactus Singularity container..."
echo "  Image: ${CACTUS_IMAGE}"
echo "  Target: ${CONTAINER}"

if [ -f "${CONTAINER}" ]; then
    echo "  Container already exists — skipping pull."
    echo "  (Delete ${CONTAINER} to force re-pull)"
else
    # Grace typically has Singularity available as a module
    module load Singularity 2>/dev/null || module load singularity 2>/dev/null || true

    SINGULARITY_TMPDIR="${PROJECT_DIR}/tmp" \
    singularity pull "${CONTAINER}" "docker://${CACTUS_IMAGE}"
    echo "  Pull complete."
fi
echo ""

# ---- 3. Verify container tools ----
echo "[3/6] Verifying container tools..."

SING="singularity exec -B ${PROJECT_DIR}:${PROJECT_DIR} ${CONTAINER}"

# Check cactus
CACTUS_VER=$(${SING} cactus --version 2>&1 || echo "FAILED")
echo "  cactus:          ${CACTUS_VER}"

# Check cactus-prepare
PREP_CHECK=$(${SING} cactus-prepare --help 2>&1 | head -1 || echo "FAILED")
echo "  cactus-prepare:  ${PREP_CHECK}"

# Check halStats
HAL_CHECK=$(${SING} halStats --version 2>&1 || echo "FAILED")
echo "  halStats:        ${HAL_CHECK}"

# Check hal2maf
H2M_CHECK=$(${SING} hal2maf --help 2>&1 | head -1 || echo "FAILED")
echo "  hal2maf:         available"

echo ""

# ---- 4. Build Cactus seqFile ----
echo "[4/6] Building Cactus seqFile..."
echo ""
echo "  The seqFile format is:"
echo "    Line 1: Newick tree"
echo "    Lines 2+: <taxon_name> <path_to_fasta>"
echo ""

# Check genome directory
if [ ! -d "${GENOME_DIR}" ]; then
    echo "  WARNING: Genome directory not found: ${GENOME_DIR}"
    echo "  Download genomes first (scripts/phase2/download_genomes.slurm)"
    echo "  Creating placeholder seqFile with tree only."

    # Write tree line only
    if [ -f "${CONSTRAINT_TREE}" ]; then
        cat "${CONSTRAINT_TREE}" > "${SEQFILE}"
        echo "" >> "${SEQFILE}"
        echo "  Tree written to seqFile (no genomes yet)"
    else
        echo "  ERROR: Constraint tree not found either: ${CONSTRAINT_TREE}"
        echo "  Cannot build seqFile."
    fi
else
    # Count available genomes
    GENOME_COUNT=$(find "${GENOME_DIR}" -name "*.fa" -o -name "*.fa.gz" -o -name "*.fna" -o -name "*.fna.gz" | wc -l)
    echo "  Found ${GENOME_COUNT} genome files in ${GENOME_DIR}"

    if [ "${GENOME_COUNT}" -eq 0 ]; then
        echo "  WARNING: No genome files found."
        echo "  Expected .fa or .fa.gz files from download step."
    else
        # Build seqFile
        # Line 1: the Newick tree
        cat "${CONSTRAINT_TREE}" > "${SEQFILE}"

        # Lines 2+: taxon_name  /path/to/genome.fa
        # Taxon names must match tree tip labels exactly
        # Our tree uses species names like "Tribolium_castaneum"
        # Genomes are stored as accession-named files; we need the mapping

        echo "" >> "${SEQFILE}"

        # Build mapping from constraint tree tip labels to genome files
        # Tip labels in tree are species names (underscored)
        # Downloaded files should be named by accession
        # Use tree_tip_mapping.csv if available to link them

        TIP_MAPPING="${PROJECT_DIR}/data/tree_tip_mapping.csv"
        if [ -f "${TIP_MAPPING}" ]; then
            echo "  Using tree_tip_mapping.csv for label→accession mapping"

            # CSV format: tip_label,species_name,accession,...
            # We need: tip_label  /path/to/accession.fa
            tail -n +2 "${TIP_MAPPING}" | while IFS=',' read -r tip species accession rest; do
                # Look for genome file by accession
                for ext in fa fa.gz fna fna.gz; do
                    FPATH="${GENOME_DIR}/${accession}.${ext}"
                    if [ -f "${FPATH}" ]; then
                        echo "${tip} ${FPATH}" >> "${SEQFILE}"
                        break
                    fi
                    # Also try accession with dots replaced
                    FPATH2="${GENOME_DIR}/${accession%%.*}.${ext}"
                    if [ -f "${FPATH2}" ]; then
                        echo "${tip} ${FPATH2}" >> "${SEQFILE}"
                        break
                    fi
                done
            done

            MAPPED=$(tail -n +2 "${SEQFILE}" | grep -c . || true)
            echo "  Mapped ${MAPPED} of ${GENOME_COUNT} genomes to tree tips"
        else
            echo "  WARNING: tree_tip_mapping.csv not found"
            echo "  Building seqFile from filenames (species names assumed)"

            for genome_file in "${GENOME_DIR}"/*.fa "${GENOME_DIR}"/*.fa.gz; do
                [ -f "${genome_file}" ] || continue
                # Extract species name from filename
                BASENAME=$(basename "${genome_file}")
                TAXON="${BASENAME%%.*}"
                echo "${TAXON} ${genome_file}" >> "${SEQFILE}"
            done
        fi

        TOTAL_ENTRIES=$(tail -n +2 "${SEQFILE}" | grep -c . || true)
        echo "  seqFile: ${SEQFILE}"
        echo "  Entries: ${TOTAL_ENTRIES}"
        echo "  First 3 entries:"
        tail -n +2 "${SEQFILE}" | head -3 | sed 's/^/    /'
    fi
fi
echo ""

# ---- 5. Run cactus-prepare (decomposition preview) ----
echo "[5/6] Running cactus-prepare (dry run / decomposition)..."
echo ""

TOTAL_ENTRIES=$(tail -n +2 "${SEQFILE}" | grep -c . 2>/dev/null || echo "0")

if [ "${TOTAL_ENTRIES}" -gt 2 ]; then
    echo "  Running cactus-prepare to decompose alignment into steps..."
    echo "  This produces a set of commands that can be submitted as SLURM jobs."
    echo ""

    mkdir -p "${PREPARED_DIR}"

    # cactus-prepare generates a shell script of commands and a modified seqFile
    ${SING} cactus-prepare \
        "${SEQFILE}" \
        --outDir "${PREPARED_DIR}" \
        --outSeqFile "${PREPARED_DIR}/prepared_seqfile.txt" \
        --outHal "${PROJECT_DIR}/hal_files/scarab.hal" \
        --jobStore "${PROJECT_DIR}/work/js" \
        > "${PREPARED_DIR}/steps.sh" 2>&1 || {
            echo "  WARNING: cactus-prepare failed (this is OK if seqFile is incomplete)"
            echo "  Error output saved to ${PREPARED_DIR}/steps.sh"
        }

    if [ -f "${PREPARED_DIR}/steps.sh" ]; then
        STEP_COUNT=$(grep -c "^cactus" "${PREPARED_DIR}/steps.sh" 2>/dev/null || echo "0")
        echo "  cactus-prepare generated ${STEP_COUNT} alignment steps"
        echo "  Steps file: ${PREPARED_DIR}/steps.sh"
        echo ""
        echo "  First 5 steps:"
        head -10 "${PREPARED_DIR}/steps.sh" | sed 's/^/    /'
    fi
else
    echo "  Skipping: Need >2 genomes in seqFile to decompose."
    echo "  Download genomes first, then re-run this script."
fi
echo ""

# ---- 6. Summary ----
echo "============================================================"
echo "Setup Summary"
echo "============================================================"
echo ""
echo "Container:     ${CONTAINER}"
echo "seqFile:       ${SEQFILE}"
echo "Prepared dir:  ${PREPARED_DIR}"
echo "Project dir:   ${PROJECT_DIR}"
echo ""
echo "Genome count:  ${TOTAL_ENTRIES} mapped to tree tips"
echo ""
echo "NEXT STEPS:"
echo "  1. If genomes not yet downloaded:"
echo "     sbatch scripts/phase2/download_genomes.slurm"
echo "     Then re-run this setup script."
echo ""
echo "  2. Test alignment on 5 small genomes:"
echo "     sbatch test_alignment.slurm"
echo ""
echo "  3. If test passes, run full alignment:"
echo "     bash submit_prepared.sh"
echo "     (This submits the cactus-prepare steps as SLURM jobs)"
echo ""
echo "Finished: $(date)"
echo "Log: ${LOG_FILE}"

} 2>&1 | tee "${LOG_FILE}"
