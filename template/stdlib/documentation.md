# Documentation (Doc-in-the-Loop)

Keep the codebase understandable for future-you, teammates, or the next AI session. Documentation is part of the loop, not an afterthought.

## When to Add or Update Docs

**New module or new directory with multiple files:**
- Add a short `README.md` in that directory: what the module does, main entry points, and how it fits into the app (1–3 paragraphs max).

**New or meaningfully changed public API:**
- Public = exported from a module and used by other parts of the app (e.g. route handlers, shared utilities, components used in more than one place).
- Add or update doc comments for the main function or component: purpose, parameters, return value or behavior, and any non-obvious contract (e.g. "caller must ensure user is authenticated").

**Non-obvious behavior or quirk:**
- If the code does something that isn't obvious from reading it (workaround, env dependency, integration detail), document it in code or in RALPH.md under "Learned Lessons."

## What Counts as "Enough"

- **README:** Enough that someone opening the folder knows what it does and where to start. No need to document every file.
- **Doc comments:** Enough that a caller knows what to pass and what to expect. No need to document every parameter if the types are clear.
- **RALPH.md:** One line per learning (build/run/test quirk, env, validation pattern). Use it for behavior that affects how the project is built or run.

## Enforcement

If you add or change a module or public API without adding/updating the relevant doc, add it before marking the task complete. If the task didn't touch modules or public APIs, no doc update is required.
