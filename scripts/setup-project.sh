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

# link_or_copy SRC DST — native symlink where possible (macOS, or Windows with
# Developer Mode), else a plain copy. Sets LINK_FELL_BACK=1 on copy. Never aborts.
link_or_copy() {
  local src="$1" dst="$2"
  rm -rf "$dst"
  if ln -s "$src" "$dst" 2>/dev/null && [ -L "$dst" ]; then
    return 0
  fi
  rm -rf "$dst"
  cp -R "$src" "$dst"
  LINK_FELL_BACK=1
  return 0
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

  # gum is optional — it only styles the "kit update available" notice shown at
  # the start of a sprint. Never let a failed install abort setup.
  if ! command -v gum &>/dev/null; then
    case "$PLATFORM" in
      macos)
        if ! command -v brew &>/dev/null; then
          echo "Homebrew not found — installing it first (for gum)..."
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
          if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
          elif [ -f "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
          fi
        fi
        if command -v brew &>/dev/null; then
          echo "Installing gum (styles Ralph's update notifications)..."
          brew install gum && echo "✓ Installed gum" || true
        else
          echo "⚠️  Skipped gum — update notifications will be plain text."
          echo "   Install later: https://brew.sh, then: brew install gum"
        fi
        ;;
      windows)
        if command -v winget &>/dev/null; then
          echo "Installing gum via winget (styles Ralph's update notifications)..."
          winget install --id charmbracelet.gum -e --accept-source-agreements --accept-package-agreements \
            || echo "⚠️  winget install failed — update notifications will be plain text."
        else
          echo "⚠️  gum not found (optional). Install later: winget install charmbracelet.gum"
        fi
        ;;
      *)
        echo "⚠️  gum not found (optional — styles update notifications). See https://github.com/charmbracelet/gum"
        ;;
    esac
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

# Resolve starter kit directory early (needed for project detection guard below)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STARTER_KIT_DIR="$(dirname "$SCRIPT_DIR")"

# Get project directory
CURRENT_DIR="$(pwd)"
if [ -d "$CURRENT_DIR/.git" ] && [ "$CURRENT_DIR" != "$STARTER_KIT_DIR" ]; then
  # Already inside a git repo that isn't the starter kit — use it
  PROJECT_DIR="$CURRENT_DIR"
