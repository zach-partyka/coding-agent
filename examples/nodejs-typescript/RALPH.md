# Ralph Build Instructions - Node.js/TypeScript

## Quick Reference

**Build & Test:**
```bash
# Install dependencies
npm install

# Local validation (type checking)
npm run check

# Start development server
npm run dev

# Run E2E tests against staging
STAGING_URL=https://app-staging.zgtools.net npm test
```

**Deployment:**
- Pushing to `main` auto-deploys to staging via GitLab CI/CD
- Wait time: ~5 minutes for full deployment
- Health check: `GET /health` returns `{"status":"healthy","timestamp":"..."}`

## Project Structure

```
client/src/           Frontend (React + Vite)
  components/         React components
  pages/              Route components
  hooks/              Custom React hooks
  utils/              Client-side utilities
  App.tsx             Main app component

server/               Backend (Express + TypeScript)
  routes.ts           API route definitions
  middleware/         Express middleware
  services/           Business logic
  db/                 Database utilities
  process_*.py        Python scripts for AI/data processing

shared/               Shared between client and server
  schema.ts           Zod schemas for validation
  types.ts            TypeScript type definitions

specs/                Feature specifications (WHAT to build)
stdlib/               Technical patterns (HOW to build)

tests/                E2E tests (Playwright)
  *.spec.ts           Test files
  fixtures/           Test data and helpers
```

## Common Patterns

### Adding a New API Endpoint

1. **Define route** in `server/routes.ts`:
   ```typescript
   app.get('/api/users/:id', async (req, res) => {
     const userId = parseInt(req.params.id);
     const user = await userService.getUser(userId);
     res.json(user);
   });
   ```

2. **Add service logic** in `server/services/userService.ts`:
   ```typescript
   export async function getUser(userId: number): Promise<User> {
     const user = await db.query('SELECT * FROM users WHERE id = ?', [userId]);
     if (!user) throw new NotFoundError('User not found');
     return user;
   }
   ```

3. **Add validation** in `shared/schema.ts`:
   ```typescript
   export const UserSchema = z.object({
     id: z.number(),
     email: z.string().email(),
     name: z.string().min(2).max(100),
   });
   ```

4. **Add E2E test** in `tests/user-api.spec.ts`:
   ```typescript
   test('get user by id', async ({ request }) => {
     const response = await request.get('/api/users/123');
     expect(response.status()).toBe(200);
     const user = await response.json();
     expect(user.id).toBe(123);
   });
   ```

### Adding a React Component

1. **Create component** in `client/src/components/UserCard.tsx`:
   ```typescript
   interface UserCardProps {
     user: User;
   }

   export function UserCard({ user }: UserCardProps) {
     return (
       <div className="user-card">
         <h3>{user.name}</h3>
         <p>{user.email}</p>
       </div>
     );
   }
   ```

2. **Add test** in `tests/user-card.spec.ts`:
   ```typescript
   test('displays user information', async ({ page }) => {
     await page.goto('/users/123');
     await expect(page.locator('.user-card h3')).toContainText('John Doe');
     await expect(page.locator('.user-card p')).toContainText('john@example.com');
   });
   ```

3. **Verify locally**:
   ```bash
   npm run dev
   # Open http://localhost:3000/users/123 in browser
   ```

### Path Aliases

This project uses TypeScript path aliases:
- `@/*` → `client/src/*`
- `@shared/*` → `shared/*`
- `@assets/*` → `attached_assets/*`

**Example:**
```typescript
// Instead of: import { UserSchema } from '../../../shared/schema';
import { UserSchema } from '@shared/schema';
```

Configured in `tsconfig.json` and Vite config.

## Project-Specific Quirks

- **Hybrid TypeScript/Python**: Express server calls Python scripts for AI operations
  - Python dependencies NOT managed by npm - requires separate `pip install`
  - Python scripts in `server/` directory
- **Database**: Databricks SQL (custom query layer, Zod schemas — no ORM)
- **Authentication**: Email/password (bcrypt) with express-session (sessions in Databricks)
- **CORS**: Configured for `*.zgtools.net` domains only
- **Health Check**: Returns `{"status":"healthy","timestamp":"2026-01-15T10:30:00Z"}`

## Python Integration

Some operations use Python scripts called from Express:

**Install Python dependencies:**
```bash
pip3 install -r server/requirements.txt
```

**Common Python scripts:**
- `process_brief.py` - AI brief processing with OpenAI
- `python_jira_api.py` - Jira ticket creation
- `python_chat_api.py` - Chat API integration

**If Python scripts fail:**
```bash
# Verify Python packages installed
pip3 list | grep -E "openai|databricks|requests"

# Check Python version (requires 3.9+)
python3 --version
```

## Environment Variables

**Required for local development (.env):**
- `DATABRICKS_HOST`: Databricks workspace URL
- `DATABRICKS_HTTP_PATH`: SQL warehouse path
- `DATABRICKS_TOKEN`: Authentication token
- `DATABRICKS_CATALOG`: Catalog name
- `DATABRICKS_SCHEMA`: Schema name
- `ZGAI_API_KEY`: Zillow internal AI API key
- `SESSION_SECRET`: Min 32 characters for session encryption

**Testing:**
- `STAGING_URL`: Injected automatically by ralph.config.sh

**Tip:** Copy `.env.example` to `.env` and fill in values. Server won't start without these.

## Common Issues

**Port 3000 already in use:**
```bash
npm run kill-port    # Kills process on port 3000
npm run dev          # Restart server
```

**TypeScript errors after git pull:**
```bash
npm install          # Update dependencies
npm run check        # Verify types compile
```

**E2E tests failing locally:**
- Make sure dev server is running on port 3000
- Check that test credentials are set up (see tests/README.md)
- Staging tests require STAGING_URL environment variable

**Python script failures:**
```bash
# Reinstall Python dependencies
pip3 install -r server/requirements.txt --upgrade
```

## Validation Checklist

After making changes:

1. **Type checking:** `npm run check` - MUST pass before commit
2. **Start server:** `npm run dev` - Server must start without crashes
3. **Health check:** `curl http://localhost:3000/health` - Must return 200
4. **Visual check:** Open feature in browser, verify it works
5. **E2E tests:** `npm test` - Tests against staging must pass

## Learned Lessons

### 2026-01-30 - Visual Validation is Mandatory
**What happened:** 36% of UI tasks failed because code was committed but visual changes weren't verified
**Solution:** After staging deploy: (1) open browser, (2) visually confirm change, (3) check `git status`
**Pattern:** NEVER mark UI task complete without visual verification in staging

### 2026-01-30 - Search All Instances Before Changing UI Text
**What happened:** Changed text in one component but it existed in 3 components (header, mobile-nav, landing)
**Solution:** `grep -r "text to change" client/src/` before editing
**Pattern:** UI text often appears in multiple components - find ALL instances

### 2026-01-30 - Check Git Status Before Marking Complete
**What happened:** Changes were in working directory but never committed
**Solution:** Run `git status` as part of completion checklist
**Pattern:** Uncommitted changes = not deployed = task incomplete
