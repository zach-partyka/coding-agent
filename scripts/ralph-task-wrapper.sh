#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ─── Cross-platform helpers ─────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed_i() { sed -i '' "$@"; }
  date_fmt() { date -r "$1" "$2"; }
else
  sed_i() { sed -i "$@"; }
  date_fmt() { date -d "@$1" "$2"; }
fi
# ─────────────────────────────────────────────────────────────────────────────

# Ralph task wrapper - provides clean terminal UI + background post-processing
# Called by ralph-continuous.sh for each task
#
# Architecture (Approach 2 - background watcher):
#   1. Wrapper starts background watcher that monitors for claude-done marker
#   2. Claude runs INTERACTIVELY (user can redirect/interrupt)
#   3. When Claude finishes task, it touches claude-done marker
#   4. Background watcher detects claude-done, runs post-processing
#      (SHELL_WILL_UPDATE replacement, sprint totals), then touches task-done
#   5. Orchestrator sees task-done and spawns next tab
#   6. If user exits Claude manually, wrapper also triggers background watcher

if [ $# -lt 4 ]; then
  echo "ERROR: Not enough arguments (need at least 4, got $#)" >&2
  echo "Usage: $0 TASK_NUM PROJECT_DIR TASK_START_TS MARKER_DIR [RALPH_MODEL]" >&2
  exit 1
fi

readonly TASK_NUM="$1"
readonly PROJECT_DIR="$2"
readonly TASK_START_TS="$3"
readonly MARKER_DIR="$4"
readonly RALPH_MODEL="${5:-}"  # Optional: model to use

# Colors
readonly BLUE='\033[0;34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Create debug log file
readonly DEBUG_LOG="$PROJECT_DIR/.ralph-wrapper-debug.log"
exec 3>>"$DEBUG_LOG"
echo "═══════════════════════════════════════════════════════════" >&3
echo "Wrapper started: $(date '+%Y-%m-%d %H:%M:%S')" >&3
echo "Task: #$TASK_NUM" >&3
echo "PID: $$" >&3
echo "Architecture: Approach 2 (background watcher)" >&3
echo "═══════════════════════════════════════════════════════════" >&3

# Clear screen AND scrollback buffer immediately (hides command echo)
printf '\033[2J\033[3J\033[H'

# Display clean banner
PROJECT_NAME=$(basename "$PROJECT_DIR")
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Ralph Task #${TASK_NUM}${NC}"
echo -e "${BLUE}  Project: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}  Started: $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Change to project directory
cd "$PROJECT_DIR" || {
  echo "Error: Cannot change to directory $PROJECT_DIR" >&2
  exit 1
}

# Deterministic model version string for display and prompt
case "${RALPH_MODEL:-default}" in
  opus)       RALPH_MODEL_LABEL="Opus 4.6" ;;
  opus-1m)    RALPH_MODEL_LABEL="Opus 4.6 (1M)" ;;
  sonnet-1m)  RALPH_MODEL_LABEL="Sonnet 4.5 (1M)" ;;
  haiku)      RALPH_MODEL_LABEL="Haiku 4.5" ;;
  *)          RALPH_MODEL_LABEL="Sonnet 4.5 (default)" ;;
esac

# Build Claude command with optional model selection
CLAUDE_ARGS=("claude" "--dangerously-skip-permissions" "--max-turns" "50")
if [ -n "$RALPH_MODEL" ]; then
  CLAUDE_ARGS+=("--model" "$RALPH_MODEL")
fi
echo -e "Model: ${GREEN}${RALPH_MODEL_LABEL}${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# BACKGROUND WATCHER: monitors for claude-done, runs post-processing, touches task-done
# This runs in a subshell so Claude can stay interactive while post-processing
# happens automatically when Claude signals completion.
# ═══════════════════════════════════════════════════════════════════════════════

readonly CLAUDE_DONE_MARKER="$MARKER_DIR/task-${TASK_NUM}-claude-done"
readonly TASK_DONE_MARKER="$MARKER_DIR/task-done"

# Remove stale markers
rm -f "$CLAUDE_DONE_MARKER" "$TASK_DONE_MARKER"

