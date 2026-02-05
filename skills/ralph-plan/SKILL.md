---
name: ralph-plan
description: Interactive sprint planning for Ralph. Pulls up backlog items, asks clarifying questions one at a time, and builds a sprint_plan.md ready for /ralph-continuous.
---

# Ralph Plan - Interactive Sprint Planning

Build the next sprint through focused, one-question-at-a-time conversation.

## Workflow

### 1. Get Project Directory

Use `AskUserQuestion` to ask which project to plan for. Search for directories with `RALPH.md` or previous `sprint_plan.md` files.

### 2. Check if Current Sprint Needs Archiving

**Before planning next sprint, verify current sprint is archived.**

Read `sprint_plan.md` if it exists.

**Check for completed but unarchived sprint:**

Look for these indicators:
1. Sprint has "Sprint Performance Summary" section
2. Sprint status is "COMPLETE" or "IN PROGRESS" with all tasks in Completed
3. Has tasks in "Completed" section
4. Sprint number/name is mentioned in the file

If sprint exists and appears complete, check if it's been archived:

```bash
# Extract sprint number from sprint_plan.md (look for "Sprint: N" or "Sprint N:")
# Check if sprints/sprint-N-* directory exists
ls -d sprints/sprint-[N]-* 2>/dev/null
```

**If sprint is complete but NOT archived:**

Tell the user:
```
Found completed Sprint [N] that hasn't been archived yet.
I need to archive it before planning the next sprint.

Archiving Sprint [N] now...
```

**Run ralph-archive workflow inline:**
1. Follow all steps from ralph-archive skill (steps 3-12)
2. Archive the current sprint
3. This will create a fresh sprint_plan.md
4. Then continue with ralph-plan workflow below

**If sprint is already archived:**
- Proceed to step 3 below

**If no sprint_plan.md exists or it's empty:**
- Proceed to step 3 below (first sprint for this project)

### 3. Review Current State

Read these files if they exist:
- `RALPH.md` - Project context and patterns
- `sprint_plan.md` - Any existing/previous plan (may be fresh if just archived)
- `sprints/` directory - Past sprint archives
- `backlog.md` - Outstanding items (if exists)
- `sprint_summary.md` - Learnings from last sprint (may be freshly generated if just archived)

Summarize what you found:
- What was completed in the last sprint
- Any items that were blocked or deferred
- Existing backlog items

### 4. Ask About Focus (One Question)

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

### 5. Gather Details (One Question at a Time)

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

### 5.5. Suggest Investigation Tasks (For Certain Sprint Types)

**Before asking about investigation needs, check if sprint involves:**

Keywords triggering investigation-first approach:
- "standardize" → audit current patterns first
- "refactor" → understand existing structure first
- "optimize" → profile/measure first
- "migration" → survey data patterns first
- "consistency" → document inconsistencies first
- "align" → compare implementations first

**If keywords detected, prompt user:**

Use `AskUserQuestion`:
```json
{
  "questions": [{
    "question": "I notice this sprint involves [keyword]. Investigation-first approach in Sprint 10 achieved 305x ROI by documenting inconsistencies before implementation (3 audit tasks → 12 implementation tasks averaging 3 min each vs. typical 10-15 min). Would you like me to add 1-2 investigation/audit tasks at the start of the sprint to document current state before implementation?",
    "header": "Investigation-First Approach",
    "options": [
      {"label": "Yes - Add investigation tasks first (Recommended)", "description": "Document current state before implementing changes"},
      {"label": "No - Proceed with implementation tasks only", "description": "Skip investigation and go straight to implementation"}
    ],
    "multiSelect": false
  }]
}
```

**If user selects "Yes":**

- Add 1-2 investigation tasks to sprint plan (marked High Priority)
- Format: "Audit [X] patterns across codebase" or "Document current [Y] implementation approaches"
- Timebox: ~10 min per investigation task
- Expected output: Document findings in task description or create summary in sprint_plan.md Notes section

### 6. Identify Investigation Tasks

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

### 7. Estimate and Sequence

Ask about sprint size:
```json
{
  "questions": [{
    "question": "How big should this sprint be?",
    "header": "Sprint Size",
    "options": [
      {"label": "Focused (5-8 tasks)", "description": "Clear goal, easy to review"},
      {"label": "Standard (9-14 tasks)", "description": "Balanced sprint, your typical size"},
      {"label": "Ambitious (15-20 tasks)", "description": "Large scope, ensure tasks are atomic"}
    ],
    "multiSelect": false
  }]
}
```

**If user selects "Ambitious (15-20 tasks)":**

Show warning with guidance:

```
⚠️ Ambitious sprint! To keep this manageable:

- Ensure each task is 1-2 SP (completable in 10-20 min)
- Group related tasks conceptually (e.g., 3 investigation, 10 implementation, 3 testing)
- Consider if this could be split into Sprint N and Sprint N+1

Based on your sprint history (Sprint 10), 15-20 task sprints work when:

- Investigation-first approach with clear atomic implementation steps
- Each implementation task averages 5-8 min (proven in Sprint 10: 305x ROI)

Proceed with [X] tasks?
```

