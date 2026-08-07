---
name: repo-audit
description: "Substrate drift detector for samuel consumer repos: deterministic checks (samuel.md, gh auth/repo, pipeline+roadmap+promo labels, .claude gitignored, CLAUDE.md; optional: constitution, REVIEW.md, conductor heartbeat, release-please, squash merge, TL;DR templates) + a semantic pass over CLAUDE.md. Report-only. Trigger on 'repo audit', 'audit repo', 'auditar repo', 'drift check'."
allowed-tools: Bash(bash *) Bash(gh api *) Bash(gh issue *) Bash(gh repo *) Bash(gh auth *) Bash(gh label *) Bash(git *) Bash(awk *) Bash(test *) Bash(date *) Read AskUserQuestion
---

# Repo Audit

The substrate drift detector for the repos the samuel pipeline runs in — read-only by construction. Two layers: a deterministic checklist and a semantic pass over CLAUDE.md. **Report-only**: the verdict never gates anything.

> Script: `scripts/audit.sh` (run from the target repo's root). No `--apply` — every fix is a normal change (label creation, a `.gitignore` line, a PR), never an auto-mutation.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Repo (samuel.md): !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_SAMUEL_MD"`
- CLAUDE.md present: !`test -f CLAUDE.md && echo "yes" || echo "no"`
- CONSTITUTION.md present: !`test -f CONSTITUTION.md && echo "yes" || echo "no"`
- REVIEW.md present: !`test -f REVIEW.md && echo "yes" || echo "no"`
- gh identity: !`gh api user --jq .login 2>/dev/null || echo "NO_AUTH"`

## Process

### 1) CHECK

Run `bash "${CLAUDE_PLUGIN_ROOT}/skills/repo-audit/scripts/audit.sh"` from the target repo's root. Present the full `[PASS|GAP|OPT] {check} — {evidence}` table verbatim, plus the closing `AUDIT: PASS|FAIL — N gap(s) · M optional` line. This is the whole deterministic layer, zero model judgment.

### 2) SEMANTIC PASS

Read CLAUDE.md end-to-end (and CONSTITUTION.md, when present) and answer three questions:

1. **Does CLAUDE.md reflect reality?** Spot-check its claims (commands, structure, conventions) against the actual tree. Cite `file:line` for anything stale or wrong.
2. **MUST sampling** — only when CONSTITUTION.md exists: pick ≤3 MUST principles and check them against recent practice (skim recent commits/PRs for a live violation). Skip entirely when there's no constitution — never invent MUSTs.
3. **Are the documented boundaries sufficient for autonomous runs?** The gate command, worktree/CI isolation, anything an unattended conductor run could touch unsafely. Flag gaps explicitly.

Every finding needs `file:line` evidence + a one-line suggested fix. A GAP the deterministic layer reports that is actually intentional (documented somewhere) is judged here — say which it is and why, never silently wave it through or re-flag it.

### 3) REPORT

```
AUDIT REPORT — {repo}
Deterministic: {PASS|FAIL} — {n} gap(s) · {m} optional
Semantic: {n} finding(s)

{the full check table from Step 1}

Semantic findings:
- {finding} — {file:line} — {suggested fix}
```

Report-only — this never blocks anything on its own.

**WAIT for confirmation before filing anything.**

### 4) ISSUES (opt-in)

Ask: "File `pipeline:triage` Issues for the N gap(s)/finding(s) above?" On yes, per finding, list-first and idempotent:

```bash
gh issue list -R {repo} --search "\"[substrate] {check-id}\" in:title" --state all --json number,title
```

Matched (normalized title match) → skip, report `"{title} already exists as {number}, skipping"`. Unmatched → create: title `[substrate] {check-id}` (deterministic) or `[substrate] semantic: {short-title}` (semantic), labels `type:chore,priority:low,pipeline:triage`, TL;DR + Brief + AC from the finding's evidence (adapter § TL;DR — `Ojo:` carries what the gap actually costs if left, which is the whole reason a substrate issue is worth opening). On "no", the report stands as the only output — nothing is filed.

## Autonomy

Under `/samuel:conductor` (or headless): render Steps 1–3 and proceed without the Step 3 WAIT — the report is the checkpoint output. Step 4 always needs the explicit opt-in regardless of mode — it's the only write surface.

## Gotchas

_Add a line each time Claude trips on something._

- **Report-only** — `AUDIT: FAIL` gates nothing. A conductor/CI gate is a possible v2, after dogfood.
- **`[OPT]` never counts toward the verdict** — informational, present-or-absent, not pass/fail.
- **No `Write`/`Edit` in `allowed-tools`** — this skill never mutates the tree; fixes are normal changes.
- The script must run from the **target repo's root** (it reads `.claude/samuel.md` and `.gitignore` relative to CWD), not from the plugin dir.
- `gh api` leaks the raw error body to stdout on non-2xx even with `2>/dev/null` — the script tests exit status, never string emptiness.
