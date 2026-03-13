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

set -euo pipefail
IFS=$'\n\t'

# Configuration
RALPH_WT_PROFILE="${RALPH_WT_PROFILE:-Git Bash}"  # Windows Terminal profile name (customizable)
RALPH_MODEL=""  # Model selection (set via prompt or RALPH_MODEL env var)

# Parse args in one pass: --inline flag and project directory
FORCE_INLINE=false
PROJECT_ARG=""
for arg in "$@"; do
  if [ "$arg" = "--inline" ]; then
    FORCE_INLINE=true
  elif [ -z "$PROJECT_ARG" ]; then
    PROJECT_ARG="$arg"
  fi
done

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
  done < <(find "$HOME/Documents" -name "sprint_plan.md" -type f 2>/dev/null | grep -v "/sprints/" | head -n 10)

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

readonly FIX_PLAN="${PROJECT_DIR}/sprint_plan.md"
readonly LOG_FILE="${PROJECT_DIR}/ralph-continuous.log"
readonly MARKER_DIR="${PROJECT_DIR}/.ralph-markers"

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

  # Check for sprint-level BLOCKED status (all remaining work blocked)
  if grep -qE "^\*\*Sprint Status:\*\*\s*BLOCKED" "$FIX_PLAN" 2>/dev/null; then
    return 1  # Sprint blocked - no unblocked tasks remain
  fi

  # Content before "## Completed" (one read for all remaining checks)
  local completed_line content
  completed_line=$(grep -n "^## Completed" "$FIX_PLAN" 2>/dev/null | head -1 | cut -d: -f1)
  if [ -n "$completed_line" ]; then
    content=$(head -n "$((completed_line - 1))" "$FIX_PLAN" 2>/dev/null)
  else
    content=$(cat "$FIX_PLAN")
  fi

  # Check for unchecked task boxes that are NOT blocked: - [ ] **#N** ... (anywhere in file)
  if grep -E "^\s*-\s*\[ \]" "$FIX_PLAN" 2>/dev/null | grep -qvE "BLOCKED"; then
    return 0  # Found unblocked unchecked tasks
  fi

  # Check for numbered tasks not in Completed section AND not BLOCKED
  if echo "$content" | grep -qE "^\s*[0-9]+\.\s*\[#[0-9]+\].*" 2>/dev/null; then
    if echo "$content" | grep -E "^\s*[0-9]+\.\s*\[#[0-9]+\]" | grep -qvE "BLOCKED"; then
      return 0
    fi
  fi

  # Check for any line with "IN PROGRESS" (active tasks) but not BLOCKED
  if echo "$content" | grep -qiE "IN PROGRESS" 2>/dev/null; then
    if echo "$content" | grep -iE "IN PROGRESS" | grep -qvE "BLOCKED"; then
      return 0
    fi
  fi

  return 1
}

# Set PROJECT_NAME and SPRINT_NAME for banner output (call before printing sprint banners)
get_sprint_display_info() {
  PROJECT_NAME=$(basename "$PROJECT_DIR")
  SPRINT_NAME=$(grep -E "^#\s*Sprint\s+[0-9]+" "$FIX_PLAN" 2>/dev/null | head -1 | sed 's/^#\s*//' || echo "Current Sprint")
}

check_blocked() {
  if grep -qE "BLOCKED|blocked" "$FIX_PLAN" 2>/dev/null; then
    # Check for numbered format: 1. [#7] Task - BLOCKED
    if grep -qE "^\s*[0-9]+\.\s*\[#[0-9]+\].*-\s*(BLOCKED|IN PROGRESS.*BLOCKED)" "$FIX_PLAN"; then
      return 0
    fi
    # Check for checkbox format: - [ ] **#7** Task - BLOCKED
    if grep -qE "^\s*-\s*\[\s*\]\s*\*\*#[0-9]+\*\*.*-\s*BLOCKED" "$FIX_PLAN"; then
      return 0
    fi
    # Check for sprint-level blocking status
    if grep -qE "^\*\*Sprint Status:\*\*\s*BLOCKED" "$FIX_PLAN"; then
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
  elif command -v wt.exe &> /dev/null && [ -n "$WT_SESSION" ]; then
    echo "windows-terminal"
  else
    # Default to Terminal.app on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
      echo "terminal"
    else
      echo "inline"
    fi
  fi
}

# Set task env used by all spawn_* functions: TASK_START_TS, SCRIPT_DIR, WRAPPER, start marker
prepare_task_env() {
  local task_num=$1
  TASK_START_TS=$(date +%s)
  date -r "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S' > "$MARKER_DIR/task-${task_num}-start"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  WRAPPER="$SCRIPT_DIR/ralph-task-wrapper.sh"
}

