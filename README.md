# Ralph Starter Kit

AI-powered sprint execution for your development projects. Define what to build, Ralph implements it autonomously, you review the results.

**Proven Results:** 6 sprints completed at $7.50 total cost vs. $1,750 engineer baseline.

---

## Quick Start

### 1. Clone the Starter Kit

```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git
```

### 2. Install ralph-continuous.sh (One-Time, All Projects)

This enables the keyboard shortcut workflow.

```bash
cp ~/ralph-starter-kit/scripts/ralph-continuous.sh ~/Documents/AI/ralph-continuous.sh
chmod +x ~/Documents/AI/ralph-continuous.sh
```

### 3. Set Up Your Project

**Important:** Run this in an existing project with code (not an empty directory).

```bash
# Navigate to your project
cd /path/to/your/project

# Your project should have:
# ✓ Code (Python, Node.js, etc.)
# ✓ Git repository (run 'git init' if needed)
# ✓ Staging environment that auto-deploys

# Run setup
~/ralph-starter-kit/scripts/setup.sh
```

Answer the prompts:
- Git remote URL
- Staging environment URL
- Test commands
- iTerm2 hotkey setup

### 4. Set Up iTerm2 Hotkey (Recommended)

Open iTerm2 → Preferences (Cmd+,) → Keys → Key Bindings → Click "+"

Configure:
- **Keyboard Shortcut:** Press `Shift+Cmd+R`
- **Action:** "Send Text with vim Special Chars"
- **Text:** `claude "/ralph-continuous"\n`

Click OK.

### 5. Run Your First Sprint

```bash
cd /path/to/your/project

# Plan your sprint
claude "/ralph-plan"

# Execute it (opens new tab for each task)
Press Shift+Cmd+R
```

Done! Ralph will implement, test, commit, and deploy each task automatically.

---

## How to Use Ralph

### Planning a Sprint
```bash
claude "/ralph-plan"
```
Answers questions about what you want to build, creates sprint_plan.md with tasks.

### Running a Sprint

**Option 1: Keyboard Shortcut (Recommended)**
```
Press Shift+Cmd+R
```
Runs all tasks automatically. Each task opens in a new iTerm2 tab so you can watch progress.

**Option 2: Command Line**
```bash
claude "/ralph-continuous"
```
Same as keyboard shortcut.

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

## More Information

- `EXAMPLES.md` - Detailed setup guides and troubleshooting
- `CHANGELOG.md` - Version history
- Questions? Ask Zach Partyka (zpartyka@zillow.com)

Internal Zillow use only.
