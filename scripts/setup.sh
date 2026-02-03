#!/bin/bash
# Ralph Starter Kit - Interactive Setup Script

set -e

echo "=== Ralph Starter Kit Setup ==="
echo ""

# Get current directory
PROJECT_DIR="$(pwd)"

# Check if already set up
if [ -f "$PROJECT_DIR/ralph.config.sh" ]; then
  echo "⚠️  ralph.config.sh already exists in this directory."
  read -p "Overwrite? (y/n): " OVERWRITE
  if [ "$OVERWRITE" != "y" ]; then
    echo "Setup cancelled."
    exit 0
  fi
fi

# Detect project type
echo "Detecting project type..."
PROJECT_TYPE="generic"

if [ -f "package.json" ]; then
  PROJECT_TYPE="nodejs"
  echo "✓ Detected: Node.js/TypeScript project"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  PROJECT_TYPE="python"
  echo "✓ Detected: Python project"
elif [ -f "go.mod" ]; then
  PROJECT_TYPE="go"
  echo "✓ Detected: Go project"
else
  echo "✓ Generic project (will need custom configuration)"
fi

echo ""

# Git Configuration
echo "=== Git Configuration ==="
echo ""

# Try to detect git remote
GIT_REMOTE=""
if [ -d ".git" ]; then
  GIT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  # Convert SSH to HTTPS if needed
  if [[ "$GIT_REMOTE" == git@* ]]; then
    GIT_REMOTE=$(echo "$GIT_REMOTE" | sed 's/git@\(.*\):\(.*\)/https:\/\/\1\/\2/')
    echo "Note: Converted SSH remote to HTTPS (Ralph requires HTTPS)"
  fi
fi

if [ -n "$GIT_REMOTE" ]; then
  echo "Detected git remote: $GIT_REMOTE"
  read -p "Use this remote? (y/n): " USE_REMOTE
  if [ "$USE_REMOTE" != "y" ]; then
    GIT_REMOTE=""
  fi
fi

if [ -z "$GIT_REMOTE" ]; then
  read -p "Enter git remote URL (HTTPS): " GIT_REMOTE
fi

# Git main branch
GIT_MAIN_BRANCH="main"
if [ -d ".git" ]; then
  DETECTED_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
  echo "Detected main branch: $DETECTED_BRANCH"
  read -p "Use this branch? (y/n): " USE_BRANCH
  if [ "$USE_BRANCH" == "y" ]; then
    GIT_MAIN_BRANCH="$DETECTED_BRANCH"
  fi
fi

echo ""

# Staging Configuration
echo "=== Staging Environment ==="
echo ""

read -p "Enter staging URL (e.g., https://app-staging.zgtools.net): " STAGING_URL

# Deployment wait time
DEPLOY_WAIT=300
if [ "$PROJECT_TYPE" == "python" ]; then
  DEPLOY_WAIT=180
  echo "Suggested deploy wait: 180 seconds (typical for Python apps)"
elif [ "$PROJECT_TYPE" == "nodejs" ]; then
  DEPLOY_WAIT=300
  echo "Suggested deploy wait: 300 seconds (typical for Node.js apps)"
fi

read -p "Deploy wait time in seconds [$DEPLOY_WAIT]: " USER_DEPLOY_WAIT
if [ -n "$USER_DEPLOY_WAIT" ]; then
  DEPLOY_WAIT="$USER_DEPLOY_WAIT"
fi

# Health check path
HEALTH_CHECK="/health"
read -p "Health check endpoint path [$HEALTH_CHECK]: " USER_HEALTH_CHECK
if [ -n "$USER_HEALTH_CHECK" ]; then
  HEALTH_CHECK="$USER_HEALTH_CHECK"
fi

echo ""

# Validation Commands
echo "=== Validation Commands ==="
echo ""

# Set defaults based on project type
case "$PROJECT_TYPE" in
  nodejs)
    DEFAULT_LOCAL="npm run check"
    DEFAULT_STAGING="npm test"
    ;;
  python)
    DEFAULT_LOCAL="python -m ruff check src/ && python -m mypy src/ && python -m pytest tests/unit/"
    DEFAULT_STAGING="python -m pytest tests/integration/ -v"
    ;;
  go)
    DEFAULT_LOCAL="go test ./..."
    DEFAULT_STAGING="go test -tags=integration ./..."
    ;;
  *)
    DEFAULT_LOCAL="make lint && make test"
    DEFAULT_STAGING="make integration-test"
    ;;
esac

