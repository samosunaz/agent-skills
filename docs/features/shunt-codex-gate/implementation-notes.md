# Implementation Notes: shunt-codex-gate

> **Item**: #43  ·  **Plan**: Issue body plan section  ·  **Constitution**: none
> **Counters**: D:4 V:1 T:0 Q:2 (open_remaining: 0)
> **Status**: sealed
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

### D-003 · Both shipped hooks files declare SHUNT_CLIENT; neither relies on the default
- **Phase**: foundational
- **Step**: 3
- **When**: 2026-09-14
- **Files**: `plugins/shunt/hooks/hooks.json`, `plugins/shunt/scripts/install-codex.sh`
- **Status**: applied
- **Affects**: none
- **Context**: `SHUNT_CLIENT` unset emits the neutral message. The Claude Code hooks file did not set it, so the primary client silently dropped from its own precise wording to the generic one — a downgrade the eval could not see, because its grader matches only the denial prefix. Found by the interrogate pass, not by the gate.
- **Decision**: Every shipped hooks file names its client: `SHUNT_CLIENT=claude` in `hooks/hooks.json`, `SHUNT_CLIENT=codex` in what the installer writes. The unset state is a fallback for a hand-written hooks file, never the path either client takes.
- **Why**: A default that one shipped configuration silently depends on is not a default, it is an undeclared coupling. Naming the client in both files also makes the hooks file readable on its own: the command says which vocabulary it expects.

### D-004 · The installer identifies its own handlers by script name everywhere
- **Phase**: polish
- **Step**: 4
- **When**: 2026-09-14
- **Files**: `plugins/shunt/scripts/install-codex.sh`
- **Status**: applied
- **Affects**: none
- **Context**: The merge first dropped prior handlers by the path fragment `shunt/scripts/check-`. That matches the repo checkout and nothing else: a marketplace install lives at `plugins/cache/<marketplace>/shunt/<version>/scripts/`, where the fragment never appears. The independent review reproduced the consequence — three installs left six handlers, and a version upgrade would leave the handler pointing at the deleted directory in place.
- **Decision**: Every place that recognises a shunt handler matches on the script name (`check-read.sh`, `check-search.sh`), the same identity `gate_state` already used. The filter also runs inside the matcher group instead of dropping the group, so a foreign handler sharing a group survives.
- **Why**: A versioned install directory is the normal deployment, not an edge case, and a self-test run from the repo checkout can never see the failure. One identity used in all three places (merge, gate report, trust lookup) is the only shape that cannot drift.

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
- **Status**: deferred
- **Resolution**: Deferred at validation. Real use answers it for free: duplicate lines carrying the same second in the denial log mean the delivery is real, their absence means the first probe was misread. A Codex run bought now would only buy precision in a measurement nothing consumes yet.
- **Impact if unresolved**: The denial log double-counts, so any measurement built on its line count overstates the gate's hit rate. The gate itself is unaffected: a second deny on a blocked call changes nothing.

### Q-002 · Would a future Codex that loads plugin hooks double-install the gate?
- **Phase**: foundational
- **Step**: 5
- **When**: 2026-09-14
- **Spec ref**: Step 5, the `hooks` field in the Codex manifest
- **Question**: The Codex manifest now declares `hooks: ./hooks/hooks.json` for the version that re-enables plugin-shipped handlers. A repo that also ran `install-codex.sh` would then carry the same two gates twice: once from the plugin, once from `.codex/hooks.json`. Does Codex de-duplicate identical handlers, and if not, should `install-codex.sh --check` warn when both sources are present?
- **Blocking**: no
- **Status**: deferred
- **Resolution**: Deferred at validation, and unverifiable today by construction: it needs a Codex version that runs plugin-shipped handlers. Revisit when one ships.
- **Impact if unresolved**: A doubled gate denies the same call twice, which changes nothing for the model, and logs the denial twice, which inflates the measurement. It cannot happen on 0.154.0, where plugin handlers never run.

