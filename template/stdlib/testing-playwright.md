# Testing Patterns (Playwright E2E)

Codified from 10+ sprints of Ralph development learnings.

---

## Test Selector Priority

**Problem:** Broad CSS selectors match unintended elements, causing strict mode violations or wrong element assertions.

**Selector priority (prefer top → bottom):**

1. **`data-testid` attributes** — Most robust, explicit

```typescript
await page.locator('[data-testid="section-card-overview"]')
```

2. **Role-based selectors** — Semantic, accessible

```typescript
await page.getByRole('button', { name: 'Save' })
await page.getByRole('heading', { name: 'Overview' })
```

3. **Label-based selectors** — Good for form inputs

```typescript
await page.getByLabel('Campaign Name').fill('Q1 Campaign')
```

4. **Text content** — Fragile if copy changes

```typescript
await page.getByText('Exact button text')
```

5. **Class names** — Last resort, very brittle

```typescript
// ❌ AVOID: Broad patterns match unintended elements
await page.locator('[class*="border-blue"]')

// ❌ AVOID: Utility classes change frequently
await page.locator('.rounded-lg.border-2')
```

**Generated IDs — NEVER USE:**

```typescript
// ❌ NEVER: Component libraries generate random IDs per render
await page.locator('#\\:rg\\:')
```

**Responsive design — Handle duplicates:**

```typescript
// ❌ PROBLEM: Desktop + mobile = 2 elements, strict mode fails
await page.locator('.section-card').click()

// ✅ SOLUTION: Use .first() or screen-size specific selector
await page.locator('.section-card').first().click()
```

---

## Async Data Loading

**Problem:** UI elements appear before data loads. Tests pass locally but fail in CI, or tests check elements before data populates them.

**Symptom:**

```typescript
// ❌ This passes even when data hasn't loaded yet
await expect(page.locator('[data-testid="badge"]')).toBeVisible()
// Badge shows "0%" because data not loaded, test passes incorrectly
```

**Pattern — Wait for Computed Data:**

```typescript
// ✅ Wait for actual data to load
await page.waitForFunction(() => {
  const badge = document.querySelector('[data-testid="badge"]')
  const percentText = badge?.textContent || '0%'
  const percent = parseInt(percentText)
  return percent > 0
})
```

**When to use:**
- Components using data fetching hooks (React Query, SWR, Apollo, etc.)
- Components displaying computed/derived state
- Data that loads after initial render

---

## Form Field Navigation (Special Characters in IDs)

**Problem:** Component libraries generate IDs with special characters (`:`, `.`, etc.) that break CSS selectors.

**Pattern — Navigate from Label:**

```typescript
// ✅ Find label, then traverse to associated input
const label = page.getByText('Field Label')
const input = page.locator(`input[id="${await label.getAttribute('for')}"]`)
await input.fill('value')

// Or simpler: Use label directly (Playwright traverses automatically)
await page.getByLabel('Field Label').fill('value')
```

**When to use:**
- Any form field with generated IDs
- Component libraries (Radix UI, Headless UI, etc.)
- Components using framework `useId()` hooks

---

## Multiple Status Elements

**Problem:** Multiple elements show the same status text (button text + status indicator). Assertions match the wrong element.

**Pattern — Use Specific Selectors or Regex:**

```typescript
// ❌ PROBLEM: Matches button text "Saving..." AND status indicator "Saving"
await expect(page.getByText('Saved')).toBeVisible()

// ✅ Be explicit about which element
await expect(page.locator('[data-testid="save-status"]')).toHaveText(/^Saved/)
await expect(page.getByRole('button')).toHaveText('Save')
```

---

## Waiting Patterns

Playwright auto-waits for most actions, but sometimes explicit waits are needed.

```typescript
// ✅ Good — Wait for network to settle
await page.goto('/')
await page.waitForLoadState('networkidle')

// ✅ Good — Wait for specific element
await page.waitForSelector('[data-testid="dashboard-loaded"]')

// ✅ Good — Wait for URL change
await page.getByRole('button', { name: 'Submit' }).click()
await page.waitForURL('/success')

// ❌ Bad — Arbitrary timeouts
await page.waitForTimeout(5000)  // Flaky! Don't use unless absolutely necessary
```