run_post_processing() {
  # This function runs post-processing (SHELL_WILL_UPDATE replacement + sprint totals)
  # Called by background watcher OR by wrapper after Claude exits manually
  
  local debug_log="$PROJECT_DIR/.ralph-wrapper-debug.log"
  local sprint_plan="$PROJECT_DIR/sprint_plan.md"
  
  echo "Post-processing started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$debug_log"
  
  # Capture end time and calculate duration
  local task_end_ts
  task_end_ts=$(date +%s)
  local task_duration=$(( (task_end_ts - TASK_START_TS) / 60 ))
  
  # Minimum 1 min
  if [ "$task_duration" -lt 1 ]; then
    task_duration=1
  fi
  
  # Cost estimate based on model
  local cost_per_min
  case "${RALPH_MODEL:-default}" in
    opus)       cost_per_min="0.05" ;;
    opus-1m)    cost_per_min="0.08" ;;
    sonnet-1m)  cost_per_min="0.05" ;;
    haiku)      cost_per_min="0.01" ;;
    *)          cost_per_min="0.03" ;;
  esac
  
  local cost_est
  if command -v bc &> /dev/null; then
    cost_est=$(echo "scale=2; $task_duration * $cost_per_min" | bc)
  else
    cost_est=$(awk "BEGIN {printf \"%.2f\", $task_duration * $cost_per_min}")
  fi
  
  local duration_diff=$((task_end_ts - TASK_START_TS))
  local duration_decimal
  duration_decimal=$(awk "BEGIN {printf \"%.1f\", $duration_diff / 60}")
  
  echo "Duration: ${task_duration} min, Cost: \$${cost_est}, Model: ${RALPH_MODEL_LABEL}" >> "$debug_log"
  
  # ── 1. Replace SHELL_WILL_UPDATE placeholder ──
  if [ -f "$sprint_plan" ] && grep -q "SHELL_WILL_UPDATE" "$sprint_plan"; then
    local perf_line="**Performance:** ${task_duration} min | ${RALPH_MODEL_LABEL} | \$${cost_est} est"
    local calc_line="    - Duration calc: (${task_end_ts} - ${TASK_START_TS}) \/ 60 = ${duration_diff} \/ 60 = ${duration_decimal} min"
    local ts_line="    - Timestamps: start=${TASK_START_TS}, end=${task_end_ts}"
    
    # Replace FIRST occurrence only
    awk -v perf="$perf_line" -v calc="$calc_line" -v ts="$ts_line" '
      !replaced && /\*\*Performance:\*\* SHELL_WILL_UPDATE/ {
        print "  - " perf
        print calc
        print ts
        replaced = 1
        next
      }
      { print }
    ' "$sprint_plan" > "${sprint_plan}.tmp" && mv "${sprint_plan}.tmp" "$sprint_plan"
    
    echo "✓ Performance placeholder replaced" >> "$debug_log"
  fi
  
  # ── 2. Update sprint totals ──
  if [ -f "$sprint_plan" ]; then
    # Count completed tasks
    local completed_count
    completed_count=$(grep -cE "^\s*-\s*\[x\]\s*\*\*#[0-9]+\*\*" "$sprint_plan" 2>/dev/null || echo 0)
    if [ "$completed_count" -eq 0 ]; then
      local completed_line
      completed_line=$(grep -n "^## Completed" "$sprint_plan" 2>/dev/null | head -1 | cut -d: -f1 || true)
      if [ -n "$completed_line" ]; then
        completed_count=$(tail -n +"$completed_line" "$sprint_plan" | grep -cE "^\s*-\s*\*\*#[0-9]+\*\*" 2>/dev/null || echo 0)
      fi
    fi
    
    # Sum durations from Performance lines
    local total_duration
    total_duration=$({ grep -oE "\*\*Performance:\*\* [0-9]+ min" "$sprint_plan" 2>/dev/null \
      | grep -oE "[0-9]+" | awk '{sum+=$1} END {print sum+0}'; } || true)
    total_duration="${total_duration:-0}"
    
    # Sum costs
    local total_cost
    total_cost=$({ grep -oE "\\\$[0-9]+\.[0-9]+ est" "$sprint_plan" 2>/dev/null \
      | grep -oE "[0-9]+\.[0-9]+" | awk '{sum+=$1} END {printf "%.2f", sum+0}'; } || true)
    total_cost="${total_cost:-0.00}"
    
    # Averages
    local avg_duration=0
    local avg_cost="0.00"
    if [ "$completed_count" -gt 0 ] && [ "$total_duration" -gt 0 ]; then
      avg_duration=$(( (total_duration + completed_count - 1) / completed_count ))
      if command -v bc &> /dev/null; then
        avg_cost=$(echo "scale=2; $total_cost / $completed_count" | bc)
      else
        avg_cost=$(awk "BEGIN {printf \"%.2f\", $total_cost / $completed_count}")
      fi
    fi
    
    # Total task count
    local total_tasks
    total_tasks=$(grep -cE "^\s*-\s*\[.\]\s*\*\*#[0-9]+\*\*" "$sprint_plan" 2>/dev/null || echo 0)
    if [ "$total_tasks" -eq 0 ]; then
      total_tasks=$(grep -cE "\*\*#[0-9]+\*\*" "$sprint_plan" 2>/dev/null || echo "?")
    fi
    
    # Update summary section (only if we have completed tasks)
    if [ "$completed_count" -gt 0 ]; then
      local tmp_file="${sprint_plan}.tmp.$$"
      
      # Completed count
      sed "s/\*\*Completed:\*\* [0-9~]*\/[0-9?]* tasks/**Completed:** ${completed_count}\/${total_tasks} tasks/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      sed "s/\*\*Completed so far:\*\* [0-9~]*\/[0-9?]* tasks/**Completed so far:** ${completed_count}\/${total_tasks} tasks/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      
      # Total duration - match numeric OR SHELL_WILL_UPDATE
      sed "s/\*\*Total duration:\*\* [0-9~.]* min/**Total duration:** ${total_duration} min/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      sed "s/\*\*Total duration:\*\* SHELL_WILL_UPDATE/**Total duration:** ${total_duration} min/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      
      # Total cost - match numeric OR SHELL_WILL_UPDATE
      if grep -q "\*\*Total cost:\*\*" "$sprint_plan"; then
        sed "s/\*\*Total cost:\*\* [~]*\\\$[0-9.]*/**Total cost:** \$${total_cost}/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
        sed "s/\*\*Total cost:\*\* SHELL_WILL_UPDATE/**Total cost:** \$${total_cost}/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      fi
      
      # Avg per task - match numeric OR SHELL_WILL_UPDATE
      if grep -q "\*\*Avg per task:\*\* .* min / \\\$" "$sprint_plan"; then
        sed "s/\*\*Avg per task:\*\* [~]*[0-9]* min \/ \\\$[0-9.]*/**Avg per task:** ${avg_duration} min \/ \$${avg_cost}/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      elif grep -q "\*\*Avg per task:\*\* .* min" "$sprint_plan"; then
        sed "s/\*\*Avg per task:\*\* [~]*[0-9]* min/**Avg per task:** ${avg_duration} min \/ \$${avg_cost}/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      elif grep -q "\*\*Avg per task:\*\* SHELL_WILL_UPDATE" "$sprint_plan"; then
        sed "s/\*\*Avg per task:\*\* SHELL_WILL_UPDATE/**Avg per task:** ${avg_duration} min \/ \$${avg_cost}/" "$sprint_plan" > "$tmp_file" && mv "$tmp_file" "$sprint_plan"
      fi
      
      echo "✓ Sprint totals: ${completed_count}/${total_tasks}, ${total_duration} min, \$${total_cost}" >> "$debug_log"
    fi
  fi
  
  echo "Post-processing complete at $(date '+%Y-%m-%d %H:%M:%S')" >> "$debug_log"
}

