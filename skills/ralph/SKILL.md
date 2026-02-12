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

## When Invoked from ralph-continuous

If the user message includes **ONE TASK ONLY** or is from `ralph-continuous.sh`:
- Implement **exactly one** unchecked task from sprint_plan.md (the first one).
- Do **not** implement, mark complete, or touch any other task.
- When done, **touch the claude-done marker** specified in the prompt (e.g., `touch /path/to/.ralph-markers/task-N-claude-done`).
- If the entire sprint is complete (no unchecked tasks left), also touch the sprint-complete marker.
- The next tab will handle the next task.

## Workflow

### 1. Get Project Directory

Check if directory was provided in the prompt first. If the user's message contains "Project directory:" followed by a path, use that path directly.

If no directory provided, use `AskUserQuestion`:
```
Which project directory should I work in?
(Full path to repo with sprint_plan.md, specs/, stdlib/, RALPH.md)
```

### 2. Validate Directory

```bash
ls -la [PROJECT_DIR]
```

Required (stop if missing):
- `sprint_plan.md` — if missing, tell user to run `/ralph-plan`
- `RALPH.md`

Warn but continue if missing:
- `specs/` directory
- `stdlib/` directory

Do NOT use glob patterns — they fail when directories exist but patterns don't match.

### 3. Study Context

