#!/usr/bin/env bash
# PreToolUse gate for Grep and Bash (rg/grep/git grep): a content-mode search
# with no result bound and no scope narrower than the repo is denied with a
# message that points at files-first / scoped / bounded forms. Fails open.
#
# Env: SHUNT_DISABLE=1 (gate off) · SHUNT_LOG (denial log path) ·
# SHUNT_CLIENT (claude|codex; unset emits a message valid on either client).

[ "${SHUNT_DISABLE:-0}" = "1" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Selects the vocabulary of the denial message. An unknown value falls back to
# the neutral wording rather than to one client's tools.
client="${SHUNT_CLIENT:-}"
case "$client" in claude|codex) ;; *) client="" ;; esac

input="$(cat)" || exit 0
tool="$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null)" || exit 0
cwd="$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)"
agent="$(jq -r '.agent_type // .agent_id // .subagent_type // empty' <<<"$input" 2>/dev/null)"
case "$agent" in shunt:bulk-reader|shunt:code-writer) exit 0 ;; esac

# True when $1 is the search root or absent: the search spans the whole repo.
is_repo_wide() {
  local p="$1"
  [ -z "$p" ] && return 0
  case "$p" in .|./|"$cwd"|"$cwd/") return 0 ;; esac
  return 1
}

deny() {
  local what="$1"
  local log="${SHUNT_LOG:-$HOME/.claude/plugin-data/shunt/denials.log}"
  { mkdir -p "$(dirname "$log")" && printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%FT%T)" "$tool" "${agent:-main}" "search" "$what" >>"$log"; } 2>/dev/null || true
  local reason head tail
  head="shunt: unbounded content search across the whole repo (${what}). Every matching line would enter this context. Choose one:"
  case "$client" in
    claude)
      tail="(1) FILES FIRST → Grep output_mode=files_with_matches (rg -l), then open the few files that matter with a targeted Read. (2) SCOPE or BOUND → narrow with path/glob/type (rg -g/-t, a subdirectory), or bound with head_limit=N (rg -m N, | head -n N). (3) Deliberate override → pass head_limit explicitly (any value); an explicit bound passes this gate."
      ;;
    codex)
      tail="(1) FILES FIRST → rg -l <pattern>, then open the few files that matter with a bounded read (sed -n). (2) SCOPE or BOUND → narrow with rg -g/-t or a subdirectory path, or bound with rg -m N. (3) Deliberate override → pass an explicit bound (rg -m N, or pipe the output through head -n N); a bounded search passes this gate."
      ;;
    *)
      tail="(1) FILES FIRST → list the matching files only, then open the few that matter with a bounded read. (2) SCOPE or BOUND → narrow by path, glob, or file type, or cap the number of results. (3) Deliberate override → pass an explicit result bound; a bounded search passes this gate."
      ;;
  esac
  reason="${head} ${tail} Details: skill shunt:bulk-read § Search gate."
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case "$tool" in
  Grep)
    mode="$(jq -r '.tool_input.output_mode // "files_with_matches"' <<<"$input" 2>/dev/null)"
    [ "$mode" = "content" ] || exit 0
    bounded="$(jq -r 'if .tool_input.head_limit != null then "1" else "" end' <<<"$input" 2>/dev/null)"
    [ -n "$bounded" ] && exit 0
    scoped="$(jq -r 'if (.tool_input.glob // "") != "" or (.tool_input.type // "") != "" then "1" else "" end' <<<"$input" 2>/dev/null)"
    [ -n "$scoped" ] && exit 0
    path="$(jq -r '.tool_input.path // empty' <<<"$input" 2>/dev/null)"
    is_repo_wide "$path" || exit 0
    pattern="$(jq -r '.tool_input.pattern // empty' <<<"$input" 2>/dev/null)"
    deny "Grep content mode, pattern '${pattern}'"
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)"
    [ -n "$cmd" ] || exit 0
    # Pipes, redirects, and chains mean the output is filtered or bounded downstream.
    case "$cmd" in *'|'*|*'>'*|*'&&'*|*';'*|*'`'*|*'$('*) exit 0 ;; esac
    read -r -a words <<<"$cmd"
    case "${words[0]}" in
      rg|grep) argv=("${words[@]:1}") ;;
      git) [ "${words[1]:-}" = "grep" ] || exit 0; argv=("${words[@]:2}"); words[0]="git grep" ;;
      *) exit 0 ;;
    esac
    positional=()
    skip=0
    for w in "${argv[@]}"; do
      if [ "$skip" = 1 ]; then skip=0; continue; fi
      case "$w" in
        -l|--files-with-matches|-c|--count|-q|--quiet|--files|-L|--files-without-match) exit 0 ;;
        -m|--max-count|-m*|--max-count=*) exit 0 ;;
        -g|--glob|-t|--type|--iglob|--include|-e|--regexp) skip=1; [ "$w" = -e ] || [ "$w" = --regexp ] || exit 0 ;;
        -g*|-t*|--glob=*|--type=*|--include=*) exit 0 ;;
        -A|-B|-C|--after-context|--before-context|--context|-M|--max-columns) skip=1 ;;
        --) ;;
        --*) ;;
        -*) case "$w" in *l*|*c*|*q*|*m*) exit 0 ;; esac ;;   # bundled short flags: -rln, -rc, -rm5
        *) positional+=("$w") ;;
      esac
    done
    # positional = pattern [paths...]; a path narrower than the root is a scope.
    [ "${#positional[@]}" -ge 1 ] || exit 0
    if [ "${#positional[@]}" -ge 2 ]; then
      for p in "${positional[@]:1}"; do
        p="${p%\"}"; p="${p#\"}"; p="${p%\'}"; p="${p#\'}"
        is_repo_wide "$p" || exit 0
      done
    fi
    deny "${words[0]} content mode, pattern ${positional[0]}"
    ;;
esac
exit 0
