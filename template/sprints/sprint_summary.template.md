# Sprint [Number]: [Theme]

**Duration:** [start date] - [end date]
**Theme:** [one-line description of sprint focus]

## Performance Metrics

- **Tasks completed:** [N]
- **Total duration:** [X hours Y min]
- **Total cost:** $[X.XX]
- **Average per task:** [X.X min] / $[X.XX]
- **Main model:** [e.g. Opus 4.6]
- **Sub models:** [e.g. Sonnet 4.6, Haiku 4.5 — or "none" if single-model sprint]

**Task count note:** Count only tracked tasks. Validation (e.g. run full test suite) is acceptance criteria, not a separate task unless it includes investigation/fixes.

## Business Case Comparison

**Engineer baseline for equivalent work:**
- **Time:** ~6-8 hours (estimated)
- **Cost:** $300-400 (loaded rate: $50-75/hr)

**Baseline used for calculations:** $[350] and [420] min (7 hrs)

**Ralph performance:**
- **Time:** [actual duration]
- **Cost:** $[actual cost]
- **Speed multiplier:** [X]x faster (baseline_min ÷ actual_min)
- **Cost multiple:** ~[X]x cheaper (baseline_cost ÷ actual_cost)
- **Cost advantage:** [X]% reduction

## ROI Summary

**Cost Savings:** $[XXX] saved vs. engineer approach
**Speed Multiplier:** [X]x faster delivery
**Value:** Equivalent to [X] engineer-hours of work

## Tasks Completed

[Copy entire "Completed" section from sprint_plan.md with performance data]

Example format (multi-model):
- [x] Brief → audience logic mapper - 2026-01-27
  - Implemented in server/services/audienceMapper.ts
  - **Performance:** 8 min | $1.91
    - Main: Opus | $1.81 (34 in / 4322 out / 127242 cache-write / 1818518 cache-read)
    - Sub: Haiku | $0.10 (47 in / 24 out / 64556 cache-write / 173472 cache-read) — Scout codebase
    - Duration calc: (end - start) / 60 = X / 60 = Y min
    - Timestamps: start=EPOCH, end=EPOCH

Example format (single model):
- [x] Task name - 2026-01-27
  - **Performance:** 3 min | Opus | $2.77 (30 in / 2813 out / 309833 cache-write / 1520338 cache-read)
    - Duration calc: (end - start) / 60 = X / 60 = Y min
    - Timestamps: start=EPOCH, end=EPOCH

**Performance format explanation:**
- Duration: Wall clock time from task start to completion (includes thinking/planning)
  - For tasks blocked mid-work: sum of all work phases, excludes wait time
  - Format: "15 min (8 min + 7 min after unblock)" for blocked tasks
- Tokens: Per-agent breakdown (input / output / cache-write / cache-read)
- Cost: Per-agent cost calculated from tokens at model-specific pricing
- Sub agent descriptions: Captured from Agent tool_use calls (e.g. "Scout codebase", "Run npm run check")

**Tracked autonomously via timestamps:**
- Start: `date +%s` when task marked IN PROGRESS
- Blocked: `date +%s` when task blocked (if applicable)
- Resumed: `date +%s` when task resumed (if applicable)
- End: `date +%s` when task marked COMPLETED
- Duration: Sum of work phases, excludes blocked wait time

**Blocked task example:**
- [x] Task name - 2026-01-27
  - **Performance:** 15 min (8 min + 7 min after unblock) | $0.35
  - **Note:** Blocked for missing credentials, resumed after provided

## Technical Learnings

[Copy "Learnings / TODOs" section from sprint_plan.md]

Example:
1. **Allowlist is hardcoded placeholder** - Need real Databricks schema
2. **JIRA Team field format unknown** - Using UUID approach with logging
3. **Hightouch criterion parser is naive** - Simple string matching, acceptable for V1

## Blockers Encountered

[List any tasks that blocked during sprint and how resolved]

**Format per blocker:**
- **Task name:** Why blocked
  - Time before blocking: [X] min
  - Wait time: [X] hours/days until unblocked
  - Resolution: How it was resolved
  - Impact: Effect on sprint progress

Examples:

- **Task #5 (Unit tests):** Blocked on framework choice (Jest vs E2E)
  - Time before blocking: 6 min
  - Wait time: 1 day (waiting for architecture decision)
  - Resolution: Decided on E2E API tests using existing Playwright
  - Impact: +1 day sprint delay, but avoided new dependencies

- **Task #3 (JIRA integration):** Blocked on missing field IDs
  - Time before blocking: 12 min
  - Wait time: 2 hours (waiting for Zach to provide credentials)
  - Resolution: Received JIRA field mappings
  - Impact: Minimal, other tasks completed during wait

**Blocking insights:**
- Total tasks blocked: [X] out of [Y] ([Z]%)
- Average time before blocking: [X] min (shows how quickly blockers are detected)
- Most common blocker type: [Missing credentials / Unclear specs / Architecture decisions]
- Recommendation: [What could prevent these blockers in future sprints]

## Quality Metrics

- **Test pass rate:** [%] (e.g., 100%)
- **Validation failures:** [count] (e.g., 2 failures, both resolved)
- **Specs clarity score:** [subjective: clear/moderate/vague]
- **Rework required:** [count of tasks that needed significant revision]

## What Worked Well

- [Observations about what made this sprint successful]

Examples:
- Clear specs in specs/ directory reduced ambiguity
- stdlib/ patterns provided consistent implementation approach
- Progress tracker service enabled real-time status updates
- Draft-only execution mode prevented accidental production changes

## What to Improve

- [Observations about what slowed progress or caused issues]

Examples:
- Some task requirements were too vague (e.g., "add validation")
- Missing test framework decision upfront caused mid-sprint blocker
- Allowlist hardcoded instead of using real data source (technical debt)
- Integration tasks should be planned earlier (discovered after 8 isolated services)

## Recommendations for Next Sprint

- [Actionable suggestions based on learnings]

Examples:
- Define testing strategy before sprint starts (unit vs E2E vs manual)
- Plan integration milestones after every 2-3 services
- Get real data schema/credentials before building data-dependent features
- Add explicit "BLOCKED: need decision" status to sprint_plan.md earlier

---

**Generated:** [date] by Ralph
**Sprint Status:** ✅ Complete / 🚧 Partial / ❌ Blocked
