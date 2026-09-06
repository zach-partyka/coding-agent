#!/bin/bash
# Install Ralph skills and agents from the kit — kit is single source of truth.
# Symlinks where the OS/filesystem supports them (macOS, or Windows with
# Developer Mode); a plain copy otherwise (Git Bash without Developer Mode).
# Usage: ./install.sh   — run from any directory; kit location resolves via $0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_SKILLS_DIR="${SCRIPT_DIR}/../skills"
KIT_AGENTS_DIR="${SCRIPT_DIR}/../agents"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"
CURSOR_SKILLS_DIR="${HOME}/.cursor/skills"
SKILL_NAMES="ralph ralph-plan ralph-continuous ralph-archive"
AGENT_NAMES="code-explorer build-validator playwright-runner deep-investigator"

ANY_COPY=0

# link_or_copy SRC DST — native symlink if possible, else recursive copy.
link_or_copy() {
  local src="$1" dst="$2"
  rm -rf "$dst"
  if ln -s "$src" "$dst" 2>/dev/null && [ -L "$dst" ]; then
    return 0
  fi
  rm -rf "$dst"
  cp -R "$src" "$dst"
  ANY_COPY=1
  return 0
}

echo "Installing Ralph skills and agents..."
echo "Kit: ${SCRIPT_DIR}/.."
echo ""

mkdir -p "$CLAUDE_SKILLS_DIR"

for skill in $SKILL_NAMES; do
  link_or_copy "${KIT_SKILLS_DIR}/${skill}" "${CLAUDE_SKILLS_DIR}/${skill}"
  echo "✓ ~/.claude/skills/${skill}"
done

echo ""

# Cursor (best-effort — only if ~/.cursor/skills/ exists)
if [ -d "$CURSOR_SKILLS_DIR" ]; then
  echo "Cursor skills directory found — installing there too..."
  for skill in $SKILL_NAMES; do
    link_or_copy "${KIT_SKILLS_DIR}/${skill}" "${CURSOR_SKILLS_DIR}/${skill}"
    echo "✓ ~/.cursor/skills/${skill}"
  done
  echo ""
fi

mkdir -p "$CLAUDE_AGENTS_DIR"

for agent in $AGENT_NAMES; do
  link_or_copy "${KIT_AGENTS_DIR}/${agent}.md" "${CLAUDE_AGENTS_DIR}/${agent}.md"
  echo "✓ ~/.claude/agents/${agent}.md"
done

echo ""
echo "✓ Ralph installed successfully."
echo ""
if [ "$ANY_COPY" = "1" ]; then
  echo "Note: this OS can't make the links natively, so skills/agents were COPIED."
  echo "After you 'git pull' in the kit, re-run this installer to refresh them."
else
  echo "Edit kit/skills/<name>/SKILL.md or kit/agents/<name>.md — changes are live instantly."
fi
echo "Re-run this installer any time to repair or upgrade."
echo ""
cat << 'DRAGON'
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣠⣤⣴⣶⣾⣿⢿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⡿⢋⡴⠋⣠⡞⠁⣴⠟⢁⣴⠋⠀⣠⡟⠀⢰⡇⠀⢻⡄⠘⣧⠈⠻⣿⡿⣿⣷⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣰⠛⣽⠟⣡⡾⠋⢀⣾⠃⢀⣾⠃⠀⢸⠃⠀⠀⠸⠋⠀⠀⠸⠀⠀⠀⢻⡆⠀⠸⣿⠀⠘⢷⠈⢷⡄⠙⣿⡳⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⣾⢁⣾⠇⢠⡿⠀⠀⢸⡟⠀⠀⠸⠀⠀⠀⠀⠀⢀⣴⠾⠿⠿⠿⠶⣆⡀⠀⠀⠀⠀⠀⠀⣠⡴⠾⠿⠛⠷⢦⡀⢸⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣿⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⣶⣷⠄⠀⠀⠀⢈⣧⠀⠀⠀⢈⣿⠀⠀⠀⢾⣿⠀⠀⢸⠇⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢾⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣧⠀⠀⠀⠀⠀⠀⠀⠙⢷⣤⣀⣀⣠⣤⡾⠟⠀⠀⠛⠒⠶⢶⣮⡛⠷⣶⡴⠶⠋⠀⠀⠀⣿⠀
⠀⠀⠀⠀⠈⠳⣦⣤⣤⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⠿⠛⠻⣷⣄⠀⣠⣴⡿⠀⠀⠀⠀⠀⠀⠀⠀⠻⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠻⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠐⣿⠀⠀⣠⡟⠀⠀⠀⢠⣾⣷⠶⢶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⡾⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢀⡿⠁⠀⠉⠻⢷⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠘⠛⠉⠉⠹⣿⠉⠉⣽⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⣤⣾⠿⣿⣶⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⣿⠏⠉⠉⠙⠿⣶⣦⡀⠀⠀⠀⠀⣿⡿⠿⢿⡟⠁⢈⣿⣷⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀⠈⠻⠿⢶⣄⣀⣾⠟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣄⣠⣿⠀⠀⣸⡿⠋⠈⠻⣷⣻⣿⣦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢀⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⣼⠏⠀⠀⠘⢿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀⠙⠻⣶⣤⣄⡀⠀⠀⠀⠀⠀⠀⣀⣠⣤⣶⡾⠟⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⢻⣧⠀⠀⠀⠀⠀⠀⠀
⢠⣿⠋⠛⠛⠿⢷⣶⣤⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣷⢹⣿⡆⠀⠀⠀⠀⠀
⠀⢻⡟⠛⠿⢷⣶⣤⣄⣀⡀⠀⠀⠀⠉⠉⠉⠛⠛⠛⠻⠿⠿⠿⣿⣿⣶⣶⣶⣶⣶⣶⣶⣿⣿⣿⣿⣿⡟⠛⠛⠛⠉⠉⠉⢻⣿⠉⠉⠉⠀⣿⡇⠸⣿⠀⠀⠀⠀⠀
⠀⠀⢻⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠙⠛⠛⠻⠿⠿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣤⣤⣤⣤⣴⠾⠟⠋⠉⠉⠁⢸⣿⣶⣾⣿⠀⠀⠀⠀⠀
⠀⠀⠀⠘⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⠁⢀⠀⠀⠙⣷⠀⠀⠀
⠀⠀⠀⠀⠀⠈⢿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣾⢣⡆⠀⠀⣏⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠘⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⠿⠿⠋⠉⠉⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⠷⢶⠶⠶⠶⣿⡿⠛⠛⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢰⡏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣾⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣧⠀⠀⠀⠀⠀⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣈⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢠⣾⠛⠻⢿⣷⣶⣦⣤⣤⣤⣤⣤⣤⣤⣶⡶⠿⠿⠿⠿⠿⣶⣄⣀⣸⡇⠀⠀⠉⠉⠙⠛⠛⠛⠛⠉⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠈⠉⠻⠷⣦⣄⠀⠀
⠀⠀⠀⠀⠀⠉⠛⠷⢶⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠛⣿⣷⣶⣶⣤⣤⣤⣤⣄⣀⣀⣀⣀⡀⠀⠀⠀⠀⠀⣀⣀⣀⣠⣴⡿⠇
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠛⠛⠻⠿⠿⠷⠶⣶⣶⣶⣶⣦⣤⣤⣤⣤⣤⣶⣶⠿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
DRAGON
