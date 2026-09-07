# Ralph Changelog

Changes here are written in plain English for anyone using Ralph —
no technical background required.

---

## 2026-09-07

- **Fixed: Ralph could quit right after you picked a model.** On Mac and Windows,
  choosing Sonnet or Opus stopped the script before the sprint started. Choosing
  Haiku worked. Now all three work.
- **The main tab now shows a task board.** The tab you start Ralph in lists every
  task with its status — done, running, or waiting — plus the sprint name, the
  model, and how long the sprint has been going. It updates as tasks finish.
  Before, this tab was just a scrolling log. Mac and Windows.
- **Ralph offers to plan when there's nothing to run.** If `sprint_plan.md` is
  missing, or still the blank template, Ralph asks if you want to run
  `/ralph-plan` instead of starting an empty sprint. Mac and Windows.
- **Windows: `/ralph-plan` opens in its own tab.** Choosing to plan now opens a
  "Ralph: Plan" tab, the same way tasks do. Before, it took over the main tab.
- **Windows: fixed task tabs opening in a separate window.** On Windows Terminal
  1.24 and newer, new tabs opened detached from the main window and the task
  never started. Tabs now open in the same window and run as expected.

## 2026-09-06

- **Ralph runs on Windows.** Same commands and the same tab-per-task flow as on a
  Mac, using Git Bash + Windows Terminal. `docs/README-WINDOWS.md` walks you through
  setup.
- **One-key launch.** Bind a key in your terminal to start a sprint — `Shift+Cmd+R`
  on macOS (iTerm2), `Ctrl+Shift+R` on Windows (Windows Terminal). Setup shows you
  how.
- **Scrollable menus.** Pick your project and model with the arrow keys instead of
  typing a number. The model menu lists Sonnet / Opus / Haiku, which always point at
  the current version. (Numbered prompts still appear where `gum` isn't installed;
  `RALPH_UI=plain` forces them.)
- **Quicker recovery from a stuck tab.** If a task tab fails to open, Ralph notices
  in a few seconds and runs that task in the current window instead of waiting out
  the full timeout.
- **Cleaner start-up.** Less on-screen noise before the first prompt — the details
  still go to `ralph-continuous.log`.

## 2026-03-13

- **RALPH.md is now shared across all projects.** Instead of copying a separate RALPH.md into each project, setup now creates a link. Changes to RALPH.md in the kit (via `git pull`) instantly apply to every project on your machine. Learnings written back during sprints are already in the kit, ready to share.
- **Stack standards moved into ralph-config.md.** The 5 stdlib files Ralph used to read on every task (API patterns, secrets, testing, validation, docs) are now condensed into a `## Stack Standards` section in `ralph-config.md`. One file for a new sprint, not six. The detailed originals stay in the kit as reference.
- **Update check when you start a sprint.** If the kit is behind, Ralph tells you and offers to update in place before the sprint runs. Reading the changelog first is optional — the default is just to update.
