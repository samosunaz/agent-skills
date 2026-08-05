# Validation Report: #12 — feat: automatic trigger (heartbeat) for the autonomous pipeline loop

**Date**: 2026-06-16   ·   **Tracker**: github   ·   **Item**: 12   ·   **Branch**: feat/12-auto-trigger

## Overall: PASS

> Gate green · independent reviewer APPROVE (1 Nit, now resolved) · no Blocker, no Important.

## Gate

This is a content/plugin repo — no `bun run gate`. The objective gate for this change is `actionlint` on the workflow template + a YAML-parse + a link-resolution sweep:

- **PASS** `actionlint plugins/samuel/skills/workflow/conductor/assets/conductor.yml` → exit 0 (clean, re-run after the post-review fix).
- **PASS** `python3 yaml.safe_load(conductor.yml)` → YAML OK.
- **PASS** link-resolution across all new cross-references (automated-trigger.md, conductor.yml, the SKILL/CLAUDE/pipeline edits) → all resolve.

## Independent Review (Step 2.5)

- **Verdict**: APPROVE   ·   🔴 0   ·   🟡 0   ·   🔵 1 (resolved)
- The reviewer (independent `opus`, fresh context) confirmed all six AC, the authority ceiling (draft-PR only; `deny` blocks merge/ready/close), the CI-scoped SAFETY GATE relaxation (local `main` still refused), and the doc wiring.
- **🔵 Nit (resolved)**: a turn-cap / agent-error stop aborts the `conductor` job before writing `$GITHUB_OUTPUT`, so `ci-check` skipped and posted nothing — contradicting the "always comments green/red" promise. **Fix applied** (journal D-006): emit `outputs.issue` up front; `ci-check` now runs on conductor success **or** failure (`always()` + `needs.conductor.result` guard, still skips on a non-`pipeline:ready` skip) and posts a 🟡 "did not complete" note. Reference updated; `actionlint` re-run green.

## Criteria

| AC | Status | Evidence |
|---|---|---|
| SC-1 reference w/ 3 mechanisms + secrets + permissions + pre-stage + caps + CI-isolation + post-check + A-vs-B table | PASS | `plugins/samuel/reference/automated-trigger.md` — all elements present (reviewer-confirmed) |
| SC-2 valid workflow: triggers (schedule + issues:labeled→ready + dispatch), pre-stage, `claude -p` + turn cap, draft PR | PASS | `conductor.yml` — `actionlint` exit 0; `--max-turns 50`; `--ship` → `/samuel:done --draft` |
| SC-3 post-PR job: `gh pr checks --watch` + comment green/red, no ready/merge | PASS | `conductor.yml` `ci-check` job; comment at end confirms never ready/merge |
| SC-4 SAFETY GATE accepts CI runner, without relaxing local main/non-worktree refusal | PASS | `conductor/SKILL.md` gate item 1 (worktree OR CI runner; local main still refused — unambiguous) |
| SC-5 A→B = only `runs-on:` change | PASS | stated in `automated-trigger.md` (B section + A-vs-B table) + `conductor.yml` comment |
| SC-6 doc wiring: autonomous-run, conductor/SKILL, pipeline, CLAUDE.md → reference | PASS | all four edited to link the reference; links resolve; no duplication |

DoD: all Steps complete · `actionlint` green · all internal links resolve · every AC met · draft-PR-only authority preserved.

## Manual Testing Checklist (consumer repo — the template is a scaffold, not wired live here)

1. Copy `conductor.yml` to `.github/workflows/` in a consumer repo that uses the samuel pipeline (Issues with `pipeline:*` labels).
2. Add repo secret `ANTHROPIC_API_KEY` (or `CLAUDE_CODE_OAUTH_TOKEN`).
3. Trigger via `workflow_dispatch` with a `pipeline:ready` issue number → expect: a feature branch, a **draft** PR (`Closes #N`), and an issue comment with the CI result.
4. Add the `pipeline:ready` label to a planned issue → expect the `conductor` job to fire (labeled path) and ship a draft PR.
5. Confirm the workflow never marks a PR ready, merges, or closes an issue.
6. (Option B) change `runs-on: ubuntu-latest` → `self-hosted`; confirm nothing else needs changing.

## Issues (before merge)

None. The single review Nit was resolved in-branch.

## Documentation impact

- **In scope (SC-6) — done**: `CLAUDE.md`, `reference/pipeline.md`, `conductor/SKILL.md`, `autonomous-run.md` all point to `reference/automated-trigger.md`.
- **Surfaced (not auto-applied)**: `README.md` "Autonomous (headless / droplet)" section (lines ~76-83) documents the *manual* loop only; a one-line pointer to the automatic trigger would keep it current. Out of the plan's scope — propose as a follow-up or quick edit.
- **Feature dossier**: not required — `automated-trigger.md` already serves as the capability reference for this dev-tooling plugin.

## Journal: D:6 V:1 T:0 Q:0 (open: 0)  ·  Deviations: 1 (V-001, sub-threshold, no escalation)
