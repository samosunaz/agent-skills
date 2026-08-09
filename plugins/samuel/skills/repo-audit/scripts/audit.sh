#!/usr/bin/env bash
# Substrate drift detector for samuel consumer repos.
# Deterministic layer only — report, never mutate. Run from the
# target repo's root. Exit 0 always (report-only); the verdict line carries the result.
set -uo pipefail

GAP_COUNT=0
OPT_COUNT=0

pass() { printf '[PASS] %s — %s\n' "$1" "$2"; }
gap()  { printf '[GAP]  %s — %s\n' "$1" "$2"; GAP_COUNT=$((GAP_COUNT + 1)); }
opt()  { printf '[OPT]  %s — %s\n' "$1" "$2"; OPT_COUNT=$((OPT_COUNT + 1)); }

# --- samuel.md + repo ---------------------------------------------------------
REPO=""
if [ -f .claude/samuel.md ]; then
  REPO=$(awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;exit}' .claude/samuel.md)
  TRACKER=$(awk '/^tracker:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;exit}' .claude/samuel.md)
  if [ -n "$REPO" ] && [ "$REPO" != "owner/name" ]; then
    pass "samuel-md" ".claude/samuel.md with repo: $REPO"
  else
    gap "samuel-md" ".claude/samuel.md present but repo: is missing/placeholder"
  fi
  if [ -n "${TRACKER:-}" ] && [ "$TRACKER" != "github" ]; then
    gap "tracker-legacy" "tracker: $TRACKER — pre-migration context (ADR 0002); must be github"
  fi
else
  gap "samuel-md" "no .claude/samuel.md (repo config) — skills will ask every run"
fi

# --- gh ------------------------------------------------------------------------
if gh auth status >/dev/null 2>&1; then
  pass "gh-auth" "$(gh api user --jq .login 2>/dev/null || echo 'authenticated')"
else
  gap "gh-auth" "gh unauthenticated — the pipeline cannot reach its SoT"
fi

if [ -n "$REPO" ] && gh repo view "$REPO" --json name >/dev/null 2>&1; then
  pass "gh-repo" "$REPO reachable"
elif [ -n "$REPO" ]; then
  gap "gh-repo" "gh repo view $REPO failed — access or name problem"
fi

# --- labels ---------------------------------------------------------------------
if [ -n "$REPO" ]; then
  MISSING=""
  EXISTING=$(gh label list -R "$REPO" --limit 200 --json name --jq '.[].name' 2>/dev/null)
  for L in pipeline:triage pipeline:planned pipeline:ready pipeline:in-progress pipeline:in-review roadmap:now roadmap:next roadmap:later promo:blog promo:bip; do
    printf '%s\n' "$EXISTING" | grep -qx "$L" || MISSING="$MISSING $L"
  done
  if [ -z "$MISSING" ]; then
    pass "labels" "pipeline:* + roadmap:* + promo:* complete"
  else
    gap "labels" "missing:$MISSING (idempotent fix: gh label create --force)"
  fi
fi

# --- local hygiene ---------------------------------------------------------------
if [ -f .gitignore ] && grep -q '^\.claude' .gitignore 2>/dev/null; then
  pass "claude-gitignored" ".claude/ ignored (task-context/samuel.md never committed)"
else
  gap "claude-gitignored" ".claude/ not in .gitignore — local pipeline state could land in a commit"
fi

if [ -f CLAUDE.md ]; then
  pass "claude-md" "present ($(wc -l < CLAUDE.md | tr -d ' ') lines)"
else
  gap "claude-md" "no CLAUDE.md — agents work here blind"
fi

# --- optional substrate (present-or-absent, never counts toward the verdict) ------
[ -f CONSTITUTION.md ] && opt "constitution" "present" || opt "constitution" "absent (pipeline degrades gracefully)"
[ -f REVIEW.md ] && opt "review-md" "present" || opt "review-md" "absent (reviewers run on the default rubric)"
[ -f .github/workflows/conductor.yml ] && opt "conductor-ci" "heartbeat workflow present" || opt "conductor-ci" "no conductor.yml (manual runs only)"
if [ -f .github/PULL_REQUEST_TEMPLATE.md ] && ls .github/ISSUE_TEMPLATE/*.md >/dev/null 2>&1; then
  opt "tldr-templates" "issue + PR templates present (TL;DR pre-filled for hand-opened items)"
else
  opt "tldr-templates" "missing — items opened in the GitHub UI skip the TL;DR block"
fi
# Cross-session messaging is a machine property, not a repo one — but waves and the
# conductor's escalation channel silently degrade below 2.1.224, so the audit reports it.
CCVER=$(claude --version 2>/dev/null | awk '{print $1}')
if [ -z "${CCVER:-}" ]; then
  opt "cross-session" "claude CLI not on PATH — peer messaging unverifiable"
elif printf '2.1.224\n%s\n' "$CCVER" | sort -V | head -1 | grep -qx '2.1.224'; then
  opt "cross-session" "claude $CCVER — peer messaging available (needs >= 2.1.224)"
else
  opt "cross-session" "claude $CCVER < 2.1.224 — waves/conductor peer messaging unavailable; upgrade"
fi
if ls release-please-config.json >/dev/null 2>&1 || ls .github/workflows/release-please*.yml >/dev/null 2>&1; then
  opt "release-please" "configured"
else
  opt "release-please" "not configured"
fi
if [ -n "$REPO" ]; then
  SQUASH=$(gh api "repos/$REPO" --jq '.allow_squash_merge' 2>/dev/null)
  [ "$SQUASH" = "true" ] && opt "merge-squash" "squash merge enabled" || opt "merge-squash" "squash merge not confirmed"
fi

# --- verdict ----------------------------------------------------------------------
echo
if [ "$GAP_COUNT" -eq 0 ]; then
  echo "AUDIT: PASS — 0 gaps · $OPT_COUNT optional"
else
  echo "AUDIT: FAIL — $GAP_COUNT gap(s) · $OPT_COUNT optional"
fi
exit 0
