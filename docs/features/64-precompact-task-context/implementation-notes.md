# Implementation Notes: 64-precompact-task-context

> **Item**: #64  ·  **Plan**: Issue #64 body, `## Proposed change` (no Executor Plan; size S)  ·  **Constitution**: none
> **Counters**: D:1 V:1 T:0 Q:0 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

## Design Decisions

### D-001 · no jq, no stdin parsing
- **Decision**: the script drains stdin and reads nothing from it; it resolves the repo root with `git rev-parse --show-toplevel` from the session cwd.
- **Why**: plain-text output (V-001) removed the only reason for `jq`. The hook already runs in the session cwd, so reading `.cwd` from the payload added a dependency for no observed case.
- **Affects**: none.

## Deviations

### V-001 · plain stdout instead of `hookSpecificOutput`
- **Plan said**: keep the output contract `hookSpecificOutput.hookEventName = "PreCompact"` with `additionalContext` (Proposed change step 3, AC1 wording).
- **Found**: Claude Code 2.1.289 rejects it: "Hook JSON output validation failed — hookSpecificOutput.hookEventName: expected one of PreToolUse | UserPromptSubmit | …". The schema has no PreCompact variant. The user-level hook this replaces failed on every compaction for the same reason, so it never injected anything.
- **Measured**: a probe hook printing plain text made the compaction summary start with the probe's marker, so plain stdout reaches the compaction instructions.
- **Resolution**: the script prints the rules, branch and frontmatter as plain text. AC1's "additionalContext contains `item: 99`" is met as "the compaction summary contains `item: 99`".
- **Linked decision**: none needed (the planned contract does not exist in the runtime).

## Validation evidence (2026-10-05, Claude Code 2.1.289)

- Fixture scenarios, run with a PATH holding only `sh git sed awk cat` (no jq, no grep): branch `issue-99-x` + `99.md`, a subdirectory, legacy `.claude/task-context.md` only, neither file, outside git, a file without frontmatter. All exit 0 and print the rules; the frontmatter appears only where a file resolves.
- Branch `feat/42-x` with no `42.md` and two files in the directory: no frontmatter (no guess).
- End to end: `claude -p "/compact" --resume <sid> --plugin-dir plugins/samuel` in the fixture repo. Debug log: one `PreCompact:manual [sh "${CLAUDE_PLUGIN_ROOT}/scripts/precompact-handoff.sh"] completed with status 0`, zero errors. The compaction summary contains `issue-99-x`, `99.md` and `item: 99`.
- `claude plugin validate plugins/samuel` passes; the debug log shows `Read hooks.json for plugin samuel`.
- Owner machine: `~/.claude/settings.json` backed up to `settings.json.bak-20261005-precompact`, `hooks.PreCompact` removed (diff shows nothing else changed), `~/.claude/hooks/precompact-handoff.sh` moved to `.bak`.

## Tradeoffs

## Open Questions
