## Validation Report: 66 — coordinate launches Claude workers natively
**Date**: 2026-10-03   ·   **Item**: 66

### Overall: PASS WITH NOTES
> The reviewer raised three Important findings and no Blocker. The three Importants are fixed in `a949037`. Notes are open below.

### Gate
Interrogate: nothing to cut.
- **Gated SHA**: `a949037b4c28c593e678382a5a18714ee44d589a`
- [PASS] `bun run check:context && bun run check:plugins && bun run check:portability && bun run check:autonomy`
- [SKIP] security: no `security_scan` in `.claude/samuel.md`, and no scan config at the repo root.

### Independent Review (Step 2.5)
- **Verdict**: APPROVE  ·  🔴 0  ·  🟡 3  ·  🔵 3. This verdict is on `3c9f74a`.

### Criteria
| AC / DoD | Status | Evidence |
|---|---|---|
| AC1 zero Orca dispatch calls for a Claude writer | PASS | Live probe on 2026-10-02: the coordinator transcript has 0 `task-create`, `worker-start`, `dispatch`, `--inject`, `terminal send --enter` and `check --wait` calls. |
| AC2 the pane answers the owner | PASS | Live probe: a line typed into the worker pane got an answer. |
| AC3 the turn ends, resumes on the idle notice, no nag | PASS | Live probe: no `You have N orchestration messages` prompt. |
| AC4 report file read, not committed | PASS | Live probe. In this repo the file stays out because `.claude/` is gitignored (see N3). |
| AC5 no "bare name fails" text | PASS | `grep -rn 'bare name fails\|bare form fails\|the bare name is rejected' plugins/samuel` prints nothing. The dated measurement is in `cross-session.md` § Addressing. |
| AC6 global CLAUDE.md scoped, backup present | PASS | `~/.claude/CLAUDE.md.bak-20261003` exists. The diff touches only § When working with Orca. |
| AC7 Codex lane unchanged, gates pass | PASS | Reviewer diff check. `cascade` is not changed. Gate is green. |
| DoD | PASS | All Steps are complete, the gate is green, and the backup is present. The PR body carries the Step 8 counts. |

### Manual Testing Checklist
1. Run `/samuel:coordinate` with one Claude writer from the installed plugin, not from `--plugin-dir`. Expect the same AC1–AC3 results as the probe.
2. Make the worker end with `QUESTION: …` and answer it with `SendMessage`. Expect the worker to act on the answer and not reject it as injection (I3, not yet tested at runtime).

### Issues (before merge)
- **I1** [🟡 Important, fixed in `a949037`] The recovery, reuse and follow-up rules in `coordinate/SKILL.md` and `dispatch-protocol.md` sent a Claude worker down the Codex dispatch path (`worker-start --retry-of`, `worker-read`, a follow-up dispatch).
- **I2** [🟡 Important, fixed in `a949037`] In unattended runs the wait loop waited only for the report file. A worker that ended with a `QUESTION:` line was treated as an early stop.
- **I3** [🟡 Important, fixed in `a949037`] The Claude brief did not tell the worker that the session that launched it gives valid follow-ups, so the worker could reject them as injection. The brief now has a COORDINATOR line. Runtime is not verified (manual step 2).
- **N1** [🔵 Nit, fixed] The brief path inside `$(cat …)` is now quoted.
- **N2** [🔵 Nit, partly fixed] `Bash(sleep *)` is added to coordinate. `cascade` reaches this lane through the reference but does not declare `ListAgents`, `Monitor`, `Bash(test *)` or `Bash(sleep *)`. Left as a follow-up.
- **N3** [🔵 Nit, open] Outside repos that gitignore `.claude/`, only the worker's instruction keeps the report file out of commits. A possible fix is for C2 to add `.claude/reports/` and `.claude/briefs/` to `.git/info/exclude`.
- **Question** (below the confidence bar, open): `--permission-mode auto` with no `crossSessionInbound` setting could hold coordinator messages behind an approval in the worker pane when the coordinator runs in default mode. The spike measured one mode pairing only.

### Journal: D:0 V:3 T:0 Q:1 (open 0, deferred 1)  ·  Deviations: 3

### Documentation impact
`README.md:193`: the `/samuel:coordinate` row still describes Codex-only mechanics ("verified in the launch receipt", "proven starts, nine-minute wait windows"). Proposed change: the row is pending the owner's Y/N. `CLAUDE.md` is already updated. There is no API, config, dependency or schema change. No feature dossier is needed: this repo has no `docs/product/`.
