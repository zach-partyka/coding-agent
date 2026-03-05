#!/bin/bash
# Ralph Wiggum Loop Runner (Generic)
# Usage:
#   ./ralph.sh --plan        # Planning mode: regenerate sprint_plan.md
#   ./ralph.sh               # Building mode: implement one thing from sprint_plan.md
#   ./ralph.sh --continuous  # Continuous mode: keep building until done/blocked

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

# Load project configuration
if [ -f "./ralph.config.sh" ]; then
  source ./ralph.config.sh
else
  echo "ERROR: ralph.config.sh not found"
  echo ""
  echo "Ralph needs a configuration file to work with your project."
  echo ""
  echo "To set up Ralph:"
  echo "  1. Copy the template: cp /path/to/ralph-starter-kit/template/ralph.config.sh.template ralph.config.sh"
  echo "  2. Edit ralph.config.sh with your project details"
  echo "  3. Run ./ralph.sh again"
  echo ""
  echo "Or use the setup script: /path/to/ralph-starter-kit/scripts/setup.sh"
  exit 1
fi

# Validate required configuration
if [ -z "$RALPH_GIT_REMOTE" ]; then
  echo "ERROR: RALPH_GIT_REMOTE not set in ralph.config.sh"
  echo "Set the git remote URL (e.g., 'https://gitlab.zgtools.net/team/project.git')"
  exit 1
fi

if [ -z "$RALPH_STAGING_URL" ]; then
  echo "ERROR: RALPH_STAGING_URL not set in ralph.config.sh"
  echo "Set the staging environment URL (e.g., 'https://app-staging.domain.com')"
  exit 1
fi

# Set defaults for optional configuration
RALPH_GIT_MAIN_BRANCH="${RALPH_GIT_MAIN_BRANCH:-main}"
RALPH_DEPLOY_WAIT_SECONDS="${RALPH_DEPLOY_WAIT_SECONDS:-300}"
RALPH_VALIDATE_LOCAL="${RALPH_VALIDATE_LOCAL:-echo 'No local validation configured'}"
RALPH_VALIDATE_STAGING="${RALPH_VALIDATE_STAGING:-echo 'No staging validation configured'}"
RALPH_HEALTH_CHECK_PATH="${RALPH_HEALTH_CHECK_PATH:-/health}"
RALPH_TASK_TIMEOUT_MINUTES="${RALPH_TASK_TIMEOUT_MINUTES:-15}"
RALPH_AUTO_ARCHIVE="${RALPH_AUTO_ARCHIVE:-true}"

# Export all config for skills to access
export RALPH_GIT_REMOTE
export RALPH_GIT_MAIN_BRANCH
export RALPH_STAGING_URL
export RALPH_DEPLOY_WAIT_SECONDS
export RALPH_VALIDATE_LOCAL
export RALPH_VALIDATE_STAGING
export RALPH_HEALTH_CHECK_PATH
export RALPH_TASK_TIMEOUT_MINUTES
export RALPH_AUTO_ARCHIVE
export RALPH_TEST_ENV_VARS

# Safety net: auto-commit on interrupt/exit to prevent lost work
cleanup() {
  echo ""
  echo "=== Ralph session ending ==="

  # Check for uncommitted changes
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "⚠️  Uncommitted changes detected - auto-saving..."
    git add -A
    git commit -m "WIP: Ralph auto-commit (session interrupted)" 2>/dev/null || echo "Nothing to commit"
    git push origin "$RALPH_GIT_MAIN_BRANCH" 2>/dev/null || echo "Push failed - run 'git push origin ${RALPH_GIT_MAIN_BRANCH}' manually"
    echo "✓ Work saved. Run './ralph.sh' to continue."
  fi
}
trap cleanup EXIT

MODE="build"

if [ "$1" == "--plan" ]; then
  MODE="plan"
elif [ "$1" == "--continuous" ]; then
  MODE="continuous"
fi

echo "=== Ralph Wiggum Loop ==="
echo "Mode: $MODE"
echo "Project: $(pwd)"
echo "Staging: $RALPH_STAGING_URL"
echo ""

# Get project directory (current directory)
readonly PROJECT_DIR="$(pwd)"

if [ "$MODE" == "plan" ]; then
  # Planning mode - use /ralph-plan skill
  echo "Starting planning mode..."
  claude --dangerously-skip-permissions "/ralph-plan

Project directory: ${PROJECT_DIR}"

elif [ "$MODE" == "continuous" ]; then
  # Continuous mode - use /ralph-continuous skill
  echo "Starting continuous mode..."
  echo "Press Ctrl+C to stop"
  echo ""

  claude --dangerously-skip-permissions "/ralph-continuous

Project directory: ${PROJECT_DIR}"

