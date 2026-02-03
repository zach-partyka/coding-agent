---
name: ralph-plan
description: Interactive sprint planning for Ralph. Pulls up backlog items, asks clarifying questions one at a time, and builds a sprint_plan.md ready for /ralph-continuous.
---

# Ralph Plan - Interactive Sprint Planning

Build the next sprint through focused, one-question-at-a-time conversation.

## Workflow

### 1. Get Project Directory

Use `AskUserQuestion` to ask which project to plan for. Search for directories with `RALPH.md` or previous `sprint_plan.md` files.

### 2. Review Current State

Read these files if they exist:
- `RALPH.md` - Project context and patterns
- `sprint_plan.md` - Any existing/previous plan
- `sprints/` directory - Past sprint archives
- `backlog.md` - Outstanding items (if exists)
- `sprint_summary.md` - Learnings from last sprint

Summarize what you found:
- What was completed in the last sprint
- Any items that were blocked or deferred
- Existing backlog items

### 3. Ask About Focus (One Question)

Use `AskUserQuestion`:
```json
{
  "questions": [{
    "question": "What should this sprint focus on?",
    "header": "Sprint Focus",
    "options": [
      {"label": "Backlog items", "description": "Work through existing backlog"},
      {"label": "New feature", "description": "Build something new"},
      {"label": "Bug fixes", "description": "Fix known issues"},
      {"label": "Technical debt", "description": "Refactoring and cleanup"}
    ],
    "multiSelect": false
  }]
}
```

### 4. Gather Details (One Question at a Time)

Based on their focus, ask follow-up questions **one at a time**:

**If backlog items:**
- Show the backlog items and ask which to prioritize
- Ask if any should be removed or deferred

**If new feature:**
- "What feature do you want to build?"
- "Who is this for and what problem does it solve?"
- "What does success look like?"
- "Any technical constraints or preferences?"

**If bug fixes:**
- "What bugs need fixing?" (or show known issues)
- "Which is highest priority?"

**If technical debt:**
- "What areas need cleanup?"
- "Any specific patterns to follow?"

### 5. Identify Investigation Tasks

Some items may need investigation before implementation. Ask:

```json
{
  "questions": [{
    "question": "Do any of these need investigation first?",
    "header": "Investigation",
    "options": [
      {"label": "Yes - some items need research", "description": "Create investigation tasks that may spawn follow-up tickets"},
      {"label": "No - ready to implement", "description": "All items are well-defined"}
    ],
    "multiSelect": false
  }]
}
```

For investigation tasks:
- Mark them as `[INVESTIGATE]` in the sprint plan
- Add a note: "After investigation, add follow-up tasks to sprint"
- Keep them small and focused

### 6. Estimate and Sequence

Ask about sprint size:
```json
{
  "questions": [{
    "question": "How big should this sprint be?",
    "header": "Sprint Size",
    "options": [
      {"label": "Small (3-5 tasks)", "description": "Quick iteration, low risk"},
      {"label": "Medium (5-8 tasks)", "description": "Balanced sprint"},
      {"label": "Large (8-12 tasks)", "description": "Ambitious, more context resets"}
    ],
    "multiSelect": false
  }]
}
```

### 7. Generate sprint_plan.md

Create the sprint plan with this structure:

```markdown
# Sprint [N]: [Theme/Goal]

## Goal
[One sentence describing what success looks like]

## Tasks

### Implementation Tasks
1. [#1] Task name - Brief description
   - Acceptance: [What "done" looks like]
   - Files: [Likely files to touch]

2. [#2] Task name - Brief description
   - Acceptance: [What "done" looks like]
   - Files: [Likely files to touch]

### Investigation Tasks
[INVESTIGATE] [#N] Investigation name - What we need to learn
   - Questions to answer: [Specific questions]
   - After investigation: Add implementation tasks to sprint
   - Max time: [Timebox]

## Blocked
(Empty - tasks move here if blocked)

## Completed
(Empty - tasks move here when done)

## Notes
- [Any context or decisions made during planning]
- [Links to relevant docs/specs]
```

### 8. Confirm and Save

Show the draft plan and ask:
```json
{
  "questions": [{
    "question": "Does this sprint plan look good?",
    "header": "Confirm",
    "options": [
      {"label": "Yes, save it", "description": "Write sprint_plan.md and start building"},
      {"label": "Make changes", "description": "Adjust tasks or priorities"},
      {"label": "Start over", "description": "Rethink the sprint focus"}
    ],
    "multiSelect": false
  }]
}
```

## Key Principles

1. **One question at a time** - Don't overwhelm. Each question builds on the last.

2. **Show what you found** - Always summarize existing state before asking what's next.

3. **Investigation tasks are first-class** - Some things need research. That's a valid task outcome.

4. **Keep tasks small** - Each task should be completable in one Claude session (~10-20 min).

5. **Acceptance criteria matter** - Every task needs clear "done" definition.

## Example Conversation Flow

```
Claude: "Found marketing-copilot-coaching with Sprint 4 completed.
         3 items in backlog. Last sprint fixed the 500 error on Brief Editor.

         What should Sprint 5 focus on?"
         [Backlog items] [New feature] [Bug fixes] [Tech debt]

User: [Backlog items]

Claude: "Here's the current backlog:
         1. Add user authentication
         2. Improve error messages
         3. Dashboard analytics

         Which items should be in Sprint 5?"
         [1 and 2] [All three] [Just #1] [Different items]

User: [1 and 2]

Claude: "For 'Add user authentication' - do you need to investigate
         auth options first, or is the approach already decided?"
         [Need to investigate] [Approach is clear]

User: [Need to investigate]

Claude: "Got it. I'll add an investigation task first.
         What auth approaches should we evaluate?"

User: "OAuth with Google, maybe Okta for enterprise"

Claude: [Creates investigation task, continues to next item...]
```

## After Planning

Once sprint_plan.md is saved, remind the user:
- "Run `/ralph` to implement one task at a time"
- "Run `/ralph-continuous` to implement all tasks automatically"
- "Investigation tasks may add new tasks mid-sprint - that's expected"
