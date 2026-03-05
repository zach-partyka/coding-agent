---
name: ralph-archive
description: Archives completed Ralph sprint with performance metrics. Generates sprint_summary.md, copies sprint_plan.md to archive, creates fresh sprint_plan.md, updates sprint_history.md and roadmap.md (with follow-ups and completions). Use when all tasks in sprint_plan.md are complete and ready to start new sprint.
---

# Ralph Archive Mode

Archive a completed sprint and prepare for the next one.

`/ralph` and `/ralph-continuous` trigger this automatically when a sprint completes. Use this skill directly only for manual archiving, re-archiving, or mid-sprint archiving.

## Workflow

### 1. Get Project Directory

Check if directory was provided in the prompt. If the user's message contains "Project directory:" followed by a path, use it directly.

If no directory provided, use `AskUserQuestion` to collect the path.

### 2. Validate Sprint is Complete

Read `sprint_plan.md` and verify:
- Has "Sprint Performance Summary" section
- Has "Completed" section with tasks
- All non-blocked tasks are in "Completed"

If incomplete, list the uncompleted tasks and stop. Tell user to run `/ralph` to continue or block remaining tasks before archiving.

### 3. Determine Sprint Number and Theme

```bash
ls -d sprints/sprint-* 2>/dev/null | wc -l
```

New sprint = last sprint number + 1.

Use `AskUserQuestion` to get the sprint theme (2-4 words, lowercase-with-dashes). Theme should answer: "What was the focus of this sprint?"

Confirm sprint number, theme, archive directory, task count, duration, and cost before proceeding.

### 4. Extract Performance Data

From `sprint_plan.md`, extract:

**Sprint Performance Summary section:** sprint name, start date, status, total tasks, total duration, total cost, average per task, main model, sub models (if present).

**Completed section:** all completed tasks with per-task performance data.

**Learnings / TODOs section:** technical learnings and discoveries.

**Blocked section (if exists):** tasks that blocked and how they were resolved.

### 5. Generate sprint_summary.md

Use template from `sprints/sprint_summary.template.md`.

Include main model and sub models in Performance Metrics if recorded in sprint_plan.md.

**Business case formulas (engineer baseline: 7 hours / $350):**

```
Speed = 420 min / [actual duration]
Cost reduction % = 100 × (1 - [actual cost] / $350)
Savings = $350 - [actual cost]
```

Use consistent baseline across sprints for comparison.

**Quality metrics:**
- Test pass rate (from task notes)
- Validation failures (count from Blocked section)
- Specs clarity: "Clear" (0-1 spec blockers), "Moderate" (2-3), "Vague" (4+)

**What worked / What to improve:** Analyze patterns in completion times, blocker types, and rework. Be specific — "Clear specs reduced ambiguity to 1 blocker" not "Good progress this sprint."

**Recommendations:** Generate 3-5 actionable items based on what to improve.

### 6. Write Archive

```bash
mkdir -p sprints/sprint-[N]-[theme]
cp sprint_plan.md sprints/sprint-[N]-[theme]/sprint_plan.md
```

Write generated sprint_summary.md to `sprints/sprint-[N]-[theme]/sprint_summary.md`.

Run the math validator:
```bash
node sprints/scripts/validate_sprint_math.cjs sprints/sprint-[N]-[theme]
```

Exit code 0: continue. Exit code 1: surface discrepancies as a warning but do not block.

### 7. Update sprint_history.md

Path: **sprints/sprint_history.md** (same project directory as sprint_plan.md). Do not write to project root or to Ralph/template.

Add a new entry above the previous sprint (reverse chronological order):

```markdown
## Sprint [N]: [Theme]

**Status:** Complete
**Duration:** [start] - [end]
**Performance:** [X] tasks, [Y] min, $[Z], [ROI]x faster, [cost reduction]%
**Main model:** [if present]
**Sub models:** [if present, e.g. "Sonnet 4.6, Haiku 4.5" — omit line if single-model sprint]

[View details](./sprint-[N]-[theme]/)

(Link is relative to sprints/; same folder as sprint_history.md.)

---
```

Update the footer with today's date and total sprint count.

### 8. Create Fresh sprint_plan.md

Before overwriting, extract from the archived sprint:
- Out of scope items → carry to Backlog
- Recommendations from sprint_summary.md → carry to Backlog
- Unresolved learnings → carry to Learnings section
- Blocked items that couldn't be resolved → carry to Blocked section

Prioritize carried items (Critical Path → High → Medium → Backlog). Don't dump everything flat.

Write a fresh sprint_plan.md with: previous sprint reference, carried items by priority, empty Completed/Blocked/Learnings sections, and a zeroed Sprint Performance Summary.

The old file is already archived in step 6. Overwriting is safe.

### 9. Update roadmap.md

Extract follow-up items from sprint_summary.md (recommendations, improvements, unresolved blockers, out-of-scope items).

For each follow-up:
1. Check if similar item already exists in roadmap.md (don't duplicate)
2. Add to appropriate section: **Now** (critical/blocking), **Next** (important, not urgent), **Later** (polish/exploration)
3. Format with: What, Problem, Acceptance, Considerations, Origin (Sprint N)

Mark completed roadmap items with a checkmark. Update "Last updated" date.

If no roadmap.md exists, note it and move on.

### 10. Update RALPH.md

Extract learnings from sprint_summary.md. Add non-obvious, repeatable technical discoveries to RALPH.md under a `Sprint [N]: [Theme]` heading — framework quirks, deployment gotchas, testing patterns, integration lessons.

Skip generic advice, one-off issues, and performance metrics (those belong in sprint_summary.md).

### 11. Performance Insights (5+ Sprints Only)

```bash
sprint_count=$(ls -d sprints/sprint-* 2>/dev/null | wc -l)
```

If 5+ sprints exist and 3+ sprints since last insights report:

Parse all sprint_summary.md files. Analyze sprint size patterns, task duration trends, investigation-first impact, cost performance, and blocker frequency.

Present 3-5 data-backed recommendations to the user. Save detailed report to `sprints/performance_insights.md`.

Use `AskUserQuestion` to ask whether to update RALPH.md with performance patterns, let user specify which patterns, just save the report, or skip entirely.

Update `.ralph/last_insights_sprint` with current sprint number.

### 12. Report and Stop

Report: sprint number and theme, date range, performance summary (tasks, time, cost, ROI), business case (speed advantage, cost savings), files archived, files updated (sprint_history, roadmap, RALPH.md), and next steps.

Then stop. User can now start planning the next sprint with `/ralph-plan`.

---

## Edge Cases

**Open blockers:** Include unresolved blocked tasks in sprint_summary.md. Carry them forward as first items in fresh sprint_plan.md.

**Missing performance data:** Calculate metrics only from tasks with data. Note "Partial data — [X]/[Y] tasks tracked" in the summary. Do not fabricate missing data.

**User wants different theme after archiving:** Rename the directory and update sprint_history.md manually. No need to re-archive.

---

## Success Criteria

Complete when:
- sprint_summary.md generated with available data
- sprint_plan.md archived to sprint directory
- Fresh sprint_plan.md created for next sprint
- sprint_history.md updated
- roadmap.md updated (if exists)
- User knows next steps

Fails when:
- Sprint not complete (tasks still pending)
- Directory creation fails
- Required files missing (sprint_plan.md, sprints/sprint_history.md)
