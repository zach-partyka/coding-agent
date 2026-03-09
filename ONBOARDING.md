# Getting Your App Ready for Ralph

Ralph needs a running app with a test environment and CI/CD before it can do anything useful. This guide walks you through exactly how to get there — based on what it took to stand up Marketing Copilot at Zillow.

If your app is already deployed with a test URL and a GitLab pipeline, skip to [Using Ralph →](README.md).

---

## Progress tracker

Check these off as you go:

- [ ] **Step 1** — App built and running locally (~2–4 hrs, you)
- [ ] **Step 2** — Data and Databricks set up (~1–2 hrs, you) *(skip if no Databricks)*
- [ ] **Step 3** — Containerized + CI/CD pipeline (~1–2 days, you + Delivery/CI)
- [ ] **Step 4** — Deployed to Kubernetes (~1 day, you + Delivery/CI)
- [ ] **Step 5** — ZGAI connected (~2–3 days, you + platform team) *(skip if no AI)*
- [ ] **Step 6** — Secrets in Zodiac + Keeper (~1 hr, you)
- [ ] **Step 7** — Accounts working, URL shared (~30 min, you)
- [ ] **Step 8** — Playwright tests wired into CI (~2–3 hrs, you)

**Total:** ~1–2 weeks end-to-end, mostly waiting on approvals from other teams.

---

## Step 1 — Build the app and set up the repo

**Who:** You
**Time:** 2–4 hours
**Blockers:** None — this is fully in your control

Stand up your app and get it into a GitLab repo under your team's group (e.g. `gitlab.zgtools.net/tpm_cdp_team/your-app`).

Make sure a teammate can clone it and run it locally with:

```bash
git clone https://gitlab.zgtools.net/tpm_cdp_team/your-app.git
cd your-app
cp .env.example .env   # fill in local values
npm install
npm run dev
```

Document what goes in `.env` — every required variable, what it does, and where to get the value. This saves everyone who onboards after you.

**Done when:** Anyone on your team can clone the repo, fill in `.env`, and see the app running at `localhost:3000` within 15 minutes.

---

## Step 2 — Set up data and backend jobs *(skip if no Databricks)*

**Who:** You
**Time:** 1–2 hours
**Blockers:** None if you already have Databricks access

If your app reads from or writes to Databricks:

1. Create the tables your app needs:
   ```sql
   CREATE TABLE IF NOT EXISTS sandbox_marketing.your_app (
     -- your schema here
   );
   ```

2. Create a Databricks job for any scheduled data work (availability checks, notebook runs, SQL tasks). Tag it so platform tooling recognizes it:
   - `Service: your-app`
   - `Team: your-team`

3. Add the Databricks connection details to your `.env.example` so teammates know they're needed.

**Done when:** Your app can read and write data without errors. The Databricks job runs on schedule.

---

## Step 3 — Containerize the app and set up CI/CD

**Who:** You + Delivery/CI team
**Time:** 1–2 days (including wait time for Delivery/CI)
**Blockers:** Delivery/CI needs to set up Artifactory repos and grant deploy permissions — file these requests early

This is what allows GitLab to automatically build and deploy your app every time you push to `main`.

**First: file requests with Delivery/CI (do this before writing any code)**

Ask Delivery/CI to:
1. Create Artifactory Docker repos for your team group (`tpm_cdp_team` or equivalent)
2. Add the required GitLab CI variables to your project (`ARTIFACTORY_USER`, `ARTIFACTORY_PASSWORD`, `ARTIFACTORY_REGISTRY`)
3. Grant deploy permissions for your GitLab pipeline to the consumer nonprod Kubernetes cluster

Without these, your pipeline will fail when it tries to push Docker images or deploy.

**Then: add a `Dockerfile` to your repo**

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

Adjust for your stack (Python, Go, etc.).

**Then: add a `.gitlab-ci.yml`**

Start with the standard Zillow CI template and add build + deploy stages. Delivery/CI can share a working example for your cluster.

**Done when:** Every push to `main` builds a Docker image, pushes it to Artifactory, and triggers a deploy. You can see the pipeline pass in GitLab → CI/CD → Pipelines.

---

## Step 4 — Deploy into Kubernetes (consumer nonprod)

**Who:** You + Delivery/CI team
**Time:** ~1 day
**Blockers:** Depends on Step 3 being complete

Once your pipeline can build and push images, wire it to deploy into the **consumer nonprod Kubernetes cluster**.

1. Work with Delivery/CI to get a Kubernetes namespace and deployment config for your app.
2. Your app will get a URL like:
   ```
   https://your-app-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net
   ```
3. Add a `/health` endpoint to your app — Ralph uses this to confirm deploys succeeded:
   ```typescript
   app.get('/health', (req, res) => res.json({ status: 'healthy' }));
   ```

