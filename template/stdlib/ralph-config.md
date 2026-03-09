# ralph-config.md

One file at project root. Ralph creates and maintains it.

**Create** when missing (infer from project). **Update** in the same task when you change deploy URL, validate commands, or git remote. Commit with the change.

**Infer from project root:**

| Variable | Source |
|----------|--------|
| RALPH_GIT_REMOTE | `git remote get-url origin` |
| RALPH_GIT_MAIN_BRANCH | `main` or default branch |
| RALPH_DEPLOY_URL | README / DEPLOYMENT_GUIDE; or dev.playwright.config baseURL |
| RALPH_VALIDATE_LOCAL | package.json `check` script |
| RALPH_VALIDATE_DEPLOY | package.json `test` script |
| RALPH_HEALTH_CHECK_PATH | `/health` or app docs |

Format: fenced block `ralph-config` with one `KEY="value"` per line. No secrets. Full spec: kit docs/RALPH_CONFIG.md.
