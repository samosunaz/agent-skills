# Implementation Notes: 74-waves-native-claude-supervision

> **Item**: #74  ·  **Plan**: Issue #74 body, `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:1 V:0 T:0 Q:0 (open_remaining: 0)
> **Status**: living
> **Flags**: none

## Design Decisions

### D-001 · A crashed claude-variant worker reports as `aborted`
- **Phase**: implement
- **Step**: 2
- **When**: 2026-10-03
- **Decision**: the P4 tick's crash case writes the report row `aborted`, not `crashed`.
- **Why**: P6's outcome set already has `aborted` for a run that ended without a result, and a new value would need its own definition there. The plan said `crashed`.
- **Affects**: none

## Validation evidence

### AC2 probe · 2026-10-03, Claude Code 2.1.288
- Two stub workers: `claude -p "…sleep 60 in the foreground…, then reply DONE." --model haiku --name stub74-{a,b} --settings '{"crossSessionInbound":"accept"}'`, stream-json to `stub-{a,b}.jsonl`.
- Supervised by the new P3/P4 text: both `issue`-style rows confirmed in `ListAgents`, one `SendMessage({to, notify_when_idle: true})` each with no `message`, one `Monitor` tick armed, turn ended.
- Notices: `stub74-a` and `stub74-b` each sent one `[Cross-session idle notice]` at 23:32 carrying `DONE.`.
- `.jsonl` reads before both notices: 0. Reads after: one per worker.
- Result reads: `stub74-a: success · $0.0555005 · 2 turns`, `stub74-b: success · $0.0558595 · 2 turns`. These are the values a P6 row takes (AC3).

## Tradeoffs

## Deviations

## Open Questions
