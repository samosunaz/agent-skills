# Implementation Notes: 66-coordinate-native-claude-workers

> **Item**: #66  ·  **Plan**: Issue #66 body, `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:0 V:2 T:0 Q:0 (open_remaining: 0)
> **Status**: living
> **Flags**: has-deviations

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

## Tradeoffs

## Open Questions
