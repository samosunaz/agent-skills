# Implementation Notes: codex-only-model-routing

> **Item**: #103 · **Plan**: [Executor Plan](https://github.com/samosunaz/agent-skills/issues/103) · **Constitution**: none
> **Counters**: D:0 V:1 T:0 Q:0 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

## Design Decisions

## Deviations

### V-001 · Strict manifest validation

- **Phase**: foundational
- **Step**: 1
- **When**: 2026-11-21
- **Files**: `scripts/validate-plugins.sh`
- **Status**: applied
- **Linked decision**: [Issue decision](https://github.com/samosunaz/agent-skills/issues/103#issuecomment-7065343543)
- **Affects**: none
- **Plan said**: Run the existing strict manifest gate.
- **Did**: Validate canonical linked manifests in temporary package copies. An incorrect link and an unknown manifest field each failed in isolated fixtures.
- **Why**: Claude Code 2.1.330 rejected the tracked symlink on the unchanged base.

## Tradeoffs

## Open Questions