# Spawn Claude in a new terminal window (macOS Terminal.app)
# Uses 'do script' without keystroke to avoid accessibility permission requirements
spawn_in_terminal() {
  local task_num=$1
  prepare_task_env "$task_num"

  local launcher="/tmp/ralph-task-${task_num}.sh"
  cat > "$launcher" << LAUNCHER
#!/bin/bash
rm -f "$launcher"
exec "$WRAPPER" "$task_num" "$PROJECT_DIR" "$TASK_START_TS" "$MARKER_DIR" "$RALPH_MODEL"
LAUNCHER
  chmod +x "$launcher"

  osascript <<EOF
tell application "Terminal"
  activate
  do script "$launcher"
end tell
EOF
}

# Spawn Claude in a new iTerm2 window
# Uses 'create window' to avoid accessibility permission requirements
spawn_in_iterm() {
  local task_num=$1
  prepare_task_env "$task_num"

  local launcher="/tmp/ralph-task-${task_num}.sh"
  cat > "$launcher" <<EOF
#!/bin/bash
set -euo pipefail
rm -f "$launcher"

# Run wrapper (no extra startup chatter)
"$WRAPPER" "$task_num" "$PROJECT_DIR" "$TASK_START_TS" "$MARKER_DIR" "$RALPH_MODEL"
WRAPPER_EXIT=\$?

if [ \$WRAPPER_EXIT -ne 0 ]; then
  echo "Ralph wrapper exited with code \$WRAPPER_EXIT"
  echo "Press any key to close..."
  read -n 1
fi
exit \$WRAPPER_EXIT
EOF
  chmod +x "$launcher"

  osascript <<EOF
tell application "iTerm"
  activate
  if (count of windows) = 0 then
    create window with default profile
    tell current session of current window
      write text "$launcher"
    end tell
  else
    tell current window
      create tab with default profile
      tell current session
        write text "$launcher"
      end tell
    end tell
  end if
end tell
EOF
}

# Spawn Claude in a new Windows Terminal tab
spawn_in_windows_terminal() {
  local task_num=$1
  prepare_task_env "$task_num"

  local launcher="/tmp/ralph-task-${task_num}.sh"
  cat > "$launcher" << LAUNCHER
#!/bin/bash
rm -f "$launcher"
exec "$WRAPPER" "$task_num" "$PROJECT_DIR" "$TASK_START_TS" "$MARKER_DIR" "$RALPH_MODEL"
LAUNCHER
  chmod +x "$launcher"

  if wt.exe new-tab --profile "$RALPH_WT_PROFILE" bash -c "$launcher" 2>/dev/null; then
    return 0
  else
    echo "⚠️  Failed to spawn Windows Terminal tab"
    echo "   Profile '$RALPH_WT_PROFILE' not found in Windows Terminal"
    echo "   Set RALPH_WT_PROFILE env var if using different profile name"
    echo "   Falling back to inline mode..."
    return 1
  fi
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
  prepare_task_env "$task_num"
  "$WRAPPER" "$task_num" "$PROJECT_DIR" "$TASK_START_TS" "$MARKER_DIR" "$RALPH_MODEL"
}

