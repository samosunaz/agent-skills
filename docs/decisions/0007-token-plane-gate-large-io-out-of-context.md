# 7. A token plane: gate large-file I/O out of the frontier context

Date: 2026-09-08
Status: Accepted
Source: engineering.atspotify.com, "Portal by Spotify cut my Claude Code token usage by 90%" (sep 2026)

## Context

Most of what a coding agent does with a large file is I/O, not reasoning: it reads 800 lines to answer one question, and those lines then occupy the frontier context for the rest of the session. Spotify measured the pattern on a Java monorepo and moved it to a cheap worker behind three layers: a `PreToolUse` hook that denies whole-file reads over 350 lines, a script that ships the files to the worker, and a skill that says when to call it. They report ~90% fewer tokens on the read scenarios they measured, not on the session total.

This repo's CLAUDE.md already asks for subagents on broad exploration. It is advice, not enforcement: no plugin here had a hook, and the harness's own auto-mode guidance pushes `cat` over `Read`, so a 700-line reference spoke still lands in context whenever the model finds it convenient.

## Decision

A new plugin, `plugins/shunt/`, is the **token plane**: orthogonal to delivery (`samuel:`), it controls what enters the frontier context.

1. **Enforcement is a Claude Code plugin hook**, `hooks/hooks.json` → `scripts/check-read.sh`, on `Read` and `Bash`. A whole-file `Read` (no `offset`/`limit`) or a bare `cat`/`less`/`more`/`bat` on a text file over `SHUNT_MIN_LINES` (default 350) is denied with a message that names the three exits: delegate the question, read a targeted range, or override deliberately with `offset=1 limit=<n>`.
2. **The workers are plugin agents on cheap Claude models**: `bulk-reader` (haiku, read-only tools, structured bullets with `file:line`, refuses debugging and design) and `code-writer` (sonnet, `Write` on one target file from one reference file). The worker is a subagent, not an external engine; the corpus lives in the subagent's context and is discarded on return.
3. **The gate fails open.** No `jq`, a binary file, a piped or chained command, a range reader (`sed -n`, `head -n`, `tail -n`), or unparseable input all allow. A gate that blocks legitimate work under uncertainty gets disabled; one that only bites the unambiguous case stays on.
4. **Searches are gated on output shape, not speed.** `scripts/check-search.sh` denies a content-mode `Grep`/`rg`/`grep`/`git grep` that has no bound (`head_limit`, `-m`) and no scope (glob, type, subdirectory) across the whole repo; files-only, count, piped, bounded, and scoped forms pass. Search speed was never the cost: ripgrep answers a few-thousand-file repo in milliseconds, and a faster index returns the same lines. The cost is every matching line entering context, so the flag discipline the gate enforces is files first, then scope, then a bound, then context.
5. **Two skills carry the how**: `shunt:bulk-read` (one closed question, structured bullets with `file:line` back, never for debugging/architecture/safety paths or the region about to be edited) and `shunt:code-write` (pattern-following generation from a **mandatory** reference file, output to disk, verified via `git diff` + the verify contract).
6. **The Codex manifest ships the skills only.** Codex has neither hooks nor agents; the plane is a Claude Code feature and the `.codex-plugin` manifest exists for repo-convention parity.

## Consequences

- A whole-file read over the limit now costs one extra turn (the denial) before the model picks an exit. `SHUNT_DISABLE=1` on the `claude` process removes it for a session; `SHUNT_MIN_LINES` tunes it.
- Worker summaries carry no reliable line numbers and miss subtle bugs (Spotify's own limits, reproduced in the skill). Editing and debugging still read directly, in ranges. The saving is on answer-shaped reads, not on everything.
- Each delegation is a subagent round-trip. A single borderline file with a two-line answer is a bad trade; `Grep` first.
- Hooks are session-wide and fire inside subagents (verified on Claude Code 2.1.266: the hook input carries `agent_type`). The script exempts the two workers by name; every other agent is gated like the main thread, which is the intent: an `Explore` that swallows 800 lines pays the same as the main model does.
- Every denial (read or search) appends one line (`date, tool, agent, lines|search, target`) to `~/.claude/plugin-data/shunt/denials.log` (`SHUNT_LOG` overrides). That log is the measurement.
- The plane does not touch the fixed per-session cost: this repo's CLAUDE.md, skill hubs above the ~100-line guideline, and the largest reference spokes. That is the next lever and a separate decision.
- The 90% is Spotify's number on Spotify's corpus. Two weeks of the denial log, plus the token size of the shunted reads, gives ours.
