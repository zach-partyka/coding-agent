#!/bin/bash
# ralph-start.sh - Launcher that uses Claude for project selection, then runs fresh sessions per task

SELECTION_FILE="/tmp/ralph-project-selection.txt"
rm -f "$SELECTION_FILE"

echo ""
echo "Starting Claude to select project..."
echo "(After selecting, press Escape or Ctrl+C to continue)"
echo ""

# Launch Claude to ask the question
CLAUDE_PROMPT="Use AskUserQuestion to ask which project directory to work in. Search for directories with sprint_plan.md in /Users/zachpa/Documents to find options. After the user selects, write ONLY the full path to $SELECTION_FILE (no other text, just the path)."
claude --dangerously-skip-permissions "$CLAUDE_PROMPT"

# Check if selection was made
if [ -f "$SELECTION_FILE" ]; then
  read -r PROJECT_DIR < "$SELECTION_FILE"
  PROJECT_DIR="${PROJECT_DIR#"${PROJECT_DIR%%[![:space:]]*}"}"
  PROJECT_DIR="${PROJECT_DIR%"${PROJECT_DIR##*[![:space:]]}"}"
  rm -f "$SELECTION_FILE"

  if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
    echo ""
    echo "Starting Ralph Continuous for: $PROJECT_DIR"
    echo ""
    # Run the main script (same directory as this script)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$SCRIPT_DIR/ralph-continuous.sh" "$PROJECT_DIR"
  else
    echo "Invalid project directory: $PROJECT_DIR" >&2
    exit 1
  fi
else
  echo "No project selected. Exiting." >&2
  exit 1
fi
