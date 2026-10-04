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

## Tradeoffs

## Deviations

## Open Questions
