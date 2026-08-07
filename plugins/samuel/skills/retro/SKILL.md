---
name: retro
description: "Personal retrospective: analyze what worked, what didn't, and what to change, from GitHub + git history. Trigger on 'retro', 'retrospective', 'lessons learned'."
allowed-tools: Bash(gh *) Bash(git log *) Bash(git diff *) Bash(git branch *) Bash(awk *) Bash(date *) Read Write AskUserQuestion
---

# Personal Retrospective

Analyze recent work through **GitHub** + git history. Structured self-reflection to improve your process.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Context

- Closed issues: !`gh issue list --state closed -L 50 --json number,title,closedAt,labels 2>/dev/null || echo "n/a"`
- Merged PRs: !`gh pr list --state merged -L 50 --json number,title,mergedAt 2>/dev/null || echo "n/a"`
- Commits (14 days): !`git log --oneline --since="14 days ago" 2>/dev/null || echo ""`
- Branches: !`git branch --list 2>/dev/null || echo ""`
- Today: !`date '+%Y-%m-%d'`

> **Tracker**: `../../reference/tracker.md`.

## Process

### 1) Gather data

Closed issues + merged PRs in the period (filter by `closedAt`/`mergedAt`), open-but-stale items, commit cadence.

If history is thin, ask the user what period to reflect on and what they worked on.

### 2) Analysis

- **Velocity** — items completed; started-but-unfinished; ratio; AC checked (from Issue body checkboxes).
- **Scope** — planned vs added vs dropped; scope-creep assessment.
- **Work patterns** — most active days, session lengths (commit timestamps), handoffs created (deep-session signal), draft PRs that sat unreviewed.

### 3) Reflection prompts

Present and **WAIT for each** (skippable):

```
1. What went well? A decision/approach you're glad you took.
2. What was harder than expected? Where did complexity surprise you?
3. What would you do differently in approach?
4. What blocked you? Technical and non-technical (energy, time, clarity).
5. What to change next sprint/week?
```

### 4) Generate the retro document

Combine data + reflections into:

```markdown
# Retro: {date range}
**Date**: {today}

## Numbers
- Completed: {n}   ·   In progress: {n}   ·   Completion: {%}
- Commits: {n} over {days} days   ·   Scope changes: {+added / -dropped}
- AC checked: {checked}/{total} (from Issue body checkboxes)

## What Went Well
{user answer + data evidence}

## What Was Hard
{user answer + detected patterns}

## What To Change
{concrete, actionable}

## Action Items
- [ ] {specific change for next period}
```

**Save it:**
A committed file `docs/retros/{date}.md` (`Write`). Optionally open a tracking issue labelled `type:chore` if an action item needs follow-up.

### 5) Present summary

```
Retro saved: {path}
- {n} completed, {n} in progress
- Went well: {1 line}   ·   To improve: {1 line}
- Main action item: {the most important one}
```

## Rules

- **No judgment** — self-reflection, not self-criticism.
- **Data-informed, not data-driven** — numbers tell part; the user's feelings tell the rest.
- **Actionable** — every retro produces ≥1 concrete action item.
- **Respect energy** — keep it light if the user doesn't want depth.
- **Save for continuity** — the retro builds a history of learnings.

## Gotchas

_Add a line each time Claude trips on something._

- Filter closed issues / merged PRs by date client-side from the JSON `closedAt`/`mergedAt`.
- Surface draft PRs that sat unreviewed — a real process signal for a solo/autonomous workflow.
