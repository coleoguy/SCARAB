#!/bin/bash
# ============================================================================
# P1_map_busco_to_tribolium.sh — Map all 1,367 BUSCO insecta proteins to
# Tribolium castaneum (Tcas5.2) chromosomes and assign Stevens elements
# ============================================================================
#
# Purpose:
#   Map each BUSCO insecta_odb10 protein to its chromosomal position in the
#   Tribolium castaneum reference genome, then assign to one of 9 Stevens
#   elements (ancestral beetle chromosomes, Bracewell et al. 2024).
#
# Prerequisites:
#   - BUSCO insecta_odb10 already downloaded via prepare_nuclear_markers.sh
#   - Tribolium castaneum genome in $SCRATCH/scarab/genomes/
#
# Output:
#   $SCRATCH/scarab/phylogenomics/busco_tribolium_map.tsv
#   Columns: busco_id  protein_length  tcas_scaffold  tcas_start  tcas_end
#            tcas_strand  stevens_element  pident  evalue
#
# Run on LOGIN NODE (fast — single tBLASTn against one genome):
#   bash P1_map_busco_to_tribolium.sh
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
GENOME_DIR="${PROJECT_DIR}/genomes"
MARKER_DIR="${PROJECT_DIR}/nuclear_markers"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
BUSCO_DIR="${MARKER_DIR}/busco_insecta_odb10"

# All 1,367 BUSCO protein files are individual FASTAs in ancestral_variants/
BUSCO_PROTEINS="${BUSCO_DIR}/ancestral_variants"

# Tribolium castaneum genome — find it by accession pattern
# Tcas5.2 = GCF_000002335 (RefSeq) or GCA_000002335
TCAS_GENOME=$(find "${GENOME_DIR}" -name "*Tribolium_castaneum*" -name "*.fna" | head -1)

# Stevens element assignments for Tcas5.2 chromosomes
# From Bracewell et al. (2024) Table S1: Tcas LG1-10 → Stevens elements
# Tcas has 10 chromosomes (9 autosomes + X)
# These mappings are from Bracewell et al. 2024 supplementary data
# Format: scaffold_name → Stevens element letter
# NOTE: Heath should verify these against the Bracewell supplement
declare -A STEVENS_MAP
STEVENS_MAP=(
    ["NC_003081.2"]="X"      # Tcas X chromosome → Stevens X
    ["NC_007416.3"]="A"      # Tcas LG2 → Stevens A
    ["NC_007417.3"]="B"      # Tcas LG3 → Stevens B
    ["NC_007418.3"]="C"      # Tcas LG4 → Stevens C
    ["NC_007419.3"]="D"      # Tcas LG5 → Stevens D
    ["NC_007420.3"]="E"      # Tcas LG6 → Stevens E
    ["NC_007421.3"]="F"      # Tcas LG7 → Stevens F
    ["NC_007422.3"]="G"      # Tcas LG8 → Stevens G
    ["NC_007423.3"]="H"      # Tcas LG9 → Stevens H
    ["NC_007424.3"]="I"      # Tcas LG10 → Stevens I
)
# IMPORTANT: The scaffold names above are placeholders based on Tcas5.2
# RefSeq accession numbers. Heath needs to verify the actual scaffold
# names in the downloaded Tcas FASTA and update the Stevens assignments
# from Bracewell et al. (2024) Table S1.

mkdir -p "${PHYLO_DIR}"

echo "============================================================"
echo "SCARAB P.1 — Map BUSCO Proteins to Tribolium / Stevens Elements"
echo "Started: $(date)"
echo "============================================================"
echo ""

# ============================================================================
# 0. VERIFY INPUTS
# ============================================================================

echo "[0] Verifying inputs..."

