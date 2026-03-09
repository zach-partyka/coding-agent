# Ralph — Examples and detailed guides

> **New to Ralph?** Start with `README.md`. This doc goes deeper into specific project types, workflow patterns, and troubleshooting. You probably won't need it until you've run a few sprints.

Detailed walkthroughs for different project types and workflow patterns.

---

## Table of Contents

- [iTerm2 Hotkey Setup](#iterm2-hotkey-setup)
- [Python/FastAPI Example](#pythonfastapi-example)
- [Node.js/TypeScript Example](#nodejstypescript-example)
- [Workflow Patterns](#workflow-patterns)
- [Troubleshooting](#troubleshooting)

---

## iTerm2 Hotkey Setup

**Goal:** One keypress to execute entire sprint with full interactive visibility.

### Step-by-Step Setup

**1. Open iTerm2 Preferences**
```bash
# Keyboard shortcut:
Cmd+,

# Or via menu:
iTerm2 → Preferences (or Settings)
```

**2. Navigate to Key Bindings**
```
Preferences → Keys → Key Bindings
```

**3. Add New Hotkey**
- Click the "+" button at the bottom left
- You'll see "Add Key Binding" dialog

**4. Configure Hotkey**

Fill in the dialog:

| Field | Value |
|-------|-------|
| **Keyboard Shortcut** | Press: `Shift+Cmd+R` |
| **Action** | Select: "Send Text with vim Special Chars" |
| **Text** | Enter: `claude "/ralph-continuous"\n` |

**Important:** Include the `\n` at the end - this sends Enter key after the command.

**5. Click OK**

Your hotkey is now active!

### Alternative Hotkeys (Optional)

You can set up additional hotkeys for other Ralph commands:

| Hotkey | Command | Purpose |
|--------|---------|---------|
| `Shift+Cmd+R` | `claude "/ralph-continuous"\n` | Execute entire sprint |
| `Shift+Cmd+P` | `claude "/ralph-plan"\n` | Sprint planning |
| `Shift+Cmd+T` | `claude "/ralph"\n` | Single task execution |
| `Shift+Cmd+A` | `claude "/ralph-archive"\n` | Archive completed sprint |

**Tip:** Choose shortcuts that don't conflict with system or iTerm2 defaults.

### Testing Your Hotkey

1. Navigate to your project directory:
   ```bash
   cd ~/path/to/your/project
   ```

2. Ensure you have:
   - ✅ `sprint_plan.md` with tasks
   - ✅ `ralph.config.sh` configured
   - ✅ Ralph skills installed

3. Press `Shift+Cmd+R`

You should see:
- Orchestrator output in current tab
- New iTerm2 tabs opening for each task
- Full interactive Claude UI in each task tab

### Why This Workflow is Powerful

**Before hotkey:**
```bash
# Manual typing every time
cd ~/Documents/AI/my-project
claude "/ralph-continuous"
```

**After hotkey:**
```bash
# Just press Shift+Cmd+R
# Already in project directory from previous work
```

**Benefits:**
- **Muscle memory** - No need to remember command syntax
- **Zero friction** - Reduce mental overhead for iteration
- **Faster cycles** - Complete sprint → review → start next in seconds
- **Context preservation** - Stay in flow state

---

## Python/FastAPI Example

Complete example for FastAPI projects (Zillow standard).

### Prerequisites

Before running setup, your project needs:
- ✅ Python code (FastAPI app)
- ✅ Git repository (`git init` if needed)
- ✅ `requirements.txt` or `pyproject.toml`
- ✅ Staging environment that auto-deploys on push

### Project Setup

**1. Run setup script**
```bash
cd ~/your-fastapi-project
~/ralph-starter-kit/scripts/setup.sh
```

Setup will detect Python project and suggest:
```
✓ Detected: Python project

Local validation command:
Default: python -m ruff check src/ && python -m mypy src/ && python -m pytest tests/unit/
Press Enter to use default, or type custom command:
```

**2. Verify generated config**
```bash
cat ralph.config.sh
```

Should look like:
```bash
export RALPH_GIT_REMOTE="https://gitlab.zgtools.net/your-team/your-app.git"
export RALPH_GIT_MAIN_BRANCH="main"
export RALPH_DEPLOY_URL="https://your-app-dev.your-domain.com"
export RALPH_VALIDATE_LOCAL="python -m ruff check src/ && python -m mypy src/ && python -m pytest tests/unit/"
export RALPH_VALIDATE_DEPLOY="python -m pytest tests/integration/ -v"
```

**3. Review example patterns**
```bash
# See FastAPI patterns
cat examples/python-fastapi/stdlib/fastapi_patterns.md

# See testing patterns
cat examples/python-fastapi/stdlib/testing_patterns.md

# See example spec
cat examples/python-fastapi/specs/user_api.md
```

### FastAPI-Specific Patterns

**Key differences from Flask:**
- Async/await everywhere (`async def`, `await db.execute()`)
- Pydantic for validation (not Marshmallow)
- SQLAlchemy 2.0 async (`AsyncSession`, `select()` syntax)
- Ruff for linting (replaces flake8/black/isort)
- httpx.AsyncClient for testing (not Flask TestClient)

**Example spec structure:**
```markdown
# Spec: User API

## GET /users/{id}
**Response:** 200 OK
```json
{"id": 123, "email": "user@example.com"}
```

**Pydantic Schema:**
```python
class UserResponse(BaseModel):
    id: int
    email: EmailStr
    name: str
    model_config = {"from_attributes": True}
```
```

**Example stdlib entry:**
```markdown
## FastAPI Dependency Injection

```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncSession:
    async with async_session_maker() as session:
        yield session

@router.get("/users/{user_id}")
async def get_user(
    user_id: int,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()
```
```

### Virtual Environment Setup

**Critical:** Activate venv before running Ralph!

```bash
# Create venv (one-time)
python -m venv venv

# Activate (every session)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Verify
which python  # Should show venv/bin/python
```

**Add to your shell profile:**
```bash
# ~/.zshrc or ~/.bashrc
alias activate-myproject='cd ~/path/to/project && source venv/bin/activate'
```

Then just: `activate-myproject` before pressing `Shift+Cmd+R`

---

## Node.js/TypeScript Example

Based on Zillow Marketing Copilot (6 sprints, $7.50 total cost).

### Prerequisites

Before running setup, your project needs:
- ✅ Node.js/TypeScript code
- ✅ Git repository (`git init` if needed)
- ✅ `package.json` with scripts
- ✅ Staging environment that auto-deploys on push

### Project Setup

**1. Run setup script**
```bash
cd ~/your-nodejs-project
~/ralph-starter-kit/scripts/setup.sh
```

Setup detects Node.js and suggests:
```
✓ Detected: Node.js/TypeScript project

Local validation command:
Default: npm run check
Press Enter to use default, or type custom command:
```

**2. Verify generated config**
```bash
cat ralph.config.sh
```

Should look like:
```bash
export RALPH_GIT_REMOTE="https://gitlab.zgtools.net/your-team/your-app.git"
export RALPH_DEPLOY_URL="https://your-app-dev.your-domain.com"
export RALPH_VALIDATE_LOCAL="npm run check"
export RALPH_VALIDATE_DEPLOY="STAGING_URL=\$RALPH_DEPLOY_URL npm test"
```

**3. Review example patterns**
```bash
# Express patterns
cat examples/nodejs-typescript/stdlib/express_patterns.md

# Playwright testing
cat examples/nodejs-typescript/stdlib/testing_patterns.md
```

### Node.js-Specific Patterns

**Key stack:**
- Express + TypeScript for backend
- React + Vite for frontend (if full-stack)
- Drizzle ORM for database
- Zod for validation
- Playwright for E2E testing

**Example spec structure:**
```markdown
# Spec: User API Endpoint

## POST /api/users
**Request Body:**
```json
{"email": "user@example.com", "name": "John"}
```

**Validation (Zod):**
```typescript
const UserCreateSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
});
```
```

**Example stdlib entry:**
```markdown
## Express Validation Middleware

```typescript
function validateRequest(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (error) {
      if (error instanceof z.ZodError) {
        return res.status(400).json({
          error: 'Validation failed',
          details: error.errors
        });
      }
      next(error);
    }
  };
}
```
```

---

## Workflow Patterns

### Pattern 1: Investigation-First (Performance/Bug Sprints)

**When to use:** Bug fixes, performance optimization, debugging.

**Sprint structure:**
```markdown
## Sprint: Fix Chat Response Slowness

### Tasks
- [ ] **#1** Investigate chat response slowness (time-boxed 10-15 min)
  - Goal: Identify root causes, NOT implement fixes
  - Output: List of specific issues with evidence

<!-- After investigation completes, Ralph updates plan: -->

## Investigation Results (Task #1)
Root causes identified:
1. Databricks query taking 3.2s (N+1 query problem)
2. No response streaming (user waits for full response)
3. Missing database indexes on user_id column

Recommended fix order: [1, 3, 2] (based on impact/effort)

### Remaining Tasks
- [ ] **#2** Add database indexes for user queries
- [ ] **#3** Fix N+1 query in chat endpoint
- [ ] **#4** Implement response streaming
```

**Why this works:** Sprint 2 proved this. Investigation (7 min) identified 3 root causes, informing 9 subsequent tasks with zero blockers.

### Pattern 2: UI Changes with Visual Validation

**Lesson learned:** Sprint 3 had 36% UI task failure rate because code was committed but changes weren't visually verified.

**Required checklist for UI tasks:**
```markdown
- [ ] **#5** Update landing page headline
  - Change "Start Here" to "Confident Campaigns Start Here"
  - **CRITICAL:** Search ALL files for "Start Here" first
  - Files to check: header.tsx, mobile-nav.tsx, landing.tsx
  - Validation:
    1. Commit changes
    2. Wait for deploy (5 min)
    3. Open deploy target in browser
    4. Visually confirm headline changed
    5. Check `git status` for uncommitted files
```

**Common UI pitfalls:**
- Text exists in multiple components (grep before editing)
- Edited wrong component (use DevTools to trace)
- Changes in working directory but not committed
- Deploy succeeded but wrong component updated

### Pattern 3: Small, Focused Tasks

**Good task size:** 15-30 minutes implementation time.

**Bad task (too large):**
```markdown
- [ ] Add user authentication system
```

**Good tasks (right-sized):**
```markdown
- [ ] Add password hashing utility (bcrypt)
- [ ] Create User model with password_hash field
- [ ] Add POST /auth/login endpoint
- [ ] Add JWT token generation
- [ ] Add authentication middleware
- [ ] Add protected route example
```

**Why:** Smaller tasks = clearer specs, easier validation, faster feedback cycles.

---

## Troubleshooting

### iTerm2 Hotkey Issues

**Issue: Hotkey doesn't work**

Check conflicts:
```bash
# System Preferences → Keyboard → Shortcuts
# Verify Shift+Cmd+R isn't used by macOS

# iTerm2 → Preferences → Keys → Key Bindings
# Look for duplicate or conflicting shortcuts
```

Try alternative:
- `Shift+Cmd+B` (Build)
- `Ctrl+Cmd+R` (Control variant)
- `Opt+Cmd+R` (Option variant)

**Issue: Command doesn't execute**

Verify text exactly:
```
claude "/ralph-continuous"\n
```

Common mistakes:
- ❌ Missing `\n` at end
- ❌ Wrong quotes (smart quotes vs. straight quotes)
- ❌ Extra spaces
- ✅ Correct: `claude "/ralph-continuous"\n`

**Issue: Runs in wrong directory**

Hotkeys execute in current iTerm2 working directory. Before pressing hotkey:
```bash
cd ~/path/to/your/project
pwd  # Verify you're in the right place
```

### iTerm2 Tab Spawning Issues

**Issue: No tabs open, runs inline**

Check AppleScript permissions:
```bash
# System Settings → Privacy & Security → Automation
# Ensure iTerm2 can control Terminal or System Events
```

Verify iTerm2 detected:
```bash
echo $TERM_PROGRAM
# Should output: iTerm.app
```

**Issue: Tabs open but no output**

Check marker directory:
```bash
ls -la .ralph-markers/
# If stuck, remove: rm -rf .ralph-markers/
```

Check orchestrator log:
```bash
tail -f ralph-continuous.log
```

**Issue: Terminal.app opens instead of iTerm2**

Set iTerm2 as default terminal:
```bash
# iTerm2 → Preferences → General
# Check: "Make iTerm2 Default Term"
```

Or set explicitly:
```bash
export TERM_PROGRAM="iTerm.app"
```

### Configuration Issues

**Issue: Config not loaded**

Verify file exists:
```bash
ls -la ralph.config.sh
# Should be executable: -rwxr-xr-x
```

Make executable:
```bash
chmod +x ralph.config.sh
```

Test config loads:
```bash
source ralph.config.sh
echo $RALPH_DEPLOY_URL
# Should print your deploy target URL
```

**Issue: Skills use wrong values**

Skills need updating to read env vars. Check:
```bash
# Current skills still use hardcoded values (backward compatible)
# Future: Skills will read $RALPH_* environment variables
```

Workaround: Set env vars before running:
```bash
export RALPH_DEPLOY_URL="https://your-app.com"
claude "/ralph-continuous"
```

### Python Virtual Environment Issues

**Issue: ModuleNotFoundError**

Virtual environment not activated:
```bash
which python
# Should show: /path/to/project/venv/bin/python
# If not, run: source venv/bin/activate
```

**Issue: Wrong Python version**

Check Python version:
```bash
python --version
# Should be 3.9+
```

Recreate venv with correct version:
```bash
rm -rf venv
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Git Issues

**Issue: Push rejected**

Verify HTTPS remote (not SSH):
```bash
git remote -v
# Should show: https://gitlab.zgtools.net/...
# Not: git@gitlab.zgtools.net:...
```

Fix if SSH:
```bash
git remote set-url origin https://gitlab.zgtools.net/your-team/your-repo.git
```

**Issue: Authentication failed**

Configure git credentials:
```bash
# macOS Keychain
git config --global credential.helper osxkeychain

# Or use personal access token
# GitLab → Preferences → Access Tokens
# Use token as password when prompted
```

### Deployment Issues

**Issue: Health check fails**

Verify deploy target URL:
```bash
curl https://your-app-dev.your-domain.com/health
# Should return 200 with {"status":"healthy"}
```

Check deploy wait time:
```bash
# If deploys take longer, increase timeout
export RALPH_DEPLOY_WAIT_SECONDS=600  # 10 minutes
```

**Issue: Tests fail on deploy target**

Run tests manually:
```bash
STAGING_URL=https://your-app-dev.your-domain.com npm test

# Or for Python:
STAGING_URL=https://your-app-dev.your-domain.com python -m pytest tests/integration/
```

Check deploy target logs for errors.

---

## Additional Resources

**Starter Kit Documentation:**
- `README.md` - Quick start and overview
- `CONFIGURATION_GUIDE.md` - Complete configuration reference
- `CHANGELOG.md` - Version history and migration guides

**Example Projects:**
- `examples/python-fastapi/` - FastAPI reference implementation
- `examples/nodejs-typescript/` - Node.js/TypeScript reference

**Scripts:**
- `scripts/setup.sh` - Interactive project setup
- `scripts/validate.sh` - Configuration validator (coming soon)
- `scripts/migrate.sh` - Migration helper (coming soon)

**Questions or Issues:**
Report at: [Your GitLab Issues URL]