**Done when:** Push to `main`, wait ~5 minutes, hit your app's URL in a browser and see it running. No local setup required for teammates.

---

## Step 5 — Connect to ZGAI *(skip if your app doesn't use AI)*

**Who:** You + platform team
**Time:** 2–3 days (approval + Terraform automation)
**Blockers:** Two separate requests, each with wait time — file them in parallel

If your app calls the Zillow internal LLM API (ZGAI), you need to be allowlisted and get an API key before any AI calls will work.

**Request 1: Get added to the SERVICE_ALLOWLIST**

File a request to get your app added to the `SERVICE_ALLOWLIST` for `zgai-llm-api`. This is required before ZGAI will accept calls from your service in nonprod. Ask your team's platform contact or check the ZGAI onboarding docs.

**Request 2: Get a Kong consumer and API key via Zodiac**

1. Go to Zodiac → your service → Operational Requests
2. Select **Kong – API Key**
3. Fill in:
   - `Target Service`: `zgai-llm-api`
   - `Sub-environment`: `stage`
4. Submit. Automation runs Terraform plan/apply and provisions the key.

The key will be named something like `your-app-zgai-llm-api-stage`.

**Done when:** ZGAI calls from your app return actual responses instead of 401/403 errors.

---

## Step 6 — Store secrets in Zodiac + Keeper

**Who:** You
**Time:** ~1 hour
**Blockers:** Depends on Step 5 if you have ZGAI keys to store

Never hardcode API keys. Here's the right way to manage them at Zillow:

1. **Copy the key into Keeper** — store it in your team's shared folder so anyone can find it:
   ```
   Keeper → tpm_cdp_team → your-app → ZGAI_API_KEY
   ```

2. **Add it as a nonprod secret in Zodiac:**
   - Go to Zodiac → your service → Secrets
   - Add the key as a nonprod secret with the variable name your app expects (e.g. `ZGAI_API_KEY`)
   - Zodiac injects it into your app at runtime — your app reads it from `process.env.ZGAI_API_KEY`

3. **Add the variable name (not the value) to `.env.example`** so teammates know it's required locally:
   ```
   ZGAI_API_KEY=     # get from Keeper: tpm_cdp_team/your-app
   ```

**Done when:** Your deployed app reads secrets from the environment. No credentials are checked into git. Teammates can find values in Keeper.

---

## Step 7 — Enable accounts and share access

**Who:** You
**Time:** ~30 minutes
**Blockers:** Depends on Steps 4–6 being complete

1. Verify the core user flow works end-to-end: sign up, log in, create something, see it saved.
2. Confirm data is being stored correctly (Databricks, Drizzle ORM, wherever it goes).
3. Share the URL with your team:
   ```
   App URL: https://your-app-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net
   Sign in with your Zillow credentials.
   ```

**Done when:** Teammates can hit the URL, create an account, and use the app without asking you anything.

---

## Step 8 — Add Playwright tests and wire them into CI

**Who:** You
**Time:** 2–3 hours
**Blockers:** None — do this any time after Step 4

This is what lets Ralph verify its changes didn't break anything.

**Install Playwright:**

```bash
npm install --save-dev @playwright/test
npx playwright install chromium
```

**Write smoke tests** covering your critical paths (auth, core user flows, key UI elements):

```typescript
// tests/smoke.spec.ts
import { test, expect } from '@playwright/test';

const BASE_URL = process.env.STAGING_URL || 'http://localhost:3000';

test('homepage loads', async ({ page }) => {
  await page.goto(BASE_URL);
  await expect(page).toHaveTitle(/Your App Name/);
});

test('login page renders', async ({ page }) => {
  await page.goto(`${BASE_URL}/login`);
  await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
});
```

**Configure `playwright.config.ts`:**

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: {
    baseURL: process.env.STAGING_URL || 'http://localhost:3000',
  },
});
```

**Add to `package.json`:**

```json
"scripts": {
  "test": "playwright test"
}
```

**Wire into GitLab CI** — add a test stage that runs after deploy:

```yaml
test:
  stage: test
  script:
    - npm install
    - npx playwright install chromium
    - STAGING_URL=$DEV_URL npm test
  only:
    - main
```

**Done when:** Push to `main` — pipeline builds → deploys → runs tests against the live URL. Green checkmarks in GitLab CI.

---

## You're ready for Ralph

At this point you have:
- ✅ App running at a shared URL
- ✅ GitLab pipeline that deploys on push to `main`
- ✅ `/health` endpoint returning 200
- ✅ Playwright tests running against the live URL
- ✅ Secrets in Zodiac, not in code

Now set up Ralph: [README.md →](README.md)
