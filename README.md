# Ralph Starter Kit

AI-powered sprint execution. Define what to build, Ralph implements and deploys it, you review results.

**Without Ralph:** Spec → Code → Test → Debug → Commit → Push → Deploy → Test → Fix → Repeat

**With Ralph:** Spec → `claude "/ralph-continuous"` → Review deployed results

**Proven:** 6 sprints, $7.50 vs $1,750 baseline (99%+ savings).

---

## Prerequisites

**Windows:**
- Git Bash ([download](https://git-scm.com/download/win))
- Windows Terminal ([download](https://aka.ms/terminal)) - optional
  - Without: Sequential execution in current window
  - With: Parallel execution in new tabs (faster, better visibility)

**Mac:**
- Terminal.app (built-in) or iTerm2

**Everyone:**
- Claude Code CLI (`claude --version` works)
- Git repository with HTTPS remote
- Ralph skills installed (`claude` then `/ralph` autocompletes)

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

Creates: `ralph.config.sh`, `RALPH.md`, `sprint_plan.md`, `specs/`, `stdlib/`

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
Generates `sprint_plan.md` from Q&A.

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
- Skills missing. Contact team lead.

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

### Upgrading from ~/Documents/AI/

Old location: `~/Documents/AI/ralph-continuous.sh` (still works, no updates)
New location: `~/Documents/ralph/ralph-continuous.sh` (auto-installed)

**Migrate:**
```bash
rm ~/Documents/AI/ralph-continuous.sh
rmdir ~/Documents/AI 2>/dev/null
```

### Project Files

```
your-project/
├── ralph.config.sh      # Config: git, staging, tests
├── RALPH.md             # Build instructions
├── sprint_plan.md       # Task list
├── specs/               # Feature specs
├── stdlib/              # Code patterns
└── sprints/             # Archives
```

**ralph.config.sh:** Git remote, staging URL, test commands, timeouts

**RALPH.md:** Build instructions. Update when patterns change.

**sprint_plan.md:** Tasks Ralph reads. Created by `/ralph-plan`, updated by `/ralph`.

**specs/:** Requirements, API contracts, edge cases, success criteria

**stdlib/:** Code examples, test patterns, conventions

### Tips

**Clear specs:**
- Edge cases and error handling
- Validation commands
- Files to modify

**Small tasks:**
- 15-30 minutes each
- One feature/fix per task
- Clear success criteria

**Update RALPH.md:**
- Document mistakes
- Note project quirks
- Keep current

---

## More

- `EXAMPLES.md` - Detailed guides
- `CHANGELOG.md` - Version history
- Questions: Zach Partyka (zpartyka@zillow.com)

Internal Zillow use only.
