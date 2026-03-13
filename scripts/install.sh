#!/bin/bash
# Install Ralph skills and agents as symlinks from the kit — kit is single source of truth.
# Usage: ./install.sh
# Run from any directory; script resolves kit location relative to itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_SKILLS_DIR="${SCRIPT_DIR}/../skills"
KIT_AGENTS_DIR="${SCRIPT_DIR}/../agents"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"
CURSOR_SKILLS_DIR="${HOME}/.cursor/skills"
SKILL_NAMES="ralph ralph-plan ralph-continuous ralph-archive"
AGENT_NAMES="code-explorer build-validator playwright-runner deep-investigator"

echo "Installing Ralph skills and agents as symlinks..."
echo "Kit: ${SCRIPT_DIR}/.."
echo ""

mkdir -p "$CLAUDE_SKILLS_DIR"

for skill in $SKILL_NAMES; do
  rm -rf "${CLAUDE_SKILLS_DIR}/${skill}"
  ln -s "${KIT_SKILLS_DIR}/${skill}" "${CLAUDE_SKILLS_DIR}/${skill}"
  echo "✓ ~/.claude/skills/${skill} -> kit/skills/${skill}"
done

echo ""

# Cursor (best-effort — only if ~/.cursor/skills/ exists)
if [ -d "$CURSOR_SKILLS_DIR" ]; then
  echo "Cursor skills directory found — installing there too..."
  for skill in $SKILL_NAMES; do
    rm -rf "${CURSOR_SKILLS_DIR}/${skill}"
    ln -s "${KIT_SKILLS_DIR}/${skill}" "${CURSOR_SKILLS_DIR}/${skill}"
    echo "✓ ~/.cursor/skills/${skill} -> kit/skills/${skill}"
  done
  echo ""
fi

mkdir -p "$CLAUDE_AGENTS_DIR"

for agent in $AGENT_NAMES; do
  rm -f "${CLAUDE_AGENTS_DIR}/${agent}.md"
  ln -s "${KIT_AGENTS_DIR}/${agent}.md" "${CLAUDE_AGENTS_DIR}/${agent}.md"
  echo "✓ ~/.claude/agents/${agent}.md -> kit/agents/${agent}.md"
done

echo ""
echo "✓ Ralph installed successfully."
echo ""
echo "Edit kit/skills/<name>/SKILL.md or kit/agents/<name>.md — changes are live instantly, no reinstall needed."
echo ""
echo "This installer will self-destruct in 10 seconds..."
echo "Press Ctrl+C to keep it."
echo ""
for i in 10 9 8 7 6 5 4 3 2 1; do
  echo -ne "  Deleting in $i...\r"
  sleep 1
done
echo ""
echo "👋 Byeeeeeee. Enjoy Ralph!"
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
rm -- "$0"
