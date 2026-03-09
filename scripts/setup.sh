#!/bin/bash
# Ralph Starter Kit - Interactive Setup Script

set -e

# Detect platform and check prerequisites
detect_platform() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "mingw"* ]]; then
    PLATFORM="windows"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
  else
    PLATFORM="unknown"
  fi
}

check_prerequisites() {
  # Check for bash (should always exist if we're running, but validate)
  if ! command -v bash &> /dev/null; then
    echo "❌ Bash not found"
    exit 1
  fi

  # Windows-specific checks
  if [[ "$PLATFORM" == "windows" ]]; then
    if ! command -v wt.exe &> /dev/null; then
      echo "⚠️  Windows Terminal not found (optional but recommended)"
      echo "   Install from: https://aka.ms/terminal"
      echo "   Without it, Ralph will run in inline mode (slower but functional)"
      echo ""
      read -p "Continue anyway? (y/N): " -n 1 -r
      echo
      [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
  fi

  # Check for Claude CLI (all platforms)
  if ! command -v claude &> /dev/null; then
    echo "❌ Claude CLI not found"
    echo "   Make sure 'claude' command is available in your PATH"
    exit 1
  fi
}

# Run checks
detect_platform
check_prerequisites

# Parse arguments
CUSTOM_INSTALL_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --path)
      CUSTOM_INSTALL_PATH="$2"
      shift 2
      ;;
    --help)
      echo "Usage: setup.sh [--path /custom/path]"
      echo ""
      echo "Options:"
      echo "  --path DIR    Install ralph-continuous.sh to custom directory"
      echo "                (default: ~/Documents/ralph)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run 'setup.sh --help' for usage"
      exit 1
      ;;
  esac
done

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

# Deploy Target Configuration
echo "=== Deploy Environment ==="
echo ""

read -p "Enter your deploy target URL (e.g., https://your-app-dev.your-domain.com): " STAGING_URL

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
echo "Dev validation command (integration tests against your dev site):"
echo "Default: $DEFAULT_STAGING"
read -p "Press Enter to use default, or type custom command: " VALIDATE_STAGING
if [ -z "$VALIDATE_STAGING" ]; then
  VALIDATE_STAGING="$DEFAULT_STAGING"
fi

echo ""

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
export RALPH_DEPLOY_URL="$STAGING_URL"
export RALPH_DEPLOY_WAIT_SECONDS=$DEPLOY_WAIT

# Validation Commands
export RALPH_VALIDATE_LOCAL="$VALIDATE_LOCAL"
export RALPH_VALIDATE_DEPLOY="$VALIDATE_STAGING"

# Health check endpoint
export RALPH_HEALTH_CHECK_PATH="$HEALTH_CHECK"

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================

# Set deploy URL as environment variable for integration tests
export RALPH_TEST_ENV_VARS="STAGING_URL=\$RALPH_DEPLOY_URL"

# Task timeout in minutes (default: 15)
# export RALPH_TASK_TIMEOUT_MINUTES=15

# Auto-archive completed sprints (default: true)
# export RALPH_AUTO_ARCHIVE=true
EOF

chmod +x "$PROJECT_DIR/ralph.config.sh"
echo "✓ Created ralph.config.sh"

# Copy ralph.sh launcher
echo "Copying ralph.sh..."
cp "$STARTER_KIT_DIR/scripts/ralph.sh" "$PROJECT_DIR/ralph.sh"
chmod +x "$PROJECT_DIR/ralph.sh"
echo "✓ Created ralph.sh"

# Install ralph-continuous.sh to global location (one-time)
if [ -n "$CUSTOM_INSTALL_PATH" ]; then
  GLOBAL_RALPH_DIR="$CUSTOM_INSTALL_PATH"
else
  GLOBAL_RALPH_DIR="$HOME/Documents/ralph"
fi

GLOBAL_RALPH_SCRIPT="$GLOBAL_RALPH_DIR/ralph-continuous.sh"

if [ ! -f "$GLOBAL_RALPH_SCRIPT" ]; then
  echo "Installing ralph-continuous.sh globally..."
  mkdir -p "$GLOBAL_RALPH_DIR"
  cp "$STARTER_KIT_DIR/scripts/ralph-continuous.sh" "$GLOBAL_RALPH_SCRIPT"
  chmod +x "$GLOBAL_RALPH_SCRIPT"
  echo "✓ Installed to $GLOBAL_RALPH_SCRIPT"
