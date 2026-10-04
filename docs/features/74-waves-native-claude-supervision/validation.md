## Validation Report: 74 — waves follows claude-variant workers through idle notices
**Date**: 2026-10-03   ·   **Item**: 74

### Overall: PASS WITH NOTES
> The reviewer returned REQUEST CHANGES with no Blocker and three Importants. All three Importants and both Nits are fixed in `95d3d83`. The gate is green after the fix.

### Gate
Interrogate: nothing to cut.
- **Gated SHA**: `95d3d832d9852414b684946462bafd73b7a34ee0`
- [PASS] `bun run check:context && bun run check:plugins && bun run check:portability && bun run check:autonomy`
- [SKIP] security: there is no `security_scan` in `.claude/samuel.md` and no scan config at the repo root.

### Independent Review (Step 2.5)
- **Verdict**: REQUEST CHANGES  ·  🔴 0  ·  🟡 3  ·  🔵 2. The review ran on `e5c6dd0`.

### Criteria
| AC / DoD | Status | Evidence |
|---|---|---|
| AC1 one notice per exiting `-p` worker | PASS | Measured on 2026-10-03 with Claude Code 2.1.288, two workers: one notice each, and each notice carried the last reply line. |
| AC2 two stub workers, zero poll iterations | PASS | Journal § Validation evidence: two notices at 23:32, 0 `.jsonl` reads before them, one read per worker after. |
| AC3 report carries cost and turns | PASS | The P6 row now has `cost \| turns`, filled from the P4 `result` read (stub values: $0.0555 and $0.0559, 2 turns each). |
| AC4 gates | PASS | All four checks pass at the Gated SHA. |
| DoD: separate issue for conductor `tail -n 1` | PENDING | Prepared in `apply-8.sh`; it waits for the owner to run it. |

### Manual Testing Checklist
1. Run `/samuel:waves` on one real claude-variant item. Expect one notice when the conductor exits, then one `result` read and a P6 row with cost and turns.

### Issues (before merge)
- **I1** [🟡 Important, fixed] P5 sent `[landed]` text to a live `-p` worker without renewing the subscription. That text opens another turn, so the single notice could close the worker early, or the last `result` line could hide a failed first turn. Now the send carries `notify_when_idle`, the on-notice step confirms the pane exited, and a worker that got `[landed]` is judged on all its `result` lines.
- **I2** [🟡 Important, fixed] The tick had no case for a worker that exited with a `result` line but sent no notice, and the subscribe step had no case for a worker already gone. Now any exited pane is handled as a notice, and a missing roster row means read the pane.
- **I3** [🟡 Important, fixed] `Bash(git log *)` and `Bash(sleep *)` were missing from waves `allowed-tools`.
- **N1** [🔵 Nit, fixed] An aborted claude-variant row now writes the budget cap as its cost.
- **N2** [🔵 Nit, fixed] The tick check now runs for each silent worker, not only when the whole wave had no notice.
- **Not measured:** whether `total_cost_usd` and `num_turns` on a second `result` line are cumulative or per turn; and, in a mixed wave, whether notices and ticks wait behind the foreground Codex `check --wait` windows.

### Journal: D:1 V:0 T:0 Q:0  ·  Deviations: 0

### Documentation impact
README and CLAUDE.md do not describe the waves poll. No update is needed.
