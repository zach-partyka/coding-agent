# Ralph Starter Kit

AI-powered sprint execution for your development projects. Define what to build, Ralph implements it autonomously, you review the results.

**Proven Results:** 6 sprints completed at $7.50 total cost vs. $1,750 engineer baseline.

---

## Before You Begin

Make sure you have these installed:

**Windows users:**
- [ ] **Git Bash** ([Git for Windows](https://git-scm.com/download/win))
- [ ] **Windows Terminal** ([Microsoft Store](https://aka.ms/terminal) or built-in on Windows 11)
  - **Configure Git Bash profile:**
    1. Open Windows Terminal → Settings (Ctrl+,)
    2. Click "+ Add a new profile" → "New empty profile"
    3. **Name:** `Git Bash`
    4. **Command line:** `C:\Program Files\Git\bin\bash.exe`
    5. **Starting directory:** `%USERPROFILE%`
    6. Under **Advanced** → **Close on exit:** Select `Never` (or `Only on success`)
    7. Click **Save**

  **Custom profile name?** Set environment variable:
  ```bash
  export RALPH_WT_PROFILE="YourProfileName"
  ```

**Mac users:**
- [ ] iTerm2 (recommended) or Terminal.app (Terminal.app is built-in)
  - **Zillow users:** Install iTerm2 via Jamf Self Service (search "iTerm2" in the Self Service app on your Mac)

**Everyone:**
- [ ] Claude Code CLI installed (`claude --version` should work)
  - **Zillow users:** Install via [ServiceNow](https://zillow.service-now.com/esc?id=sc_cat_item&sys_id=5ef70cfb93bfea149922f60b6aba10a9)
- [ ] GitLab access configured (HTTPS with authentication token)
- [ ] Ralph skills installed in Claude Code
  - Verify: Type `claude` then `/ralph` - should autocomplete
  - If missing: Contact your team lead for skill installation

**Need a test project?** Use the examples in this repo (see Step 2 below).

---

## Quick Start

> **Windows users:** Use **Git Bash** for all commands below (not PowerShell or CMD)

### 1. Clone the Starter Kit

```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git
cd ralph-starter-kit
```

### 2. Set Up Your Project

**Important:** Run this in an existing project with code (not an empty directory).

**Testing first?** Try Ralph on an example project:
```bash
cd examples/nodejs-typescript
../../scripts/setup.sh
```

**Ready for your real project?** Run setup in your project directory:
```bash
cd /path/to/your/project
/path/to/ralph-starter-kit/scripts/setup.sh
```

**Custom installation path?** Use the `--path` flag:
```bash
/path/to/ralph-starter-kit/scripts/setup.sh --path ~/my-custom-location
```

The setup script will:
- ✓ Check prerequisites (Git Bash, Claude CLI)
- ✓ Detect your project type (Node.js, Python, Go, etc.)
- ✓ Create project configuration (`ralph.config.sh`)
- ✓ Create build instructions (`RALPH.md`)
- ✓ Create sprint tracker (`sprint_plan.md`)
- ✓ Set up specs/ and stdlib/ directories
- ✓ Install ralph-continuous.sh to `~/Documents/ralph/` (first time only)

### 3. Run Your First Sprint

```bash
cd /path/to/your/project

# Plan your sprint
claude "/ralph-plan"

# Execute it
claude "/ralph-continuous"
```

Done! Ralph will implement, test, commit, and deploy each task automatically.

---

## Upgrading from Previous Installation

**If you previously installed ralph-continuous.sh to `~/Documents/AI/`:**

The new standard location is `~/Documents/ralph/ralph-continuous.sh`.

When you run `setup.sh` in a new project, it will install to the new location. Your old installation will continue to work but won't receive updates.

**To migrate to the new location:**

```bash
# Remove old installation
rm ~/Documents/AI/ralph-continuous.sh

# Optionally remove old directory if empty
rmdir ~/Documents/AI 2>/dev/null

# New installations will go to ~/Documents/ralph/
```

**Or keep using your old location:**
- You'll need to manually copy updates from `ralph-starter-kit/scripts/ralph-continuous.sh`
- Won't get automatic updates when running setup.sh in new projects

---

## How to Use Ralph

### Planning a Sprint
```bash
claude "/ralph-plan"
```
Answers questions about what you want to build, creates sprint_plan.md with tasks.

### Running a Sprint

**Option 1: Command Line**
```bash
claude "/ralph-continuous"
```
Runs all tasks automatically. Each task opens in a new terminal tab so you can watch progress.

**Option 2: Keyboard Shortcut (Optional)**
```
Press Shift+Cmd+R (macOS only - see Advanced section below)
```
Same as command line, but with one keypress.

**Option 3: One Task at a Time**
```bash
claude "/ralph"
```
Implements one task, then stops. Good for learning or cautious iteration.

### What Ralph Does

For each task:
1. Creates git branch
2. Implements the feature (follows specs/ and stdlib/ patterns)
3. Runs tests
4. Commits and pushes
5. Waits for staging deployment
6. Runs integration tests
7. Updates sprint_plan.md

---

## Project Files

After setup, your project will have:

```
your-project/
├── ralph.config.sh      # Your project's configuration
├── RALPH.md             # Build instructions for Ralph
├── sprint_plan.md       # Current sprint tasks
├── specs/               # What to build (requirements)
├── stdlib/              # How to build (code patterns)
└── sprints/             # Completed sprint history
```

### ralph.config.sh
Tells Ralph about your project:
- Git repository URL
- Staging environment URL
- How to run tests
- Deployment wait times

### RALPH.md
Instructions for building and testing your project. Update this when you discover new patterns or quirks.

### sprint_plan.md
Your current sprint tasks. Ralph reads this to know what to build next.

### specs/
Feature specifications. Describe WHAT to build:
- Requirements
- API contracts
- Edge cases
- Success criteria

### stdlib/
Technical patterns. Describe HOW to build:
- Code examples
- Testing patterns
- Project-specific conventions

---

## Examples

Complete examples are in the `examples/` directory:

### Python/FastAPI
Full configuration for Python projects using FastAPI (Zillow standard).

**See:**
- `examples/python-fastapi/ralph.config.sh` - Configuration
- `examples/python-fastapi/RALPH.md` - Build instructions
- `examples/python-fastapi/specs/` - Example API specs
- `examples/python-fastapi/stdlib/` - FastAPI patterns

### Node.js/TypeScript
Reference from Marketing Copilot (6 sprints, $7.50 cost).

**See:**
- `examples/nodejs-typescript/ralph.config.sh` - Configuration
- `examples/nodejs-typescript/RALPH.md` - Build instructions
- `examples/nodejs-typescript/specs/` - Example API specs
- `examples/nodejs-typescript/stdlib/` - Express + Playwright patterns

---

## Troubleshooting

### Hotkey doesn't work
- Check iTerm2 Preferences → Keys → Key Bindings for conflicts
- Try a different shortcut (Shift+Cmd+B, Ctrl+Cmd+R)
- Make sure you typed `claude "/ralph-continuous"\n` exactly (include `\n`)

### No iTerm2 tabs open
- Check System Settings → Privacy & Security → Automation
- Make sure iTerm2 can control System Events

### Tests fail
- Run the test command manually to see the error
- For Python: make sure virtual environment is activated (`source venv/bin/activate`)
- For Node.js: make sure dependencies are installed (`npm install`)

### Git push rejected
- Make sure git remote uses HTTPS: `git remote -v`
- If it shows `git@gitlab...`, fix it:
  ```bash
  git remote set-url origin https://gitlab.zgtools.net/your-team/your-repo.git
  ```

### Need more help
See `EXAMPLES.md` for detailed troubleshooting and setup guides.

---

## Tips

**Write clear specs:**
- Describe what should happen when things go wrong
- Include validation commands
- Specify which files to change

**Keep tasks small:**
- 15-30 minutes per task
- One feature or fix per task
- Clear success criteria

**Update RALPH.md as you learn:**
- Add "Learned Lessons" when Ralph makes mistakes
- Document project quirks
- Keep build instructions current

---

## Advanced: iTerm2 Hotkey (Optional)

**macOS users:** For faster workflow, set up a hotkey to run Ralph with one keypress instead of typing commands.

### Set Up Hotkey

1. Open iTerm2 → Preferences (Cmd+,)
2. Navigate to: **Keys → Key Bindings**
3. Click the **"+"** button
4. Configure:
   - **Keyboard Shortcut:** Press `Shift+Cmd+R`
   - **Action:** Select "Send Text with vim Special Chars"
   - **Text:** `claude "/ralph-continuous"\n`

   ⚠️ Include the `\n` at the end - this sends the Enter key

5. Click **OK**

### First Time Setup: macOS Permissions

macOS will prompt you to allow iTerm2 to control System Events the first time you use the hotkey.

1. Click "Open System Settings" when prompted
2. Enable iTerm2 under: **Privacy & Security → Accessibility**
3. Try the hotkey again

### Usage

Once configured, press `Shift+Cmd+R` from your project directory to start a sprint.

**Alternative hotkeys you might set up:**
- `Shift+Cmd+P` → `claude "/ralph-plan"\n` (sprint planning)
- `Shift+Cmd+T` → `claude "/ralph"\n` (single task)

**Troubleshooting:**
- If hotkey doesn't work, check for conflicts in System Preferences → Keyboard → Shortcuts
- Try a different key combination (e.g., `Shift+Cmd+B`)

---

## More Information

- `EXAMPLES.md` - Detailed setup guides and troubleshooting
- `CHANGELOG.md` - Version history
- Questions? Ask Zach Partyka (zpartyka@zillow.com)

Internal Zillow use only.
