# Ralph Kit — Universal vs. Zillow Separation Audit

> **This file stays in GitLab.** It references Zillow infrastructure by name and is an internal record only. Do not push to GitHub.

**Date:** 2026-03-13
**Purpose:** Reference map for the GitHub cleanup and the eventual three-layer architecture (universal core → org layer → project layer). No files were changed to produce this document.

---

## Classification System

| Label | Meaning |
|---|---|
| **Universal** | No Zillow-specific content. Goes to GitHub as-is. |
| **Zillow** | Entirely or predominantly Zillow-specific. Stays in GitLab. Needs a generic replacement for GitHub. |
| **Mixed** | Mostly universal with specific Zillow references. Goes to GitHub after targeted edits — exact lines/sections called out below. |

---

## File-by-File Classification

### Root files

| File | Classification | Notes |
|---|---|---|
| `RALPH.md` | **Mixed** | Content is universal. Two issues for GitHub: (1) outdated reference to `stdlib/` directory (changed to `ralph-config.md` in current kit); (2) "Learned Lessons" section should be stripped — it's a per-project accumulation point, not kit content. |
| `README.md` | **Mixed** | Almost entirely universal. One Zillow reference: line 22 links to `gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit`. Replace with GitHub repo URL. Also needs a short note explaining the two-repo relationship (GitHub = universal core, org forks = org-specific layer). |
| `ONBOARDING.md` | **Zillow** | Entirely Zillow infrastructure: ZGAI (internal LLM), Zodiac/Keeper (secret management), Artifactory (Docker registry), `zgcp-consumer-nonprod-k8s` (K8s cluster), Marketing Copilot as the reference app. The *structure* is reusable (steps 1–8 for getting an app Ralph-ready) but every specific reference needs to be rewritten. GitHub version needs a clean generic rewrite covering the same 8-step flow using generic CI/CD, Docker Hub/ECR, any secret manager, and a placeholder reference app. |
| `CHANGELOG.md` | **Universal** | No Zillow content. Ready as-is. |
| `.gitignore` | **Universal** | Standard gitignore patterns. No Zillow content. |

---

### scripts/

| File | Classification | Notes |
|---|---|---|
| `setup-project.sh` | **Mixed** | Core logic is universal. One framing issue: the SSH→HTTPS git conversion note is written for GitLab (valid for GitHub too, but framing is GitLab-centric). Update comment to be generic: "ensure your remote uses HTTPS, not SSH." The Homebrew/gum install and `~/Documents/ralph` install path default are fully universal. |
| `ralph-continuous.sh` | **Mixed** | Orchestration logic is fully universal. The `check_for_updates()` function fetches from `origin/main` of whatever kit repo is local — universally correct, no Zillow assumptions baked in. The `RALPH_WT_PROFILE="Git Bash"` default is Windows-specific but not Zillow-specific (fine for GitHub). Minor: verify any inline comments don't reference GitLab specifically. |
| `ralph-task-wrapper.sh` | **Universal** | No Zillow content. |
| `ralph.sh` | **Universal** | No Zillow content. |
| `install.sh` | **Universal** | Installs skills/agents as symlinks to Claude Code. No Zillow content. |

---

### skills/

| File | Classification | Notes |
|---|---|---|
| `skills/ralph/SKILL.md` | **Universal** | No Zillow content. The Co-Authored-By line uses `<noreply@anthropic.com>` which is correct for any Claude user. |
| `skills/ralph-continuous/SKILL.md` | **Universal** | No Zillow content. |
| `skills/ralph-plan/SKILL.md` | **Universal** | No Zillow content. |
| `skills/ralph-archive/SKILL.md` | **Universal** | No Zillow content. |

---

### agents/

| File | Classification | Notes |
|---|---|---|
| `agents/build-validator.md` | **Universal** | No Zillow content. |
| `agents/code-explorer.md` | **Universal** | No Zillow content. |
| `agents/deep-investigator.md` | **Universal** | No Zillow content. |
| `agents/playwright-runner.md` | **Universal** | No Zillow content. |

