#!/bin/bash
################################################################################
#
# PHASE 4.5 — DATA RELEASE PACKAGING
# Coleoptera Whole-Genome Alignment: Visualization & Manuscript
#
# PURPOSE:
#   Create structured release package for public distribution.
#   Organize all final data files, generate manifest and README.
#   Produce tar.gz archive suitable for data deposition.
#
# OUTPUT:
#   - scarab_release/     Release directory structure
#   - scarab_release.tar.gz   Compressed archive
#   - package_release.log                  Processing log
#
# AUTHOR: SCARAB Team
# DATE: 2026-03-21
#
################################################################################

set -e  # Exit on error

## <<<STUDENT: Set PROJECT_ROOT to your SCARAB project directory>>>
PROJECT_ROOT="${SCARAB_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"

# ============================================================================
# 0. SETUP & PATHS
# ============================================================================

## <<<STUDENT: Update base directory path>>>
BASE_DIR="${PROJECT_ROOT}/phases"

## <<<STUDENT: Update output directory>>>
OUTPUT_DIR="${PROJECT_ROOT}/phases/phase5_viz_manuscript/PHASE_4.5_data_release"

RELEASE_DIR="${OUTPUT_DIR}/scarab_release"
LOG_FILE="${OUTPUT_DIR}/package_release.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No color

# Logging function
log_msg() {
  local msg=$1
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[${timestamp}] ${msg}" | tee -a "${LOG_FILE}"
}

# ============================================================================
# 1. INITIALIZE LOG AND DIRECTORIES
# ============================================================================

mkdir -p "${OUTPUT_DIR}"
> "${LOG_FILE}"

log_msg "=== PHASE 4.5: Data Release Packaging ==="
log_msg "Release directory: ${RELEASE_DIR}"

# Create release directory structure
rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"/{data,figures,scripts,docs,metadata}

log_msg "Created directory structure"

# ============================================================================
# 2. COPY FINAL DATA FILES
# ============================================================================

log_msg "Copying final data files..."

# Phase 4 (rearrangement analysis) outputs
## <<<STUDENT: Adjust file paths to match your actual output locations>>>

PHASE3_OUTPUT="${BASE_DIR}/phase4_rearrangements"

copy_file() {
  local source=$1
  local dest=$2

  if [ -f "${source}" ]; then
    cp "${source}" "${dest}"
    log_msg "  ✓ Copied $(basename ${source})"
  else
    log_msg "  ⚠ WARNING: File not found: ${source}"
  fi
}

# Rearrangement data
copy_file "${PHASE3_OUTPUT}/PHASE_3.2_filtering/rearrangements_confirmed.tsv" \
          "${RELEASE_DIR}/data/rearrangements_confirmed.tsv"

copy_file "${PHASE3_OUTPUT}/PHASE_3.2_filtering/rearrangements_inferred.tsv" \
          "${RELEASE_DIR}/data/rearrangements_inferred.tsv"

copy_file "${PHASE3_OUTPUT}/PHASE_3.3_tree_mapping/rearrangements_mapped.tsv" \
          "${RELEASE_DIR}/data/rearrangements_mapped.tsv"

copy_file "${PHASE3_OUTPUT}/PHASE_3.4_branch_stats/rearrangements_per_branch.tsv" \
          "${RELEASE_DIR}/data/rearrangements_per_branch.tsv"

copy_file "${PHASE3_OUTPUT}/PHASE_3.6_ancestral_karyotypes/ancestral_karyotypes.csv" \
          "${RELEASE_DIR}/data/ancestral_karyotypes.csv"

copy_file "${PHASE3_OUTPUT}/PHASE_3.6_ancestral_karyotypes/ancestral_linkage_groups.csv" \
          "${RELEASE_DIR}/data/ancestral_linkage_groups.csv"

# Synteny data
PHASE2_OUTPUT="${BASE_DIR}/phase3_alignment_synteny"
copy_file "${PHASE2_OUTPUT}/synteny_anchored.tsv" \
          "${RELEASE_DIR}/data/synteny_anchored.tsv"

copy_file "${PHASE2_OUTPUT}/constraint_tree.nwk" \
          "${RELEASE_DIR}/data/constraint_tree.nwk"

# ============================================================================
# 3. COPY FIGURE FILES
# ============================================================================

