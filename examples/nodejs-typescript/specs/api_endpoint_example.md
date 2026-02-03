# Spec: API Endpoint Example (Express + TypeScript)

## Overview
Example specification for a REST API endpoint using Express and TypeScript.

## Endpoint

### GET /api/items/:id
**Purpose:** Retrieve a single item by ID

**Path Parameters:**
- `id` (string): Item identifier

**Response:** 200 OK
```json
{
  "id": "abc123",
  "name": "Example Item",
  "description": "An example item",
  "createdAt": "2026-01-01T00:00:00Z",
  "updatedAt": "2026-01-15T10:30:00Z"
}
```

**Errors:**
- 400 Bad Request: Invalid ID format
- 404 Not Found: Item doesn't exist
- 500 Internal Server Error: Server error

---

### POST /api/items
**Purpose:** Create a new item

**Request Body:**
```json
{
  "name": "New Item",
  "description": "Description of the new item"
}
```

**Validation (Zod Schema):**
```typescript
import { z } from 'zod';

export const ItemCreateSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
});
```

**Response:** 201 Created
```json
{
  "id": "abc124",
  "name": "New Item",
  "description": "Description of the new item",
  "createdAt": "2026-01-20T14:30:00Z",
  "updatedAt": "2026-01-20T14:30:00Z"
}
```

**Errors:**
- 400 Bad Request: Validation failed (includes field-specific errors)
- 500 Internal Server Error: Server error

---

## Implementation Notes

### Database Schema
```typescript
// Using Drizzle ORM
import { pgTable, text, timestamp, uuid } from 'drizzle-orm/pg-core';

export const items = pgTable('items', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  description: text('description'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at').defaultNow().notNull(),
});
```

### Route Implementation
```typescript
// server/routes.ts
import express from 'express';
import { z } from 'zod';
import { db } from './db';
import { items } from './schema';
import { eq } from 'drizzle-orm';

const router = express.Router();

// GET /api/items/:id
router.get('/api/items/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const item = await db.query.items.findFirst({
      where: eq(items.id, id),
    });

    if (!item) {
      return res.status(404).json({ error: 'Item not found' });
    }

    res.json(item);
  } catch (error) {
    console.error('Error fetching item:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /api/items
router.post('/api/items', async (req, res) => {
  try {
    // Validate request body
    const data = ItemCreateSchema.parse(req.body);

    // Insert into database
    const [newItem] = await db.insert(items)
      .values(data)
      .returning();

    res.status(201).json(newItem);
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ error: 'Validation failed', details: error.errors });
    }
    console.error('Error creating item:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;
```

### Testing
```typescript
// tests/items.spec.ts
import { test, expect } from '@playwright/test';

test('get item by id', async ({ request }) => {
  // Arrange: Create test item
  const createResponse = await request.post('/api/items', {
    data: { name: 'Test Item', description: 'Test description' }
  });
  const { id } = await createResponse.json();

  // Act: Fetch item
  const response = await request.get(`/api/items/${id}`);

  // Assert
  expect(response.status()).toBe(200);
  const item = await response.json();
  expect(item.id).toBe(id);
  expect(item.name).toBe('Test Item');
});

test('create item with validation', async ({ request }) => {
  // Act: Create item with invalid data
  const response = await request.post('/api/items', {
    data: { name: '' }  // Empty name should fail
  });

  // Assert
  expect(response.status()).toBe(400);
  const error = await response.json();
  expect(error.error).toBe('Validation failed');
});
```

---

## Error Response Format

All errors should return consistent JSON structure:
```json
{
  "error": "Brief error message",
  "details": {}  // Optional: additional error details
}
```

For validation errors:
```json
{
  "error": "Validation failed",
  "details": [
    {
      "path": ["name"],
      "message": "String must contain at least 1 character(s)"
    }
  ]
}
```
