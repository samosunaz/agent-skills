#!/usr/bin/env bash
# review-md.sh — samuel:create-review-md deterministic layer.
# Adapted for solo use: no org base, .claude/samuel.md config, and the
# review history a solo repo actually has — committed validation.md verdicts, journal
# deviations/questions, and self-audit PR comments.
# Two modes:
#   --evidence : gather a compact evidence digest (repo type, gate signals, CI job
#                names, feature-artifact findings, PR review-comment digest) for
#                Claude's semantic derivation pass (SKILL.md DERIVE step). Never
#                writes REVIEW.md — classification is exclusively the semantic layer's job.
#   --check    : validate the root REVIEW.md against schema v1 (template/REVIEW.md).
#                [PASS|GAP] per check, always exits 0 (report-only, like repo-audit).
#
# Usage: review-md.sh --evidence [--allow-branch-drift] | --check
set -euo pipefail

MODE=""
ALLOW_DRIFT=0
for arg in "$@"; do
  case "$arg" in
    --evidence) MODE="evidence" ;;
    --check) MODE="check" ;;
    --allow-branch-drift) ALLOW_DRIFT=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
if [ -z "$MODE" ]; then
  echo "Usage: review-md.sh --evidence [--allow-branch-drift] | --check" >&2
  exit 2
fi

REPO_ROOT="$(pwd)"
REVIEW_MD="$REPO_ROOT/REVIEW.md"
GAP_COUNT=0

pass() { printf '[PASS] %s — %s\n' "$1" "$2"; }
gap()  { printf '[GAP]  %s — %s\n' "$1" "$2"; GAP_COUNT=$((GAP_COUNT + 1)); }

# repo comes from .claude/samuel.md, never from git remote (SSH-alias origins break
# owner/repo parsing — reference/tracker.md).
REPO="$(awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;exit}' "$REPO_ROOT/.claude/samuel.md" 2>/dev/null || true)"
[ "${REPO:-}" = "owner/name" ] && REPO=""

# ============================================================
# --evidence: read-only digest, never writes REVIEW.md.
# ============================================================

detect_repo_type() {
  # composer.json is probed BEFORE package.json: Laravel repos ship a package.json
  # for Vite/husky/commitlint, so a package.json-first chain misclassifies every PHP
  # repo as Node. Same logic puts React Native/Expo before generic Node — the mobile
  # app ships a package.json too.
  local js_note=""
  if [ -f "$REPO_ROOT/package.json" ]; then
    js_note=" + package.json (JS tooling/assets)"
  fi
  if [ -f "$REPO_ROOT/nx.json" ]; then
    echo "Nx monorepo (nx.json + package.json)"
  elif [ -f "$REPO_ROOT/composer.json" ] && [ -f "$REPO_ROOT/artisan" ]; then
    echo "PHP/Laravel repo (composer.json + artisan)$js_note"
  elif [ -f "$REPO_ROOT/composer.json" ]; then
    echo "PHP repo (composer.json)$js_note"
  elif [ -f "$REPO_ROOT/package.json" ] && grep -q '"react-native"' "$REPO_ROOT/package.json" 2>/dev/null; then
    echo "React Native/Expo app (package.json with react-native)"
  elif [ -f "$REPO_ROOT/package.json" ]; then
    echo "Node/JS repo (package.json)"
  else
    echo "unknown (no package.json/composer.json/nx.json found)"
  fi
}

gate_signals() {
  # The samuel pipeline has no repo-level verify key — the gate command lives in each
  # plan's Validation → Automated section. The digest surfaces candidates; DERIVE
  # names the actual gate in the Repo context line.
  local found=0
  if [ -f "$REPO_ROOT/package.json" ]; then
    found=1
    echo "package.json scripts:"
    awk '/"scripts"[[:space:]]*:/{f=1;next} f&&/^[[:space:]]*}/{f=0} f' "$REPO_ROOT/package.json"
  fi
  if [ -f "$REPO_ROOT/composer.json" ]; then
    found=1
    echo "composer.json scripts:"
    awk '/"scripts"[[:space:]]*:/{f=1;next} f&&/^[[:space:]]*}/{f=0} f' "$REPO_ROOT/composer.json"
  fi
  [ "$found" = "1" ] || echo "[none] no package.json/composer.json — gate lives in each plan's Validation section"
}

ci_job_names() {
  local wf_dir="$REPO_ROOT/.github/workflows" f wf_name jobs found=0
  if [ ! -d "$wf_dir" ]; then
    echo "[none] no .github/workflows/"
    return
  fi
  for f in "$wf_dir"/*.yml "$wf_dir"/*.yaml; do
    [ -f "$f" ] || continue
    found=1
    wf_name="$(awk -F': ' '/^name:/{print $2; exit}' "$f")"
    jobs="$(awk '
      /^jobs:/ { in_jobs=1; next }
      in_jobs && /^[^ ]/ { in_jobs=0 }
      in_jobs && /^  [A-Za-z0-9_-]+:/ { line=$0; sub(/^  /,"",line); sub(/:.*/,"",line); print line }
    ' "$f" | tr '\n' ',' | sed 's/,$//')"
    printf '%s (%s): %s\n' "$(basename "$f")" "${wf_name:-unnamed}" "${jobs:-no jobs found}"
  done
  [ "$found" = "1" ] || echo "[none] no .yml/.yaml workflow files"
}

