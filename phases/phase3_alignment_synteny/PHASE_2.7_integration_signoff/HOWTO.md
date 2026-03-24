# HOWTO 3.7: Phase 3 Integration Signoff

**Task Goal:** Verify that all Phase 3 (Alignment & Synteny) deliverables are complete, consistent, and ready for downstream rearrangement analysis in Phase 4.

**Timeline:** Day 24 (end of Phase 3)
**Responsible Person:** Heath (final sign-off); Student (runs checklist script)

---

## Prerequisites

- [ ] Task 2.2 (Full Alignment) complete — HAL file validated
- [ ] Task 2.3 (Synteny Extraction) complete — synteny blocks extracted
- [ ] Task 2.4 (Synteny QC) complete — quality metrics pass thresholds
- [ ] Task 2.5 (Ancestral Reconstruction) complete — RACA output validated
- [ ] Task 2.6 (Synteny Anchoring) complete — anchored synteny table generated

---

## Inputs

All Phase 3 outputs from Tasks 2.2–2.6:

| File | Source Task | Expected Location |
|------|-----------|-------------------|
| `scarab.hal` | 2.2 | `$SCRATCH/scarab/hal_files/` (on Grace) |
| Synteny blocks TSV | 2.3 | `results/phase3_alignment_synteny/` |
| Synteny QC report | 2.4 | `results/phase3_alignment_synteny/` |
| Ancestral genomes | 2.5 | `data/ancestral/` |
| `synteny_anchored.tsv` | 2.6 | `results/phase3_alignment_synteny/` |

---

## Outputs

1. **`phase3_integration_report.html`** — Summary of all Phase 3 results
2. **`phase3_signoff.log`** — Pass/fail for each checklist item

---

## Acceptance Criteria

- [ ] HAL file contains all 439 genomes (halStats check)
- [ ] Synteny blocks cover ≥ 80% of each genome
- [ ] No self-alignment artifacts in synteny blocks
- [ ] Ancestral reconstructions exist for ≥ 10 key internal nodes
- [ ] Anchored synteny table has the expected number of rows
- [ ] All output files documented in `results/phase3_alignment_synteny/`
- [ ] Phase 3 entries added to `ai_use_log.md`
- [ ] Heath has reviewed and approved all outputs

---

## Script

```bash
# Run the integration report
Rscript phases/phase3_alignment_synteny/PHASE_2.7_integration_signoff/integration_report.R
```

The script `integration_report.R` in this directory generates the integration report. It has `<<<STUDENT:>>>` markers for path configuration.

---

## Next Steps

Once sign-off is complete, proceed to **Phase 4: Rearrangement Annotation** (PHASE_3.1 Breakpoint Calling).
