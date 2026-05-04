#!/bin/bash
# ==============================================================================
# 03_filter_loci.sh — BLAST-based locus extraction with SuperCRUNCH
# ==============================================================================
# Applies SuperCRUNCH Taxa_Assessment.py + Cluster_Blast_Extract.py to the
# raw per-family FASTA files from 02_pull_per_family.sh.
#
# Steps per family:
#   1. Taxa_Assessment.py   — cross-checks sequence record names against the
#                             Bouchard taxonomy; flags synonyms and mismatches.
#   2. Cluster_Blast_Extract.py — BLAST each record against a reference
#                             sequence for the locus; retains only hits that
#                             cluster with the reference (controls for
#                             annotation errors / contamination).
#
# Run on login node or submit as a single medium job if >200 families.
# This script runs serially; for very large runs, wrap in an array (see below).
#
# Prerequisites:
#   - 02_pull_per_family.sh complete
#   - $SCRATCH/tob/data/locus_references.fasta  (9 seqs, one per locus)
#   - $SCRATCH/tob/data/taxonomy_names.txt       (for Taxa_Assessment)
#     Format: one name per line, all accepted Coleoptera species names.
#     Generate from the Bouchard CSV + NCBI taxonomy dump.
#
# Usage:
#   bash 03_filter_loci.sh
# ==============================================================================

set -euo pipefail

SCRATCH_TOB="${SCRATCH}/tob"
RAW_DIR="${SCRATCH_TOB}/raw_seqs"
FILT_DIR="${SCRATCH_TOB}/filtered_seqs"
SC_DIR="${SCRATCH_TOB}/SuperCRUNCH"
SC_SCRIPTS="${SC_DIR}/supercrunch/scripts"
REF_FASTA="${SCRATCH_TOB}/data/locus_references.fasta"
TAXNAMES="${SCRATCH_TOB}/data/taxonomy_names.txt"
LOG_DIR="${SCRATCH_TOB}/logs"

# BLAST identity and coverage thresholds for Cluster_Blast_Extract
# These are the SuperCRUNCH defaults; adjust if yield is too low.
MIN_IDENTITY=70    # % identity to reference
MIN_COVERAGE=50    # % query coverage

LOCI="COI 16S 18S 28S CAD EF1a ArgK RNApol2 wingless"

module purge
module load Anaconda3/2024.02-1
source activate "${SCRATCH_TOB}/envs/supercrunch"

mkdir -p "${FILT_DIR}" "${LOG_DIR}"

# Verify reference FASTA exists
if [ ! -f "${REF_FASTA}" ]; then
    echo "ERROR: ${REF_FASTA} not found."
    echo "Create a 9-sequence FASTA with one reference per locus."
    echo "Header format: >LOCUS_NAME (e.g., >COI)"
    exit 1
fi

# Split reference FASTA into per-locus files for Cluster_Blast_Extract
REF_DIR="${SCRATCH_TOB}/data/locus_refs_split"
mkdir -p "${REF_DIR}"
python3 - <<PYEOF
from Bio import SeqIO
import os
ref = "${REF_FASTA}"
outdir = "${REF_DIR}"
for rec in SeqIO.parse(ref, "fasta"):
    locus = rec.id.split()[0]
    outpath = os.path.join(outdir, locus + "_ref.fasta")
    with open(outpath, "w") as fh:
        SeqIO.write(rec, fh, "fasta")
    print("Wrote:", outpath)
PYEOF

# Iterate over families that have raw seq directories
for FAMDIR in "${RAW_DIR}"/*/; do
    FAMILY=$(basename "${FAMDIR}")
    OUTDIR="${FILT_DIR}/${FAMILY}"
    mkdir -p "${OUTDIR}"

    echo "Processing: ${FAMILY}"

    for LOCUS in ${LOCI}; do
        RAW_FA="${FAMDIR}/${LOCUS}.fasta"
        if [ ! -s "${RAW_FA}" ]; then
            continue  # no sequences for this locus in this family
        fi

        LOCUS_OUTDIR="${OUTDIR}/${LOCUS}"
        mkdir -p "${LOCUS_OUTDIR}"

        # Step 1: Taxa_Assessment — validate taxon names against Bouchard list
        # Outputs: "Accepted" and "Unaccepted" FASTA files
        python "${SC_SCRIPTS}/Taxa_Assessment.py" \
            -i "${RAW_FA}" \
            -t "${TAXNAMES}" \
            -o "${LOCUS_OUTDIR}/taxa_assessed" \
            2>>"${LOG_DIR}/${FAMILY}_${LOCUS}_taxa.log" || {
            echo "  WARNING: Taxa_Assessment failed for ${FAMILY}/${LOCUS}"
            continue
        }

        # Use the Accepted sequences for BLAST extraction
        ACCEPTED="${LOCUS_OUTDIR}/taxa_assessed/Accepted.fasta"
        if [ ! -s "${ACCEPTED}" ]; then
            # Fall back to full raw if taxa assessment yields nothing
            ACCEPTED="${RAW_FA}"
        fi

        # Step 2: Cluster_Blast_Extract — BLAST against reference + extract
        REF_FOR_LOCUS="${REF_DIR}/${LOCUS}_ref.fasta"
        if [ ! -f "${REF_FOR_LOCUS}" ]; then
            echo "  WARNING: No reference for locus ${LOCUS}; skipping BLAST step"
            cp "${ACCEPTED}" "${OUTDIR}/${LOCUS}_filtered.fasta" 2>/dev/null || true
            continue
        fi

        python "${SC_SCRIPTS}/Cluster_Blast_Extract.py" \
            -i "${ACCEPTED}" \
            -d "${REF_FOR_LOCUS}" \
            -o "${LOCUS_OUTDIR}/blast_extracted" \
            --min_identity "${MIN_IDENTITY}" \
            --min_coverage "${MIN_COVERAGE}" \
            2>>"${LOG_DIR}/${FAMILY}_${LOCUS}_blast.log" || {
            echo "  WARNING: Cluster_Blast_Extract failed for ${FAMILY}/${LOCUS}"
            continue
        }

        # Collect the final filtered FASTA
        EXTRACTED="${LOCUS_OUTDIR}/blast_extracted/Filtered_sequences.fasta"
        if [ -s "${EXTRACTED}" ]; then
            cp "${EXTRACTED}" "${OUTDIR}/${LOCUS}_filtered.fasta"
            N=$(grep -c "^>" "${OUTDIR}/${LOCUS}_filtered.fasta")
            echo "  ${LOCUS}: ${N} sequences retained"
        else
            echo "  ${LOCUS}: 0 sequences after filtering"
        fi

    done
done

echo ""
echo "Filtering complete. Filtered sequences in: ${FILT_DIR}"
echo ""
echo "NOTE: SuperCRUNCH script names and flag names (--min_identity, --min_coverage)"
echo "should be confirmed against your installed version before running at scale."
echo "Check: python \${SC_SCRIPTS}/Cluster_Blast_Extract.py --help"
