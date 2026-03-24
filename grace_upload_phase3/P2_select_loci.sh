#!/bin/bash
# ============================================================================
# P2_select_loci.sh — Select 300-500 BUSCO loci balanced across Stevens
# elements for multi-locus phylogenomics
# ============================================================================
#
# Purpose:
#   From the BUSCO→Tribolium mapping (P1 output), select loci that:
#   1. Are distributed across all 9 Stevens elements (+ X)
#   2. Have sufficient protein length (≥300 aa preferred)
#   3. Prioritize longer proteins for phylogenetic signal
#
# Input:
#   $SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv (from P1)
#
# Output:
#   $SCRATCH/scarab/phylogenomics/selected_loci.txt  (BUSCO IDs, one per line)
#   $SCRATCH/scarab/phylogenomics/loci_by_element.tsv (locus + element assignment)
#   $SCRATCH/scarab/phylogenomics/selected_proteins.fasta (concatenated FASTAs)
#
# Run on LOGIN NODE:
#   bash P2_select_loci.sh
# ============================================================================

set -euo pipefail

PROJECT_DIR="${SCRATCH}/scarab"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
BUSCO_PROTEINS="${PROJECT_DIR}/nuclear_markers/busco_insecta_odb10/ancestral_variants"
MAP_FILE="${PHYLO_DIR}/busco_tribolium_map.tsv"

TARGET_LOCI=500          # aim for 500, accept ≥300
MIN_PROTEIN_LEN=200      # minimum protein length (aa)

echo "============================================================"
echo "SCARAB P.2 — Select Balanced Loci Across Stevens Elements"
echo "Started: $(date)"
echo "============================================================"
echo ""

# ============================================================================
# 0. VERIFY INPUT
# ============================================================================

if [ ! -f "${MAP_FILE}" ]; then
    echo "ERROR: Missing ${MAP_FILE}"
    echo "  Run P1_map_busco_to_tribolium.sh first"
    exit 1
fi

N_MAPPED=$(tail -n +2 "${MAP_FILE}" | wc -l)
echo "  Input: ${N_MAPPED} mapped BUSCO proteins"

# Check that Stevens elements have been assigned
N_UNKNOWN=$(tail -n +2 "${MAP_FILE}" | awk -F'\t' '$7=="UNKNOWN"' | wc -l)
if [ "${N_UNKNOWN}" -gt 0 ]; then
    echo ""
    echo "  WARNING: ${N_UNKNOWN} loci still have UNKNOWN Stevens element."
    echo "  Proceeding anyway — unknown elements will be assigned proportionally."
    echo ""
fi

# ============================================================================
# 1. SELECT LOCI — BALANCED ACROSS ELEMENTS, PRIORITIZE LENGTH
# ============================================================================

echo "[1] Selecting loci balanced across Stevens elements..."

# Strategy: sort by protein length descending within each element,
# then round-robin select across elements until we hit TARGET_LOCI

python3 - <<'PYEOF'
import sys, os

map_file = os.environ.get("MAP_FILE", "")
target = int(os.environ.get("TARGET_LOCI", "500"))
min_len = int(os.environ.get("MIN_PROTEIN_LEN", "200"))
phylo_dir = os.environ.get("PHYLO_DIR", "")

# Read mapping
loci = {}  # element -> [(busco_id, length, ...)]
with open(map_file) as f:
    header = f.readline().strip().split("\t")
    for line in f:
        cols = line.strip().split("\t")
        busco_id = cols[0]
        prot_len = int(cols[1])
        element = cols[6]
        pident = float(cols[7])

        if prot_len < min_len:
            continue

        if element not in loci:
            loci[element] = []
        loci[element].append((busco_id, prot_len, pident))

# Sort each element by protein length (descending)
for elem in loci:
    loci[elem].sort(key=lambda x: -x[1])

elements = sorted(loci.keys())
print(f"  Stevens elements found: {', '.join(elements)}")
print(f"  Loci per element (≥{min_len} aa):")
for e in elements:
    print(f"    {e}: {len(loci[e])}")

# Round-robin selection
selected = []
selected_details = []
indices = {e: 0 for e in elements}

while len(selected) < target:
    added_this_round = False
    for elem in elements:
        if indices[elem] < len(loci[elem]) and len(selected) < target:
            busco_id, prot_len, pident = loci[elem][indices[elem]]
            selected.append(busco_id)
            selected_details.append((busco_id, elem, prot_len, pident))
            indices[elem] += 1
            added_this_round = True
    if not added_this_round:
        break  # exhausted all elements

print(f"\n  Selected {len(selected)} loci")

# Element balance summary
from collections import Counter
elem_counts = Counter(d[1] for d in selected_details)
print("  Per-element counts:")
for e in sorted(elem_counts):
    print(f"    {e}: {elem_counts[e]}")

# Write outputs
loci_file = os.path.join(phylo_dir, "selected_loci.txt")
detail_file = os.path.join(phylo_dir, "loci_by_element.tsv")

with open(loci_file, "w") as f:
    for busco_id in selected:
        f.write(busco_id + "\n")

with open(detail_file, "w") as f:
    f.write("busco_id\tstevens_element\tprotein_length\tpident_vs_tcas\n")
    for busco_id, elem, plen, pid in selected_details:
        f.write(f"{busco_id}\t{elem}\t{plen}\t{pid:.1f}\n")

print(f"\n  Wrote: {loci_file}")
print(f"  Wrote: {detail_file}")
PYEOF

# ============================================================================
# 2. EXTRACT SELECTED PROTEIN FASTAS
# ============================================================================

echo ""
echo "[2] Extracting protein FASTAs for selected loci..."

SELECTED="${PHYLO_DIR}/selected_loci.txt"
OUTFASTA="${PHYLO_DIR}/selected_proteins.fasta"

> "${OUTFASTA}"
COUNT=0
while IFS= read -r BUSCO_ID; do
    # Each BUSCO has a .faa in ancestral_variants/
    FA="${BUSCO_PROTEINS}/${BUSCO_ID}.faa"
    if [ -f "${FA}" ]; then
        cat "${FA}" >> "${OUTFASTA}"
        COUNT=$((COUNT + 1))
    else
        echo "  WARNING: No FASTA for ${BUSCO_ID}"
    fi
done < "${SELECTED}"

echo "  Extracted ${COUNT} protein FASTAs → ${OUTFASTA}"

# ============================================================================
# 3. SUMMARY
# ============================================================================

echo ""
echo "============================================================"
echo "P.2 COMPLETE"
echo "============================================================"
echo "  Selected loci: ${COUNT}"
echo "  Loci list: ${PHYLO_DIR}/selected_loci.txt"
echo "  Element map: ${PHYLO_DIR}/loci_by_element.tsv"
echo "  Proteins: ${OUTFASTA}"
echo ""
echo "NEXT STEP: P.3 — tBLASTn selected loci × 439 genomes"
echo "  Submit: sbatch P3_blast_selected_loci.slurm"
echo "============================================================"
