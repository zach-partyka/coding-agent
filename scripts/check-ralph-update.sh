#!/bin/bash
# Check if the Ralph starter kit has updates on the remote. Runs automatically
# from ralph-continuous; prompts to update (y/N) when behind. Does not pull
# unless user says yes.
# Usage: ./check-ralph-update.sh [KIT_ROOT]
#   KIT_ROOT = directory containing .git and scripts/ (default: parent of this script's dir)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
REMOTE="${RALPH_UPDATE_REMOTE:-origin}"
BRANCH="${RALPH_UPDATE_BRANCH:-main}"

if [ ! -d "$KIT_ROOT/.git" ]; then
  exit 0
fi

cd "$KIT_ROOT" || exit 0

if ! git fetch "$REMOTE" "$BRANCH" 2>/dev/null; then
  exit 0
fi

BEHIND=$(git rev-list --count "HEAD..${REMOTE}/${BRANCH}" 2>/dev/null || echo "0")
if [ "${BEHIND:-0}" -le 0 ]; then
  exit 0
fi

echo ""
echo "A new version of Ralph is available ($BEHIND commit(s) behind $REMOTE/$BRANCH)."

if [ -t 0 ]; then
  read -p "Update now? (y/N): " reply
  if [[ "$reply" =~ ^[Yy] ]]; then
    if git pull "$REMOTE" "$BRANCH"; then
      echo "Ralph updated. Continuing."
    else
      echo "Update failed. You can run: cd $KIT_ROOT && git pull $REMOTE $BRANCH"
    fi
  fi
else
  echo "To update:  cd $KIT_ROOT && git pull $REMOTE $BRANCH"
fi
echo ""
