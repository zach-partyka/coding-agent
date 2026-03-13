# Getting Your App Ready for Ralph

Ralph needs a running app with a test environment and CI/CD. This guide walks through the steps — adjust each one for your stack, team, and infrastructure.

If your app is already deployed with a test URL and an auto-deploying CI/CD pipeline, skip to [Using Ralph →](README.md).

---

## Progress tracker

- [ ] **Step 1** — App built and running locally
- [ ] **Step 2** — Data / backend (database, external services, etc.)
- [ ] **Step 3** — Containerized + CI/CD pipeline
- [ ] **Step 4** — Deployed to a hosting environment
- [ ] **Step 5** — External API connected *(skip if no external AI/API)*
- [ ] **Step 6** — Secrets managed securely
- [ ] **Step 7** — Accounts working, URL shared
- [ ] **Step 8** — Playwright tests in CI

---

## Step 1 — Build the app and set up the repo

**Who:** You

Get your app running locally and put it in a git repo (GitHub, GitLab, Bitbucket — anywhere that supports HTTPS remotes).

- Clone, install, run:
  ```bash
  git clone https://your-git-host.com/your-org/your-app.git
  cd your-app
  cp .env.example .env   # fill in local values
  npm install            # or pip install / go mod download
  npm run dev
  ```
- Document every variable in `.env.example` — name, purpose, where to get the value.

**Done when:** A teammate can clone, fill `.env`, and see the app at `localhost:3000` (or equivalent) within ~15 minutes.

---

## Step 2 — Data and backend

**Who:** You

Set up whatever your app uses for data:

- **Relational DB (Postgres, MySQL, etc.):** Provision a database, run migrations, add the connection string to `.env.example`. Cloud options: Neon (serverless Postgres), PlanetScale, Railway, or a managed instance on your cloud provider.
- **Other data stores:** Add connection details to `.env.example` with notes on where to get credentials.

**Done when:** The app reads/writes data successfully. Skip if your app has no DB or external data yet.

---

## Step 3 — Containerize and set up CI/CD

**Who:** You (+ your platform/infra team if needed)

Get your CI/CD pipeline building and deploying on push to `main`.

1. **Add a `Dockerfile`** — expose the app port and set the start command.
2. **Add a CI/CD config** — GitHub Actions, GitLab CI, CircleCI, etc. Add build and deploy stages. Your platform team can usually provide a template for your target environment.

Example GitHub Actions deploy step:
```yaml
- name: Deploy
  run: |
    docker build -t your-registry/your-app:${{ github.sha }} .
    docker push your-registry/your-app:${{ github.sha }}
    # trigger deploy to your hosting platform
```

**Done when:** Push to `main` → pipeline builds image, pushes to your registry, triggers deploy. Green pipeline.

---

## Step 4 — Deploy to a hosting environment

**Who:** You (+ platform team if needed)

Deploy your app to a persistent test/dev URL. Options: Render, Railway, Fly.io, AWS ECS/EKS, GCP Cloud Run, Kubernetes — whatever your team uses.

Add a **`/health`** endpoint — Ralph uses it to confirm deploys succeeded:

```typescript
app.get('/health', (req, res) => res.json({ status: 'healthy' }));
```

Your dev URL pattern will look something like:
```
https://your-app-dev.your-domain.com
```

**Done when:** Push to `main`, wait a few minutes, open the app URL in a browser and see it running.

---

## Step 5 — Connect external APIs *(skip if not applicable)*

**Who:** You (+ API provider onboarding if needed)

If your app calls an external AI or other API:

1. Get an API key from the provider (OpenAI, Anthropic, etc.)
2. Add the key name to `.env.example` with a note on where to get it
3. Store it in your secret manager (Step 6) — don't hardcode it

**Done when:** API calls from your deployed app return 200.

---

## Step 6 — Secrets managed securely

**Who:** You

Don't hardcode credentials or commit them to git. Common approaches:

- **Environment variables injected at deploy time** — set in your hosting platform's dashboard or CI/CD secrets
- **Secret manager** — AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager, Doppler, etc.
- **`.env` files** — local development only; always gitignored

The pattern:
1. Add the variable name (not value) to `.env.example` with a note on where to get it
2. Set the actual value in your secret manager or hosting platform
3. App reads it from `process.env.VAR_NAME` (or equivalent)

**Done when:** Deployed app gets secrets from the environment. Nothing sensitive is in git.

---

## Step 7 — Accounts and access

**Who:** You

1. Verify the main flow: sign up, sign in, create/save something.
2. Confirm data is stored correctly.
3. Share the app URL and how to sign in with your team.

**Done when:** A teammate can open the URL, create an account, and use the app without your help.

---

## Step 8 — Playwright tests in CI

**Who:** You

Ralph uses these to verify changes didn't break the app.

- **Install:** `npm install --save-dev @playwright/test` and `npx playwright install chromium`
- **Config:** Set `baseURL` from env so the same tests run locally and against your deploy:
  ```typescript
  // playwright.config.ts
  use: {
    baseURL: process.env.STAGING_URL || 'http://localhost:3000',
  }
  ```
- **Tests:** Smoke tests for auth and core flows; use `data-testid` or roles for stable selectors
- **CI:** Add a test stage that runs after deploy:
  ```yaml
  - name: Test
    run: STAGING_URL=${{ vars.DEV_URL }} npm test
  ```

**Done when:** Push to `main` → build → deploy → tests run against the live URL; pipeline is green.

---

## Ready for Ralph

You should have:

- App at a shared URL
- CI/CD pipeline that deploys on push to `main`
- `/health` returning 200
- Playwright tests running against the live URL
- Secrets in your secret manager, not in code

Next: [Set up Ralph →](README.md)
