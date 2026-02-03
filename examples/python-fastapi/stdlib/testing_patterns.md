# Testing Patterns for Python/FastAPI

## Test Organization

### Directory Structure
```
tests/
  unit/
    test_models.py       # Model tests (no DB)
    test_services.py     # Service tests (with test DB)
    test_schemas.py      # Pydantic validation tests
  integration/
    test_api.py          # API endpoint tests
    test_workflows.py    # Multi-endpoint workflows
    conftest.py          # Shared fixtures
```

**Pattern:** Unit tests are fast and isolated. Integration tests hit real endpoints with httpx.AsyncClient.

---

## Fixture Patterns

### Database Fixtures (Async)
```python
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool
from src.models.database import Base
from src.main import app
from src.api.dependencies import get_db

# Test database URL (use in-memory SQLite or separate test DB)
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture(scope="session")
async def engine():
    """Create async engine for tests"""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        poolclass=NullPool  # No connection pooling for tests
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()

@pytest_asyncio.fixture
async def db_session(engine):
    """Create new session for each test"""
    async_session_maker = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with async_session_maker() as session:
        yield session
        await session.rollback()  # Rollback changes after test

@pytest_asyncio.fixture
async def client(db_session):
    """Async HTTP client with dependency overrides"""
    from httpx import AsyncClient

    # Override database dependency
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

    # Clear overrides after test
    app.dependency_overrides.clear()
```

**Why:** Session-scoped engine, function-scoped session with rollback for isolation. Use httpx.AsyncClient, not TestClient.

---

### Test Data Factories
```python
# tests/factories.py
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.user import User
from src.core.security import hash_password

class UserFactory:
    @staticmethod
    async def create(
        db: AsyncSession,
        email='test@example.com',
        name='Test User',
        password='password123',
        status='active',
        **kwargs
    ) -> User:
        user = User(
            email=email,
            name=name,
            password_hash=hash_password(password),
            status=status,
            **kwargs
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user

# Usage in tests:
@pytest.mark.asyncio
async def test_get_user(client, db_session):
    user = await UserFactory.create(db_session, email='specific@example.com')
    response = await client.get(f'/users/{user.id}')
    assert response.status_code == 200
```

**Pattern:** Async factories with sensible defaults make test setup clean and readable.

---

## API Testing Patterns

### Testing Success Cases
```python
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

@pytest.mark.asyncio
async def test_create_user_success(client: AsyncClient, db_session: AsyncSession):
    payload = {
        'email': 'newuser@example.com',
        'name': 'New User',
        'password': 'securepass123'
    }
    response = await client.post('/users/', json=payload)

    # Check status and structure
    assert response.status_code == 201
    data = response.json()
    assert data['email'] == payload['email']
    assert data['name'] == payload['name']
    assert 'id' in data
    assert 'password' not in data  # Never return passwords

    # Verify it's actually in the database
    from sqlalchemy import select
    from src.models.user import User

    result = await db_session.execute(
        select(User).where(User.email == payload['email'])
    )
    user = result.scalar_one_or_none()
    assert user is not None
    assert user.name == payload['name']
```

**Pattern:** Test HTTP response AND database state. Always use async/await.

---

### Testing Validation Failures
```python
@pytest.mark.parametrize('payload,expected_field', [
    (
        {'name': 'Test', 'password': 'pass'},
        'email'  # Missing email
    ),
    (
        {'email': 'invalid', 'name': 'Test', 'password': 'pass'},
        'email'  # Invalid format
    ),
    (
        {'email': 'test@example.com', 'name': 'T', 'password': 'pass'},
        'name'  # Too short
    ),
    (
        {'email': 'test@example.com', 'name': 'Test', 'password': 'short'},
        'password'  # Too short
    ),
])
@pytest.mark.asyncio
async def test_create_user_validation_failures(
    client: AsyncClient,
    payload: dict,
    expected_field: str
):
    response = await client.post('/users/', json=payload)
    assert response.status_code == 422  # FastAPI returns 422 for validation
    data = response.json()

    # FastAPI validation errors have 'detail' array
    assert 'detail' in data
    # Check that expected field appears in error locations
    error_fields = [error['loc'][-1] for error in data['detail']]
    assert expected_field in error_fields
```

**Pattern:** Use parametrize to test multiple validation cases. FastAPI returns 422 for validation errors.

---

### Testing Conflict/Error Cases
```python
@pytest.mark.asyncio
async def test_create_user_duplicate_email(client: AsyncClient, db_session: AsyncSession):
    # Create first user
    existing_user = await UserFactory.create(
        db_session,
        email='duplicate@example.com'
    )

    # Try to create another with same email
    payload = {
        'email': 'duplicate@example.com',
        'name': 'Another User',
        'password': 'password123'
    }
    response = await client.post('/users/', json=payload)

    assert response.status_code == 409
    data = response.json()
    assert 'email' in data['detail'].lower()
```

**Pattern:** Set up conflicting state first, then verify proper error handling.

---

## Integration Testing Against Staging

### Environment Setup
```python
# tests/integration/conftest.py
import os
import pytest
import httpx

@pytest.fixture(scope='session')
def staging_url():
    """Get staging URL from environment"""
    url = os.environ.get('STAGING_URL')
    if not url:
        pytest.skip('STAGING_URL not set')
    return url

@pytest.fixture
async def staging_client(staging_url):
    """Async HTTP client configured for staging"""
    async with httpx.AsyncClient(
        base_url=staging_url,
        timeout=30.0,
        headers={'User-Agent': 'Ralph-Integration-Test'}
    ) as client:
        yield client
```

