# Ralph Build Instructions

Project-specific configuration (deploy target URL, build commands, git remote) lives in `ralph-config.md`.

---

## Sprint Plan Format

Tasks must use bullet checkboxes. Ralph won't detect numbered lists.

**Correct:**
```markdown
- [ ] **#1** Task name
  - Details here
  - Validation: How to verify
```

**Wrong:**
```markdown
1. [ ] **#1** Task name
```

---

## How to Run Sprints Well

### Choose the right model

Default to Sonnet. Use Opus only for hard problems.

- **Sonnet** — use for most tasks: building features, fixing bugs, writing tests, config changes
- **Opus** — use only when the problem is genuinely complex: multiple interacting bugs, major architectural decisions. Keep Opus tasks short.

Sonnet costs 2–4x less than Opus and handles most work just as well.

### Start with investigation for bugs and unfamiliar code

When fixing a bug or working in unfamiliar code, start with a task that just investigates — don't build yet. Ask Ralph to find the root cause and report back. Then plan the fix.

Skip investigation when you already know what to build.

### Run cohesive tasks in a single session

When tasks share a canonical reference doc (brand guide, API spec, style doc), run all in one session. Prompt caching multiplies efficiency 10-20x. Best for: brand/theme refactors, design-system updates, API implementations with a detailed spec.

### For external APIs, validate before writing code

Before writing integration code:
1. Validate the real API response structure with curl (~5-10 min investigation task)
2. Document actual field names and nesting in sprint_plan.md
3. Implement against the validated structure, not assumed/documented structure

External APIs often return nested objects with different field names than their docs suggest.

### Don't let failing tests pile up

Every sprint should end with all tests passing (or explicitly skipped with a reason). If a test fails, fix it in the same sprint. Don't carry broken tests forward — they mask new problems.

### Use subagents for investigation and testing

Spawn subagents for codebase search, investigation tasks, validation, and test runs against your deploy target. This keeps the main session focused on implementation and reduces cost. See the ralph skill for which agents to use and when.

---

## stdlib/ — Technical Patterns

The `stdlib/` directory is for project-specific coding patterns Ralph follows on every task. It starts empty — stack standards (routes, secrets, schema, selectors, async, tests, docs) live in the `## Stack Standards` section of `ralph-config.md`.

Add files here for patterns that go beyond the defaults: framework conventions, ORM patterns, API-specific rules, etc. (e.g. `drizzle_patterns.md`, `graphql_patterns.md`).

The kit ships baseline pattern files in `template/stdlib/` if you want a starting point — copy any you need into your project's `stdlib/` and customize for your stack.

Ralph reads stdlib/ during every task (Step 3 in the skill). If it violates a pattern, update the relevant file with the correction.
