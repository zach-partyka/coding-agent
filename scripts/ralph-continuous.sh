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

_RALPH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_RALPH_SCRIPT_DIR/ralph-portable.sh" ]; then
  # shellcheck source=ralph-portable.sh
  . "$_RALPH_SCRIPT_DIR/ralph-portable.sh"
else
  echo "ERROR: ralph-portable.sh not found next to $(basename "${BASH_SOURCE[0]}")." >&2
  echo "Re-run scripts/setup-project.sh to refresh the global Ralph install." >&2
  exit 1
fi

# Configuration
RALPH_WT_PROFILE="${RALPH_WT_PROFILE:-Git Bash}"  # Windows Terminal profile name (customizable)
RALPH_MODEL=""  # Model selection (set via prompt or RALPH_MODEL env var)

# Keep the original argv so check_for_updates can re-exec cleanly after a pull.
RALPH_ARGV=("$@")

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
  # Find directories with sprint_plan.md (Ralph-compatible projects)
  # Exclude /sprints/ subdirectories (those are archives)
  RALPH_PROJECTS=()
  while IFS= read -r sprint_file; do
    RALPH_PROJECTS+=("$(dirname "$sprint_file")")
  done < <({ find "$HOME/Documents" -name "sprint_plan.md" -type f 2>/dev/null
             [ -d "$HOME/OneDrive/Documents" ] && find "$HOME/OneDrive/Documents" -name "sprint_plan.md" -type f 2>/dev/null
           } | grep -v "/sprints/" | sort -u | head -n 10)

  RALPH_OTHER_OPT="Enter a different path..."
  if [ ${#RALPH_PROJECTS[@]} -gt 0 ]; then
    PROJECT_CHOICE="$(ui_choose "Which project directory should I work in?" \
      "${RALPH_PROJECTS[@]}" "$RALPH_OTHER_OPT")" || { echo "No selection. Exiting."; exit 1; }
  else
    PROJECT_CHOICE="$RALPH_OTHER_OPT"
  fi

  if [ "$PROJECT_CHOICE" = "$RALPH_OTHER_OPT" ]; then
    PROJECT_DIR="$(ui_input "Project directory path:" "~/Documents/my-project")" \
      || { echo "No path provided. Exiting."; exit 1; }
  else
    PROJECT_DIR="$PROJECT_CHOICE"
  fi
  PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"

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

# Same as log(), but file only — for startup detail that would clutter the
# screen before the first menu.
logf() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
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
  [ -n "$SPRINT_NAME" ] || SPRINT_NAME="Current Sprint"
}

# ── Overview screen ─────────────────────────────────────────────────────────
# The orchestrator tab is a live status board, not a scrolling log: every task
# in sprint_plan.md with its state. Re-rendered whenever that state changes.
#   render_overview [running|idle] [FOOTER...]
# In "running" mode the first open task is marked in-flight (that's the one the
# task tab picks up).
render_overview() {
  local mode="${1:-idle}"; shift || true
  get_sprint_display_info

  local done_n=0 total_n=0 marked=0
  local -a rows
  local line box id name glyph colour
  while IFS= read -r line; do
    box=$(printf '%s' "$line" | sed -n 's/^[[:space:]]*-[[:space:]]*\[\(.\)\].*/\1/p')
    id=$(printf '%s' "$line" | sed -n 's/.*\*\*#\([0-9][0-9]*\)\*\*.*/\1/p')
    name=$(printf '%s' "$line" \
      | sed -e 's/^[[:space:]]*-[[:space:]]*\[.\][[:space:]]*//' \
            -e 's/\*\*#[0-9][0-9]*\*\*[[:space:]]*//' -e 's/^[-–—[:space:]]*//')
    [ ${#name} -gt 58 ] && name="${name:0:55}..."
    total_n=$((total_n + 1))
    case "$box" in
      x|X) glyph="[x]"; colour="38;5;42";  done_n=$((done_n + 1)) ;;
      *)
        if [ "$mode" = running ] && [ "$marked" -eq 0 ]; then
          glyph="[>]"; colour="1;38;5;${RALPH_UI_ACCENT}"; marked=1
        else
          glyph="[ ]"; colour="38;5;244"
        fi
        ;;
    esac
    rows+=("$(printf '\033[%sm  %s  #%-3s %s\033[0m' "$colour" "$glyph" "${id:-?}" "$name")")
  done < <(grep -E '^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*\*\*#[0-9]+\*\*' "$FIX_PLAN" 2>/dev/null || true)

  printf '\033[2J\033[3J\033[H'
  ui_banner info "Ralph  ·  ${SPRINT_NAME}" \
    "${PROJECT_NAME}   ·   $done_n of $total_n done   ·   $(ralph_model_sprint_label "$RALPH_MODEL")"

  if [ "$total_n" -eq 0 ]; then
    printf '  (no numbered tasks found in sprint_plan.md)\n'
  else
    printf '%s\n' "${rows[@]}"
  fi

  local elapsed_min=$(( ($(date +%s) - ${START_TIME:-$(date +%s)}) / 60 ))
  printf '\n\033[38;5;244m  %s min elapsed   ·   log: %s\033[0m\n' \
    "$elapsed_min" "$(basename "$LOG_FILE")"
  [ $# -gt 0 ] && printf '\n%s\n' "$@"
  return 0
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
  if [ "${TERM_PROGRAM:-}" = "iTerm.app" ]; then
    echo "iterm"
  elif [ "${TERM_PROGRAM:-}" = "Apple_Terminal" ]; then
    echo "terminal"
  elif [ "${TERM_PROGRAM:-}" = "vscode" ] && [[ "${OSTYPE:-}" == "darwin"* ]]; then
    # VS Code sets TERM_PROGRAM=vscode on every OS; only the macOS integrated
    # terminal can hand off to Terminal.app/iTerm. Off macOS, fall through to the
    # Windows Terminal / inline detection below.
    echo "vscode"
  elif command -v wt.exe &> /dev/null && [ -n "${WT_SESSION:-}" ]; then
    echo "windows-terminal"
  else
    # Default to Terminal.app on macOS
    if [[ "${OSTYPE:-}" == "darwin"* ]]; then
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
  date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S' > "$MARKER_DIR/task-${task_num}-start"
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  WRAPPER="$SCRIPT_DIR/ralph-task-wrapper.sh"
}

# Spawn Claude in a new terminal window (macOS Terminal.app)
# Uses 'do script' without keystroke to avoid accessibility permission requirements
spawn_in_terminal() {
  local task_num=$1
  prepare_task_env "$task_num"

  local launcher="${TMPDIR:-/tmp}/ralph-task-${task_num}.sh"
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

  local launcher="${TMPDIR:-/tmp}/ralph-task-${task_num}.sh"
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

  local launcher="${TMPDIR:-/tmp}/ralph-task-${task_num}.sh"
  local spawned_marker="$MARKER_DIR/task-${task_num}-spawned"
  rm -f "$spawned_marker"
  cat > "$launcher" << LAUNCHER
#!/bin/bash
touch "$spawned_marker"
rm -f "$launcher"
exec "$WRAPPER" "$task_num" "$PROJECT_DIR" "$TASK_START_TS" "$MARKER_DIR" "$RALPH_MODEL"
LAUNCHER
  chmod +x "$launcher"

  # wt.exe is a Win32 process: it resolves `bash` against the *new tab's* PATH,
  # not this shell's, and `bash` is often not on the persistent Windows PATH.
  # Pass an explicit interpreter, converted to a Windows path for wt.exe.
  local bash_exe="" cand
  for cand in "$(command -v bash 2>/dev/null)" \
              "/c/Program Files/Git/bin/bash.exe" \
              "/c/Program Files/Git/usr/bin/bash.exe"; do
    if [ -n "$cand" ] && [ -x "$cand" ]; then bash_exe="$cand"; break; fi
  done
  [ -z "$bash_exe" ] && bash_exe="bash"
  if command -v cygpath &> /dev/null; then
    bash_exe="$(cygpath -w "$bash_exe" 2>/dev/null || echo "$bash_exe")"
  fi

  # wt.exe returns 0 even when the in-tab command never starts, so its exit code
  # can't gate the fallback. The launcher touches "$spawned_marker" as its first
  # action; if that never appears, treat the spawn as failed so the caller drops
  # to inline mode instead of blocking on wait_for_completion for the full
  # task timeout.
  MSYS_NO_PATHCONV=1 wt.exe new-tab -w 0 --profile "$RALPH_WT_PROFILE" \
    --title "Ralph: Task ${task_num}" \
    "$bash_exe" -l "$launcher" 2>>"$LOG_FILE" || true

  if wait_for_marker "$spawned_marker" 15; then
    return 0
  fi

  echo "⚠️  Windows Terminal tab did not start."
  echo "   Check that a profile named '$RALPH_WT_PROFILE' exists (set RALPH_WT_PROFILE"
  echo "   to match yours) and that Git Bash is installed. Falling back to inline mode..."
  return 1
}

# A Git Bash interpreter as a Windows path (wt.exe resolves `bash` against the
# new tab's PATH, where it often isn't).
_resolve_wt_bash() {
  local cand
  for cand in "$(command -v bash 2>/dev/null)" \
              "/c/Program Files/Git/bin/bash.exe" \
              "/c/Program Files/Git/usr/bin/bash.exe"; do
    if [ -n "$cand" ] && [ -x "$cand" ]; then
      command -v cygpath >/dev/null 2>&1 && cygpath -w "$cand" 2>/dev/null || printf '%s\n' "$cand"
      return 0
    fi
  done
  printf 'bash\n'
}

# Open /ralph-plan in its own Windows Terminal tab titled "Ralph: Plan".
# Returns 0 if the tab started, 1 otherwise.
spawn_plan_tab() {
  local launcher="${TMPDIR:-/tmp}/ralph-plan.sh"
  local spawned="${TMPDIR:-/tmp}/ralph-plan-spawned"
  rm -f "$spawned"
  cat > "$launcher" <<LAUNCHER
#!/bin/bash
touch "$spawned"
rm -f "$launcher"
cd "$PROJECT_DIR" || exit 1
claude --dangerously-skip-permissions --model "$RALPH_MODEL" "/ralph-plan

Project directory: $PROJECT_DIR"
echo ""
echo "Plan written. Close this tab, then re-run Ralph to start the sprint."
exec bash -li
LAUNCHER
  chmod +x "$launcher"
  local bash_exe; bash_exe="$(_resolve_wt_bash)"
  MSYS_NO_PATHCONV=1 wt.exe new-tab -w 0 --profile "$RALPH_WT_PROFILE" \
    --title "Ralph: Plan" "$bash_exe" -l "$launcher" 2>>"$LOG_FILE" || true
  wait_for_marker "$spawned" 15
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
  local fail_marker="$MARKER_DIR/task-failed"
  # Historic default is 60 minutes. Project config may set RALPH_TASK_TIMEOUT_MINUTES.
  local timeout_min="${RALPH_TASK_TIMEOUT_MINUTES:-60}"
  local timeout=$((timeout_min * 60))

  # Remove old markers before starting
  rm -f "$marker_file" "$fail_marker"

  render_overview running "$(printf '\033[1;38;5;%sm  Run %s in progress — watch the "Ralph: Task %s" tab\033[0m\n\033[38;5;244m  Ctrl+C there to stop it.\033[0m' \
    "$RALPH_UI_ACCENT" "$task_num" "$task_num")"
  wait_for_marker "$marker_file" "$timeout" "$fail_marker"
}

# Header
ui_title "Ralph: Overview"
ui_banner info "Ralph Continuous" "Watch Claude work - diffs, reasoning, one tab per task"

TERMINAL_TYPE=$(detect_terminal)
logf "Starting Ralph Continuous (terminal type: ${TERMINAL_TYPE})"
logf "Project: ${PROJECT_DIR}"
logf "Fix Plan: ${FIX_PLAN}"

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
  logf "Configuration loaded"
fi

# ── Update check ────────────────────────────────────────────────────────────
check_for_updates() {
  command -v git >/dev/null 2>&1 || return
  local kit_dir
  kit_dir="$(cd "$(dirname "$0")/.." && pwd)"
  git -C "$kit_dir" rev-parse --git-dir >/dev/null 2>&1 || return

  # Compare against THIS checkout's own upstream, not a hard-coded origin/main.
  # Hard-coding it loops forever whenever the kit is on any other branch (or
  # main has moved past what this checkout has): the prompt keeps firing, but a
  # pull on the current branch never closes the gap.
  local upstream
  upstream="$(git -C "$kit_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)" || return

  git -C "$kit_dir" fetch --quiet 2>/dev/null || return
  local behind
  behind=$(git -C "$kit_dir" rev-list "HEAD..$upstream" --count 2>/dev/null || echo 0)
  [ "${behind:-0}" -eq 0 ] 2>/dev/null && return

  ui_banner info "Ralph update available" \
    "$behind update$([ "$behind" -gt 1 ] && echo s) on $upstream"

  local UPD="Update now" VIEW="View what changed" SKIP="Skip for now" pick
  while :; do
    pick="$(ui_choose "Update Ralph?" "$UPD" "$VIEW" "$SKIP")" || pick="$SKIP"
    case "$pick" in
      "$VIEW") ui_pager "$kit_dir/CHANGELOG.md" ;;   # q returns here
      "$SKIP")
        echo "Skipped. Update later with:  git -C \"$kit_dir\" pull"
        return
        ;;
      *) break ;;                                     # "Update now"
    esac
  done

  local before after
  before="$(git -C "$kit_dir" rev-parse HEAD 2>/dev/null)"
  if ! ( cd "$kit_dir" && git merge --ff-only --quiet "$upstream" ); then
    ui_banner err "Couldn't fast-forward" \
      "The kit has local commits. Update by hand:  git -C \"$kit_dir\" pull --rebase"
    return
  fi
  after="$(git -C "$kit_dir" rev-parse HEAD 2>/dev/null)"
  [ "$before" = "$after" ] && return   # no-op pull — don't re-exec, don't loop

  # The merge just rewrote this running script; bash reads a script by byte
  # offset, so continuing would run garbage. Re-exec the fresh copy — the re-run
  # sees behind=0 and skips this block.
  ui_banner ok "Ralph updated" "Restarting on the new version..."
  exec bash "$0" ${RALPH_ARGV[@]+"${RALPH_ARGV[@]}"}
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

