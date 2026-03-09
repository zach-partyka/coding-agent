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
    RALPH_INPUT_RATE="5"; RALPH_OUTPUT_RATE="25"
    RALPH_CACHE_WRITE_RATE="6.25"; RALPH_CACHE_READ_RATE="0.50"
    RALPH_COST_PER_MIN="0.05"
    ;;
  opus-1m)
    RALPH_MODEL_LABEL="Opus 4.6 (1M)"
    RALPH_INPUT_RATE="5"; RALPH_OUTPUT_RATE="25"
    RALPH_CACHE_WRITE_RATE="6.25"; RALPH_CACHE_READ_RATE="0.50"
    RALPH_COST_PER_MIN="0.08"
    ;;
  sonnet-1m)
    RALPH_MODEL_LABEL="Sonnet 4.6 (1M)"
    RALPH_INPUT_RATE="3"; RALPH_OUTPUT_RATE="15"
    RALPH_CACHE_WRITE_RATE="3.75"; RALPH_CACHE_READ_RATE="0.30"
    RALPH_COST_PER_MIN="0.05"
    ;;
  haiku)
    RALPH_MODEL_LABEL="Haiku 4.5"
    RALPH_INPUT_RATE="1"; RALPH_OUTPUT_RATE="5"
    RALPH_CACHE_WRITE_RATE="1.25"; RALPH_CACHE_READ_RATE="0.10"
    RALPH_COST_PER_MIN="0.01"
    ;;
  *)
    RALPH_MODEL_LABEL="Sonnet 4.6 (default)"
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