else
  echo "✓ ralph-continuous.sh already installed at $GLOBAL_RALPH_SCRIPT"
fi

# Install Ralph skills to Claude Code (one-time)
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
if [ -d "$STARTER_KIT_DIR/skills" ]; then
  echo "Installing Ralph skills to Claude Code..."
  mkdir -p "$CLAUDE_SKILLS_DIR"

  for skill in ralph ralph-plan ralph-continuous ralph-archive; do
    if [ ! -d "$CLAUDE_SKILLS_DIR/$skill" ]; then
      cp -r "$STARTER_KIT_DIR/skills/$skill" "$CLAUDE_SKILLS_DIR/"
      echo "✓ Installed $skill skill"
    else
      echo "✓ $skill skill already installed"
    fi
  done
else
  echo "⚠️  Skills directory not found in starter kit"
fi

# Install subagents to project
if [ -d "$STARTER_KIT_DIR/.claude/agents" ]; then
  echo "Installing subagents..."
  mkdir -p "$PROJECT_DIR/.claude/agents"
  for agent in codebase-scout deep-investigator test-runner validation-runner; do
    if [ ! -f "$PROJECT_DIR/.claude/agents/$agent.md" ]; then
      cp "$STARTER_KIT_DIR/.claude/agents/$agent.md" "$PROJECT_DIR/.claude/agents/"
      echo "✓ Installed $agent"
    else
      echo "✓ $agent already installed"
    fi
  done
fi

# Create sprint_plan.md if it doesn't exist
if [ ! -f "$PROJECT_DIR/sprint_plan.md" ]; then
  echo "Creating sprint_plan.md..."
  cp "$STARTER_KIT_DIR/template/sprint_plan.md.template" "$PROJECT_DIR/sprint_plan.md"
  echo "✓ Created sprint_plan.md"
fi

# Create RALPH.md from template
if [ ! -f "$PROJECT_DIR/RALPH.md" ]; then
  echo "Creating RALPH.md..."
  cp "$STARTER_KIT_DIR/RALPH.md" "$PROJECT_DIR/RALPH.md"
  echo "✓ Created RALPH.md"
fi

# Create roadmap.md from template
if [ ! -f "$PROJECT_DIR/roadmap.md" ]; then
  echo "Creating roadmap.md..."
  cp "$STARTER_KIT_DIR/template/roadmap.md.template" "$PROJECT_DIR/roadmap.md"
  echo "✓ Created roadmap.md (add your Now/Next/Later items)"
fi

# Create directories
echo "Creating directories..."
mkdir -p "$PROJECT_DIR/specs"
mkdir -p "$PROJECT_DIR/stdlib"
mkdir -p "$PROJECT_DIR/sprints"
echo "✓ Created specs/, stdlib/, sprints/"

# Copy sprint templates
if [ ! -f "$PROJECT_DIR/sprints/sprint_history.md" ]; then
  cp "$STARTER_KIT_DIR/template/sprints/sprint_history.md" "$PROJECT_DIR/sprints/sprint_history.md"
  echo "✓ Created sprints/sprint_history.md"
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Files created:"
echo "  ✓ ralph.sh (launcher)"
echo "  ✓ ralph.config.sh (configuration)"
echo "  ✓ RALPH.md (build instructions)"
echo "  ✓ roadmap.md (product roadmap — Now/Next/Later)"
echo "  ✓ sprint_plan.md (sprint tracker)"
echo "  ✓ specs/ (feature specifications)"
echo "  ✓ stdlib/ (technical patterns)"
echo "  ✓ sprints/ (sprint archives + history)"
echo "  ✓ ralph-continuous.sh available at $GLOBAL_RALPH_DIR/"
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
  echo "For detailed troubleshooting, see: README-MAC.md"
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
echo "2. Add items to roadmap.md (Now section = ready for sprints)"
echo "3. Add specs to specs/ directory"
echo "4. Add technical patterns to stdlib/ directory"
echo "5. Run your first sprint:"
echo ""
echo "   Option A (with hotkey): Press Shift+Cmd+R"
echo "   Option B (command):     claude \"/ralph-plan\""
echo "   Option C (wrapper):     ./ralph.sh --plan"
echo ""
echo "For help: cat $STARTER_KIT_DIR/README-MAC.md"
echo ""
