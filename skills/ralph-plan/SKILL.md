---
name: ralph-plan
description: Interactive sprint planning for Ralph. Pulls up backlog items, asks clarifying questions one at a time, and builds a sprint_plan.md ready for /ralph-continuous.
---

# Ralph Plan - Interactive Sprint Planning

Build the next sprint through focused, one-question-at-a-time conversation.

## Workflow

### 1. Get Project Directory

Use `AskUserQuestion` to ask which project to plan for. Search for directories with `RALPH.md` or previous `sprint_plan.md` files.

### 2. Check if Current Sprint Needs Archiving

Read `sprint_plan.md` if it exists. If the sprint appears complete (all non-blocked tasks in Completed section) but no matching `sprints/sprint-N-*` archive directory exists, run the `/ralph-archive` workflow inline before continuing.

If already archived or no sprint_plan.md exists, proceed.

### 3. Review Current State

Read these files if they exist:
- `roadmap.md` — **primary source** for sprint items (Now/Next/Later sections)
- `RALPH.md` — project context and patterns
- `sprint_plan.md` — any existing/previous plan
- `sprints/` — past sprint archives
- `sprint_summary.md` — learnings from last sprint
- `backlog.md` — legacy items (if exists, migrate to roadmap.md)

Summarize what you found: last sprint results, blocked/deferred items, roadmap "Now" items ready for implementation with priority and estimated task count.

### 4. Ask About Focus

Show what's in roadmap.md "Now" section with priority and estimated tasks per item.

Use `AskUserQuestion` with options: Roadmap items, New feature, Bug fixes, Technical debt.

### 5. Gather Details

Based on their focus, ask follow-up questions **one at a time**:

**Roadmap items:** Show "Now" items with acceptance criteria and estimated tasks. Ask which to include. Use the "Considerations" section from roadmap.md as task templates.

**New feature:** What feature? Who is it for? What does success look like? Technical constraints? (After sprint, add to roadmap.md if warranted.)

**Bug fixes:** What bugs? Which is highest priority?

**Technical debt:** What areas? Patterns to follow?

### 6. Suggest Investigation Tasks

Scan sprint context for keywords that benefit from investigation-first:
- standardize, refactor, optimize, migration, consistency, align
- API, integrate, external (Sprint 12-13: Hightouch API parsing caught post-deploy = 27 min rework)
- database, schema, data model, deploy, config, credentials

If detected, use `AskUserQuestion` to recommend 1-2 investigation/audit tasks at the start of the sprint. Reference Sprint 10's 305x ROI from investigation-first approach.

If no keywords detected, still ask whether any items need investigation before implementation. For investigation tasks: mark as `[INVESTIGATE]`, timebox to 10-15 min, output is documented findings not implementation.

### 7. Size and Sequence

Use `AskUserQuestion` to ask about sprint size: Focused (5-8 tasks), Standard (9-14), or Ambitious (15-20).

For ambitious sprints, warn that each task must be 1-2 SP (10-20 min) and suggest considering whether it should split into two sprints.

Order tasks explicitly by dependencies and priority so Ralph executes top-to-bottom:

```markdown
## Critical Path (must complete in order)
1. [#1] Set up database schema - BLOCKER for all data tasks
2. [#2] Add user model - depends on #1

## High Priority (independent)
3. [#3] Add dashboard UI
4. [#4] Add error logging
```

### 8. Generate sprint_plan.md

Create the sprint plan:

```markdown
# Sprint [N]: [Theme/Goal]

## Goal
[One sentence describing what success looks like]

## Tasks

### Critical Path
1. [#1] Task name - Brief description
   - Acceptance: [What "done" looks like]
   - Files: [Likely files to touch]

### High Priority
2. [#2] Task name - Brief description
   - Acceptance: [What "done" looks like]

### Investigation Tasks
[INVESTIGATE] [#N] Investigation name - What we need to learn
   - Questions to answer: [Specific questions]
   - After investigation: Add implementation tasks to sprint
   - Max time: [Timebox]

## Blocked
(Empty - tasks move here if blocked)

## Completed
(Empty - tasks move here when done)

## Notes
- [Context or decisions from planning]
```

### 9. Confirm and Save

Show the draft plan. Use `AskUserQuestion` with options: Yes save it, Make changes, Start over.

Once saved, remind the user:
- `/ralph` to implement one task at a time
- `/ralph-continuous` to implement all tasks automatically
- Investigation tasks may add new tasks mid-sprint

---

## Task Sizing

Every task must complete within a single Claude session (~10-20 min, ~200k token context).

- **1 SP (5-10 min):** Single file, clear pattern, config changes, UI with clear specs
- **2 SP (10-20 min):** Multi-file, new patterns, investigation tasks, testing tasks
- **3+ SP = too big:** Split it. "Build auth system" → investigate options, add user model, implement login, add JWT, add middleware

Investigation tasks: document findings only, don't implement. Timebox 10-15 min.

## Roadmap Integration

`roadmap.md` is the source of truth for sprint items.

**Pulling into sprints:** Parse "Now" section for items with priority, acceptance criteria, considerations (pre-broken task list), and dependencies. Each "Consideration" becomes a sprint task. Update roadmap status to "In Sprint [N]".

**After sprints:** Follow-ups flow back to roadmap.md via `/ralph-archive` — not lost in sprint archives.
