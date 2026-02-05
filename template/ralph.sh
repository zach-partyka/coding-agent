#!/bin/bash
# Ralph Wiggum Loop Runner (Generic)
# Usage:
#   ./ralph.sh --plan        # Planning mode: regenerate sprint_plan.md
#   ./ralph.sh               # Building mode: implement one thing from sprint_plan.md
#   ./ralph.sh --continuous  # Continuous mode: keep building until done/blocked

set -e

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
    git push origin "$RALPH_GIT_MAIN_BRANCH" 2>/dev/null || echo "Push failed - run 'git push origin $RALPH_GIT_MAIN_BRANCH' manually"
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
PROJECT_DIR="$(pwd)"

if [ "$MODE" == "plan" ]; then
  # Planning mode - use /ralph-plan skill
  echo "Starting planning mode..."
  claude --dangerously-skip-permissions "/ralph-plan

Project directory: $PROJECT_DIR"

elif [ "$MODE" == "continuous" ]; then
  # Continuous mode - use /ralph-continuous skill
  echo "Starting continuous mode..."
  echo "Press Ctrl+C to stop"
  echo ""

  claude --dangerously-skip-permissions "/ralph-continuous

Project directory: $PROJECT_DIR"

else
  # Build mode (one thing) - use /ralph skill
  echo "Starting build mode (one task)..."
  
  # Capture start timestamp (shell-enforced time tracking)
  TASK_START_TS=$(date +%s)
  echo "✓ Task clocked in: $(date -r $TASK_START_TS '+%Y-%m-%d %H:%M:%S') (timestamp: $TASK_START_TS)"
  echo ""
  
  claude --dangerously-skip-permissions "/ralph

Project directory: $PROJECT_DIR
Task start timestamp: $TASK_START_TS (shell-enforced)"

  # Capture end timestamp and calculate duration
  TASK_END_TS=$(date +%s)
  TASK_DURATION=$(( (TASK_END_TS - TASK_START_TS) / 60 ))
  
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Task Timing (Shell-Enforced)"
  echo "═══════════════════════════════════════════════════════════"
  echo "Started:  $(date -r $TASK_START_TS '+%Y-%m-%d %H:%M:%S')"
  echo "Ended:    $(date -r $TASK_END_TS '+%Y-%m-%d %H:%M:%S')"
  echo "Duration: ${TASK_DURATION} minutes"
  echo ""
  
  # Verify timestamp was recorded in sprint_plan.md
  if [ -f "sprint_plan.md" ]; then
    if grep -q "Start timestamp: $TASK_START_TS" sprint_plan.md; then
      echo "✓ Timestamp verified in sprint_plan.md"
    else
      echo "⚠️  WARNING: Start timestamp not found in sprint_plan.md"
      echo "   Shell captured: $TASK_START_TS"
      echo "   Duration: ${TASK_DURATION} minutes"
      echo "   You may need to manually add this to the completed task entry"
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
