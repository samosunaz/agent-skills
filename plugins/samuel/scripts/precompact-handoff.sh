#!/bin/sh
# PreCompact hook: injects handoff rules into the compaction summary so the resumed
# session gets a self-contained handoff, plus the active branch and the item's
# task-context frontmatter when one exists. /samuel:session-handoff stays the
# deliberate checkpoint; this only raises the floor of every compaction.
# Fails open: a missing piece (git, task-context) drops that piece, never the rules.
# Output is plain stdout: Claude Code appends it to the compaction instructions. PreCompact
# has no hookSpecificOutput variant, and a JSON one fails validation (2.1.289).

cat > /dev/null 2>&1

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$ROOT" ] && cd "$ROOT" 2>/dev/null

BRANCH=$(git branch --show-current 2>/dev/null)

# Same order as the canonical resolver (reference/task-context.md § Reading):
# branch number, else the only file in the directory, else the legacy single file.
FILE=""
NUM=$(printf '%s' "$BRANCH" | sed -n 's/^[^0-9]*\([0-9][0-9]*\).*/\1/p')
if [ -n "$NUM" ] && [ -f ".claude/task-context/$NUM.md" ]; then
  FILE=".claude/task-context/$NUM.md"
elif [ -d .claude/task-context ]; then
  set -- .claude/task-context/*.md
  [ "$#" -eq 1 ] && [ -f "$1" ] && FILE="$1"
fi
[ -z "$FILE" ] && [ -f .claude/task-context.md ] && FILE=".claude/task-context.md"

CTX=""
if [ -n "$FILE" ]; then
  CTX=$(awk 'NR==1 && $0!="---"{exit} {print} NR>1 && $0=="---"{exit}' "$FILE" 2>/dev/null)
fi

cat <<'EOF'
COMPACTION HANDOFF RULES (from /samuel:session-handoff / Frequent Intentional Compaction).
The post-compaction session resumes with ZERO context beyond your summary — write it as a
self-contained handoff, not a recap. Structure it with these sections and rules:

1. Task & Progress — what the user asked for; what is DONE (with file:line evidence); what
   REMAINS as concrete, ordered next steps; the exact step in flight when compaction hit.
2. Key learnings — decisions made and why, constraints and gotchas discovered, approaches
   tried and rejected (so they are not retried).
3. Exact references — keep verbatim: file paths with line numbers, branch names, Issue/PR
   numbers, IDs, URLs, commands already run and their relevant outcomes. Never paraphrase
   an identifier.
4. Work in flight — uncommitted changes, background tasks/agents still running, pending
   verifications or user approvals.
5. Resume protocol — the first actions for the resumed session, plus the sources of truth
   to reconcile against (git status/log, the GitHub Issue, the tracker) instead of trusting
   this summary blindly.

Style: terse bullets over prose; reference code by path:line, never inline large code
blocks; state blockers and open questions explicitly.
EOF
[ -n "$BRANCH" ] && printf '\nActive git branch: %s\n' "$BRANCH"
[ -n "$CTX" ] && printf '\nActive task-context frontmatter, %s (preserve verbatim in the summary):\n%s\n' "$FILE" "$CTX"
exit 0
