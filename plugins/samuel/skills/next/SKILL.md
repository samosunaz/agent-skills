---
name: next
description: "Pull the next prioritized work item (GitHub Issues). Trigger on 'next', 'next task', 'qué sigue', 'pull task'."
allowed-tools: Bash(gh *) Bash(git branch *) Bash(awk *) Read AskUserQuestion
---

# Next Item

Pull the next prioritized work item from GitHub Issues (the "ready list").

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
> **Autonomy:** which gates below auto-advance, and what gets announced instead of asked — `../../reference/autonomy.md`. An **unattended** run — headless `claude -p`, CI, or `/samuel:conductor` — is `autonomous` and ignores the `Autonomy:` value in Context.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Autonomy: !`awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)exit 1}' .claude/samuel.md 2>/dev/null || awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)print"interactive"}' ~/.claude/samuel.md 2>/dev/null || echo "interactive"`
- Ready issues: !`gh issue list --state open --label "pipeline:ready" --json number,title,labels --jq 'sort_by(.number)' 2>/dev/null || echo "n/a"`
- Planned issues: !`gh issue list --state open --label "pipeline:planned" --json number,title,labels 2>/dev/null || echo "n/a"`
- In-progress issues: !`gh issue list --state open --label "pipeline:in-progress" --json number,title 2>/dev/null || echo "n/a"`
- Roadmap now: !`gh issue list --state open --label "roadmap:now" --json number,title 2>/dev/null || echo "n/a"`

> **Tracker**: `../../reference/tracker.md`. Adapter: `../../reference/github-operations.md`.

## Process

If `gh issue list` returned `n/a`, the repo default isn't set — tell the user to run `gh repo set-default owner/name` (or `/samuel:start-task` once).

### 1) Check work in progress

If in-progress items exist:

```
You have {N} item(s) in progress:
{list}
Continue one of these, or pull a new one?
```

**WAIT.** To continue, route to `/samuel:start-task {item}`.

### 2) Present available work

From the ready/planned list, sort by:
1. Priority (high → medium → low)
2. Unblocked first (no open dependency)
3. Group related items (same feature/epic)

```
Available work:

1. #{item} — {title}  ({priority})  [{status: ready|planned|triage}]
2. #{item} — {title}  ({priority})

Which one?
```

> Prefer `pipeline:ready` (planned + unblocked); `pipeline:planned` items still need an unmet dep resolved; `pipeline:triage` items have no plan yet (route through `/samuel:plan`). Surface the status so the user knows.

If only one is available, still confirm. (attended-auto: pull it without asking, and open the response by naming what was pulled and that it was the only candidate. The rule above exists so the skill never picks in silence — announcing satisfies that; skipping the announcement does not. With more than one candidate the menu still renders at every level, because there is no obvious default to take.)

### 3) On selection

1. Confirm: `Picking: {item} — {title}`
2. Route to `/samuel:start-task {item}`.

## Edge Cases

- **Empty / nothing ready** → if `roadmap:now` bets exist (Context above), surface them and offer to **promote** one into delivery: `gh issue edit {n} --add-label pipeline:triage --remove-label "roadmap:now"`, expand its `## Opportunity` into a `## Brief`, then `/samuel:plan {n}`. Otherwise offer `/samuel:roadmap` (decide what to build next), `/samuel:plan` (plan a triage item), `/samuel:kickoff` (new project), or capture a new item (`gh issue create`).
- **All done** → `/samuel:validate` pending? `/samuel:progress`? plan the next phase?
- **All blocked** → list each item and its open blocker; offer to work the dependency first.

## Rules

- **No auto-assignment.** Always show options and let the user choose.
- **Context awareness.** Show in-progress items before offering new ones.
- **Dependency respect.** Never offer an item with an open dependency.
- **Priority first.** High priority always on top.

## Gotchas

_Add a line each time Claude trips on something._

- `gh issue list` without `-R` needs `gh repo set-default` to have run. `n/a` in Context = not configured, not "no work".
- Dependencies are item ids — verify the actual id, not a phase number.
