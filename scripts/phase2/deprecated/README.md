# Deprecated: SLURM Array Download Script

**Superseded**: 2026-03-21, Session 5

This SLURM array job attempted to download genomes on Grace compute nodes, which have NO internet access (curl exit code 7).

**Replaced by**: `download_login.sh` which runs on the Grace login node with 4 parallel curl processes via nohup.
