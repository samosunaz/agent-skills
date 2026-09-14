#!/usr/bin/env bash
# Installs the shunt gates as Codex PreToolUse hooks in the CURRENT repo, or
# reports on them with --check. Codex CLI 0.154.0 does not load hooks shipped
# inside a plugin, so the hooks file is written per repo instead.
#
# Writes only <repo>/.codex/hooks.json and, when absent, <repo>/.codex/config.toml.
# It NEVER touches ~/.codex: that file belongs to the user (and to whatever tool
# manages it), and the project layer is enough for a repo-scoped gate.
#
# Usage:  bash install-codex.sh          install or refresh
#         bash install-codex.sh --check  report only, writes nothing
#
# Fails open like the gates themselves: a missing jq or an unreadable file is a
# reported gap, never a non-zero exit.

set -uo pipefail

MODE=install
case "${1:-}" in
  --check) MODE=check ;;
  "") ;;
  *) printf 'usage: install-codex.sh [--check]\n' >&2; exit 2 ;;
esac

GAP_COUNT=0
pass() { printf '[PASS] %s — %s\n' "$1" "$2"; }
gap()  { printf '[GAP]  %s — %s\n' "$1" "$2"; GAP_COUNT=$((GAP_COUNT + 1)); }

verdict() {
  printf '\n'
  if [ "$GAP_COUNT" -eq 0 ]; then
    printf 'SHUNT-CODEX: PASS — 0 gaps\n'
  else
    printf 'SHUNT-CODEX: FAIL — %d gap(s)\n' "$GAP_COUNT"
  fi
  exit 0
}

# The plugin ships the gates; the hooks file must point at them by absolute
# path, because Codex sets no plugin-root variable for a project-level hook.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$PLUGIN_ROOT" ] || PLUGIN_ROOT="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
READ_GATE="$PLUGIN_ROOT/scripts/check-read.sh"
SEARCH_GATE="$PLUGIN_ROOT/scripts/check-search.sh"

DOT=.codex
HOOKS="$DOT/hooks.json"
CONF="$DOT/config.toml"
CODEX_CONF="${CODEX_HOME:-$HOME/.codex}/config.toml"

if ! command -v jq >/dev/null 2>&1; then
  gap "jq" "not on PATH; the hooks file cannot be composed safely"
  verdict
fi

read_cmd="SHUNT_CLIENT=codex bash \"$READ_GATE\""
search_cmd="SHUNT_CLIENT=codex bash \"$SEARCH_GATE\""

# Every Codex shell tool reports as `Bash`; it has no Read or Grep tool, so one
# matcher covers both gates.
desired() {
  jq -n --arg r "$read_cmd" --arg s "$search_cmd" '
    [ {matcher: "Bash", hooks: [{type: "command", command: $r, timeout: 5}]},
      {matcher: "Bash", hooks: [{type: "command", command: $s, timeout: 5}]} ]'
}

# Replaces this plugin's own groups and leaves every other hook in place.
merged() {
  local existing='{}'
  [ -f "$HOOKS" ] && existing="$(cat "$HOOKS" 2>/dev/null)"
  printf '%s' "$existing" | jq --argjson add "$(desired)" '
    (.hooks // {}) as $h
    | .hooks = ($h | .PreToolUse = (
        (($h.PreToolUse // [])
          | map(select(([.hooks[]?.command // ""]
              | map(select(contains("shunt/scripts/check-")))
              | length) == 0)))
        + $add))'
}

# Prints "<state>|<referenced path>" for the handler that names $1. Matching is
# by script name, not by the path this installer would write: a hooks file
# pointing at a plugin that has since moved must read as stale, not as absent.
gate_state() {
  local base="$1"
  [ -f "$HOOKS" ] || { printf 'absent|'; return; }
  local cmd ref
  cmd="$(jq -r --arg s "$base" '
    [.hooks.PreToolUse[]?.hooks[]?.command // "" | select(contains($s))] | .[0] // empty
  ' "$HOOKS" 2>/dev/null)"
  [ -n "$cmd" ] || { printf 'absent|'; return; }
  ref="${cmd#*\"}"; ref="${ref%\"*}"
  if [ -f "$ref" ]; then printf 'ok|%s' "$ref"; else printf 'stale|%s' "$ref"; fi
}

report_one_gate() {
  local id="$1" base="$2" st ref
  st="$(gate_state "$base")"
  ref="${st#*|}"; st="${st%%|*}"
  case "$st" in
    ok)    pass "$id" "$ref" ;;
    stale) gap  "$id" "$HOOKS points at $ref, which does not exist; re-run this installer" ;;
    *)     gap  "$id" "no PreToolUse handler references $base" ;;
  esac
}

report_gates() {
  report_one_gate "read-gate"   "check-read.sh"
  report_one_gate "search-gate" "check-search.sh"
}

# Codex skips an untrusted handler in silence. The hash is computed inside
# Codex over the normalized handler identity, so it cannot be produced here —
# but an entry keyed by this repo's hooks file proves the prompt was answered
# at least once.
report_trust() {
  local key abs
  abs="$(cd "$DOT" 2>/dev/null && pwd)/hooks.json"
  if [ ! -f "$CODEX_CONF" ]; then
    gap "trust" "no $CODEX_CONF; open codex once in this repo and approve the two handlers"
    return
  fi
  key="$(grep -c "^\[hooks\.state\.\"${abs}:pre_tool_use" "$CODEX_CONF" 2>/dev/null)"
  key=${key:-0}
  if [ "$key" -ge 1 ]; then
    pass "trust" "$key trusted handler entry(ies) for $abs"
  else
    gap "trust" "handlers not trusted yet — open codex once in this repo and approve them, or pass --dangerously-bypass-hook-trust in automation"
  fi
}

if [ "$MODE" = install ]; then
  if ! mkdir -p "$DOT" 2>/dev/null; then
    gap "codex-config" "cannot create $DOT"
    verdict
  fi

  if [ -f "$CONF" ]; then
    pass "codex-config" "$CONF present, left untouched"
  elif printf '# Project config layer. Codex reads %s next to it.\n' "$HOOKS" > "$CONF" 2>/dev/null; then
    pass "codex-config" "$CONF created (the project layer must exist for Codex to read the hooks file)"
  else
    gap "codex-config" "cannot write $CONF"
    verdict
  fi

  new="$(merged 2>/dev/null)"
  if [ -z "$new" ]; then
    gap "hooks-file" "$HOOKS exists but is not valid JSON; left untouched"
    report_trust
    verdict
  fi

  if [ -f "$HOOKS" ] && [ "$(cat "$HOOKS" 2>/dev/null)" = "$new" ]; then
    pass "hooks-file" "$HOOKS already current, not rewritten"
  elif printf '%s\n' "$new" > "$HOOKS" 2>/dev/null; then
    pass "hooks-file" "$HOOKS written"
  else
    gap "hooks-file" "cannot write $HOOKS"
    verdict
  fi
else
  if [ -f "$CONF" ]; then
    pass "codex-config" "$CONF present"
  else
    gap "codex-config" "$CONF missing; Codex needs the project layer to read the hooks file"
  fi
  if [ ! -f "$HOOKS" ]; then
    gap "hooks-file" "$HOOKS missing; run this script with no arguments to install"
  elif jq -e . "$HOOKS" >/dev/null 2>&1; then
    pass "hooks-file" "$HOOKS present and valid JSON"
  else
    gap "hooks-file" "$HOOKS is not valid JSON"
  fi
fi

report_gates
report_trust
verdict
