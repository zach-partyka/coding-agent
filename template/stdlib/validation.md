# Validation Patterns

## Schema as Single Source of Truth

Define shared schemas that produce both types and runtime validation. One definition, two benefits.

### Zod (TypeScript)

```typescript
import { z } from "zod";

export const resourceSchema = z.object({
  id: z.number(),
  title: z.string().nullable(),
  status: z.string().default("draft"),
  createdAt: z.string(),
  updatedAt: z.string()
});

export type Resource = z.infer<typeof resourceSchema>;
```

### Pydantic (Python)

```python
from pydantic import BaseModel
from typing import Optional

class Resource(BaseModel):
    id: int
    title: Optional[str]
    status: str = "draft"
    created_at: str
    updated_at: str
```

**Why:** Single source of truth for types, runtime validation catches bad data at boundaries, nullable/optional fields are explicit.

## Adding Optional Fields (Safe)

```typescript
export const resourceSchema = z.object({
  // existing fields...
  newField: z.string().optional()  // ✅ Backwards compatible
});
```

Optional fields don't break existing data or API calls.

## Adding Required Fields (Requires Migration)

```typescript
// ❌ DON'T DO THIS without database migration
newField: z.string()  // Breaks existing records without this field

// ✅ DO THIS instead
newField: z.string().default("default_value")
```

Required fields without defaults break existing records. Always provide a default or make the field optional, then backfill.

## Validate at Boundaries

```typescript
// ✅ Validate request bodies before database operations
const validated = resourceSchema.parse(req.body);
await db.insert(validated);

// ✅ Validate API responses before using them
const data = externalApiSchema.parse(response.data);
```

Validate at:
- **Inbound:** Request bodies, query params, form data
- **Outbound:** External API responses, database query results (if schema may drift)
- **Never:** Internal function calls between trusted modules (trust your types)

## Timestamps: Know Your Database

Some databases return timestamps as strings (ISO 8601), others as Date objects. Match your schema to what the database actually returns.

```typescript
// If your DB returns strings (common with SQL-over-HTTP, Databricks, etc.)
createdAt: z.string()

// If your DB returns Date objects (common with ORMs like Prisma, Drizzle)
createdAt: z.date()
```

Check once, document in this file, and use consistently.

## Path Aliases (Must Stay Synced)

If you use path aliases (e.g. `@shared/*`), they must be defined in **both** your TypeScript config and your bundler config:

```
tsconfig.json:   "@shared/*": ["shared/*"]
vite.config.ts:  "@shared": path.resolve(__dirname, "./shared")
```

If one is updated without the other, imports break silently or at build time.

## Common Mistakes

- Using `Date` type when the database returns strings (or vice versa)
- Adding required fields without defaults (breaks existing data)
- Not using `.nullable()` or `.optional()` appropriately
- Breaking shared type sync between frontend and backend
- Validating inside trusted internal functions (unnecessary overhead)