feature_artifacts() {
  # The solo repo's richest review history is committed, not on GitHub: validation.md
  # carries the independent reviewer's verdict + Blocker/Important findings, the
  # journal carries deviations (V-) and open questions (Q-). Recurrence across
  # features is the signal DERIVE looks for.
  local f any=0
  for f in "$REPO_ROOT"/docs/features/*/validation.md; do
    [ -f "$f" ] || continue
    any=1
    printf '### %s\n' "${f#"$REPO_ROOT"/}"
    grep -E '^### Overall|^- \*\*Verdict\*\*|^- \[(🔴|🟡)' "$f" 2>/dev/null || echo "(no Overall/Verdict/finding lines)"
    echo
  done
  for f in "$REPO_ROOT"/docs/features/*/implementation-notes.md; do
    [ -f "$f" ] || continue
    any=1
    printf '### %s\n' "${f#"$REPO_ROOT"/}"
    grep -E '^### (V|Q)-[0-9]+' "$f" 2>/dev/null || echo "(no V-/Q- entries)"
    echo
  done
  [ "$any" = "1" ] || echo "[none] no docs/features/*/ validation or journal files"
}

review_history() {
  if [ -z "$REPO" ]; then
    echo "[none] no repo resolved (.claude/samuel.md repo: missing)"
    return
  fi
  local prs
  prs="$(gh pr list -R "$REPO" --state merged --limit 15 --json number,title -q '.[] | "\(.number)\t\(.title)"' 2>/dev/null || echo "")"
  if [ -z "$prs" ]; then
    echo "[none] no merged PRs found"
    return
  fi
  local any=0
  while IFS=$'\t' read -r n title; do
    [ -z "$n" ] && continue
    local reviews
    # Cap each review body to its first 3 lines *inside* the jq projection
    # (join(" / ") keeps it one line per review) — capping after the fact with
    # `head -3` per already-single line is a no-op, it doesn't limit anything.
    reviews="$(gh api "repos/$REPO/pulls/$n/reviews" --jq '.[] | select(.body != "" and (.user.login | endswith("[bot]") | not)) | "\(.user.login): \(.body | split("\n")[0:3] | join(" / "))"' 2>/dev/null || echo "")"
    [ -z "$reviews" ] && continue
    any=1
    printf '### PR #%s — %s\n' "$n" "$title"
    printf '%s\n' "$reviews"
    echo
  done <<< "$prs"
  [ "$any" = "1" ] || echo "[none] no review comments on the last 15 merged PRs"
}

# The digest mixes WORKING-TREE evidence (repo type, gate signals, CI job names,
# feature artifacts) with REMOTE evidence (PR review history). On a stale branch the
# two describe different repos and DERIVE writes a REVIEW.md for one that no longer
# exists. Guards `--evidence` only: `--check` reads a file already in the tree, so
# drift cannot mislead it.
check_branch_drift() {
  local default behind
  if [ -z "$REPO" ]; then
    echo "[warn] branch-drift guard skipped — no repo resolved" >&2
    return 0
  fi
  default="$(gh repo view "$REPO" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null)" || default=""
  if [ -z "$default" ]; then
    echo "[warn] branch-drift guard skipped — could not resolve the default branch" >&2
    return 0
  fi
  # Opportunistically refreshes refs/remotes/origin/$default; a stale local ref would
  # make the ancestry test pass for the wrong reason. Best-effort: offline still works,
  # it just compares against whatever was last fetched.
  git fetch origin "$default" --quiet 2>/dev/null || true
  if ! git rev-parse --verify --quiet "origin/$default" >/dev/null 2>&1; then
    echo "[warn] branch-drift guard skipped — origin/$default not available locally" >&2
    return 0
  fi
  # Ancestry, not branch-name equality: generating from a fresh branch cut off the
  # default is the happy path, and must not abort.
  if git merge-base --is-ancestor "origin/$default" HEAD 2>/dev/null; then
    return 0
  fi
  behind="$(git rev-list --count "HEAD..origin/$default" 2>/dev/null || echo "?")"
  if [ "$ALLOW_DRIFT" = "1" ]; then
    printf '> **[branch drift]** HEAD is %s commit(s) behind `origin/%s`. Working-tree evidence\n' "$behind" "$default"
    printf '> below (repo type, gate signals, CI jobs, feature artifacts) may not describe the repo reviews run against.\n\n'
    return 0
  fi
  cat >&2 <<EOF
[abort] branch drift: HEAD is $behind commit(s) behind origin/$default.

  --evidence reads repo type, gate signals, CI job names and feature artifacts from the
  WORKING TREE, but review history from GitHub. On a stale branch those describe
  different repos, and DERIVE would write a REVIEW.md for one that no longer exists.

  Fix: rebase onto origin/$default, or generate from a worktree cut from it:
    git worktree add ../<repo>--review-md -b chore/review-md origin/$default

  Override (you accept a possibly-wrong digest): --allow-branch-drift
EOF
  exit 3
}

