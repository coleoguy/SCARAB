#!/bin/bash
# ==============================================================================
# 02_pull_per_family.sh — Pull GenBank sequences per Coleoptera family
# ==============================================================================
# Run on Grace LOGIN NODE (has internet). Iterates over the Bouchard↔NCBI
# reconciliation table, queries NCBI Entrez for each locus, and writes per-family
# FASTA files.
#
# SuperCRUNCH approach: SuperCRUNCH's GenBank-pulling module (Genbank_Grab.py)
# retrieves records by taxon + locus keyword. Each family run produces one FASTA
# per locus. We then hand off to 03_filter_loci.sh for BLAST-based extraction.
#
# Taxonomy notes:
#   - 443 families: exact NCBI match — query by ncbi_taxid directly
#   - 12 families: "conflict" (Bouchard separates; NCBI lumps as subfamilies)
#       Cicindelidae (in Carabidae 41069), Colonidae (in Leiodidae 111502),
#       Disteniidae (in Cerambycidae 51011), Megalopodidae (in Chrysomelidae 7028),
#       Oxypeltidae (in Cerambycidae 51011), Sinopyrophoridae (in Elateridae 7050)
#       Strategy: query BOTH the parent-family taxid and the NCBI subfamily name.
#   - 335 families: "missing" (fossil/ichnotaxon) — written to no_data_families.txt
#
# Loci targeted (9 standard Coleoptera Sanger markers):
#   COI, 16S, 18S, 28S, CAD, EF1a, ArgK, RNApol2, wingless
#
# Usage:
#   bash 02_pull_per_family.sh
# ==============================================================================

set -euo pipefail

SCRATCH_TOB="${SCRATCH}/tob"
RECON_CSV="${SCRATCH_TOB}/data/bouchard2024_ncbi_reconciliation.csv"
RAW_DIR="${SCRATCH_TOB}/raw_seqs"
SC_DIR="${SCRATCH_TOB}/SuperCRUNCH"
SC_SCRIPTS="${SC_DIR}/supercrunch/scripts"
NO_DATA_FILE="${SCRATCH_TOB}/no_data_families.txt"
LOG_DIR="${SCRATCH_TOB}/logs"

# --- Load environment ---
module purge
module load Anaconda3/2024.02-1
source activate "${SCRATCH_TOB}/envs/supercrunch"

mkdir -p "${RAW_DIR}" "${LOG_DIR}"
> "${NO_DATA_FILE}"

# Locus name strings matching NCBI GenBank annotation keywords.
# SuperCRUNCH Parse_Loci.py matches these against sequence records.
# CONFIRM these match your locus_names.txt before running at scale.
LOCI="COI 16S 18S 28S CAD EF1a ArgK RNApol2 wingless"

# Mapping of the 6 conflict families to their NCBI parent taxid and subfamily name
# Format: "BOUCHARD_NAME:PARENT_TAXID:NCBI_SUBFAMILY_NAME"
declare -A CONFLICT_PARENT
CONFLICT_PARENT["Cicindelidae"]="41069:Cicindelinae"       # parent=Carabidae
CONFLICT_PARENT["Colonidae"]="111502:Coloninae"             # parent=Leiodidae
CONFLICT_PARENT["Disteniidae"]="51011:Disteniinae"          # parent=Cerambycidae
CONFLICT_PARENT["Megalopodidae"]="7028:Megalopodinae"       # parent=Chrysomelidae
CONFLICT_PARENT["Oxypeltidae"]="51011:Oxypeltinae"          # parent=Cerambycidae
CONFLICT_PARENT["Sinopyrophoridae"]="7050:Sinopyrophorinae" # parent=Elateridae

# Python snippet to parse the CSV (avoids awk quoting issues with CSV)
PARSE_CSV=$(cat <<'PYEOF'
import csv, sys
rows = []
with open(sys.argv[1]) as f:
    for row in csv.DictReader(f):
        rows.append((
            row['bouchard_family'].strip(),
            row['ncbi_taxid'].strip(),
            row['match_status'].strip()
        ))
for r in rows:
    print('\t'.join(r))
PYEOF
)

