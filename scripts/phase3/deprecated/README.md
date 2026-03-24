# Deprecated: scripts/phase3/

These scripts were an earlier version of the Phase 3 alignment pipeline. They have been superseded by the canonical scripts in `grace_upload_phase3/`.

## Canonical Location

Use `grace_upload_phase3/` for all Phase 3 alignment work. That directory contains:

- `prepare_nuclear_markers.sh` — Downloads BUSCO insecta data, selects 15 marker proteins
- `extract_nuclear_markers_and_build_tree.slurm` — Nuclear guide tree pipeline (tBLASTn → MAFFT → FastTree)
- `build_seqfile.sh` — Builds Cactus seqFile with nuclear guide tree
- `setup_phase3.sh` — Full setup with container pull and cactus-prepare
- `test_alignment.slurm` — 5-genome validation
- `run_full_alignment.slurm` — Full 439-genome alignment

Deprecated: 2026-03-22