logf "Terminal: $TERMINAL_TYPE"

# Model selection — labels come from ralph_models() (ralph-portable.sh),
# the single place model choices are defined.
if [ -z "$RALPH_MODEL" ]; then
  MODEL_LABELS=()
  while IFS= read -r _label; do MODEL_LABELS+=("$_label"); done < <(ralph_model_menu_labels)

  MODEL_CHOICE="$(ui_choose "Which model should Ralph use?" "${MODEL_LABELS[@]}")" \
    || MODEL_CHOICE="${MODEL_LABELS[0]}"

  RALPH_MODEL="$(ralph_model_alias_for "$MODEL_CHOICE")"
  [ -n "$RALPH_MODEL" ] || RALPH_MODEL="sonnet"
fi

export RALPH_MODEL
echo -e "Model: ${GREEN}$(ralph_model_sprint_label "$RALPH_MODEL")${NC}  (${RALPH_MODEL})"
echo ""

# Validate project structure. A missing sprint_plan.md — or one that's still the
# unfilled template — means there's nothing to build yet; offer to plan.
plan_ready() {
  [ -f "$FIX_PLAN" ] || return 1
  ! grep -qE '\[Task name\]|\[Theme/Goal\]|\[One sentence describing' "$FIX_PLAN"
}
if ! plan_ready; then
  if [ -f "$FIX_PLAN" ]; then
    ui_banner warn "No sprint plan yet" "sprint_plan.md is still the empty template."
  else
    ui_banner warn "No sprint plan yet" "sprint_plan.md doesn't exist in this project."
  fi
  if ui_confirm "Create one now with /ralph-plan?"; then
    if [ "$TERMINAL_TYPE" = "windows-terminal" ] && spawn_plan_tab; then
      ui_banner info "Planning in a new tab" \
        "See the 'Ralph: Plan' tab." \
        "When the plan is written, start Ralph again."
    else
      # No tab support (or the spawn failed) — plan right here.
      cd "$PROJECT_DIR" || exit 1
      claude --dangerously-skip-permissions --model "$RALPH_MODEL" "/ralph-plan

