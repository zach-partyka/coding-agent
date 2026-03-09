# Getting Your App Ready for Ralph

Ralph needs a running app with a test environment and CI/CD. This guide walks through the steps; **Marketing Copilot** is the reference example — use it for patterns and file examples, and adjust for your app and team.

If your app is already deployed with a test URL and a GitLab pipeline, skip to [Using Ralph →](README.md).

---

## Progress tracker

- [ ] **Step 1** — App built and running locally
- [ ] **Step 2** — Data / backend (Databricks, Postgres/Neon, etc.)
- [ ] **Step 3** — Containerized + CI/CD (you + Delivery/CI)
- [ ] **Step 4** — Deployed to Kubernetes
- [ ] **Step 5** — ZGAI connected *(skip if no AI)*
- [ ] **Step 6** — Secrets in Zodiac + Keeper
- [ ] **Step 7** — Accounts working, URL shared
- [ ] **Step 8** — Playwright tests in CI

---

## Step 1 — Build the app and set up the repo

**Who:** You

Get your app running locally and put it in a GitLab repo under your team's group (e.g. `gitlab.zgtools.net/your-team/your-app`). **Reference:** Marketing Copilot is at `tpm_cdp_team/marketing_copilot`.

- Clone, install, run:
  ```bash
  git clone https://gitlab.zgtools.net/your-team/your-app.git
  cd your-app
  cp .env.example .env   # fill in local values
  npm install
  npm run dev
  ```
- Document every variable in `.env.example` — name, purpose, where to get the value.

**Done when:** A teammate can clone, fill `.env`, and see the app at `localhost:3000` within ~15 minutes.

---

## Step 2 — Data and backend

**Who:** You

Set up whatever your app uses for data:

- **Databricks:** Create the tables you need; add any scheduled jobs (tag `Service: your-app`, `Team: your-team`). Put connection details in `.env.example`.
- **Postgres / Neon:** Provision a database (e.g. Neon Serverless), create schema, add the connection string to Zodiac secrets and `.env.example` (e.g. `SESSION_DATABASE_URL`, `DATABASE_URL`).

**Reference:** Marketing Copilot uses Neon Postgres for session store and (optionally) Databricks for other data; see its schema and env pattern if helpful.

**Done when:** The app reads/writes data and any scheduled jobs run. Skip if your app has no DB or external data yet.

---

## Step 3 — Containerize and set up CI/CD

**Who:** You + Delivery/CI

Get GitLab building and deploying on push to `main`.

1. **Request from Delivery/CI:** Artifactory Docker repos for your team, GitLab CI variables (`ARTIFACTORY_*`), and deploy permissions to the target cluster.
2. **Add a `Dockerfile`** — Node, Python, or Go; expose the app port and set the start command.
3. **Add `.gitlab-ci.yml`** — Use the standard Zillow CI template; add build + deploy stages. Delivery/CI can provide an example for your cluster.

**Reference:** Marketing Copilot’s [.gitlab-ci.yml](https://gitlab.zgtools.net/tpm_cdp_team/marketing_copilot/-/blob/main/.gitlab-ci.yml) is a minimal build-and-deploy example.

**Done when:** Push to `main` → pipeline builds image, pushes to Artifactory, and triggers deploy. Green pipeline in GitLab.

---

## Step 4 — Deploy to Kubernetes (consumer nonprod)

**Who:** You + Delivery/CI

Wire the pipeline to deploy into the **consumer nonprod** cluster. Your app gets a URL like:

```
https://your-app-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net
```

Add a **`/health`** endpoint — Ralph uses it to confirm deploys:

```typescript
app.get('/health', (req, res) => res.json({ status: 'healthy' }));
```

**Reference:** Marketing Copilot dev URL: `https://marketing-copilot-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net`. Its server exposes `/health`.

**Done when:** Push to `main`, wait ~5 min, open the app URL in a browser and see it running.

---

## Step 5 — Connect to ZGAI *(skip if no AI)*

**Who:** You + platform team

If your app uses the Zillow LLM API (ZGAI):

1. **Request:** Get your service added to the ZGAI `SERVICE_ALLOWLIST` (ask platform or check ZGAI onboarding).
2. **Zodiac:** Kong – API Key request; target `zgai-llm-api`, sub-environment `stage`. Terraform provisions the key.

**Reference:** Marketing Copilot uses ZGAI for chat and brief coaching; it reads the key from env (e.g. `ZGAI_API_KEY`).

**Done when:** ZGAI calls from your app return 200, not 401/403.

---

## Step 6 — Secrets in Zodiac + Keeper

**Who:** You  
Don’t hardcode keys. Store them in Keeper and expose them to the app via Zodiac.

1. Put the key in **Keeper** (e.g. team folder → your-app → `ZGAI_API_KEY`).
2. In **Zodiac** → your service → Secrets: add a nonprod secret with the variable name your app expects. The app reads it from `process.env.VAR_NAME`.
3. In **`.env.example`** list the variable name and where to get the value (e.g. “from Keeper: team/your-app”).

**Reference:** Marketing Copilot stores ZGAI_API_KEY, SESSION_DATABASE_URL, SESSION_SECRET, etc. in Zodiac; see its `.env.example` for the list.

**Done when:** Deployed app gets secrets from the environment; nothing sensitive is in git.

---

## Step 7 — Accounts and access

**Who:** You

1. Verify the main flow: sign up, sign in, create/save something.
2. Confirm data is stored correctly.
3. Share the app URL and how to sign in (e.g. “Sign in with your Zillow credentials”).

**Done when:** Teammates can open the URL, create an account, and use the app without your help.

---

## Step 8 — Playwright tests in CI

**Who:** You

Ralph uses these to verify changes didn’t break the app.

- **Install:** `npm install --save-dev @playwright/test` and `npx playwright install chromium`.
- **Config:** Set `baseURL` from env (e.g. `process.env.STAGING_URL || 'http://localhost:3000'`) so the same tests run locally and against deploy.
- **Tests:** Smoke tests for auth and core flows; use `data-testid` or roles for stable selectors.
- **CI:** Add a test stage that runs after deploy with `STAGING_URL=$DEV_URL npm test`.

**Reference:** Marketing Copilot’s `playwright.config.ts` and `tests/` show baseURL, auth setup, and test patterns. See [marketing_copilot repo](https://gitlab.zgtools.net/tpm_cdp_team/marketing_copilot) for examples.

**Done when:** Push to `main` → build → deploy → tests run against the live URL; pipeline is green.

---

## Ready for Ralph

You should have:

- App at a shared URL
- GitLab pipeline that deploys on push to `main`
- `/health` returning 200
- Playwright tests running against the live URL
- Secrets in Zodiac, not in code

Next: [Set up Ralph →](README.md)
