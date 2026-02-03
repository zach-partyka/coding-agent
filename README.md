# Ralph Starter Kit

**What:** AI-powered sprint execution that automates your entire development workflow.

**Impact:** Define what to build, Ralph implements it autonomously, you review deployed results.

**Without Ralph:**
```
Write specs → Write code → Write tests → Debug → Commit → Push →
Wait for deploy → Test staging → Fix bugs → Repeat
```

**With Ralph:**
```
Write specs → claude "/ralph-continuous" → Review deployed results
```

**Proven savings:** 6 sprints at $7.50 total vs $1,750 engineer baseline (99%+ cost reduction).

---

## Prerequisites

**Windows:**
- Git Bash ([download](https://git-scm.com/download/win)) - **required**
- Windows Terminal ([download](https://aka.ms/terminal)) - **optional, recommended**
  - Without it: Tasks run sequentially in current window
  - With it: Each task opens in new tab (faster, better visibility)

**Mac:**
- Terminal.app (built-in) or iTerm2 (recommended)

**Everyone:**
- Claude Code CLI (`claude --version` should work)
- Git repository with HTTPS remote
- Ralph skills installed (type `claude` then `/ralph` to verify)

> **Windows users:** Run all commands in Git Bash, not PowerShell or CMD.

---

## Quick Start

### 1. Clone this repo

```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git
cd ralph-starter-kit
```

### 2. Run setup in your project

```bash
cd /path/to/your/project
/path/to/ralph-starter-kit/scripts/setup.sh
```

Setup will detect your project type and create:
- `ralph.config.sh` - Git remote, staging URL, test commands
- `RALPH.md` - Build instructions for Ralph
- `sprint_plan.md` - Sprint task tracker
- `specs/` and `stdlib/` - What to build and how to build it

### 3. Run your first sprint

```bash
# Plan the sprint (answers questions, creates tasks)
claude "/ralph-plan"

# Execute the sprint (implements all tasks)
claude "/ralph-continuous"
```

Done. Ralph will implement, test, commit, push, deploy, and validate each task automatically.

---

## How to Use Ralph

**Plan a sprint:**
```bash
claude "/ralph-plan"
```
Answers questions about what to build, generates `sprint_plan.md`.

**Execute a sprint:**
```bash
claude "/ralph-continuous"
```
Implements all tasks. Opens each task in a new terminal tab so you can watch progress.

**Run one task:**
```bash
claude "/ralph"
```
Implements one task, then stops. Good for learning or testing.

**What happens per task:**
1. Creates git branch
2. Implements feature (follows `specs/` and `stdlib/` patterns)
3. Runs local tests
4. Commits and pushes
5. Waits for staging deployment
6. Runs integration tests against staging
7. Updates `sprint_plan.md`

---

## Examples

**Try Ralph on an example project first:**

```bash
cd ralph-starter-kit/examples/nodejs-typescript
../../scripts/setup.sh
claude "/ralph-plan"
claude "/ralph-continuous"
```

**Example projects included:**
- `examples/nodejs-typescript/` - Express + Playwright (Marketing Copilot reference)
- `examples/python-fastapi/` - FastAPI + pytest (Zillow standard)

Each includes:
- `ralph.config.sh` - Configured for example project
- `RALPH.md` - Build instructions
- `specs/` - Example feature specs
- `stdlib/` - Code patterns

---

## Troubleshooting

**Setup fails with "Claude CLI not found":**
- Install Claude Code: `claude --version` should work
- Zillow users: Install via [ServiceNow](https://zillow.service-now.com/esc?id=sc_cat_item&sys_id=5ef70cfb93bfea149922f60b6aba10a9)

**"/ralph command not found":**
- Skills not installed. Contact your team lead.

**Tests fail:**
- Run test command manually to see error
- Python: activate venv first (`source venv/bin/activate`)
- Node.js: install dependencies (`npm install`)

**Git push rejected:**
- Verify HTTPS remote: `git remote -v`
- If SSH (`git@...`), switch to HTTPS:
  ```bash
  git remote set-url origin https://gitlab.zgtools.net/your-team/your-repo.git
  ```

**Windows Terminal doesn't spawn tabs:**
- See Advanced section below for Windows Terminal profile setup

**More help:** See `EXAMPLES.md` for detailed guides.

---

## Advanced

### Custom Installation Path

Install `ralph-continuous.sh` to a custom location:

```bash
/path/to/ralph-starter-kit/scripts/setup.sh --path ~/custom-location
```

Default: `~/Documents/ralph/`

### iTerm2 Hotkey (macOS)

Run sprints with one keypress instead of typing commands.

**Setup:**
1. iTerm2 → Preferences (Cmd+,) → Keys → Key Bindings → Click "+"
2. Configure:
   - **Keyboard Shortcut:** Press `Shift+Cmd+R`
   - **Action:** "Send Text with vim Special Chars"
   - **Text:** `claude "/ralph-continuous"\n` (include `\n`)
3. Click OK

**First use:** macOS will prompt for Accessibility permission. Grant it in System Settings → Privacy & Security.

**Usage:** Press `Shift+Cmd+R` from your project directory to start a sprint.

**Other useful hotkeys:**
- `Shift+Cmd+P` → `claude "/ralph-plan"\n` (planning)
- `Shift+Cmd+T` → `claude "/ralph"\n` (single task)

### Windows Terminal Setup

**If terminal tabs don't spawn on Windows:**

1. Open Windows Terminal → Settings (Ctrl+,)
2. Click "+ Add a new profile" → "New empty profile"
3. Configure:
   - **Name:** `Git Bash`
   - **Command line:** `C:\Program Files\Git\bin\bash.exe`
   - **Starting directory:** `%USERPROFILE%`
   - **Advanced → Close on exit:** `Never` (or `Only on success`)
4. Save

**Custom profile name?** Set environment variable:
```bash
export RALPH_WT_PROFILE="YourProfileName"
```

### Upgrading from ~/Documents/AI/

**If you previously installed to `~/Documents/AI/`:**

New location is `~/Documents/ralph/`. Old installation still works but won't get updates.

**To migrate:**
```bash
rm ~/Documents/AI/ralph-continuous.sh
rmdir ~/Documents/AI 2>/dev/null  # if empty
```

New installs will use `~/Documents/ralph/` automatically.

### Project Files Reference

After setup, your project has:

```
your-project/
├── ralph.config.sh      # Git remote, staging URL, test commands
├── RALPH.md             # Build instructions for Ralph
├── sprint_plan.md       # Current sprint tasks
├── specs/               # Feature specifications (what to build)
├── stdlib/              # Code patterns (how to build)
└── sprints/             # Completed sprint archives
```

**ralph.config.sh** - Configuration (git remote, staging URL, test commands, deploy wait times)

**RALPH.md** - Build instructions. Update when you discover new patterns or project quirks.

**sprint_plan.md** - Task list Ralph reads. Created by `/ralph-plan`, updated by `/ralph`.

**specs/** - Feature requirements (API contracts, edge cases, success criteria)

**stdlib/** - Technical patterns (code examples, testing patterns, conventions)

### Tips for Better Results

**Write clear specs:**
- Describe edge cases and error handling
- Include validation commands
- Specify which files to modify

**Keep tasks small:**
- 15-30 minutes per task
- One feature or fix per task
- Clear success criteria

**Update RALPH.md as you learn:**
- Add "Learned Lessons" when Ralph makes mistakes
- Document project quirks
- Keep build instructions current

---

## More Information

- `EXAMPLES.md` - Detailed setup guides and troubleshooting
- `CHANGELOG.md` - Version history
- Questions? Ask Zach Partyka (zpartyka@zillow.com)

Internal Zillow use only.
