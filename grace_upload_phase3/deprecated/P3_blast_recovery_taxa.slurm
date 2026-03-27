#!/bin/bash
#SBATCH --job-name=scarab_P3_recovery
#SBATCH --output=scarab_P3_recovery_%j.out
#SBATCH --error=scarab_P3_recovery_%j.err
#SBATCH --partition=medium
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=blackmon@tamu.edu

#===============================================================================
# P3 BLAST supplement: run 1,286-gene tBLASTn on 39 recovery genomes
#===============================================================================
# This is identical to P3_blast_1286_loci.slurm but only processes the
# recovery genomes. Results integrate seamlessly with the main P3 output
# because they use the same directory structure and file naming.
#
# Run AFTER download_recovery_genomes.sh and the main P3 job complete.
#===============================================================================

set -euo pipefail

SCARAB="${SCRATCH}/scarab"
PHYLO="${SCARAB}/phylogenomics"
GENOME_DIR="${SCARAB}/genomes"
BLAST_DB_DIR="${PHYLO}/blast_dbs"
GENE_DIR="${PHYLO}/per_gene_fasta"
PROTEINS="${PHYLO}/selected_proteins.fasta"
LOCI_LIST="${PHYLO}/selected_loci.txt"

# Recovery genome accessions
RECOVERY_ACCESSIONS=(
    GCA_030710515.1 GCA_044115395.2 GCA_050578095.1 GCA_047676225.1
    GCA_965278915.1 GCA_050941775.1 GCA_055275695.1 GCA_048127345.1
    GCA_031761425.1 GCA_030704885.1 GCA_031893035.2 GCA_034092305.1
    GCA_021725515.1 GCA_029955175.1 GCA_030704895.1 GCA_030620095.1
    GCA_013368075.1 GCA_050947525.1 GCA_052696345.1 GCA_036346125.1
    GCA_028455855.1 GCA_030674115.1 GCA_029963825.1 GCA_020740385.1
    GCA_018344505.1 GCA_047371185.1 GCA_020654155.1 GCA_036346225.1
    GCA_036326145.1 GCA_029963845.1 GCA_037954035.1 GCA_036346155.1
    GCA_036325965.1 GCA_051294475.1 GCA_982185335.1 GCA_055532135.1
    GCA_034508555.1 GCA_036346205.1 GCA_032362365.1
)

# Species name mapping (accession -> tip label)
declare -A SPECIES_MAP
SPECIES_MAP=(
    [GCA_030710515.1]="Abscondita_cerata"
    [GCA_044115395.2]="Agriotes_pubescens"
    [GCA_050578095.1]="Araecerus_fasciculatus"
    [GCA_047676225.1]="Asbolus_verrucosus"
    [GCA_965278915.1]="Astagobius_angustatus"
    [GCA_050941775.1]="Batocera_rufomaculata"
    [GCA_055275695.1]="Calosoma_relictum"
    [GCA_048127345.1]="Carabus_depressus"
    [GCA_031761425.1]="Cosmopolites_sordidus"
    [GCA_030704885.1]="Cynegetis_impunctata"
    [GCA_031893035.2]="Dermolepida_albohirtum"
    [GCA_034092305.1]="Diaprepes_abbreviatus"
    [GCA_021725515.1]="Epicauta_chinensis"
    [GCA_029955175.1]="Exocentrus_adspersus"
    [GCA_030704895.1]="Henosepilachna_vigintioctopunctata"
    [GCA_030620095.1]="Kuschelorhynchus_macadamiae"
    [GCA_013368075.1]="Lamprigera_yunnana"
    [GCA_050947525.1]="Lampyris_noctiluca"
    [GCA_052696345.1]="Lethrus_scoparius"
    [GCA_036346125.1]="Lycocerus_yunnanus"
    [GCA_028455855.1]="Meloe_dianella"
    [GCA_030674115.1]="Micraspis_discolor"
    [GCA_029963825.1]="Molorchus_minor"
    [GCA_020740385.1]="Mylabris_phalerata"
    [GCA_018344505.1]="Nebria_ingens_riversi"
    [GCA_047371185.1]="Neoclytus_acuminatus_acuminatus"
    [GCA_020654155.1]="Novius_pumilus"
    [GCA_036346225.1]="Platerodrilus_igneus"
    [GCA_036326145.1]="Rhagophthalmus_giganteus"
    [GCA_029963845.1]="Rhamnusium_bicolor"
    [GCA_037954035.1]="Rosalia_funebris"
    [GCA_036346155.1]="Sinelater_perroti"
    [GCA_036325965.1]="Sinopyrophorus_schimmeli"
    [GCA_051294475.1]="Sternochetus_mangiferae"
    [GCA_982185335.1]="Troglocharinus_ferreri"
    [GCA_055532135.1]="Trypodendron_lineatum"
    [GCA_034508555.1]="Venustoraphidia_nigricollis"
    [GCA_036346205.1]="Vesta_saturnalis"
    [GCA_032362365.1]="Zygogramma_bicolorata"
)

