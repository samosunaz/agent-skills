# Implementation Notes: 65-iaas-single-launch

> **Item**: #65  ·  **Plan**: Issue #65 body, `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:0 V:0 T:0 Q:0 (open_remaining: 0)
> **Status**: living
> **Flags**: none

## Design Decisions

Option A was chosen at plan time (Issue #65 decision comment): one backgrounded `claude -p` per phase.

## Validation evidence

### Stub phase · 2026-10-04 21:53, Claude Code 2.1.289
- Command: `cd {scratch} && claude -p --model haiku --effort low --output-format stream-json --verbose < stub.md >> stub.jsonl 2>> stub.log`, launched with `run_in_background: true`. `stub.md` says "Reply with the single word DONE."
- The bypass and `--settings` flags were left out: the scratch directory has no `.claude/autonomous-ship.json`, and the stub uses no tool.
- Exit 0, with the harness's background-task notice as the end signal.
- `result` lines in the log: 1. The outcome read printed `success · $0.0581235 · 1 turns`.
- Leftover processes from the stub after exit: 0 (`pgrep -fl 'claude -p'`).
- Not verified: whether the skill's `Bash(cd *) Bash(claude -p *)` rules admit the compound `cd … && claude -p … < … >> …` when the iaas skill itself issues it. The stub ran from this session, not from inside the skill. The post-merge full run on a size-S item covers this.

## Tradeoffs

## Deviations

## Open Questions
