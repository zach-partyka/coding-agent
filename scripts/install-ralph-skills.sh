#!/bin/bash
# Install Ralph skills into ~/.claude/skills/ from the canonical skills repo.
# Single source of truth: the ralph-skills repo (GitLab or GitHub).
# Usage: ./install-ralph-skills.sh [SKILLS_REPO_URL]

set -euo pipefail

CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
RALPH_SKILLS_REPO="${1:-https://gitlab.zgtools.net/tpm_cdp_team/ralph-skills.git}"
SKILL_NAMES="ralph ralph-plan ralph-continuous ralph-archive"

echo "Installing Ralph skills to ${CLAUDE_SKILLS_DIR}..."
echo "Source: ${RALPH_SKILLS_REPO}"
echo ""

mkdir -p "$CLAUDE_SKILLS_DIR"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if git clone --depth 1 "$RALPH_SKILLS_REPO" "$TMP_DIR/repo" 2>/dev/null; then
  for skill in $SKILL_NAMES; do
    if [ -d "$TMP_DIR/repo/$skill" ]; then
      rm -rf "${CLAUDE_SKILLS_DIR:?}/$skill"
      cp -r "$TMP_DIR/repo/$skill" "$CLAUDE_SKILLS_DIR/"
      echo "✓ $skill"
    else
      echo "⚠ $skill not found in repo, skipped"
    fi
  done
  echo ""
  echo "Done. Claude will load skills from ${CLAUDE_SKILLS_DIR}"
else
  echo "Failed to clone skills repo: ${RALPH_SKILLS_REPO}" >&2
  echo "Create the repo and push the four skill directories (ralph, ralph-plan, ralph-continuous, ralph-archive)." >&2
  echo "See Ralph/SKILLS.md for one-time setup." >&2
  exit 1
fi
