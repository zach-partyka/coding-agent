# FastAPI Patterns

## Router Organization

### Router Structure
```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from src.api.dependencies import get_db
from src.schemas.user import UserCreate, UserResponse
from src.services import user_service

router = APIRouter(
    prefix="/users",
    tags=["users"],
    responses={404: {"description": "Not found"}}
)

@router.get("/", response_model=list[UserResponse])
async def list_users(
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db)
):
    return await user_service.list_users(db, limit=limit, offset=offset)

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

**Pattern:** Group related routes in routers. Register in main app:
```python
from fastapi import FastAPI
from src.api.routers import users, auth

app = FastAPI(title="My API", version="1.0.0")
app.include_router(users.router)
app.include_router(auth.router)
```

---

## Error Handling

### Custom Exception Classes
```python
class APIError(Exception):
    """Base API error"""
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail

class NotFoundError(APIError):
    def __init__(self, detail: str = "Resource not found"):
        super().__init__(status_code=404, detail=detail)

class ConflictError(APIError):
    def __init__(self, detail: str = "Resource already exists"):
        super().__init__(status_code=409, detail=detail)
```

### Exception Handler Registration
```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI()

@app.exception_handler(APIError)
async def api_error_handler(request: Request, exc: APIError):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )

@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    return JSONResponse(
        status_code=404,
        content={"detail": "Resource not found"}
    )

@app.exception_handler(500)
async def internal_error_handler(request: Request, exc):
    # Log for debugging
    logger.error(f"Internal error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )
```

**Pattern:** Raise custom exceptions in business logic, let FastAPI exception handlers convert to HTTP responses.

---

## Request Validation with Pydantic

### Defining Schemas
```python
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Literal

class UserCreate(BaseModel):
    email: EmailStr  # Automatic email validation
    name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=8)

    @validator('password')
    def password_strength(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isalpha() for char in v):
            raise ValueError('Password must contain at least one letter')
        return v

class UserUpdate(BaseModel):
    email: EmailStr | None = None
    name: str | None = Field(None, min_length=2, max_length=100)
    status: Literal["active", "inactive", "suspended"] | None = None
```

### Using Schemas in Routes
```python
@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    user_data: UserCreate,  # Pydantic automatically validates
    db: AsyncSession = Depends(get_db)
):
    # user_data is already validated
    user = await user_service.create_user(db, user_data)
    return user
```

**Pattern:** FastAPI validates request body automatically. No decorator needed - just type hint the parameter.

---

## Database Patterns (Async SQLAlchemy 2.0)

### Session Management
```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from src.core.config import settings

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True
)

async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

async def get_db() -> AsyncSession:
    async with async_session_maker() as session:
        yield session
```

### Query Patterns
```python
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.user import User

# Get single record
async def get_user(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()

# Get multiple records
async def list_users(
    db: AsyncSession,
    limit: int = 50,
    offset: int = 0,
    status: str | None = None
) -> list[User]:
    query = select(User)
    if status:
        query = query.where(User.status == status)
    query = query.limit(limit).offset(offset)

    result = await db.execute(query)
    return result.scalars().all()

# Create record
async def create_user(db: AsyncSession, user_data: UserCreate) -> User:
    user = User(**user_data.model_dump(exclude={'password'}))
    user.password_hash = hash_password(user_data.password)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user

# Update record
async def update_user(
    db: AsyncSession,
    user_id: int,
    user_data: UserUpdate
) -> User:
    user = await get_user(db, user_id)
    if not user:
        raise NotFoundError("User not found")

    for field, value in user_data.model_dump(exclude_unset=True).items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)
    return user
```

**Pattern:** Always use async/await, use `select()` syntax (not Query), yield sessions from dependency.

---

## Dependency Injection

### Common Dependencies
```python
# src/api/dependencies.py
from typing import Annotated
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.database import async_session_maker
from src.core.security import decode_jwt

security = HTTPBearer()

async def get_db() -> AsyncSession:
    async with async_session_maker() as session:
        yield session

async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: Annotated[AsyncSession, Depends(get_db)]
) -> User:
    token = credentials.credentials
    user_id = decode_jwt(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await user_service.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return user

# Type alias for cleaner syntax
CurrentUser = Annotated[User, Depends(get_current_user)]
```

### Using Dependencies
```python
@router.get("/me", response_model=UserResponse)
async def get_current_user_endpoint(current_user: CurrentUser):
    # current_user is automatically injected and authenticated
    return current_user

@router.post("/posts")
async def create_post(
    post_data: PostCreate,
    current_user: CurrentUser,
    db: Annotated[AsyncSession, Depends(get_db)]
):
    return await post_service.create_post(db, post_data, current_user.id)
```

**Pattern:** Use `Annotated` for reusable dependency combinations. Dependencies are resolved automatically.

---

## Service Layer Pattern

### Separation of Concerns
```python
# src/api/routers/users.py - Handle HTTP concerns
@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    user = await user_service.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# src/services/user_service.py - Business logic
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.models.user import User

async def get_user(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    # Business logic: Don't return deleted users
    if user and user.status == 'deleted':
        return None

    return user

# src/models/user.py - Data representation
from sqlalchemy import Column, Integer, String
from src.models.database import Base

class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    email = Column(String, nullable=False, unique=True)
    name = Column(String, nullable=False)
    # ...
```

**Pattern:** Routes handle HTTP, services handle business logic, models handle data. Keep layers clean.

---

## Configuration Management

### Settings with Pydantic
```python
# src/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # Database
    DATABASE_URL: str

    # Security
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # App
    DEBUG: bool = False
    API_TITLE: str = "My API"
    API_VERSION: str = "1.0.0"

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
```

### App Factory with Settings
```python
# src/main.py
from fastapi import FastAPI
from src.core.config import settings
from src.api.routers import users, auth

def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.API_TITLE,
        version=settings.API_VERSION,
        debug=settings.DEBUG
    )

    # Register routers
    app.include_router(users.router)
    app.include_router(auth.router)

    return app

app = create_app()
```

**Pattern:** Environment-based config with Pydantic validation, type safety guaranteed.

---

## Background Tasks

### Using BackgroundTasks
```python
from fastapi import BackgroundTasks

def send_email(email: str, message: str):
    # Expensive email sending operation
    time.sleep(3)
    print(f"Email sent to {email}")

@router.post("/users/", status_code=201)
async def create_user(
    user_data: UserCreate,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    user = await user_service.create_user(db, user_data)

    # Send welcome email in background
    background_tasks.add_task(send_email, user.email, "Welcome!")

    return user
```

**Pattern:** Use `BackgroundTasks` for quick operations after response. For longer tasks, use Celery or similar.

---

## Middleware

### Custom Middleware
```python
from fastapi import FastAPI, Request
import time

@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response
```

### CORS Middleware
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://*.zgtools.net"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Pattern:** Middleware runs on every request. Use for logging, timing, CORS, etc.
