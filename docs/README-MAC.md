# Ralph — Mac Setup Guide

Ralph is an AI agent that builds software for you. You describe what you want, Ralph implements it, deploys it, and lets you review the live result.

**The old way:** Write a spec, hand it to engineering, wait for a sprint, get it back, give feedback, wait again.

**With Ralph:** Describe what you want → Ralph builds and deploys it → you review the live result. One sitting.

---

## How it works

Ralph operates in a simple cycle:

1. **Plan** — You tell Ralph what to build (a roadmap item, a bug fix, a new feature). Ralph turns it into a sprint plan with small, concrete tasks.
2. **Build** — Ralph works through each task: writes the code, runs tests, pushes it live to your dev environment, and verifies it works.
3. **Review** — You open your dev site in a browser and check the result. If something needs adjusting, you tell Ralph and it fixes it.

You interact with Ralph through Terminal (the black window where you type commands). Ralph handles the rest — git, deployments, testing — so you don't need to know those systems.

---

## What you need before starting

### 1. Claude Code

This is the AI tool that powers Ralph. It runs in your terminal.

**To check if you have it:** Open Terminal (search "Terminal" in Spotlight), type `claude --version`, and press Enter. If you see a version number, you're set.

**To get it at Zillow:**
1. Submit a [ServiceNow request](https://zillow.service-now.com/esc?id=sc_cat_item&sys_id=5ef70cfb93bfea149922f60b6aba10a9) to get access — should get access same day
2. Once approved, open Terminal and run:
   ```bash
   curl -fsSL https://claude.ai/install.sh | bash
   ```
3. When prompted to log in, use your Zillow email and password

### 2. A project to use it on

Ralph works on existing codebases that have:
- Source code in a git repository (ask your team if you're unsure)
- A dev environment where code auto-deploys when pushed — if your app isn't deployed yet, follow [ONBOARDING.md](../ONBOARDING.md) first

### 3. The Ralph starter kit

**Option A — Download:** Go to [gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit](https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit), click the download icon, and extract the zip to `~/Documents/ralph-starter-kit`.

**Option B — Clone:**
```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git ~/Documents/ralph-starter-kit
```

---

## Setting up Ralph on your project

Once you have everything above, the setup takes about 5 minutes.

**Step 1:** Open Terminal and navigate to your project folder:
```bash
cd ~/path/to/your/project
```
(Replace with the actual path. If you're not sure, ask the engineer on your team where the code lives.)

**Step 2:** Run the setup script:
```bash
~/Documents/ralph-starter-kit/scripts/setup.sh
```
(Adjust the path if you put the starter kit somewhere else.)

The script will ask you a few questions about your project — staging URL, what language the code is in, etc. It auto-detects most things. When in doubt, press Enter to accept the defaults.

**What's in the starter kit scripts:**

| Script | What it does |
|--------|--------------|
| `setup.sh` | One-time setup — asks questions, creates config files, installs skills |
| `ralph.sh` | Project launcher — copied to your project root by setup.sh |
| `ralph-continuous.sh` | Runs all tasks in the sprint, opening a new terminal tab per task |
| `ralph-task-wrapper.sh` | Runs inside each tab — handles the UI, cost tracking, and post-processing |
| `install-ralph-skills.sh` | Reinstalls Ralph skills into `~/.claude/skills/` if needed |

**What setup creates:**

| File | What it's for |
|------|---------------|
| `roadmap.md` | Your product backlog — what you want to build, organized by priority |
| `sprint_plan.md` | The current sprint — tasks Ralph is working on right now |
| `RALPH.md` | Build instructions — how to run and test your specific project |
| `ralph.config.sh` | Configuration — your dev URL, git settings, test commands |
| `specs/` | Detailed requirements for features (you write these, Ralph follows them) |
| `stdlib/` | Code patterns your project follows (Ralph stays consistent with these) |
| `sprints/` | Archive of completed sprints with performance data |

---

## Running your first sprint

### Plan it

```bash
claude "/ralph-plan"
```

Ralph auto-detects your project, reads the current state (existing sprint, roadmap, past sprints), and summarizes where things stand. Then it starts a planning conversation — asking what you want to build next, breaking it into concrete tasks, and writing `sprint_plan.md` when you're happy with the plan.

**Tip:** Start small. 3–5 tasks for your first sprint. You can always run another.

### Run it

```bash
claude "/ralph-continuous"
```

Ralph opens a new terminal tab for each task and works through them one at a time. You'll see it:

- Reading your code to understand what to change
- Writing new code or modifying existing files
- Running tests to make sure nothing broke
- Pushing the changes live to your dev site
- Verifying the deployment worked

Each task typically takes 5–20 minutes. A 5-task sprint typically takes 1–2 hours.

**While it's running,** you can switch between terminal tabs to watch any task. You don't need to do anything — just watch if you're curious, or go do other work and come back.

**To stop it,** press `Ctrl+C` in any task tab. Ralph stops cleanly.

### Review it

When the sprint finishes, open your dev site in a browser and check the changes.

**Important:** Always visually verify UI changes. Ralph's tests can pass even when something looks wrong on screen. A quick eye-check catches things automated tests miss.

### One task at a time (alternative)

If you'd rather go task-by-task instead of running the whole sprint:

```bash
claude "/ralph"
```

Ralph implements one task, then stops and waits for you. Good for your first time, or when you want tighter control.

---

## Day-to-day workflow

Once you're set up, the rhythm is:

1. **Plan a sprint** — Run `claude "/ralph-plan"` and describe what you want to build. Ralph breaks it into tasks and writes `sprint_plan.md`.
2. **Run the sprint** — `claude "/ralph-continuous"` and let it go.
3. **Review results** — Check your dev site, give feedback, note anything that needs adjustment.
4. **Archive** — When a sprint is done, Ralph archives it (performance data, learnings) and carries follow-ups into your roadmap.

A sprint takes about an hour. You can run multiple sprints in a day if you want.

---

## Writing good specs

Ralph is only as good as what you tell it to build. The key files you'll edit:

### `roadmap.md` — What to build

Organized into three sections:
- **Now** — Things Ralph should build in the next sprint
- **Next** — Coming soon but not yet
- **Later** — Ideas and future work

Ralph reads the "Now" section during planning.

### `specs/` — Detailed requirements

For complex features, write a spec file. Plain English is fine. Include:
- What the feature does (from a user's perspective)
- What success looks like
- Edge cases or constraints ("don't change the header," "must work on mobile")

### `sprint_plan.md` — You usually don't edit this directly

Ralph generates this during planning and updates it during execution. But you can read it anytime to see progress.

---

## When something goes wrong

**Ralph gets stuck or stops mid-task:**
Run `claude "/ralph"` again. It picks up where it left off.

**The dev site doesn't look right:**
Tell Ralph what's wrong — describe what you expected vs. what you see. It can fix visual issues in a follow-up task.

**You want to undo everything Ralph did:**
Your code is in git, so nothing is permanent. Ask the engineer on your team to help revert if needed, or run `git revert` yourself if you're comfortable with it.

**"`claude` command not found":**
Claude Code isn't installed. See [What you need](#1-claude-code) above.

**"`/ralph` not found":**
The Ralph skills aren't installed. Run the setup script again:
```bash
~/Documents/ralph-starter-kit/scripts/setup.sh
```

**Git credential errors:**
If you see authentication errors when Ralph tries to push code, make sure your Mac Keychain has your GitLab credentials saved. Run `git push` manually once from your project folder — it will prompt for your username and password, and macOS will save them via `osxkeychain`.

**Need help:**
Reach out to Zach Partyka (zpartyka@zillow.com). No question is too basic.

---

## Tips from 37 sprints

- **Start small.** Your first sprint should be 3–5 tasks. Build confidence before going bigger.
- **Be specific in specs.** "Make the page faster" is hard for Ralph. "Reduce the brief-loading spinner from 5 seconds to under 2 seconds" is actionable.
- **Always check your dev site visually.** 36% of UI tasks in early sprints passed automated tests but had visual issues. A quick look in the browser catches what tests miss.
- **One thing per task.** "Add a button AND change the header AND update the footer" should be three tasks, not one.
- **Use investigation tasks for bugs and unfamiliar code.** For a bug or performance issue, start with a task that just investigates and reports findings — don't implement yet. Sprints that did this had zero rework. Skip investigation for follow-on work or when you already have a clear spec.
- **Default to Sonnet, use Opus only for hard problems.** When Ralph asks which model to use, Sonnet handles most implementation tasks well and costs 2–4x less than Opus. Reserve Opus for complex debugging with multiple root causes or tricky architectural decisions. Model choice is one of the biggest cost drivers.
- **Task duration is driven by complexity, not sprint size.** Simple implementation tasks run 5–10 minutes. Debugging tasks with multiple root causes run 20+ minutes regardless of how many other tasks are in the sprint. Plan accordingly.

---

Questions? Reach out to Zach Partyka (zpartyka@zillow.com).

Internal Zillow use only.