run_evidence() {
  check_branch_drift
  echo "## Repo type"
  detect_repo_type
  echo
  echo "## Gate signals (per-plan gate — candidates only)"
  gate_signals
  echo
  echo "## CI job names"
  ci_job_names
  echo
  echo "## Feature artifacts (validation.md verdicts + journal V-/Q- entries)"
  feature_artifacts
  echo
  echo "## Review history (last 15 merged PRs, review comments)"
  review_history
}

# ============================================================
# --check: schema v1 conformance of the root REVIEW.md. Report-only, exit 0.
# ============================================================

check_review_presence() {
  local check="review-md:presence"
  if [ -f "$REVIEW_MD" ]; then
    pass "$check" "$REVIEW_MD present"
  else
    gap "$check" "$REVIEW_MD missing"
  fi
}

check_review_authority_line() {
  local check="review-md:authority-line"
  if grep -q '^\*\*Authority:\*\*' "$REVIEW_MD" 2>/dev/null; then
    pass "$check" "Authority line present"
  else
    gap "$check" "no **Authority:** line"
  fi
}

check_review_repo_context_line() {
  local check="review-md:repo-context-line"
  if grep -q '^\*\*Repo context:\*\*' "$REVIEW_MD" 2>/dev/null; then
    pass "$check" "Repo context line present"
  else
    gap "$check" "no **Repo context:** line"
  fi
}

check_review_sections() {
  local check="review-md:sections" want missing=""
  for want in "## What Blocker/Important mean here" "## Never flag" "## Always check" "## Evidence bar" "## Noise budget"; do
    grep -qxF "$want" "$REVIEW_MD" 2>/dev/null || missing="$missing|$want"
  done
  if [ -z "$missing" ]; then
    pass "$check" "all 5 H2 sections present"
  else
    gap "$check" "missing:${missing#|}"
  fi
}

check_review_body_length() {
  local check="review-md:body-length" count
  count="$(awk '
    BEGIN{seen_h1=0}
    !seen_h1 && /^# / { seen_h1=1; next }
    /<!--/ { in_comment=1 }
    in_comment { if (/-->/) in_comment=0; next }
    seen_h1 { count++ }
    END { print count+0 }
  ' "$REVIEW_MD" 2>/dev/null || echo 0)"
  if [ "$count" -le 30 ]; then
    pass "$check" "$count body lines (<=30)"
  else
    gap "$check" "$count body lines (>30, HTML comments excluded)"
  fi
}

check_review_no_placeholders() {
  local check="review-md:no-placeholders" count
  # grep -c prints "0" AND exits 1 on zero matches — the assignment already
  # captured that "0"; `|| true` just stops set -e from killing the script,
  # it must never echo a fallback value (that would double the captured count).
  count="$(grep -cE '\{[a-zA-Z][^}]*\}' "$REVIEW_MD" 2>/dev/null)" || true
  if [ "$count" = "0" ]; then
    pass "$check" "zero {placeholder} markers"
  else
    gap "$check" "$count {placeholder} marker(s) left unfilled"
  fi
}

# The Authority line names a relationship ("the reviewer's default rubric"), never a
# path: REVIEW.md is read by three reviewers, one of which (native /code-review) knows
# nothing of our plugins. Any backticked path it does name must at least resolve inside
# THIS repo — a REVIEW.md asserting a directory its own repo lacks is the defect.
# Only backticked tokens are inspected: paths are backticked by schema convention, and
# scanning bare words for a `/` would gap on ordinary prose ("and/or").
check_review_authority_paths() {
  local check="review-md:authority-paths" line tok missing=""
  line="$(grep -m1 '^\*\*Authority:\*\*' "$REVIEW_MD" 2>/dev/null)" || line=""
  if [ -z "$line" ]; then
    gap "$check" "no **Authority:** line to inspect"
    return
  fi
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    [ -e "$REPO_ROOT/$tok" ] || missing="$missing|$tok"
  done <<< "$(printf '%s\n' "$line" | grep -oE '`[^`]+`' | tr -d '`' | grep '/' || true)"
  if [ -z "$missing" ]; then
    pass "$check" "authority line names no unresolvable path"
  else
    gap "$check" "path(s) absent from this repo:${missing#|}"
  fi
}

run_check() {
  check_review_presence
  if [ ! -f "$REVIEW_MD" ]; then
    printf -- '--- %d gap(s) ---\n' "$GAP_COUNT"
    return
  fi
  check_review_authority_line
  check_review_repo_context_line
  check_review_sections
  check_review_body_length
  check_review_no_placeholders
  check_review_authority_paths
  printf -- '--- %d gap(s) ---\n' "$GAP_COUNT"
}

case "$MODE" in
  evidence) run_evidence; exit 0 ;;
  check) run_check; exit 0 ;;
esac
