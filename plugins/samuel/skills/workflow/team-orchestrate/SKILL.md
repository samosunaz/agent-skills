---
name: team-orchestrate
description: "Orchestrate Claude Code agent teams (multi-session parallel agents with shared task list and inter-agent messaging) for code review, debugging with competing hypotheses, multi-module features, or multi-angle research. Use whenever the work has independent parallelizable streams, when teammates need to challenge each other's findings, or when the user mentions 'agent team', 'spawn teammates', 'swarm', 'parallel review', 'team mode', 'orquestar agentes'. Different from /samuel:codebase-documentation (single-session parallel subagents) — use this when teammates must communicate, persist across turns, or be addressed individually."
allowed-tools: Bash Read TeamCreate TeamDelete SendMessage TaskCreate TaskUpdate TaskList TaskGet AskUserQuestion
---

# Team Orchestrate

Coordinate a team of Claude Code sessions where each teammate is a full independent session that communicates with peers via shared task list and direct messaging. You play the role of **team lead**: diagnose, spawn, monitor, synthesize, cleanup.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- Claude Code version: !`claude --version 2>/dev/null || echo "unknown"`
- Agent teams flag: !`printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS 2>/dev/null || echo "0"`
- tmux installed: !`which tmux 2>/dev/null || echo "not_installed"`
- Inside tmux session: !`printenv TMUX >/dev/null 2>&1 && echo "yes" || echo "no"`
- Working tree: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO"`

## When to use this vs alternatives

Pick the right primitive — teams have real coordination overhead and ~4× token cost.

| Need | Use |
|---|---|
| One-shot codebase investigation, results summarized back | `/samuel:codebase-documentation` |
| Short focused query, throwaway worker | `Agent` tool (subagents) |
| Multiple independent streams, peer communication, persistent sessions, addressable teammates | **This skill** |

Do **not** spawn a team for: sequential work, same-file edits, single workstream, or routine tasks. The coordination cost will exceed the benefit.

## Step 1 — Prerequisites check

Before spawning anything, verify all four. If any fails, stop and tell the user how to fix.

| Check | Required | If missing |
|---|---|---|
| Claude Code version ≥ 2.1.32 | from Context above | `brew upgrade claude-code` |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | `1` in Context above | suggest `/update-config` to add it to `~/.claude/settings.json` under `env` |
| tmux installed | not `not_installed` | `brew install tmux` |
| Inside tmux session | `yes` in Context above | instruct: `tmux new -s team` then re-run from inside |

The tmux requirement matters because split-pane mode lets the user click into any teammate. In-process mode works without tmux but loses visibility — only fall back to it if the user explicitly asks.

## Step 2 — Diagnose and pick an archetype

Ask one question if intent is ambiguous: what is the user trying to accomplish? Then map to one of four archetypes. Read `references/archetypes.md` for full role definitions, file ownership rules, spawn prompt templates, and deliverables.

| Archetype | Trigger signals | Default size |
|---|---|---|
| `review-team` | "review this PR", parallel audit by dimension | 3 (security, performance, tests) |
| `debug-team` | ambiguous bug, multiple plausible causes, "investiga teorías" | 3-5 (one per hypothesis) |
| `feature-team` | cross-layer change (front + api + tests), independent modules | 2-4 (one per layer) |
| `research-team` | multi-angle exploration, library evaluation, "explora desde X ángulos" | 3-4 (one per lens) |

If none fits cleanly, ask the user to confirm a custom composition before spawning.

## Step 3 — File ownership map (anti-conflict)

Two teammates editing the same file = overwrites. Before spawning, define a clear ownership boundary and embed it in each spawn prompt:

- `feature-team` example: split by repo (`<frontend-repo>/**` vs `<api-repo>/**`) or by directory (`apps/web/**` vs `apps/api/**`). Tests teammate owns `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`.
- `review-team` is read-only by default — no conflicts possible. Skip ownership.
- `debug-team` is read-only during investigation; if any teammate proposes a fix, hand off to a single implementer afterward.