if [ -z "${TCAS_GENOME}" ] || [ ! -f "${TCAS_GENOME}" ]; then
    echo "ERROR: Cannot find Tribolium castaneum genome in ${GENOME_DIR}"
    echo "  Looking for files matching *Tribolium_castaneum*.fna"
    echo "  Available genomes:"
    ls "${GENOME_DIR}"/*.fna 2>/dev/null | head -5
    echo ""
    echo "  You may need to set TCAS_GENOME manually. Check:"
    echo "    ls \${SCRATCH}/scarab/genomes/ | grep -i tribolium"
    exit 1
fi

if [ ! -d "${BUSCO_PROTEINS}" ]; then
    echo "ERROR: BUSCO protein directory not found: ${BUSCO_PROTEINS}"
    echo "  Run prepare_nuclear_markers.sh first (downloads insecta_odb10)"
    exit 1
fi

N_BUSCO=$(ls "${BUSCO_PROTEINS}"/*.faa 2>/dev/null | wc -l)
echo "  Tribolium genome: ${TCAS_GENOME}"
echo "  BUSCO proteins found: ${N_BUSCO}"

if [ "${N_BUSCO}" -lt 100 ]; then
    echo "ERROR: Expected ~1,367 BUSCO proteins, found only ${N_BUSCO}"
    exit 1
fi

# ============================================================================
# 1. CONCATENATE ALL BUSCO PROTEINS
# ============================================================================

echo "[1] Concatenating ${N_BUSCO} BUSCO proteins..."

ALL_PROTEINS="${PHYLO_DIR}/all_busco_insecta_proteins.fasta"
cat "${BUSCO_PROTEINS}"/*.faa > "${ALL_PROTEINS}"

N_SEQS=$(grep -c "^>" "${ALL_PROTEINS}")
echo "  Total protein sequences: ${N_SEQS}"

# ============================================================================
# 2. MAKE BLAST DATABASE FOR TRIBOLIUM
# ============================================================================

echo "[2] Building BLAST database for Tribolium..."

TCAS_DB="${PHYLO_DIR}/tcas_blastdb"
module load GCC/12.2.0 BLAST+/2.14.0

makeblastdb -in "${TCAS_GENOME}" -dbtype nucl -out "${TCAS_DB}" \
    -title "Tribolium_castaneum_Tcas5.2" 2>&1 | tail -3

# ============================================================================
# 3. tBLASTn ALL BUSCO PROTEINS → TRIBOLIUM
# ============================================================================

echo "[3] Running tBLASTn (all BUSCO proteins vs Tribolium)..."

BLAST_OUT="${PHYLO_DIR}/busco_vs_tcas_tblastn.tsv"

tblastn -query "${ALL_PROTEINS}" \
        -db "${TCAS_DB}" \
        -out "${BLAST_OUT}" \
        -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qlen" \
        -evalue 1e-5 \
        -max_target_seqs 1 \
        -num_threads 4

N_HITS=$(wc -l < "${BLAST_OUT}")
echo "  Total BLAST hits: ${N_HITS}"

# ============================================================================
# 4. PARSE HITS + ASSIGN STEVENS ELEMENTS
# ============================================================================

echo "[4] Parsing hits and assigning Stevens elements..."

OUTPUT="${PHYLO_DIR}/busco_tribolium_map.tsv"

# Header
echo -e "busco_id\tprotein_length\ttcas_scaffold\ttcas_start\ttcas_end\ttcas_strand\tstevens_element\tpident\tevalue" > "${OUTPUT}"

# Filter: keep best hit per BUSCO, require >=100 aa alignment and >=30% identity
awk -F'\t' '
BEGIN { OFS="\t" }
{
    qid = $1; sid = $2; pident = $3; alen = $4;
    sstart = $9; send = $10; eval = $11; qlen = $13;
    # Filter
    if (alen < 100 || pident < 30.0) next;
    # Keep best hit per query (first seen = best by bitscore in -max_target_seqs 1)
    if (!(qid in seen)) {
        seen[qid] = 1;
        strand = (sstart < send) ? "+" : "-";
        if (strand == "-") { tmp = sstart; sstart = send; send = tmp; }
        print qid, qlen, sid, sstart, send, strand, "UNKNOWN", pident, eval;
    }
}' "${BLAST_OUT}" >> "${OUTPUT}"

N_MAPPED=$(tail -n +2 "${OUTPUT}" | wc -l)
echo "  Proteins mapped to Tribolium: ${N_MAPPED} / ${N_BUSCO}"

# ============================================================================
# 5. ASSIGN STEVENS ELEMENTS (requires manual verification)
# ============================================================================

echo "[5] Assigning Stevens elements..."
echo ""
echo "  *** ACTION REQUIRED ***"
echo "  The Stevens element assignments in this script are PLACEHOLDERS."
echo "  Heath needs to:"
echo "    1. Check actual scaffold names: head -1 ${TCAS_GENOME}"
echo "    2. Cross-reference with Bracewell et al. (2024) Table S1"
echo "    3. Update STEVENS_MAP in this script"
echo "    4. Re-run this script"
echo ""
echo "  For now, listing unique Tribolium scaffolds with hit counts:"

tail -n +2 "${OUTPUT}" | cut -f3 | sort | uniq -c | sort -rn | head -20

echo ""
echo "  Output so far (without Stevens assignments): ${OUTPUT}"

# ============================================================================
# 6. SUMMARY
# ============================================================================

echo ""
echo "============================================================"
echo "P.1 COMPLETE"
echo "============================================================"
echo "  BUSCO proteins queried:     ${N_BUSCO}"
echo "  Mapped to Tribolium (≥100aa, ≥30% id): ${N_MAPPED}"
echo "  Output: ${OUTPUT}"
echo ""
echo "NEXT STEP: P.2 — Select 300-500 loci balanced across Stevens elements"
echo "  Requires: Stevens element assignments verified in ${OUTPUT}"
echo "============================================================"
