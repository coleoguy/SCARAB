#!/bin/bash
# ============================================================================
# P3_blast_selected_loci.slurm — SUPERSEDED by P3_blast_1286_loci.slurm on Grace
# Original plan: 300-500 loci. Actual: 1,286 loci (all mapped genes).
# The running version on Grace is: $SCRATCH/scarab/phylogenomics/P3_blast_1286_loci.slurm
# ============================================================================
#
# Purpose:
#   Search each selected BUSCO protein against all 439 genomes to extract
#   orthologs for gene tree inference.
#
# Strategy:
#   - Process loci in batches (12 parallel BLAST jobs to limit memory)
#   - For each locus: tBLASTn against all 439 genomes (concatenated DB)
#   - Filter: ≥100 aa alignment, ≥30% identity, best hit per genome
#   - Output: per-locus FASTA files with protein sequences from all taxa
#
# Prerequisites:
#   P1 + P2 complete, selected_loci.txt and selected_proteins.fasta exist
#   All 439 genomes in $SCRATCH/scarab/genomes/
#
# Resources: 1 node, 48 cores, 128GB, ~24-48 hours
#
# Usage:
#   sbatch P3_blast_selected_loci.slurm
# ============================================================================

#SBATCH --job-name=scarab_P3_blast
#SBATCH --partition=long
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --output=scarab_P3_blast_%j.log
#SBATCH --error=scarab_P3_blast_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_DIR="${SCRATCH}/scarab"
GENOME_DIR="${PROJECT_DIR}/genomes"
PHYLO_DIR="${PROJECT_DIR}/phylogenomics"
LOCI_LIST="${PHYLO_DIR}/selected_loci.txt"
BUSCO_PROTEINS="${PROJECT_DIR}/nuclear_markers/busco_insecta_odb10/ancestral_variants"
TIP_MAP="${PROJECT_DIR}/data/tree_tip_mapping.csv"

BLAST_DIR="${PHYLO_DIR}/blast_results"
SEQ_DIR="${PHYLO_DIR}/per_gene_seqs"

NCPUS=${SLURM_CPUS_PER_TASK:-48}
MAX_PARALLEL=12      # parallel BLAST jobs (128GB / 12 ≈ 10GB each)
MIN_HIT_LENGTH=100   # minimum alignment length (aa)
MIN_PIDENT=30.0      # minimum identity (%)

echo "============================================================"
echo "SCARAB P.3 — tBLASTn Selected Loci × 439 Genomes"
echo "Job ID: ${SLURM_JOB_ID:-local}"
echo "Started: $(date)"
echo "Node: $(hostname)"
echo "CPUs: ${NCPUS}, Max parallel: ${MAX_PARALLEL}"
echo "============================================================"
echo ""

# ============================================================================
# 0. VERIFY INPUTS
# ============================================================================

echo "[0] Verifying inputs..."

if [ ! -f "${LOCI_LIST}" ]; then
    echo "ERROR: ${LOCI_LIST} not found. Run P2_select_loci.sh first."
    exit 1
fi

N_LOCI=$(wc -l < "${LOCI_LIST}")
echo "  Loci to process: ${N_LOCI}"

N_GENOMES=$(find "${GENOME_DIR}" -name "*.fna" | wc -l)
echo "  Genomes available: ${N_GENOMES}"

if [ "${N_GENOMES}" -lt 439 ]; then
    echo "WARNING: Expected 439 genomes, found ${N_GENOMES}"
fi

mkdir -p "${BLAST_DIR}" "${SEQ_DIR}"

# ============================================================================
# 1. BUILD PER-GENOME BLAST DATABASES (if not already done)
# ============================================================================

echo "[1] Building/verifying per-genome BLAST databases..."

module load GCC/12.2.0 BLAST+/2.14.0

DB_DIR="${PHYLO_DIR}/blast_dbs"
mkdir -p "${DB_DIR}"

build_db() {
    local genome_fna="$1"
    local basename=$(basename "${genome_fna}" .fna)
    local db_path="${DB_DIR}/${basename}"
    if [ ! -f "${db_path}.nhr" ] && [ ! -f "${db_path}.nsq" ]; then
        makeblastdb -in "${genome_fna}" -dbtype nucl -out "${db_path}" \
            -title "${basename}" > /dev/null 2>&1
    fi
}
export -f build_db
export DB_DIR

# Build DBs in parallel (quick, mostly I/O)
find "${GENOME_DIR}" -name "*.fna" | \
    xargs -P ${MAX_PARALLEL} -I{} bash -c 'build_db "$@"' _ {}

