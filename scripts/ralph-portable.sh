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

# ─── Python interpreter discovery ──────────────────────────────────────────
# Print the name of a working Python interpreter (python3, python, or the
# Windows `py` launcher), or return 1 if none is usable. Rejects the Windows
# Store App-Execution-Alias stub (on PATH, but runs nothing).
# Caller:  "$(ralph_python)" script.py args...
ralph_python() {
  local p
  for p in python3 python py; do
    command -v "$p" >/dev/null 2>&1 || continue
    if [ "$("$p" -c 'print(1)' 2>/dev/null)" = "1" ]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

# ─── Minimal JSON reader ───────────────────────────────────────────────────
# json_str FILE KEY  — print the top-level string/number value for KEY.
# Uses jq when present, else Python, else prints nothing. Never aborts.
json_str() {
  local file="${1:-}" key="${2:-}" py
  { [ -n "$file" ] && [ -n "$key" ] && [ -f "$file" ]; } || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null || true
    return 0
  fi
  if py="$(ralph_python)"; then
    "$py" -c 'import json,sys
try:
    d = json.load(open(sys.argv[1]))
    v = d.get(sys.argv[2])
    print("" if v is None else v)
except Exception:
    pass' "$file" "$key" 2>/dev/null || true
  fi
  return 0
}

# ─── Line counting ────────────────────────────────────────────────────────
# count_matches PATTERN FILE  — number of lines in FILE matching extended-regex
# PATTERN. Prints 0 on no match, missing file, or error. Avoids the
# `x=$(grep -cE ... || echo 0)` pitfall where `grep -c` prints "0" AND exits 1,
# so `|| echo 0` appends a second value and `[ "$x" -eq 0 ]` then blows up.
count_matches() {
  local n
  n=$(grep -cE "$1" "$2" 2>/dev/null || true)
  n=${n%%[!0-9]*}
  printf '%s\n' "${n:-0}"
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