NFAMILIES=0
NSKIPPED=0
NCONFLICT=0

while IFS=$'\t' read -r FAMILY TAXID STATUS; do
    # Skip header echoes and empty
    [ -z "${FAMILY}" ] && continue

    if [ "${STATUS}" = "missing" ]; then
        echo "${FAMILY}" >> "${NO_DATA_FILE}"
        NSKIPPED=$((NSKIPPED + 1))
        continue
    fi

    OUTDIR="${RAW_DIR}/${FAMILY}"
    mkdir -p "${OUTDIR}"

    if [ "${STATUS}" = "conflict" ] && [ -n "${CONFLICT_PARENT[$FAMILY]+x}" ]; then
        # Conflict family: query parent taxid AND NCBI subfamily name
        PARENT_INFO="${CONFLICT_PARENT[$FAMILY]}"
        PARENT_TAXID="${PARENT_INFO%%:*}"
        SUBFAM_NAME="${PARENT_INFO##*:}"

        echo "[conflict] ${FAMILY}: querying parent taxid ${PARENT_TAXID} + subfamily ${SUBFAM_NAME}"

        # Query 1: parent family taxid (gets everything under it, filter to subfamily below)
        python "${SC_SCRIPTS}/Genbank_Grab.py" \
            --taxid "${PARENT_TAXID}" \
            --loci ${LOCI} \
            --outdir "${OUTDIR}/from_parent" \
            --retmax 100000 \
            2>&1 | tee "${LOG_DIR}/${FAMILY}_parent_pull.log" || true

        # Query 2: subfamily name string (catches records annotated at subfamily level)
        python "${SC_SCRIPTS}/Genbank_Grab.py" \
            --taxon "${SUBFAM_NAME}" \
            --loci ${LOCI} \
            --outdir "${OUTDIR}/from_subfam" \
            --retmax 100000 \
            2>&1 | tee "${LOG_DIR}/${FAMILY}_subfam_pull.log" || true

        # Merge both outputs into a single FASTA per locus
        for LOCUS in ${LOCI}; do
            cat "${OUTDIR}/from_parent/${LOCUS}.fasta" \
                "${OUTDIR}/from_subfam/${LOCUS}.fasta" \
                2>/dev/null \
            | sort -u -t '|' -k1,1 \
            > "${OUTDIR}/${LOCUS}.fasta" || true
        done

        NCONFLICT=$((NCONFLICT + 1))

    elif [ -n "${TAXID}" ] && [ "${STATUS}" = "exact" ]; then
        echo "[exact] ${FAMILY}: taxid ${TAXID}"

        python "${SC_SCRIPTS}/Genbank_Grab.py" \
            --taxid "${TAXID}" \
            --loci ${LOCI} \
            --outdir "${OUTDIR}" \
            --retmax 100000 \
            2>&1 | tee "${LOG_DIR}/${FAMILY}_pull.log" || true

    else
        echo "[skip] ${FAMILY}: status=${STATUS} taxid=${TAXID}"
        echo "${FAMILY}" >> "${NO_DATA_FILE}"
        NSKIPPED=$((NSKIPPED + 1))
        continue
    fi

    NFAMILIES=$((NFAMILIES + 1))

done < <(python3 -c "${PARSE_CSV}" "${RECON_CSV}")

echo ""
echo "Done."
echo "  Families queried:   ${NFAMILIES}"
echo "  Conflict families:  ${NCONFLICT}"
echo "  Skipped (missing):  ${NSKIPPED}"
echo "  No-data list:       ${NO_DATA_FILE}"
echo ""
echo "NOTE: Genbank_Grab.py module name may differ in your SuperCRUNCH version."
echo "Confirm with: ls ${SC_SCRIPTS}/ | grep -i grab"
echo "See 00_README.md blocker note on SuperCRUNCH pull commands."
