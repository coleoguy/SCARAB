# HOWTO Template — SCARAB Project

Use this template for all new HOWTO.md files. Existing HOWTOs should be updated to match this structure when they are next edited.

---

```markdown
# HOWTO [Phase].[Task]: [Descriptive Title]

**Task Goal:** [1-2 sentence description of what this task accomplishes]

**Timeline:** Day X–Y
**Responsible Person:** [who runs it] (reviewed by [who reviews])

---

## Prerequisites

- [ ] [Prior task] complete — [specific deliverable]
- [ ] [Required data/tool] available at [location]

---

## Inputs

| File | Location | Description |
|------|----------|-------------|
| `filename` | `path/to/file` | What it is |

---

## Outputs

1. **`output_file`** — [description]
2. **`output_log`** — [description]

---

## Acceptance Criteria

- [ ] [Specific, verifiable criterion]
- [ ] [Another criterion]

---

## Script

<<<STUDENT: Set PROJECT_ROOT before running>>>

\`\`\`bash
Rscript phases/[phase]/[task]/script.R
\`\`\`

---

## Step-by-Step Instructions

### Step 1: [Name]

[Instructions]

### Step 2: [Name]

[Instructions]

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| ... | ... | ... |

---

## Next Steps

Proceed to **HOWTO [X.Y]** ([next task name]).
```

---

## Section Requirements

**Required sections** (every HOWTO must have these):
- Title with HOWTO number
- Task Goal
- Prerequisites (with checkboxes)
- Inputs table
- Outputs list
- Acceptance Criteria (with checkboxes)

**Recommended sections** (include when relevant):
- Script (with command to run)
- Step-by-Step Instructions
- Troubleshooting table
- Next Steps

## Naming Convention

- File: always `HOWTO.md` (one per task directory)
- Title: `# HOWTO [Phase].[Task]: [Title]`
- Phase numbering: Phase 1 = Literature, Phase 2 = Genome Inventory, Phase 3 = Alignment, Phase 4 = Rearrangements, Phase 5 = Viz & Manuscript
- Task numbering within phase: sequential (1.1, 1.2, ... 5.7)