log_msg "Copying figure files..."

PHASE4_OUTPUT="${BASE_DIR}/phase5_viz_manuscript"

copy_figure() {
  local source=$1
  local dest_name=$2

  if [ -f "${source}" ]; then
    cp "${source}" "${RELEASE_DIR}/figures/${dest_name}"
    log_msg "  ✓ Copied figure: ${dest_name}"
  else
    log_msg "  ⚠ WARNING: Figure not found: ${source}"
  fi
}

copy_figure "${PHASE4_OUTPUT}/PHASE_4.1_interactive_tree/beetle_tree_rearrangements.pdf" \
            "Figure_1_phylogenetic_tree.pdf"

copy_figure "${PHASE4_OUTPUT}/PHASE_4.2_synteny_dotplots/synteny_dotplots.pdf" \
            "Figure_2_synteny_dotplots.pdf"

copy_figure "${PHASE4_OUTPUT}/PHASE_4.3_hotspot_viz/hotspot_figures.pdf" \
            "Figure_3_hotspot_analysis.pdf"

copy_figure "${PHASE4_OUTPUT}/PHASE_4.4_ancestral_figures/ancestral_karyotype_figures.pdf" \
            "Figure_4_ancestral_karyotypes.pdf"

# ============================================================================
# 4. COPY AND ORGANIZE SCRIPTS
# ============================================================================

log_msg "Organizing analysis scripts..."

mkdir -p "${RELEASE_DIR}/scripts/phase3" "${RELEASE_DIR}/scripts/phase4"

# Phase 3 scripts
for script in "${PHASE3_OUTPUT}"/PHASE_3.*/call_breakpoints.R \
              "${PHASE3_OUTPUT}"/PHASE_3.*/filter_rearrangements.R \
              "${PHASE3_OUTPUT}"/PHASE_3.*/map_to_tree.R \
              "${PHASE3_OUTPUT}"/PHASE_3.*/branch_statistics.R \
              "${PHASE3_OUTPUT}"/PHASE_3.*/compare_literature.R \
              "${PHASE3_OUTPUT}"/PHASE_3.*/reconstruct_karyotypes.R \
              "${PHASE3_OUTPUT}"/PHASE_3.*/phase3_report.R; do
  if [ -f "${script}" ]; then
    cp "${script}" "${RELEASE_DIR}/scripts/phase3/" 2>/dev/null || true
  fi
done

log_msg "  ✓ Copied Phase 3 scripts"

# Phase 4 scripts
for script in "${PHASE4_OUTPUT}"/PHASE_4.*/plot_tree.R \
              "${PHASE4_OUTPUT}"/PHASE_4.*/make_dotplots.R \
              "${PHASE4_OUTPUT}"/PHASE_4.*/hotspot_figures.R \
              "${PHASE4_OUTPUT}"/PHASE_4.*/ancestral_karyotype_figures.R; do
  if [ -f "${script}" ]; then
    cp "${script}" "${RELEASE_DIR}/scripts/phase4/" 2>/dev/null || true
  fi
done

log_msg "  ✓ Copied Phase 4 scripts"

# ============================================================================
# 5. GENERATE MANIFEST
# ============================================================================

log_msg "Generating manifest.csv..."

manifest_file="${RELEASE_DIR}/manifest.csv"

cat > "${manifest_file}" << 'EOF'
filename,file_type,description,version,size_bytes,md5sum,date_created
EOF

