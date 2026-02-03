# Express + TypeScript Patterns

## Route Organization

### Single Routes File
```typescript
// server/routes.ts
import express from 'express';
import { db } from './db';
import { validateRequest } from './middleware/validation';
import { UserCreateSchema } from '@shared/schema';

const app = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/api/users/:id', async (req, res) => {
  try {
    const user = await db.query.users.findFirst({
      where: eq(users.id, parseInt(req.params.id))
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json(user);
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/users', validateRequest(UserCreateSchema), async (req, res) => {
  try {
    const [user] = await db.insert(users).values(req.body).returning();
    res.status(201).json(user);
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default app;
```

**Pattern:** For small/medium apps, single routes file is simpler. For larger apps, split into route modules.

### Modular Routes (for larger apps)
```typescript
// server/routes/users.ts
import { Router } from 'express';
import * as userController from '../controllers/userController';

const router = Router();

router.get('/:id', userController.getUser);
router.post('/', userController.createUser);
router.patch('/:id', userController.updateUser);

export default router;

// server/routes.ts
import express from 'express';
import userRoutes from './routes/users';
import authRoutes from './routes/auth';

const app = express();

app.use('/api/users', userRoutes);
app.use('/api/auth', authRoutes);

export default app;
```

---

## Request Validation with Zod

### Defining Schemas
```typescript
// shared/schema.ts
import { z } from 'zod';

export const UserCreateSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  password: z.string().min(8),
});

export const UserUpdateSchema = z.object({
  email: z.string().email().optional(),
  name: z.string().min(2).max(100).optional(),
  status: z.enum(['active', 'inactive', 'suspended']).optional(),
});

export type UserCreate = z.infer<typeof UserCreateSchema>;
export type UserUpdate = z.infer<typeof UserUpdateSchema>;
```

### Validation Middleware
```typescript
// server/middleware/validation.ts
import { Request, Response, NextFunction } from 'express';
import { z, ZodSchema } from 'zod';

export function validateRequest(schema: ZodSchema) {
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

// Usage:
app.post('/api/users', validateRequest(UserCreateSchema), async (req, res) => {
  // req.body is now typed and validated
  const user = req.body; // type: UserCreate
  // ...
});
```

---

## Error Handling

### Error Handler Middleware
```typescript
// server/middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';

export class APIError extends Error {
  constructor(
    public statusCode: number,
    public message: string,
    public details?: any
  ) {
    super(message);
    this.name = 'APIError';
  }
}

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  if (err instanceof APIError) {
    return res.status(err.statusCode).json({
      error: err.message,
      details: err.details
    });
  }

  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
}

// Register at the end of middleware chain:
app.use(errorHandler);

// Usage in routes:
if (!user) {
  throw new APIError(404, 'User not found');
}
```

### Async Error Wrapper
```typescript
// server/middleware/asyncHandler.ts
import { Request, Response, NextFunction } from 'express';

export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// Usage (eliminates try/catch):
app.get('/api/users/:id', asyncHandler(async (req, res) => {
  const user = await db.query.users.findFirst({
    where: eq(users.id, parseInt(req.params.id))
  });

  if (!user) {
    throw new APIError(404, 'User not found');
  }

  res.json(user);
}));
```

---

## Database Patterns (Drizzle ORM)

### Schema Definition
```typescript
// shared/schema.ts
import { pgTable, text, timestamp, integer, index } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: integer('id').primaryKey().generatedAlwaysAsIdentity(),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  passwordHash: text('password_hash').notNull(),
  status: text('status', { enum: ['active', 'inactive', 'suspended', 'deleted'] })
    .notNull()
    .default('active'),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('created_at').defaultNow().notNull(),
}, (table) => ({
  emailIdx: index('email_idx').on(table.email),
  statusIdx: index('status_idx').on(table.status),
}));
```

### Database Connection
```typescript
// server/db.ts
import { drizzle } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from '@shared/schema';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export const db = drizzle(pool, { schema });
```

### Query Patterns
```typescript
import { db } from './db';
import { users } from '@shared/schema';
import { eq, and, desc } from 'drizzle-orm';

// Select single
const user = await db.query.users.findFirst({
  where: eq(users.id, userId)
});

// Select multiple with conditions
const activeUsers = await db.query.users.findMany({
  where: eq(users.status, 'active'),
  orderBy: desc(users.createdAt),
  limit: 50,
  offset: 0,
});

// Insert
const [newUser] = await db.insert(users)
  .values({
    email: 'test@example.com',
    name: 'Test User',
    passwordHash: hashedPassword,
  })
  .returning();

// Update
const [updatedUser] = await db.update(users)
  .set({ name: 'New Name' })
  .where(eq(users.id, userId))
  .returning();

// Delete
await db.delete(users)
  .where(eq(users.id, userId));
```

---

## Middleware Patterns

### Authentication Middleware
```typescript
// server/middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt';

export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const payload = verifyToken(token);
    (req as any).user = payload;  // Attach user to request
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
}

// Usage:
app.get('/api/profile', requireAuth, async (req, res) => {
  const userId = (req as any).user.id;
  // ...
});
```

### Request Logging
```typescript
// server/middleware/logger.ts
import { Request, Response, NextFunction } from 'express';

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`${req.method} ${req.path} ${res.statusCode} ${duration}ms`);
  });

  next();
}

// Register early:
app.use(requestLogger);
```

---

## TypeScript Type Safety

### Typed Request/Response
```typescript
// server/types.ts
import { Request, Response } from 'express';
import { User } from '@shared/schema';

export interface AuthRequest extends Request {
  user?: User;
}

export type TypedResponse<T> = Response<T | { error: string }>;

// Usage:
app.get('/api/profile', async (req: AuthRequest, res: TypedResponse<User>) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  res.json(req.user);
});
```

### Path Aliases
```typescript
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["client/src/*"],
      "@shared/*": ["shared/*"],
      "@server/*": ["server/*"]
    }
  }
}

// Usage:
import { UserSchema } from '@shared/schema';
import { db } from '@server/db';
import { Button } from '@/components/Button';
```

---

## Configuration

### Environment Variables
```typescript
// server/config.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().transform(Number).default('3000'),
  DATABASE_URL: z.string(),
  JWT_SECRET: z.string().min(32),
  SESSION_SECRET: z.string().min(32),
});

export const config = envSchema.parse(process.env);

// Usage:
const port = config.PORT;
```

**Pattern:** Validate env vars at startup with Zod. Fail fast if configuration is invalid.

---

## CORS Configuration

```typescript
import cors from 'cors';

app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? ['https://app.yourdomain.com', 'https://*.zgtools.net']
    : true,  // Allow all origins in development
  credentials: true,
}));
```

---

## API Response Patterns

### Consistent Success Responses
```typescript
// server/utils/response.ts
import { Response } from 'express';

export function success<T>(res: Response, data: T, statusCode = 200) {
  res.status(statusCode).json(data);
}

export function created<T>(res: Response, data: T) {
  res.status(201).json(data);
}

export function noContent(res: Response) {
  res.status(204).send();
}

// Usage:
app.get('/api/users/:id', async (req, res) => {
  const user = await getUser(req.params.id);
  success(res, user);
});

app.post('/api/users', async (req, res) => {
  const user = await createUser(req.body);
  created(res, user);
});

app.delete('/api/users/:id', async (req, res) => {
  await deleteUser(req.params.id);
  noContent(res);
});
```
