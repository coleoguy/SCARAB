# HOWTO 4.7: Phase 4 Integration Signoff

**Task Goal:** Verify that all Phase 4 (Rearrangement Annotation & Ancestral Reconstruction) deliverables are complete, consistent, and ready for visualization and manuscript preparation in Phase 5.

**Timeline:** Day 30 (end of Phase 4)
**Responsible Person:** Heath (final sign-off); Student (runs checklist script)

---

## Prerequisites

- [ ] Task 3.1 (Breakpoint Calling) complete — raw rearrangements classified
- [ ] Task 3.2 (Filtering) complete — filtered rearrangement set generated
- [ ] Task 3.3 (Tree Mapping) complete — rearrangements mapped to branches
- [ ] Task 3.4 (Branch Statistics) complete — per-branch rates computed
- [ ] Task 3.5 (Literature Comparison) complete — karyotype cross-validation done
- [ ] Task 3.6 (Ancestral Karyotypes) complete — reconstructions at key nodes

---

## Inputs

All Phase 4 outputs from Tasks 3.1–3.6:

| File | Source Task | Expected Location |
|------|-----------|-------------------|
| `rearrangements_raw.tsv` | 3.1 | `phases/phase4_rearrangements/PHASE_3.1_breakpoint_calling/` |
| `rearrangements_filtered.tsv` | 3.2 | `phases/phase4_rearrangements/PHASE_3.2_filtering/` |
| `rearrangements_mapped.tsv` | 3.3 | `phases/phase4_rearrangements/PHASE_3.3_tree_mapping/` |
| Branch rate statistics | 3.4 | `phases/phase4_rearrangements/PHASE_3.4_branch_stats/` |
| Literature comparison | 3.5 | `phases/phase4_rearrangements/PHASE_3.5_literature_comparison/` |
| Ancestral karyotypes | 3.6 | `phases/phase4_rearrangements/PHASE_3.6_ancestral_karyotypes/` |

---

## Outputs

1. **`phase4_integration_report.html`** — Summary of all Phase 4 results
2. **`phase4_signoff.log`** — Pass/fail for each checklist item

---

## Acceptance Criteria

- [ ] Rearrangement calls span ≥ 80% of tree branches
- [ ] Filtered set removes low-confidence calls without excessive data loss
- [ ] Branch-specific rates computed for all internal branches
- [ ] Karyotype cross-validation: ≥ 70% concordance with literature karyotypes (for species with data)
- [ ] Ancestral karyotypes reconstructed at ≥ 10 key nodes (root, major clade MRCAs)
- [ ] All output files documented in `results/phase4_rearrangements/`
- [ ] Phase 4 entries added to `ai_use_log.md`
- [ ] Heath has reviewed and approved all outputs

---

## Script

```bash
# Run the integration report
Rscript phases/phase4_rearrangements/PHASE_3.7_integration_signoff/phase3_report.R
```

The script `phase3_report.R` in this directory generates the integration report. It has `<<<STUDENT:>>>` markers for path configuration — set `PROJECT_ROOT` before running.

---

## Next Steps

Once sign-off is complete, proceed to **Phase 5: Visualization & Manuscript** (PHASE_4.1 Interactive Tree).
