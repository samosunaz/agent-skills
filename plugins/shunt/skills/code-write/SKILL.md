---
name: code-write
description: "Hand pattern-following code generation (tests, configs, type stubs, fixtures, adapters) to a cheap worker (the code-writer agent on sonnet under Claude Code, spawn_agent under Codex) that writes straight to disk from a mandatory reference file, so neither the reference nor the output passes through the main context. Trigger on 'write tests like', 'generate boilerplate', 'stub this', 'same pattern as', 'code write'."
allowed-tools: Agent Grep Glob Read Bash(git diff *) Bash(git status *)
---

# code-write

The model reads a reference test, then emits 200 lines shaped like it, paying main-model price twice. This skill sends the spec plus one reference file to a cheap worker — the plugin's `shunt:code-writer` agent (`agents/code-writer.md`, sonnet, `Write` allowed) under Claude Code, a `spawn_agent` call carrying the same contract under Codex — and lets the worker put the result on disk. Only the file list comes back.

> **Clients:** delegate with `Agent` under Claude Code, with `spawn_agent` under Codex — tool names, install paths, and the inline worker contract: `../../reference/cross-client.md`.

## When to delegate

- **Pattern exists**: a sibling test, a config for another env, a DTO that mirrors an existing one, a repository class shaped like its neighbours.
- **Spec is closed**: you can state the acceptance in a few lines and the worker does not need to make a design call.
- **Not**: a new pattern, anything user-facing (UI, copy, API design), or code on a payments/auth/safety path. Those stay with the main model.

## Process

### 1) Pick the reference

Exactly one file that the output must resemble. Without it the worker generates context-free code that matches nothing in the repo; the reference is mandatory. Name the target path explicitly.

### 2) Delegate

**Claude Code** — spawn the `shunt:code-writer` agent with a self-contained English prompt:

```
Create <target path>.
Reference: <reference path> — match its structure, imports, naming, and assertion style exactly.
Spec: <what the file must cover, as a short list>.
Constraints: no new dependencies, do not touch any other file.
```

**Codex** — there is no agent definition file, so the same contract travels inside the message. Call `spawn_agent` with `model: gpt-5.5` and `reasoning_effort: low`:

```
Create <target path>.
Reference: read <reference path> with sed -n '1,<line count>p' — the read gate applies to you too, and a bounded range is its deliberate override, so never cat it. Match its structure, imports, naming, and assertion style exactly.
Spec: <what the file must cover, as a short list>.
Rules: read a sibling file only when the reference imports it and you need its signature. Write the target file and no other; add no dependencies. No markdown fences and no explanations inside the file — comments only where the reference uses them. Reply with the target path and one line per section written, nothing else. If the spec needs a design call the reference does not settle, follow what the pattern implies and report it in one line prefixed `assumed:`.
```

The worker writes with its own client's tool (`apply_patch` under Codex), so the contract names the target file, never a tool. The `sed -n` sentence is not optional: a Codex subagent reports `agent_type: "default"`, so the gates' worker exemption never matches it.

### 3) Verify

Run the repo's verify contract on the new file (tests, lint, typecheck). Read the diff with `git diff`, not the file. A failing or vacuous result goes back to the worker with the failure text, or you finish it yourself; never report it done on the worker's word.

## Gotchas

_Add a line each time Claude trips on something._

- A reference file over the shunt limit is fine to name in the prompt: under Claude Code the worker is exempt from the gate and reads it whole, you do not. Under Codex no worker is exempt, so the prompt hands it the bounded `sed -n` read instead.
- `assumed:` lines in the worker's reply are design calls it made for you. Read them before running tests, not after.