### Staging Tests
```python
@pytest.mark.asyncio
async def test_staging_health_check(staging_client):
    response = await staging_client.get('/health')

    assert response.status_code == 200
    data = response.json()
    assert data['status'] == 'healthy'

@pytest.mark.asyncio
async def test_staging_create_user_flow(staging_client):
    import uuid

    # Create user with unique email
    unique_email = f'test-{uuid.uuid4()}@example.com'
    create_response = await staging_client.post('/users/', json={
        'email': unique_email,
        'name': 'Integration Test User',
        'password': 'testpass123'
    })
    assert create_response.status_code == 201
    user_id = create_response.json()['id']

    # Get user
    get_response = await staging_client.get(f'/users/{user_id}')
    assert get_response.status_code == 200

    # Cleanup: Delete user
    delete_response = await staging_client.delete(f'/users/{user_id}')
    assert delete_response.status_code == 204
```

**Pattern:** Staging tests include cleanup. Use unique identifiers. Always use async with httpx.AsyncClient.

---

## Mocking External Dependencies

### Mocking with pytest-mock
```python
@pytest.mark.asyncio
async def test_send_email_on_user_creation(client, db_session, mocker):
    # Mock external email service
    mock_email = mocker.patch('src.services.email_service.send_email')

    response = await client.post('/users/', json={
        'email': 'test@example.com',
        'name': 'Test User',
        'password': 'password123'
    })

    assert response.status_code == 201
    # Verify email was called
    mock_email.assert_called_once()
    call_args = mock_email.call_args[0]
    assert call_args[0] == 'test@example.com'
```

### Mocking Async Functions
```python
@pytest.mark.asyncio
async def test_external_api_call(mocker):
    # Mock async function
    mock_api = mocker.patch(
        'src.services.external_api.fetch_data',
        new_callable=mocker.AsyncMock
    )
    mock_api.return_value = {'data': 'mocked'}

    from src.services import external_api
    result = await external_api.fetch_data('param')

    assert result == {'data': 'mocked'}
    mock_api.assert_awaited_once_with('param')
```

**Pattern:** Use `mocker.patch` for sync functions, `mocker.AsyncMock` for async functions.

---

## Coverage Patterns

### Running with Coverage
```bash
# Run tests with coverage report
python -m pytest tests/unit/ --cov=src --cov-report=term-missing

# HTML report for detailed view
python -m pytest tests/unit/ --cov=src --cov-report=html
open htmlcov/index.html

# Fail if coverage below threshold
python -m pytest tests/ --cov=src --cov-fail-under=80
```

### Coverage Configuration (pyproject.toml)
```toml
[tool.coverage.run]
source = ["src"]
omit = [
    "*/tests/*",
    "*/migrations/*",
    "*/__pycache__/*",
]

[tool.coverage.report]
precision = 2
show_missing = true
skip_covered = false
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
    "if __name__ == .__main__.:",
    "if TYPE_CHECKING:",
]
```

**Pattern:** Aim for 80%+ coverage on service layer, 90%+ on business logic.

---

## pytest Configuration

### pyproject.toml
```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
python_classes = ["Test*"]
python_functions = ["test_*"]
asyncio_mode = "auto"  # Automatically detect async tests
addopts = [
    "-v",
    "--strict-markers",
    "--tb=short",
]
markers = [
    "integration: Integration tests (run against staging)",
    "unit: Unit tests (fast, isolated)",
]
```

### Running Specific Tests
```bash
# All tests
pytest

# Only unit tests
pytest tests/unit/

# Only integration tests (requires STAGING_URL)
pytest tests/integration/ -m integration

# Specific test file
pytest tests/unit/test_services.py

# Specific test function
pytest tests/unit/test_services.py::test_create_user

# With verbose output
pytest -v

# With debug on failure
pytest --pdb
```

---

## Common Assertions

### Response Structure Helpers
```python
def assert_user_response(data: dict, expected_email: str | None = None):
    """Reusable assertion for user response structure"""
    assert 'id' in data
    assert 'email' in data
    assert 'name' in data
    assert 'status' in data
    assert 'created_at' in data
    assert 'password' not in data
    assert 'password_hash' not in data

    if expected_email:
        assert data['email'] == expected_email

# Usage:
@pytest.mark.asyncio
async def test_get_user(client, test_user):
    response = await client.get(f'/users/{test_user.id}')
    data = response.json()
    assert_user_response(data, expected_email=test_user.email)
```

**Pattern:** Extract common assertions into helpers for consistency and DRY.

---

## Debugging Tests

### Print Debugging
```python
@pytest.mark.asyncio
async def test_something(client):
    response = await client.get('/users/')
    print(f"Status: {response.status_code}")
    print(f"Body: {response.json()}")
    assert response.status_code == 200
```

Run with `-s` flag to see print output:
```bash
pytest tests/test_api.py::test_something -s
```

### PDB Debugging
```python
@pytest.mark.asyncio
async def test_something(client):
    response = await client.get('/users/')
    import pdb; pdb.set_trace()  # Debugger stops here
    assert response.status_code == 200
```

Or run with `--pdb` to auto-break on failures:
```bash
pytest --pdb
```

**Pattern:** Use print for quick checks, pdb for interactive debugging.