else
  # Build mode (one thing) - use /ralph skill
  echo "Starting build mode (one task)..."
  
  # Optional model selection - deterministic version string for sprint_plan.md (match ralph-task-wrapper.sh)
  case "${RALPH_MODEL:-default}" in
    opus)       RALPH_MODEL_LABEL="Opus 4.6" ;;
    opus-1m)    RALPH_MODEL_LABEL="Opus 4.6 (1M)" ;;
    sonnet-1m)  RALPH_MODEL_LABEL="Sonnet 4.6 (1M)" ;;
    haiku)      RALPH_MODEL_LABEL="Haiku 4.5" ;;
    *)          RALPH_MODEL_LABEL="Sonnet 4.6 (default)" ;;
  esac
  if [ -n "$RALPH_MODEL" ]; then
    echo "Model: $RALPH_MODEL_LABEL"
    echo ""
  fi
  
  # Capture start timestamp (shell-enforced time tracking)
  readonly TASK_START_TS=$(date +%s)
  echo "✓ Task clocked in: $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S') (timestamp: ${TASK_START_TS})"
  echo ""
  
  claude --dangerously-skip-permissions "/ralph

Project directory: ${PROJECT_DIR}
Ralph model: ${RALPH_MODEL_LABEL}"

  # Capture end timestamp and calculate duration
  readonly TASK_END_TS=$(date +%s)
  TASK_DURATION=$(( (TASK_END_TS - TASK_START_TS) / 60 ))
  
  # Handle edge case: if duration is 0, set to 1 min minimum
  if [ "$TASK_DURATION" -lt 1 ]; then
    TASK_DURATION=1
  fi
  
  # Calculate cost estimate based on model and duration
  # Same pricing as ralph-task-wrapper.sh for consistency:
  # - Opus 4.6: ~$0.05/min
  # - Sonnet 4.6: ~$0.03/min
  # - Haiku 4.5: ~$0.01/min
  case "${RALPH_MODEL:-default}" in
    opus)       COST_PER_MIN="0.05" ;;
    opus-1m)    COST_PER_MIN="0.08" ;;
    sonnet-1m)  COST_PER_MIN="0.05" ;;
    haiku)      COST_PER_MIN="0.01" ;;
    *)          COST_PER_MIN="0.03" ;;
  esac
  
  # Calculate cost (using bc for floating point, fallback to awk)
  if command -v bc &> /dev/null; then
    COST_EST=$(echo "scale=2; $TASK_DURATION * $COST_PER_MIN" | bc)
  else
    COST_EST=$(awk "BEGIN {printf \"%.2f\", $TASK_DURATION * $COST_PER_MIN}")
  fi
  
  # Calculate duration in decimal minutes for audit trail
  readonly DURATION_DIFF=$((TASK_END_TS - TASK_START_TS))
  readonly DURATION_DECIMAL=$(awk "BEGIN {printf \"%.1f\", $DURATION_DIFF / 60}")
  
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Task Complete"
  echo "═══════════════════════════════════════════════════════════"
  echo "Started:  $(date_fmt "$TASK_START_TS" '+%Y-%m-%d %H:%M:%S')"
  echo "Ended:    $(date_fmt "$TASK_END_TS" '+%Y-%m-%d %H:%M:%S')"
  echo "Duration: ${TASK_DURATION} min"
  echo "Model:    ${RALPH_MODEL_LABEL}"
  echo "Cost:     \$${COST_EST} (estimated)"
  echo ""
  
  # Write timing into sprint_plan.md using SHELL_WILL_UPDATE placeholder replacement
  # Format: **Performance:** X min | Model | $X.XX est
  #           - Duration calc: (end - start) / 60 = diff / 60 = X.X min
  #           - Timestamps: start=XXXXX, end=XXXXX
  if [ -f "sprint_plan.md" ]; then
    # 1. Replace placeholder with full performance data
    if grep -q "SHELL_WILL_UPDATE" sprint_plan.md; then
      PERF_LINE="**Performance:** ${TASK_DURATION} min | ${RALPH_MODEL_LABEL} | \$${COST_EST} est"
      CALC_LINE="    - Duration calc: (${TASK_END_TS} - ${TASK_START_TS}) \/ 60 = ${DURATION_DIFF} \/ 60 = ${DURATION_DECIMAL} min"
      TS_LINE="    - Timestamps: start=${TASK_START_TS}, end=${TASK_END_TS}"
      
      # Only replace the FIRST occurrence (most recent task) to handle multiple SHELL_WILL_UPDATE placeholders
      TMP_FILE="sprint_plan.md.tmp.$$"
      awk -v perf="$PERF_LINE" -v calc="$CALC_LINE" -v ts="$TS_LINE" '
        !replaced && /\*\*Performance:\*\* SHELL_WILL_UPDATE/ {
          print "  - " perf
          print calc
          print ts
          replaced = 1
          next
        }
        { print }
      ' sprint_plan.md > "$TMP_FILE" && mv "$TMP_FILE" sprint_plan.md
      
      echo "✓ Performance data written: ${TASK_DURATION} min | ${RALPH_MODEL_LABEL} | \$${COST_EST}"
    fi

    # 2. Count completed tasks
    COMPLETED_COUNT=$(grep -cE "^\s*-\s*\[x\]\s*\*\*#[0-9]+\*\*" sprint_plan.md 2>/dev/null || echo 0)
    if [ "$COMPLETED_COUNT" -eq 0 ]; then
      COMPLETED_LINE=$(grep -n "^## Completed" sprint_plan.md | head -1 | cut -d: -f1)
      if [ -n "$COMPLETED_LINE" ]; then
        COMPLETED_COUNT=$(tail -n +$COMPLETED_LINE sprint_plan.md | grep -cE "^\s*-\s*\*\*#[0-9]+\*\*" 2>/dev/null || echo 0)
      fi
    fi
    
    # 3. Sum all durations from Performance lines
    TOTAL_DURATION=$(grep -oE "\*\*Performance:\*\* [0-9]+ min" sprint_plan.md 2>/dev/null \
      | grep -oE "[0-9]+" | awk '{sum+=$1} END {print sum+0}')
    
    # 4. Sum all costs from Performance lines
    TOTAL_COST=$(grep -oE "\\\$[0-9]+\.[0-9]+ est" sprint_plan.md 2>/dev/null \
      | grep -oE "[0-9]+\.[0-9]+" | awk '{sum+=$1} END {printf "%.2f", sum+0}')
    
    # 5. Calculate averages
    if [ "$COMPLETED_COUNT" -gt 0 ] && [ "$TOTAL_DURATION" -gt 0 ]; then
      AVG_DURATION=$(( (TOTAL_DURATION + COMPLETED_COUNT - 1) / COMPLETED_COUNT ))
      if command -v bc &> /dev/null; then
        AVG_COST=$(echo "scale=2; $TOTAL_COST / $COMPLETED_COUNT" | bc)
      else
        AVG_COST=$(awk "BEGIN {printf \"%.2f\", $TOTAL_COST / $COMPLETED_COUNT}")
      fi
    else
      AVG_DURATION=0
      AVG_COST="0.00"
    fi
    
    # 6. Get total task count
    TOTAL_TASKS=$(grep -cE "^\s*-\s*\[.\]\s*\*\*#[0-9]+\*\*" sprint_plan.md 2>/dev/null || echo 0)
    if [ "$TOTAL_TASKS" -eq 0 ]; then
      TOTAL_TASKS=$(grep -cE "\*\*#[0-9]+\*\*" sprint_plan.md 2>/dev/null || echo "?")
    fi
    
    # 7. Update Sprint Performance Summary
    if [ "$COMPLETED_COUNT" -gt 0 ]; then
      sed_i "s/\*\*Completed:\*\* [0-9~]*\/[0-9?]* tasks/**Completed:** ${COMPLETED_COUNT}\/${TOTAL_TASKS} tasks/" sprint_plan.md
      sed_i "s/\*\*Completed so far:\*\* [0-9~]*\/[0-9?]* tasks/**Completed so far:** ${COMPLETED_COUNT}\/${TOTAL_TASKS} tasks/" sprint_plan.md
      sed_i "s/\*\*Total duration:\*\* [0-9~.]* min/**Total duration:** ${TOTAL_DURATION} min/" sprint_plan.md
      
      if grep -q "\*\*Total cost:\*\*" sprint_plan.md; then
        sed_i "s/\*\*Total cost:\*\* [~]*\\\$[0-9.]*/**Total cost:** \$${TOTAL_COST}/" sprint_plan.md
      fi
      
      if grep -q "\*\*Avg per task:\*\* .* min / \\\$" sprint_plan.md; then
        sed_i "s/\*\*Avg per task:\*\* [~]*[0-9]* min \/ \\\$[0-9.]*/**Avg per task:** ${AVG_DURATION} min \/ \$${AVG_COST}/" sprint_plan.md
      elif grep -q "\*\*Avg per task:\*\* .* min" sprint_plan.md; then
        sed_i "s/\*\*Avg per task:\*\* [~]*[0-9]* min/**Avg per task:** ${AVG_DURATION} min \/ \$${AVG_COST}/" sprint_plan.md
      fi
      
      echo "✓ Sprint totals: ${COMPLETED_COUNT}/${TOTAL_TASKS} tasks, ${TOTAL_DURATION} min, \$${TOTAL_COST}"
    fi
  fi

  # Post-run verification
  echo ""
  echo "=== Post-run verification ==="
  if [ -n "$(git status --porcelain 2>/dev/null | grep -v node_modules)" ]; then
    echo "⚠️  WARNING: Uncommitted changes detected after run!"
    echo "The /ralph skill should have committed. Checking..."
    git status --short | head -10
  elif [ -n "$(git log origin/$RALPH_GIT_MAIN_BRANCH..HEAD 2>/dev/null)" ]; then
    echo "⚠️  WARNING: Commits not pushed to remote!"
    git log --oneline "origin/$RALPH_GIT_MAIN_BRANCH..HEAD"
    echo "Pushing now..."
    git push origin "$RALPH_GIT_MAIN_BRANCH" || echo "Push failed - run manually"
  else
    echo "✓ All changes committed and pushed"
  fi
fi
