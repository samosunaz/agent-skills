# Backlog as the Local Disector (optional)

Backlog.md is **not a tracker** (ADR 0002, `docs/decisions/0002-single-tracker-github.md`). It survives in the samuel pipeline as one thing only: an **optional, implement-time scratchpad** to dissect the Issue's Executor Plan into checkable local subtasks — in agent language, with dependency ordering and local ticks — when a plan is big enough to want them. The SoT stays in GitHub (`reference/tracker.md`).

**The litmus test: derivable and disposable.**
- *Derivable* — every subtask is a projection of a plan Step already in the Issue body. Nothing original lives here.
- *Disposable* — `backlog/` is gitignored; throw it away at close (or don't — it dies with the worktree). **Nobody reads it back**: not `validate`, not `done`, not a resuming session (resume reads the Issue body pointers + the committed journal, never local backlog state).

## When to use it

During `/samuel:implement`, at the agent's discretion: mirror the plan's Steps (or one fat Step's sub-work) into local subtasks, order them with `sequence list`, tick them as you go. Skip it entirely for small plans — the plan's inline Steps + the journal are usually enough.

## The op set

MCP preferred (`mcp__backlog__*`), CLI fallback (`which backlog` → `bun install -g backlog.md`). Only these operations are in scope:

| Operation | MCP Tool | CLI Command |
|---|---|---|
| Create subtask | `mcp__backlog__task_create` | `backlog task create "title" --flags` |
| Edit / tick | `mcp__backlog__task_edit` | `backlog task edit [id] --status "Done"` |
| View | `mcp__backlog__task_view` | `backlog task [id] --plain` |
| List | `mcp__backlog__task_list` | `backlog task list --plain` |
| Execution order | N/A | `backlog sequence list --plain` |
| Draft (raw idea parking) | N/A | `backlog draft create "title"` · `promote` · `archive` |

Useful create flags: `--description`, `--priority`, `--status`, `--parent`, `--depends-on` (comma-separated), `--ac` (repeatable). Edit flags: `--status`, `--check-ac [index]` (1-based), `--append-notes`. Status values are case-sensitive: `"To Do"`, `"In Progress"`, `"Done"`.

### Example — dissect a plan Step

```bash
backlog task create "Step 3: rewire validate reviewer injection" \
  --description "Plan Step 3 of Issue #42 — REVIEW.md into the adversarial prompt" \
  --status "To Do" --depends-on 2 \
  --ac "reviewer prompt contains REVIEW.md body"
backlog sequence list --plain     # dependency-ordered execution view
backlog task edit 3 --status "Done" --check-ac 1
```

## What backlog is NOT for (the NOT-list)

- **No backlog docs. Ever.** Plans live in the Issue body; research/spec/journal/validation are **committed files** in `feature_dir` (`docs/features/<slug>/`). A skill writing any artifact via `backlog doc` is wrong.
- **No decisions.** Task-level decisions are Issue comments; durable ones are ADRs (`docs/decisions/`). `backlog decision` is out.
- **No milestones, no DoD defaults, no overview/board reporting.** Those are tracker features; the tracker is GitHub.
- **No cross-session state.** Never read backlog to answer "where was I" — that is the Issue body (pointers, checkboxes) + the committed journal.
- **No external surface.** Nothing here is visible outside the worktree; never cite a backlog id in an Issue, PR, or journal entry.

## Gotchas

_Add a line each time Claude trips on something._

- `backlog task update` does not exist — use `backlog task edit [id] --status "Done"`.
- Status values are case-sensitive: `"To Do"`, `"In Progress"`, `"Done"`.
- Requires an initialized `backlog/` (`backlog init` once per worktree). If missing and you still want the disector, init it; it's gitignored either way.
- Backlog filenames contain spaces (`task-N - Title.md`). macOS BSD `xargs` has no `-d` — always use `find -print0 | xargs -0`.
