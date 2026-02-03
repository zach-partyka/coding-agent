# Ralph Build Instructions - Python/FastAPI

## Quick Reference

**Build & Test:**
```bash
# Activate virtual environment (REQUIRED before using Ralph)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Local validation (before commit)
python -m ruff check src/         # Linting
python -m mypy src/               # Type checking
python -m pytest tests/unit/ -v  # Unit tests

# Start development server
uvicorn src.main:app --reload --port 8000

# Run integration tests against staging
STAGING_URL=https://app-staging.zgtools.net python -m pytest tests/integration/ -v
```

**Deployment:**
- Pushing to `main` auto-deploys to staging via GitLab CI/CD
- Wait time: ~3 minutes for FastAPI apps
- Health check: `GET /health` returns `{"status": "healthy", "version": "1.0.0"}`

## Project Structure

```
src/
  api/
    __init__.py
    routers/
      users.py          # User API routes
      auth.py           # Authentication routes
    dependencies.py     # FastAPI dependencies (DB sessions, auth, etc.)

  models/
    __init__.py
    user.py            # SQLAlchemy models
    database.py        # DB connection and session factory

  schemas/
    __init__.py
    user.py            # Pydantic schemas for request/response

  services/
    __init__.py
    user_service.py    # Business logic layer

  core/
    __init__.py
    config.py          # Settings (using Pydantic BaseSettings)
    security.py        # Password hashing, JWT, etc.

  main.py              # FastAPI app instance

tests/
  unit/
    test_services.py   # Service layer unit tests
    test_models.py     # Model tests
  integration/
    test_api.py        # API endpoint tests (run against staging)
    conftest.py        # Pytest fixtures

requirements.txt       # Production dependencies
requirements-dev.txt   # Development/testing dependencies
pyproject.toml         # Tool configuration (ruff, mypy, pytest)
```

## Common Patterns

### Adding a New API Endpoint

1. **Define Pydantic schemas** in `src/schemas/user.py`:
   ```python
   from pydantic import BaseModel, EmailStr, Field

   class UserCreate(BaseModel):
       email: EmailStr
       name: str = Field(..., min_length=2, max_length=100)
       password: str = Field(..., min_length=8)

   class UserResponse(BaseModel):
       id: int
       email: str
       name: str
       status: str
       created_at: datetime

       class Config:
           from_attributes = True  # Allows Pydantic to read from ORM models
   ```

2. **Define route** in `src/api/routers/users.py`:
   ```python
   from fastapi import APIRouter, Depends, HTTPException
   from sqlalchemy.ext.asyncio import AsyncSession
   from src.api.dependencies import get_db
   from src.schemas.user import UserCreate, UserResponse
   from src.services import user_service

   router = APIRouter(prefix="/users", tags=["users"])

   @router.get("/{user_id}", response_model=UserResponse)
   async def get_user(
       user_id: int,
       db: AsyncSession = Depends(get_db)
   ):
       user = await user_service.get_user(db, user_id)
       if not user:
           raise HTTPException(status_code=404, detail="User not found")
       return user
   ```

3. **Add service logic** in `src/services/user_service.py`:
   ```python
   from sqlalchemy.ext.asyncio import AsyncSession
   from sqlalchemy import select
   from src.models.user import User

   async def get_user(db: AsyncSession, user_id: int) -> User | None:
       result = await db.execute(select(User).where(User.id == user_id))
       return result.scalar_one_or_none()
   ```

4. **Register router** in `src/main.py`:
   ```python
   from fastapi import FastAPI
   from src.api.routers import users, auth

   app = FastAPI(title="My API", version="1.0.0")
   app.include_router(users.router)
   app.include_router(auth.router)
   ```

5. **Add integration test** in `tests/integration/test_api.py`:
   ```python
   import pytest
   from httpx import AsyncClient

   @pytest.mark.asyncio
   async def test_get_user(client: AsyncClient, test_user):
       response = await client.get(f"/users/{test_user.id}")
       assert response.status_code == 200
       data = response.json()
       assert data["id"] == test_user.id
       assert data["email"] == test_user.email
   ```

### Database Migrations (Alembic)

