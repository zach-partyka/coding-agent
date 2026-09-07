# Ralph Changelog

Changes here are written in plain English for anyone using Ralph —
no technical background required.

---

## 2026-09-06 (later)

- **Scrollable menus.** The project picker and model picker in `/ralph-continuous`
  are now arrow-key menus (`gum choose`) instead of "type a number". Task banners are
  styled boxes. When `gum` isn't installed you get the old numbered prompts; set
  `RALPH_UI=plain` to force them.
- **One place to edit the model list.** The models Ralph offers (and their
  `sprint_plan.md` labels) are defined once in `scripts/ralph-portable.sh`
  (`ralph_models`) instead of three separate copies that had drifted out of date. The
  menu now uses version-free aliases (`sonnet`, `opus`, `opusplan`, `haiku`) that
  always resolve to the current model.
- **Quieter start.** The startup log lines between the banner and the first menu now
  go to `ralph-continuous.log` only.

## 2026-09-06

- **Ralph runs on Windows now, not just macOS.** Same commands, same tab-per-task
  experience — using **Git Bash + Windows Terminal**. `setup-project.sh` no longer
  tries to install Homebrew on Windows, `/ralph-continuous` no longer aborts before
  it starts, and cost/metrics no longer depend on tools Git for Windows doesn't ship
  (`jq`, `python3`). One shared codebase — nothing about the macOS experience changes.
- **A failed task tab is caught fast.** If Windows Terminal can't open a task tab
  (wrong `RALPH_WT_PROFILE` name, Git Bash not found), Ralph now notices within ~15
  seconds and runs that task inline instead of hanging for the full task timeout.
- **One-key launch on Windows.** Bind `Ctrl+Shift+R` in Windows Terminal — see the
  "Windows Terminal Hotkey Setup" section in `docs/EXAMPLES.md`. `setup-project.sh`
  writes the `RALPH_WT_PROFILE` line into `ralph-config.md` for you.
- **`gum` is now optional everywhere.** It only styles the update notice. Setup
  installs it via `winget` on Windows / Homebrew on macOS when available, and just
  carries on (plain-text notice) when it can't.

## 2026-03-13

- **RALPH.md is now shared across all projects.** Instead of copying a separate RALPH.md into each project, setup now creates a link. Changes to RALPH.md in the kit (via `git pull`) instantly apply to every project on your machine. Learnings written back during sprints are already in the kit, ready to share.
- **Stack standards moved into ralph-config.md.** The 5 stdlib files Ralph used to read on every task (API patterns, secrets, testing, validation, docs) are now condensed into a `## Stack Standards` section in `ralph-config.md`. One file for a new sprint, not six. The detailed originals stay in the kit as reference.
- **Update notifications when you start a sprint.** If the kit has updates you haven't pulled, Ralph will show a styled notification when you run `/ralph-continuous`. You can preview the changelog and update in-place before sprinting. Requires `gum` (installed automatically via Homebrew during setup, or install manually).
