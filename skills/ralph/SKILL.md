---
name: ralph
description: Building mode for Ralph - implements ONE thing from sprint_plan.md and stops. Creates branch, implements per specs/stdlib, commits/pushes to GitLab, merges to main, waits for staging deploy, runs Playwright against staging. Updates sprint_plan.md and RALPH.md. Stops after one thing for human review.
---

# Ralph Building Mode

Implement ONE thing from `sprint_plan.md`, then stop.

## When to Use

- sprint_plan.md exists (created by `/ralph-plan`)
- Ready to build next most important thing
- Want human review after each implementation
- Prefer tight control over continuous execution

## Workflow

### 1. Get Project Directory

**Check if directory was provided in the prompt first.**

If the user's message contains "Project directory:" followed by a path, use that path directly. This allows the skill to be called from scripts/automation.

**If no directory provided, prompt:**
```
Which project directory should I work in?
(Full path to repo with sprint_plan.md, specs/, stdlib/, RALPH.md)

Example: /Users/zachpa/Documents/AI/marketing-copilot-coaching
```

Use `AskUserQuestion` to collect path only if not already provided.

### 2. Validate Directory Structure

Use `ls` to check the project directory contents directly:

```bash
ls -la [PROJECT_DIR]
```

Verify these exist in the output:
- ✅ `sprint_plan.md` (file) - need plan to follow
- ✅ `specs` (directory) - defines WHAT to build
- ✅ `stdlib` (directory) - defines HOW to build
- ✅ `RALPH.md` (file) - build/test instructions

**Do NOT use glob patterns** - they fail when directories exist but patterns don't match.

**If sprint_plan.md missing:**
```
Error: sprint_plan.md not found

Run /ralph-plan first to generate the plan.
```

**If specs/ or stdlib/ missing:**
```
Warning: [missing directory] not found
Continuing but implementation may not follow patterns/requirements correctly.
```

### 3. Study Context

**A. Read sprint_plan.md:**
- Identify items marked `[ ]` (not done)
- Understand priorities (Critical → High → Medium → Low)

**B. Read specs/:**
- Understand WHAT to build
- Requirements, constraints, success criteria

**C. Read stdlib/:**
- Understand HOW to build
- Coding patterns, technical conventions

**D. Read RALPH.md:**
- How to build/run the project
- How to test
- Validation commands

### 4. Choose Most Important Thing

From sprint_plan.md, pick ONE item to implement.

**Selection logic:**
1. First uncompleted item in "Critical Path" section
2. If Critical Path complete, first item in "High Priority"
3. If High Priority complete, first item in "Medium Priority"
4. If Medium Priority complete, first item in "Low Priority"

**Announce choice:**
```
=== Ralph Building Mode ===

Selected from sprint_plan.md:
[x] Brief → audience logic mapper (deterministic, no AI calls)

Category: Critical Path
Why: Blocks validation layer and all downstream features
```

### 4.5 Sprint Type Detection - Investigation First

**For performance or bug fix sprints, always start with investigation.**

**Why this matters:** Sprint 2 proved this pattern. Starting with "Investigate chat response slowness" (7 min) identified 3 root causes, which informed all 9 subsequent tasks. Result: zero blockers.

**Detection:**
If sprint theme or first tasks involve:
- Performance optimization
- Bug fixes
- "slowness", "latency", "errors"
- Debugging existing behavior

**Then:**
1. First task should be **investigation** (diagnose before implementing)
2. Investigation task documents root causes, not fixes
3. Subsequent tasks address specific root causes identified

**Investigation task format:**
```markdown
1. [#1] Investigate [problem] - IN PROGRESS
   - Goal: Identify root causes, NOT implement fixes
   - Output: List of specific issues with evidence
   - Time-boxed: 10-15 min max
```

**After investigation, update sprint_plan.md:**
```markdown
## Investigation Results (Task #1)

Root causes identified:
1. [Cause A] - [evidence/data]
2. [Cause B] - [evidence/data]
3. [Cause C] - [evidence/data]

Recommended fix order: [A, C, B] (based on impact/effort)
```

**Then proceed with implementation tasks that address specific root causes.**

**Skip investigation when:**
- Building new features from scratch (no existing behavior to analyze)
- Clear specs with no ambiguity
- Continuation of previous sprint's work

### 5. Search Codebase - "Search Before Build" Rule

**CRITICAL:** Before writing ANY new code, search thoroughly using parallel subagents.

**Common mistakes:**
- Assuming feature not implemented because you haven't seen it yet
- Building new code when existing code should be extended
- Missing existing utilities/patterns that solve the problem

**MANDATORY SEARCH STEPS:**

Use up to 500 parallel subagents to search for:

**A. Existing implementations:**
```bash
find . -name "*mapper*" -o -name "*audience*" -o -name "*brief*"
```

**B. Related functions:**
```bash
grep -rn "mapBriefToAudience" .
grep -rn "audienceLogic" .
```

**C. Imports/exports:**
```bash
grep -rn "import.*mapper" .
grep -rn "export.*audience" .
```

