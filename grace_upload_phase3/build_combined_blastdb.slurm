#!/bin/bash
# ============================================================================
# build_combined_blastdb.slurm — Single BLAST database for all 478 genomes
# ============================================================================
# Creates one searchable nucleotide database from all project genomes.
# Sequence headers are prefixed with species name for easy identification.
#
# Output: $SCRATCH/scarab/blastdb/scarab_478 (single db, ~10 files)
# Replaces: phylogenomics/blast_dbs/ (478 individual dbs, ~3,900 files)
#
# Usage after completion:
#   module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0
#   tblastn -db $SCRATCH/scarab/blastdb/scarab_478 -query my_protein.fa \
#           -outfmt '6 qseqid sseqid pident length evalue' -max_target_seqs 5
#
# The sseqid field will be: Species_name|original_scaffold_id
# ============================================================================

#SBATCH --job-name=scarab_blastdb
#SBATCH --partition=medium
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --output=scarab_blastdb_%j.log
#SBATCH --error=scarab_blastdb_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=coleoguy@gmail.com

set -euo pipefail

module load GCC/12.2.0 OpenMPI/4.1.4 BLAST+/2.14.0

PROJECT_DIR="${SCRATCH}/scarab"
SEQFILE="${PROJECT_DIR}/cactus_seqfile_478.txt"
OUTDIR="${PROJECT_DIR}/blastdb"
COMBINED="${OUTDIR}/scarab_478_combined.fna"
DBNAME="${OUTDIR}/scarab_478"

mkdir -p "${OUTDIR}"

echo "============================================================"
echo "Building combined BLAST database"
echo "Started: $(date)"
echo "============================================================"

# Build combined FASTA with species-prefixed headers
# Each genome line in seqfile: "Species_name /path/to/genome.fna"
echo "[1] Building combined FASTA with species-prefixed headers..."
> "${COMBINED}"

N=0
tail -n +2 "${SEQFILE}" | while IFS=' ' read -r SPECIES FASTA_PATH; do
    [ -z "${SPECIES}" ] && continue
    [ -f "${FASTA_PATH}" ] || { echo "  MISSING: ${SPECIES} -> ${FASTA_PATH}"; continue; }
    N=$((N + 1))

    # Stream through genome, prefix each header with species name
    if [[ "${FASTA_PATH}" == *.gz ]]; then
        zcat "${FASTA_PATH}" | awk -v sp="${SPECIES}" '/^>/{sub(/^>/, ">" sp "|"); print; next} {print}'
    else
        awk -v sp="${SPECIES}" '/^>/{sub(/^>/, ">" sp "|"); print; next} {print}' "${FASTA_PATH}"
    fi >> "${COMBINED}"

    [ $((N % 50)) -eq 0 ] && echo "  ${N} genomes processed..."
done

echo "  Combined FASTA: $(du -h ${COMBINED} | cut -f1)"
echo "  Sequences: $(grep -c '^>' ${COMBINED})"

# Build BLAST database
echo ""
echo "[2] Building BLAST database..."
makeblastdb -in "${COMBINED}" \
    -dbtype nucl \
    -out "${DBNAME}" \
    -title "SCARAB 478 beetle genomes" \
    -parse_seqids

echo ""
echo "[3] Verifying..."
blastdbcmd -db "${DBNAME}" -info

# Remove combined FASTA (the db files are sufficient)
rm -f "${COMBINED}"

echo ""
echo "============================================================"
echo "DONE: $(date)"
echo "Database: ${DBNAME}"
echo "Files: $(ls ${DBNAME}.* | wc -l)"
echo ""
echo "Usage:"
echo "  tblastn -db ${DBNAME} -query protein.fa -outfmt 6 -max_target_seqs 5"
echo "============================================================"