**When to use explicit waits:**
- After navigation (wait for load state)
- After form submission (wait for URL or success message)
- After AI/async responses (wait for response element)
- After API calls that update UI (wait for updated content)

---

## Mocking External Services

Tests should mock third-party APIs to avoid flaky dependencies:

```typescript
test('should handle API response', async ({ page }) => {
  await page.route('**/api/external/**', route => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ data: [{ id: '123', name: 'Test' }] })
    });
  });

  await page.goto('/page');
  await expect(page.getByText('Test')).toBeVisible();
});
```

**When NOT to mock:**
- Internal API routes (test real server routes)
- Database queries (use test database or fixtures)
- Frontend component logic (E2E tests real frontend)

---

## Page Object Model

For complex multi-step workflows, encapsulate interactions:

```typescript
export class CreateFlowPage {
  constructor(private page: Page) {}

  async goto() {
    await this.page.goto('/create');
  }

  async fillName(name: string) {
    await this.page.getByLabel('Name').fill(name);
  }

  async submit() {
    await this.page.getByRole('button', { name: 'Create' }).click();
  }

  async expectSuccess() {
    await this.page.waitForURL('/items/*');
    await expect(this.page.getByText('Created successfully')).toBeVisible();
  }
}
```

**When to use:** Multi-step workflows, reusable flows across tests, complex forms, flows that change frequently.

**When NOT to use:** Simple smoke tests, single-page interactions, one-off test scenarios.

---

## Visual Validation Requirement

**Sprint 3 Learning: 36% of UI tasks failed visual validation** even though code was committed.

**Why:** Code commit ≠ UI change visible. Common failures:
- Changes uncommitted (in working directory only)
- Fixed one component but same text exists in others
- Edited wrong component (similar UI in multiple files)

**Mandatory for UI changes:**
1. Wait for deploy (~5 min after merge to main)
2. Open deploy target in browser
3. Visually confirm the change (don't just check that the page loads)
4. Check for unintended side effects (layout shifts, z-index issues, etc.)

---

## Test Update Timing

**Problem:** Tests updated retroactively after implementation cause drift and rework.

**Sprint 10 Learning:** Retroactive test fixes took 39 min to fix 13 tests. Inline updates take 2-3 min each.

**Pattern — Inline Updates:**
1. Modify UI component
2. Update associated test selectors/assertions **in the same commit**
3. Run tests locally before pushing
4. If tests fail due to your change, fix before marking task complete

---

## When Tests Are Required

**MUST have E2E tests:**
- Critical user flows (onboarding, creation flows, checkout)
- Authentication/authorization (login, logout, access control)
- Data integrity (form validation, API error handling)
- User-facing features (any UI users interact with)
- Integration points (features calling external APIs)

**SHOULD have tests (not blockers):**
- Admin/settings pages
- Help documentation
- Edge cases and error states

**Tests NOT required:**
- Internal refactoring (no UI/behavior change)
- Styling/CSS-only changes
- Configuration files
- Documentation updates

---

## Adding New Features — Standard Workflow

1. **Add `data-testid` to new UI elements**

```tsx
<button data-testid="generate-button">Generate</button>
```

2. **Write E2E test for critical path**

```typescript
test('should complete the flow', async ({ page }) => {
  // Test implementation
});
```

3. **Run tests locally**

```bash
npm test  # or your project's test command
```

4. **Mark task complete only if:**
   - Feature works (manual or automated verification)
   - E2E test exists and passes
   - Existing tests still pass
   - Type checking passes

---

## Debugging Failed Tests

**Common failure causes:**

| Symptom | Likely Cause | Fix |
|---|---|---|
| "Timeout waiting for element" | Wrong selector or element not rendered | Check `data-testid`, add explicit wait |
| "Test passed locally, fails in CI" | Timing issue | Replace arbitrary waits with explicit waits |
| "Navigation timeout" | Dev server not started or wrong URL | Check `webServer` config, verify URL |
| "Strict mode violation" | Multiple matching elements | Use `.first()` or more specific selector |

**Debug commands:**

```bash
# Run with visible browser
npx playwright test --headed

# Step-by-step debugging
npx playwright test --debug

# View HTML report with screenshots and traces
npx playwright show-report
```

---

**Origin:** Extracted from internal stdlib after 13 sprints of Ralph development. Patterns are framework-agnostic where possible.
