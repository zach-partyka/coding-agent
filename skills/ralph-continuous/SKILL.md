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
│  - Full interactive Claude UI           │
│  - Colored diffs, tool calls            │
│  - Touches marker file on completion    │
│  - Stays open for review                │
└─────────────────────────────────────────┘
```

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
