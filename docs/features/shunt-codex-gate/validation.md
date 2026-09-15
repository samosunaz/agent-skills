# Validation Report: 43 — feat(shunt): run the token-plane gate under Codex

**Date**: 2026-09-14   ·   **Item**: 43

## Overall: PASS

## Gate

Interrogate: nothing to cut across two passes. The second pass (before this gate) found one defect rather than surplus — the shipped Claude hooks file did not declare `SHUNT_CLIENT`, so the primary client had silently dropped to the neutral message. Fixed in `9e1c8dd`.

- **Gated SHA**: `762852517a23fb53b42988f8197757921ae119b1`
- [PASS] `bun run check:plugins && bun run check:portability && bun run check:context` — `✔ Validation passed with warnings` (2 pre-existing symlink warnings on the `.claude-plugin/plugin.json` symlinks), `Agent Plugins conformance OK (2 plugins)`, `Context commands OK`. Exit 0.
- [SKIP] security: no `security_scan` configured in `.claude/samuel.md` — skipping. Courtesy check: no `.gitleaks.toml` or `.semgrep*` at the repo root, so nothing is wired-but-unused.

Additional evidence, outside the gate:

- `claude plugin eval plugins/shunt` (full suite, 6 runs): `large-file-read` scored **with 1.00 / without 0.67 / Δ +0.33**, grader `deny-fired` matched. Re-run as a single case after the `SHUNT_CLIENT=claude` fix: score 1.00, `deny-fired` matched — the env-var prefix in the hook command does not break Claude Code's hook execution.

## Independent Review (Step 2.5)

- **Round 1** at `9e1c8dd` — **Verdict: REQUEST CHANGES** · 🔴 2 · 🟡 3 · 🔵 1
- **Round 2** at `8623032` — **Verdict: APPROVE** · 🔴 0 · 🟡 0 · 🔵 1

The reviewer verified by reproduction, not by reading the diff: it installed the plugin from this repo's marketplace into a throwaway `CODEX_HOME` and ran the installer against the layout `codex plugin add` actually produces. That is how it found B1, which the author's own test could not see.

**Delta since the APPROVE**: the single Nit was fixed in `7628525`, exactly as the reviewer specified, together with the `CLAUDE.md` narrowing its closing question asked for. No third review pass was run; the change since the approved SHA is the reviewer's own prescription.

## Criteria

| AC / DoD | Status | Evidence |
|---|---|---|
| AC1 — Codex deny names `sed -n '1,Np'`, never `Read offset/limit` | PASS | Live probe, isolated `CODEX_HOME`, `codex exec` on a 900-line file: `hook: PreToolUse Blocked`; reason contains `sed -n '1,900p'` and no `offset`; one line appended to the denial log. |
| AC2 — installer idempotent, one entry per gate | PASS | Three installs from the versioned marketplace layout `plugins/cache/samuel-skills/shunt/4.10.0/scripts/`: 2 handlers, `git status --porcelain` empty on re-run over a committed tree. Reviewer reproduced independently, including a `4.11.0` upgrade replacing rather than appending. |
| AC3 — `--check` writes nothing; `[GAP]` without the gate, `[PASS]` with it | PASS | `git status --porcelain` empty before and after `--check` in a clean repo; 5 gaps reported with no gate, 0 after install with both handlers trusted. |
| AC4 — unset `SHUNT_CLIENT` names no client-specific tool | PASS | Asserted against the emitted reason for `offset`, `Agent shunt`, `spawn_agent`, `sed -n`, `rg `, `Grep` — none present. An unknown value falls back to the same wording. |
| AC5 — Claude side unchanged | PASS | Eval above. The one real regression here (the message downgrade) was found by the interrogate pass and fixed before this report. |
| DoD — all Steps complete | PASS | Steps 1-6 of the Executor Plan, each with its verification run. |
| DoD — gate green | PASS | See Gate. |
| DoD — live Codex probe quoted in the PR body | PENDING | Carried to `/samuel:done`. |
| DoD — the two open research questions answered or carried | PASS | Q-001 answered by measurement (a Codex subagent reports `agent_type: "default"`) as journal `D-002`; the duplicate-delivery question and the future double-install question are recorded as `Q-001`/`Q-002` with resolutions, both deferred, both non-blocking. |

## Manual Testing Checklist

1. In a repo where you use Codex: run `bash <plugin>/scripts/install-codex.sh` from its root → expect `[PASS]` for `codex-config`, `hooks-file`, `read-gate`, `search-gate`, and `[GAP] trust`.
2. Open `codex` once in that repo and approve both handlers when prompted → re-run `install-codex.sh --check` → expect `SHUNT-CODEX: PASS — 0 gaps`.
3. Ask Codex to `cat` a file over 350 lines → expect the call blocked and the reason to name `sed -n`.
4. Ask Codex a question that needs the whole file → expect it to read in bounded ranges, or to spawn a worker whose message already carries the bounded read.
5. In Claude Code, read a file over 350 lines with no `offset`/`limit` → expect the denial in Claude vocabulary (`Agent shunt:bulk-reader`, `offset=1 limit=<n>`), not the neutral wording.

## Issues (before merge)

None outstanding. For the record, the findings raised and closed during validation:

- **B1** [🔴 Blocker] The installer recognised its own handlers by the path fragment `shunt/scripts/check-`, which exists only in a repo checkout. A marketplace install lives under `plugins/cache/<marketplace>/shunt/<version>/scripts/`, so every re-run appended a duplicate pair — three runs, six handlers. Fixed in `8623032`: identity is the script name everywhere.
- **B2** [🔴 Blocker] The Codex denial's first exit told the model to spawn a worker that this same gate then denied, which the author's own probe had already measured. Fixed in `8623032`: the spawn message the denial dictates carries the bounded read.
- **I1** [🟡 Important] The trust check passed on any trusted handler in the file, so a repo with a pre-existing trusted hook certified a silently-skipped shunt gate as on. Fixed in `8623032` and tightened in `7628525`: a key is required per shunt handler, by group and handler index.
- **I2** [🟡 Important] The merge dropped a whole matcher group, taking any foreign handler that shared it. Fixed in `8623032`: filtering runs inside the group.
- **I3** [🟡 Important] `CLAUDE.md` asserted that the Codex manifest rejects a `hooks` field and that Codex has no hooks. This diff created the contradiction, so it closes it — fixed in `8623032`, narrowed to the verified form in `7628525`.
- **N1** [🔵 Nit] An empty `hooks.json` was unrecoverable and two early exits dropped the gate lines from their report; separately, the delete predicate matched a foreign command that merely named one of our scripts. Fixed in `8623032` and `7628525`.

## Journal: D:4 V:1 T:0 Q:2 (0 open)  ·  Deviations: 1
