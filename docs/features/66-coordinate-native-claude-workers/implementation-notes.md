# Implementation Notes: 66-coordinate-native-claude-workers

> **Item**: #66  ·  **Plan**: Issue #66 body, `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:0 V:3 T:0 Q:1 (open_remaining: 1)
> **Status**: living
> **Flags**: has-deviations, has-open-questions

## Design Decisions

## Deviations

### V-001 · Unattended coordinators keep the turn open for Claude workers
- **Phase**: us1
- **Step**: 3
- **When**: 2026-10-02
- **Files**: `plugins/samuel/skills/coordinate/SKILL.md` (§ Unattended runs)
- **Status**: applied
- **Affects**: none
- **Plan said**: the coordinator may end its turn while Claude workers run and resume on the idle notice.
- **Reality**: under `claude -p` an ended turn ends the run, so no notice would ever be read.
- **Applied**: the Claude lane waits in foreground windows of at most nine minutes that return when the report file appears; an expired window is a liveness tick. Interactive runs keep the plan's behaviour.
- **Linked decision**: none (sub-threshold; the plan's interactive path is unchanged)

### V-002 · Repo CLAUDE.md coordinate bullet updated
- **Phase**: us1
- **Step**: 6
- **When**: 2026-10-02
- **Files**: `CLAUDE.md` (§ Workflow Skills, `/samuel:coordinate`)
- **Status**: applied
- **Affects**: none
- **Plan said**: the plan's file list did not name the repo `CLAUDE.md`.
- **Reality**: its `/samuel:coordinate` bullet described `worker-start` for every worker, nine-minute `check --wait` windows and "workers always talk Orca mail", which this change makes false for Claude workers.
- **Applied**: the three sentences now describe both lanes.
- **Linked decision**: none (documentation follow-through)

### V-003 · The effort is observable after all
- **Phase**: us1
- **Step**: 8
- **When**: 2026-10-02
- **Files**: `plugins/samuel/skills/coordinate/references/dispatch-protocol.md` (C3 § Verify the launch), `plugins/samuel/skills/coordinate/SKILL.md` (step 5)
- **Status**: applied
- **Affects**: none
- **Plan said**: the effort cannot be read from the Claude TUI; record it as "requested, not observable" (also the TL;DR `Caveat`).
- **Reality**: the live run showed `◐ medium · /effort` in the worker's pane next to the model.
- **Applied**: the launch check now verifies model and effort; the Issue TL;DR caveat needs the same correction.
- **Linked decision**: none

## Tradeoffs

## Open Questions

### Q-001 · Two Context lines of coordinate misbehaved in the live run
- **Phase**: us1
- **Step**: 8
- **When**: 2026-10-02
- **Status**: open
- **Blocking**: no
- **Question**: the probe coordinator reported `Bound run` empty and the `Codex default` line delivered as an unexecuted instruction instead of a value. Both lines predate this change (`plugins/samuel/skills/coordinate/SKILL.md` § Context on `main`). Is it the `--plugin-dir` load, or are they broken on an installed plugin too?