# Build Claude command - always pass explicit model so CLI doesn't use its own default (e.g. Opus)
# When RALPH_MODEL is empty we want Sonnet 4.6, so pass "sonnet" explicitly
CLAUDE_MODEL_FOR_CLI="${RALPH_MODEL:-sonnet}"
CLAUDE_ARGS=("claude" "--dangerously-skip-permissions" "--max-turns" "50" "--session-id" "$SESSION_ID" "--model" "$CLAUDE_MODEL_FOR_CLI")
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
  # Tracks main agent (parent turns) and subagents separately with per-model pricing.
  # Captures subagent descriptions from Agent tool_use calls for readable output.
  local input_tokens=0
  local output_tokens=0
  local cache_creation_tokens=0
  local cache_read_tokens=0
  local cost_est="0.00"
  local cost_source="est"
  local main_agent_line=""
  local sub_agent_lines=""

  echo "Looking for session file: $SESSION_FILE" >> "$debug_log"

  if [ -f "$SESSION_FILE" ]; then
    local token_data
    token_data=$(python3 -c "
import json, sys

RATES = {
    'opus':   {'input': 5,  'output': 25, 'cache_write': 6.25, 'cache_read': 0.50},
    'sonnet': {'input': 3,  'output': 15, 'cache_write': 3.75, 'cache_read': 0.30},
    'haiku':  {'input': 1,  'output': 5,  'cache_write': 1.25, 'cache_read': 0.10},
}
LABELS = {'opus': 'Opus', 'sonnet': 'Sonnet', 'haiku': 'Haiku'}

def model_family(model_str):
    if not model_str:
        return None
    m = model_str.lower()
    for fam in ('opus', 'sonnet', 'haiku'):
        if fam in m:
            return fam
    return None

def cost_for_turn(i, o, cw, cr, fam, default_fam):
    r = RATES.get(fam or default_fam, RATES.get(default_fam, RATES['sonnet']))
    return (i/1e6)*r['input'] + (o/1e6)*r['output'] + (cw/1e6)*r['cache_write'] + (cr/1e6)*r['cache_read']

def bucket_init():
    return {'in':0,'out':0,'cw':0,'cr':0,'cost':0.0,'turns':0}

default_fam = model_family('$RALPH_MODEL') or 'sonnet'

# Separate tracking: main agent vs subagents
main = {}   # keyed by model family
subs = {}   # keyed by model family
sub_descriptions = {}  # model family -> set of description strings

# Humanize raw subagent descriptions for non-technical readers.
# Maps known patterns to short labels; falls back to the raw description.
import re as _re
HUMANIZE = [
    (_re.compile(r'scout|codebase.scout|search.*code|code.*search', _re.I), 'Code search'),
    (_re.compile(r'npm.*(run\s+)?check|type.?check|validation.?runner|run.*validation', _re.I), 'Type checking'),
    (_re.compile(r'deep.?investigat', _re.I), 'Investigation'),
    (_re.compile(r'playwright.*heal|test.*heal', _re.I), 'Test healing'),
    (_re.compile(r'playwright.*plan|test.*plan', _re.I), 'Test planning'),
    (_re.compile(r'browser', _re.I), 'Browser testing'),
    (_re.compile(r'playwright|staging.*test|test.*staging|run.*test|re-?run.*test|test.?runner', _re.I), 'Staging tests'),
]
def humanize_desc(raw):
    for pat, label in HUMANIZE:
        if pat.search(raw):
            return label
    return raw

# First pass: collect subagent descriptions from Agent tool_use calls.
agent_descs_ordered = []
with open('$SESSION_FILE') as f:
    for line in f:
        try:
            obj = json.loads(line)
        except:
            continue
        msg = obj.get('message', {})
        if not isinstance(msg, dict):
            continue
        content = msg.get('content', [])
        if not isinstance(content, list):
            continue
        for block in content:
            if isinstance(block, dict) and block.get('type') == 'tool_use' and block.get('name') == 'Agent':
                inp = block.get('input', {})
                desc = inp.get('description', '')
                stype = inp.get('subagent_type', '')
                if desc:
                    agent_descs_ordered.append(humanize_desc(desc))

# Second pass: tally tokens
total_cost = 0.0
with open('$SESSION_FILE') as f:
    for line in f:
        try:
            obj = json.loads(line)
        except:
            continue
        # Path 1: parent/main agent turns
        msg = obj.get('message', {})
        if isinstance(msg, dict) and 'usage' in msg:
            u = msg['usage']
            fam = model_family(msg.get('model', '')) or default_fam
            i = u.get('input_tokens', 0)
            o = u.get('output_tokens', 0)
            cw = u.get('cache_creation_input_tokens', 0)
            cr = u.get('cache_read_input_tokens', 0)
            tc = cost_for_turn(i, o, cw, cr, fam, default_fam)
            total_cost += tc
            main.setdefault(fam, bucket_init())
            d = main[fam]; d['in']+=i; d['out']+=o; d['cw']+=cw; d['cr']+=cr; d['cost']+=tc; d['turns']+=1
        # Path 2: subagent turns
        data = obj.get('data', {})
        if isinstance(data, dict):
            dmm = data.get('message', {})
            if isinstance(dmm, dict):
                inner = dmm.get('message', {})
                if isinstance(inner, dict) and 'usage' in inner:
                    u = inner['usage']
                    fam = model_family(inner.get('model', '')) or default_fam
                    if fam == '<synthetic>' or not fam:
                        continue
                    i = u.get('input_tokens', 0)
                    o = u.get('output_tokens', 0)
                    cw = u.get('cache_creation_input_tokens', 0)
                    cr = u.get('cache_read_input_tokens', 0)
                    if i == 0 and o == 0:
                        continue
                    tc = cost_for_turn(i, o, cw, cr, fam, default_fam)
                    total_cost += tc
                    subs.setdefault(fam, bucket_init())
                    d = subs[fam]; d['in']+=i; d['out']+=o; d['cw']+=cw; d['cr']+=cr; d['cost']+=tc; d['turns']+=1

# Compute aggregate totals
all_buckets = list(main.values()) + list(subs.values())
input_tok = sum(d['in'] for d in all_buckets)
output_tok = sum(d['out'] for d in all_buckets)
cache_create = sum(d['cw'] for d in all_buckets)
cache_read = sum(d['cr'] for d in all_buckets)
turns = sum(d['turns'] for d in all_buckets)

# Line 1: totals (backward-compatible)
print('%d %d %d %d %d %.4f' % (input_tok, output_tok, cache_create, cache_read, turns, total_cost))

# Line 2+: MAIN:<model> lines (usually just one)
for fam in sorted(main, key=lambda f: main[f]['cost'], reverse=True):
    d = main[fam]
    label = LABELS.get(fam, fam.title())
    print('MAIN:%s|%.2f|%d|%d|%d|%d|%d' % (label, d['cost'], d['turns'], d['in'], d['out'], d['cw'], d['cr']))

# SUB:<model> lines with descriptions (deduplicated, preserving order).
seen = set()
unique_descs = []
for d in agent_descs_ordered:
    if d not in seen:
        seen.add(d)
        unique_descs.append(d)
desc_str = ', '.join(unique_descs) if unique_descs else ''
sub_idx = 0
for fam in sorted(subs, key=lambda f: subs[f]['cost'], reverse=True):
    sub_idx += 1
    d = subs[fam]
    label = LABELS.get(fam, fam.title())
    ds = desc_str if sub_idx == 1 else ''
    print('SUB:%d:%s|%.2f|%d|%d|%d|%d|%d|%s' % (sub_idx, label, d['cost'], d['turns'], d['in'], d['out'], d['cw'], d['cr'], ds))

# MODEL: lines for debug log (unchanged)
by_model = {}
for fam, d in list(main.items()) + list(subs.items()):
    by_model.setdefault(fam, bucket_init())
    b = by_model[fam]
    for k in ('in','out','cw','cr','cost','turns'):
        b[k] += d[k]
for fam in sorted(by_model):
    d = by_model[fam]
    print('MODEL:%s turns=%d in=%d out=%d cw=%d cr=%d cost=%.4f' % (fam, d['turns'], d['in'], d['out'], d['cw'], d['cr'], d['cost']))
" 2>/dev/null)

    if [ -n "$token_data" ]; then
      # Line 1: totals
      local totals_line
      totals_line=$(echo "$token_data" | head -1)
      input_tokens=$(echo "$totals_line" | awk '{print $1}')
      output_tokens=$(echo "$totals_line" | awk '{print $2}')
      cache_creation_tokens=$(echo "$totals_line" | awk '{print $3}')
      cache_read_tokens=$(echo "$totals_line" | awk '{print $4}')
      local api_turns
      api_turns=$(echo "$totals_line" | awk '{print $5}')
      local python_cost
      python_cost=$(echo "$totals_line" | awk '{print $6}')

      # Parse MAIN: and SUB: lines for structured output
      main_agent_line=$(echo "$token_data" | grep '^MAIN:' | head -1)
      sub_agent_lines=$(echo "$token_data" | grep '^SUB:')

      if [ "$output_tokens" -gt 0 ] 2>/dev/null; then
        cost_est=$(printf "%.2f" "$python_cost")
        cost_est=$(ensure_leading_zero "$cost_est")
        cost_source="actual"
        echo "Session token usage (${api_turns} API turns, model-aware pricing):" >> "$debug_log"
        echo "  Input:          ${input_tokens}" >> "$debug_log"
        echo "  Output:         ${output_tokens}" >> "$debug_log"
        echo "  Cache creation: ${cache_creation_tokens}" >> "$debug_log"
        echo "  Cache read:     ${cache_read_tokens}" >> "$debug_log"
        echo "  Cost:           \$${cost_est}" >> "$debug_log"
        if [ -n "$main_agent_line" ]; then
          echo "  Main agent:     ${main_agent_line}" >> "$debug_log"
        fi
        if [ -n "$sub_agent_lines" ]; then
          echo "$sub_agent_lines" | while read -r sl; do
            echo "  Sub agent:      ${sl}" >> "$debug_log"
          done
        fi
        echo "$token_data" | grep '^MODEL:' | while read -r model_line; do
          echo "  ${model_line}" >> "$debug_log"
        done
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
  #   a) Claude wrote SHELL_WILL_UPDATE → replace with full performance block
  #   b) Claude wrote partial data like "5 min | Opus 4.6" (no $) → append cost
  # Both cases only target lines AFTER "## Completed" heading.
  #
  # Output format (multi-model):
  #   - **Performance:** 3 min | $1.87
  #     - Main Agent: Opus
  #       $1.77 (33 in / 4192 out / 127069 cache-write / 1746938 cache-read)
  #     - Sub Agent 1: Haiku — Type checking
  #       $0.10 (47 in / 24 out / 64556 cache-write / 173472 cache-read)
  # Output format (single model):
  #   - **Performance:** 3 min | $2.77
  #     - Main Agent: Opus
  #       $2.77 (30 in / 2813 out / 309833 cache-write / 1520338 cache-read)
  if [ -f "$sprint_plan" ]; then
    local has_subs=false
    [ -n "$sub_agent_lines" ] && has_subs=true

    # Build the replacement block as a temp file (handles multi-line cleanly)
    local perf_block_file
    perf_block_file=$(mktemp)

    if [ "$cost_source" = "actual" ] && [ "$has_subs" = true ]; then
      # Multi-model: summary line + per-agent sub-bullets
      echo "  - **Performance:** ${task_duration} min | \$${cost_est}" >> "$perf_block_file"

      # Main agent line(s) — format: MAIN:Label|cost|turns|in|out|cw|cr
      echo "$main_agent_line" | while IFS='|' read -r _prefix cost turns inp outp cw cr; do
        local model="${_prefix#MAIN:}"
        cost=$(ensure_leading_zero "$cost")
        echo "    - Main Agent: ${model}" >> "$perf_block_file"
        echo "      \$${cost} (${inp} in / ${outp} out / ${cw} cache-write / ${cr} cache-read)" >> "$perf_block_file"
      done

      # Sub agent line(s) — format: SUB:N:Label|cost|turns|in|out|cw|cr|descs
      echo "$sub_agent_lines" | while IFS='|' read -r _prefix cost turns inp outp cw cr descs; do
        local num_and_model="${_prefix#SUB:}"
        local sub_num="${num_and_model%%:*}"
        local model="${num_and_model#*:}"
        cost=$(ensure_leading_zero "$cost")
        local desc_suffix=""
        if [ -n "$descs" ]; then
          desc_suffix=" — ${descs}"
        fi
        echo "    - Sub Agent ${sub_num}: ${model}${desc_suffix}" >> "$perf_block_file"
        echo "      \$${cost} (${inp} in / ${outp} out / ${cw} cache-write / ${cr} cache-read)" >> "$perf_block_file"
      done

      echo "    - Duration calc: (${task_end_ts} - ${TASK_START_TS}) / 60 = ${duration_diff} / 60 = ${duration_decimal} min" >> "$perf_block_file"
      echo "    - Timestamps: start=${TASK_START_TS}, end=${task_end_ts}" >> "$perf_block_file"
    elif [ "$cost_source" = "actual" ]; then
      # Single model: summary line + agent sub-bullet
      local main_model="${RALPH_MODEL_LABEL}"
      if [ -n "$main_agent_line" ]; then
        main_model=$(echo "$main_agent_line" | cut -d'|' -f1)
        main_model="${main_model#MAIN:}"
      fi
      echo "  - **Performance:** ${task_duration} min | \$${cost_est}" >> "$perf_block_file"
      echo "    - Main Agent: ${main_model}" >> "$perf_block_file"
      echo "      \$${cost_est} (${input_tokens} in / ${output_tokens} out / ${cache_creation_tokens} cache-write / ${cache_read_tokens} cache-read)" >> "$perf_block_file"
      echo "    - Duration calc: (${task_end_ts} - ${TASK_START_TS}) / 60 = ${duration_diff} / 60 = ${duration_decimal} min" >> "$perf_block_file"
      echo "    - Timestamps: start=${TASK_START_TS}, end=${task_end_ts}" >> "$perf_block_file"
    else
      # Estimated cost fallback
      echo "  - **Performance:** ${task_duration} min | ${RALPH_MODEL_LABEL} | ~\$${cost_est} est" >> "$perf_block_file"
      echo "    - Duration calc: (${task_end_ts} - ${TASK_START_TS}) / 60 = ${duration_diff} / 60 = ${duration_decimal} min" >> "$perf_block_file"
      echo "    - Timestamps: start=${TASK_START_TS}, end=${task_end_ts}" >> "$perf_block_file"
    fi

    # Read the perf block the shell built
    local perf_block
    perf_block=$(cat "$perf_block_file")
    rm -f "$perf_block_file"

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

        has_timestamps = any('Timestamps:' in s for s in sub_bullets)

        if has_timestamps:
            # Already processed by shell in a previous run — leave alone
            out.append(task_header)
            out.extend(sub_bullets)
            i = j
            continue

        # Not yet processed — strip any agent-written Performance/SHELL_WILL_UPDATE
        # lines (and their deeper-indented children), then append shell perf block
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

    RALPH_PERF_BLOCK="$perf_block" RALPH_SPRINT_PLAN="$sprint_plan" python3 "$py_script" 2>/dev/null
    rm -f "$py_script"
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
    
    # Sum costs from **Performance:** lines only (not Main/Sub sub-bullets).
    # Extract the first dollar amount from each Performance line (always the total).
    # Handles: "3 min | $3.00", "3 min | Opus | $2.77 (...)", "3 min | Opus | ~$0.25 est"
    local total_cost
    total_cost=$({ grep '\*\*Performance:\*\*' "$sprint_plan" 2>/dev/null \
      | sed -n 's/.*\$\([0-9]*\.[0-9]*\).*/\1/p' \
      | awk '{sum+=$1} END {printf "%.2f", sum+0}'; } || true)
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
          $0 = prefix "**Total cost:** $" total_cost
          print; next
        }
        /\*\*Avg per task:\*\*/ {
          match($0, /^[-* ]*/)
          prefix = substr($0, RSTART, RLENGTH)
          $0 = prefix "**Avg per task:** " avg_duration " min / $" avg_cost
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

  # Write summary file for main script (avoids re-parsing session file for display)
  {
    echo "TASK_DURATION=$task_duration"
    echo "COST_EST=$cost_est"
    echo "COST_SOURCE=$cost_source"
    echo "INPUT_TOKENS=$input_tokens"
    echo "OUTPUT_TOKENS=$output_tokens"
    echo "CACHE_CREATION_TOKENS=$cache_creation_tokens"
    echo "CACHE_READ_TOKENS=$cache_read_tokens"
    echo "MAIN_AGENT_LINE=$main_agent_line"
    echo "SUB_AGENT_LINES=$sub_agent_lines"
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
# ═══════════════════════════════════════════════════════════════════════════════

CLAUDE_EXIT=0
CLAUDE_LOG="$MARKER_DIR/task-${TASK_NUM}-claude-output.log"
readonly PROMPT="/ralph"

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
  if [ -n "${MAIN_AGENT_LINE:-}" ]; then
    local ma_model ma_cost
    ma_model=$(echo "$MAIN_AGENT_LINE" | cut -d'|' -f1)
    ma_model="${ma_model#MAIN:}"
    ma_cost=$(echo "$MAIN_AGENT_LINE" | cut -d'|' -f2)
    echo -e "  Main:     ${ma_model} (\$${ma_cost})"
  fi
  if [ -n "${SUB_AGENT_LINES:-}" ]; then
    echo "$SUB_AGENT_LINES" | while IFS='|' read -r _prefix cost turns inp outp cw cr descs; do
      local num_and_model="${_prefix#SUB:}"
      local sub_num="${num_and_model%%:*}"
      local model="${num_and_model#*:}"
      local desc_part=""
      [ -n "$descs" ] && desc_part=" — ${descs}"
      echo -e "  Sub ${sub_num}:    ${model} (\$${cost})${desc_part}"
    done
  fi
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
