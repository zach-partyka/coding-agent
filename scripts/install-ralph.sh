#!/bin/bash
# Install Ralph skills as symlinks from the kit — kit is single source of truth.
# Usage: ./install-ralph.sh
# Run from any directory; script resolves kit location relative to itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_SKILLS_DIR="${SCRIPT_DIR}/../skills"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CURSOR_SKILLS_DIR="${HOME}/.cursor/skills"
SKILL_NAMES="ralph ralph-plan ralph-continuous ralph-archive"

echo "Installing Ralph skills as symlinks..."
echo "Kit: ${KIT_SKILLS_DIR}"
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

echo "Done. Edit kit/skills/<name>/SKILL.md — changes are live instantly, no reinstall needed."
