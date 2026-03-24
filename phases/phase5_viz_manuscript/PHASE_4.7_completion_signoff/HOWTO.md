# HOWTO 5.7: Project Completion Signoff

**Task Goal:** Final quality check before preprint submission. Verify all deliverables are complete, figures are publication-ready, data release package is correct, and manuscript sections are consistent.

**Timeline:** Day 35 (preprint submission day)
**Responsible Person:** Heath (final sign-off and submission)

---

## Prerequisites

- [ ] All Phase 5 visualization tasks complete (4.1–4.6)
- [ ] Manuscript text finalized (Introduction, Methods, Results, Discussion)
- [ ] All figures at publication resolution (≥ 300 dpi)
- [ ] Data release package built and verified (Task 4.5)
- [ ] All co-author approvals received

---

## Checklist

### Data Integrity
- [ ] HAL file backed up (Grace + off-site)
- [ ] All intermediate files reproducible from scripts
- [ ] Data release package (tar.gz) matches manifest
- [ ] Genome catalog matches NCBI records

### Manuscript Quality
- [ ] All figures referenced in text
- [ ] All tables referenced in text
- [ ] Supplementary materials complete
- [ ] AI contributions disclosed per journal policy
- [ ] References complete and formatted

### Reproducibility
- [ ] All scripts run from `PROJECT_ROOT` without hardcoded paths
- [ ] `ai_use_log.md` complete for all sessions
- [ ] Software versions documented in `software_and_tools.docx`
- [ ] SLURM job IDs and parameters recorded

### Submission
- [ ] bioRxiv preprint formatted and ready
- [ ] GitHub repository prepared (code + data links)
- [ ] Zenodo DOI reserved for data release
- [ ] NCBI BioProject/SRA references included

---

## Script

```bash
# Run the final checklist
Rscript phases/phase5_viz_manuscript/PHASE_4.7_completion_signoff/final_checklist.R
```

The script `final_checklist.R` programmatically checks file existence, figure dimensions, and data consistency. It has `<<<STUDENT:>>>` markers — set `PROJECT_ROOT` before running.

---

## Outputs

1. **`final_checklist_report.html`** — Pass/fail for each item
2. **`final_checklist.log`** — Detailed log

---

## Next Steps

Submit to bioRxiv. Simultaneously prepare for journal submission (Nature Ecology & Evolution or MBE).
