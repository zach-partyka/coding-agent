# Testing Patterns for Node.js/TypeScript (Playwright)

## Test Organization

### Directory Structure
```
tests/
  api/
    users.spec.ts       # API endpoint tests
    auth.spec.ts        # Authentication tests
  ui/
    login.spec.ts       # UI flow tests
    dashboard.spec.ts   # UI component tests
  fixtures/
    testData.ts         # Shared test data
    helpers.ts          # Test helper functions
  global-setup.ts       # Global test setup
  global-teardown.ts    # Global test cleanup
```

**Pattern:** Organize by feature area (api/, ui/). Playwright handles both API and browser testing.

---

## Playwright Configuration

### playwright.config.ts
```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,

  use: {
    baseURL: process.env.STAGING_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: process.env.STAGING_URL ? undefined : {
    command: 'npm run dev',
    url: 'http://localhost:3000/health',
    reuseExistingServer: !process.env.CI,
  },
});
```

---

## API Testing

### Basic API Test
```typescript
import { test, expect } from '@playwright/test';

test('get user by id', async ({ request }) => {
  const response = await request.get('/api/users/123');

  expect(response.status()).toBe(200);

  const user = await response.json();
  expect(user).toMatchObject({
    id: 123,
    email: expect.any(String),
    name: expect.any(String),
  });
});
```

### Testing POST Requests
```typescript
test('create user', async ({ request }) => {
  const response = await request.post('/api/users', {
    data: {
      email: 'test@example.com',
      name: 'Test User',
      password: 'password123',
    },
  });

  expect(response.status()).toBe(201);

  const user = await response.json();
  expect(user.id).toBeDefined();
  expect(user.email).toBe('test@example.com');
  expect(user).not.toHaveProperty('password');  // Never return passwords
});
```

### Testing Validation Errors
```typescript
test('create user with invalid data', async ({ request }) => {
  const response = await request.post('/api/users', {
    data: {
      email: 'invalid-email',  // Invalid format
      name: 'T',  // Too short
    },
  });

  expect(response.status()).toBe(400);

  const error = await response.json();
  expect(error.error).toBe('Validation failed');
  expect(error.details).toEqual(
    expect.arrayContaining([
      expect.objectContaining({ path: ['email'] }),
      expect.objectContaining({ path: ['name'] }),
    ])
  );
});
```

---

## UI Testing

### Page Navigation
```typescript
test('navigate to user profile', async ({ page }) => {
  await page.goto('/');
  await page.click('text=Profile');
  await expect(page).toHaveURL('/profile');
  await expect(page.locator('h1')).toContainText('Your Profile');
});
```

### Form Submission
```typescript
test('submit login form', async ({ page }) => {
  await page.goto('/login');

  // Fill form
  await page.fill('input[name="email"]', 'user@example.com');
  await page.fill('input[name="password"]', 'password123');

  // Submit
  await page.click('button[type="submit"]');

  // Verify redirect
  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('text=Welcome')).toBeVisible();
});
```

### Testing UI Elements
```typescript
test('display user information', async ({ page }) => {
  await page.goto('/profile');

  // Wait for data to load
  await page.waitForSelector('[data-testid="user-name"]');

  // Check content
  await expect(page.locator('[data-testid="user-name"]')).toContainText('John Doe');
  await expect(page.locator('[data-testid="user-email"]')).toContainText('john@example.com');
});
```

---

## Fixtures and Helpers

### Custom Fixtures
```typescript
// tests/fixtures/auth.ts
import { test as base } from '@playwright/test';

type AuthFixtures = {
  authenticatedPage: Page;
};

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    // Setup: Login before test
    await page.goto('/login');
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');
    await page.waitForURL('/dashboard');

    // Use authenticated page in test
    await use(page);

    // Teardown: Logout after test
    await page.click('text=Logout');
  },
});

// Usage:
import { test } from './fixtures/auth';

test('access protected page', async ({ authenticatedPage }) => {
  await authenticatedPage.goto('/admin');
  await expect(authenticatedPage).toHaveURL('/admin');
});
```

### Test Data Factories
```typescript
// tests/fixtures/testData.ts
import { faker } from '@faker-js/faker';

export function createUserData(overrides = {}) {
  return {
    email: faker.internet.email(),
    name: faker.person.fullName(),
    password: 'password123',
    ...overrides,
  };
}

// Usage:
test('create multiple users', async ({ request }) => {
  const user1 = createUserData({ name: 'Alice' });
  const user2 = createUserData({ name: 'Bob' });

  await request.post('/api/users', { data: user1 });
  await request.post('/api/users', { data: user2 });

  // Both have unique emails but specified names
});
```

---

## Testing Against Staging

### Environment-Based Tests
```typescript
import { test, expect } from '@playwright/test';

const isStaging = !!process.env.STAGING_URL;

test('health check', async ({ request }) => {
  const response = await request.get('/health');

  expect(response.status()).toBe(200);

  const health = await response.json();
  expect(health.status).toBe('healthy');

  if (isStaging) {
    // Additional staging-specific checks
    expect(health.version).toBeDefined();
  }
});
```

### Staging-Specific Test Suite
```typescript
// tests/staging/smoke.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Staging Smoke Tests', () => {
  test.skip(!process.env.STAGING_URL, 'Only run against staging');

  test('staging is accessible', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('h1')).toBeVisible();
  });

  test('staging health check', async ({ request }) => {
    const response = await request.get('/health');
    expect(response.status()).toBe(200);
  });
});
```

