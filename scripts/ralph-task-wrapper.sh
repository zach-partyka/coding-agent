#!/bin/bash
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

# Ralph task wrapper - provides clean terminal UI + inline post-processing
# Called by ralph-continuous.sh for each task
#
# Architecture (sequential):
#   1. Write session-context.txt
#   2. Claude runs INTERACTIVELY (user can redirect/interrupt)
#   3. wait $CLAUDE_PID blocks until Claude fully exits
#   4. Non-zero agent exit: touch task-failed (not completion markers); exit with that status
#   5. If claude-done not touched, touch it (safety net for successful exits only)
#   6. run_post_processing inline (SHELL_WILL_UPDATE replacement, sprint totals)
#   7. touch task-done — orchestrator sees this and spawns next tab

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
echo "Architecture: sequential (inline post-processing)" >&3
echo "═══════════════════════════════════════════════════════════" >&3

# Clear screen AND scrollback buffer immediately (hides command echo)
printf '\033[2J\033[3J\033[H'

# Display clean banner
PROJECT_NAME=$(basename "$PROJECT_DIR")
ui_banner info "Ralph  ·  Task #${TASK_NUM}" \
  "Project: ${PROJECT_NAME}" \
  "Started: $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')"

# Change to project directory
cd "$PROJECT_DIR" || {
  echo "Error: Cannot change to directory $PROJECT_DIR" >&2
  exit 1
}

# Model label for display — from ralph_models() in ralph-portable.sh
RALPH_MODEL_LABEL="$(ralph_model_sprint_label "${RALPH_MODEL:-sonnet}")"
readonly RALPH_MODEL_LABEL

# Generate a session ID to match against statusline stats file
readonly SESSION_ID="$(generate_uuid)"

# Build Claude command - always pass explicit model so CLI doesn't use its own default (e.g. Opus)
# When RALPH_MODEL is empty we want Sonnet 4.6, so pass "sonnet" explicitly
# Interactive sessions have no model-turn cap. The orchestrator enforces
# RALPH_TASK_TIMEOUT_MINUTES instead.
CLAUDE_MODEL_FOR_CLI="${RALPH_MODEL:-sonnet}"
CLAUDE_ARGS=("claude" "--dangerously-skip-permissions" "--session-id" "$SESSION_ID" "--model" "$CLAUDE_MODEL_FOR_CLI")
echo -e "Model: ${GREEN}${RALPH_MODEL_LABEL}${NC}"
echo -e "Session: ${SESSION_ID}"
echo ""

# On Windows `claude` is a .cmd/.ps1 shim reachable only if the npm global bin is
# on the Git Bash PATH. Fail fast (and visibly) rather than deep inside the run.
if ! command -v claude >/dev/null 2>&1; then
  echo -e "${RED}'claude' is not on PATH in this shell.${NC}" >&2
  echo "  Install Claude Code (npm i -g @anthropic-ai/claude-code) or add its bin dir to PATH." >&2
  touch "$MARKER_DIR/task-failed" 2>/dev/null || true
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Post-processing (SHELL_WILL_UPDATE replacement + sprint totals) runs inline
# after Claude exits — see run_post_processing below. Markers coordinate with
# the orchestrator: this wrapper touches task-done / task-failed; the /ralph
# skill touches task-<N>-claude-done and sprint-complete.
# ═══════════════════════════════════════════════════════════════════════════════

readonly CLAUDE_DONE_MARKER="$MARKER_DIR/task-${TASK_NUM}-claude-done"
readonly TASK_DONE_MARKER="$MARKER_DIR/task-done"
readonly TASK_FAILED_MARKER="$MARKER_DIR/task-failed"
readonly SUMMARY_FILE="$MARKER_DIR/task-${TASK_NUM}-summary.txt"

# Remove stale markers and summary file from any previous run
rm -f "$CLAUDE_DONE_MARKER" "$TASK_DONE_MARKER" "$TASK_FAILED_MARKER" "$SUMMARY_FILE"