Use `AskUserQuestion`:
```json
{
  "questions": [{
    "question": "Proceed with ambitious sprint?",
    "header": "Confirm Sprint Size",
    "options": [
      {"label": "Yes, proceed with [X] tasks", "description": "Tasks are atomic and well-defined"},
      {"label": "No, split into two sprints", "description": "Break into Sprint N and Sprint N+1"}
    ],
    "multiSelect": false
  }]
}
```

### 7.5. Order Tasks Explicitly by Priority and Dependencies

After gathering all tasks, order them explicitly so Ralph executes top-to-bottom:

**Ask clarifying questions:**
1. "Which tasks are blockers for others?" (dependencies)
2. "Which tasks are highest business value?" (priority)
3. "Which tasks need to happen first for technical reasons?" (architecture)

**Document the ordering in sprint_plan.md:**
```markdown
## Critical Path (must complete in order)
1. [#1] Set up database schema - BLOCKER for all data tasks
2. [#2] Add user model - depends on #1
3. [#3] Create login endpoint - depends on #2

## High Priority (can parallelize if no dependencies)
4. [#4] Add dashboard UI - independent
5. [#5] Add error logging - independent
```

**Tell the user:**
"I've ordered tasks by dependencies and priority. Ralph will execute top-to-bottom within each section."

**If investigation discovers priority conflicts:**

Ralph will flag conflicts during execution:

```
⚠️ Investigation finding - Priority conflict detected

Task #3 investigation revealed:
- Task #7 should happen before Task #5
- Reason: [explanation]

Options:
1. BLOCK - Update sprint_plan.md order and I'll proceed
2. Continue as-is - Keep original order
3. Mark #7 as blocker for #5 - I'll skip #5 until #7 is done
```

### 8. Generate sprint_plan.md

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

### 9. Confirm and Save

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

1. **Archive before planning** - Always check if previous sprint needs archiving first. This ensures performance data is captured and sprint history is complete.

2. **One question at a time** - Don't overwhelm. Each question builds on the last.

3. **Show what you found** - Always summarize existing state before asking what's next.

4. **Investigation tasks are first-class** - Some things need research. That's a valid task outcome.

5. **Keep tasks small** - Each task should be completable in one Claude session (~10-20 min).

6. **Acceptance criteria matter** - Every task needs clear "done" definition.

## Task Sizing Guidelines

**Every task must complete within a single Claude session:**

### Technical Constraint
- Sonnet 4.5 has ~200k token context window
- Session duration: ~10-20 minutes of complex work before context reset
- What fits: Investigate OR Build OR Test for 1 feature (not all three combined)

### Story Point Guide (Agile Framework)

**1 SP (5-10 min):**
- Single file change with clear pattern to follow
- UI changes with clear specs
- Simple API endpoints following existing patterns
- Configuration changes

**2 SP (10-20 min):**
- Multi-file changes with moderate complexity
- New patterns or infrastructure
- Investigation tasks (timeboxed to 10-15 min)
- Testing tasks

**3+ SP = TOO BIG (split into multiple tasks):**
- If estimate exceeds 20 min, break into multiple tasks
- Context window constraint: ~200k tokens ≈ 20 min complex work

### Investigation-Only Tasks

Investigation tasks should be investigation ONLY:
- Timebox: 10-15 min max
- Output: Document findings, don't implement
- Follow-up: Findings inform subsequent implementation tasks

**Sprint 10 example:** 3 investigation tasks (10 min each) → 12 implementation tasks (6.3 min avg) = 305x ROI

### Examples

**Good task sizing:**
- "Audit badge usage patterns across codebase" (Investigation, 10 min)
- "Update dashboard to use unified completion calculation" (Implementation, 5 min)
- "Add Playwright test for chat flow" (Testing, 13 min)

**Too large (needs splitting):**
- "Build authentication system" → Split into: investigate auth options, add user model, implement login endpoint, add JWT, add middleware
- "Refactor API layer" → Split into: audit current patterns, update endpoint 1, update endpoint 2, etc.

## Example Conversation Flow

### Scenario 1: Sprint Already Archived

```
Claude: "Found marketing-copilot-coaching. Sprint 4 already archived.
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

### Scenario 2: Sprint Needs Archiving First

```
Claude: "Found completed Sprint 4 that hasn't been archived yet.
         I need to archive it before planning the next sprint.
         
         Archiving Sprint 4 now..."
         
         [Runs ralph-archive workflow]
         
         "Sprint 4 archived successfully!
         - 3 tasks completed
         - ~16 min duration
         - ~$0.50 cost
         
         Now let's plan Sprint 5.
         
         Found 3 backlog items from Sprint 4 recommendations.
         
         What should Sprint 5 focus on?"
         [Backlog items] [New feature] [Bug fixes] [Tech debt]

User: [Backlog items]

Claude: [Continues with normal planning flow...]
```

## After Planning

Once sprint_plan.md is saved, remind the user:
- "Run `/ralph` to implement one task at a time"
- "Run `/ralph-continuous` to implement all tasks automatically"
- "Investigation tasks may add new tasks mid-sprint - that's expected"