echo "Local validation command (linting, type checking, unit tests):"
echo "Default: $DEFAULT_LOCAL"
read -p "Press Enter to use default, or type custom command: " VALIDATE_LOCAL
if [ -z "$VALIDATE_LOCAL" ]; then
  VALIDATE_LOCAL="$DEFAULT_LOCAL"
fi

echo ""
echo "Staging validation command (integration tests against staging):"
echo "Default: $DEFAULT_STAGING"
read -p "Press Enter to use default, or type custom command: " VALIDATE_STAGING
if [ -z "$VALIDATE_STAGING" ]; then
  VALIDATE_STAGING="$DEFAULT_STAGING"
fi

echo ""

# Optional: Example files
echo "=== Optional Setup ==="
echo ""
read -p "Generate example specs and stdlib? (y/n): " GEN_EXAMPLES

echo ""
echo "=== Generating Files ==="
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STARTER_KIT_DIR="$(dirname "$SCRIPT_DIR")"

# Create ralph.config.sh
echo "Creating ralph.config.sh..."
cat > "$PROJECT_DIR/ralph.config.sh" <<EOF
#!/bin/bash
# Ralph Project Configuration

# =============================================================================
# REQUIRED CONFIGURATION
# =============================================================================

# Git Configuration
export RALPH_GIT_REMOTE="$GIT_REMOTE"
export RALPH_GIT_MAIN_BRANCH="$GIT_MAIN_BRANCH"

# Deployment Configuration
export RALPH_STAGING_URL="$STAGING_URL"
export RALPH_DEPLOY_WAIT_SECONDS=$DEPLOY_WAIT

# Validation Commands
export RALPH_VALIDATE_LOCAL="$VALIDATE_LOCAL"
export RALPH_VALIDATE_STAGING="$VALIDATE_STAGING"

# Health check endpoint
export RALPH_HEALTH_CHECK_PATH="$HEALTH_CHECK"

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================

# Set staging URL as environment variable for integration tests
export RALPH_TEST_ENV_VARS="STAGING_URL=\$RALPH_STAGING_URL"

# Task timeout in minutes (default: 15)
# export RALPH_TASK_TIMEOUT_MINUTES=15

# Auto-archive completed sprints (default: true)
# export RALPH_AUTO_ARCHIVE=true
EOF

chmod +x "$PROJECT_DIR/ralph.config.sh"
echo "✓ Created ralph.config.sh"

# Copy ralph.sh launcher
echo "Copying ralph.sh..."
cp "$STARTER_KIT_DIR/template/ralph.sh" "$PROJECT_DIR/ralph.sh"
chmod +x "$PROJECT_DIR/ralph.sh"
echo "✓ Created ralph.sh"

# Create sprint_plan.md if it doesn't exist
if [ ! -f "$PROJECT_DIR/sprint_plan.md" ]; then
  echo "Creating sprint_plan.md..."
  cp "$STARTER_KIT_DIR/template/sprint_plan.md.template" "$PROJECT_DIR/sprint_plan.md"
  echo "✓ Created sprint_plan.md"
fi

# Create RALPH.md from template
if [ ! -f "$PROJECT_DIR/RALPH.md" ]; then
  echo "Creating RALPH.md..."
  if [ -f "$STARTER_KIT_DIR/examples/$PROJECT_TYPE/RALPH.md" ]; then
    # Use project-type-specific template
    cp "$STARTER_KIT_DIR/examples/$PROJECT_TYPE/RALPH.md" "$PROJECT_DIR/RALPH.md"
  else
    # Use generic template
    cp "$STARTER_KIT_DIR/template/RALPH.md.template" "$PROJECT_DIR/RALPH.md"
  fi
  echo "✓ Created RALPH.md (customize for your project)"
fi

# Create directories
echo "Creating directories..."
mkdir -p "$PROJECT_DIR/specs"
mkdir -p "$PROJECT_DIR/stdlib"
mkdir -p "$PROJECT_DIR/sprints"
echo "✓ Created specs/, stdlib/, sprints/"