run_post_processing() {
  # This function runs post-processing (SHELL_WILL_UPDATE replacement + sprint totals)
  # Called by background watcher OR by wrapper after Claude exits manually

  local debug_log="$PROJECT_DIR/.ralph-wrapper-debug.log"
  local sprint_plan="$PROJECT_DIR/sprint_plan.md"

  echo "Post-processing started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$debug_log"

  # Read cost + duration from statusline stats file (written by statusline-command.sh on each render)
  # Missing cost stays unavailable ("-.--"), never "0.00".
  local cost_est="-.--"
  local cost_source="unavailable"
  local task_duration=1

  local stats_file="$HOME/.claude/last-session-stats.json"
  if [ -f "$stats_file" ]; then
    local stats_session
    stats_session=$(json_str "$stats_file" session_id)
    if [ "$stats_session" = "$SESSION_ID" ]; then
      local cost_raw
      cost_raw=$(json_str "$stats_file" cost_usd)
      cost_est=$(format_cost_or_unavailable "$cost_raw")
      if [ "$cost_est" != "-.--" ]; then
        cost_source="statusline"
      fi
      local duration_ms
      duration_ms=$(json_str "$stats_file" duration_ms)
      duration_ms=${duration_ms%%.*}
      [[ "$duration_ms" =~ ^[0-9]+$ ]] || duration_ms=0
      task_duration=$(( (duration_ms + 30000) / 60000 ))
      [ "$task_duration" -lt 1 ] && task_duration=1
      echo "Stats from statusline: cost=\$${cost_est}, duration=${task_duration} min" >> "$debug_log"
    else
      echo "Session ID mismatch: expected $SESSION_ID, got $stats_session" >> "$debug_log"
    fi
  else
    echo "Stats file not found: $stats_file" >> "$debug_log"
  fi

  echo "Duration: ${task_duration} min, Cost: \$${cost_est}, Source: ${cost_source}" >> "$debug_log"

  # ── 1. Add cost data to Completed section Performance lines ──
  # Performance data lives in the Completed section only (no duplication in Tasks).
  # Shell is source of truth for cost. Handles two cases:
  #   a) Claude wrote SHELL_WILL_UPDATE → replace with performance line
  #   b) Claude wrote partial data like "5 min | Opus 4.6" (no $) → replace with full line
  # Output format:
  #   - **Performance:** 7 min | $1.47
  if [ -f "$sprint_plan" ]; then
    local perf_line
    if [ "$cost_source" = "statusline" ] && [ "$cost_est" != "-.--" ]; then
      perf_line="  - **Performance:** ${task_duration} min | \$${cost_est}"
    else
      perf_line="  - **Performance:** ${task_duration} min | unavailable"
    fi

    # Write Python script to temp file (avoids quoting/interpolation issues)
    local py_script
    py_script=$(mktemp)
    cat > "$py_script" << 'PYEOF'
import re, os

perf_block = os.environ['RALPH_PERF_BLOCK']
sprint_plan = os.environ['RALPH_SPRINT_PLAN']

in_completed = False
lines = open(sprint_plan).readlines()
out = []
i = 0

while i < len(lines):
    line = lines[i]

    if re.match(r'^##\s+Completed', line):
        in_completed = True
        out.append(line)
        i += 1
        continue

    if in_completed and re.match(r'^##\s+', line) and 'Completed' not in line:
        in_completed = False
        out.append(line)
        i += 1
        continue

    if not in_completed:
        out.append(line)
        i += 1
        continue

    # In Completed section — check for task headers: - [x] ...
    if re.match(r'\s*-\s*\[x\]', line):
        task_header = line
        sub_bullets = []
        j = i + 1
        while j < len(lines):
            sub = lines[j]
            if re.match(r'\s{2,}', sub) and not re.match(r'\s*-\s*\[', sub) and not re.match(r'^##', sub):
                sub_bullets.append(sub)
                j += 1
            else:
                break

        has_perf = any('**Performance:**' in s and ('$' in s or 'unavailable' in s) for s in sub_bullets)

        if has_perf:
            # Already has final performance data — leave alone
            out.append(task_header)
            out.extend(sub_bullets)
            i = j
            continue

        # Not yet processed — strip any agent-written Performance/SHELL_WILL_UPDATE
        # lines (and their deeper-indented children), then append shell perf line
        clean_subs = []
        k = 0
        while k < len(sub_bullets):
            s = sub_bullets[k]
            if '**Performance:**' in s or 'SHELL_WILL_UPDATE' in s:
                perf_indent = len(s) - len(s.lstrip())
                k += 1
                while k < len(sub_bullets):
                    next_indent = len(sub_bullets[k]) - len(sub_bullets[k].lstrip())
                    if next_indent > perf_indent:
                        k += 1
                    else:
                        break
            else:
                clean_subs.append(s)
                k += 1

        out.append(task_header)
        out.extend(clean_subs)
        out.append(perf_block.rstrip() + '\n')
        i = j
        continue

    out.append(line)
    i += 1

with open(sprint_plan, 'w') as f:
    f.writelines(out)
PYEOF

    local py_bin
    if py_bin="$(ralph_python)"; then
      RALPH_PERF_BLOCK="$perf_line" RALPH_SPRINT_PLAN="$sprint_plan" "$py_bin" "$py_script" 2>/dev/null \
        && echo "✓ Performance lines updated in Completed section" >> "$debug_log" \
        || echo "⚠ Performance-line rewrite failed ($py_bin)" >> "$debug_log"
    else
      echo "⚠ No Python interpreter found — skipped Performance-line rewrite" >> "$debug_log"
    fi
    rm -f "$py_script"
  fi

  # ── 2. Update sprint totals ──
  if [ -f "$sprint_plan" ]; then
    # Count completed tasks
    local completed_count
    completed_count=$(count_matches "^\s*-\s*\[x\]\s*\*\*#[0-9]+\*\*" "$sprint_plan")
    if [ "$completed_count" -eq 0 ]; then
      local completed_line
      completed_line=$(grep -n "^## Completed" "$sprint_plan" 2>/dev/null | head -1 | cut -d: -f1 || true)
      if [ -n "$completed_line" ]; then
        completed_count=$(tail -n +"$completed_line" "$sprint_plan" | grep -cE "^\s*-\s*\*\*#[0-9]+\*\*" 2>/dev/null || true)
        completed_count=${completed_count%%[!0-9]*}; completed_count=${completed_count:-0}
      fi
    fi

    # Sum durations from Performance lines
    local total_duration
    total_duration=$({ grep -oE "\*\*Performance:\*\* [0-9]+ min" "$sprint_plan" 2>/dev/null \
      | grep -oE "[0-9]+" | awk '{sum+=$1} END {print sum+0}'; } || true)
    total_duration="${total_duration:-0}"

    # Sum costs from **Performance:** lines only. Missing cost is never $0.00.
    local total_cost="unavailable"
    local cost_available=0
    if grep '\*\*Performance:\*\*' "$sprint_plan" 2>/dev/null | grep -qE '\$[0-9]'; then
      total_cost=$({ grep '\*\*Performance:\*\*' "$sprint_plan" 2>/dev/null \
        | grep -vE 'unavailable|-\.--' \
        | sed -n 's/.*\$\([0-9]*\.[0-9]*\).*/\1/p' \
        | awk '{sum+=$1} END {printf "%.2f", sum+0}'; } || true)
      cost_available=1
    fi

    # Averages — skip dollar aggregation when cost is unavailable
    local avg_duration=0
    local avg_cost="unavailable"
    if [ "$completed_count" -gt 0 ] && [ "$total_duration" -gt 0 ]; then
      avg_duration=$(( (total_duration + completed_count - 1) / completed_count ))
      if [ "$cost_available" -eq 1 ]; then
        if command -v bc &> /dev/null; then
          avg_cost=$(echo "scale=2; $total_cost / $completed_count" | bc)
        else
          avg_cost=$(awk "BEGIN {printf \"%.2f\", $total_cost / $completed_count}")
        fi
      fi
    fi

    # Total task count
    local total_tasks
    total_tasks=$(count_matches "^\s*-\s*\[.\]\s*\*\*#[0-9]+\*\*" "$sprint_plan")
    if [ "$total_tasks" -eq 0 ]; then
      total_tasks=$(count_matches "\*\*#[0-9]+\*\*" "$sprint_plan")
      [ "$total_tasks" -eq 0 ] && total_tasks="?"
    fi

    # Collect unique sub-model families from this sprint's Performance blocks
    local sub_models_str=""
    if grep -q '^\s*- Sub Agent' "$sprint_plan" 2>/dev/null; then
      sub_models_str=$(grep -oE '^\s*- Sub Agent [0-9]+: [A-Za-z]+' "$sprint_plan" 2>/dev/null \
        | sed 's/.*: //' | sort -u | paste -sd ', ' -)
    fi

    # Collect main model from Performance blocks (first match)
    local main_model_str=""
    main_model_str=$(grep -oE '^\s*- Main Agent: [A-Za-z]+' "$sprint_plan" 2>/dev/null \
      | head -1 | sed 's/.*: //' || true)
    # Fall back to single-model Performance lines (legacy format)
    if [ -z "$main_model_str" ]; then
      main_model_str=$(grep '\*\*Performance:\*\*' "$sprint_plan" 2>/dev/null \
        | grep -oE '\| [A-Z][a-z]+ \|' | head -1 | tr -d '| ' || true)
    fi

    # Update summary section in a single pass (only if we have completed tasks)
    # Matches both "- **Field:**" (bullet) and "**Field:**" (no bullet) formats
    if [ "$completed_count" -gt 0 ]; then
      awk -v completed="$completed_count" -v total_tasks="$total_tasks" \
          -v total_duration="$total_duration" -v total_cost="$total_cost" \
          -v avg_duration="$avg_duration" -v avg_cost="$avg_cost" \
          -v main_model="$main_model_str" -v sub_models="$sub_models_str" '
        /\*\*Completed tasks:\*\*/ || /\*\*Completed:\*\*/ || /\*\*Completed so far:\*\*/ {
          match($0, /^[-* ]*/)
          prefix = substr($0, RSTART, RLENGTH)
          $0 = prefix "**Completed tasks:** " completed "/" total_tasks
          print; next
        }
        /\*\*Status:\*\*/ {
          if (completed + 0 >= total_tasks + 0 && total_tasks != "?") {
            match($0, /^[-* ]*/)
            prefix = substr($0, RSTART, RLENGTH)
            $0 = prefix "**Status:** Complete"
          }
          print; next
        }
        /\*\*Total duration:\*\*/ {
          match($0, /^[-* ]*/)
          prefix = substr($0, RSTART, RLENGTH)
          $0 = prefix "**Total duration:** " total_duration " min"
          print; next
        }
        /\*\*Total cost:\*\*/ {
          match($0, /^[-* ]*/)
          prefix = substr($0, RSTART, RLENGTH)
          if (total_cost == "unavailable") {
            $0 = prefix "**Total cost:** unavailable"
          } else {
            $0 = prefix "**Total cost:** $" total_cost
          }
          print; next
        }
        /\*\*Avg per task:\*\*/ {
          match($0, /^[-* ]*/)
          prefix = substr($0, RSTART, RLENGTH)
          if (avg_cost == "unavailable") {
            $0 = prefix "**Avg per task:** " avg_duration " min / unavailable"
          } else {
            $0 = prefix "**Avg per task:** " avg_duration " min / $" avg_cost
          }
          print; next
        }
        /\*\*Main model:\*\*/ {
          if (main_model != "") {
            match($0, /^[-* ]*/)
            prefix = substr($0, RSTART, RLENGTH)
            $0 = prefix "**Main model:** " main_model
          }
          print; next
        }
        /\*\*Sub models:\*\*/ {
          if (sub_models != "") {
            match($0, /^[-* ]*/)
            prefix = substr($0, RSTART, RLENGTH)
            $0 = prefix "**Sub models:** " sub_models
          }
          print; next
        }
        /\*\*Model:\*\*/ {
          if (main_model != "") {
            match($0, /^[-* ]*/)
            prefix = substr($0, RSTART, RLENGTH)
            $0 = prefix "**Main model:** " main_model
            print
            if (sub_models != "") {
              print prefix "**Sub models:** " sub_models
            }
            next
          }
          print; next
        }
        { print }
      ' "$sprint_plan" > "${sprint_plan}.tmp" && mv "${sprint_plan}.tmp" "$sprint_plan"
      echo "✓ Sprint totals: ${completed_count}/${total_tasks}, ${total_duration} min, \$${total_cost}" >> "$debug_log"
    fi
  fi

  # Write summary file for main script to display completion stats
  {
    echo "TASK_DURATION=$task_duration"
    echo "COST_EST=$cost_est"
    echo "COST_SOURCE=$cost_source"
  } > "$SUMMARY_FILE" 2>/dev/null || true

  echo "Post-processing complete at $(date '+%Y-%m-%d %H:%M:%S')" >> "$debug_log"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Session context: wrapper writes dynamic values to a file; agent reads it.
# Prompt is only "/ralph" so the skill is the single source of instructions.
# Note: TASK_NUM is the run index (1st, 2nd, 3rd run), not the sprint_plan task ID (#1, #2, #9).
# The agent picks the next open task from sprint_plan.md; taskNum is only for marker paths.
# ═══════════════════════════════════════════════════════════════════════════════

SESSION_CONTEXT_FILE="$MARKER_DIR/session-context.txt"
cat <<SESSION_EOF >"$SESSION_CONTEXT_FILE"
projectDir=$PROJECT_DIR
taskNum=$TASK_NUM
doneMarker=$CLAUDE_DONE_MARKER
sprintCompleteMarker=$MARKER_DIR/sprint-complete
SESSION_EOF
echo "Session context written to $SESSION_CONTEXT_FILE" >&3

# ═══════════════════════════════════════════════════════════════════════════════
# LAUNCH CLAUDE (interactive; user can redirect or interrupt)
# macOS: background + `wait` so stderr can be tee'd live to the log.
# Windows/Linux: process substitution + backgrounding is fragile under MSYS
# (limited job control, flaky /dev/fd), so run in the foreground without the
# live tee — the log is best-effort there.
# ═══════════════════════════════════════════════════════════════════════════════

CLAUDE_EXIT=0
CLAUDE_LOG="$MARKER_DIR/task-${TASK_NUM}-claude-output.log"
readonly PROMPT="/ralph"

if [[ "${OSTYPE:-}" == "darwin"* ]]; then
  "${CLAUDE_ARGS[@]}" "$PROMPT" 2> >(tee "$CLAUDE_LOG" >&2) &
  CLAUDE_PID=$!
  wait $CLAUDE_PID || CLAUDE_EXIT=$?
else
  : > "$CLAUDE_LOG"
  "${CLAUDE_ARGS[@]}" "$PROMPT" || CLAUDE_EXIT=$?
fi

echo "Claude exited with code: $CLAUDE_EXIT" >&3

# Non-zero agent exit must not look complete — orchestrator waits on these markers.
if [ "$CLAUDE_EXIT" -ne 0 ]; then
  echo "Non-zero agent exit — not creating completion markers" >&3
  touch "$TASK_FAILED_MARKER"
  echo "task-failed marker created at $(date '+%Y-%m-%d %H:%M:%S')" >&3
  TASK_END_TS=$(date +%s)
  ui_banner err "Task Failed (exit ${CLAUDE_EXIT})" \
    "Started:  $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')" \
    "Ended:    $(date_fmt "$TASK_END_TS" '+%Y-%m-%d %H:%M:%S')" \
    "Model:    ${RALPH_MODEL_LABEL}"
  echo "Wrapper failed at $(date '+%Y-%m-%d %H:%M:%S')" >&3
  exec 3>&-
  exit "$CLAUDE_EXIT"
fi

# Safety net: if Claude exited without touching claude-done, create it now
if [ ! -f "$CLAUDE_DONE_MARKER" ]; then
  echo "Claude exited without signaling claude-done - touching now" >&3
  touch "$CLAUDE_DONE_MARKER"
fi

# Claude has exited — stats file is now written. Run post-processing inline.
sleep 1  # let final statusline write settle to disk
run_post_processing || echo "Post-processing failed, continuing" >&3
touch "$TASK_DONE_MARKER"
echo "task-done marker created at $(date '+%Y-%m-%d %H:%M:%S')" >&3

# Show completion summary (from post-processing summary file)
TASK_END_TS=$(date +%s)
TASK_DURATION=$(( (TASK_END_TS - TASK_START_TS) / 60 ))
if [ "$TASK_DURATION" -lt 1 ]; then TASK_DURATION=1; fi

# source SUMMARY_FILE to get statusline-derived duration + cost (overrides wall-clock duration)
DISPLAY_COST_SOURCE="unavailable"
DISPLAY_COST="-.--"
if [ -f "$SUMMARY_FILE" ]; then
  # shellcheck source=/dev/null
  source "$SUMMARY_FILE"
  DISPLAY_COST="${COST_EST:--.--}"
  DISPLAY_COST_SOURCE="${COST_SOURCE:-unavailable}"
  # TASK_DURATION sourced from file overrides the wall-clock value above
fi

if [ "$DISPLAY_COST_SOURCE" = "statusline" ]; then
  COST_LINE="Cost:     \$${DISPLAY_COST} (Claude Code)"
else
  COST_LINE="Cost:     ${DISPLAY_COST} (stats unavailable)"
fi
ui_banner ok "Task Complete" \
  "Started:  $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')" \
  "Ended:    $(date_fmt "$TASK_END_TS" '+%Y-%m-%d %H:%M:%S')" \
  "Duration: ${TASK_DURATION} min" \
  "Model:    ${RALPH_MODEL_LABEL}" \
  "${COST_LINE}"
echo -e "${BLUE}Close tab when ready${NC}"
echo ""

echo "Wrapper completed at $(date '+%Y-%m-%d %H:%M:%S')" >&3
echo "═══════════════════════════════════════════════════════════" >&3
exec 3>&-