---

## Test Hooks and Setup

### Before/After Hooks
```typescript
import { test, expect } from '@playwright/test';

test.describe('User Management', () => {
  let testUserId: number;

  test.beforeAll(async ({ request }) => {
    // Create test user once for all tests in this suite
    const response = await request.post('/api/users', {
      data: createUserData(),
    });
    const user = await response.json();
    testUserId = user.id;
  });

  test.afterAll(async ({ request }) => {
    // Cleanup test user
    await request.delete(`/api/users/${testUserId}`);
  });

  test.beforeEach(async ({ page }) => {
    // Run before each test in this suite
    await page.goto('/users');
  });

  test('view user details', async ({ page }) => {
    await page.click(`text=User ${testUserId}`);
    await expect(page).toHaveURL(`/users/${testUserId}`);
  });
});
```

### Global Setup/Teardown
```typescript
// tests/global-setup.ts
import { FullConfig } from '@playwright/test';

async function globalSetup(config: FullConfig) {
  // Setup database, seed data, etc.
  console.log('Running global setup...');

  // Example: Create admin user for all tests
  const baseURL = config.projects[0].use.baseURL;
  const response = await fetch(`${baseURL}/api/setup/admin`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@test.com', password: 'admin123' }),
  });

  if (!response.ok) {
    throw new Error('Failed to setup admin user');
  }
}

export default globalSetup;

// Register in playwright.config.ts:
// globalSetup: './tests/global-setup.ts',
```

---

## Debugging Tests

### Running Tests
```bash
# All tests
npx playwright test

# Specific file
npx playwright test tests/api/users.spec.ts

# Specific test
npx playwright test -g "create user"

# With UI mode (interactive)
npx playwright test --ui

# Headed mode (see browser)
npx playwright test --headed

# Debug mode (step through)
npx playwright test --debug

# Show report
npx playwright show-report
```

### Debug Tools
```typescript
test('debug example', async ({ page }) => {
  await page.goto('/');

  // Pause execution (opens inspector)
  await page.pause();

  // Take screenshot
  await page.screenshot({ path: 'screenshot.png' });

  // Console logging
  page.on('console', msg => console.log('PAGE LOG:', msg.text()));

  await page.click('button');
});
```

---

## Assertions

### Common Assertions
```typescript
// Status codes
expect(response.status()).toBe(200);
expect(response.ok()).toBeTruthy();

// JSON response
const data = await response.json();
expect(data).toEqual({ id: 123, name: 'Test' });
expect(data).toMatchObject({ id: expect.any(Number) });
expect(data).toHaveProperty('id');

// Page content
await expect(page.locator('h1')).toContainText('Welcome');
await expect(page.locator('button')).toBeVisible();
await expect(page.locator('input')).toBeEnabled();
await expect(page).toHaveURL('/dashboard');
await expect(page).toHaveTitle('Dashboard');

// Element state
await expect(page.locator('.error')).toBeHidden();
await expect(page.locator('.success')).toBeVisible();
await expect(page.locator('input')).toHaveValue('test@example.com');
```

### Custom Matchers
```typescript
// tests/fixtures/matchers.ts
import { expect } from '@playwright/test';

expect.extend({
  toBeValidEmail(received: string) {
    const pass = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(received);
    return {
      message: () => `expected ${received} to be a valid email`,
      pass,
    };
  },
});

// Usage:
test('validate email format', async ({ request }) => {
  const response = await request.get('/api/users/123');
  const user = await response.json();
  expect(user.email).toBeValidEmail();
});
```

---

## Performance Testing

### Response Time Assertions
```typescript
test('API responds within acceptable time', async ({ request }) => {
  const start = Date.now();

  await request.get('/api/users');

  const duration = Date.now() - start;
  expect(duration).toBeLessThan(500);  // Under 500ms
});
```

### Page Load Performance
```typescript
test('page loads quickly', async ({ page }) => {
  const start = Date.now();

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  const duration = Date.now() - start;
  expect(duration).toBeLessThan(3000);  // Under 3 seconds
});
```

---

## Common Patterns

### Wait Strategies
```typescript
// Wait for specific element
await page.waitForSelector('[data-testid="user-list"]');

// Wait for network to be idle
await page.waitForLoadState('networkidle');

// Wait for specific URL
await page.waitForURL('/dashboard');

// Wait for specific condition
await page.waitForFunction(() => document.querySelectorAll('.item').length > 5);

// Custom timeout
await page.waitForSelector('.slow-element', { timeout: 10000 });
```

### Handling Dynamic Content
```typescript
test('handle loading states', async ({ page }) => {
  await page.goto('/users');

  // Wait for loading spinner to disappear
  await expect(page.locator('.loading')).toBeHidden();

  // Now check content
  await expect(page.locator('.user-list')).toBeVisible();
  await expect(page.locator('.user-item')).toHaveCount(10);
});
```

---

## CI/CD Integration

### GitHub Actions Example
```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright
        run: npx playwright install --with-deps

      - name: Run tests
        run: npx playwright test
        env:
          STAGING_URL: ${{ secrets.STAGING_URL }}

      - name: Upload test results
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/
```

**Pattern:** Run against staging URL in CI, use artifacts for debugging failures.
