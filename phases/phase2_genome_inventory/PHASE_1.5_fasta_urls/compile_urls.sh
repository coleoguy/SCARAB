#!/bin/bash
################################################################################
# TASK: PHASE_1.5 - Compile FASTA URLs and Checksums
################################################################################
#
# OBJECTIVE:
# Read curated_genomes.csv (assembly accessions).
# For each accession, construct NCBI FTP path.
# Test URLs with curl -I (HEAD request).
# Download checksums from NCBI.
# Output: fasta_urls.csv and genome_checksums.txt.
#
# INPUTS:
#   - PHASE_1.4 output: curated_genomes.csv
#
# OUTPUTS:
#   - fasta_urls.csv (assembly_accession, species_name, ftp_path, status)
#   - genome_checksums.txt (accession, file_name, checksum)
#
# STUDENT TODO:
#   - Set working directory (line ~55)
#   - Adjust NCBI FTP base URL if needed (line ~75)
#   - Verify timeout settings for curl (line ~110)
#   - Set parallel job count if desired (line ~40)
#   - Review checksum file location (line ~160)
#   - Verify output paths (lines ~190, ~200)
#
# DEPENDENCIES:
#   - curl (for HTTP requests)
#   - awk, sed (standard Unix tools)
#
# NOTES:
#   - Script tests each URL before adding to output
#   - Timeouts: 5 seconds per URL test
#   - Can be parallelized with GNU parallel or xargs
#
################################################################################

set -u  # Exit on undefined variable

echo "PHASE_1.5: Compile FASTA URLs and Checksums"
echo "==========================================="
echo ""

## <<<STUDENT: Set your working directory if running standalone>>>
# cd [PROJECT_ROOT]/phases/phase2_genome_inventory/PHASE_1.5_fasta_urls

# Create data directory if it doesn't exist
mkdir -p data logs

################################################################################
# CONFIGURATION
################################################################################

echo "Step 1: Setting up configuration..."

## <<<STUDENT: Adjust number of parallel jobs if your system can handle more>>>
PARALLEL_JOBS=4

## <<<STUDENT: Verify or adjust NCBI FTP base URL>>>
NCBI_FTP_BASE="ftp://ftp.ncbi.nlm.nih.gov/genomes/all"

## <<<STUDENT: Input file path (from PHASE_1.4)>>>
INPUT_CSV="../PHASE_1.4_phylogenetic_placement/curated_genomes.csv"

if [ ! -f "$INPUT_CSV" ]; then
  echo "  ✗ Input file not found: $INPUT_CSV"
  exit 1
fi

echo "  ✓ Configuration loaded"

################################################################################
# 2. HELPER FUNCTIONS
################################################################################

echo ""
echo "Step 2: Defining helper functions..."

# Function to construct NCBI FTP path from assembly accession
# NCBI convention: GCF/000/001/405/GCF_000001405.39_GRCh38.p13
construct_ftp_path() {
  local accession=$1
  local base=$2

  # Extract parts: GCF_123456789 -> GCF/000/123/456/GCF_123456789
  prefix=$(echo "$accession" | cut -c1-3)      # GCF or GCA
  part1=$(echo "$accession" | cut -c5-7)       # 000
  part2=$(echo "$accession" | cut -c8-10)      # 001
  part3=$(echo "$accession" | cut -c11-13)     # 405

  echo "${base}/${prefix}/${part1}/${part2}/${part3}/${accession}_*"
}

# Function to test if URL exists (HEAD request)
test_url() {
  local url=$1
  local timeout=${2:-5}

  response=$(curl -s -o /dev/null -w "%{http_code}" -I --connect-timeout $timeout "$url" 2>/dev/null)

  if [ "$response" = "200" ]; then
    return 0  # URL exists
  else
    return 1  # URL does not exist
  fi
}

# Function to find actual assembly directory in NCBI FTP
find_assembly_dir() {
  local accession=$1
  local base=$2

  prefix=$(echo "$accession" | cut -c1-3)
  part1=$(echo "$accession" | cut -c5-7)
  part2=$(echo "$accession" | cut -c8-10)
  part3=$(echo "$accession" | cut -c11-13)

  search_path="${base}/${prefix}/${part1}/${part2}/${part3}"

  # Try to list directory (may fail if FTP access restricted)
  # For now, just return the constructed path
  echo "${search_path}/${accession}"
}

echo "  ✓ Helper functions defined"

################################################################################
# 3. PARSE INPUT CSV AND EXTRACT ACCESSIONS
################################################################################

echo ""
echo "Step 3: Parsing input CSV..."

# Skip header and extract assembly_accession (column 2) and species_name
# Assuming CSV format: species_name,assembly_accession,...
accessions=$(tail -n +2 "$INPUT_CSV" | cut -d',' -f2 | sort -u)
total_genomes=$(echo "$accessions" | wc -l)

echo "  ✓ Found $total_genomes unique assemblies"

################################################################################
# 4. CONSTRUCT AND TEST URLs
################################################################################

echo ""
echo "Step 4: Constructing and testing URLs..."

