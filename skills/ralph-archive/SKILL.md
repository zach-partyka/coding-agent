---
name: ralph-archive
description: Archives completed Ralph sprint with performance metrics. Generates sprint_summary.md, copies sprint_plan.md to archive, creates fresh sprint_plan.md, updates sprint_history.md. Use when all tasks in sprint_plan.md are complete and ready to start new sprint.
---

# Ralph Archive Mode

Archive a completed sprint and prepare for the next one.

**Note:** `/ralph` and `/ralph-continuous` automatically archive when sprint completes. Use this skill only for:
- Manual archiving (if auto-archive wasn't triggered)
- Re-archiving (if you want to regenerate sprint_summary.md)
- Mid-sprint archiving (forced archive before sprint fully complete)

## When to Use

Use this skill when:
- ✅ Sprint was completed but not auto-archived (edge case)
- ✅ Want to regenerate sprint_summary.md with updated metrics
- ✅ Need to archive mid-sprint (partial work, different direction)
- ✅ Auto-archive failed and you want to retry manually

## What This Does

1. Reads completed `sprint_plan.md` and extracts performance data
2. Generates comprehensive `sprint_summary.md` with ROI analysis
3. Archives both files to `sprints/sprint-[N]-[theme]/`
4. Creates fresh `sprint_plan.md` for next sprint
5. Updates `sprints/sprint_history.md` index

## Workflow

### 1. Get Project Directory

**Check if directory was provided in the prompt first.**

If the user's message contains "Project directory:" followed by a path, use that path directly. This allows the skill to be called from scripts/automation.

**If no directory provided, prompt:**
```
Which project directory should I archive?
(Full path to repo with completed sprint_plan.md)

Example: /Users/zachpa/Documents/AI/marketing-copilot-coaching
```

Use `AskUserQuestion` to collect path only if not already provided.

### 2. Validate Sprint is Complete

Read `sprint_plan.md` and check:
- ✅ Has "Sprint Performance Summary" section
- ✅ Has "Completed" section with tasks
- ✅ All non-blocked tasks are in "Completed"

**If incomplete sprint:**
```
Error: Sprint not ready to archive

Found X uncompleted tasks:
- Task #Y: [description]
- Task #Z: [description]

Complete or block these tasks before archiving.
Or run /ralph to continue working on them.
```

**If validation fails, STOP.**

### 3. Determine Sprint Number and Theme

**A. Check existing sprints:**
```bash
ls -d sprints/sprint-* 2>/dev/null | wc -l
```

This gives the last sprint number. New sprint = last + 1.

**B. Ask user for sprint theme:**

Use `AskUserQuestion`:
```
Sprint [N] is ready to archive!

What theme describes this sprint? (2-4 words, lowercase-with-dashes)

Examples:
- audience-builder-foundation
- jira-integration-v2
- ui-polish-and-testing
- api-performance-optimization
```

**C. Confirm sprint details:**
```
=== Ready to Archive ===

Sprint Number: [N]
Sprint Theme: [theme]
Directory: sprints/sprint-[N]-[theme]

Tasks completed: [X]
Duration: [Y] min
Cost: $[Z]

Proceed? (yes/no)
```

If no, ask for different theme and retry.

### 4. Extract Performance Data

From `sprint_plan.md` "Sprint Performance Summary" section, extract:
- Sprint name
- Start date
- Status (should be "Complete" - if not, mark as Complete)
- Total tasks completed
- Total duration
- Total cost
- Average per task

From "Completed" section, extract:
- List of all completed tasks
- Performance data per task (if available)

From "Learnings / TODOs" section, extract:
- Technical learnings
- Discoveries made during sprint

From "Blocked" section (if exists), extract:
- Tasks that blocked and how resolved

### 5. Generate sprint_summary.md

Use template from `sprints/sprint_summary.template.md`.

**Calculate business case metrics:**

**Engineer baseline:**
- Time: 6-8 hours (use 7 hours as midpoint)
- Cost: $300-400 (use $350 as midpoint, based on $50/hr loaded rate)

**Speed advantage:**
```
Speed = (7 hours × 60 min) / [actual duration in minutes]
Example: (420 min) / (83 min) = 5.1x faster
```

**Cost advantage:**
```
Cost reduction % = 100 × (1 - [actual cost] / $350)
Example: 100 × (1 - $2.47 / $350) = 99.3%
```

**Cost savings:**
```
Savings = $350 - [actual cost]
Example: $350 - $2.47 = $347.53 saved
```

**Quality metrics:**
- Test pass rate: Check if tests passed (if mentioned in tasks)
- Validation failures: Count from "Blocked" section or task notes
- Specs clarity: Subjective assessment based on blockers
  - "Clear" if 0-1 blockers due to unclear specs
  - "Moderate" if 2-3 blockers due to unclear specs
  - "Vague" if 4+ blockers due to unclear specs

**What worked well / What to improve:**

Analyze completed tasks and learnings to generate observations.

Look for patterns:
- Did tasks with clear specs complete faster?
- Did integration tasks block multiple times?
- Were there repeated tool/framework issues?
- Did performance improve over course of sprint?

Example observations:
- "Clear specs in specs/ directory reduced ambiguity"
- "Integration tasks should be planned earlier (discovered after 8 isolated services)"
- "Missing test framework decision upfront caused mid-sprint blocker"

**Recommendations for next sprint:**

Based on "What to Improve", generate 3-5 actionable recommendations.

Example:
- "Define testing strategy before sprint starts (unit vs E2E vs manual)"
- "Plan integration milestones after every 2-3 services"
- "Get real data schema/credentials before building data-dependent features"

### 6. Create Archive Directory

```bash
mkdir -p sprints/sprint-[N]-[theme]
```

### 7. Copy sprint_plan.md

```bash
cp sprint_plan.md sprints/sprint-[N]-[theme]/sprint_plan.md
```

### 8. Write sprint_summary.md

Write generated summary to:
```
sprints/sprint-[N]-[theme]/sprint_summary.md
```

### 9. Update sprint_history.md

Read existing `sprints/sprint_history.md`.

**Add completed sprint entry:**

```markdown
## Sprint [N]: [Theme]

**Status:** ✅ Complete
**Duration:** [start date] - [end date]
**Theme:** [description]

**Performance:**
- Tasks: [X] completed
- Duration: [Y] min ([H]h [M]m)
- Cost: $[Z]
- ROI: [X]x faster, [X]% cost reduction

[View details](./sprint-[N]-[theme]/)

---
```

Insert ABOVE the previous sprint entry (reverse chronological order).

**Update archive footer:**
```markdown
**Last updated:** [today's date]
**Total sprints:** [N]
```

### 10. Create Fresh sprint_plan.md

**Carry forward from completed sprint:**

Before creating fresh file, extract from the archived sprint:
1. **"Out of Scope" items** → Add to Backlog section
2. **"Recommendations" from sprint_summary.md** → Add to Backlog section
3. **Unresolved learnings** (e.g., "JIRA field format unverified") → Add to Learnings section
4. **Blocked items that couldn't be resolved** → Add to Blocked section

**Prioritize backlog items:**

Don't just dump everything into flat backlog. Suggest priority based on:
- **Critical Path:** Items that block other work
- **High Priority:** Direct user value or regression fixes
- **Medium Priority:** Improvements, optimizations
- **Backlog:** Nice-to-have, future exploration

Example prioritization:
```markdown
## Backlog

**From Sprint 2 Recommendations (prioritize first):**
- [ ] Add Playwright tests for chat flow (High - prevents regression)
- [ ] Get PMM feedback on staging (High - user validation)
- [ ] Instrument ZGAI performance (Medium - optimization)

**From Sprint 2 Out of Scope (lower priority):**
- [ ] Document upload UX redesign (Medium)
- [ ] Brief completion progress UX (Medium)
```

**Template for new sprint_plan.md:**

```markdown
# Sprint Plan

**Last updated:** [today's date] (fresh sprint started)

**Previous sprint archived:** sprints/sprint-[N]-[theme]/

**Sprint Performance Summary (previous):**
- Sprint [N]: [X] tasks, [Y] min, $[Z], [ROI]x faster
- [View archive](./sprints/sprint-[N]-[theme]/)

---

## [Section for New Work]

**Ralph:** Add new tasks here, or run /ralph-plan to regenerate.

- [ ] Task 1: [description]
- [ ] Task 2: [description]

---

## Completed

(empty - fresh start)

---

## Blocked

(empty - fresh start)

---

## Learnings / TODOs Ralph Discovers

(empty - fresh start)

---

## Notes for Ralph

**This file is regenerable.** If it becomes stale or incorrect:
1. Delete it
2. Run /ralph-plan
3. Ralph will regenerate it by comparing @specs/* against actual implementation

---

## Sprint Performance Summary

**Sprint:** [Next Sprint Name/Number]
**Started:** [today]
**Status:** In Progress

**Completed so far:** 0/[N] tasks
**Total duration:** 0 min
**Total cost:** $0.00
**Avg per task:** N/A

**Cost comparison:** Engineer baseline ~$300-400 (loaded rate) for 6-8 hours equivalent work
```

**Write to:** `sprint_plan.md` (overwrites existing file)

**⚠️ IMPORTANT:** The old sprint_plan.md is already archived in step 7. Overwriting is safe.

### 11. Report Completion

```
=== Sprint Archived ===

Sprint: #[N] - [Theme]
Duration: [start date] - [end date]

Performance:
- Tasks: [X] completed
- Time: [Y] min ([H]h [M]m)
- Cost: $[Z]
- ROI: [X]x faster, [X]% cost reduction vs. engineer baseline

Business Case:
- Speed advantage: [X]x faster delivery
- Cost savings: $[X] saved vs. $350 engineer baseline
- Equivalent value: [H] engineer-hours

Archived to:
- sprints/sprint-[N]-[theme]/sprint_plan.md
- sprints/sprint-[N]-[theme]/sprint_summary.md

Updated:
- sprints/sprint_history.md

Fresh sprint_plan.md created for Sprint #[N+1].

Ready to start next sprint!
Run /ralph-plan to generate plan, or add tasks to sprint_plan.md manually.
```

### 12. STOP

Archiving is complete. User can now start planning next sprint.

---

## Guidelines

### Performance Data Accuracy

**If performance data is missing:**

Some completed tasks in `sprint_plan.md` may not have performance data (duration/tokens/cost).

**For tasks WITHOUT performance data:**
- Note in sprint_summary.md: "Performance data not tracked for [X] tasks (retroactive tracking not available)"
- Calculate metrics only from tasks WITH data
- Mark summary as "Partial data - [X]/[Y] tasks tracked"

**Do NOT make up or estimate missing performance data.**

### Retroactive Performance Tracking

**User asks:** "Can we retroactively add performance data for completed tasks?"

**Answer:** No, not reliably.

Performance data comes from:
- Task duration (requires knowing when task started/ended)
- Token counts (from Claude conversation)
- API costs (calculated from tokens × model pricing)

For tasks completed before performance tracking was added:
- Duration: Could estimate from git commits, but unreliable (includes thinking time, breaks)
- Tokens: Not available unless conversation was saved
- Cost: Could calculate IF tokens known, but without tokens, cannot estimate

**Recommendation:**
- Start tracking from now forward
- Note in first sprint summary: "Performance tracking started mid-sprint - partial data only"
- Future sprints will have complete data

### Sprint Themes

**Good themes:**
- audience-builder-foundation
- jira-integration
- api-performance
- ui-polish-and-testing
- hightouch-migration
- testing-framework-setup

**Bad themes:**
- stuff (too vague)
- various-tasks (not descriptive)
- sprint-1 (use number separately, theme should describe work)

Theme should answer: "What was the focus of this sprint?"

### Business Case Calculations

**Engineer baseline assumptions:**
- Time: 7 hours (midpoint of 6-8 hour range)
- Rate: $50-75/hr loaded rate (includes benefits, overhead)
- Cost: $350 (using $50/hr × 7 hours)

These are ESTIMATES for comparison purposes.

Actual engineer time could vary:
- Junior engineer: might take longer (8-10 hours)
- Senior engineer: might be faster (4-6 hours) but higher rate
- Complex work: could take multiple days
- Simple work: might be faster

Use consistent baseline across sprints for apple-to-apples comparison.

### Quality Metrics

**Test pass rate:**
- If all tests passed: 100%
- If some tests failed but fixed: Calculate from attempts
- If tests were skipped: Note "N/A - manual validation only"

**Validation failures:**
- Count from "Blocked" section
- Include TypeScript errors, test failures, spec conflicts
- Note how each was resolved

**Specs clarity score:**
- Subjective assessment based on blockers
- Look for blockers like "ambiguous requirements", "unclear specs", "need decision"

### What Worked / What to Improve

**Be specific, not generic.**

Bad:
- "Good progress this sprint"
- "Some blockers but we overcame them"

Good:
- "Clear specs in specs/ reduced ambiguity - only 1 blocker due to unclear requirements"
- "Integration tasks should be planned earlier - discovered 8 isolated services with no orchestration layer"

Look for patterns in:
- Task completion times (did later tasks get faster as Ralph learned?)
- Blocker types (specs? tools? credentials?)
- Rework (which tasks needed significant revision?)

---

## Edge Cases

### Sprint Has Blockers Still Open

If `sprint_plan.md` has items still in "Blocked" section that couldn't be resolved:

**Include in sprint_summary.md:**
```markdown
## Unresolved Blockers

Carried forward to next sprint:

- **Task #X:** [description]
  - Why blocked: [reason]
  - Needs: [what's required to unblock]
  - Owner: [who will resolve]
```

These should be first items in fresh `sprint_plan.md`.

### No Performance Data Available

If sprint was completed before performance tracking was added:

**In sprint_summary.md:**
```markdown
## Performance Metrics

⚠️ **Performance tracking was not enabled for this sprint.**

Retroactive estimation is not reliable. Future sprints will track:
- Duration per task
- Token usage per task
- Cost per task
- ROI vs. engineer baseline

---

Tasks completed: [X]
Estimated duration: [if known from commits/notes]
Cost: Not tracked
```

Don't force metrics that don't exist.

### User Wants Different Theme After Archiving

**After archiving is complete:**

User can rename directory:
```bash
mv sprints/sprint-[N]-[old-theme] sprints/sprint-[N]-[new-theme]
```

Then update `sprint_history.md` manually to reflect new theme.

Archive process doesn't need to re-run.

---

## Success Criteria

Archiving successful when:
- ✅ `sprint_summary.md` generated with complete data
- ✅ `sprint_plan.md` archived to sprint directory
- ✅ Fresh `sprint_plan.md` created for next sprint
- ✅ `sprint_history.md` updated with new entry
- ✅ User knows next steps (start planning Sprint N+1)

Archiving fails when:
- ❌ Sprint not complete (tasks still pending)
- ❌ No performance data in sprint_plan.md (note partial data, don't block)
- ❌ Directory creation fails (permissions issue)
- ❌ Required files missing (sprint_plan.md, sprint_history.md)

---

**Remember:** This skill archives ONE sprint and prepares for the next. It's the transition point between sprints, capturing performance data for business case building.