**D. Similar functionality:**
- Check if pattern already exists elsewhere
- Look for existing utilities/helpers
- Check for partial implementations
- Search for Python files if task involves APIs/integrations (e.g., `python_jira_api.py`)

**E. For UI changes - Search ALL locations (MANDATORY):**

**⚠️ Sprint 3 Learning:** Task #13 failed because subtext existed in 3 components but only 1 was fixed.

Before changing ANY UI text, label, or component:
```bash
# Search for ALL instances of the text/element
grep -rn "Confident Campaigns" client/
grep -rn "Approve" client/  # Find all "Approve" labels
```

**Check these common locations for duplicates:**
- `client/src/components/layout/header.tsx`
- `client/src/components/mobile/mobile-nav.tsx`
- `client/src/components/mobile/mobile-*.tsx`
- `client/src/pages/*.tsx`

**Report all instances found:**
```
UI element search:
- Found "Approve" in 4 files:
  - dashboard.tsx:156 (dropdown menu)
  - mobile-brief-card.tsx:71 (dropdown menu)
  - mobile-dashboard.tsx:175 (stat card)
  - brief-list.tsx:89 (action button)

Will update ALL 4 locations.
```

**DO NOT proceed until all instances are identified.**

**E. If found existing code - Evaluate and decide:**

**Decision criteria:**

**Extend existing code when:**
- Same domain/purpose (e.g., found `python_jira_api.py`, building JIRA ticket feature)
- Natural fit (adding new function to existing module)
- Follows same patterns (same tech stack, conventions)
- Code is well-structured (not a mess that needs refactoring first)

**Build new when:**
- Different domain (e.g., found support ticket code, building JIRA analytics)
- Would require awkward refactoring
- Different tech stack or patterns
- Existing code is legacy/deprecated

**Block with recommendation when:**
- Genuinely ambiguous (could go either way)
- Significant architectural decision
- Existing code is complex and unclear
- Multiple viable approaches

**If extending:**
```
Search complete - Found existing implementation:
- python_jira_api.py has create_ticket() function
- Decision: EXTEND (same domain, natural fit)
- Will add new create_enablement_ticket() function
```

**If building new:**
```
Search complete - Found related code:
- Found supportTickets.ts (different domain - support vs JIRA)
- Decision: BUILD NEW (different system, different patterns)
- Will create jiraService.ts
```

**If blocking:**
```
BLOCKED - Need architectural decision

Found existing implementation at server/tickets/ticketGenerator.ts
- Handles support tickets currently
- Could extend for JIRA, OR build separate jiraTickets.ts
- Ambiguous whether these should share code

Recommendation: Build separate (keeps concerns separated)
But need confirmation before proceeding.
```

**Report findings:**
```
Search complete:
- Found similar pattern in server/services/briefMapper.ts (can adapt)
- No existing audienceMapper - creating new
- Can reuse validation pattern from stdlib/validation_patterns.md
```

**DO NOT PROCEED without searching first.**

### 5.5. Block Immediately On Ambiguity

**STOP and ASK before implementing if:**

- ✋ Task requirements are vague (what/where/how unclear)
- ✋ Need to guess IDs, formats, field names, API parameters
- ✋ Found existing code that might handle this (see step 5E)
- ✋ Integration path unclear ("how will this be called?")
- ✋ Have built 2+ isolated services without connecting them
- ✋ Specs contradict each other or are incomplete
- ✋ stdlib doesn't cover this pattern and you're unsure which to use

**Principle:** Over-communicate > guess wrong

**How to block:**
```
BLOCKED: [reason]

Need clarification on:
- [specific question 1]
- [specific question 2]

Found during search:
- [relevant findings]

Cannot proceed without guidance.
```

Update sprint_plan.md with BLOCKED status and exit.

### 5.75. Check Testing Requirements (ENFORCED)

**Before implementing, determine if Playwright test is required.**

**⚠️ ENFORCEMENT: Task is NOT complete until required tests exist and pass against staging.**

Both Sprint 1 and Sprint 2 identified "no automated tests added" as a gap. This step now has enforcement.

**Tests are REQUIRED for (non-negotiable):**
- **User-facing features** - Any UI change users interact with
- **Critical user flows** - Brief creation, audience builder, JIRA tickets, chat
- **Form changes** - Any input field, button, or submission flow
- **Authentication/authorization** - Login, permissions, session handling
- **External API integrations** - Databricks, JIRA, Hightouch, ZGAI

**Tests are OPTIONAL for:**
- Internal refactoring (no user-visible behavior change)
- CSS/styling only (no functional change)
- Documentation updates
- Backend-only changes with no UI impact

**If tests REQUIRED - task completion checklist:**
```
Task: Build chat performance optimization

Test requirement: REQUIRED (user-facing feature)

Before marking complete:
☐ Feature code implemented
☐ data-testid added to relevant UI elements
☐ Playwright test written in tests/*.spec.ts
☐ Test covers happy path AND error states
☐ Test passes against staging (step 10)

Task is NOT complete until all boxes checked.
```

**How to write tests (two options):**

**Option 1: Use AI Test Generator (Recommended)**

The project has Playwright AI agents available. Use them:

