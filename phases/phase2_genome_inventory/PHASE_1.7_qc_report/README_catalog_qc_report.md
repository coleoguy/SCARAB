# SCARAB - Genome Catalog QC Report Generator

## Overview

The `catalog_qc_report.R` script reads the actual `genome_catalog.csv` file and generates a comprehensive 8-page PDF quality control report with accompanying text summary.

## Requirements

- R (with base graphics; no external packages required)
- Input file: `../../../data/genomes/genome_catalog.csv`

## Usage

```bash
Rscript catalog_qc_report.R
```

The script will:
1. Read the genome catalog CSV
2. Validate and preprocess the data
3. Generate `qc_report.pdf` (8-page professional report)
4. Generate `qc_summary.txt` (text summary with detailed statistics)

## Output Files

### qc_report.pdf
A publication-quality 8-page PDF report:

- **PAGE 1**: Title page
  - Report title and generation date
  - Total assembly and species counts

- **PAGE 2**: Assembly-level overview
  - Bar chart: assemblies by assembly level (Chromosome/Scaffold/Contig)
  - Bar chart: assembly level distribution split by role (ingroup vs outgroup)

- **PAGE 3**: Family coverage analysis
  - Horizontal bar chart of top 30 families by assembly count
  - Color-coded by taxonomic suborder (Polyphaga, Adephaga, Archostemata)

- **PAGE 4**: Quality metrics
  - Histogram of scaffold N50 values (log10 scale)
  - Histogram of genome sizes
  - Scatter plot: genome size vs scaffold N50 (log-log), colored by assembly level

- **PAGE 5**: Quality heuristic breakdown
  - Stacked bar chart: include_recommended status (yes/conditional/no) for top 20 families
  - Pie chart: overall quality distribution across entire dataset

- **PAGE 6**: Restriction status
  - Bar chart of restriction status categories
  - Table of any embargoed or restricted genomes with annotations

- **PAGE 7**: Multi-assembly species analysis
  - Table: species with >2 assemblies, showing count and best assembly level
  - Recommendations for conflict resolution and deduplication

- **PAGE 8**: Outgroup summary
  - Summary statistics for Neuropterida (outgroup) genomes
  - Table: all outgroup assemblies with family, level, and N50
  - Assessment of outgroup coverage quality

### qc_summary.txt
Detailed text summary including:
- Dataset overview and role distribution
- Assembly level breakdown with percentages
- Quality metrics (genome size and scaffold N50 statistics)
- Quality recommendation distribution
- Restriction status breakdown
- Top 20 families by assembly count
- Multi-assembly species requiring conflict resolution
- Outgroup genome assessment
- Data availability statistics (annotation, publications)

## Features

- **Base R graphics only**: No external dependencies (ggplot2)
- **Publication-quality plots**: Properly configured margins, colors, and labels
- **Smart color schemes**:
  - Assembly levels: Green (Chromosome), Blue (Scaffold), Red (Contig)
  - Suborders: Blue (Polyphaga), Red (Adephaga), Orange (Archostemata)
  - Quality: Green (Recommended), Orange (Conditional), Red (Not Recommended)
- **Robust data handling**: Validates numeric columns, handles missing values
- **Comprehensive statistics**: Summary counts, percentages, and quality metrics
- **Clean code**: Well-commented, organized by section

## Data Preprocessing

The script automatically:
1. Converts numeric columns to appropriate types
2. Handles missing values (scaffold_N50, genome_size, etc.)
3. Filters out invalid entries (N50 values ≤ 0)
4. Validates family and taxonomic information
5. Identifies role (ingroup vs outgroup) genomes

## Customization

To modify the report:
- Edit color schemes in the relevant page sections
- Adjust layout sizes via `layout()` and `par()` calls
- Modify histogram breaks, plot margins, or font sizes
- Change which families are displayed (currently top 20-30)

## Troubleshooting

- **File not found**: Ensure script is run from the correct directory
- **Missing columns**: Verify genome_catalog.csv has all required columns
- **Empty plots**: Check that data file contains valid entries with non-zero values
- **PDF creation fails**: Ensure write permissions in the script's directory

## Column Requirements

The genome_catalog.csv must contain:
- `species_name`, `genus`, `family`, `superfamily`, `suborder`
- `assembly_level`, `assembly_accession`, `assembly_name`
- `genome_size_mb`, `scaffold_N50`, `contig_N50`
- `number_of_scaffolds`, `gc_percent`
- `gene_annotation_available`, `restriction_status`
- `include_recommended`, `role` (ingroup/outgroup)
- Additional metadata fields as available

## Author

SCARAB Project
Generated: March 21, 2026
