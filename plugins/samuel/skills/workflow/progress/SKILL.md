---
name: progress
description: "Personal progress dashboard: item status, velocity, and blockers from GitHub. Trigger on 'progress', 'progreso', 'dashboard', 'cómo vamos'."
allowed-tools: Bash(gh *) Bash(git log *) Bash(git branch *) Bash(awk *) Bash(date *) Read
---

# Progress Dashboard

Personal progress report from **GitHub** + git history. What's done, in progress, and coming up. One screen.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Open issues: !`gh issue list --state open -L 100 --json number,title,labels 2>/dev/null || echo "n/a"`
- Recently closed: !`gh issue list --state closed -L 20 --json number,title,closedAt 2>/dev/null || echo "n/a"`
- Open draft PRs: !`gh pr list --draft --json number,title 2>/dev/null || echo "n/a"`
- Recent commits (7 days): !`git log --oneline --since="7 days ago" 2>/dev/null || echo ""`
- Today: !`date '+%Y-%m-%d'`

> **Tracker**: `../../../reference/tracker.md`.

## Process

### 1) Status breakdown

Bucket open issues by `pipeline:*` label (triage / planned / ready / in-progress / in-review) + recently closed = done. Note open draft PRs (the autonomous output awaiting review).

```
## Dashboard — {project} ({date})

| Status | Count | Items |
|---|---|---|
| Done (recent) | {n} | {titles} |
| In review (draft PRs) | {n} | {#n titles} |
| In progress | {n} | {titles} |
| Ready / To Do | {n} | {titles} |
| Planned / Triage | {n} | {titles} |

Completion (recent): {done}/{total} ({pct}%)
{█ filled}{░ empty}
```

### 2) Feature / epic grouping

Group by feature label; show Done / In progress / To Do per group.

### 3) Recent activity (git)

From "Recent commits": count + key changes. If none in 7 days: "No recent commits — blocked, or on another project?"

### 4) Alerts

- Blocked items (open dependency) → name the blocker.
- WIP > 2 in progress → suggest closing one first.
- Draft PRs awaiting review → "{n} draft PRs ready for your review/merge."
- Nothing in progress but ready work exists → "Pull one: /samuel:next".

### 5) Recommended next step

One concrete action: continue an in-progress item · review a draft PR · `/samuel:next` · `/samuel:retro` if all done.

## Rules

- **Data-driven.** Only what's in the tracker and git. No assumptions.
- **Honest.** No activity is a data point, not a criticism.
- **Actionable.** End with a concrete next step. **Concise** — fits one screen.

## Gotchas

_Add a line each time Claude trips on something._

- `gh issue list` without `-R` needs `gh repo set-default`. `n/a` = not configured, not "no work".
- Draft PRs are the autonomous conductor's output — surface them prominently so they don't rot unreviewed.