# Add data files
for file in "${RELEASE_DIR}/data"/*; do
  if [ -f "${file}" ]; then
    filename=$(basename "${file}")
    filetype=$(echo "${filename}" | grep -o '\.[^.]*$' | tr -d '.')
    size=$(stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo "0")
    md5=$(md5sum "${file}" 2>/dev/null | awk '{print $1}' || echo "N/A")
    date=$(date -u '+%Y-%m-%d')

    case "${filename}" in
      *confirmed*)
        desc="High-confidence rearrangements (≥2 species support)"
        ;;
      *inferred*)
        desc="Inferred rearrangements (single species)"
        ;;
      *mapped*)
        desc="Rearrangements mapped to phylogenetic tree branches"
        ;;
      *per_branch*)
        desc="Per-branch rearrangement statistics and rates"
        ;;
      *karyotype*)
        desc="Ancestral chromosome numbers and structures"
        ;;
      *linkage*)
        desc="Details of ancestral linkage groups"
        ;;
      *synteny*)
        desc="Anchored synteny blocks across species"
        ;;
      *tree*)
        desc="Phylogenetic tree in Newick format"
        ;;
      *)
        desc="Data file"
        ;;
    esac

    echo "${filename},${filetype},${desc},1.0,${size},${md5},${date}" >> "${manifest_file}"
  fi
done

log_msg "  ✓ Manifest created with $(wc -l < ${manifest_file} | tr -d ' ') entries"

# ============================================================================
# 6. CREATE README
# ============================================================================

log_msg "Generating README.md..."

readme_file="${RELEASE_DIR}/README.md"

cat > "${readme_file}" << 'EOF'
# Coleoptera Whole-Genome Alignment: Rearrangement Analysis Release

## Overview

This dataset contains the results of a comprehensive whole-genome alignment analysis of ~50 beetle (Coleoptera) genomes, focusing on chromosomal rearrangements and ancestral karyotype reconstruction.

## Contents

### Data Files (`data/`)

- **rearrangements_confirmed.tsv**: High-confidence rearrangement calls supported by ≥2 independent species
  - Columns: rearrangement_id, type, species, ancestral_node, chr_involved, breakpoint_1, breakpoint_2, confidence_lower, confidence_upper, supporting_blocks

- **rearrangements_inferred.tsv**: Rearrangements inferred by synteny and parsimony (single species support)
  - Same structure as confirmed rearrangements

- **rearrangements_mapped.tsv**: Rearrangements assigned to specific branches in the phylogenetic tree
  - Additional columns: branch_id, ancestral_node_branch, derived_node_branch, is_reversion, confidence_mapping

- **rearrangements_per_branch.tsv**: Summary statistics per phylogenetic branch
  - Columns: branch_id, ancestral_node, derived_node, fusions, fissions, inversions, translocations, total_rearrangements, supporting_species, branch_length_myr, rearrangement_rate, is_hotspot

- **ancestral_karyotypes.csv**: Reconstructed chromosome numbers (2n) for major ancestral nodes
  - Columns: ancestral_node, n_linkage_groups, inferred_2n, n_species_supporting, avg_block_size_kb, notes

- **ancestral_linkage_groups.csv**: Detailed characteristics of ancestral chromosomes
  - Columns: ancestral_node, chromosome_id, n_synteny_blocks, total_length_mb, n_extant_species_mapping, description

- **synteny_anchored.tsv**: Synteny blocks aligned between extant and ancestral genomes
  - Columns: block_id, extant_species, extant_chr, extant_start, extant_end, ancestral_species, ancestral_chr, ancestral_start, ancestral_end, orientation

- **constraint_tree.nwk**: Phylogenetic tree in Newick format with branch lengths

### Figures (`figures/`)

- **Figure_1_phylogenetic_tree.pdf**: Beetle phylogeny with branches colored by rearrangement rate
- **Figure_2_synteny_dotplots.pdf**: Comparative dotplots between representative species pairs
- **Figure_3_hotspot_analysis.pdf**: Rearrangement hotspots and rate distributions
- **Figure_4_ancestral_karyotypes.pdf**: Schematic chromosome diagrams for major ancestral nodes

### Scripts (`scripts/`)

- **phase3/**: Scripts for rearrangement detection, filtering, and analysis
- **phase4/**: Scripts for visualization and figure generation

### Metadata

- **manifest.csv**: Complete file listing with file types and checksums
- **README.md**: This file

## Key Statistics

- Total rearrangement events identified: [STUDENT: fill in]
- Rearrangement types:
  - Fusions: [count]
  - Fissions: [count]
  - Inversions: [count]
  - Translocations: [count]
- Hotspot branches identified: [count]
- Ancestral nodes reconstructed: [count]

## Methods Summary

### Phase 3: Rearrangement Analysis
1. **Breakpoint Calling**: Compared synteny block order and orientation to identify rearrangements
2. **Filtering**: Applied quality thresholds; classified as confirmed, inferred, or artifact
3. **Tree Mapping**: Assigned rearrangements to phylogenetic branches using parsimony
4. **Branch Statistics**: Computed rearrangement rates normalized by branch length (My)
5. **Ancestral Reconstruction**: Inferred chromosome numbers and structure for key nodes
6. **Literature Comparison**: Validated results against published karyotype data

### Phase 4: Visualization
Generated publication-quality figures including:
- Phylogenetic trees with rate coloring
- Synteny dotplots
- Rearrangement hotspot analysis
- Ancestral karyotype diagrams

## Data Quality Notes

- Rearrangement calls supported by synteny conservation across species
- Confidence intervals provided for breakpoint positions (±5kb typical)
- Artifacts flagged: small blocks (<1kb), single supporting blocks
- Literature validation: [STUDENT: describe agreement rate with published data]

## Citation

Please cite this work as:

> [Citation to be added upon publication]

## Contact

[STUDENT: Add contact information]

## License

[STUDENT: Specify data availability and license terms]

## Funding

This research was supported by [STUDENT: Add funding information].

---

**Release Version**: 1.0
**Creation Date**: 2026-03-21
**Last Updated**: 2026-03-21
EOF

log_msg "  ✓ README.md created"

# ============================================================================
# 7. CREATE DATA DICTIONARY
# ============================================================================

log_msg "Generating data dictionary..."

dict_file="${RELEASE_DIR}/docs/DATA_DICTIONARY.md"
mkdir -p "${RELEASE_DIR}/docs"

cat > "${dict_file}" << 'EOF'
# Data Dictionary

## Rearrangement Tables

### Common Columns

- **rearrangement_id**: Unique identifier (e.g., REARR_001)
- **type**: Rearrangement type [fusion, fission, inversion, translocation]
- **species**: Extant species exhibiting the rearrangement
- **ancestral_node**: Inferred ancestral state being compared
- **chr_involved**: Chromosome(s) involved (format: chr1+chr2 for fusion, chr1/chr2 for fission)
- **breakpoint_1, breakpoint_2**: Genomic coordinates of rearrangement boundaries (bp)
- **confidence_lower, confidence_upper**: Confidence interval for breakpoint positions
- **supporting_blocks**: Number of synteny blocks supporting the call

### Rearrangements_mapped.tsv Additional Columns

- **branch_id**: Phylogenetic branch assignment (format: ancestral_node->derived_node)
- **ancestral_node_branch**: Branch ancestral node
- **derived_node_branch**: Branch derived node (species or internal node)
- **is_reversion**: Flag for potential reversion events (TRUE/FALSE)
- **parsimony_score**: Number of species exhibiting related rearrangements
- **confidence_mapping**: Mapping confidence level [high, medium, low]

### Rearrangements_per_branch.tsv

- **branch_id**: Phylogenetic branch identifier
- **ancestral_node, derived_node**: Branch endpoints
- **fusions, fissions, inversions, translocations**: Count of each rearrangement type on branch
- **total_rearrangements**: Sum of all rearrangement events
- **supporting_species**: Number of unique species on this branch
- **branch_length_myr**: Branch length in millions of years
- **rearrangement_rate**: Rearrangements per million years
- **is_hotspot**: TRUE if rate > mean + 2 SD

## Ancestral Karyotype Tables

### ancestral_karyotypes.csv

- **ancestral_node**: Ancestral node identifier
- **n_linkage_groups**: Number of chromosome pairs (n)
- **inferred_2n**: Inferred chromosome number (2n = 2n)
- **n_species_supporting**: Number of extant species mapping to this node
- **avg_block_size_kb**: Mean synteny block size (kilobases)
- **notes**: Additional information (e.g., inferred rearrangements)

### ancestral_linkage_groups.csv

- **ancestral_node**: Ancestral node identifier
- **chromosome_id**: Ancestral chromosome identifier
- **n_synteny_blocks**: Number of aligned synteny blocks on this chromosome
- **total_length_mb**: Chromosome length (megabases)
- **n_extant_species_mapping**: Number of species with synteny blocks on this chromosome
- **description**: Human-readable chromosome description

## Synteny Tables

### synteny_anchored.tsv

- **block_id**: Unique synteny block identifier
- **extant_species**: Modern species name
- **extant_chr**: Chromosome in extant species
- **extant_start, extant_end**: Genomic coordinates in extant species (bp)
- **ancestral_species**: Ancestral genome identifier
- **ancestral_chr**: Chromosome in ancestral genome
- **ancestral_start, ancestral_end**: Coordinates in ancestral genome (bp)
- **orientation**: Block orientation [+/forward, -/reverse]

## Phylogenetic Tree

### constraint_tree.nwk

Newick format phylogenetic tree with:
- Tip labels: Species identifiers
- Internal node labels: Ancestral node identifiers (optional)
- Branch lengths: Evolutionary time in millions of years (My)

---

For questions about specific columns or interpretation, see the method section in the manuscript or contact [support email].
EOF

log_msg "  ✓ Data dictionary created"

# ============================================================================
# 8. VERIFY FILE STRUCTURE
# ============================================================================

log_msg "Verifying release structure..."

file_count=$(find "${RELEASE_DIR}" -type f | wc -l)
log_msg "  Total files in release: ${file_count}"

for dir in data figures scripts docs; do
  if [ -d "${RELEASE_DIR}/${dir}" ]; then
    count=$(find "${RELEASE_DIR}/${dir}" -type f | wc -l)
    log_msg "  ${dir}/: ${count} files"
  fi
done

# ============================================================================
# 9. CREATE COMPRESSION ARCHIVE
# ============================================================================

log_msg "Creating compressed archive..."

cd "${OUTPUT_DIR}"

if command -v tar &> /dev/null; then
  tar_file="scarab_release.tar.gz"

  tar -czf "${tar_file}" scarab_release/

  if [ -f "${tar_file}" ]; then
    size=$(stat -f%z "${tar_file}" 2>/dev/null || stat -c%s "${tar_file}" 2>/dev/null)
    size_mb=$((size / 1024 / 1024))

    log_msg "  ✓ Created: ${tar_file} (${size_mb} MB)"
  fi
else
  log_msg "  WARNING: tar command not found; skipping compression"
fi

# ============================================================================
# 10. GENERATE RELEASE SUMMARY
# ============================================================================

log_msg "Generating release summary..."

summary_file="${OUTPUT_DIR}/RELEASE_SUMMARY.txt"

cat > "${summary_file}" << EOF
SCARAB: REARRANGEMENT ANALYSIS RELEASE SUMMARY
========================================================

Release Date: $(date -u '+%Y-%m-%d')
Release Version: 1.0

DIRECTORY STRUCTURE:
  scarab_release/
    ├── data/              Final analysis datasets
    ├── figures/           Publication figures (PDF)
    ├── scripts/           Analysis scripts (R, bash)
    ├── docs/              Documentation
    ├── metadata/          Metadata files
    ├── manifest.csv       File inventory with checksums
    └── README.md          Overview and guide

CONTENT STATISTICS:
  Total files: ${file_count}
  Data files: $(find "${RELEASE_DIR}/data" -type f | wc -l)
  Figure files: $(find "${RELEASE_DIR}/figures" -type f | wc -l)
  Script files: $(find "${RELEASE_DIR}/scripts" -type f | wc -l)

KEY FILES:
  - rearrangements_confirmed.tsv    High-confidence events
  - rearrangements_per_branch.tsv   Branch-level statistics
  - ancestral_karyotypes.csv        Ancestral chromosome numbers
  - constraint_tree.nwk             Phylogenetic tree

ARCHIVE:
  scarab_release.tar.gz     Compressed archive

VERIFICATION:
  All files checksummed in manifest.csv
  Run: md5sum -c manifest.csv (or equivalent)

NEXT STEPS:
  1. Verify integrity: md5sum -c manifest.csv
  2. Review README.md for dataset overview
  3. Consult DATA_DICTIONARY.md for column definitions
  4. See manuscript for methods and interpretation

========================================================

For questions or issues, contact:
[STUDENT: Add contact information]
EOF

log_msg "  ✓ Created: RELEASE_SUMMARY.txt"

# ============================================================================
# 11. COMPLETION
# ============================================================================

log_msg ""
log_msg "=== PHASE 4.5 COMPLETE ==="
log_msg "Release directory: ${RELEASE_DIR}"
log_msg "Archive: ${OUTPUT_DIR}/scarab_release.tar.gz"
log_msg "Log file: ${LOG_FILE}"

echo ""
echo -e "${GREEN}✓ Data release packaging complete${NC}"
echo "Release directory: ${RELEASE_DIR}"
echo "Archive: ${OUTPUT_DIR}/scarab_release.tar.gz"
echo ""
