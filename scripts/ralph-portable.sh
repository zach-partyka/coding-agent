#!/bin/bash
# ralph-portable.sh — cross-platform shell helpers for the Ralph scripts.
# Sourced by scripts in this directory — not executed directly.
# Must be safe under `set -euo pipefail`: a missing tool (uuidgen, python, bc)
# must degrade, never abort the caller.

# ─── BSD (macOS) vs GNU (Linux / Git Bash) sed & date ───────────────────────
if [[ "${OSTYPE:-}" == darwin* ]]; then
  sed_i()   { sed -i '' "$@"; }
  date_fmt() { date -r "$1" "$2"; }
else
  sed_i()   { sed -i "$@"; }
  date_fmt() { date -d "@$1" "$2"; }
fi

# ─── UUID generation (used for `claude --session-id`) ───────────────────────

# Strip CR/LF (Windows tools add them) and lowercase.
_uuid_normalize() {
  local u="${1:-}"
  u="$(printf '%s' "$u" | tr -d '\r\n')"
  if command -v tr >/dev/null 2>&1; then
    printf '%s\n' "$u" | tr '[:upper:]' '[:lower:]'
  else
    printf '%s\n' "$u"
  fi
}

# Last-resort UUID-shaped string from $RANDOM. NOT cryptographically strong —
# only needs to be a unique-enough session identifier.
_uuid_via_bash() {
  printf '%08x-%04x-4%03x-%04x-%012x\n' \
    $(( ((RANDOM << 15) | RANDOM) & 0xffffffff )) \
    $(( RANDOM & 0xffff )) \
    $(( RANDOM & 0x0fff )) \
    $(( (RANDOM & 0x3fff) | 0x8000 )) \
    $(( ((RANDOM << 30) | (RANDOM << 15) | RANDOM) & 0xffffffffffff ))
}

# Windows PowerShell GUID.
_uuid_via_powershell() {
  local ps=""
  if command -v powershell.exe >/dev/null 2>&1; then
    ps="powershell.exe"
  elif command -v pwsh >/dev/null 2>&1; then
    ps="pwsh"
  else
    return 1
  fi
  "$ps" -NoProfile -Command "[guid]::NewGuid().ToString()" 2>/dev/null || return 1
}

# Try, in order: uuidgen, the kernel RNG, python3, python, PowerShell, bash.
# Never aborts, always prints something UUID-shaped.
generate_uuid() {
  local u=""
  if command -v uuidgen >/dev/null 2>&1; then
    u="$(uuidgen 2>/dev/null || true)"
  fi
  if [ -z "$u" ] && [ -r /proc/sys/kernel/random/uuid ]; then
    u="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  fi
  if [ -z "$u" ] && command -v python3 >/dev/null 2>&1; then
    u="$(python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || true)"
  fi
  if [ -z "$u" ] && command -v python >/dev/null 2>&1; then
    u="$(python -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || true)"
  fi
  if [ -z "$u" ]; then
    u="$(_uuid_via_powershell 2>/dev/null || true)"
  fi
  if [ -z "$u" ]; then
    u="$(_uuid_via_bash)"
  fi
  _uuid_normalize "$u"
}

# ─── Cost formatting ───────────────────────────────────────────────────────
# Print a 2-decimal amount. Return the literal "-.--" for empty / null /
# non-numeric input so a missing cost can never be rendered as "0.00".
# A genuine 0 still formats as "0.00".
format_cost_or_unavailable() {
  local raw="${1:-}"
  case "$raw" in
    ""|null|NULL|None|none|nan|NaN) printf '%s\n' "-.--"; return 0 ;;
  esac
  case "$raw" in
    *[!0-9.]*|*.*.*|.) printf '%s\n' "-.--"; return 0 ;;
  esac
  local out
  out="$(printf '%.2f' "$raw" 2>/dev/null || printf '%s' "-.--")"
  case "$out" in
    "-.--") printf '%s\n' "-.--"; return 0 ;;
    .*)     out="0$out" ;;
  esac
  printf '%s\n' "$out"
}

# ─── Marker-file polling ───────────────────────────────────────────────────
# wait_for_marker SUCCESS_FILE TIMEOUT_SECONDS [FAIL_FILE]
#   0  -> SUCCESS_FILE appeared (and was consumed)
#   1  -> FAIL_FILE appeared (consumed), or TIMEOUT_SECONDS elapsed
wait_for_marker() {
  local success="${1:-}" timeout="${2:-0}" fail="${3:-}"
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    if [ -n "$success" ] && [ -f "$success" ]; then
      rm -f "$success"
      return 0
    fi
    if [ -n "$fail" ] && [ -f "$fail" ]; then
      rm -f "$fail"
      return 1
    fi
    sleep 3
    elapsed=$((elapsed + 3))
  done
  return 1
}
