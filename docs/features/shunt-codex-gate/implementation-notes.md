# Implementation Notes: shunt-codex-gate

> **Item**: #43  ·  **Plan**: Issue body plan section  ·  **Constitution**: none
> **Counters**: D:2 V:1 T:0 Q:1 (open_remaining: 1)
> **Status**: living
> **Flags**: has-deviations, has-open-questions

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

### D-002 · A Codex subagent stays gated; the recipe carries the bounded read
- **Phase**: foundational
- **Step**: 6
- **When**: 2026-09-14
- **Files**: `plugins/shunt/scripts/check-read.sh:19`
- **Status**: applied
- **Affects**: #44 (commented, plan holds — no label change; it is pipeline:planned)
- **Context**: The gates exempt the two workers by `agent_type` (`shunt:bulk-reader`, `shunt:code-writer`). Measured in the live probe, every Codex subagent reports `agent_type: "default"` and a UUID `agent_id`, so the exemption can never match and a Codex worker is gated exactly like the main thread. The probe confirmed the consequence: the spawned subagent was denied `cat big.txt`, took no exit, and reported failure to its parent.
- **Decision**: Leave the exemption alone and put the bounded read in the spawn message instead. The Codex worker is told to read with `sed -n '1,<n>p'` up front, which is the deliberate override the gate already honours.
- **Why**: The alternatives are worse. Exempting `agent_type: "default"` exempts every Codex subagent, which contradicts ADR 0007's stated intent that a non-worker subagent pays the same as the main model. Declaring an `[agents.<role>]` so the name matches needs a config layer installed into the user's Codex home, which the plan deliberately deferred. The override path costs one sentence in the recipe and keeps the gate a single rule.

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

### Q-001 · Is the duplicate PreToolUse delivery real?
- **Phase**: foundational
- **Step**: 6
- **When**: 2026-09-14
- **Spec ref**: Brief DoD, second open research question
- **Question**: An early probe logged two identical `PreToolUse` payloads carrying the same `tool_use_id` for a single tool call, with one handler configured. Every later run in this issue logged one payload per call. Is the duplicate a Codex behaviour under some condition, or was the first probe misread?
- **Blocking**: no
- **Status**: open
- **Impact if unresolved**: The denial log double-counts, so any measurement built on its line count overstates the gate's hit rate. The gate itself is unaffected: a second deny on a blocked call changes nothing.

