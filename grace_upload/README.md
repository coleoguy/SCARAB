# Deprecated: grace_upload/

This directory contains **Phase 2 (genome download)** scripts for Grace HPC. These scripts are still valid for their purpose but are separated from the Phase 3 alignment scripts.

## Contents

| File | Purpose | Status |
|------|---------|--------|
| `download_genomes.slurm` | SLURM array download (BROKEN — compute nodes have no internet) | Deprecated |
| `download_login.sh` | Login-node download with 4 parallel curl | **Working** — this is how genomes were actually downloaded |
| `setup_and_submit.sh` | Original setup helper | Deprecated (relied on SLURM download) |
| `validate_downloads.sh` | Post-download validation | **Working** |
| `accessions_to_download.txt` | List of 439 accessions | Current |

## For Phase 3 Alignment Scripts

Use **`grace_upload_phase3/`** instead. That directory contains the canonical Cactus alignment pipeline scripts.

Deprecated: 2026-03-22 (session 10)
