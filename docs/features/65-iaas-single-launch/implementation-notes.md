# Implementation Notes: 65-iaas-single-launch

> **Item**: #65  ·  **Plan**: Issue #65 body, `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:1 V:0 T:0 Q:0 (open_remaining: 0)
> **Status**: sealed
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

### Full-flag stub · 2026-10-04, Claude Code 2.1.289
- Same stub with the exact chain flags: `--permission-mode bypassPermissions --settings .claude/autonomous-ship.json`, the file holding a two-rule deny list (`git push`, `gh pr merge`).
- Exit 0; outcome read `success · $0.0589375 · 1 turns`; leftover processes 0.
- With the settings file absent: `Error: Settings file not found`, exit 1, 0 `result` lines. This is why the skill now checks the file before CONFIRM, and why "no `result` line" reads as an aborted phase.

### D-001 · one log per phase
- **Decision**: each phase appends to `~/iaas-{N}-{phase}.jsonl` instead of one shared log.
- **Why**: with a shared log, a phase that aborts before writing a `result` line shows the previous phase's `success`, and the chain would advance on it (independent review N1).
- **Affects**: none.

## Tradeoffs

## Deviations

## Open Questions
