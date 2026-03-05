---
name: ralph
description: Building mode for Ralph - implements ONE thing from sprint_plan.md and stops. Creates branch, implements per specs/stdlib, commits/pushes to GitLab, merges to main, waits for staging deploy, runs Playwright against staging. Updates sprint_plan.md and RALPH.md. Stops after one thing for human review.
---

# Ralph Building Mode

**One task per run.** Pick the single next **open** task from `sprint_plan.md` (one unchecked `[ ]` item). Do that task. Then stop. Do not start a second task. Do not re-do or re-describe work that is already completed — that wastes tokens. The next run will get the next open task.

## When to use this skill

- There is a `sprint_plan.md` (from `/ralph-plan`).
- You are doing the **next open task only**, then stopping for human review.

## When the prompt is only "/ralph" (run from terminal wrapper)

You were started from a terminal (e.g. iTerm2). The prompt is just `/ralph`. All session data is in a file.

**Step 1 — Read session context.**  
Open `.ralph-markers/session-context.txt` in the project. The wrapper wrote it before starting you. It has one line per key:
- `projectDir=` → use this path as the project directory for everything below.
- `taskNum=` → **run index only** (1st run, 2nd run, …). Used for marker file names. **It is NOT the task ID in sprint_plan.md.** Do not use it to choose which task to do.
- `doneMarker=` → when the task is done, run `touch` on this path.
- `sprintCompleteMarker=` → if there are no unchecked tasks left, also run `touch` on this path.

**Which task to do:** Always pick the **single next open task** from sprint_plan.md (first unchecked `[ ]` by priority: Critical Path → High → Medium → Low). That task has a number like **#9** in the plan — that is the sprint task ID. Implement that one. Ignore the `taskNum` value in session-context when selecting the task.

**Step 2 — If the file is missing** (e.g. someone ran /ralph by hand):  
Ask for the project directory. Do one task from sprint_plan.md, then stop. Do not touch any marker files.

**Step 3 — If the file exists:**  
- Use `projectDir` as the project directory. Do not ask.
- Do the **one** next open task from sprint_plan.md (first unchecked `[ ]` by priority). The plan uses IDs like #1, #2, #9 — use the plan, not `taskNum` from the file. Do not start another task. Do not re-do completed tasks.
- When that task is done: `touch` the path in `doneMarker`.
- If the sprint has no unchecked tasks left: `touch` the path in `sprintCompleteMarker`.
- Then stop. The next run will pick the next open task.

## Workflow

### 1. Get Project Directory

1. If you read `.ralph-markers/session-context.txt` and it has `projectDir=...`, use that path. Stop here.
2. Else if the user message contains "Project directory:" and a path, use that path. Stop here.
3. Else ask: "Which project directory should I work in? (Full path to the repo that has sprint_plan.md and RALPH.md)"

### 2. Validate Directory

Run `ls -la` on the project directory.

**Must be there (stop if missing):** `sprint_plan.md`, `RALPH.md`. If sprint_plan.md is missing, tell the user to run `/ralph-plan`.

**Optional (warn but continue):** `specs/`, `stdlib/`.

Do not use glob patterns in commands; they can fail even when the dirs exist.

### 3. Study Context