---

### template/

| File | Classification | Notes |
|---|---|---|
| `template/ralph-config.md.template` | **Mixed** | The fenced config block uses `[your HTTPS git remote]` placeholders (clean). The Stack Standards section is universal. Previously had Zillow GitLab and Kubernetes URLs as defaults — already cleaned up. Verify no remaining `zgtools.net` references before pushing to GitHub. |
| `template/ralph.config.sh.template` | **Universal** | No Zillow content. |
| `template/roadmap.md.template` | **Universal** | No Zillow content. |
| `template/sprint_plan.md.template` | **Universal** | No Zillow content. |
| `template/sprints/sprint_history.md` | **Universal** | No Zillow content. |
| `template/sprints/sprint_summary.template.md` | **Universal** | No Zillow content. |
| `template/stdlib/ralph-config.md` | **Universal** | No Zillow content. |
| `template/stdlib/api-routes.md` | **Universal** | No Zillow content. |
| `template/stdlib/documentation.md` | **Universal** | No Zillow content. |
| `template/stdlib/security.md` | **Universal** | No Zillow content. |
| `template/stdlib/testing-playwright.md` | **Universal** | No Zillow content. |
| `template/stdlib/validation.md` | **Universal** | No Zillow content. |

---

### docs/

| File | Classification | Notes |
|---|---|---|
| `docs/RALPH_CONFIG.md` | **Universal** | No Zillow content. |
| `docs/README-MAC.md` | **Zillow** | Deeply Zillow throughout. Specific references: ServiceNow link for Claude Code access (line 32), download/clone URLs from `gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit` (lines 47–52), project clone URLs from `gitlab.zgtools.net/your-team/your-project` (line 61), issue tracker pointing to `gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit` (lines 225 and 241), and "Internal Zillow use only." footer (line 243). GitHub version needs a full rewrite — the structure (prerequisites → setup → first sprint → key files → troubleshooting) is reusable, but every specific URL and org reference must be replaced with generic equivalents. |
| `docs/README-WINDOWS.md` | **Zillow** | Same pattern as README-MAC.md. Specific references: ServiceNow link for Claude Code access (line 54), download/clone URLs from `gitlab.zgtools.net/tpm_cdp_team/ralph-starter-kit` (lines 70–74), project clone URLs from `gitlab.zgtools.net/your-team/your-project` (line 84), issue tracker links pointing to GitLab (lines 272–273), and "Internal Zillow use only." footer (line 291). Needs the same full rewrite for GitHub. |
| `docs/EXAMPLES.md` | **Mixed** | Mostly universal workflow patterns and troubleshooting. Three Zillow-specific references requiring edits before GitHub: (1) "Zillow standard" in the Python/FastAPI section header (line 116) — change to "generic"; (2) "Based on Zillow Marketing Copilot (6 sprints, $7.50 total cost)" in the Node.js section header (line 249) — remove or genericize; (3) `gitlab.zgtools.net` HTTPS remote URL example in the Git troubleshooting section (lines 574–580) — replace with a generic HTTPS placeholder. |
| `docs/SEPARATION-AUDIT.md` | **Zillow** | This file. References Zillow infrastructure and internal tooling by name. Stays in GitLab as an internal record. |

---

## Summary: The Separation Line

### Goes to GitHub (universal core) — no changes needed

- All 4 skills (`skills/ralph/`, `skills/ralph-continuous/`, `skills/ralph-plan/`, `skills/ralph-archive/`)
- All 4 agents (`build-validator.md`, `code-explorer.md`, `deep-investigator.md`, `playwright-runner.md`)
- All template/ files (after a final spot-check of `ralph-config.md.template` for any remaining `zgtools.net` references)
- `scripts/ralph-task-wrapper.sh`, `scripts/ralph.sh`, `scripts/install.sh`
- `docs/RALPH_CONFIG.md`
- `CHANGELOG.md`, `.gitignore`

### Goes to GitHub after targeted edits (Mixed files)

