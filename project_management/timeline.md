# SCARAB: 5-Week Compressed Timeline

**Project Start Date:** March 21, 2026
**Preprint Target:** ~May 2, 2026
**Total Duration:** 5 weeks

---

## Week-by-Week Breakdown

### WEEK 1: Literature Review & Genome Inventory (Mar 21–22) — COMPLETE

- Literature review: competitive landscape, Zoonomia methods, preprint strategy
- Genome inventory: 1,121 assemblies mined → 687 primary → 439 quality-filtered
- 439/439 genomes downloaded on Grace (100% validated)
- Calibrated constraint tree (29 nodes, 320 Ma root)
- QC report + 5 supplementary figures
- Manuscript drafts: Introduction, Methods, Results, Table S1
- Karyotype compilation: 265/439 species (60.4% coverage)

### WEEK 2: Guide Tree & Alignment Launch (Mar 23–28) — IN PROGRESS

| Day | Task | Status |
|-----|------|--------|
| Mar 23 | Nuclear BUSCO guide tree job completes on Grace | Awaiting |
| Mar 23 | Quality gate check (≥90% taxa with molecular data) | Pending |
| Mar 24 | Submit test alignment (5 genomes, short queue) | Pending |
| Mar 24 | Submit full alignment (439 genomes, xlong queue) | Pending |
| Mar 25–28 | Monitor alignment; work on Google.org grant | Pending |

### WEEK 3: Alignment Running (Mar 29 – Apr 4)

- Monitor Cactus alignment on Grace (expected 7–21 days)
- Parallel work: Google.org grant (deadline Apr 17), manuscript editing, figure review
- Extract synteny blocks from HAL if alignment completes early

### WEEK 4: Synteny & Rearrangements (Apr 5–11)

- Synteny block extraction and QC
- Ancestral genome reconstruction (RACA)
- Rearrangement calling: fusions, fissions, inversions
- Map rearrangements to phylogeny
- Breakpoint hotspot analysis

### WEEK 5: Visualization & Manuscript (Apr 12–18)

- Publication figures (6 planned)
- Complete Results and Discussion
- Data release (GitHub + Zenodo)
- Preprint submission to bioRxiv

---

## Critical Path

```
Genome inventory → Guide tree → Test alignment → Full alignment (7-21d) → Synteny → Rearrangements → Manuscript → Preprint
   DONE             RUNNING       NEXT             BOTTLENECK
```

**Key Bottleneck:** Full Cactus alignment on Grace (~7–21 days wall-clock). Everything downstream is blocked.

**Parallel work while alignment runs:** Google.org grant, manuscript editing, figure preparation, student DOI curation.

---

## Risk Factors

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Alignment takes >21 days | Delays preprint by 1–2 weeks | Pilot test first; subtree decomposition |
| Guide tree quality gate fails | Delays alignment start by 1–2 days | Fallback: calibrated tree (no molecular data) |
| SU budget exceeded (200K allocated) | Must request more allocation | Pilot smallest subtree to calibrate cost |
| Hardware failure on Grace | Must restart alignment | Cactus checkpointing enabled |

---

## Grace Access Notes

- VPN: Cisco Secure Client → `vpn.tamu.edu`
- File transfer: `sftp` (not scp — Duo 2FA causes timeout)
- Compute nodes: NO internet access (downloads on login node only)
- Container runtime: Singularity (not Docker)
- SLURM scripts: must include `--ntasks=1`
- Lab access: `chmod -R o+rX $SCRATCH/scarab`
