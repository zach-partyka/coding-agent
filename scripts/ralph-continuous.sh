#!/bin/bash
# ralph-continuous.sh - Outer orchestrator for Ralph
# Spawns fresh Claude sessions in NEW TERMINAL TABS for full interactive visibility
#
# Usage:
#   ./ralph-continuous.sh /path/to/project
#   ./ralph-continuous.sh  # uses current directory
#
# Each task opens in a new Terminal tab so you can watch Claude work with full
# interactive UI (diffs, colors, reasoning). The orchestrator waits for each
# task to complete before spawning the next.

set -e

# Check for --inline flag (forces inline mode, no external terminal spawning)
FORCE_INLINE=false
for arg in "$@"; do
  if [ "$arg" = "--inline" ]; then
    FORCE_INLINE=true
  fi
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project directory (filter out --inline flag)
PROJECT_ARG=""
for arg in "$@"; do
  if [ "$arg" != "--inline" ]; then
    PROJECT_ARG="$arg"
    break
  fi
done

# Prompt for directory if not provided
if [ -z "$PROJECT_ARG" ]; then
  echo ""
  echo -e "${BLUE}Which project directory should I work in?${NC}"
  echo ""

  # Find directories with sprint_plan.md (Ralph-compatible projects)
  # Exclude /sprints/ subdirectories (those are archives)
  RALPH_PROJECTS=()
  while IFS= read -r sprint_file; do
    project_dir=$(dirname "$sprint_file")
    RALPH_PROJECTS+=("$project_dir")
  done < <(find /Users/zachpa/Documents -name "sprint_plan.md" -type f 2>/dev/null | grep -v "/sprints/" | head -n 10)

  if [ ${#RALPH_PROJECTS[@]} -gt 0 ]; then
    echo "Found Ralph projects:"
    echo ""
    for i in "${!RALPH_PROJECTS[@]}"; do
      echo -e "  ${GREEN}$((i+1))${NC}) ${RALPH_PROJECTS[$i]}"
    done
    echo ""
    echo -e "  ${YELLOW}0${NC}) Enter a different path"
    echo ""
    read -p "Select [1-${#RALPH_PROJECTS[@]}] or 0: " selection

    if [ "$selection" = "0" ]; then
      read -p "Enter path: " PROJECT_DIR
      PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
    elif [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -le ${#RALPH_PROJECTS[@]} ]; then
      PROJECT_DIR="${RALPH_PROJECTS[$((selection-1))]}"
    else
      echo -e "${RED}Invalid selection. Exiting.${NC}"
      exit 1
    fi
  else
    echo "No Ralph projects found. Enter path manually:"
    read -p "> " PROJECT_DIR
    PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
  fi

  if [ -z "$PROJECT_DIR" ]; then
    echo -e "${RED}No directory provided. Exiting.${NC}"
    exit 1
  fi
else
  PROJECT_DIR="$PROJECT_ARG"
fi

FIX_PLAN="$PROJECT_DIR/sprint_plan.md"
LOG_FILE="$PROJECT_DIR/ralph-continuous.log"
MARKER_DIR="$PROJECT_DIR/.ralph-markers"

# Create marker directory
mkdir -p "$MARKER_DIR"

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo -e "$msg"
  echo "$msg" >> "$LOG_FILE"
}

check_tasks_remain() {
  # Check for sprint-complete marker (created by Claude when sprint is done)
  if [ -f "$MARKER_DIR/sprint-complete" ]; then
    return 1  # No tasks remain
  fi

  # Check for unchecked task boxes: - [ ] **#N** or - [ ] #N or - [ ] Task #N
  if grep -qE "^\s*-\s*\[ \]" "$FIX_PLAN" 2>/dev/null; then
    return 0  # Found unchecked tasks
  fi

  # Check for numbered tasks not in Completed section
  if grep -qE "^\s*[0-9]+\.\s*\[#[0-9]+\].*" "$FIX_PLAN" 2>/dev/null; then
    local completed_line=$(grep -n "^## Completed" "$FIX_PLAN" | head -1 | cut -d: -f1)
    if [ -z "$completed_line" ]; then
      return 0
    fi
    if head -n "$completed_line" "$FIX_PLAN" | grep -qE "^\s*[0-9]+\.\s*\[#[0-9]+\]"; then
      return 0
    fi
  fi

  # Check for any line with "IN PROGRESS" (active tasks)
  if grep -qiE "IN PROGRESS" "$FIX_PLAN" 2>/dev/null; then
    # But not if it's in the Completed section
    local completed_line=$(grep -n "^## Completed" "$FIX_PLAN" | head -1 | cut -d: -f1)
    if [ -z "$completed_line" ]; then
      return 0
    fi
    if head -n "$completed_line" "$FIX_PLAN" | grep -qiE "IN PROGRESS"; then
      return 0
    fi
  fi

  return 1
}

check_blocked() {
  if grep -qE "BLOCKED|blocked" "$FIX_PLAN" 2>/dev/null; then
    if grep -qE "^\s*[0-9]+\.\s*\[#[0-9]+\].*-\s*(BLOCKED|IN PROGRESS.*BLOCKED)" "$FIX_PLAN"; then
      return 0
    fi
  fi
  return 1
}

# Detect which terminal app to use
detect_terminal() {
  if [ "$TERM_PROGRAM" = "iTerm.app" ]; then
    echo "iterm"
  elif [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
    echo "terminal"
  elif [ "$TERM_PROGRAM" = "vscode" ]; then
    echo "vscode"
  else
    # Default to Terminal.app on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "terminal"
    else
      echo "inline"
    fi
  fi
}

# Spawn Claude in a new terminal window (macOS Terminal.app)
# Uses 'do script' without keystroke to avoid accessibility permission requirements
spawn_in_terminal() {
  local task_num=$1

  # Create the command that will run in the new window
  local dir_name=$(basename "$PROJECT_DIR")
  local cmd="cd '$PROJECT_DIR' && claude --dangerously-skip-permissions --max-turns 50 '/ralph

📁 $dir_name

Implement ONE task from sprint_plan.md, then signal completion.

When done: touch $MARKER_DIR/task-done
If sprint complete: touch $MARKER_DIR/sprint-complete'"

  # 'do script' without 'in window' opens a new window - no accessibility permissions needed
  osascript <<EOF
tell application "Terminal"
  activate
  do script "$cmd"
end tell
EOF
}

# Spawn Claude in a new iTerm2 window
# Uses 'create window' to avoid accessibility permission requirements
spawn_in_iterm() {
  local task_num=$1

  local dir_name=$(basename "$PROJECT_DIR")
  local cmd="cd '$PROJECT_DIR' && claude --dangerously-skip-permissions --max-turns 50 '/ralph

📁 $dir_name

Implement ONE task from sprint_plan.md, then signal completion.

When done: touch $MARKER_DIR/task-done
If sprint complete: touch $MARKER_DIR/sprint-complete'"

  # Use tabs in existing window, or create first window if none exists
  osascript <<EOF
tell application "iTerm"
  activate
  if (count of windows) = 0 then
    create window with default profile
    tell current session of current window
      write text "$cmd"
    end tell
  else
    tell current window
      create tab with default profile
      tell current session
        write text "$cmd"
      end tell
    end tell
  end if
end tell
EOF
}

# Spawn with forced PTY (for VS Code or other non-native terminals)
# Uses `script` command to allocate a pseudo-terminal
spawn_with_pty() {
  local task_num=$1
  local dir_name=$(basename "$PROJECT_DIR")

  # script -q /dev/null forces PTY allocation
  # This makes Claude think it has a real terminal, enabling interactive UI
  # The echo "2" auto-accepts the bypass permissions prompt
  echo "2" | script -q /dev/null claude --dangerously-skip-permissions "/ralph

📁 $dir_name

Implement ONE task from sprint_plan.md, then signal completion."
}

# Spawn inline (true fallback - no TTY benefits)
spawn_inline() {
  local task_num=$1
  local dir_name=$(basename "$PROJECT_DIR")

  claude --dangerously-skip-permissions "/ralph

📁 $dir_name

Implement ONE task from sprint_plan.md, then signal completion."
}

# Wait for task completion via marker file, then close the terminal
wait_for_completion() {
  local task_num=$1
  local marker_file="$MARKER_DIR/task-done"
  local timeout=600  # 10 minutes
  local elapsed=0

  # Remove old marker before starting
  rm -f "$marker_file"

  echo -n "Waiting for task #$task_num to complete "

  while [ ! -f "$marker_file" ] && [ $elapsed -lt $timeout ]; do
    sleep 3
    elapsed=$((elapsed + 3))
    echo -n "."
  done

  echo ""

  if [ -f "$marker_file" ]; then
    rm -f "$marker_file"
    # Tab stays open for manual review - user closes when ready
    return 0
  else
    return 1
  fi
}

# Header
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Ralph Continuous - Full Interactive Visibility          ║${NC}"
echo -e "${BLUE}║  Watch Claude work with diffs and reasoning              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

TERMINAL_TYPE=$(detect_terminal)
log "Starting Ralph Continuous (terminal type: $TERMINAL_TYPE)"
log "Project: $PROJECT_DIR"
log "Fix Plan: $FIX_PLAN"

# Load project configuration if it exists
if [ -f "$PROJECT_DIR/ralph.config.sh" ]; then
  log "Loading project configuration from ralph.config.sh"
  source "$PROJECT_DIR/ralph.config.sh"

  # Export all RALPH_* variables so spawned tabs inherit them
  export RALPH_GIT_REMOTE RALPH_STAGING_URL RALPH_GIT_MAIN_BRANCH
  export RALPH_DEPLOY_WAIT_SECONDS RALPH_VALIDATE_LOCAL RALPH_VALIDATE_STAGING
  export RALPH_HEALTH_CHECK_PATH RALPH_TASK_TIMEOUT_MINUTES RALPH_AUTO_ARCHIVE
  export RALPH_TEST_ENV_VARS

  echo -e "${GREEN}✓ Configuration loaded${NC}"
  log "Configuration loaded successfully"
else
  log "No ralph.config.sh found - using default configuration"
fi

if [ "$FORCE_INLINE" = true ]; then
  echo -e "${YELLOW}Note: Running in inline mode (--inline flag).${NC}"
  echo -e "${YELLOW}Full interactive UI in this terminal. Fresh context per task.${NC}"
  echo ""
  TERMINAL_TYPE="inline"
elif [ "$TERMINAL_TYPE" = "vscode" ]; then
  # Prefer iTerm2 if installed, otherwise fall back to Terminal.app
  if [ -d "/Applications/iTerm.app" ]; then
    echo -e "${YELLOW}Note: Running from VS Code terminal.${NC}"
    echo -e "${YELLOW}Tasks will open as iTerm2 tabs for full interactive UI.${NC}"
    echo ""
    TERMINAL_TYPE="iterm"
  else
    echo -e "${YELLOW}Note: Running from VS Code terminal.${NC}"
    echo -e "${YELLOW}Tasks will open in Terminal.app windows for full interactive UI.${NC}"
    echo ""
    TERMINAL_TYPE="terminal"
  fi
fi

echo -e "Terminal: ${GREEN}$TERMINAL_TYPE${NC}"
echo ""

# Validate project structure
if [ ! -f "$FIX_PLAN" ]; then
  echo -e "${RED}Error: sprint_plan.md not found at $FIX_PLAN${NC}"
  echo "Run /ralph-plan first to generate a plan."
  exit 1
fi

if [ ! -d "$PROJECT_DIR/specs" ]; then
  echo -e "${YELLOW}Warning: specs/ directory not found${NC}"
fi

if [ ! -d "$PROJECT_DIR/stdlib" ]; then
  echo -e "${YELLOW}Warning: stdlib/ directory not found${NC}"
fi

TASK_COUNT=0
START_TIME=$(date +%s)

# Main loop
while true; do
  if ! check_tasks_remain; then
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  All tasks complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    log "All tasks complete after $TASK_COUNT iterations"

    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  - Run /ralph-archive to archive this sprint"
    echo "  - Run /ralph-plan to plan the next sprint"
    echo ""

    break
  fi

  if check_blocked; then
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Task blocked - human intervention needed${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Check sprint_plan.md for BLOCKED status and resolve."
    echo "Then run ./ralph-continuous.sh again to resume."
    log "Stopped: task blocked after $TASK_COUNT iterations"
    break
  fi

  TASK_COUNT=$((TASK_COUNT + 1))

  echo ""
  echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
  echo -e "${BLUE}  Task #$TASK_COUNT - Opening new terminal tab${NC}"
  echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
  echo ""

  log "Starting task #$TASK_COUNT"

  case $TERMINAL_TYPE in
    "iterm")
      spawn_in_iterm $TASK_COUNT
      wait_for_completion $TASK_COUNT
      ;;
    "terminal")
      spawn_in_terminal $TASK_COUNT
      wait_for_completion $TASK_COUNT
      ;;
    "pty")
      spawn_with_pty $TASK_COUNT
      ;;
    *)
      spawn_inline $TASK_COUNT
      ;;
  esac

  EXIT_CODE=$?

  if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Task #$TASK_COUNT failed or timed out${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
    log "Error: Task #$TASK_COUNT failed after $TASK_COUNT iterations"
    break
  fi

  log "Task #$TASK_COUNT complete, context reset"

  echo ""
  echo -e "${GREEN}✓ Task #$TASK_COUNT complete${NC}"
  echo "Pausing 3 seconds before next task..."
  sleep 3
done

# Cleanup
rm -rf "$MARKER_DIR"

# Summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo "  Tasks attempted: $TASK_COUNT"
echo "  Total time: ${MINUTES}m ${SECONDS}s"
echo "  Log file: $LOG_FILE"
echo ""
