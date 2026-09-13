---
name: code-write
description: "Hand pattern-following code generation (tests, configs, type stubs, fixtures, adapters) to the cheap code-writer agent (sonnet) that writes straight to disk from a mandatory reference file, so neither the reference nor the output passes through the main context. Trigger on 'write tests like', 'generate boilerplate', 'stub this', 'same pattern as', 'code write'."
allowed-tools: Agent Grep Glob Read Bash(git diff *) Bash(git status *)
---

# code-write

The model reads a reference test, then emits 200 lines shaped like it, paying main-model price twice. This skill sends the spec plus one reference file to the plugin's `shunt:code-writer` agent (`agents/code-writer.md`, sonnet, `Write` allowed) and lets the worker put the result on disk. Only the file list comes back.

## When to delegate

- **Pattern exists**: a sibling test, a config for another env, a DTO that mirrors an existing one, a repository class shaped like its neighbours.
- **Spec is closed**: you can state the acceptance in a few lines and the worker does not need to make a design call.
- **Not**: a new pattern, anything user-facing (UI, copy, API design), or code on a payments/auth/safety path. Those stay with the main model.

## Process

### 1) Pick the reference

Exactly one file that the output must resemble. Without it the worker generates context-free code that matches nothing in the repo; the reference is mandatory. Name the target path explicitly.

### 2) Delegate

Spawn `shunt:code-writer` with a self-contained English prompt:

```
Create <target path>.
Reference: <reference path> — match its structure, imports, naming, and assertion style exactly.
Spec: <what the file must cover, as a short list>.
Constraints: no new dependencies, do not touch any other file.
```

### 3) Verify

Run the repo's verify contract on the new file (tests, lint, typecheck). Read the diff with `git diff`, not the file. A failing or vacuous result goes back to the worker with the failure text, or you finish it yourself; never report it done on the worker's word.

## Gotchas

_Add a line each time Claude trips on something._

- A reference file over the shunt limit is fine to name in the prompt; the worker is exempt from the gate and reads it whole, you do not.
- `assumed:` lines in the worker's reply are design calls it made for you. Read them before running tests, not after.
