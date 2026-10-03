# Implementation Notes: 66-coordinate-native-claude-workers

> **Item**: #66  ·  **Plan**: Issue #66 body, `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:0 V:1 T:0 Q:0 (open_remaining: 0)
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

## Tradeoffs

## Open Questions