module load GCC/12.3.0 BLAST+/2.14.1

PARALLEL=12  # conservative for 128 GB
TOTAL=${#RECOVERY_ACCESSIONS[@]}
echo "P3 Recovery BLAST: ${TOTAL} genomes x 1,286 loci"
echo "Started: $(date)"

# ---------------------------------------------------------------------------
# Phase A: Build BLAST databases for recovery genomes
# ---------------------------------------------------------------------------
echo ""
echo "=== Phase A: Building BLAST databases ==="
mkdir -p "${BLAST_DB_DIR}"

for ACC in "${RECOVERY_ACCESSIONS[@]}"; do
    SP="${SPECIES_MAP[$ACC]}"
    DB="${BLAST_DB_DIR}/${SP}"

    if [[ -f "${DB}.nsq" || -f "${DB}.ndb" ]]; then
        echo "  DB exists for ${SP}, skipping"
        continue
    fi

    # Find the genome file
    GENOME=$(ls "${GENOME_DIR}/${ACC}"*_genomic.fna.gz 2>/dev/null | head -1)
    if [[ -z "${GENOME}" ]]; then
        echo "  WARNING: genome not found for ${SP} (${ACC})"
        continue
    fi

    echo "  Building DB for ${SP}..."
    zcat "${GENOME}" | makeblastdb -in - -dbtype nucl -out "${DB}" \
        -title "${SP}" -parse_seqids 2>/dev/null
done

echo "BLAST databases complete: $(date)"

# ---------------------------------------------------------------------------
# Phase B: Run tBLASTn for each locus x each recovery genome
# ---------------------------------------------------------------------------
echo ""
echo "=== Phase B: Running tBLASTn ==="
mkdir -p "${GENE_DIR}"

# Read loci list
mapfile -t LOCI < "${LOCI_LIST}"
NUM_LOCI=${#LOCI[@]}
echo "  Loci: ${NUM_LOCI}"

# Process genomes in batches to control parallelism
for ACC in "${RECOVERY_ACCESSIONS[@]}"; do
    SP="${SPECIES_MAP[$ACC]}"
    DB="${BLAST_DB_DIR}/${SP}"

    # Check DB exists
    if [[ ! -f "${DB}.nsq" && ! -f "${DB}.ndb" ]]; then
        echo "  Skipping ${SP}: no BLAST DB"
        continue
    fi

    echo "  BLASTing ${SP} (${NUM_LOCI} loci)..."

    # Run all loci for this genome in parallel batches
    RUNNING=0
    for LOCUS in "${LOCI[@]}"; do
        GENE_FASTA="${GENE_DIR}/${LOCUS}"

        # Extract this protein query
        QUERY_FILE="${PHYLO}/tmp_query_${LOCUS}.fasta"
        if [[ ! -f "${QUERY_FILE}" ]]; then
            # Extract from selected_proteins.fasta
            awk -v id="${LOCUS}" '
                BEGIN {found=0}
                /^>/ {found = ($0 ~ id) ? 1 : 0}
                found {print}
            ' "${PROTEINS}" > "${QUERY_FILE}"
        fi

        # Run tBLASTn
        (
            RESULT=$(tblastn -query "${QUERY_FILE}" -db "${DB}" \
                -evalue 1e-10 -max_target_seqs 1 -outfmt "6 sseqid sstart send sframe qstart qend evalue bitscore" \
                -num_threads 1 2>/dev/null | head -1)

            if [[ -n "${RESULT}" ]]; then
                # Extract the hit region and append to gene FASTA
                SSEQID=$(echo "${RESULT}" | cut -f1)
                SSTART=$(echo "${RESULT}" | cut -f2)
                SEND=$(echo "${RESULT}" | cut -f3)

                # Get sequence from BLAST DB
                if [[ ${SSTART} -le ${SEND} ]]; then
                    RANGE="${SSTART}-${SEND}"
                    STRAND="plus"
                else
                    RANGE="${SEND}-${SSTART}"
                    STRAND="minus"
                fi

                SEQ=$(blastdbcmd -db "${DB}" -entry "${SSEQID}" \
                    -range "${RANGE}" -strand "${STRAND}" 2>/dev/null | \
                    grep -v "^>" | tr -d '\n')

                if [[ -n "${SEQ}" ]]; then
                    echo ">${SP}" >> "${GENE_FASTA}"
                    echo "${SEQ}" >> "${GENE_FASTA}"
                fi
            fi
        ) &

        RUNNING=$((RUNNING + 1))
        if [[ ${RUNNING} -ge ${PARALLEL} ]]; then
            wait
            RUNNING=0
        fi
    done
    wait
done

# Clean up temp query files
rm -f "${PHYLO}"/tmp_query_*.fasta

echo ""
echo "=========================================="
echo "P3 Recovery BLAST complete: $(date)"
echo "Results merged into ${GENE_DIR}/"
echo "Proceed to P4/P5 (MAFFT + gene trees) on full 478-taxon dataset"
echo "=========================================="
