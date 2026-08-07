---
name: update-constitution
description: "Amend the repo's CONSTITUTION.md. Semver versioning (PATCH / MINOR / MAJOR), Sync Impact Report, updates Last Amended. Reads existing file at repo root, proposes surgical edits, applies after user approval."
allowed-tools: Bash(git config *) Bash(git rev-parse *) Bash(date *) Bash(test *) Bash(cat *) Read Write Edit AskUserQuestion
---

# Update Constitution

Surgical amendment to an existing `CONSTITUTION.md`. Versioned by semver. Generates a Sync Impact Report. Updates `Last Amended` automatically.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Pipeline Position

Standalone meta skill. Run when a principle needs revision, addition, or removal — often after an `/samuel:implement` constitution conflict showed the principle should be amended rather than worked around.

## Critical Rules

1. **Surgical edits, not rewrites.** Preserve untouched principles verbatim.
2. **Semver discipline.** MAJOR = backward-incompatible (principle removed, MUST clause inverted, scope radically shifted). MINOR = principle added or guidance materially expanded. PATCH = clarification/typo with no rule change.
3. **Sync Impact Report is mandatory.** Update the HTML comment at the top: version change, modified/added/removed principles, skills flagged for review.
4. **Last Amended updated** to today's ISO date, every amendment.
5. **Ratified date NEVER changes.**
6. **Imperative + rationale preserved.**

## Context

- Date: !`date '+%Y-%m-%d'`
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Git user: !`git config user.name 2>/dev/null || echo "unknown"`
- Constitution present: !`test -f CONSTITUTION.md && echo "yes" || echo "no — use /samuel:create-constitution first"`

## Pre-checks

If `Constitution present: no`, abort: "Run /samuel:create-constitution first to ratify v1.0.0."
If `Repo root: NO_REPO_ROOT`, abort: not a git repo.

## Phase 1: LOAD

Read the current `CONSTITUTION.md`. Parse current version, Ratified date, Last Amended date, the list of principles (Roman numeral + Name + Imperative + Rationale), optional sections, and Governance. Capture in memory; do NOT modify yet.

## Phase 2: GATHER AMENDMENT

```
Current state:
- Version: {X.Y.Z}
- Principles: I. {Name 1} · II. {Name 2} · ...

What do you want to amend?
1. Add a new principle    4. Rename a principle (no scope change)
2. Modify an existing one  5. Update Architecture / Quality Gates
3. Remove a principle      6. Fix typos / wording (no semantic change)
```

WAIT, then collect the specifics (with before/after for modifications, brief reason for removals).

## Phase 3: SEMVER DECISION

| Amendment type | Bump |
|---|---|
| Principle added | MINOR |
| Principle removed | MAJOR |
| MUST clause inverted | MAJOR |
| MUST/SHOULD level changed | MINOR if relaxed, MAJOR if tightened |
| Scope materially expanded | MINOR |
| Scope materially reduced | MAJOR |
| Rationale clarification only | PATCH |
| Rename (no scope change) | PATCH |
| Typo / wording polish | PATCH |

If ambiguous, propose the bump + reasoning and ask for confirmation. Compute the new version (1.0.0 + PATCH → 1.0.1; +MINOR → 1.1.0; +MAJOR → 2.0.0).

## Phase 4: DRAFT SYNC IMPACT REPORT

Build the HTML comment replacing the existing one:

```html
<!--
Sync Impact Report
Version change: {old} -> {new}
Modified principles: {entries}
Added principles: {entries}
Removed principles: {entries + brief reason}
Modified sections: {Architecture/Quality Gates if updated}
Skills requiring review:
- ⚠ pending: plugins/samuel/skills/plan/SKILL.md (Constitution Check)
- ⚠ pending: plugins/samuel/skills/analyze/SKILL.md (detection pass)
- ⚠ pending: plugins/samuel/skills/implement/SKILL.md (per-phase pre-check)
- ⚠ pending: plugins/samuel/skills/validate/SKILL.md (final scan)
Follow-up TODOs: {item, if any}
-->
```

Be conservative — list ALL skills referencing the constitution. The update does NOT propagate automatically.

## Phase 5: PROPOSE — CHECKPOINT

Present the full diff (version, bump type, Sync Impact Report, per-change before/after). `Apply? (Y / N / Edit)`. WAIT for approval.

## Phase 6: APPLY

Update `CONSTITUTION.md` via Edit (Write only if the rewrite is large): replace the HTML comment, bump `**Version**`, set `**Last Amended**` to today, do NOT touch `**Ratified**`, apply each amendment surgically, preserve everything else verbatim.

## Phase 7: PRESENT

```
CONSTITUTION.md amended to v{new}

Changes: {bullets}
Sync Impact Report recorded at the top.
Pending propagation (⚠): {skill paths to review}

Next:
1. git add CONSTITUTION.md && git commit -m "docs: amend constitution to v{new} ({bump} — {summary})"
2. If MAJOR: in-flight features may need /samuel:refine-plan.
3. If MINOR: the next /samuel:plan or /samuel:analyze picks up the new rule automatically.
```

## Gotchas

_Add a line each time Claude trips on something._

- Ratified date NEVER changes after creation. Only Last Amended moves.
- MAJOR bumps are real breaking changes — don't downgrade to MINOR to feel safer.
- PATCH is only for typos/wording with NO semantic shift.
- Don't auto-update referenced skills — the user runs those separately. This skill edits ONLY CONSTITUTION.md.
- The constitution version is independent from the repo/plugin/feature versions.
