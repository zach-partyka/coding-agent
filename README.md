# Ralph

Ralph is an AI agent that builds software for you. You describe what you want, Ralph implements it, deploys it, and lets you review the live result.

**The old way:** Write a spec, hand it to engineering, wait for a sprint, get it back, give feedback, wait again.

**With Ralph:** Describe what you want → Ralph builds and deploys it → you review the live result. One sitting.

Ralph has run 36+ sprints on a real production app (Marketing Copilot), averaging ~$0.35 per sprint in AI costs.

---

## How it works

Ralph operates in a simple cycle:

1. **Plan** — You tell Ralph what to build (a roadmap item, a bug fix, a new feature). Ralph turns it into a sprint plan with small, concrete tasks.
2. **Build** — Ralph works through each task: writes the code, runs tests, pushes it live to your staging environment, and verifies it works.
3. **Review** — You open your staging site in a browser and check the result. If something needs adjusting, you tell Ralph and it fixes it.

You interact with Ralph through a terminal (the black window where you type commands). Ralph handles the rest — git, deployments, testing — so you don't need to know those systems.

---

## What you need before starting

### 1. A Mac (or Windows PC)

Ralph works on both. Mac is simpler to set up.

### 2. Claude Code

This is the AI tool that powers Ralph. It runs in your terminal.

**To check if you have it:** Open Terminal (on Mac: search "Terminal" in Spotlight), type `claude --version`, and press Enter. If you see a version number, you're set.

**To get it at Zillow:** Submit a [ServiceNow request](https://zillow.service-now.com/esc?id=sc_cat_item&sys_id=5ef70cfb93bfea149922f60b6aba10a9). Once approved, follow the install instructions they send you.

### 3. A project to use it on

Ralph works on existing codebases that have:
- Source code in a git repository (ask your team's engineer — they'll know)
- A staging environment where code auto-deploys when pushed (most Zillow apps have this)

If you're not sure whether your project qualifies, ask Zach (zpartyka@zillow.com) — happy to help figure it out.

### 4. The Ralph starter kit (this folder)

If you're reading this, you probably already have it. If not:

**On Mac**, open Terminal and run:
```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit.git ~/Documents/ralph-starter-kit
```

**If `git clone` doesn't work**, you may need to set up GitLab access first. Ask your team lead or check the [Zillow GitLab docs](https://gitlab.zgtools.net).

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

**What setup creates:**

| File | What it's for |
|------|---------------|
| `roadmap.md` | Your product backlog — what you want to build, organized by priority |
| `sprint_plan.md` | The current sprint — tasks Ralph is working on right now |
| `RALPH.md` | Build instructions — how to run and test your specific project |
| `ralph.config.sh` | Configuration — your staging URL, git settings, test commands |
| `specs/` | Detailed requirements for features (you write these, Ralph follows them) |
| `stdlib/` | Code patterns your project follows (Ralph stays consistent with these) |
| `sprints/` | Archive of completed sprints with performance data |

---

## Running your first sprint

### Plan it

```bash
claude "/ralph-plan"
```

Ralph reads your `roadmap.md` and walks you through building a sprint plan. It asks what you want to focus on, suggests task breakdowns, and writes `sprint_plan.md` when you're happy with it.

**Tip:** Start small. 3–5 tasks for your first sprint. You can always run another.

### Run it

```bash
claude "/ralph-continuous"
```

Ralph opens a new terminal tab for each task and works through them one at a time. You'll see it:

- Reading your code to understand what to change
- Writing new code or modifying existing files
- Running tests to make sure nothing broke
- Pushing the changes live to your staging site
- Verifying the deployment worked

Each task typically takes 5–20 minutes. A 5-task sprint usually finishes in about an hour.

**While it's running,** you can switch between terminal tabs to watch any task. You don't need to do anything — just watch if you're curious, or go do other work and come back.

**To stop it,** press `Ctrl+C` in any task tab. Ralph stops cleanly.

### Review it

When the sprint finishes, open your staging site in a browser and check the changes.

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

1. **Update your roadmap** — Add ideas, features, and fixes to `roadmap.md` in the Now / Next / Later sections.
2. **Plan a sprint** — Run `claude "/ralph-plan"` when you're ready to build something. Ralph pulls from the "Now" section.
3. **Run the sprint** — `claude "/ralph-continuous"` and let it go.
4. **Review results** — Check staging, give feedback, note anything that needs adjustment.
5. **Archive** — When a sprint is done, Ralph archives it (performance data, learnings) and carries follow-ups into your roadmap.

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

**The staging site doesn't look right:**
Tell Ralph what's wrong — describe what you expected vs. what you see. It can fix visual issues in a follow-up task.

**You want to undo everything Ralph did:**
Your code is in git, so nothing is permanent. Ask the engineer on your team to help revert if needed, or run `git revert` yourself if you're comfortable with it.

**"`claude` command not found":**
Claude Code isn't installed. See [What you need](#2-claude-code) above.

**"`/ralph` not found":**
The Ralph skills aren't installed. Run the setup script again:
```bash
~/Documents/ralph-starter-kit/scripts/setup.sh
```

**Need help:**
Reach out to Zach Partyka (zpartyka@zillow.com). No question is too basic.

---

## Tips from 36 sprints

- **Start small.** Your first sprint should be 3–5 small tasks. Build confidence before going bigger.
- **Be specific in specs.** "Make the page faster" is hard for Ralph. "Reduce the brief-loading spinner from 5 seconds to under 2 seconds" is actionable.
- **Always check staging visually.** 36% of UI tasks in early sprints passed tests but had visual issues. A quick look in the browser catches this.
- **One thing per task.** "Add a button AND change the header AND update the footer" should be three tasks, not one.
- **Investigation tasks are valuable.** For bugs or performance issues, start with a task that just investigates and reports findings. Then plan fixes based on what Ralph discovers.

---

## Going deeper

Once you're comfortable with the basics:

| Doc | What it covers |
|-----|---------------|
| `EXAMPLES.md` | Detailed walkthroughs, workflow patterns, and troubleshooting |
| `examples/nodejs-typescript/` | Example setup for a Node.js/TypeScript project |
| `examples/python-fastapi/` | Example setup for a Python/FastAPI project |

---

Questions? Reach out to Zach Partyka (zpartyka@zillow.com).

Internal Zillow use only.