| File | Edit Required |
|---|---|
| `README.md` | Line 22: swap GitLab URL for GitHub repo URL. Add 1-paragraph note on two-repo relationship. |
| `RALPH.md` | Strip "Learned Lessons" section. Fix outdated `stdlib/` reference to match current `ralph-config.md` pattern. |
| `scripts/setup-project.sh` | Update SSH→HTTPS comment to be registry-neutral (not GitLab-framed). |
| `scripts/ralph-continuous.sh` | Verify no GitLab-specific inline comments; none found in review — likely fine as-is. |
| `template/ralph-config.md.template` | Final verification: confirm no remaining `zgtools.net` URLs; likely clean from prior session edits. |
| `docs/EXAMPLES.md` | Three targeted edits: remove "Zillow standard" (line 116), genericize "Zillow Marketing Copilot" reference (line 249), replace `gitlab.zgtools.net` example URLs in Git troubleshooting (lines 574–580). |

### Stays in GitLab (Zillow layer) — full rewrite needed for GitHub

| File | What GitHub Needs Instead |
|---|---|
| `ONBOARDING.md` | Generic version: same 8-step flow using generic CI/CD, Docker Hub/ECR, any secret manager, placeholder reference app instead of Marketing Copilot |
| `docs/README-MAC.md` | Generic Mac setup guide: replace ServiceNow with "get Claude Code from claude.ai", replace all `gitlab.zgtools.net` URLs with `github.com/your-org/your-repo` placeholders, remove "Internal Zillow use only." |
| `docs/README-WINDOWS.md` | Same treatment as README-MAC.md |

---

## Entanglement Score

Of 34 files audited (excluding `.git` internals and `.DS_Store`):

| Label | Count | Files |
|---|---|---|
| **Universal** | 24 | CHANGELOG.md, .gitignore, 3 scripts (ralph.sh, ralph-task-wrapper.sh, install.sh), 4 skills, 4 agents, 12 template/ files (all stdlib + all base templates), docs/RALPH_CONFIG.md |
| **Mixed** | 6 | README.md, RALPH.md, scripts/setup-project.sh, scripts/ralph-continuous.sh, template/ralph-config.md.template, docs/EXAMPLES.md |
| **Zillow** | 4 | ONBOARDING.md, docs/README-MAC.md, docs/README-WINDOWS.md, docs/SEPARATION-AUDIT.md (this file) |

**The kit is ~71% universal already (24/34 files).** The Zillow surface area is more concentrated than it looks: 3 Zillow files (ONBOARDING.md + both README platform guides) each need a full generic rewrite, and 6 Mixed files need a total of ~10 targeted line edits across all of them.

---

## What GitHub Version Needs That Doesn't Exist Yet

1. **Generic `ONBOARDING.md`** — Same 8-step structure, rewritten for any CI/CD platform (GitHub Actions, GitLab CI, or generic), any Docker registry, any secret manager, with a placeholder app instead of Marketing Copilot.

2. **Generic `docs/README-MAC.md`** — Keep the structure (how it works → prerequisites → setup → running sprints → key files → troubleshooting). Strip all Zillow-specific access paths. Reference GitHub release/clone instead of GitLab.

3. **Generic `docs/README-WINDOWS.md`** — Same treatment as README-MAC.md.

4. **Two-repo relationship note in README.md** — A short section (3–5 lines) explaining: "This is the universal core. Fork it as your org's layer. Your org layer adds org-specific ONBOARDING, tooling defaults, and stack patterns on top of this core."

---

## Next Conversation

This audit is the input for the GitHub cleanup sprint. The work in that conversation:

1. Make the 6 Mixed-file edits (targeted, surgical — no rewrites)
2. Write 3 new generic files for GitHub (ONBOARDING.md, README-MAC.md, README-WINDOWS.md)
3. Add the two-repo note to README.md
4. Push the cleaned version to the GitHub remote
5. Document the fork/contribution model for Zillow technologists who want to contribute back to the universal core
