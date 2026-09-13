#!/usr/bin/env bash
# PreToolUse gate for Read and Bash: a whole-file read of a large text file is
# denied with a message that points the model at the delegation path
# (shunt:bulk-read). Fails open: any error, missing jq, or unknown shape allows.
#
# Env: SHUNT_MIN_LINES (default 350) · SHUNT_DISABLE=1 (gate off) · SHUNT_LOG
# (denial log path) · SHUNT_DEBUG (append every hook input to this file).

[ "${SHUNT_DISABLE:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

threshold="${SHUNT_MIN_LINES:-350}"
case "$threshold" in ''|*[!0-9]*) threshold=350 ;; esac
[ "$threshold" -eq 0 ] && exit 0

input="$(cat)" || exit 0
tool="$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null)" || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
agent="$(jq -r '.agent_type // .agent_id // .subagent_type // empty' <<<"$input" 2>/dev/null)"
[ -n "${SHUNT_DEBUG:-}" ] && printf '%s\n' "$input" >>"$SHUNT_DEBUG" 2>/dev/null
# The workers read whole files by design; gating them would be circular.
case "$agent" in shunt:bulk-reader|shunt:code-writer) exit 0 ;; esac

# Prints the line count when $1 is a large text file, nothing otherwise.
large_lines() {
  local f="$1"
  [ -n "$f" ] || return 0
  [[ "$f" = /* ]] || f="${cwd:-.}/$f"
  [ -f "$f" ] || return 0
  grep -qI '' "$f" 2>/dev/null || return 0        # binary → not ours
  local n
  n="$(wc -l <"$f" 2>/dev/null | tr -d ' ')" || return 0
  [ "${n:-0}" -gt "$threshold" ] && printf '%s' "$n"
  return 0
}

deny() {
  local file="$1" lines="$2"
  # The denial log is the measurement (ADR 0007); it never blocks the gate.
  local log="${SHUNT_LOG:-$HOME/.claude/plugin-data/shunt/denials.log}"
  { mkdir -p "$(dirname "$log")" && printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%FT%T)" "$tool" "${agent:-main}" "$lines" "$file" >>"$log"; } 2>/dev/null || true
  local reason
  reason="shunt: ${file} has ${lines} lines (limit ${threshold}). A whole-file read of a large file does not enter this context. Choose one: (1) You need an ANSWER about the file → delegate the read: Agent shunt:bulk-reader, prompt 'Read ${file} and answer: <your question>. Output structured bullets only, cite file:line.' (2) You need to EDIT a region → Read the file with offset/limit around the target lines, or Grep for the symbol first; targeted reads pass this gate. (3) The whole file is genuinely required (a diff you must review, a config you must reproduce verbatim) → Read with offset=1 and limit=${lines}; that is the explicit, deliberate override. Details: skill shunt:bulk-read."
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Read)
    has_range="$(jq -r 'if (.tool_input.offset != null) or (.tool_input.limit != null) then "1" else "" end' <<<"$input" 2>/dev/null)"
    [ -n "$has_range" ] && exit 0
    file="$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)"
    n="$(large_lines "$file")"
    [ -n "$n" ] && deny "$file" "$n"
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)"
    [ -n "$cmd" ] || exit 0
    # Only a bare pager/cat on files is a whole-file read. Pipes, redirects,
    # chains, and range readers (sed -n, head/tail -n) are targeted or filtered.
    case "$cmd" in *'|'*|*'>'*|*'&&'*|*';'*|*'`'*|*'$('*) exit 0 ;; esac
    read -r -a words <<<"$cmd"
    case "${words[0]}" in cat|less|more|bat) ;; *) exit 0 ;; esac
    for w in "${words[@]:1}"; do
      case "$w" in -*) continue ;; esac
      w="${w%\"}"; w="${w#\"}"; w="${w%\'}"; w="${w#\'}"
      n="$(large_lines "$w")"
      [ -n "$n" ] && deny "$w" "$n"
    done
    ;;
esac
exit 0