Read these in parallel:
- **sprint_plan.md** — identify unchecked `[ ]` items and priorities
- **specs/** — what to build (requirements, constraints, success criteria)
- **stdlib/** — how to build (coding patterns, conventions)
- **RALPH.md** — build/run/test instructions

### 4. Select Task

Choose the **single next open task** — the first unchecked `[ ]` item in sprint_plan.md. Skip BLOCKED. Ignore all `[x]` items; do not re-do or describe completed work.

**Order to pick:** Critical Path first, then High, then Medium, then Low. The task has an ID in the plan (e.g. **#9**). That ID is from the plan, not from session-context `taskNum` (which is the run index). If everything is blocked or done, stop and say so. You do only this one task this run.

Say which task you chose (ID and title from the plan) and which section it was in.

### 5. Clock In

Mark the task IN PROGRESS in sprint_plan.md:

```markdown
- [ ] **#4** Add globalTeardown to playwright.config.ts - IN PROGRESS
  - Started: 2026-02-10
  - Model: Sonnet 4.6 (default)
```

Check the prompt for `"Ralph model: [value]"` — if present, note it.

Shell handles timestamp capture. You just mark the status.

### 6. Investigation Tasks

If the current task is labeled "investigate", "audit", "research", or "diagnose" — do the investigation, then **immediately add follow-up tasks as unchecked `[ ]` items** in `sprint_plan.md` before marking the investigation complete.

**Why this matters:** The shell loop only continues if unchecked `[ ]` tasks exist. If you write findings as prose but don't add task items, Ralph stops and the sprint stalls.

**How to complete an investigation task:**

1. Do the investigation (time-box to 10–15 min).
2. Write a short findings summary as sub-bullets under the task.
3. Add each recommended follow-up as a new unchecked task in the appropriate priority section:

```markdown
- [ ] **#N** Fix [specific thing found] (from investigation #M)
```

4. Move the investigation task to Completed.
5. The shell loop will pick up the new tasks automatically.

**Skip investigation mode for:** new features with clear specs, continuation of previous sprint work.

### 7. Search Codebase

**Always search before writing new code.** Most past failures were from adding new code instead of extending existing code.

With the task marked IN PROGRESS, search for: (A) files whose names match the feature, (B) related function names and imports, (C) similar or partial implementations (including Python for API work). For **UI text or labels**, grep all of `client/` (e.g. `components/layout/`, `components/mobile/`, `pages/`) and list every place the text appears; fix all of them or block.

If you find existing code: **extend** it when it fits; **add new** only when it’s a different area or stack; **block** when it’s unclear or a big design choice.

Write one short "Search complete" summary and use that for decisions. Do not paste long grep output.

### 8. Block on Ambiguity

Do **not** implement if you would have to guess: IDs, formats, field names, API params, or how this fits with existing code. Do **not** implement if specs conflict or stdlib doesn’t cover the pattern. If you’ve added 2–3 separate pieces and they’re not wired together, stop and check sprint_plan.md for an integration task; if none or unclear, block.

**To block:** Put the task in the Blocked section of sprint_plan.md with the exact questions, then exit.

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

**Completing task:** Move the task to the Completed section. Use this format (keep the line `**Performance:** SHELL_WILL_UPDATE` exactly; the shell fills in duration/cost later):

```markdown
- [x] **#4** Add globalTeardown to playwright.config.ts
  - Added tests/fixtures/globalTeardown.ts
  - Configured playwright.config.ts
  - **Performance:** SHELL_WILL_UPDATE
```

Update the "Last updated" timestamp.

### 16. Update RALPH.md

Only if you learned something new about building/running the project — a non-obvious build command, environment quirk, or validation pattern. One line per learning. Most tasks don't need a RALPH.md update.

### 17. Finish

**Sprint not complete:** Report in this format, then stop:

```
=== Task Complete ===
Implemented: [one-line task description]
Validation: TypeScript, GitLab, Staging, Playwright
Sprint Progress: X/Y tasks
Next: [next task title]
Run /ralph again to continue.
```

**Sprint complete (no unchecked tasks):** Run `/ralph-archive` with the project directory, then stop. Do not start another task.

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

**session-context `taskNum` vs sprint_plan task ID:** `taskNum` in the file is the **run index** (1st, 2nd, 3rd run). It is not the task ID (#1, #2, #9) in sprint_plan.md. After a reopened sprint or multiple runs, `taskNum` might be 2 while the only open task in the plan is #9. Always choose by the plan: first open `[ ]` by priority. Ignore `taskNum` for task selection.

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
- Multiple items implemented in one run (do one open task only)
- Re-doing or re-describing already completed tasks (wastes tokens)
