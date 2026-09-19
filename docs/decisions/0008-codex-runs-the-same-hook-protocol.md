# 8. Codex runs the same hook protocol: the token plane is a two-client plane

Date: 2026-09-19
Status: Accepted
Supersedes: decision point 6 of [ADR 0007](0007-token-plane-gate-large-io-out-of-context.md)

## Context

ADR 0007 built the token plane on two claims about the second client: Codex has no hooks and no agents, so the plane is a Claude Code feature and the `.codex-plugin` manifest ships the skills for repo-convention parity. Measured against `codex-cli 0.154.0` on 2026-09-13, both halves are false.

- **Hooks.** Codex runs a `PreToolUse` engine source-compatible with Claude Code's: the same JSON on stdin, the same `hookSpecificOutput.permissionDecision` verdict. The unmodified `scripts/check-read.sh` denied a 900-line `cat` under `codex exec` with no change to the script.
- **Agents.** Codex has multi-agent support (feature `multi_agent`, stable and on). The tool is `spawn_agent`, and it takes `model` and `reasoning_effort` per call. A named worker can be declared as `[agents.<role>]`, but only through a config layer installed into the user's or the repo's Codex home.
- **Tool names differ.** Codex reports `Bash` for every shell-like tool, `apply_patch` (matcher aliases `Write`, `Edit`), and `spawn_agent` (alias `Agent`). It has no `Read` and no `Grep` tool, so a whole-file read there is always a shell command.
- **Plugin-shipped hooks do not run.** 0.154.0 accepts a `hooks` field in `.codex-plugin/plugin.json` and installs the manifest without complaint, but runs no handler from it.
- **A handler must be trusted once.** Codex keys the trust by a hash under `[hooks.state]` in `~/.codex/config.toml`. The hash is computed inside Codex over the normalized handler identity, so it cannot be produced from outside; until it exists, the handler is skipped **in silence**.
- **There is no cheap model tier.** The catalog on this machine is `gpt-5.5`, `gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-6-astra` — no equivalent of haiku.
- **A Codex subagent is not exempt.** Every Codex subagent reports `agent_type: "default"` with a UUID `agent_id`, so the gates' exemption by worker name can never match one. In a live probe the spawned worker was denied a `cat`, took none of the three exits the denial named, and reported failure to its parent.

## Decision

The token plane is a **two-client plane**. One protocol, one pair of gate scripts, two installs.

1. **The gate scripts are client-neutral and stay one implementation.** `SHUNT_CLIENT=claude|codex` selects the vocabulary the denial names its three exits in; unset emits wording valid on either client, and both shipped hooks files declare their client rather than relying on that default.
2. **The install differs per client.** Claude Code loads the plugin's own `hooks/hooks.json`. Codex gets `<repo>/.codex/hooks.json` written per repo by `plugins/shunt/scripts/install-codex.sh`, which never touches `~/.codex`. The manifest keeps its `hooks` field for the version that starts running plugin-shipped handlers.
3. **Trust is the human's step and is reported, never assumed.** `install-codex.sh --check` reads whether a `[hooks.state]` entry exists for each shunt handler and says so; automation that cannot approve passes `--dangerously-bypass-hook-trust`.
4. **The Codex worker carries its contract inline.** `spawn_agent` with `model: gpt-5.5` and `reasoning_effort: low`, the worker's rules in the message. The `[agents.<role>]` form is deferred: it needs config installed into a Codex home, and the gain is not retyping six lines.
5. **Every Codex spawn message orders the bounded read itself** (`sed -n '1,<n>p'`), the deliberate override the gate already honours. Exempting `agent_type: "default"` was rejected: it would exempt every Codex subagent, against ADR 0007's stated intent that a non-worker subagent pays what the main model pays.
6. This supersedes **decision point 6 of ADR 0007**. That ADR keeps its body: it records what was decided and why at its date, and editing it to match later knowledge would destroy the reason the original looked right.

## Consequences

- The plugin's promise is now client-conditional in one direction only: the **gate** holds on both clients, the **install** is automatic on one and a per-repo command on the other. A Codex repo that never runs the installer has no plane at all, and nothing in the session says so — `--check` is the only signal.
- A silently skipped handler looks exactly like a repo with small files. Any Codex measurement starts by confirming trust, not by reading the denial log.
- On the Codex side the saving is the corpus dying in the worker's context, not a lower per-token price: the worker runs on a frontier model at low effort. The trade is still favourable for answer-shaped reads and poor for a borderline file.
- The delegation recipes now carry two blocks each, and the platform facts live in `plugins/shunt/reference/cross-client.md` so they are stated once. A third client would add a column there, not a third block in each skill.
- A Codex worker pays the gate like the main thread, so a recipe that forgets the bounded-read sentence produces a worker that fails instead of one that costs more. The failure is loud, which is the reason the sentence is in the recipe and not in a gotcha.