Project directory: $PROJECT_DIR"
      echo ""
      echo "Plan written. Start Ralph again to run the sprint."
    fi
  else
    echo "Run  claude \"/ralph-plan\"  first, then start again."
  fi
  exit 0
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
      render_overview idle
      ui_banner warn "Sprint blocked" \
        "Every remaining task is blocked." \
        "1. Clear the blockers (environment, dependencies, ...)" \
        "2. Start Ralph again to finish them" \
        "Details: $FIX_PLAN"
      logf "Sprint blocked: $SPRINT_NAME - all remaining tasks blocked after $TASK_COUNT iterations"
      break
    fi
  fi
  
  if ! check_tasks_remain; then
    render_overview idle
    ui_banner ok "Sprint complete" \
      "Next: /ralph-archive to file it, /ralph-plan for the next one." \
      "Details: $FIX_PLAN"
    logf "All tasks complete: $SPRINT_NAME after $TASK_COUNT iterations"
    break
  fi

  if check_blocked; then
    logf "Task blocked after $TASK_COUNT iterations"

    # Check if there are any unblocked tasks remaining
    if ! check_tasks_remain; then
      render_overview idle
      ui_banner warn "Sprint paused" \
        "Every remaining task is blocked or done." \
        "Clear the blockers, then start Ralph again."
      logf "All tasks blocked or complete - stopping"
      break
    else
      render_overview idle "$(printf '\033[38;5;214m  A task is blocked — skipping to the next unblocked one.\033[0m')"
      logf "Continuing with next unblocked task"
      sleep 2
    fi
  fi

  TASK_COUNT=$((TASK_COUNT + 1))

  render_overview running "$(printf '\033[1;38;5;%sm  Run %s starting...\033[0m' \
    "$RALPH_UI_ACCENT" "$TASK_COUNT")"

  logf "Starting task #$TASK_COUNT"

  # Capture wait/spawn status without tripping set -e, so timeout cleanup runs.
  EXIT_CODE=0
  case $TERMINAL_TYPE in
    "iterm")
      spawn_in_iterm $TASK_COUNT
      wait_for_completion $TASK_COUNT || EXIT_CODE=$?
      ;;
    "terminal")
      spawn_in_terminal $TASK_COUNT
      wait_for_completion $TASK_COUNT || EXIT_CODE=$?
      ;;
    "windows-terminal")
      if spawn_in_windows_terminal $TASK_COUNT; then
        wait_for_completion $TASK_COUNT || EXIT_CODE=$?
      else
        # Fallback to inline if tab spawning failed
        echo "ℹ️  Running in inline mode - tasks will execute sequentially in this window."
        spawn_inline $TASK_COUNT || EXIT_CODE=$?
      fi
      ;;
    *)
      echo "ℹ️  Terminal tab spawning not available in this environment"
      echo "   (Supported: iTerm2, Terminal.app, VS Code, Windows Terminal)"
      echo "   Running in inline mode - tasks will execute sequentially in this window."
      echo ""
      spawn_inline $TASK_COUNT || EXIT_CODE=$?
      ;;
  esac

  if [ $EXIT_CODE -ne 0 ]; then
    render_overview idle
    ui_banner err "Run $TASK_COUNT failed or timed out" \
      "Check the 'Ralph: Task $TASK_COUNT' tab for what happened." \
      "Fix it, then start Ralph again to resume."
    logf "Error: Task #$TASK_COUNT failed after $TASK_COUNT iterations"
    # Do not leave a stale sprint-complete marker for the next run
    rm -f "$MARKER_DIR/sprint-complete" "$MARKER_DIR/task-done" "$MARKER_DIR/task-failed"
    rm -rf "$MARKER_DIR"
    break
  fi

  logf "Task #$TASK_COUNT complete, context reset"

  render_overview idle "$(printf '\033[38;5;42m  Run %s complete.\033[0m \033[38;5;244mNext task starting...\033[0m' \
    "$TASK_COUNT")"
  sleep 3
done

# Cleanup
rm -rf "$MARKER_DIR"

# Summary
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

ui_banner info "Session summary" \
  "Runs attempted: $TASK_COUNT" \
  "Total time:     ${MINUTES}m ${SECONDS}s" \
  "Log:            $LOG_FILE"
