# Spec: User API Endpoints (FastAPI)

## Overview
RESTful API endpoints for user management with full CRUD operations, built with FastAPI.

## Endpoints

### GET /users
**Purpose:** List all users with optional filtering and pagination

**Query Parameters:**
- `limit` (optional, int, default: 50, max: 500): Max users to return
- `offset` (optional, int, default: 0): Pagination offset
- `status` (optional, string): Filter by user status (active|inactive|suspended)

**Response:** 200 OK
```json
{
  "users": [
    {
      "id": 123,
      "email": "user@example.com",
      "name": "John Doe",
      "status": "active",
      "created_at": "2026-01-01T00:00:00Z"
    }
  ],
  "total": 150,
  "limit": 50,
  "offset": 0
}
```

**Errors:**
- 422 Unprocessable Entity: Invalid query parameters (FastAPI automatic validation)

---

### GET /users/{id}
**Purpose:** Get single user by ID

**Path Parameters:**
- `id` (int): User ID

**Response:** 200 OK
```json
{
  "id": 123,
  "email": "user@example.com",
  "name": "John Doe",
  "status": "active",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-15T10:30:00Z"
}
```

**Errors:**
- 404 Not Found: User doesn't exist
- 422 Unprocessable Entity: Invalid ID format

---

### POST /users
**Purpose:** Create new user

**Request Body:**
```json
{
  "email": "newuser@example.com",
  "name": "Jane Smith",
  "password": "securepassword123"
}
```

**Pydantic Schema (Validation):**
```python
class UserCreate(BaseModel):
    email: EmailStr  # Pydantic validates email format
    name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=8, regex="^(?=.*[A-Za-z])(?=.*\\d).+$")
```

**Validation Rules:**
- `email`: Required, valid email format (Pydantic `EmailStr`), unique
- `name`: Required, 2-100 characters
- `password`: Required, min 8 characters, must include letter + number

**Response:** 201 Created
```json
{
  "id": 124,
  "email": "newuser@example.com",
  "name": "Jane Smith",
  "status": "active",
  "created_at": "2026-01-20T14:30:00Z"
}
```

**Errors:**
- 422 Unprocessable Entity: Validation failed (FastAPI automatic, includes field details)
- 409 Conflict: Email already exists

---

### PATCH /users/{id}
**Purpose:** Update existing user (partial update)

**Path Parameters:**
- `id` (int): User ID

**Request Body:** (all fields optional)
```json
{
  "name": "Jane Doe",
  "status": "inactive"
}
```

**Pydantic Schema:**
```python
class UserUpdate(BaseModel):
    email: EmailStr | None = None
    name: str | None = Field(None, min_length=2, max_length=100)
    status: Literal["active", "inactive", "suspended"] | None = None
```

**Response:** 200 OK (updated user object)

**Errors:**
- 422 Unprocessable Entity: Validation failed
- 404 Not Found: User doesn't exist
- 409 Conflict: Email already taken

---

### DELETE /users/{id}
**Purpose:** Soft-delete user (set status to deleted, retain data)

**Path Parameters:**
- `id` (int): User ID

**Query Parameters:**
- `hard_delete` (optional, bool, default: false): If true, permanently delete record

**Response:** 204 No Content

**Errors:**
- 404 Not Found: User doesn't exist

**Note:** Default is soft delete - user record remains in DB with `status='deleted'`. For hard delete (GDPR compliance), use `DELETE /users/{id}?hard_delete=true`

---

## Implementation Notes

### Database Schema (SQLAlchemy 2.0 Async)
```python
from sqlalchemy import Column, Integer, String, Enum, DateTime, Index
from sqlalchemy.sql import func
from src.models.database import Base

class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    name = Column(String(100), nullable=False)
    password_hash = Column(String(255), nullable=False)
    status = Column(
        Enum('active', 'inactive', 'suspended', 'deleted', name='user_status'),
        default='active',
        nullable=False
    )
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False
    )

    # Composite index for common query pattern
    __table_args__ = (
        Index('idx_status_created', 'status', 'created_at'),
    )
```

### Pydantic Schemas
```python
from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Literal

class UserBase(BaseModel):
    email: EmailStr
    name: str = Field(..., min_length=2, max_length=100)

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    email: EmailStr | None = None
    name: str | None = Field(None, min_length=2, max_length=100)
    status: Literal["active", "inactive", "suspended"] | None = None

class UserResponse(UserBase):
    id: int
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}  # Allows conversion from ORM

class UserListResponse(BaseModel):
    users: list[UserResponse]
    total: int
    limit: int
    offset: int
```

### Security
- Passwords must be hashed with `passlib[bcrypt]` before storage
- Never return `password_hash` in API responses (excluded from Pydantic schema)
- Email lookups should be case-insensitive (normalize to lowercase in service layer)
- Use FastAPI's `Depends()` for authentication (future requirement)

### Pagination Helper
```python
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

async def paginate_query(
    db: AsyncSession,
    query: select,
    limit: int = 50,
    offset: int = 0
) -> dict:
    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()

    # Get paginated items
    paginated_query = query.limit(limit).offset(offset)
    result = await db.execute(paginated_query)
    items = result.scalars().all()

    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset
    }
```

### Testing
Integration tests must cover:
1. Happy path for each endpoint
2. Validation failures (FastAPI handles automatically but verify error format)
3. Conflict cases (duplicate email)
4. Edge cases (empty list, pagination boundaries, max limit enforcement)
5. Authentication (when auth is added)

### Error Response Format
FastAPI automatically returns validation errors in this format:
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "value is not a valid email address",
      "type": "value_error.email"
    },
    {
      "loc": ["body", "password"],
      "msg": "ensure this value has at least 8 characters",
      "type": "value_error.any_str.min_length"
    }
  ]
}
```

For custom errors, use:
```python
from fastapi import HTTPException

raise HTTPException(status_code=409, detail="Email already exists")
```

---

## Automatic API Documentation

FastAPI automatically generates interactive API docs:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

All endpoints, schemas, and validation rules are documented automatically based on type hints and Pydantic models. No additional work needed.
