#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

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
echo -e "${BLUE}  Started: $(date -r "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Change to project directory
cd "$PROJECT_DIR" || {
  echo "Error: Cannot change to directory $PROJECT_DIR" >&2
  exit 1
}

# Model label and pricing (single source of truth)
case "${RALPH_MODEL:-default}" in
  opus)
    RALPH_MODEL_LABEL="Opus 4.6"
    RALPH_INPUT_RATE="15"; RALPH_OUTPUT_RATE="75"
    RALPH_CACHE_WRITE_RATE="18.75"; RALPH_CACHE_READ_RATE="1.50"
    RALPH_COST_PER_MIN="0.05"
    ;;
  opus-1m)
    RALPH_MODEL_LABEL="Opus 4.6 (1M)"
    RALPH_INPUT_RATE="15"; RALPH_OUTPUT_RATE="75"
    RALPH_CACHE_WRITE_RATE="18.75"; RALPH_CACHE_READ_RATE="1.50"
    RALPH_COST_PER_MIN="0.08"
    ;;
  sonnet-1m)
    RALPH_MODEL_LABEL="Sonnet 4.5 (1M)"
    RALPH_INPUT_RATE="3"; RALPH_OUTPUT_RATE="15"
    RALPH_CACHE_WRITE_RATE="3.75"; RALPH_CACHE_READ_RATE="0.30"
    RALPH_COST_PER_MIN="0.05"
    ;;
  haiku)
    RALPH_MODEL_LABEL="Haiku 4.5"
    RALPH_INPUT_RATE="0.80"; RALPH_OUTPUT_RATE="4.00"
    RALPH_CACHE_WRITE_RATE="1.00"; RALPH_CACHE_READ_RATE="0.08"
    RALPH_COST_PER_MIN="0.01"
    ;;
  *)
    RALPH_MODEL_LABEL="Sonnet 4.5 (default)"
    RALPH_INPUT_RATE="3"; RALPH_OUTPUT_RATE="15"
    RALPH_CACHE_WRITE_RATE="3.75"; RALPH_CACHE_READ_RATE="0.30"
    RALPH_COST_PER_MIN="0.03"
    ;;
esac
readonly RALPH_MODEL_LABEL RALPH_INPUT_RATE RALPH_OUTPUT_RATE \
  RALPH_CACHE_WRITE_RATE RALPH_CACHE_READ_RATE RALPH_COST_PER_MIN

# Generate a session ID so we can parse exact token usage afterwards
readonly SESSION_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"
# Session file path (single definition; used by post-processing and summary)
readonly ENCODED_PROJECT="${PROJECT_DIR//\//-}"
readonly SESSION_FILE="$HOME/.claude/projects/${ENCODED_PROJECT}/${SESSION_ID}.jsonl"

# Build Claude command with optional model selection
CLAUDE_ARGS=("claude" "--dangerously-skip-permissions" "--max-turns" "50" "--session-id" "$SESSION_ID")
if [ -n "$RALPH_MODEL" ]; then
  CLAUDE_ARGS+=("--model" "$RALPH_MODEL")
fi
echo -e "Model: ${GREEN}${RALPH_MODEL_LABEL}${NC}"
echo -e "Session: ${SESSION_ID}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# BACKGROUND WATCHER: monitors for claude-done, runs post-processing, touches task-done
# This runs in a subshell so Claude can stay interactive while post-processing
# happens automatically when Claude signals completion.
# ═══════════════════════════════════════════════════════════════════════════════

readonly CLAUDE_DONE_MARKER="$MARKER_DIR/task-${TASK_NUM}-claude-done"
readonly TASK_DONE_MARKER="$MARKER_DIR/task-done"
readonly SUMMARY_FILE="$MARKER_DIR/task-${TASK_NUM}-summary.txt"

# Remove stale markers and summary file from any previous run
rm -f "$CLAUDE_DONE_MARKER" "$TASK_DONE_MARKER" "$SUMMARY_FILE"