Print the ownership map for the user before spawning. If they push back, adjust.

## Step 4 — Spawn

Use `TeamCreate` to bootstrap, then spawn each teammate. Required ingredients per spawn prompt (teammates do **not** inherit your conversation history):

1. **Role and lens** — what perspective they own
2. **Files in scope** — explicit ownership boundary (paths or globs)
3. **Context bundle** — relevant facts, constraints, prior decisions
4. **Quality criteria** — what "good" looks like
5. **Reporting protocol** — `SendMessage` to `team-lead` with their findings using a fixed format
6. **Stop condition** — when they should mark their task complete

Reuse local subagent definitions when fit: `component-locator`, `implementation-analyzer`, `pattern-scanner`. Reference them by `subagent_type` in the spawn — definition body appends to system prompt.

For risky work (anything that writes files, modifies infra, or touches money flows), require **plan approval** when spawning. Teammate works in read-only plan mode until you approve.

## Step 5 — Monitor and steer

Common failure modes and what to do:

- **Lead implements instead of delegating** → tell yourself explicitly: "Wait for teammates. Do not write code yourself." Synthesize only.
- **Teammate stuck or silent** → message them directly. If unrecoverable, shut them down and spawn a replacement with a corrected prompt.
- **Task status stuck in_progress** → manually update via `TaskUpdate`.
- **Permission prompts pile up** → pre-approve common operations in `~/.claude/settings.json` before next spawn.

Periodically `TaskList` to check progress. Don't poll obsessively.

## Step 6 — Synthesize

When teammates report findings, you (the lead) own the synthesis. Cross-reference, surface contradictions, deduplicate, prioritize. Produce a single deliverable for the user. Each archetype has a default deliverable shape — see `references/archetypes.md`.

## Step 7 — Cleanup

Always run cleanup through the lead, never from a teammate.

1. Send `requestShutdown` to each teammate
2. Wait for `approveShutdown` confirmations
3. Verify no active members remain
4. `TeamDelete` to remove team resources

If `TeamDelete` fails: a teammate is still active. Find it, shut it down, retry.

## Quality gates via hooks (optional)

For high-stakes orchestration, configure hooks in `~/.claude/settings.json`:

- `TeammateIdle` — exit 2 to keep a teammate working when their output is incomplete
- `TaskCreated` — exit 2 to reject malformed task shape before creation
- `TaskCompleted` — exit 2 to reject deliverables that don't pass a check (e.g. missing test, no `file:line` reference)

Suggest hooks only when the user mentions reliability, automation, or repeated team workflows. Otherwise skip — adds complexity.

## Gotchas

_Add a line each time Claude trips on something._

- Teammates do NOT inherit the lead's conversation history. Always embed task-relevant context in the spawn prompt.
- File conflicts cascade silently — overwrites lose work. Always define and print the file ownership map before spawning.
- The lead drifts into implementing tasks itself instead of delegating. Remind yourself to wait and synthesize, never write code while teammates run.
- `~/.claude/teams/{team-name}/config.json` is runtime state. Never edit by hand — overwritten on next state update.
- `/resume` and `/rewind` do NOT restore in-process teammates. After resume, spawn fresh teammates rather than messaging the dead ones.
- Cleanup fails if teammates are still active. Always shutdown first, then `TeamDelete`.
- "Hallway testing" pattern: teammates produce code that passes tests but contains fallbacks like `// TODO: real impl, returning null for now`. Audit deliverables for stubs before declaring done.
- Validation is the bottleneck, not orchestration. A vague spec paralyzed across 5 teammates produces 5× the chaos. Sharpen the spec before spawning.
- Permission prompts multiply with team size. Pre-authorize common ops or accept that interactive approval will fragment your attention.
- `skills` and `mcpServers` from a subagent definition are NOT applied when used as a teammate — the teammate loads from project + user settings instead.