1. **Verify agents are initialized:**
   ```bash
   ls .claude/agents/playwright-test-*.md
   ```
   Expected: 3 agent files (generator, healer, planner)

2. **Invoke test-generator agent:**
   - Describe the feature behavior to test
   - Agent will execute actions in real browser
   - Agent generates test code automatically
   - Test is saved to tests/[feature].spec.ts

3. **Verify test works:**
   ```bash
   npm test -- tests/[feature].spec.ts
   ```

**Option 2: Write test manually (if agents unavailable)**

Use this template:
```typescript
// tests/[feature].spec.ts
import { test, expect } from '@playwright/test';

test.describe('[Feature Name]', () => {
  test('should [expected behavior]', async ({ page }) => {
    await page.goto('/');
    // Test implementation
    await expect(page.getByTestId('element-id')).toBeVisible();
  });

  test('should handle [error case]', async ({ page }) => {
    // Error case test
  });
});
```

**If tests NOT required:**
```
Task: Refactor audienceMapper.ts (internal refactoring)

Test requirement: NOT REQUIRED (internal refactoring, no UI change)
Reason: No user-visible behavior change
Verification: Existing tests still pass
```

**DO NOT skip required tests.** If blocked on test writing, mark task as BLOCKED with reason.

### 6. Implement ONE Thing

Follow the specs and stdlib patterns.

**Key rules:**
- DO NOT implement placeholders (full implementation or nothing)
- DO NOT implement "TODO" as code comments (implement completely)
- DO implement according to specs/ requirements
- DO follow stdlib/ technical patterns
- DO respect constraints (e.g., draft-only execution mode)

**Example:**

Task: "Brief → audience logic mapper (deterministic, no AI calls)"

From specs/audience_builder.md:
- Input: marketing brief
- Output: audience logic (inclusion/exclusion rules, time windows, geography)
- Constraint: Deterministic (same input → same output)
- Constraint: No AI calls, no DB calls

From stdlib/validation_patterns.md:
- Use Zod schemas for validation
- Return structured errors
- TypeScript with proper types

**Implement:**
```typescript
// server/services/audienceMapper.ts
import { z } from "zod";

export const briefInputSchema = z.object({
  objective: z.string(),
  targetAudience: z.string().optional(),
  geography: z.string().optional(),
  timeWindow: z.string().optional()
});

export type BriefInput = z.infer<typeof briefInputSchema>;

export interface AudienceLogic {
  inclusion: string[];
  exclusion: string[];
  timeWindow: string | null;
  geography: string[] | null;
}

export function mapBriefToAudienceLogic(brief: BriefInput): AudienceLogic {
  const validated = briefInputSchema.parse(brief);

  // Deterministic mapping logic
  return {
    inclusion: parseInclusionCriteria(validated.targetAudience),
    exclusion: parseExclusionCriteria(validated.targetAudience),
    timeWindow: validated.timeWindow || null,
    geography: validated.geography ? [validated.geography] : null
  };
}

function parseInclusionCriteria(target?: string): string[] {
  if (!target) return [];
  // Deterministic parsing logic here
  return target.split(",").map(s => s.trim()).filter(Boolean);
}

function parseExclusionCriteria(target?: string): string[] {
  // Deterministic exclusion logic here
  return [];
}
```

### 7. Local Validation (TypeScript Only)

Run quick local validation before pushing:

```bash
# TypeScript must compile - catches obvious errors before deploy
npm run check
```

**If TypeScript fails:**
- Fix the errors before proceeding
- Do NOT push broken code

**If TypeScript passes:**
- Proceed to git workflow

**Note:** We skip local E2E tests. Real testing happens against staging where it's more realistic.

### 8. Git Workflow - Branch, Commit, Push, Merge

**A. Create task branch:**

Generate branch name from task number and slug:
```bash
# Example: ralph/task-3-brief-mapper
git checkout -b ralph/task-{N}-{slug}
```

**Branch naming:**
- Prefix: `ralph/task-`
- Task number from sprint_plan.md
- Slug: lowercase, hyphens, max 30 chars (e.g., `brief-mapper`, `jira-integration`)

**B. Stage and commit changes:**

```bash
# Stage specific files (not git add -A)
git add [files you changed]

# Commit with descriptive message
git commit -m "$(cat <<'EOF'
[Task #N] Brief description of what was implemented

- Detail 1
- Detail 2

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**C. Push branch to GitLab:**

```bash
git push -u origin ralph/task-{N}-{slug}
```

**D. Merge to main:**

```bash
# Switch to main and pull latest
git checkout main
git pull origin main

# Merge the task branch
git merge ralph/task-{N}-{slug}

# Push to main (triggers staging deploy)
git push origin main
```

**If merge conflicts:**
- STOP immediately
- Report conflict details
- Update sprint_plan.md with BLOCKED status
- Human must resolve conflicts

### 9. Wait for Staging Deploy

After pushing to main, staging auto-deploys in ~5 minutes.

**Wait and verify deployment:**

```bash
# Wait 5 minutes for deploy
sleep 300