# Ensure cost string has leading zero (e.g. .25 -> 0.25)
ensure_leading_zero() {
  local v="$1"
  [[ "$v" == .* ]] && echo "0$v" || echo "$v"
}

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
  
  # Parse exact token usage from Claude session JSONL file (SESSION_FILE defined at top level)
  local input_tokens=0
  local output_tokens=0
  local cache_creation_tokens=0
  local cache_read_tokens=0
  local cost_est="0.00"
  local cost_source="est"

  echo "Looking for session file: $SESSION_FILE" >> "$debug_log"

  if [ -f "$SESSION_FILE" ]; then
    # Parse exact token counts from session JSONL using Python
    local token_data
    token_data=$(python3 -c "
import json, sys
input_tok = output_tok = cache_create = cache_read = 0
turns = 0
with open('$SESSION_FILE') as f:
    for line in f:
        obj = json.loads(line)
        msg = obj.get('message', {})
        if isinstance(msg, dict) and 'usage' in msg:
            u = msg['usage']
            turns += 1
            input_tok += u.get('input_tokens', 0)
            output_tok += u.get('output_tokens', 0)
            cache_create += u.get('cache_creation_input_tokens', 0)
            cache_read += u.get('cache_read_input_tokens', 0)
print(f'{input_tok} {output_tok} {cache_create} {cache_read} {turns}')
" 2>/dev/null)

    if [ -n "$token_data" ]; then
      input_tokens=$(echo "$token_data" | awk '{print $1}')
      output_tokens=$(echo "$token_data" | awk '{print $2}')
      cache_creation_tokens=$(echo "$token_data" | awk '{print $3}')
      cache_read_tokens=$(echo "$token_data" | awk '{print $4}')
      local api_turns
      api_turns=$(echo "$token_data" | awk '{print $5}')

      if [ "$output_tokens" -gt 0 ] 2>/dev/null; then
        # Calculate exact cost using centralized Anthropic pricing (RALPH_*_RATE)
        cost_est=$(awk "BEGIN {printf \"%.2f\", \
          ($input_tokens / 1000000) * $RALPH_INPUT_RATE + \
          ($output_tokens / 1000000) * $RALPH_OUTPUT_RATE + \
          ($cache_creation_tokens / 1000000) * $RALPH_CACHE_WRITE_RATE + \
          ($cache_read_tokens / 1000000) * $RALPH_CACHE_READ_RATE}")
        cost_est=$(ensure_leading_zero "$cost_est")
        cost_source="actual"
        echo "Session token usage (${api_turns} API turns):" >> "$debug_log"
        echo "  Input:          ${input_tokens}" >> "$debug_log"
        echo "  Output:         ${output_tokens}" >> "$debug_log"
        echo "  Cache creation: ${cache_creation_tokens}" >> "$debug_log"
        echo "  Cache read:     ${cache_read_tokens}" >> "$debug_log"
        echo "  Cost:           \$${cost_est}" >> "$debug_log"
      fi
    else
      echo "Python token parsing failed" >> "$debug_log"
    fi
  else
    echo "Session file not found: $SESSION_FILE" >> "$debug_log"
  fi

  # Fall back to duration-based estimate if token parsing failed (use centralized RALPH_COST_PER_MIN)
  if [ "$cost_source" = "est" ]; then
    if command -v bc &> /dev/null; then
      cost_est=$(echo "scale=2; $task_duration * $RALPH_COST_PER_MIN" | bc)
    else
      cost_est=$(awk "BEGIN {printf \"%.2f\", $task_duration * $RALPH_COST_PER_MIN}")
    fi
    cost_est=$(ensure_leading_zero "$cost_est")
    echo "Duration-based cost estimate (token parsing failed): \$${cost_est}" >> "$debug_log"
  fi
  
  local duration_diff=$((task_end_ts - TASK_START_TS))
  local duration_decimal
  duration_decimal=$(awk "BEGIN {printf \"%.1f\", $duration_diff / 60}")
  
  echo "Duration: ${task_duration} min, Cost: \$${cost_est}, Model: ${RALPH_MODEL_LABEL}, Source: ${cost_source}" >> "$debug_log"
  
  # ── 1. Add cost data to Completed section Performance lines ──
  # Performance data lives in the Completed section only (no duplication in Tasks).
  # Shell is source of truth for cost/tokens. Handles two cases:
  #   a) Claude wrote SHELL_WILL_UPDATE → replace with full performance line
  #   b) Claude wrote partial data like "5 min | Opus 4.6" (no $) → append cost
  # Both cases only target lines AFTER "## Completed" heading.
  if [ -f "$sprint_plan" ]; then
    local cost_str
    if [ "$cost_source" = "actual" ]; then
      cost_str="\$${cost_est} (${input_tokens} in / ${output_tokens} out / ${cache_creation_tokens} cache-write / ${cache_read_tokens} cache-read)"
    else
      cost_str="~\$${cost_est} est"
    fi

    local full_perf="**Performance:** ${task_duration} min | ${RALPH_MODEL_LABEL} | ${cost_str}"
    local calc_line="    - Duration calc: (${task_end_ts} - ${TASK_START_TS}) \/ 60 = ${duration_diff} \/ 60 = ${duration_decimal} min"
    local ts_line="    - Timestamps: start=${TASK_START_TS}, end=${task_end_ts}"

    # Single pass: replace SHELL_WILL_UPDATE or append cost to partial Performance lines in Completed section
    awk -v perf="$full_perf" -v calc="$calc_line" -v ts="$ts_line" -v cost_append=" | ${cost_str}" '
      /^## Completed/ { in_completed = 1 }
      in_completed && /\*\*Performance:\*\* SHELL_WILL_UPDATE/ {
        print "  - " perf
        print calc
        print ts
        next
      }
      in_completed && /\*\*Performance:\*\*/ && (index($0, "$") == 0) {
        sub(/[ \t]*$/, "")
        print $0 cost_append
        next
      }
      { print }
    ' "$sprint_plan" > "${sprint_plan}.tmp" && mv "${sprint_plan}.tmp" "$sprint_plan"
    echo "✓ Performance lines updated in Completed section" >> "$debug_log"
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
    
    # Sum costs (match token-based, duration est, and legacy formats)
    # Patterns: "$2.45 (123 in", "~$0.25 est", "$.25 est"
    local total_cost
    total_cost=$({ grep -oE "~?\\\$[0-9]*\.[0-9]+ (est|\([0-9]+ in)" "$sprint_plan" 2>/dev/null \
      | grep -oE "[0-9]*\.[0-9]+" | awk '{sum+=$1} END {printf "%.2f", sum+0}'; } || true)
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
    
    # Update summary section in a single pass (only if we have completed tasks)
    if [ "$completed_count" -gt 0 ]; then
      awk -v completed="$completed_count" -v total_tasks="$total_tasks" \
          -v total_duration="$total_duration" -v total_cost="$total_cost" \
          -v avg_duration="$avg_duration" -v avg_cost="$avg_cost" '
        /^\*\*Completed:\*\* / { $0 = "**Completed:** " completed "/" total_tasks " tasks"; print; next }
        /^\*\*Completed so far:\*\* / { $0 = "**Completed so far:** " completed "/" total_tasks " tasks"; print; next }
        /^\*\*Total duration:\*\* / { $0 = "**Total duration:** " total_duration " min"; print; next }
        /^\*\*Total cost:\*\* / { $0 = "**Total cost:** $" total_cost; print; next }
        /^\*\*Avg per task:\*\* / { $0 = "**Avg per task:** " avg_duration " min / $" avg_cost; print; next }
        { print }
      ' "$sprint_plan" > "${sprint_plan}.tmp" && mv "${sprint_plan}.tmp" "$sprint_plan"
      echo "✓ Sprint totals: ${completed_count}/${total_tasks}, ${total_duration} min, \$${total_cost}" >> "$debug_log"
    fi
  fi

  # Write summary file for main script (avoids re-parsing session file for display)
  {
    echo "TASK_DURATION=$task_duration"
    echo "COST_EST=$cost_est"
    echo "COST_SOURCE=$cost_source"
    echo "INPUT_TOKENS=$input_tokens"
    echo "OUTPUT_TOKENS=$output_tokens"
    echo "CACHE_CREATION_TOKENS=$cache_creation_tokens"
    echo "CACHE_READ_TOKENS=$cache_read_tokens"
  } > "$SUMMARY_FILE" 2>/dev/null || true

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
CLAUDE_LOG="$MARKER_DIR/task-${TASK_NUM}-claude-output.log"
PROMPT=$(cat <<EOF
/ralph

Implement task #${TASK_NUM} from sprint_plan.md. When that task is done, touch $CLAUDE_DONE_MARKER and stop. Do not start or continue to any other task in this session.

If the entire sprint is complete (no unchecked tasks left): touch $MARKER_DIR/sprint-complete && touch $CLAUDE_DONE_MARKER
EOF
)

# Capture stderr to log file while still displaying it live (maintains full visibility)
"${CLAUDE_ARGS[@]}" "$PROMPT" 2> >(tee "$CLAUDE_LOG" >&2) || CLAUDE_EXIT=$?

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

# Show completion summary (from post-processing summary file or duration-based fallback)
TASK_END_TS=$(date +%s)
TASK_DURATION=$(( (TASK_END_TS - TASK_START_TS) / 60 ))
if [ "$TASK_DURATION" -lt 1 ]; then TASK_DURATION=1; fi

# Prefer summary file written by run_post_processing (single source of truth; no re-parse)
DISPLAY_COST_SOURCE="est"
DISPLAY_COST=""
DISPLAY_TOKENS=""
if [ -f "$SUMMARY_FILE" ]; then
  # shellcheck source=/dev/null
  source "$SUMMARY_FILE"
  DISPLAY_COST="$COST_EST"
  DISPLAY_COST_SOURCE="$COST_SOURCE"
  if [ "$DISPLAY_COST_SOURCE" = "actual" ]; then
    FMT_INPUT=$(printf "%'d" "${INPUT_TOKENS:-0}")
    FMT_OUTPUT=$(printf "%'d" "${OUTPUT_TOKENS:-0}")
    FMT_CACHE_W=$(printf "%'d" "${CACHE_CREATION_TOKENS:-0}")
    FMT_CACHE_R=$(printf "%'d" "${CACHE_READ_TOKENS:-0}")
    DISPLAY_TOKENS="exact"
  fi
fi
# Fallback when summary file missing (e.g. post-processing failed)
if [ -z "$DISPLAY_COST" ]; then
  DISPLAY_COST=$(awk "BEGIN {printf \"%.2f\", $TASK_DURATION * $RALPH_COST_PER_MIN}")
  DISPLAY_COST=$(ensure_leading_zero "$DISPLAY_COST")
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Task Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Started:  $(date -r "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')"
echo -e "  Ended:    $(date -r "$TASK_END_TS" '+%Y-%m-%d %H:%M:%S')"
echo -e "  Duration: ${TASK_DURATION} min"
echo -e "  Model:    ${RALPH_MODEL_LABEL}"
if [ "$DISPLAY_TOKENS" = "exact" ]; then
  echo -e "  Cost:     \$${DISPLAY_COST} (exact)"
  echo -e "  Tokens:   ${FMT_INPUT} in / ${FMT_OUTPUT} out / ${FMT_CACHE_W} cache-write / ${FMT_CACHE_R} cache-read"
else
  echo -e "  Cost:     \$${DISPLAY_COST} (estimated)"
fi
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Close tab when ready${NC}"
echo ""

echo "Wrapper completed at $(date '+%Y-%m-%d %H:%M:%S')" >&3
echo "═══════════════════════════════════════════════════════════" >&3
exec 3>&-
