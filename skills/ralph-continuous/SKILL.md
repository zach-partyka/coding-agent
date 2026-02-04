---
name: ralph-continuous
description: Continuous building mode for Ralph with full interactive visibility - each task opens in a NEW terminal tab so you can watch Claude work with diffs and reasoning. Implements ALL items from sprint_plan.md until complete or blocked.
---

# Ralph Continuous Mode

Implement ALL items from `sprint_plan.md` until done or blocked, with **fresh context per task** and **full interactive visibility**.

## How It Works

Each task opens in a **new Terminal tab** with full interactive Claude UI:
- See every diff (red/green highlighting)
- Watch tool calls and reasoning in real-time
- Scroll back through any task's history
- Intervene if needed (Ctrl+C in the task tab)

The orchestrator tab waits for each task to complete, then spawns the next.

## Workflow

### 1. Get Project Directory

**Check if directory was provided in the prompt first.**

If the user's message contains "Project directory:" followed by a path, use that path directly.

**If no directory provided, use `AskUserQuestion` tool:**

```json
{
  "questions": [{
    "question": "Which project directory should I work in?",
    "header": "Project",
    "options": [
      {
        "label": "/Users/zachpa/Documents/AI/marketing-copilot-coaching",
        "description": "Marketing Copilot project"
      },
      {
        "label": "Enter different path",
        "description": "Specify a different project directory"
      }
    ],
    "multiSelect": false
  }]
}
```

**IMPORTANT:** Always use `AskUserQuestion` tool - do NOT just print text asking for input.

### 2. Validate Directory Structure

Use `ls` to check the project directory contents:

```bash
ls -la [PROJECT_DIR]
```

Verify these exist:
- ✅ `sprint_plan.md` (file)
- ✅ `specs` (directory)
- ✅ `stdlib` (directory)
- ✅ `RALPH.md` (file)

**If sprint_plan.md or RALPH.md missing:** Stop immediately.
**If specs/ or stdlib/ missing:** Warn but continue.

### 3. Start the Outer Loop

Run the bash script:

```bash
/Users/zachpa/Documents/AI/ralph-continuous.sh [PROJECT_DIR]
```

The script:
1. Detects your terminal (Terminal.app, iTerm2, or VS Code)
2. Opens a **new tab** for each task (or falls back to inline if needed)
3. Waits for task completion via marker file
4. Loops until all tasks complete or one blocks

### 4. Watch It Work

**You'll see two things:**

1. **Orchestrator tab** - Shows task transitions and progress dots
2. **Task tabs** - Full interactive Claude UI with diffs and reasoning

Switch between tabs to watch any task. Each tab stays open after completion so you can review the history.

**📊 Time & Cost Tracking:**

Each task tab runs `/ralph`, which **automatically tracks**:
- Start timestamp (captured with `date +%s`)
- End timestamp (captured on completion)
- Duration (calculated from timestamps)
- Token usage (input/output from system warnings)
- Cost (calculated from tokens × model pricing)

NO action needed - tracking happens automatically in each `/ralph` invocation. See `/ralph` skill instructions for details.

---

## Architecture

```
┌─────────────────────────────────────────┐
│  Orchestrator Tab                       │
│  - Spawns new tabs via AppleScript      │
│  - Waits for marker file                │
│  - Tracks progress                      │
└─────────────────────────────────────────┘
          │
          ▼ (opens new tab)
┌─────────────────────────────────────────┐
│  Task Tab (real TTY!)                   │
│  - Invokes /ralph for each task         │
│  - Full interactive Claude UI           │
│  - Colored diffs, tool calls            │
│  - Uses Playwright AI agents            │
│  - Touches marker file on completion    │
│  - Stays open for review                │
└─────────────────────────────────────────┘
```

**Each task runs the base `/ralph` skill, which includes:**
- Test requirement detection (step 5.75)
- Playwright AI test generation (via playwright-test-generator agent)
- E2E test execution against staging (step 10)
- Test healing when tests fail (via playwright-test-healer agent)

---

## Terminal Support

| Terminal | Full UI | How |
|----------|---------|-----|
| Terminal.app | ✅ | Opens new tabs via AppleScript |
| iTerm2 | ✅ | Opens new tabs via AppleScript |
| VS Code | ✅ | Uses `script` command for PTY allocation |
| Other | ⚠️ | Falls back to text mode |

**All three major terminals now support full interactive UI!**

VS Code uses a clever trick: the `script` command allocates a pseudo-terminal, making Claude think it has a real TTY. You get the full interactive experience in the same terminal.

---

## When to Use

- You want to **watch and learn** from how Claude works
- Tasks might need **human intervention**
- You're validating a new sprint plan
- You want full visibility into every file change

## When NOT to Use

- Running headless/overnight (requires active terminal)
- On Linux (AppleScript tab-spawning is macOS only, but PTY mode works)

---

## Resume After Block

1. Fix the blocking issue in sprint_plan.md
2. Run `/ralph-continuous` again

Ralph picks up where it left off (skips completed tasks).

---

## Safety Notes

Uses `--dangerously-skip-permissions` for auto-approval.

**Mitigations:**
- **Full visibility** - you see every file change in the task tab
- **Intervene anytime** - Ctrl+C in any task tab to stop it
- Keep sprints small and well-specified
- Commit before running (can rollback)
- Script stops on first error/block

---

## Sprint 3 Learning: Visual Validation Required

**36% of UI tasks in Sprint 3 failed visual validation** even though code was committed.

**Why:** Code commit ≠ UI change visible. Common failures:
- Changes uncommitted (in working directory only)
- Fixed one component but same text exists in others
- Edited wrong component (similar UI in multiple files)

**After ralph-continuous completes, always:**
1. Open staging in browser
2. Visually verify UI changes
3. Run `git status` to check for uncommitted changes

Ralph now includes visual verification steps, but human QA remains the final safety net.

---

## Playwright AI Agents Integration

Each task invoked by ralph-continuous uses the base `/ralph` skill, which includes Playwright AI agent support:

**Test Generation (Step 5.75):**
- Detects when tests are required (user-facing features, forms, auth, APIs)
- Invokes `playwright-test-generator` agent to create tests automatically
- Generated tests saved to `tests/*.spec.ts`

**Test Execution (Step 10):**
- Runs `npm test` against staging after deployment
- All E2E tests must pass before task is marked complete

**Test Healing (Step 10):**
- If tests fail due to code changes (not bugs), invokes `playwright-test-healer` agent
- Agent fixes tests automatically to match new behavior
- Re-runs tests to verify fix

**Setup Required:**
```bash
# Must be run before using ralph-continuous
npx playwright install chromium
npx playwright init-agents --loop=claude --prompts
```

**Verify agents available:**
```bash
ls .claude/agents/playwright-test-*.md
```

Expected: 3 agents (generator, healer, planner)