N_DBS=$(ls "${DB_DIR}"/*.nsq 2>/dev/null | wc -l)
echo "  BLAST databases ready: ${N_DBS}"

# ============================================================================
# 2. BUILD TIP NAME LOOKUP
# ============================================================================

echo "[2] Building accession → tip name lookup..."

# TIP_MAP format: accession,species_name,tip_label,...
# We need: genome filename → tip label
declare -A ACC_TO_TIP

if [ -f "${TIP_MAP}" ]; then
    while IFS=',' read -r acc species tip rest; do
        # Skip header
        [ "${acc}" = "accession" ] && continue
        ACC_TO_TIP["${acc}"]="${tip}"
    done < "${TIP_MAP}"
    echo "  Loaded ${#ACC_TO_TIP[@]} accession→tip mappings"
else
    echo "WARNING: ${TIP_MAP} not found. Using filenames as tip labels."
fi

# ============================================================================
# 3. tBLASTn EACH LOCUS × ALL GENOMES
# ============================================================================

echo "[3] Running tBLASTn for ${N_LOCI} loci..."

COMPLETED=0
FAILED=0

process_locus() {
    local BUSCO_ID="$1"
    local QUERY_FA="${BUSCO_PROTEINS}/${BUSCO_ID}.faa"
    local OUT_DIR="${SEQ_DIR}/${BUSCO_ID}"
    local BLAST_RESULT="${BLAST_DIR}/${BUSCO_ID}_hits.tsv"
    local GENE_FASTA="${SEQ_DIR}/${BUSCO_ID}.fasta"

    if [ ! -f "${QUERY_FA}" ]; then
        echo "  SKIP: No FASTA for ${BUSCO_ID}" >&2
        return 1
    fi

    # Skip if already done
    if [ -f "${GENE_FASTA}" ] && [ -s "${GENE_FASTA}" ]; then
        return 0
    fi

    # Query protein sequence
    QUERY_SEQ=$(grep -v "^>" "${QUERY_FA}" | tr -d '\n')
    QUERY_LEN=${#QUERY_SEQ}

    # BLAST against all genome DBs, collect best hit per genome
    > "${BLAST_RESULT}"

    for DB_FILE in "${DB_DIR}"/*.nsq; do
        DB_BASE="${DB_FILE%.nsq}"
        DB_NAME=$(basename "${DB_BASE}")

        tblastn -query "${QUERY_FA}" \
                -db "${DB_BASE}" \
                -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore sseq" \
                -evalue 1e-5 \
                -max_target_seqs 1 \
                -num_threads 1 \
                2>/dev/null | \
            awk -v db="${DB_NAME}" -v minlen="${MIN_HIT_LENGTH}" -v minpid="${MIN_PIDENT}" \
                -F'\t' '$4 >= minlen && $3 >= minpid { print db "\t" $0; exit }' \
                >> "${BLAST_RESULT}"
    done

    # Extract protein sequences and build per-gene FASTA
    > "${GENE_FASTA}"

    while IFS=$'\t' read -r db_name qid sid pident alen mm gapopen qs qe ss se eval bits sseq; do
        # Get tip label
        local tip="${db_name}"
        # Clean up protein sequence (remove gaps from translated hit)
        local clean_seq=$(echo "${sseq}" | tr -d '-' | tr -d '*')
        if [ -n "${clean_seq}" ]; then
            echo ">${tip}" >> "${GENE_FASTA}"
            echo "${clean_seq}" >> "${GENE_FASTA}"
        fi
    done < "${BLAST_RESULT}"

    local n_taxa=$(grep -c "^>" "${GENE_FASTA}" 2>/dev/null || echo 0)
    echo "  ${BUSCO_ID}: ${n_taxa} taxa" >&2
}

export -f process_locus
export BUSCO_PROTEINS BLAST_DIR SEQ_DIR DB_DIR MIN_HIT_LENGTH MIN_PIDENT

# Process loci with controlled parallelism
cat "${LOCI_LIST}" | xargs -P ${MAX_PARALLEL} -I{} bash -c 'process_locus "$@"' _ {}

# ============================================================================
# 4. SUMMARY
# ============================================================================

echo ""
echo "[4] Summary..."

N_DONE=0
N_GOOD=0
for FASTA in "${SEQ_DIR}"/*.fasta; do
    [ -f "${FASTA}" ] || continue
    N_DONE=$((N_DONE + 1))
    N_TAXA=$(grep -c "^>" "${FASTA}" 2>/dev/null || echo 0)
    if [ "${N_TAXA}" -ge 100 ]; then
        N_GOOD=$((N_GOOD + 1))
    fi
done

echo ""
echo "============================================================"
echo "P.3 COMPLETE"
echo "============================================================"
echo "  Loci processed: ${N_DONE} / ${N_LOCI}"
echo "  Loci with ≥100 taxa: ${N_GOOD}"
echo "  Results: ${SEQ_DIR}/"
echo ""
echo "NEXT STEP: P.4 — Per-gene MAFFT alignments"
echo "  Submit: sbatch P4_align_and_gene_trees.slurm"
echo "============================================================"
echo "Finished: $(date)"
