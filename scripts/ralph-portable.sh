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

# ─── Interactive UI ───────────────────────────────────────────────────────
# gum-styled menus/banners when `gum` is on PATH and stdout is a TTY; a plain
# numbered-prompt / ASCII-box fallback otherwise. Set RALPH_UI=plain to force
# the fallback (useful for logs / CI / screenshots without gum).
# Resolve the gum binary: PATH first, then the winget install location
# (AppData\Local\Microsoft\WinGet\Packages\... is not always on Git Bash's PATH).
_UI_GUM_BIN=""
_ui_gum() {
  [ -n "$_UI_GUM_BIN" ] && { printf '%s\n' "$_UI_GUM_BIN"; return 0; }
  local c
  if c="$(command -v gum 2>/dev/null)"; then _UI_GUM_BIN="$c"; printf '%s\n' "$c"; return 0; fi
  for c in "$HOME"/AppData/Local/Microsoft/WinGet/Packages/charmbracelet.gum_*/*/gum.exe \
           "$HOME"/scoop/apps/gum/current/gum.exe \
           /c/ProgramData/chocolatey/bin/gum.exe; do
    [ -x "$c" ] && { _UI_GUM_BIN="$c"; printf '%s\n' "$c"; return 0; }
  done
  return 1
}

_ui_have_gum() {
  [ "${RALPH_UI:-}" != "plain" ] && _ui_gum >/dev/null 2>&1 && [ -t 1 ]
}

# ui_banner COLOR TITLE [LINE...] — boxed banner. COLOR is info|ok|warn|err.
ui_banner() {
  local color="$1"; shift
  local title="$1"; shift
  local gc ac
  case "$color" in
    ok)   gc=42;  ac='1;32' ;;
    warn) gc=214; ac='1;33' ;;
    err)  gc=203; ac='1;31' ;;
    *)    gc=39;  ac='1;34' ;;
  esac
  if _ui_have_gum; then
    "$(_ui_gum)" style --border rounded --border-foreground "$gc" --foreground "$gc" \
      --padding "0 2" --margin "1 0" "$title" "$@"
    return
  fi
  local w=59 fill l
  fill=$(printf '%*s' "$w" '' | tr ' ' '=')
  printf '\n\033[%sm╔%s╗\033[0m\n' "$ac" "$fill"
  printf '\033[%sm║ %-*s ║\033[0m\n' "$ac" "$((w - 2))" "$title"
  for l in "$@"; do printf '\033[%sm║ %-*s ║\033[0m\n' "$ac" "$((w - 2))" "$l"; done
  printf '\033[%sm╚%s╝\033[0m\n\n' "$ac" "$fill"
}

# ui_choose PROMPT OPT... — print the chosen OPT to stdout. Returns 1 on abort
# (Esc / Ctrl-C / EOF / invalid).
ui_choose() {
  local prompt="$1"; shift
  # gum reads the terminal via /dev/tty, so it works even when stdin isn't a
  # TTY (e.g. the script was launched with stdin closed/redirected).
  if _ui_have_gum; then
    "$(_ui_gum)" choose --header "$prompt" "$@" || return 1
    return 0
  fi
  # Prompt + list to stderr so a $(...) caller still shows them; read from stdin
  # (the caller's command substitution inherits it).
  printf '\n\033[1;34m%s\033[0m\n' "$prompt" >&2
  local i=1 opt
  for opt in "$@"; do printf '  \033[0;32m%d\033[0m) %s\n' "$i" "$opt" >&2; i=$((i + 1)); done
  local sel
  read -r -p "Select [1-$#]: " sel || return 1
  case "$sel" in ''|*[!0-9]*) return 1 ;; esac
  { [ "$sel" -ge 1 ] && [ "$sel" -le "$#" ]; } || return 1
  printf '%s\n' "${!sel}"
}

# ui_input PROMPT [PLACEHOLDER] — read one line of text from the user.
ui_input() {
  local prompt="$1" ph="${2:-}"
  if _ui_have_gum; then
    "$(_ui_gum)" input --header "$prompt" --placeholder "$ph"
    return
  fi
  local val
  read -r -p "$prompt " val || return 1
  printf '%s\n' "$val"
}

# ─── Model choices ───────────────────────────────────────────────────────
# Single source of truth for the models Ralph offers. One row per model:
#   alias | menu label | sprint_plan.md label | rough cost per minute (USD)
# The alias is what `claude --model` accepts; aliases auto-resolve to the
# current model version, so this list does not need touching when versions
# change. (There is no CLI that reports the /model list.)
ralph_models() {
  cat <<'MODELS'
sonnet|Sonnet  -  balanced, best for most tasks|Sonnet|0.03
opus|Opus    -  hardest reasoning and debugging|Opus|0.05
haiku|Haiku   -  fastest and cheapest|Haiku|0.01
MODELS
}

# Menu labels (field 2), newline-separated — feed straight to ui_choose.
ralph_model_menu_labels() { ralph_models | cut -d'|' -f2; }

# alias whose menu label == $1 (empty if none — caller should default).
ralph_model_alias_for() {
  local a l s c
  ralph_models | while IFS='|' read -r a l s c; do
    [ "$l" = "$1" ] && printf '%s\n' "$a"
  done
}

# sprint_plan.md label for alias $1 (default: Sonnet).
ralph_model_sprint_label() {
  local a l s c
  { ralph_models | while IFS='|' read -r a l s c; do
      [ "$a" = "$1" ] && printf '%s\n' "$s"
    done; } | grep . || printf 'Sonnet\n'
}

# rough $/min for alias $1 (default: 0.03).
ralph_model_cost_per_min() {
  local a l s c
  { ralph_models | while IFS='|' read -r a l s c; do
      [ "$a" = "$1" ] && printf '%s\n' "$c"
    done; } | grep . || printf '0.03\n'
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