Read these in parallel:
- **sprint_plan.md** — identify unchecked `[ ]` items and priorities
- **specs/** — what to build (requirements, constraints, success criteria)
- **stdlib/** — how to build (coding patterns, conventions)
- **RALPH.md** — build/run/test instructions

### 4. Select Task

Pick ONE unchecked item from sprint_plan.md. Skip any task marked BLOCKED.

Selection order:
1. First unblocked item in "Critical Path"
2. Then "High Priority"
3. Then "Medium Priority"
4. Then "Low Priority"
5. If all blocked or complete, stop

Announce your choice with the task, its category, and why it matters. Note any skipped blocked tasks.

### 5. Clock In

Mark the task IN PROGRESS in sprint_plan.md:

```markdown
- [ ] **#4** Add globalTeardown to playwright.config.ts - IN PROGRESS
  - Started: 2026-02-10
  - Model: Sonnet 4.5 (default)
```

Check the prompt for `"Ralph model: [value]"` — if present, note it.

Shell handles timestamp capture. You just mark the status.

### 6. Detect Investigation Sprints

If the sprint theme or first tasks involve performance, bugs, slowness, latency, or debugging — start with investigation, not implementation.

**Why:** Sprint 2 proved this. "Investigate chat response slowness" (7 min) identified 3 root causes, informing 9 subsequent tasks with zero blockers.

Investigation tasks:
- Document root causes, don't implement fixes
- Time-box to 10-15 min
- Update sprint_plan.md with findings and recommended fix order

Skip investigation for new features, clear specs, or continuation of previous sprint work.

### 7. Search Codebase

**Search before writing any new code.** This is the single biggest source of past failures — building new when existing code should be extended.

Confirm task is marked IN PROGRESS, then search using parallel subagents:

**A. Existing implementations** — files with relevant names

**B. Related functions** — grep for function names, imports, exports

**C. Similar functionality** — check for partial implementations, utilities, Python files for API tasks

**D. For UI changes — search ALL locations:**

Sprint 3 Learning: Task #13 failed because subtext existed in 3 components but only 1 was fixed.

Before changing any UI text/label/component, grep the entire `client/` directory. Check `components/layout/`, `components/mobile/`, `pages/`. Report all instances found. Do not proceed until all are identified.

**E. If existing code found — decide:**

- **Extend** when same domain, natural fit, same patterns
- **Build new** when different domain, awkward refactoring, different stack
- **Block** when genuinely ambiguous or significant architectural decision

**Write a "Search complete" summary.** Use only this summary for all later decisions — do not re-paste raw grep output.

### 8. Block on Ambiguity

Stop and ask before implementing if:
- Task requirements are vague
- Need to guess IDs, formats, field names, API parameters
- Found existing code that might handle this
- Integration path unclear
- Specs contradict each other or are incomplete
- stdlib doesn't cover this pattern

**Integration checkpoint:** If you've built 2-3 isolated services without connecting them, stop. Check sprint_plan.md for Integration/Testing tasks. If none exist or the path is unclear, block and ask.

How to block: update sprint_plan.md with BLOCKED status, document the specific questions, and exit.

### 9. Check Test Requirements

Determine if Playwright tests are required before implementing.

**Tests required for:** user-facing features, critical user flows, form changes, auth, external API integrations.

**Tests optional for:** internal refactoring, CSS-only changes, documentation, backend-only with no UI impact.

If required, task is not complete until:
- Feature code implemented
- `data-testid` added to relevant UI elements
- Playwright test written (use AI test generator if available, otherwise follow patterns in existing `tests/*.spec.ts`)
- Test covers happy path and error states
- Test passes against staging

If blocked on test writing, mark BLOCKED with reason.

### 10. Implement

Follow specs/ requirements and stdlib/ patterns. Full implementation or nothing — no placeholders, no TODOs. If specs say deterministic, no AI/DB calls. If stdlib says Zod, use Zod.

### 11. Local Validation

```bash
npm run check
```

TypeScript must compile. Fix errors before proceeding. Do not push broken code.

We skip local E2E — real testing happens against staging.

### 12. Git Workflow

**A. Branch:** `ralph/task-{N}-{slug}` (slug: lowercase, hyphens, max 30 chars)

**B. Commit:** Stage specific files (not `git add -A`):
```bash
git commit -m "$(cat <<'EOF'
[Task #N] Brief description

- Detail 1
- Detail 2

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**C. Push:** `git push -u origin ralph/task-{N}-{slug}`

**D. Merge to main:**
```bash
git checkout main && git pull origin main
git merge ralph/task-{N}-{slug}
git push origin main
```

If merge conflicts: stop, report details, mark BLOCKED. Human resolves.

### 13. Wait for Staging

Staging auto-deploys in ~5 minutes after pushing to main.

```bash
sleep 300
curl -s -o /dev/null -w "%{http_code}" $RALPH_STAGING_URL/health
```

Expected: HTTP 200. If not responding, check the GitLab pipeline. If pipeline failed, BLOCK. If still running, wait 2 more minutes.

### 14. Test and Verify

**A. Run Playwright against staging:**

```bash
STAGING_URL=$RALPH_STAGING_URL npm test
```

Test against staging, not localhost. After each run, write a short test summary (e.g., "12 passed, 0 failed"). Use only this summary for decisions — do not re-paste full test output.

**B. Visual verification for UI changes:**

Sprint 3 Learning: 36% of UI tasks failed because code was committed but never visually verified.

1. Open staging in browser, navigate to affected page
2. Confirm the change is visible (check mobile viewport if applicable)
3. Run `git status` — if source files are modified, the change was NOT deployed

Do not mark UI tasks complete without visual verification.

**C. If tests fail:**

Determine if the test broke due to your code changes (heal the test with playwright-test-healer) or if your implementation has a bug (fix the code). Try up to 2 fix attempts, then BLOCK.

**D. Catastrophic failure (>50% tests failing or staging unresponsive):**

```bash
git revert HEAD
git push origin main
```

Wait for rollback deploy, mark task BLOCKED with failure details. Do not attempt additional rollback attempts — alert user for manual intervention.

### 15. Update sprint_plan.md

Update the plan as you work, not just at the end.

**Blocked mid-work:** Move task to Blocked section with reason and what's needed.

**Discovered new work:** Add to appropriate priority section with `(discovered during #N)`.

**Completing task:** Move to Completed section with this exact format:

```markdown
## Completed

- [x] **#4** Add globalTeardown to playwright.config.ts
  - Added tests/fixtures/globalTeardown.ts
  - Configured playwright.config.ts
  - **Performance:** SHELL_WILL_UPDATE
```

**The literal string `SHELL_WILL_UPDATE` is required.** The shell replaces it with actual duration, model, and cost after you exit. Do not attempt to calculate these yourself.

Update the "Last updated" timestamp.

### 16. Update RALPH.md

Only if you learned something new about building/running the project — a non-obvious build command, environment quirk, or validation pattern. One line per learning. Most tasks don't need a RALPH.md update.

### 17. Finish

**If sprint is NOT complete:**

Report what you implemented, validation results, sprint progress, and the next task. Then stop.

```
=== Task Complete ===

Implemented: [task description]
Validation: TypeScript, GitLab, Staging, Playwright
Sprint Progress: X/Y tasks
Next: [next task]

Run /ralph again to continue.
```

**If sprint IS complete:**

Invoke `/ralph-archive` with the project directory.

**Then stop.** Do not continue to the next task. Human reviews first.

---

## Time Tracking Reference

Shell handles all time/cost math. You handle status updates.

| Responsibility | You | Shell |
|---|---|---|
| Mark IN PROGRESS | Yes | - |
| Record what you did | Yes | - |
| Write `**Performance:** SHELL_WILL_UPDATE` | Yes | - |
| Calculate duration, cost, model label | - | Yes |
| Replace placeholder with actual data | - | Yes |
| Update sprint totals | - | Yes |

Why: LLMs are unreliable at arithmetic. Shell math is deterministic.

---

## Edge Cases

**Multiple items at same priority:** Pick the first one in the list.

**Item already implemented:** Search found it exists. Move to Completed, pick next item.

**Item is blocked:** Specs unclear, dependency missing. Move to Blocked section, document why, pick next unblocked item.

**No validation command:** Use standard validations (npm run check + Playwright against staging). Note minimal validation in completion entry.

**Unrelated tests fail:** Fix them. You own green tests before marking complete.

---

## Success Criteria

Complete when:
- ONE item implemented (not multiple)
- TypeScript compiles
- Committed, pushed, merged to main
- Deployed to staging
- Playwright tests pass against staging
- sprint_plan.md updated
- Code follows specs/ and stdlib/
- User knows what's next

Fails when:
- TypeScript won't compile
- Merge conflicts (human resolves)
- Staging deploy fails
- Tests fail after 2 fix attempts
- Placeholder implementation
- Multiple items implemented