# Generate examples if requested
if [ "$GEN_EXAMPLES" == "y" ]; then
  echo "Copying example files..."

  EXAMPLE_DIR="$STARTER_KIT_DIR/examples/$PROJECT_TYPE"
  if [ "$PROJECT_TYPE" == "python" ]; then
    EXAMPLE_DIR="$STARTER_KIT_DIR/examples/python-fastapi"
  elif [ "$PROJECT_TYPE" == "nodejs" ]; then
    EXAMPLE_DIR="$STARTER_KIT_DIR/examples/nodejs-typescript"
  else
    EXAMPLE_DIR="$STARTER_KIT_DIR/examples/generic"
  fi

  if [ -d "$EXAMPLE_DIR/specs" ]; then
    cp -r "$EXAMPLE_DIR/specs"/* "$PROJECT_DIR/specs/" 2>/dev/null || echo "No spec examples available"
    echo "✓ Copied example specs"
  fi

  if [ -d "$EXAMPLE_DIR/stdlib" ]; then
    cp -r "$EXAMPLE_DIR/stdlib"/* "$PROJECT_DIR/stdlib/" 2>/dev/null || echo "No stdlib examples available"
    echo "✓ Copied example stdlib"
  fi
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Files created:"
echo "  ✓ ralph.sh (launcher)"
echo "  ✓ ralph.config.sh (configuration)"
echo "  ✓ RALPH.md (build instructions)"
echo "  ✓ sprint_plan.md (sprint tracker)"
echo "  ✓ specs/ (feature specifications)"
echo "  ✓ stdlib/ (technical patterns)"
echo "  ✓ sprints/ (archive directory)"
echo ""

# iTerm2 hotkey setup (optional but recommended)
echo "=== Optional: iTerm2 Hotkey Setup (Recommended) ==="
echo ""
echo "For the smoothest workflow, set up an iTerm2 hotkey for one-keypress sprint execution."
echo ""
echo "This lets you press Shift+Cmd+R to start a sprint instead of typing commands."
echo ""
read -p "Would you like instructions for setting up iTerm2 hotkeys? (y/n): " SHOW_HOTKEY_INSTRUCTIONS

if [ "$SHOW_HOTKEY_INSTRUCTIONS" == "y" ]; then
  echo ""
  echo "📋 iTerm2 Hotkey Setup Instructions:"
  echo ""
  echo "1. Open iTerm2 Preferences:"
  echo "   Press Cmd+, or use menu: iTerm2 → Preferences"
  echo ""
  echo "2. Navigate to Keys:"
  echo "   Preferences → Keys → Key Bindings"
  echo ""
  echo "3. Add new hotkey:"
  echo "   Click the '+' button at bottom left"
  echo ""
  echo "4. Configure the hotkey:"
  echo "   • Keyboard Shortcut: Press Shift+Cmd+R"
  echo "   • Action: Select 'Send Text with vim Special Chars'"
  echo "   • Text: Type exactly:  claude \"/ralph-continuous\"\\n"
  echo "     (Important: Include the \\n at the end)"
  echo ""
  echo "5. Click OK to save"
  echo ""
  echo "6. Test your hotkey:"
  echo "   • Make sure you're in your project directory (cd $PROJECT_DIR)"
  echo "   • Press Shift+Cmd+R"
  echo "   • You should see Ralph start and open new tabs for each task"
  echo ""
  echo "Optional: Set up additional hotkeys:"
  echo "  • Shift+Cmd+P → claude \"/ralph-plan\"\\n     (sprint planning)"
  echo "  • Shift+Cmd+T → claude \"/ralph\"\\n          (single task)"
  echo "  • Shift+Cmd+A → claude \"/ralph-archive\"\\n  (archive sprint)"
  echo ""
  echo "For detailed troubleshooting, see: $STARTER_KIT_DIR/EXAMPLES.md"
  echo ""

  read -p "Open iTerm2 Preferences now? (y/n): " OPEN_ITERM_PREFS

  if [ "$OPEN_ITERM_PREFS" == "y" ]; then
    # AppleScript to open iTerm2 preferences to the Keys pane
    osascript <<EOF
tell application "iTerm"
  activate
end tell

tell application "System Events"
  tell process "iTerm2"
    keystroke "," using {command down}
  end tell
end tell
EOF
    echo ""
    echo "✓ Opened iTerm2 Preferences"
    echo "  Navigate to: Keys → Key Bindings → Click '+'"
    echo ""
  fi
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Customize RALPH.md with your project's build/test instructions"
echo "2. Add specs to specs/ directory"
echo "3. Add technical patterns to stdlib/ directory"
echo "4. Run your first sprint:"
echo ""
echo "   Option A (with hotkey): Press Shift+Cmd+R"
echo "   Option B (command):     claude \"/ralph-plan\""
echo "   Option C (wrapper):     ./ralph.sh --plan"
echo ""
echo "For detailed examples and troubleshooting:"
echo "  • Quick start: cat $STARTER_KIT_DIR/README.md"
echo "  • Examples:    cat $STARTER_KIT_DIR/EXAMPLES.md"
echo "  • Config ref:  cat $STARTER_KIT_DIR/CONFIGURATION_GUIDE.md"
echo ""
