# Genome Download & Curation Instructions

## Overview
The file `genome_catalog.csv` contains 1,121 genome assemblies: 971 Coleoptera (ingroup) and 150 Neuropterida (outgroup: Raphidioptera, Megaloptera, Neuroptera). Your job is to download the genomes we select, verify publications, and flag any use restrictions.

## What You Need Installed

```bash
# NCBI datasets CLI (required for batch downloads)
# Install via conda:
conda install -c conda-forge ncbi-datasets-cli

# Or via direct download:
curl -o datasets 'https://ftp.ncbi.nlm.nih.gov/pub/datasets/command-line/v2/linux-amd64/datasets'
chmod +x datasets
```

## Step 1: Filter the Catalog

Open `genome_catalog.csv` in R and filter to the genomes Heath has approved. The `include_recommended` column has three values:
- `yes` — meets quality thresholds (scaffold N50 >= 1Mb, chromosome or scaffold level)
- `conditional` — borderline quality, may be useful if it fills a phylogenetic gap
- `no` — low quality but still listed for completeness

```r
cat <- read.csv("genome_catalog.csv", stringsAsFactors = FALSE)
# Start with 'yes' genomes
selected <- cat[cat$include_recommended == "yes", ]
# Check family coverage
table(selected$family)
```

## Step 2: Download Genomes

### Option A: NCBI Datasets CLI (Recommended)
Each row in the catalog has a pre-built command in the `ncbi_datasets_command` column. To download a single genome:

```bash
# Example:
datasets download genome accession GCF_000002335.3 --include gff3,rna,protein,genome
unzip ncbi_dataset.zip -d GCF_000002335.3/
```

### Option B: Batch Download
Create a file with accessions (one per line), then:

```bash
# Extract accessions from R
# write.table(selected$assembly_accession, "accessions_to_download.txt", row.names=F, col.names=F, quote=F)

# Batch download
datasets download genome accession --inputfile accessions_to_download.txt \
  --include gff3,genome \
  --filename all_genomes.zip

# Or download individually in a loop (safer for large batches):
while read acc; do
  echo "Downloading $acc..."
  datasets download genome accession "$acc" --include gff3,genome --filename "${acc}.zip"
  sleep 1
done < accessions_to_download.txt
```

### Option C: Direct URL
Each row also has an `ncbi_download_url` column with a direct API link. You can use `wget` or `curl`:

```bash
wget -O GCF_000002335.3.zip "https://api.ncbi.nlm.nih.gov/datasets/v2/genome/accession/GCF_000002335.3/download?include_annotation_type=GENOME_FASTA,GENOME_GFF&filename=GCF_000002335.3.zip"
```

## Step 3: What to Save

For each downloaded genome, you need these files in a folder named by accession:

```
data/genomes/
├── GCF_000002335.3/
│   ├── *.fna          # Genome FASTA (required)
│   ├── *.gff          # Gene annotation GFF3 (if available)
│   ├── assembly_data_report.jsonl  # Assembly metadata
│   └── README.md      # Download provenance
```

**Minimum required**: The genome FASTA (`.fna` or `.fa`) file. Everything else is nice to have.

## Step 4: Verify Publications

For each genome in the catalog, check whether a publication exists:

1. Click the `bioproject_url` link in the catalog
2. On the BioProject page, look for "Publications" in the sidebar
3. If a paper exists, record the DOI in the `publication_doi` column
4. If no paper, check Google Scholar: search `"[assembly_accession]" OR "[species name]" genome`

**Priority**: Focus on the genomes marked `include_recommended = yes`. These are the ones we'll use.

## Step 5: Check Use Restrictions

The `restriction_status` column has preliminary flags:
- `published_open` — RefSeq/representative genome, almost certainly fine to use with citation
- `check_ebp_dtol` — BioProject starts with PRJEB, may be Earth BioGenome Project or Darwin Tree of Life. **CHECK THESE.**
- `to_verify` — Unknown status, needs manual check

### How to check EBP/DToL restrictions:
1. Go to the BioProject page
2. Look for mentions of embargo, data use policy, or Fort Lauderdale agreement
3. Check if there's a consortium data policy (e.g., "data may be used for genome-wide analyses but not single-gene studies before publication")
4. Record findings in `restriction_notes` column

### If in doubt:
- If published with a DOI → generally safe, cite the paper
- If unpublished but no stated restrictions → mark as `prepub_no_restrictions_stated`
- If there's an explicit embargo → mark as `embargo` and note the date/terms
- If the consortium asks for co-authorship or prior approval → mark as `prepub_restricted` and note terms

## Step 6: Flag Conflicts

If you find the same species has multiple assemblies:
- If one is clearly better (newer, higher quality, chromosome-level vs scaffold), keep the better one as primary
- If both have merit (e.g., different populations, one has annotation the other doesn't), keep both and write `CONFLICT: [reason]` in the `conflict_flag` column

## Grace Cluster Notes

If downloading on Grace/FASTER:
```bash
# Load modules
module load NCBI-Datasets-CLI

# Download to scratch (faster I/O)
cd $SCRATCH/scarab_genomes/

# Run batch download as a job
sbatch download_genomes.slurm
```

## Questions?
Email Heath (coleoguy@gmail.com) before:
- Including any genome marked `embargo`
- Spending time on genomes marked `include_recommended = no`
- If you find a genome not in the catalog (add it!)
