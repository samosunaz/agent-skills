# Shunt Across Clients

The token plane runs on **Claude Code** and on **Codex**. The two gate scripts are the same files on both; what differs is where the hooks file lives, what the tools are called, and how a worker is spawned. This spoke holds those facts once — `shunt:bulk-read` and `shunt:code-write` link here instead of restating them, because a fact written twice drifts.

## The two clients

| | Claude Code | Codex |
|---|---|---|
| Hook install | the plugin's own `hooks/hooks.json`, loaded when the plugin is installed | `<repo>/.codex/hooks.json`, written per repo by `scripts/install-codex.sh` — `codex-cli 0.154.0` reads a plugin's `hooks` field and runs no handler from it |
| Trust | none: a plugin handler runs as installed | each handler is **skipped in silence** until it is trusted once — approve it in the TUI, or pass `--dangerously-bypass-hook-trust`; `install-codex.sh --check` reports which state the repo is in |
| Hook tool names | `Read`, `Grep`, `Bash`, `Agent` | `Bash` for every shell-like tool, `apply_patch` (matcher aliases `Write`, `Edit`), `spawn_agent` (alias `Agent`). There is **no `Read` and no `Grep`** |
| Whole-file read (denied) | `Read` with no `offset`/`limit` | `cat`, `less`, `more`, `bat` through `Bash` |
| Bounded read (passes) | `Read` with `offset`/`limit` | `sed -n '<start>,<end>p'` |
| Worker | `Agent` on a plugin agent definition (`agents/bulk-reader.md`, `agents/code-writer.md`) | `spawn_agent` with `model` and `reasoning_effort` per call; there is no agent definition file, so the contract travels inside the message |
| Worker model | haiku (read) · sonnet (write) | `gpt-5.5` at `reasoning_effort: low` |
| Denial vocabulary | `SHUNT_CLIENT=claude` | `SHUNT_CLIENT=codex` |

## A Codex worker is gated like the main thread

The gates exempt the two workers by `agent_type` (`shunt:bulk-reader`, `shunt:code-writer`). Measured on `codex-cli 0.154.0`: every Codex subagent reports `agent_type: "default"` with a UUID `agent_id`, so that exemption can never match one. In a live probe the spawned worker was denied a `cat` of a large file, took none of the three exits the denial named, and reported failure to its parent.

Every Codex spawn message therefore **orders the bounded read itself** — `read <file> with sed -n '1,<line count>p'` — which is the deliberate override the gate already honours. Without that sentence the recipe produces a worker that is denied and gives up. Exempting `agent_type: "default"` was rejected: it would exempt every Codex subagent, against ADR 0007's intent that a non-worker subagent pays what the main model pays.

## Where the saving comes from

The Codex model catalog has no cheap tier: `gpt-5.5`, `gpt-5.6-luna`, `gpt-5.6-sol`, `gpt-5.6-terra`, `gpt-6-astra`, with no equivalent of haiku. `gpt-5.5` at `reasoning_effort: low` is the oldest and cheapest entry. On the Codex side the saving is the corpus dying in the worker's context, not a lower per-token price; under Claude Code it is both.

A named role (`[agents.<role>]` in a Codex config layer) would let the contract live in a file instead of in every message. It needs config installed into the user's or the repo's Codex home, and the gain is not retyping six lines, so the recipes use the self-contained inline form. The role is a follow-up if the prompt proves noisy in use.

## The standard phrase

One line per skill, next to its other spoke pointers:

```markdown
> **Clients:** delegate with `Agent` under Claude Code, with `spawn_agent` under Codex — tool names, install paths, and the inline worker contract: `../../reference/cross-client.md`.
```

## Gotchas

_Add a line each time an agent trips on something._

- Nothing in a Codex block may rely on `${CLAUDE_PLUGIN_ROOT}` or on a Claude-only frontmatter field (`allowed-tools`, `model`): Codex resolves neither.
- `install-codex.sh` writes only `<repo>/.codex/`. It never touches `~/.codex`, so trusting the handler stays the human's step.