else
  # Not in a project repo — find candidates in ~/Documents
  echo "Which project directory should I set up Ralph in?"
  echo ""

  GIT_PROJECTS=()
  while IFS= read -r git_dir; do
    project="$(dirname "$git_dir")"
    # Exclude the starter kit itself
    [ "$project" != "$STARTER_KIT_DIR" ] && GIT_PROJECTS+=("$project")
  done < <({ find "$HOME/Documents" -maxdepth 4 -name ".git" -type d 2>/dev/null
             [ -d "$HOME/OneDrive/Documents" ] && find "$HOME/OneDrive/Documents" -maxdepth 4 -name ".git" -type d 2>/dev/null
           } | head -n 10)

  if [ ${#GIT_PROJECTS[@]} -gt 0 ]; then
    echo "Found git projects:"
    echo ""
    for i in "${!GIT_PROJECTS[@]}"; do
      echo "  $((i+1))) ${GIT_PROJECTS[$i]}"
    done
    echo ""
    echo "  0) Enter a different path"
    echo ""
    read -p "Select [1-${#GIT_PROJECTS[@]}] or 0: " selection

    if [ "$selection" = "0" ]; then
      read -p "Enter path: " PROJECT_DIR
      PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
    elif [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -le ${#GIT_PROJECTS[@]} ]; then
      PROJECT_DIR="${GIT_PROJECTS[$((selection-1))]}"
    else
      echo "Invalid selection. Exiting."
      exit 1
    fi
  else
    echo "No git projects found in ~/Documents. Enter path manually:"
    read -p "> " PROJECT_DIR
    PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
  fi

  if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    echo "Invalid directory. Exiting."
    exit 1
  fi

  cd "$PROJECT_DIR"
fi

# Check if already set up
if [ -f "$PROJECT_DIR/ralph-config.md" ]; then
  echo "⚠️  ralph-config.md already exists in this directory."
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

# Create ralph-config.md
echo "Creating ralph-config.md..."
# On Windows, ralph-continuous.sh opens each task in a Windows Terminal tab whose
# profile name must match this value (defaults to "Git Bash" if the line is absent).
WT_PROFILE_CFG=""
if [ "$PLATFORM" = "windows" ]; then
  WT_PROFILE_CFG='RALPH_WT_PROFILE="Git Bash"   # must match your Windows Terminal profile name exactly'
fi
cat > "$PROJECT_DIR/ralph-config.md" <<EOF
# Ralph config

Ralph scripts and agents read the block below for deploy URL, validation commands, and git. See RALPH_CONFIG.md in the Ralph kit.

\`\`\`ralph-config
RALPH_GIT_REMOTE="$GIT_REMOTE"
RALPH_GIT_MAIN_BRANCH="$GIT_MAIN_BRANCH"
RALPH_DEPLOY_URL="$STAGING_URL"
RALPH_DEPLOY_WAIT_SECONDS=$DEPLOY_WAIT
RALPH_VALIDATE_LOCAL="$VALIDATE_LOCAL"
RALPH_VALIDATE_DEPLOY="$VALIDATE_STAGING"
RALPH_HEALTH_CHECK_PATH="$HEALTH_CHECK"
RALPH_TEST_ENV_VARS="STAGING_URL=\$RALPH_DEPLOY_URL"
EOF
[ -n "$WT_PROFILE_CFG" ] && printf '%s\n' "$WT_PROFILE_CFG" >> "$PROJECT_DIR/ralph-config.md"
printf '%s\n' '```' >> "$PROJECT_DIR/ralph-config.md"
echo "✓ Created ralph-config.md"

# Copy ralph.sh launcher
echo "Copying ralph.sh..."
cp "$STARTER_KIT_DIR/scripts/ralph.sh" "$PROJECT_DIR/ralph.sh"
chmod +x "$PROJECT_DIR/ralph.sh"
echo "✓ Created ralph.sh"

# Install the global Ralph runtime (refreshed on every run so it can't go stale)
if [ -n "$CUSTOM_INSTALL_PATH" ]; then
  GLOBAL_RALPH_DIR="$CUSTOM_INSTALL_PATH"
else
  GLOBAL_RALPH_DIR="$HOME/Documents/ralph"
fi

GLOBAL_RALPH_SCRIPT="$GLOBAL_RALPH_DIR/ralph-continuous.sh"

echo "Installing Ralph runtime to $GLOBAL_RALPH_DIR ..."
mkdir -p "$GLOBAL_RALPH_DIR"
cp "$STARTER_KIT_DIR/scripts/ralph-continuous.sh"   "$GLOBAL_RALPH_DIR/ralph-continuous.sh"
cp "$STARTER_KIT_DIR/scripts/ralph-task-wrapper.sh" "$GLOBAL_RALPH_DIR/ralph-task-wrapper.sh"
cp "$STARTER_KIT_DIR/scripts/ralph-portable.sh"     "$GLOBAL_RALPH_DIR/ralph-portable.sh"
chmod +x "$GLOBAL_RALPH_DIR/ralph-continuous.sh" "$GLOBAL_RALPH_DIR/ralph-task-wrapper.sh"
echo "✓ Installed ralph-continuous.sh, ralph-task-wrapper.sh, ralph-portable.sh"

# Install Ralph skills and agents to Claude Code (symlinks — kit is single source of truth)
echo "Installing Ralph skills and agents..."
bash "${STARTER_KIT_DIR}/scripts/install.sh"

# Create sprint_plan.md if it doesn't exist
if [ ! -f "$PROJECT_DIR/sprint_plan.md" ]; then
  echo "Creating sprint_plan.md..."
  cp "$STARTER_KIT_DIR/template/sprint_plan.md.template" "$PROJECT_DIR/sprint_plan.md"
  echo "✓ Created sprint_plan.md"
fi

# Link RALPH.md (symlink so all projects share the kit's version; copy where
# native symlinks aren't available, e.g. Git Bash without Developer Mode)
echo "Linking RALPH.md..."
link_or_copy "$STARTER_KIT_DIR/RALPH.md" "$PROJECT_DIR/RALPH.md"
if [ "${LINK_FELL_BACK:-0}" = "1" ]; then
  echo "✓ Copied RALPH.md (symlinks unavailable — re-run setup-project.sh after 'git pull' in the kit)"
else
  echo "✓ Linked RALPH.md (global — updates automatically with git pull)"
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

# stdlib/ is intentionally empty — stack standards now live in ralph-config.md
echo "✓ stdlib/ directory ready (stack standards are in ralph-config.md ## Stack Standards)"

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
echo "  ✓ ralph-config.md (configuration)"
echo "  ✓ RALPH.md (build instructions — symlinked to kit, updates with git pull)"
echo "  ✓ roadmap.md (product roadmap — Now/Next/Later)"
echo "  ✓ sprint_plan.md (sprint tracker)"
echo "  ✓ specs/ (feature specifications)"
echo "  ✓ stdlib/ (empty — stack standards live in ralph-config.md ## Stack Standards)"
echo "  ✓ sprints/ (sprint archives + history)"
echo "  ✓ ralph-continuous.sh available at $GLOBAL_RALPH_DIR/"
echo ""

# One-key launch setup (optional) — platform-specific
if [ "$PLATFORM" = "macos" ]; then
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
    echo "For detailed troubleshooting, see: docs/EXAMPLES.md"
    echo ""

    read -p "Open iTerm2 Preferences now? (y/n): " OPEN_ITERM_PREFS

    if [ "$OPEN_ITERM_PREFS" == "y" ]; then
      # AppleScript to open iTerm2 preferences to the Keys pane
      osascript <<'OSA'
tell application "iTerm"
  activate
end tell

tell application "System Events"
  tell process "iTerm2"
    keystroke "," using {command down}
  end tell
end tell
OSA
      echo ""
      echo "✓ Opened iTerm2 Preferences"
      echo "  Navigate to: Keys → Key Bindings → Click '+'"
      echo ""
    fi
  fi
elif [ "$PLATFORM" = "windows" ]; then
  echo "=== Optional: Windows Terminal one-key launch ==="
  echo ""
  echo "Bind a key in Windows Terminal so one keypress starts a sprint."
  echo ""
  echo "  1. Windows Terminal → Ctrl+, → \"Open JSON file\""
  echo "  2. Add to the \"actions\" array:"
  echo '       { "command": { "action": "sendInput", "input": "claude \"/ralph-continuous\"\r" }, "id": "User.ralphContinuous" }'
  echo "  3. Add to the \"keybindings\" array:"
  echo '       { "id": "User.ralphContinuous", "keys": "ctrl+shift+r" }'
  echo ""
  echo "  Full walkthrough (incl. the no-prompt variant and profile-name notes):"
  echo "    $STARTER_KIT_DIR/docs/EXAMPLES.md  (\"Windows Terminal Hotkey Setup\")"
  echo ""
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Customize RALPH.md with your project's build/test instructions"
echo "2. Add items to roadmap.md (Now section = ready for sprints)"
echo "3. Add specs to specs/ directory"
echo "4. Review the ## Stack Standards section in ralph-config.md — customize for your stack"
echo "5. Run your first sprint:"
echo ""
if [ "$PLATFORM" = "windows" ]; then
  echo "   Option A (with hotkey): Press Ctrl+Shift+R  (after the Windows Terminal setup above)"
  HELP_DOC="docs/README-WINDOWS.md"
else
  echo "   Option A (with hotkey): Press Shift+Cmd+R"
  HELP_DOC="docs/README-MAC.md"
fi
echo "   Option B (command):     claude \"/ralph-plan\""
echo "   Option C (wrapper):     ./ralph.sh --plan"
echo ""
echo "For help: cat $STARTER_KIT_DIR/$HELP_DOC"
echo ""