# ── Launch background watcher ──
(
  # Background subshell: disable set -e so individual command failures don't kill us.
  # The EXIT trap is our safety net - task-done MUST be created no matter what.
  set +e
  
  # Safety net: ALWAYS touch task-done on exit so the loop never hangs.
  # This fires on normal exit AND on error. The post-processing is best-effort;
  # the loop advancing is non-negotiable.
  trap '
    if [ ! -f "$TASK_DONE_MARKER" ]; then
      touch "$TASK_DONE_MARKER" 2>/dev/null
      echo "BG watcher: task-done created via safety trap at $(date "+%Y-%m-%d %H:%M:%S")" >> "$DEBUG_LOG" 2>/dev/null
    fi
  ' EXIT
  
  # Wait for Claude to signal task completion
  while [ ! -f "$CLAUDE_DONE_MARKER" ]; do
    sleep 2
  done
  
  echo "BG watcher: claude-done detected at $(date '+%Y-%m-%d %H:%M:%S')" >> "$DEBUG_LOG"
  
  # Small delay to let Claude finish any final file writes
  sleep 1
  
  # Run post-processing (SHELL_WILL_UPDATE replacement + sprint totals)
  # If this fails, the EXIT trap still creates task-done
  run_post_processing || echo "BG watcher: post-processing failed, continuing" >> "$DEBUG_LOG"
  
  # Signal orchestrator that task is fully done (post-processing complete)
  touch "$TASK_DONE_MARKER"
  echo "BG watcher: task-done marker created at $(date '+%Y-%m-%d %H:%M:%S')" >> "$DEBUG_LOG"
  
  # EXIT trap will see task-done exists and skip (no double-touch)
) &
BG_WATCHER_PID=$!
echo "Background watcher started (PID: $BG_WATCHER_PID)" >&3

