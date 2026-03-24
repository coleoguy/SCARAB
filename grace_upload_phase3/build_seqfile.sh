#!/bin/bash
# ============================================================================
# build_seqfile.sh — Build Cactus seqFile from downloaded genomes on Grace
# ============================================================================
#
# Maps tree tip labels to FASTA file paths using tree_tip_mapping.csv.
# Genomes are in NCBI Datasets format: $GENOME_DIR/GCA_XXX/ncbi_dataset/data/GCA_XXX/*.fna
#
# Input:
#   constraint_tree_calibrated.nwk  (in $SCRATCH/scarab/data/)
#   tree_tip_mapping.csv            (in $SCRATCH/scarab/data/)
#   Genome FASTAs                   (in $SCRATCH/scarab/genomes/)
#
# Output:
#   $SCRATCH/scarab/cactus_seqfile.txt
#
# Usage (on Grace login node):
#   bash build_seqfile.sh
# ============================================================================

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
GENOME_DIR="${PROJECT_DIR}/genomes"
# Use the nuclear BUSCO marker guide tree (built by extract_nuclear_markers_and_build_tree.slurm)
# Falls back to calibrated tree if nuclear tree not yet built
# NOTE: COI tree is DEPRECATED (only 41% hit rate — see grace_upload_phase3/deprecated/)
if [ -f "${PROJECT_DIR}/nuclear_markers/nuclear_guide_tree_439.nwk" ]; then
    TREE_FILE="${PROJECT_DIR}/nuclear_markers/nuclear_guide_tree_439.nwk"
    echo "Using nuclear BUSCO marker guide tree"
elif [ -f "${PROJECT_DIR}/data/constraint_tree_calibrated.nwk" ]; then
    TREE_FILE="${PROJECT_DIR}/data/constraint_tree_calibrated.nwk"
    echo "WARNING: Nuclear tree not found, falling back to calibrated tree"
    echo "  Run prepare_nuclear_markers.sh + extract_nuclear_markers_and_build_tree.slurm first"
else
    echo "ERROR: No guide tree found"
    exit 1
fi
TIP_MAP="${PROJECT_DIR}/data/tree_tip_mapping.csv"
SEQFILE="${PROJECT_DIR}/cactus_seqfile.txt"

echo "============================================"
echo "SCARAB — Build Cactus seqFile"
echo "============================================"
echo ""

# Verify inputs
for f in "$TREE_FILE" "$TIP_MAP"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: Missing file: $f"
        exit 1
    fi
done

if [ ! -d "$GENOME_DIR" ]; then
    echo "ERROR: Genome directory not found: $GENOME_DIR"
    exit 1
fi

# Line 1: the Newick tree
cat "$TREE_FILE" > "$SEQFILE"
echo "" >> "$SEQFILE"

# Lines 2+: tip_label  /path/to/genome.fna
FOUND=0
MISSING=0
MISSING_LIST=""

# Skip header row of CSV
tail -n +2 "$TIP_MAP" | while IFS=',' read -r tip_label species_name accession family clade role; do
    # Find the FASTA file for this accession
    # NCBI Datasets extracts to: genomes/GCA_XXX/ncbi_dataset/data/GCA_XXX/*.fna
    FASTA=$(find "${GENOME_DIR}/${accession}/" -name "*.fna" -type f 2>/dev/null | head -1)

    if [ -n "$FASTA" ]; then
        echo "${tip_label} ${FASTA}" >> "$SEQFILE"
    else
        echo "WARNING: No FASTA found for ${tip_label} (${accession})" >&2
    fi
done

# Count results
TOTAL_ENTRIES=$(tail -n +2 "$SEQFILE" | grep -c . || true)
echo ""
echo "seqFile: ${SEQFILE}"
echo "Entries: ${TOTAL_ENTRIES} genomes mapped to tree tips"
echo ""
echo "First 5 entries:"
tail -n +2 "$SEQFILE" | head -5 | sed 's/^/  /'
echo ""
echo "Last 5 entries:"
tail -n +2 "$SEQFILE" | tail -5 | sed 's/^/  /'
echo ""

if [ "$TOTAL_ENTRIES" -lt 400 ]; then
    echo "WARNING: Only ${TOTAL_ENTRIES} genomes mapped. Expected ~439."
    echo "Check that genome directories contain .fna files."
fi

echo "Done."
