# SCARAB: Synteny, Chromosomes, And Rearrangements Across Beetles

A genome-scale atlas of chromosomal rearrangements across 439 beetle and outgroup genomes spanning the major clades of Coleoptera.

**PI:** Heath Blackmon (Texas A&M University)

## Project Summary

SCARAB constructs a comprehensive chromosomal rearrangement atlas for Coleoptera — the most species-rich eukaryotic order — using whole-genome alignment of 439 genomes from 61 beetle families plus Neuropterida outgroups. We leverage ProgressiveCactus to align all genomes, extract synteny blocks, call rearrangements (fusions, fissions, inversions, translocations), and reconstruct ancestral karyotypes at key phylogenetic nodes. A centerpiece analysis correlates cytogenetic fusion/fission rates from the Blackmon lab karyotype database (~4,400 species) with Cactus-inferred genomic rearrangement rates.

## Quick Start

### Project Status

See `context.md` for full project state and `project_management/progress_tracking.md` for detailed tracking.

### Key Directories

| Directory | Contents |
|-----------|----------|
| `data/genomes/` | Genome catalog, phylogenetic trees, tip mapping |
| `data/karyotypes/` | Empirical karyotype data for cross-validation |
| `grace_upload_phase3/` | **Canonical** Grace HPC scripts for alignment pipeline |
| `phases/` | Phase-specific HOWTO documentation and scripts |
| `manuscript/` | Drafts, figures, supplementary materials |
| `project_management/` | AI use log, progress tracking, task board |
| `results/` | Analysis outputs organized by phase |
| `scripts/` | Analysis workflows (Phase 2 download scripts, R scripts) |

### Running on TAMU Grace HPC

All alignment work runs on Grace. The pipeline is:

1. **Download genomes** (Phase 2, DONE): `scripts/phase2/download_login.sh` on login node
2. **Prepare nuclear markers**: `bash grace_upload_phase3/prepare_nuclear_markers.sh` (login node, downloads BUSCO data)
3. **Build nuclear guide tree**: `sbatch grace_upload_phase3/extract_nuclear_markers_and_build_tree.slurm`
4. **Setup**: `bash grace_upload_phase3/setup_phase3.sh` (pulls Cactus container, builds seqFile)
5. **Test alignment**: `sbatch grace_upload_phase3/test_alignment.slurm` (5 genomes, ~1 hr)
6. **Full alignment**: `sbatch grace_upload_phase3/run_full_alignment.slurm` (439 genomes, ~7-21 days)

File transfer to Grace uses `sftp` (not `scp`) due to Duo 2FA. Compute nodes have no internet — all downloads run on login nodes.

### Genome Dataset

1,121 NCBI assemblies screened down to 439 quality-filtered genomes:
- 422 Coleoptera (61 families) + 17 Neuropterida outgroups
- Quality criteria: chromosome/scaffold-level assembly, scaffold N50 >= 100 kb
- Full catalog: `data/genomes/genome_catalog.csv` (43 columns)

## Reproducibility

All AI-generated code is documented in `project_management/ai_use_log.md` with dates, model versions, outputs, and review status. Human review is required before executing any AI-generated code on production data or HPC resources.

## Dependencies

- **ProgressiveCactus v2.9.3** (Singularity container on Grace)
- **BLAST+ 2.14.0**, **MAFFT 7.520**, **FastTree 2.1.11** (Grace modules)
- **R** (base R for Phase 2 scripts; packages: ape, phangorn)
- **Python 3** (standard library + pandas for data processing)
- **halTools** (bundled in Cactus container: halStats, halSynteny, halValidate)

## Contact

Heath Blackmon, Ph.D. (he/him/his)
Associate Professor | Department of Biology | Texas A&M University
coleoguy@gmail.com