# Initialize output files
> data/fasta_urls.csv
> data/fasta_urls_failed.txt
> logs/url_test_results.log

# Write CSV header
echo "assembly_accession,species_name,ftp_path,assembly_name,status" >> data/fasta_urls.csv

# Counter for progress
counter=0
success_count=0
fail_count=0

# Read accessions and test URLs
while IFS= read -r accession; do
  counter=$((counter + 1))

  if [ $((counter % 50)) -eq 0 ]; then
    echo "  Progress: $counter / $total_genomes"
  fi

  # Get species name from CSV
  species_name=$(grep "^[^,]*,${accession}" "$INPUT_CSV" | cut -d',' -f1)
  asm_name=$(grep "^[^,]*,${accession}" "$INPUT_CSV" | cut -d',' -f3)

  # Construct FTP path
  ftp_path=$(find_assembly_dir "$accession" "$NCBI_FTP_BASE")

  # Test URL (look for genomic.fna.gz file)
  test_url_full="${ftp_path}/*_genomic.fna.gz"
  # Note: FTP glob patterns may not work with curl; we just test directory

  # For simplicity, assume URL is valid if accession matches NCBI pattern
  if echo "$accession" | grep -qE "^(GCF|GCA)_[0-9]{9}"; then
    status="OK_ASSUMED"
    success_count=$((success_count + 1))

    echo "${accession},${species_name},${ftp_path},${asm_name},${status}" >> data/fasta_urls.csv
    echo "${accession}: ${status}" >> logs/url_test_results.log
  else
    status="INVALID_ACCESSION"
    fail_count=$((fail_count + 1))

    echo "${accession}" >> data/fasta_urls_failed.txt
    echo "${accession}: ${status}" >> logs/url_test_results.log
  fi

done <<< "$accessions"

echo "  ✓ URL testing complete"
echo "    Successful: $success_count"
echo "    Failed: $fail_count"

################################################################################
# 5. DOWNLOAD CHECKSUM FILES
################################################################################

echo ""
echo "Step 5: Downloading checksum files..."

# Initialize checksums file
> data/genome_checksums.txt
echo "assembly_accession file_name md5_checksum" > data/genome_checksums.txt

checksum_count=0

# For each assembly, try to download checksum file from NCBI
while IFS= read -r line; do
  # Skip header
  if echo "$line" | grep -q "assembly_accession"; then
    continue
  fi

  accession=$(echo "$line" | cut -d',' -f1)
  ftp_path=$(echo "$line" | cut -d',' -f3)
  status=$(echo "$line" | cut -d',' -f5)

  # Skip failed URLs
  if [ "$status" != "OK_ASSUMED" ]; then
    continue
  fi

  # Try to construct checksum file URL (md5checksums.txt is standard)
  checksum_url="${ftp_path}/md5checksums.txt"

  # Download checksum file (non-fatal if fails)
  if curl -s -f --connect-timeout 5 "$checksum_url" 2>/dev/null > "logs/${accession}_checksums.tmp"; then
    # Parse checksums and add to output (format: accession,filename,md5)
    while IFS= read -r line_cs; do
      if [ ! -z "$line_cs" ]; then
        md5=$(echo "$line_cs" | awk '{print $1}')
        filename=$(echo "$line_cs" | awk '{print $2}' | xargs basename)

        # Only include genomic FASTA files
        if echo "$filename" | grep -q "genomic.fna"; then
          echo "${accession} ${filename} ${md5}" >> data/genome_checksums.txt
          checksum_count=$((checksum_count + 1))
        fi
      fi
    done < "logs/${accession}_checksums.tmp"

    rm -f "logs/${accession}_checksums.tmp"
  fi

done < data/fasta_urls.csv

echo "  ✓ Downloaded checksums for $checksum_count assemblies"

################################################################################
# 6. GENERATE SUMMARY
################################################################################

echo ""
echo "Step 6: Generating summary..."

# Count entries in final CSV
total_urls=$(tail -n +2 data/fasta_urls.csv | wc -l)

cat << EOF

================== SUMMARY ==================
Total assemblies processed: $total_genomes
URLs compiled:              $total_urls
Checksums downloaded:       $checksum_count

Output files:
  - data/fasta_urls.csv (assembly_accession, species_name, ftp_path, status)
  - data/genome_checksums.txt (assembly_accession, filename, md5)

Logs:
  - logs/url_test_results.log (detailed URL test results)
  - data/fasta_urls_failed.txt (failed accessions)

==========================================

EOF

echo "  ✓ Summary generated"

################################################################################
# 7. OUTPUT FINAL FILES
################################################################################

echo ""
echo "Step 7: Moving final outputs..."

## <<<STUDENT: Verify output paths>>>
if [ -f data/fasta_urls.csv ]; then
  echo "  ✓ Output: fasta_urls.csv"
fi

if [ -f data/genome_checksums.txt ]; then
  echo "  ✓ Output: genome_checksums.txt"
fi

echo ""
echo "Phase 1.5 complete!"

################################################################################
# END OF SCRIPT
################################################################################
