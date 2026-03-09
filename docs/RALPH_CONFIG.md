# Ralph config

One file: **ralph-config.md** at project root. No ralph.config.sh. Scripts load the `ralph-config` fenced block (shell KEY=value lines); subagents read this file for deploy URL and validation commands.

## Format

````markdown
```ralph-config
RALPH_GIT_REMOTE="https://gitlab.zgtools.net/team/project.git"
RALPH_GIT_MAIN_BRANCH="main"
RALPH_DEPLOY_URL="https://app-dev.example.com"
RALPH_DEPLOY_WAIT_SECONDS=300
RALPH_VALIDATE_LOCAL="npm run check"
RALPH_VALIDATE_DEPLOY="npm test"
RALPH_HEALTH_CHECK_PATH="/health"
```
````

Required: `RALPH_GIT_REMOTE`, `RALPH_DEPLOY_URL`. Rest optional (scripts default).

Quoted values if spaces/special chars. No secrets.

---

## Ralph keeps it current

**Create** when missing. **Update** in the same task when you change deploy URL, validate commands, or git remote. Commit with the change.

### Infer from project (run from project root)

| Variable | Source |
|----------|--------|
| RALPH_GIT_REMOTE | `git remote get-url origin` |
| RALPH_GIT_MAIN_BRANCH | Default branch, usually `main` |
| RALPH_DEPLOY_URL | README / DEPLOYMENT_GUIDE; or dev.playwright.config baseURL; or _infra/ws. Use URL for “E2E against deploy.” |
| RALPH_DEPLOY_WAIT_SECONDS | 300 |
| RALPH_VALIDATE_LOCAL | package.json `scripts.check` or RALPH.md |
| RALPH_VALIDATE_DEPLOY | package.json `scripts.test` or RALPH.md |
| RALPH_HEALTH_CHECK_PATH | App docs or `/health` |

Prefer deploy docs over guessing. No app config or secrets in this file.

---

## Scripts

- **ralph.sh**: Load only ralph-config.md. Missing → error, point here.
- **ralph-continuous.sh**: Load only ralph-config.md. Missing → no export, continue.
