# Deprecated: Original Phase 3 Pipeline Scripts

**Superseded**: 2026-03-21

These were the first-draft Cactus pipeline scripts. They had incorrect CLI syntax for Cactus v2.x (positional args wrong, --batchSystem inside SLURM, non-existent --checkpoint flag).

**Replaced by**: Scripts in `grace_upload_phase3/` which have correct Cactus v2.9.3 API calls, proper SLURM integration, and nuclear BUSCO guide tree support.

## Files
- `setup_grace.sh` — original setup (wrong cactus-prepare syntax)
- `submit_prepared.sh` — original submission wrapper
- `test_alignment.slurm` — original test job (star tree bug, wrong memory flags)