# Wait for task completion via marker file, then close the terminal
wait_for_completion() {
  local task_num=$1
  local marker_file="$MARKER_DIR/task-done"
  local timeout=3600  # 60 minutes
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
log "Starting Ralph Continuous (terminal type: ${TERMINAL_TYPE})"
log "Project: ${PROJECT_DIR}"
log "Fix Plan: ${FIX_PLAN}"

# Load project configuration from ralph-config.md only
load_ralph_config() {
  [ -f "$PROJECT_DIR/ralph-config.md" ] || return 1
  local tmp
  tmp=$(mktemp)
  sed -n '/^```ralph-config$/,/^```$/p' "$PROJECT_DIR/ralph-config.md" | sed '1d;$d' > "$tmp" 2>/dev/null || true
  if [ -s "$tmp" ]; then
    source "$tmp"
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

if load_ralph_config; then
  export RALPH_GIT_REMOTE RALPH_DEPLOY_URL RALPH_GIT_MAIN_BRANCH
  export RALPH_DEPLOY_WAIT_SECONDS RALPH_VALIDATE_LOCAL RALPH_VALIDATE_DEPLOY
  export RALPH_HEALTH_CHECK_PATH RALPH_TASK_TIMEOUT_MINUTES RALPH_AUTO_ARCHIVE
  export RALPH_TEST_ENV_VARS
  echo -e "${GREEN}✓ Configuration loaded${NC}"
  log "Configuration loaded"
fi

# ── Update check ────────────────────────────────────────────────────────────
check_for_updates() {
  command -v gum &>/dev/null || return  # skip silently if gum not installed
  local kit_dir
  kit_dir="$(cd "$(dirname "$0")/.." && pwd)"
  git -C "$kit_dir" fetch origin --quiet 2>/dev/null || return
  local behind
  behind=$(git -C "$kit_dir" rev-list HEAD..origin/main --count 2>/dev/null || echo "0")
  [ "$behind" -eq 0 ] && return

  echo ""
  gum style \
    --border double \
    --border-foreground 212 \
    --foreground 212 \
    --padding "1 3" \
    "⚡ Ralph update available — $behind new change$([ "$behind" -gt 1 ] && echo 's')"
  echo ""

  if gum confirm "View what's new?"; then
    gum pager < "$kit_dir/CHANGELOG.md"
    echo ""
  fi

  if gum confirm "Update Ralph now? (recommended before sprinting)"; then
    gum spin --spinner dot --title "Pulling updates..." -- \
      git -C "$kit_dir" pull --quiet
    echo ""
    gum style --foreground 82 "✓ Ralph updated. Starting sprint..."
    echo ""
  fi
}

check_for_updates
# ── End update check ─────────────────────────────────────────────────────────

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

# Model selection
if [ -z "$RALPH_MODEL" ]; then
  echo -e "${BLUE}Which model should Ralph use?${NC}"
  echo ""
  echo -e "  ${GREEN}1${NC}) Default (Sonnet 4.6) - \$3/\$15 per Mtok - good for most tasks"
  echo -e "  ${GREEN}2${NC}) opus - Opus 4.6 - \$5/\$25 per Mtok - most capable"
  echo -e "  ${GREEN}3${NC}) opus-1m - Opus 4.6 (1M context) - \$10/\$37.50 per Mtok"
  echo -e "  ${GREEN}4${NC}) sonnet-1m - Sonnet 4.6 (1M context) - \$6/\$22.50 per Mtok"
  echo -e "  ${GREEN}5${NC}) haiku - Haiku 4.5 - \$1/\$5 per Mtok - fastest"
  echo ""
  read -p "Select [1-5]: " model_selection
  
  case $model_selection in
    1|"")
      RALPH_MODEL="sonnet"
      ;;
    2)
      RALPH_MODEL="opus"
      ;;
    3)
      RALPH_MODEL="opus-1m"
      ;;
    4)
      RALPH_MODEL="sonnet-1m"
      ;;
    5)
      RALPH_MODEL="haiku"
      ;;
    *)
      echo -e "${YELLOW}Invalid selection, using default model${NC}"
      RALPH_MODEL=""
      ;;
  esac
fi

if [ -n "$RALPH_MODEL" ]; then
  echo -e "Model: ${GREEN}$RALPH_MODEL${NC}"
  export RALPH_MODEL
else
  echo -e "Model: ${GREEN}default${NC}"
fi
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
  # Check blocking FIRST before checking completion
  if check_blocked; then
    # Tasks are blocked - check if ALL remaining tasks are blocked
    if ! check_tasks_remain; then
      get_sprint_display_info
      echo ""
      echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
      echo -e "${YELLOW}  Sprint Blocked: ${SPRINT_NAME}${NC}"
      echo -e "\033[2m  ${PROJECT_NAME}${NC}"
      echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
      echo ""
      echo "All remaining tasks are blocked."
      echo ""
      echo -e "${BLUE}View details:${NC}"
      echo "  file://$FIX_PLAN"
      echo ""
      echo -e "${BLUE}Next steps:${NC}"
      echo "  1. Fix blocking issues (environment, dependencies, etc.)"
      echo "  2. Run ralph-continuous.sh again to complete blocked tasks"
      echo ""
      log "Sprint blocked: $SPRINT_NAME - all remaining tasks blocked after $TASK_COUNT iterations"
      break
    fi
  fi
  
  if ! check_tasks_remain; then
    get_sprint_display_info
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  All tasks complete: ${SPRINT_NAME}${NC}"
    echo -e "\033[2m  ${PROJECT_NAME}${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    log "All tasks complete: $SPRINT_NAME after $TASK_COUNT iterations"

    echo ""
    echo -e "${BLUE}View sprint details:${NC}"
    echo "  file://$FIX_PLAN"
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
    echo -e "${YELLOW}  Task blocked${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    log "Task blocked after $TASK_COUNT iterations"
    
    # Check if there are any unblocked tasks remaining
    if ! check_tasks_remain; then
      echo "All remaining tasks are blocked or complete."
      echo "Sprint paused - resolve blocked tasks and run Ralph again."
      echo ""
      log "All tasks blocked or complete - stopping"
      break
    else
      echo "Blocked task detected - skipping to next unblocked task"
      echo ""
      log "Continuing with next unblocked task"
      sleep 2
    fi
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
    "windows-terminal")
      if spawn_in_windows_terminal $TASK_COUNT; then
        wait_for_completion $TASK_COUNT
      else
        # Fallback to inline if tab spawning failed
        echo "ℹ️  Running in inline mode - tasks will execute sequentially in this window."
        spawn_inline $TASK_COUNT
      fi
      ;;
    *)
      echo "ℹ️  Terminal tab spawning not available in this environment"
      echo "   (Supported: iTerm2, Terminal.app, VS Code, Windows Terminal)"
      echo "   Running in inline mode - tasks will execute sequentially in this window."
      echo ""
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
