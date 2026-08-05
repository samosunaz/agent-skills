# Validation Report: 46 — samuel: waves — ejecución multi-issue por DAG de dependencias sobre Orca

**Date**: 2026-07-28  ·  **Item**: 46  ·  **Branch**: feat/46-waves

## Overall: PASS

> Computed: gate green · security SKIP (neutral) · independent review APPROVE with zero open findings.

## Gate

- [PASS] `bun run check:context && bun run check:plugins && bun run check:autonomy` — 18/18 checks green, exit 0. Re-run after the review fixes; G1 checkpoint coverage picks up the new SKILL.md, `lint-skill-context.sh` parses its `## Context`, G5 conductor-bypass count intact at 9.
- [SKIP] security: no `security_scan` configured in `.claude/samuel.md` — explicitly skipped. No `.gitleaks.toml` / `.semgrep*` at the repo root either.

## Independent Review (Step 2.5)

- **Verdict**: APPROVE  ·  🔴 0  ·  🟡 0  ·  🔵 0 open
- History: the initial pass returned REQUEST CHANGES (🔴 2 · 🟡 3 · 🔵 2). All seven findings were fixed in commits `0bf2d96`, `8471068`, `6a3899f` and re-verified live by the same reviewer (it re-ran the corrected recipes against Orca and the GitHub API, and re-ran the three gates itself) → APPROVE.

| ID | Severity | Finding | Resolution |
|---|---|---|---|
| B1 | 🔴 | `--repo name:{REPO}` conflated the GitHub repo name with Orca's displayName (`repo_not_found`, with exit code 0) | P0 resolves `{ORCA_REPO_ID}` by absolute path; all selectors use `id:`; `.ok`-not-`$?` caveat documented + SKILL.md gotcha |
| B2 | 🔴 | P6 `conductor:log` find-or-create dropped the `gh label create --force` guard — first run in a repo loses its report | Guard restored as the first line of the P6 block, matching autonomous-run.md |
| I1 | 🟡 | "REST does not expose dependencies" was false | § Issue dependencies rewritten: both APIs; REST single-issue read recipe added; lowercase/uppercase `state` caution |
| I2 | 🟡 | Orca `task-list --ready` labeled "dispatch queue" — tasks complete at draft-PR time, before the human merge | P2 now: provenance only; dispatch decided exclusively by the GitHub graph (P5) |
| I3 | 🟡 | Drafting artifact ("— wait:") left inside P1's peeling rule | Rewritten as two ordered passes: exclude external-blocked, then peel zero-open-blocker candidates |
| N1 | 🔵 | `## Context` fallbacks unreachable (pipe swallows exit status) | Both pipelines end `\| grep . \|\| echo "…"`; both paths verified |
| N2 | 🔵 | README skill registry stale vs CLAUDE.md | Tree line + skills-table row added |

Standing caveat (non-blocking): the reviewer declined to reproduce V-001's write-mutation claim (`addBlockedBy` re-add fails loudly) against the live repo; it was verified in-session during implement Step 1.

## Criteria

| AC / DoD | Status | Evidence |
|---|---|---|
| AC1 — three gates green with the new files; no `checkpoint-exclusions.txt` entry; `## Context` expansion-free | PASS | 18/18, exit 0 (re-run post-fixes); exclusions file untouched (verified by two agents) |
| AC2 — `wave-protocol.md` cold-agent litmus | PASS | The independent reviewer executed P0 recipes verbatim as a cold agent (`orca repo list` → id → `repo show` `ok=true base=origin/main`); the two litmus failures it found (B1, B2) are fixed and re-verified |
| AC3 — full dogfood cycle over a ≥2-issue DAG | DEFERRED | Post-merge attended run, tracked on the issue (declared out of this validate by the plan) |
| AC4 — § Issue dependencies recipes reproduce cold | PASS | REST read of 46 → 29, 30 (verified twice: maker + reviewer); GraphQL batch verified; `addBlockedBy` fail-loudly contract documented (V-001); `.[0]//empty` + `nodes: []` guards present |
| DoD — 4 Steps complete · gate green · AC1/AC2/AC4 met · CLAUDE.md entry, exclusions untouched | PASS | v-analyzer: all 4 changes LANDED with file:line evidence; gate output above |

## Manual Testing Checklist

1. **AC3 dogfood (post-merge, attended)**: `/samuel:waves` over ≥2 `pipeline:ready` issues with ≥1 native `blockedBy` edge → WAVE PLAN checkpoint → dispatch → `worker_done` → draft PR → human merge → next-wave release. Expected: full cycle with zero agent-executed merge/ready/close.
2. **Prereqs UI (from item 30, Sam's side)**: Orca Settings `agentDefaultArgs` for codex (`--model gpt-5.5 -c model_reasoning_effort="high"`), skip-confirm settings, `orca repo set-base-ref` on the target repo. The two-step fallback works without them.

## Documentation impact

- README.md registry updated (tree + table) as review fix N2 — applied on the branch, announced, not silent.
- CLAUDE.md entry landed in-plan (Step 4). `pipeline.md` carries no per-skill index — no gap. `checkpoint-exclusions.txt` correctly untouched.
- Feature dossier: not applicable — this is workflow tooling in the skill registry, not product behavior.

## Journal: D:0 V:3 T:0 Q:0 (open: 0)  ·  Deviations: 3

V-001 `addBlockedBy` re-add fails loudly (implement) · V-002 REST does expose issue dependencies (review fix) · V-003 Orca `name:` selector matches displayName (review fix). Sealed by this validation.
