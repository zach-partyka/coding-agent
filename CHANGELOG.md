# Ralph Changelog

Changes here are written in plain English for anyone using Ralph —
no technical background required.

---

## 2026-03-13

- **RALPH.md is now shared across all projects.** Instead of copying a separate RALPH.md into each project, setup now creates a link. Changes to RALPH.md in the kit (via `git pull`) instantly apply to every project on your machine. Learnings written back during sprints are already in the kit, ready to share.
- **Stack standards moved into ralph-config.md.** The 5 stdlib files Ralph used to read on every task (API patterns, secrets, testing, validation, docs) are now condensed into a `## Stack Standards` section in `ralph-config.md`. One file for a new sprint, not six. The detailed originals stay in the kit as reference.
- **Update notifications when you start a sprint.** If the kit has updates you haven't pulled, Ralph will show a styled notification when you run `/ralph-continuous`. You can preview the changelog and update in-place before sprinting. Requires `gum` (installed automatically via Homebrew during setup, or install manually).
