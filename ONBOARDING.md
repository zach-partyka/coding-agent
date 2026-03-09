# Getting Your App Ready for Ralph

Ralph needs a running app with a test environment and CI/CD before it can do anything useful. This guide walks you through exactly how to get there — based on what it took to stand up Marketing Copilot at Zillow.

If your app is already deployed with a test URL and a GitLab pipeline, skip to [Using Ralph →](README.md).

---

## What you need by the end of this guide

- Your app running at a shared URL teammates can hit (e.g. `https://your-app-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net`)
- A GitLab pipeline that automatically deploys your app when you push to `main`
- A test suite (Playwright) that runs against that URL
- Secrets managed through Zodiac so nothing is hardcoded

---

## Step 1 — Build the app and set up the repo

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

**What "done" looks like:** Anyone on your team can clone the repo, fill in `.env`, and see the app running at `localhost:3000` (or wherever) within 15 minutes.

---

## Step 2 — Set up data and backend jobs (if your app needs it)

If your app reads from or writes to Databricks:

1. Create the tables your app needs. For Marketing Copilot this was:
   ```sql
   CREATE TABLE IF NOT EXISTS sandbox_marketing.marketing_copilot (
     -- your schema here
   );
   ```

2. Create a Databricks job to handle any scheduled data work (availability checks, notebook runs, SQL tasks). Tag it so platform tooling recognizes it:
   - `Service: your-app`
   - `Team: your-team`

3. Add the Databricks connection details to your `.env.example` so teammates know they're needed.

**What "done" looks like:** Your app can read and write data without errors. The Databricks job runs on schedule.

---

## Step 3 — Containerize the app and set up CI/CD

This is what allows GitLab to build and deploy your app automatically every time you push.

**Get Artifactory Docker repos set up:**

Ask someone on Delivery/CI to create Artifactory Docker repos for your team group (`tpm_cdp_team` or equivalent) and add the required GitLab CI variables to your project. Without this, your pipeline will fail when it tries to push Docker images.

You'll need these GitLab CI variables set (Delivery/CI will know what these are):
- `ARTIFACTORY_USER`
- `ARTIFACTORY_PASSWORD`
- `ARTIFACTORY_REGISTRY`

**Get deploy permissions:**

Ask Delivery/CI to grant deploy permissions for your GitLab pipeline to the target Kubernetes cluster. Without this, the pipeline builds the image but can't deploy it.

**Add a `Dockerfile` to your repo:**

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

**Add a `.gitlab-ci.yml`:**

Start with the standard Zillow CI template and add build + deploy stages. Delivery/CI can share a working example for your cluster.

**What "done" looks like:** Every push to `main` builds a Docker image, pushes it to Artifactory, and triggers a deploy. You can see the pipeline pass in GitLab → CI/CD → Pipelines.

---

## Step 4 — Deploy into Kubernetes (consumer nonprod)

Once your pipeline can build and push images, wire it to deploy into the **consumer nonprod Kubernetes cluster**.

1. Work with Delivery/CI to get a Kubernetes namespace and deployment config for your app.
2. Your app will get a URL like:
   ```
   https://your-app-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net
   ```
3. Add a `/health` endpoint to your app that returns HTTP 200 — Ralph uses this to confirm deploys succeeded:
   ```typescript
   app.get('/health', (req, res) => res.json({ status: 'healthy' }));
   ```

**What "done" looks like:** Push to `main`, wait ~5 minutes, hit your app's URL in a browser and see it running. No local setup required for teammates.

---

## Step 5 — Connect to ZGAI (if your app uses AI)

If your app calls the Zillow internal LLM API (ZGAI), you need to get it allowlisted and get an API key before any AI calls will work.

**Get added to the SERVICE_ALLOWLIST:**

File a request to get your app added to the `SERVICE_ALLOWLIST` for `zgai-llm-api`. This is required before ZGAI will accept calls from your service in nonprod. Ask your team's platform contact or check the ZGAI onboarding docs.

**Request a Kong consumer and API key:**

Use the **Zodiac Operational Request** for Kong:
1. Go to Zodiac → your service → Operational Requests
2. Select **Kong – API Key**
3. Fill in:
   - `Target Service`: `zgai-llm-api`
   - `Sub-environment`: `stage`
4. Submit. Automation runs Terraform plan/apply and provisions the key.

The key will be called something like `your-app-zgai-llm-api-stage`.

**What "done" looks like:** You have an API key and ZGAI calls from your app return responses instead of 401/403 errors.

---

## Step 6 — Store secrets in Zodiac + Keeper

Never hardcode API keys. Here's the right way to manage them at Zillow:

1. **Copy the key into Keeper** — store it in your team's shared Keeper folder so others can find it if needed.

2. **Add it as a nonprod secret in Zodiac:**
   - Go to Zodiac → your service → Secrets
   - Add the key as a nonprod secret with the variable name your app expects (e.g. `ZGAI_API_KEY`)
   - Zodiac injects it into your app at runtime — your app reads it from `process.env.ZGAI_API_KEY`

3. **Add the variable name (not the value) to `.env.example`** so teammates know it's required locally:
   ```
   ZGAI_API_KEY=           # get from Keeper: tpm_cdp_team/your-app
   ```

**What "done" looks like:** Your deployed app reads secrets from the environment. No credentials are checked into git. Teammates can find values in Keeper.

---

## Step 7 — Enable accounts and share access

Once the app is deployed:

1. Make sure user creation works end-to-end (sign up, log in, create content — whatever your app's core flow is).
2. Confirm user data is being stored correctly (Databricks tables, Drizzle ORM, wherever it goes).
3. Share the dev URL with your team:
   ```
   App URL: https://your-app-dev.int.zgcp-consumer-nonprod-k8s.zg-int.net
   Sign in with your Zillow credentials.
   ```

**What "done" looks like:** Teammates can hit the URL, create an account, and use the app without any help from you.

---

## Step 8 — Add Playwright tests and wire them into CI

This is what lets Ralph verify that its changes didn't break anything.

**Install Playwright:**

```bash
npm install --save-dev @playwright/test
npx playwright install chromium
```

**Write smoke tests** covering the critical paths (auth, core user flows, key UI elements):

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

**What "done" looks like:** Push to `main`, pipeline builds → deploys → runs tests against the live URL. You see green checkmarks in GitLab CI.

---

## You're ready for Ralph

At this point you have:
- ✅ App running at a shared URL
- ✅ GitLab pipeline that deploys on push to `main`
- ✅ `/health` endpoint returning 200
- ✅ Playwright tests running against the live URL
- ✅ Secrets in Zodiac, not in code

Now set up Ralph: [README.md →](README.md)