```bash
# Create migration
alembic revision --autogenerate -m "Add user email field"

# Review migration file in alembic/versions/

# Apply locally
alembic upgrade head

# Commit migration file (auto-applies on staging deploy)
git add alembic/versions/*.py
git commit -m "Add user email migration"
```

### Dependency Injection Pattern

FastAPI uses dependency injection for database sessions, auth, etc.:

```python
# src/api/dependencies.py
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.database import async_session_maker

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_maker() as session:
        yield session

# Usage in routes:
@router.get("/users")
async def list_users(db: AsyncSession = Depends(get_db)):
    # db is automatically provided and closed after request
    pass
```

## Project-Specific Quirks

- **Async by default**: All database operations use `async`/`await`
- **SQLAlchemy 2.0+**: Uses new async API (`AsyncSession`, `select()` syntax)
- **Pydantic V2**: Uses `model_config` instead of nested `Config` class
- **Ruff**: Replaces flake8, black, isort (faster, single tool)
- **Health Check**: Returns `{"status": "healthy", "version": "1.0.0"}` from `__version__.py`
- **CORS**: Configured for `*.zgtools.net` domains only

## Virtual Environment Setup

Ralph **requires** an activated virtual environment. Before running any Ralph commands:

```bash
# Create venv (one-time)
python -m venv venv

# Activate (every terminal session)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Verify activation
which python  # Should show venv/bin/python
```

If you forget to activate, you'll see errors like:
- `ModuleNotFoundError: No module named 'fastapi'`
- `command not found: pytest`

## Environment Variables

**Local Development (.env):**
- `DATABASE_URL`: PostgreSQL async connection string (`postgresql+asyncpg://...`)
- `SECRET_KEY`: JWT secret key
- `DEBUG`: Set to `true` for local dev

**Testing:**
- `STAGING_URL`: Injected automatically by ralph.config.sh
- `DATABASE_URL`: Test database (separate from local dev)

**Production/Staging:**
- Managed by Kubernetes secrets - don't commit to git

## Common Issues

**Port 8000 already in use:**
```bash
lsof -ti:8000 | xargs kill -9  # Kill process on port 8000
uvicorn src.main:app --reload  # Restart
```

**Type errors after changes:**
```bash
python -m mypy src/  # Check what's failing
```

**Alembic migration conflicts:**
```bash
alembic downgrade -1  # Rollback one migration
alembic upgrade head  # Re-apply
```

**Async test failures:**
- Make sure you're using `@pytest.mark.asyncio` decorator
- Use `AsyncClient` from httpx, not `TestClient`
- Database fixtures must use `async`/`await`

## Validation Checklist

After making changes:

1. **Linting:** `python -m ruff check src/` - MUST pass before commit
2. **Type checking:** `python -m mypy src/` - MUST pass before commit
3. **Unit tests:** `python -m pytest tests/unit/` - MUST pass
4. **Start server:** `uvicorn src.main:app --reload` - Server must start
5. **Health check:** `curl http://localhost:8000/health` - Must return 200
6. **OpenAPI docs:** Open http://localhost:8000/docs - Verify endpoints show up
7. **Integration tests:** `STAGING_URL=... pytest tests/integration/` - Tests against staging

## Learned Lessons

### 2026-01-20 - Async Context Managers
**What happened:** Database sessions leaked because `await` was missing
**Solution:** Use `async with async_session_maker() as session` consistently
**Pattern:** All database operations must use async context managers

### 2026-01-22 - Pydantic from_attributes
**What happened:** Pydantic couldn't convert SQLAlchemy models to response schemas
**Solution:** Set `model_config = {"from_attributes": True}` in Pydantic models
**Pattern:** Always enable `from_attributes` for ORM-backed response models

### 2026-01-25 - Test Client Must Be Async
**What happened:** Integration tests failed with "coroutine was never awaited"
**Solution:** Use `httpx.AsyncClient` instead of `starlette.testclient.TestClient`
**Pattern:**
```python
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_endpoint(client: AsyncClient):
    response = await client.get("/endpoint")
```

### 2026-01-28 - Alembic Auto-Detection Needs Imports
**What happened:** `alembic revision --autogenerate` didn't detect new models
**Solution:** Import all models in `alembic/env.py` before `target_metadata` assignment
**Pattern:** Every new model file must be imported in `env.py`