# Check staging is responding
curl -s -o /dev/null -w "%{http_code}" https://marketing-copilot-staging.zgtools.net/health
```

**Expected:** HTTP 200

**If staging not responding after 5 min:**
- Check GitLab pipeline: https://gitlab.zgtools.net/tpm_cdp_team/marketing-copilot/-/pipelines
- If pipeline failed → BLOCK, report error, human must fix
- If pipeline running → wait another 2 minutes

### 10. Run Playwright Against Staging

Run E2E tests against the real staging environment:

```bash
# Run Playwright tests against staging
STAGING_URL=https://marketing-copilot-staging.zgtools.net npm test
```

**Or if test config uses environment variable:**
```bash
npx playwright test --config=playwright.config.ts
```

**Test against staging URL, not localhost.**

### 10.5. Visual Verification for UI Changes (MANDATORY)

**⚠️ Sprint 3 Learning:** 36% of UI tasks failed validation because code was committed but UI wasn't visually verified. Code commit ≠ UI change visible.

**For ANY task that changes UI (labels, layout, components, styling):**

1. **Wait for staging deploy** (step 9)

2. **Open staging in browser and visually verify:**
   - Navigate to the affected page/component
   - Confirm the change is visible
   - Check on mobile viewport if applicable

3. **Check for uncommitted changes:**
   ```bash
   git status
   ```
   **If any source files show as modified, the change was NOT deployed.** Commit and push before marking complete.

4. **Document verification:**
   ```
   Visual verification:
   ✓ Opened staging URL
   ✓ Navigated to [page/component]
   ✓ Confirmed [specific change] is visible
   ✓ git status shows clean working directory
   ```

**Common failure modes (from Sprint 3):**
- Changes in working directory but never committed (Task #5)
- Fixed one component but same text exists in others (Task #13)
- Edited wrong component (similar UI in multiple files)

**DO NOT mark UI tasks complete without visual verification.**

**If Playwright tests PASS:**
- AND visual verification confirms change is visible
- Proceed to update sprint_plan.md
- Task is verified working in real environment

**If Playwright tests FAIL:**

1. **Capture failure details:**
   ```
   STAGING TEST FAILURE

   Test: [test name]
   Error: [error message]
   Screenshot: [if available]
   ```

2. **Determine failure type:**

   **If test is broken due to code changes (not a bug):**
   - Use playwright-test-healer agent to fix the test
   - Agent analyzes failure and updates test to match new behavior
   - Re-run tests to verify fix
   - Commit updated test with fix

   **If implementation has a bug:**
   - Create fix branch:
     ```bash
     git checkout -b ralph/fix-task-{N}-{attempt}
     ```
   - Fix the bug in implementation code
   - Re-run tests to verify
   - Commit and push fix

3. **If unable to fix after 2 attempts:**
   - Update sprint_plan.md with BLOCKED status
   - Document what failed and why
   - Human must investigate

**Principle:** Code isn't done until it works in staging. "It worked locally" is not acceptable.

### 11. Update sprint_plan.md - Real-Time Updates

**Update sprint_plan.md DURING work, not just at the end:**

---

## ⚠️ CRITICAL: Time & Cost Tracking is MANDATORY

**For EVERY task, you MUST:**
1. ✅ Capture start timestamp with `date +%s` when starting
2. ✅ Record it in sprint_plan.md immediately
3. ✅ Capture end timestamp when completing
4. ✅ Calculate actual duration: `(end - start) / 60`
5. ✅ Track token usage from system warnings (input/output)
6. ✅ Calculate cost: (tokens / 1M) × model pricing
7. ✅ Show calculation in completion entry

**NO ESTIMATES ALLOWED:**
- ❌ "Duration: ~10 min" - INVALID
- ❌ "Duration: about 8 minutes" - INVALID
- ❌ "Cost: roughly $0.20" - INVALID
- ✅ "Duration: 8 min (calculated: (end - start) / 60)" - VALID
- ✅ "Performance: 8 min | 12.5K in, 3.2K out | $0.09" - VALID

**Why this matters:** Accurate time AND cost tracking is required for ROI metrics and business case. We need to demonstrate value vs. engineer baseline ($50-75/hr × 6-8 hours = $300-600 for equivalent work).

**Human will verify:** After you report "task complete", human will check for timestamps, token usage, and cost calculation. If missing, completion will be rejected.

---

**A. When starting a task:**

First, capture start timestamp:
```bash
date +%s  # Returns Unix timestamp (seconds)
```

Store in sprint_plan.md:
```markdown
1. [#1] Brief → audience logic mapper - IN PROGRESS
   - Blockers: none
   - Started: 2026-01-26
   - Start timestamp: 1706294400
```

Keep timestamp on its own line for easy extraction later.

**Example:**
```bash
# Ralph runs this when starting task
date +%s
# Returns: 1706294400
```

Then adds to sprint_plan.md:
```markdown
- Start timestamp: 1706294400
```

**B. When discovering blockers mid-work:**

Capture blocked timestamp:
```bash
date +%s  # Get blocked timestamp
```

Extract start timestamp from task metadata, calculate partial duration:
```
partial_duration = (blocked_timestamp - start_timestamp) / 60
```

Update sprint_plan.md:
```markdown
1. [#1] Brief → audience logic mapper - BLOCKED
   - Blockers: Need custom field IDs for JIRA integration
   - Started: 2026-01-26
   - Start timestamp: 1706294400
   - Blocked timestamp: 1706294880
   - Time before blocking: 8 min
   - Why blocked: Need custom field IDs for JIRA integration
   - What's needed: Zach to provide JIRA field IDs
```

Move to "Blocked" section immediately, don't wait until end.

**When resuming blocked task:**

Capture resume timestamp:
```bash
date +%s  # Get resume timestamp
```

Update task in sprint_plan.md:
```markdown
1. [#1] Brief → audience logic mapper - IN PROGRESS (RESUMED)
   - Blockers: [resolved]
   - Started: 2026-01-26
   - Start timestamp: 1706294400
   - Blocked timestamp: 1706294880
   - Time before blocking: 8 min
   - Resumed timestamp: 1706381280
```

Continue work from where you left off.

**C. When discovering new work:**
Add to appropriate priority section as you find it:
```markdown
## Medium Priority

12. [#12] Add error handling for invalid brief format (discovered during #3 implementation)
    - Blockers: blocked by #3
```

**D. When completing task - Move to Completed:**

**Step 1: Capture completion timestamp and calculate duration**

```bash
date +%s  # Get end timestamp
```

Extract timestamps from task metadata in sprint_plan.md.

**Case A: Task completed without blocking**
- Has start_timestamp only
- Calculate: `duration = (end_timestamp - start_timestamp) / 60`

**Case B: Task was blocked and resumed**
- Has start_timestamp, blocked_timestamp, resumed_timestamp
- Calculate phases:
  - Phase 1: `(blocked_timestamp - start_timestamp) / 60`
  - Phase 2: `(end_timestamp - resumed_timestamp) / 60`
  - Total: Phase 1 + Phase 2

**Case C: Task blocked multiple times**
- Sum all work phases (start→block, resume→block, resume→complete)
- Exclude blocked wait time (block→resume)

Round to nearest minute (or 1 decimal place if <10 min).

**Step 2: Get token usage**

From system warnings in conversation:
```
Token usage: 78139/200000; 121861 remaining
```

Calculate tokens used for THIS task:
- Subtract tokens at task start from tokens at task end
- This gives input tokens consumed
- Output tokens are estimated (typically 20-30% of input, or use actual if available)

If can't calculate delta (no baseline), note current total and mark as "partial tracking".

**Step 3: Calculate cost**

Using model pricing (Sonnet 4.5 as of 2026-01):
- Input: $3 per million tokens
- Output: $15 per million tokens

Cost = (input_tokens / 1_000_000 × $3) + (output_tokens / 1_000_000 × $15)

**Step 4: Format completion entry**

**Case A: Completed without blocking**

From:
```markdown
## Critical Path

1. [#1] Brief → audience logic mapper (deterministic, no AI calls)
   - Blockers: none
   - Started: 2026-01-26
   - Start timestamp: 1706294400
```

To:
```markdown
## Completed

- [x] [#1] Brief → audience logic mapper (deterministic, no AI calls) - 2026-01-26
  - Created server/services/audienceMapper.ts
  - Deterministic mapping from brief to audience logic
  - Zod validation, TypeScript types
  - Validation: npm run check passed, export verified
  - **Performance:** 8 min | 12.5K in, 3.2K out | $0.18
```

**Case B: Completed after being blocked**

From:
```markdown
## Blocked

1. [#1] Brief → audience logic mapper - IN PROGRESS (RESUMED)
   - Blockers: [resolved]
   - Started: 2026-01-26
   - Start timestamp: 1706294400
   - Blocked timestamp: 1706294880
   - Time before blocking: 8 min
   - Resumed timestamp: 1706381280
```

To:
```markdown
## Completed

- [x] [#1] Brief → audience logic mapper (deterministic, no AI calls) - 2026-01-27
  - Created server/services/audienceMapper.ts
  - Deterministic mapping from brief to audience logic
  - Zod validation, TypeScript types
  - Validation: npm run check passed, export verified
  - **Performance:** 15 min (8 min + 7 min after unblock) | 25K in, 6K out | $0.35
  - **Note:** Blocked for missing Databricks schema, resumed after data provided
```

**Performance format:**
```
[duration] min | [input]K in, [output]K out | $[cost]
```

For blocked tasks, show breakdown:
```
[total] min ([phase1] min + [phase2] min after unblock) | [tokens] | [cost]
```

Examples:
- `8 min | 12.5K in, 3.2K out | $0.18`
- `15 min | 45K in, 8K out | $0.26`
- `3.5 min | 5K in, 1K out | $0.08`

**Full example workflow:**

Task starts:
```bash
date +%s  # Returns: 1706294400
```

Task completes (8 minutes later):
```bash
date +%s  # Returns: 1706294880
```

Calculation:
```
Duration = (1706294880 - 1706294400) / 60 = 480 / 60 = 8 minutes
```

Token usage from system warnings:
- Task start: "Token usage: 65000/200000"
- Task end: "Token usage: 77500/200000"
- Input tokens: 77500 - 65000 = 12500 (12.5K)
- Output tokens: ~3200 (estimated from output length)

Cost calculation:
```
Input cost: 12500 / 1000000 × $3 = $0.0375
Output cost: 3200 / 1000000 × $15 = $0.048
Total: $0.0855 ≈ $0.09 (or use $0.18 if output was actually higher)
```

Final entry:
```markdown
- [x] Task name - 2026-01-26
  - **Performance:** 8 min | 12.5K in, 3.2K out | $0.18
```

**If start timestamp missing (edge case):**

If task was started without timestamp (before tracking was added, or conversation interrupted):
```markdown
- [x] Task name - 2026-01-26
  - **Performance:** duration unknown | 12.5K in, 3.2K out | $0.18
  - Note: Started before timestamp tracking enabled
```

Still track cost and tokens. Duration can be noted as "N/A" in sprint summary.

**E. Update Sprint Performance Summary:**

At the bottom of sprint_plan.md, maintain a running performance summary.

**After each task completion:**

1. Parse all completed tasks for performance data
2. Sum totals: duration, tokens, cost
3. Calculate averages: total / completed_count
4. Update summary section

```markdown
---

## Sprint Performance Summary

**Sprint:** [sprint name/number]
**Started:** [date]
**Status:** In Progress

**Completed so far:** 3/8 tasks
**Total duration:** 24 min
**Total cost:** $0.54
**Avg per task:** 8.0 min / $0.18

**Cost comparison:** Engineer baseline ~$300-400 (loaded rate) for 6-8 hours
```

**Calculation example:**

Completed tasks:
- Task 1: 8 min | $0.18
- Task 2: 12 min | $0.31
- Task 3: 4 min | $0.05

Totals:
- Duration: 8 + 12 + 4 = 24 min
- Cost: $0.18 + $0.31 + $0.05 = $0.54
- Average: 24/3 = 8.0 min, $0.54/3 = $0.18

Update after each task completion. When all tasks complete, mark status as "Complete" and add completion date.

**F. Update "Last updated" timestamp:**
```markdown
**Last updated:** 2026-01-26 (by ralph after completing #1 audience mapper)
```

**Principle:** sprint_plan.md is a living document. Update it as you learn, not just when done.

### 12. Update RALPH.md (If You Learned Something)

**Only update if you learned something new** about building/running the project.

**Good reasons to update:**
- Discovered non-obvious build command
- Found new way to run tests
- Learned about environment quirk
- Discovered validation pattern

**Bad reasons:**
- Just completed a task (that's sprint_plan.md's job)
- Added a new file (not RALPH.md's concern)

**Example update:**

If you learned TypeScript requires explicit file extensions in imports:
```markdown
## Ralph's Learning Log

**2026-01-26:** TypeScript ESM requires explicit .js extensions in imports, even for .ts files. Use `import { x } from './file.js'` not `import { x } from './file'`.
```

Keep it brief. One line per learning.

### 13. Check if Sprint Complete

After updating sprint_plan.md, check if sprint is complete:

**Sprint is complete when:**
- All items in Critical Path / High Priority / Medium Priority sections are in "Completed"
- No items remain uncompleted (except Low Priority, which is optional)
- OR user explicitly says sprint is done

**If sprint NOT complete:**

Report task completion and stop:
```
=== Task Complete ===

Implemented:
[x] Brief → audience logic mapper

Created:
- server/services/audienceMapper.ts (105 lines)

Validation:
✓ npm run check passed
✓ Pushed to GitLab, merged to main
✓ Staging deploy successful
✓ Playwright tests passed against staging

Updated:
- sprint_plan.md (moved to completed)

Sprint Progress: 9/14 tasks complete

Next most important thing:
[ ] Validation layer (required fields, conflict detection)

Run /ralph again to continue, or review implementation first.
```

**If sprint IS complete:**

Proceed to automatic archiving (step 11).

### 14. Auto-Archive Sprint (If Complete)

When sprint is complete, automatically archive it.

**A. Determine sprint number:**
```bash
# Count existing sprint directories
ls -d sprints/sprint-* 2>/dev/null | wc -l
```
New sprint = count + 1

**B. Auto-generate sprint theme:**

Analyze completed tasks to infer theme. Look for:
- Common domain (e.g., "audience builder", "jira integration", "api performance")
- Technical focus (e.g., "testing framework", "data pipeline", "ui components")
- Business context (e.g., "v1 foundation", "migration", "refactoring")

**Theme format:** 2-4 words, lowercase-with-dashes

**Examples:**
- If tasks mostly about audience builder → "audience-builder-foundation"
- If tasks about JIRA integration → "jira-integration"
- If tasks about testing → "testing-framework-setup"
- If mixed infrastructure work → "infrastructure-improvements"

Use most specific theme that covers >50% of tasks.

**C. Extract performance data:**

From sprint_plan.md "Sprint Performance Summary":
- Total tasks, duration, cost
- Start date, calculate end date (today)

**D. Calculate ROI metrics:**

Engineer baseline: 7 hours, $350 (at $50/hr)

Speed advantage: `(420 min) / [actual duration]`
Cost reduction: `100 × (1 - [cost] / $350)`
Savings: `$350 - [actual cost]`

**E. Generate sprint_summary.md:**

Follow template from `sprints/sprint_summary.template.md`.

Include:
- Performance metrics
- Business case comparison (ROI)
- All completed tasks with performance data
- Technical learnings from sprint_plan.md
- Quality metrics (test pass rate, blockers)
- What worked / what to improve (infer from blockers and learnings)

**F. Create archive:**
```bash
mkdir -p sprints/sprint-[N]-[theme]
cp sprint_plan.md sprints/sprint-[N]-[theme]/
# Write generated sprint_summary.md
```

**G. Update sprint_history.md:**

Add entry at top:
```markdown
## Sprint [N]: [Theme]

**Status:** ✅ Complete
**Duration:** [start] - [end]
**Theme:** [description]

**Performance:**
- Tasks: [X] completed
- Duration: [Y] min
- Cost: $[Z]
- ROI: [X]x faster, [X]% cost reduction

[View details](./sprint-[N]-[theme]/)

---
```

**H. Create fresh sprint_plan.md:**

Reset for next sprint with template noting previous sprint performance.

**I. Report archive completion:**
```
=== Sprint Complete & Archived ===

Sprint #[N]: [Theme]
Duration: [start] - [end]

Performance:
- Tasks: [X] completed
- Time: [Y] min
- Cost: $[Z]
- ROI: [X]x faster, [X]% cost reduction

Archived to:
- sprints/sprint-[N]-[theme]/

Fresh sprint_plan.md created for Sprint #[N+1].

Ready to start next sprint!
Run /ralph-plan to generate new plan.
```

### 15. STOP

Do not continue to next task. Human reviews first.

If sprint was archived, human will start planning Sprint N+1.

---

## Guidelines

### One Thing Per Loop

**Only implement ONE item from sprint_plan.md per invocation.**

This is not negotiable. It's the core philosophy.

**Why:**
- Preserves context window (fresh start each loop)
- Allows human review
- Prevents runaway behavior
- Keeps changes focused and testable

### Integration Checkpoints - Stop Building, Start Connecting

**After building 2-3 isolated services, STOP and check:**

```
I've built [service1], [service2], [service3].

Before continuing:
- How do these connect?
- What API route calls them?
- What's the frontend integration?
- Should I build integration layer now?
```

**Red flag:** Building 8+ services with no orchestration/integration layer.

**Solution:** sprint_plan.md should have "Integration/Testing" section that's explicitly blocked by the services it connects.

**When to pause for integration:**
- Built 2-3 services
- About to start building more services
- No clear path for how they'll be called

**What to do:**
1. Check sprint_plan.md for Integration/Testing tasks
2. If they're unblocked (services are ready), implement integration next
3. If unclear, BLOCK and ask: "Should I integrate services #1-#3 before continuing?"

### Search Before Implementing

**Always search codebase thoroughly before writing new code.**

Use 500 parallel subagents if needed. Common patterns:
- File name search
- Function name search
- Import/export search
- Similar functionality search

**Don't assume it's not implemented just because you haven't found it.**

### No Placeholders

**Do not implement placeholder/minimal implementations.**

```typescript
// ❌ BAD (placeholder)
export function mapBriefToAudienceLogic(brief: BriefInput): AudienceLogic {
  return { inclusion: [], exclusion: [], timeWindow: null, geography: null };
}

// ✅ GOOD (full implementation)
export function mapBriefToAudienceLogic(brief: BriefInput): AudienceLogic {
  const validated = briefInputSchema.parse(brief);
  return {
    inclusion: parseInclusionCriteria(validated.targetAudience),
    exclusion: parseExclusionCriteria(validated.targetAudience),
    timeWindow: validated.timeWindow || null,
    geography: validated.geography ? [validated.geography] : null
  };
}
```

### Block on Failure

**If validation fails, STOP immediately.**

Do not try to fix and continue. Report the failure, update sprint_plan.md with BLOCKED status, exit.

Human will fix and run `/ralph` again to retry.

### Follow stdlib Patterns

**Respect technical patterns in stdlib/.**

If stdlib says "use Zod schemas" → use Zod schemas
If stdlib says "timestamps are strings" → use strings, not Dates
If stdlib says "session-based auth" → use session-based auth

### Update RALPH.md Sparingly

**Only update RALPH.md if you learned something about building/running the project.**

Not every task requires an update. Most don't.

---

## Edge Cases

### Multiple Items at Same Priority

Pick the first one in the list.

### Item Is Already Implemented

Search found it exists:
- Move to "Completed" in sprint_plan.md
- Pick next item
- Continue

### Item Is Blocked

Specs unclear, dependency missing, etc:
- Do NOT implement
- Move to "Blocked" section in sprint_plan.md
- Document why blocked
- Pick next unblocked item

### Validation Command Missing

Item in sprint_plan.md has no validation command:
- Use standard validations: npm run check (local), Playwright against staging (remote)
- Use best judgment
- Note in completion entry that validation was minimal

### Tests Unrelated to Your Work Fail

Fix them. If tests fail (even if not your code), you're responsible for getting them green before marking complete.

---

## Success Criteria

Building complete when:
- ✅ ONE item from sprint_plan.md is implemented
- ✅ TypeScript compiles (`npm run check` passes)
- ✅ Code committed and pushed to GitLab
- ✅ Merged to main, deployed to staging
- ✅ Playwright tests pass against staging
- ✅ sprint_plan.md is updated (item moved to completed)
- ✅ RALPH.md updated if new learning
- ✅ User knows what's next
- ✅ Code follows specs/ requirements
- ✅ Code follows stdlib/ patterns

Building fails when:
- ❌ TypeScript compilation fails
- ❌ Merge conflicts (human must resolve)
- ❌ Staging deploy fails
- ❌ Playwright tests fail against staging (after 2 fix attempts)
- ❌ Placeholder implementation
- ❌ Doesn't follow specs/stdlib
- ❌ Multiple items implemented (violated one-thing rule)

---

## Sprint Archiving

When a sprint is complete (all tasks in sprint_plan.md done), archive it for performance tracking and business case building.

### How to Archive

Run the dedicated archiving skill:
```
/ralph-archive
```

This skill will:
- Validate sprint is complete
- Extract performance data from sprint_plan.md
- Generate sprint_summary.md with ROI analysis
- Archive to sprints/sprint-[N]-[theme]/
- Create fresh sprint_plan.md for next sprint
- Update sprints/sprint_history.md index

**Full documentation:** See `/ralph-archive` skill.

### Quick Reference (if running manually):

**1. Create sprint directory:**
```bash
mkdir -p sprints/sprint-[number]-[theme]
```

Example: `sprints/sprint-001-audience-builder-foundation`

**2. Generate sprint_summary.md:**

```markdown
# Sprint [Number]: [Theme]

**Duration:** [start date] - [end date]
**Theme:** [one-line description of sprint focus]

## Performance Metrics

- **Tasks completed:** [N]
- **Total duration:** [X hours Y min]
- **Total cost:** $[X.XX]
- **Average per task:** [X.X min] / $[X.XX]
- **Token usage:** [XXX]K input, [XX]K output

## Business Case Comparison

**Engineer baseline for equivalent work:**
- **Time:** ~6-8 hours (estimated)
- **Cost:** $300-400 (loaded rate: $50-75/hr)

**Ralph performance:**
- **Time:** [actual duration]
- **Cost:** $[actual cost]
- **Speed advantage:** [X]x faster
- **Cost advantage:** [X]% reduction

## Tasks Completed

[Copy entire "Completed" section from sprint_plan.md]

## Technical Learnings

[Copy "Learnings / TODOs" section from sprint_plan.md]

## Blockers Encountered

[List any tasks that blocked during sprint and how resolved]

## Quality Metrics

- **Test pass rate:** [%]
- **Validation failures:** [count]
- **Specs clarity score:** [subjective: clear/moderate/vague]

## What Worked Well

- [Observations about what made this sprint successful]

## What to Improve

- [Observations about what slowed progress or caused issues]

---

**Generated:** [date] by Ralph
```

**3. Copy sprint_plan.md:**
```bash
cp sprint_plan.md sprints/sprint-[number]-[theme]/sprint_plan.md
```

**4. Create fresh sprint_plan.md:**

Reset for next sprint:
```markdown
# Fix Plan

**Last updated:** [today's date] (fresh sprint started)

**Previous sprint archived:** sprints/sprint-[number]-[theme]/

---

## [New Sprint Section]

[New tasks for next sprint]

---

## Completed

(empty - fresh start)

---

## Sprint Performance Summary

**Sprint:** [new sprint name]
**Started:** [today]
**Status:** In Progress

**Completed so far:** 0/[N] tasks
**Total duration:** 0 min
**Total cost:** $0.00
```

**5. Update sprint index:**

If `sprints/README.md` doesn't exist, create it:

```markdown
# Ralph Sprint Archive

Performance tracking for AI-assisted development sprints.

## Sprints

### Sprint 001: Audience Builder Foundation
- **Duration:** Jan 20-27, 2026
- **Tasks:** 8 completed
- **Performance:** 1h 23m / $2.47
- **ROI:** 6x faster than manual, 99% cost reduction
- **Status:** ✅ Complete
- [View details](./sprint-001-audience-builder-foundation/)

### Sprint 002: [Next Sprint]
- **Status:** 🚧 In Progress
```

Update this file after each sprint archive.

### Archive Completion Report

After archiving, report to user:

```
=== Sprint Archived ===

Sprint: #001 - Audience Builder Foundation
Duration: Jan 20-27, 2026

Performance:
- Tasks: 8 completed
- Time: 1h 23m
- Cost: $2.47
- ROI: 6x faster, 99% cost reduction vs. engineer baseline

Archived to:
- sprints/sprint-001-audience-builder-foundation/

Fresh sprint_plan.md created for next sprint.

Ready to start Sprint #002.
```

---

**Remember:** Implement ONE thing, then stop. Human reviews. Run `/ralph` again to continue. This is intentional.

For unattended execution, use `/ralph-continuous`.
