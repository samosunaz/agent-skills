# Implementation Notes: shunt-codex-gate

> **Item**: #43  ·  **Plan**: Issue body plan section  ·  **Constitution**: none
> **Counters**: D:1 V:1 T:0 Q:0 (open_remaining: 0)
> **Status**: living
> **Flags**: has-deviations

## Design Decisions

### D-001 · A gate handler is matched by script name, not by the path we would write
- **Phase**: foundational
- **Step**: 4
- **When**: 2026-09-14
- **Files**: `plugins/shunt/scripts/install-codex.sh`
- **Status**: applied
- **Affects**: none
- **Context**: The plan asked `--check` to detect a hooks file whose referenced script no longer exists. Matching the handler by the absolute path the installer would write makes that state unreachable: the path is derived from the running script's own location, so it always exists, and a hooks file pointing anywhere else reads as *absent* instead of *stale*.
- **Decision**: Match on the script name (`check-read.sh`), then read the quoted path out of the command and test that path. A handler pointing at a different but existing shunt install reports `[PASS]` with the path it actually references, not a warning.
- **Why**: The two failures a human must tell apart are "no gate here" and "a gate that cannot run". Reporting the referenced path makes the second one self-explanatory, and a second working install is not an error worth a gap.

## Deviations

### V-001 · The trust check observes Codex config instead of always reporting a gap
- **Phase**: foundational
- **Step**: 4
- **When**: 2026-09-14
- **Files**: `plugins/shunt/scripts/install-codex.sh`
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: The `trust` check is always a `[GAP]` with the instruction, because the hash cannot be read from outside Codex.
- **Did**: The check greps `${CODEX_HOME:-~/.codex}/config.toml` for a `[hooks.state."<abs hooks.json>:pre_tool_use:..."]` key and reports `[PASS]` when one exists, `[GAP]` with the instruction otherwise. It never writes there.
- **Why**: The plan's premise was half right. The hash cannot be *computed* outside Codex, but its *presence* is observable — the entries are plain TOML keys in the user config. A check that always fails trains the reader to ignore it, and the verdict line could never reach PASS on a correctly installed repo.

## Tradeoffs

## Open Questions
