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
TREE_FILE="${PROJECT_DIR}/data/constraint_tree_calibrated.nwk"
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
