---
name: ralph
description: Building mode for Ralph - implements ONE thing from sprint_plan.md and stops. Creates branch, implements per specs/stdlib, commits/pushes to GitLab, merges to main, waits for deploy, runs Playwright against the deploy target. Updates sprint_plan.md and RALPH.md. Stops after one thing for human review.
disable-model-invocation: true
argument-hint: [task-id]
---

## Session Context
!`cat .ralph-markers/session-context.txt 2>/dev/null || echo "No session context — manual run"`

## Current Sprint
!`head -80 sprint_plan.md 2>/dev/null || echo "No sprint_plan.md found — run /ralph-plan first"`

# Ralph Building Mode

**One task per run.** Do one open task, then stop. No second tasks. No re-describing completed work.

## What's Already in This Prompt

The skill template above injects two things. **Use them directly. Do NOT re-read these files.**

1. **Session Context** — contains `projectDir`, `taskNum`, `doneMarker`, `sprintCompleteMarker`
2. **Current Sprint** — first 80 lines of `sprint_plan.md`

If Session Context says "No session context — manual run", ask for the project directory.
If Current Sprint says "No sprint_plan.md found", tell the user to run `/ralph-plan`.

### Session Context Keys

| Key | Meaning |
|---|---|
| `projectDir` | Project directory. Use for all file paths. |
| `taskNum` | **Run index** (1st, 2nd, 3rd run). For marker filenames only. **Not the task ID.** |
| `doneMarker` | `touch` this path when the task is done. |
| `sprintCompleteMarker` | `touch` this path when no unchecked tasks remain. |

## Task Selection

**If `/ralph 4` or `/ralph #4`:** Find task #4 in sprint_plan.md. If completed or blocked, say so and stop.

**If `/ralph` (no argument):** Pick the first unchecked `[ ]` item by priority: Critical Path > High > Medium > Low. Skip the Blocked section. The task ID is the `#N` in the plan (e.g. **#9**) — this is unrelated to `taskNum`.

If all tasks are done or blocked, `touch` both markers and stop.

## Workflow

### 1. Study Context

Read these if they exist (do NOT read sprint_plan.md — it's already injected):
- **specs/** — requirements, constraints, success criteria
- **ralph-config.md** — project config + stack standards (the ## Stack Standards section)
- **RALPH.md** — build/run/test instructions

### 2. Clock In

Mark the task IN PROGRESS in sprint_plan.md:

```markdown
- [ ] **#4** Add globalTeardown to playwright.config.ts - IN PROGRESS
  - Started: 2026-02-10
  - Model: Sonnet 4.6 (default)
```

If the prompt contains `"Ralph model: [value]"`, note it.

### 3. Investigation Tasks

If the task says "investigate", "audit", "research", or "diagnose":

1. Do the investigation (10-15 min max).
2. Write findings as sub-bullets under the task.
3. Add follow-up tasks as new unchecked `[ ]` items in sprint_plan.md. **This is required** — the shell loop stops if no unchecked tasks exist.
4. Move the investigation to Completed.

Skip this step for features with clear specs or continuation work.

### 4. Search Codebase

**Always search before writing new code.** Use the `code-explorer` agent.

Search for: (A) files matching the feature name, (B) related functions/imports, (C) existing partial implementations.
For UI text/labels: grep all of `client/` and list every occurrence.

Extend existing code when possible. Add new code only for different areas. Block if unclear.

Write one short summary. No long grep output.

### 5. Block on Ambiguity

Do not implement if you'd have to guess IDs, formats, field names, API params, or integration points. Do not implement if specs conflict.

To block: move the task to the Blocked section in sprint_plan.md with exact questions, then stop.

### 6. Check Test Requirements

**Tests required for:** user-facing features, critical flows, form changes, auth, external API integrations.
**Tests optional for:** refactoring, CSS-only, docs, backend-only with no UI.

If required, the task is not done until Playwright tests pass against the deploy target.

### 7. Implement

Follow specs/ and ralph-config.md Stack Standards patterns. Full implementation — no placeholders, no TODOs.

### 8. Validate

Use the `build-validator` agent to run `npm run check`. TypeScript must compile. Fix errors before proceeding.

### 9. Git

**Branch:** `ralph/task-{N}-{slug}` (slug: lowercase, hyphens, max 30 chars)

**Commit:** Stage specific files (not `git add -A`):
```bash
git commit -m "$(cat <<'EOF'
[Task #N] Brief description

- Detail 1
- Detail 2

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**Push:** `git push -u origin ralph/task-{N}-{slug}`

**Merge:**
```bash
git checkout main && git pull origin main
git merge ralph/task-{N}-{slug}
git push origin main
```

Merge conflicts: stop, report, mark BLOCKED. Human resolves.

### 10. Wait for Deploy

Auto-deploys ~5 minutes after push to main.

```bash
sleep 300
curl -s -o /dev/null -w "%{http_code}" $RALPH_DEPLOY_URL/health
```

Expected: HTTP 200. If not, check pipeline. Pipeline failed = BLOCK. Still running = wait 2 more minutes.

### 11. Test and Verify

Use the `playwright-runner` agent:

```bash
STAGING_URL=$RALPH_DEPLOY_URL npm test
```

Write a short summary (e.g. "12 passed, 0 failed"). No full test output.

**UI changes:** Open deploy target in browser, confirm visually. Run `git status` — modified source files means NOT deployed. Do not mark UI tasks complete without visual verification.

**Test failures:** Determine if your code broke the test or if the test needs healing. Try up to 2 fixes, then BLOCK.

**Catastrophic failure (>50% failing or deploy unresponsive):**
```bash
git revert HEAD
git push origin main
```
Mark BLOCKED. Do not retry — alert user.

### 12. Update sprint_plan.md

Update as you work, not just at the end.

**Completing:** Move to Completed with this format:
```markdown
- [x] **#4** Add globalTeardown to playwright.config.ts
  - What you did
  - **Performance:**
```
The `**Performance:**` line is required but leave it empty — the shell wrapper fills in duration and cost after you exit.

**Discovered work:** Add as new `[ ]` items with `(discovered during #N)`.

Update the "Last updated" timestamp.

### 13. Update RALPH.md

Only if you learned a non-obvious build/run/test fact. One line. Most tasks skip this.

### 14. Finish

Touch `doneMarker`. If no unchecked tasks remain, also touch `sprintCompleteMarker`.

**Sprint not complete:**
```
=== Task Complete ===
Implemented: [one-line description]
Validation: TypeScript, GitLab, Deploy, Playwright
Sprint Progress: X/Y tasks
Next: [next task title]
Run /ralph again to continue.
```

**Sprint complete:** Run `/ralph-archive` with the project directory, then stop.

---

## Time Tracking

Shell handles all duration/cost math. Write an empty `**Performance:**` line under completed tasks — the shell fills in the values.

## Edge Cases

| Situation | Action |
|---|---|
| Multiple tasks at same priority | Pick the first in the list |
| Task already implemented (found in codebase) | Move to Completed, pick next |
| Task is blocked | Move to Blocked with reason, pick next unblocked |
| No validation command available | Use `npm run check` + Playwright. Note minimal validation. |
| Unrelated tests fail | Fix them. You own green tests. |

## Success Criteria

Done when:
- One task implemented
- TypeScript compiles
- Committed, pushed, merged to main
- Deployed to deploy target
- Playwright tests pass
- sprint_plan.md updated

Fails when:
- TypeScript won't compile
- Merge conflicts (human resolves)
- Deploy fails
- Tests fail after 2 fix attempts
- Placeholder implementation
- Multiple tasks in one run
- Re-describing completed work
