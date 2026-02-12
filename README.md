# Ralph Starter Kit

AI-powered sprint execution. Define what to build, Ralph implements and deploys it, you review results.

**Without Ralph:** Spec → Code → Test → Debug → Commit → Push → Deploy → Test → Fix → Repeat

**With Ralph:** Spec → `claude "/ralph-continuous"` → Review deployed results

**Proven:** 20 sprints, ~$7.50 total vs ~$7,000 engineer baseline (99%+ savings).

**Cross-platform:** Works on macOS and Windows (Git Bash).

---

## Prerequisites

**Windows:**
- Git Bash ([download](https://git-scm.com/download/win))
- Windows Terminal ([download](https://aka.ms/terminal)) - optional
  - Without: Sequential execution in current window
  - With: Parallel execution in new tabs (faster, better visibility)

**Mac:**
- Terminal.app (built-in) or iTerm2 (recommended)
  - Terminal.app: Opens new windows per task (clutters screen)
  - iTerm2: Opens new tabs in same window (cleaner)

**Everyone:**
- Claude Code CLI (`claude --version` works)
- Git repository with HTTPS remote

> **Windows:** Use Git Bash for all commands, not PowerShell/CMD.

---

## Quick Start

### 1. Clone

```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git
cd ralph-starter-kit
```

### 2. Setup

```bash
cd /path/to/your/project
/path/to/ralph-starter-kit/scripts/setup.sh
```

Installs Ralph skills and creates: `ralph.config.sh`, `RALPH.md`, `roadmap.md`, `sprint_plan.md`, `specs/`, `stdlib/`, `sprints/`

### 3. Run

```bash
claude "/ralph-plan"        # Plan sprint
claude "/ralph-continuous"  # Execute sprint
```

Ralph implements, tests, commits, pushes, deploys, and validates each task.

---

## How to Use

**Plan:**
```bash
claude "/ralph-plan"
```
Pulls items from `roadmap.md` and generates `sprint_plan.md` through Q&A.

**Execute all tasks:**
```bash
claude "/ralph-continuous"
```
Opens each task in new terminal tab. Watch progress live.

**Execute one task:**
```bash
claude "/ralph"
```
Implements one task, stops. Good for testing.

**Per-task workflow:**
1. Create git branch
2. Implement (follows `specs/` and `stdlib/`)
3. Run local tests
4. Commit and push
5. Wait for staging deployment
6. Run integration tests
7. Update `sprint_plan.md`

---

## Examples

**Try it:**
```bash
cd ralph-starter-kit/examples/nodejs-typescript
../../scripts/setup.sh
claude "/ralph-plan"
claude "/ralph-continuous"
```

**Included examples:**
- `examples/nodejs-typescript/` - Express + Playwright
- `examples/python-fastapi/` - FastAPI + pytest

Each has: config, build instructions, specs, code patterns.

---

## Troubleshooting

**"Claude CLI not found":**
- Install: `claude --version` should work
- Zillow: [ServiceNow](https://zillow.service-now.com/esc?id=sc_cat_item&sys_id=5ef70cfb93bfea149922f60b6aba10a9)

**"/ralph not found":**
- Skills not installed. Run setup.sh again or verify `~/.claude/skills/` has ralph directories.

**Tests fail:**
- Run test command manually
- Python: activate venv (`source venv/bin/activate`)
- Node.js: install deps (`npm install`)

**Git push rejected:**
- Check: `git remote -v` (must be HTTPS, not SSH)
- Fix: `git remote set-url origin https://gitlab.zgtools.net/your-team/repo.git`

**Windows tabs don't spawn:**
- See Advanced → Windows Terminal Setup

**More:** See `EXAMPLES.md`

---

## Advanced

### Custom Install Path

```bash
/path/to/ralph-starter-kit/scripts/setup.sh --path ~/custom-location
```

Default: `~/Documents/ralph/`

### iTerm2 Hotkey (macOS)

Press one key to run sprints.

**Setup:**
1. iTerm2 → Preferences (Cmd+,) → Keys → Key Bindings → "+"
2. Shortcut: `Shift+Cmd+R`, Action: "Send Text with vim Special Chars", Text: `claude "/ralph-continuous"\n`
3. Grant Accessibility permission when prompted

**Other hotkeys:**
- `Shift+Cmd+P` → `claude "/ralph-plan"\n`
- `Shift+Cmd+T` → `claude "/ralph"\n`

### Windows Terminal Setup

**If tabs don't spawn:**

1. Windows Terminal → Settings (Ctrl+,) → "+ Add profile" → "New empty profile"
2. Name: `Git Bash`, Command: `C:\Program Files\Git\bin\bash.exe`, Start dir: `%USERPROFILE%`
3. Advanced → Close on exit: `Never`

**Custom profile name:**
```bash
export RALPH_WT_PROFILE="YourProfileName"
```

### Project Files

```
your-project/
├── ralph.config.sh      # Config: git, staging, tests
├── RALPH.md             # Build instructions
├── roadmap.md           # What to build (Now / Next / Later)
├── sprint_plan.md       # Current sprint tasks
├── specs/               # Feature specs
├── stdlib/              # Code patterns
└── sprints/             # Sprint archives
    ├── sprint_history.md
    └── sprint-N-theme/
        └── sprint_summary.md
```

**ralph.config.sh:** Git remote, staging URL, test commands, timeouts.

**RALPH.md:** Build instructions. Update when patterns change.

**roadmap.md:** Product roadmap with Now / Next / Later sections. `/ralph-plan` pulls items from the **Now** section to build sprints. `/ralph-archive` flows follow-ups back here after each sprint.

**sprint_plan.md:** Current sprint tasks. Created by `/ralph-plan`, updated by `/ralph` during execution.

**specs/:** Requirements, API contracts, edge cases, success criteria.

**stdlib/:** Code examples, test patterns, conventions.

**sprints/:** Sprint archives. `sprint_history.md` is an index of all completed sprints. Each sprint gets its own folder with a `sprint_summary.md` containing performance metrics, ROI, and learnings. Created automatically by `/ralph-archive`.

### Tips

**Clear specs:**
- Edge cases and error handling
- Validation commands
- Files to modify

**Small tasks:**
- 15-30 minutes each
- One feature/fix per task
- Clear success criteria

**Keep your roadmap current:**
- Add features to `roadmap.md` in the Now / Next / Later sections
- `/ralph-plan` reads the Now section to suggest sprint items
- Move items between sections as priorities change

**Run retrospectives:**
- `/ralph-archive` archives the sprint, generates a summary with ROI metrics, and updates RALPH.md with learnings
- Follow-ups flow back to `roadmap.md` automatically
- Keeps build instructions current

---

## More

- `EXAMPLES.md` - Detailed guides
- `CHANGELOG.md` - Version history
- Questions: Zach Partyka (zpartyka@zillow.com)

Internal Zillow use only.