# ═══════════════════════════════════════════════════════════════════════════════
# LAUNCH CLAUDE (interactive mode - user can redirect/interrupt)
# ═══════════════════════════════════════════════════════════════════════════════

CLAUDE_EXIT=0
PROMPT=$(cat <<EOF
/ralph

Project directory: $PROJECT_DIR
Ralph model: $RALPH_MODEL_LABEL

When task is complete: touch $CLAUDE_DONE_MARKER
If the entire sprint is complete (no unchecked tasks left): touch $MARKER_DIR/sprint-complete && touch $CLAUDE_DONE_MARKER
EOF
)

"${CLAUDE_ARGS[@]}" "$PROMPT" || CLAUDE_EXIT=$?

echo "Claude exited with code: $CLAUDE_EXIT" >&3

# ═══════════════════════════════════════════════════════════════════════════════
# POST-CLAUDE: If Claude exited (user quit manually) but didn't signal claude-done,
# trigger the background watcher now so post-processing still runs.
# ═══════════════════════════════════════════════════════════════════════════════

if [ ! -f "$CLAUDE_DONE_MARKER" ]; then
  echo "Claude exited without signaling claude-done - triggering manually" >&3
  touch "$CLAUDE_DONE_MARKER"
fi

# Wait for background watcher to finish post-processing
if kill -0 "$BG_WATCHER_PID" 2>/dev/null; then
  echo "Waiting for post-processing to complete..." >&3
  wait "$BG_WATCHER_PID" 2>/dev/null || true
fi

# Show completion summary (post-processing already done by background watcher)
TASK_END_TS=$(date +%s)
TASK_DURATION=$(( (TASK_END_TS - TASK_START_TS) / 60 ))
if [ "$TASK_DURATION" -lt 1 ]; then TASK_DURATION=1; fi

case "${RALPH_MODEL:-default}" in
  opus)       COST_PER_MIN="0.05" ;;
  opus-1m)    COST_PER_MIN="0.08" ;;
  sonnet-1m)  COST_PER_MIN="0.05" ;;
  haiku)      COST_PER_MIN="0.01" ;;
  *)          COST_PER_MIN="0.03" ;;
esac
if command -v bc &> /dev/null; then
  COST_EST=$(echo "scale=2; $TASK_DURATION * $COST_PER_MIN" | bc)
else
  COST_EST=$(awk "BEGIN {printf \"%.2f\", $TASK_DURATION * $COST_PER_MIN}")
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Task Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Started:  $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')"
echo -e "  Ended:    $(date_fmt "$TASK_END_TS" '+%Y-%m-%d %H:%M:%S')"
echo -e "  Duration: ${TASK_DURATION} min"
echo -e "  Model:    ${RALPH_MODEL_LABEL}"
echo -e "  Cost:     \$${COST_EST} (estimated)"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Close tab when ready${NC}"
echo ""

echo "Wrapper completed at $(date '+%Y-%m-%d %H:%M:%S')" >&3
echo "═══════════════════════════════════════════════════════════" >&3
exec 3>&-
