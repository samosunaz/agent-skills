---
name: bulk-read
description: "Delegate whole-file reads of large files to the cheap bulk-reader agent (haiku) and bring back only the answer. Fired by the shunt hook when a Read/cat exceeds the line limit; also use proactively before reading 2+ large files for one question. Trigger on 'bulk read', 'summarize these files', 'what does this file do', a denied Read with a shunt: message."
allowed-tools: Agent Grep Glob Read Bash(wc *)
---

# bulk-read

Most of what an agent does with a large file is I/O, not reasoning: it reads 800 lines to answer one question, and those lines then sit in the main context for the rest of the session. This skill moves that read to a cheap worker and keeps only the answer. The `shunt` hook (`hooks/hooks.json`) enforces it: a whole-file `Read`, `cat`, `less`, `more`, or `bat` on a text file over `SHUNT_MIN_LINES` (default 350) is denied with a pointer here. Targeted reads pass: `Read` with `offset`/`limit`, `sed -n`, `head -n`, `tail -n`, and any piped or chained command.

Worker: the plugin's `shunt:bulk-reader` agent (`agents/bulk-reader.md`, haiku, read-only tools). The corpus lands in the worker's context, which is discarded when it returns; only its bullets reach you.

## When to delegate

- **One question, many lines**: "what does this service do", "which endpoints exist", "where is X handled", "summarize the migration history". Read-only, answer-shaped.
- **2+ large files for one answer**: send them all in one delegation. Follow-up questions re-send the same paths; the corpus never enters this context, so the repeat costs only worker tokens.
- **Not**: debugging a subtle bug, an architectural call, a security or payments path, or anything you are about to edit. A cheap worker finds surface patterns and misses threading/ordering bugs. For an edit, `Grep` the symbol and `Read` with `offset`/`limit` around it.

## Process

### 1) Shape the question

One question, concrete, with the exact output you want back. Bad: "read these files". Good: "list every public method with its `file:line` and one-line purpose".

### 2) Delegate

Spawn `shunt:bulk-reader` with a self-contained English prompt:

```
Read: <path1>, <path2>
Answer: <the one question>
Output: structured bullets only, each fact cited as file:line.
```

Paths absolute, or relative to the session `cwd`. Expect one subagent round-trip, so a single 400-line file with a two-line answer is borderline: delegate when the alternative is the whole file in context, not when a `Grep` would do.

### 3) Verify before acting

Line numbers from a worker summary are hints, not facts: confirm with `Grep` or a targeted `Read` before editing at them. If the answer is thin or wrong, escalate instead of trusting it: re-run with the `Explore` agent or `samuel:implementation-analyzer` (sonnet), or read the region directly.

## Search gate

The same plugin gates searches (`scripts/check-search.sh`, matchers `Grep` and `Bash`): a **content-mode** search with **no bound** and **no scope narrower than the repo** is denied. Files-only (`files_with_matches`, `rg -l`), counts, `head_limit`/`-m`, a `glob`/`type`/`-g`/`-t`, a subdirectory path, or any pipe all pass. The order is the one ripgrep already supports: files first, then scope, then a bound, then context. An explicit `head_limit` is the deliberate override.

## Deliberate override

When the whole file is required (a diff under review, a config you must reproduce verbatim), `Read` with `offset=1` and `limit=<line count>`. That is the explicit override and it passes the gate. Per-session switches: `SHUNT_MIN_LINES=N` raises or lowers the limit, `SHUNT_DISABLE=1` turns the gate off, and `SHUNT_CLIENT=claude|codex` selects the vocabulary of the denial message — unset emits wording valid on either client. All three are environment variables of the agent process, not of a tool call.

## Gotchas

_Add a line each time Claude trips on something._

- Under auto mode the harness prefers `cat` over `Read`; both paths are gated, do not switch to `cat` to dodge a denied `Read`.
- The hook fails open: no `jq`, a binary file, or malformed input all allow the read. A silent gate is not proof the file was small.
- Hooks are session-wide: they fire inside subagents too. The script exempts `shunt:bulk-reader` and `shunt:code-writer` by `agent_type`; any other agent (`Explore`, `samuel:implementation-analyzer`) is gated like the main thread.
