---
name: debrief
description: "Report the outcome of work that already landed — what it achieved in the owner's terms, whether any of it is visible and where to look, what was measured, and what comes next in the epic. Reads merged PRs and their issues; writes nothing. Trigger on 'debrief', 'what did we gain with this wave', 'tldr of what we shipped', 'is there a visual change', 'what is next in this epic'."
allowed-tools: Bash(gh *) Bash(git branch *) Bash(date *) Read
---

# Debrief — What Landed, What Shows, What Follows

After a wave, an epic slice or a merged PR the owner asks the same three questions in one breath: what did this actually achieve, is any of it visible and where do I look, and what comes next here. Measured over 30 days, that exchange ran in **41 of 109 sessions across 102 turns** — every time re-stating the scope and re-asking the visual question, because a plain summary answers the first and leaves the other two to a second prompt.

This skill answers all three in one fixed shape, from evidence. A PR is read through its diff and its issue's acceptance criteria, never through its title: the title is the claim, the diff is the fact. Nothing is written, posted or started — no comment, no label, no dev server, no capture.

**Boundary.** `/samuel:tldr` is the prose standard this output must already satisfy, not a results report — invoking it bare is what forced the owner to re-frame the question by hand every time. `/samuel:progress` is the dashboard of **open** work; `/samuel:retro` judges **how** the work went; `/samuel:done` closes one item and records what it left behind. `debrief` reports the **outcome** of work that already landed, and changes nothing.

## Mode

```
/samuel:debrief                  — merged since the previous debrief of this session; none → last 24 h on the default branch
/samuel:debrief 101 102          — these PR numbers
/samuel:debrief epic 77          — an epic issue: its task list / sub-issues and their PRs
/samuel:debrief wave             — the most recent wave run, read off the rolling run-log issue
/samuel:debrief --since 2026-01-30   — everything merged on or after that date
```

This skill leaves no marker of its own, so "since the previous debrief" is a fact of **this session only**. In a fresh session, fall back to 24 h and say which rule resolved the scope.

## Context

- Default branch: !`gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || echo "NO_REPO"`
- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Recently merged PRs: !`gh pr list --state merged -L 20 --json number,title,mergedAt,url 2>/dev/null || echo "NO_MERGED_PRS"`
- Still open as drafts: !`gh pr list --draft -L 20 --json number,title 2>/dev/null || echo "NO_DRAFTS"`
- Run-log issue: !`gh issue list --label conductor:log --state open -L 1 --json number,title 2>/dev/null || echo "NO_RUN_LOG"`
- Today: !`date +%Y-%m-%d`

## Process

1. **SCOPE — resolve it, then print it.** Turn the argument into an explicit set of merged PRs plus the issues they link (`Closes` / `Part of`): the epic's task list or sub-issues for `epic`, the last run report on the rolling `conductor:log` issue for `wave` (`../../reference/automated-trigger.md` § The run report). **The resolved list is the first line of the answer** — number, title, state. A PR that is not merged goes under `Not landed`; it is never described as done.
2. **READ THE CHANGE, NOT THE STORY.** Per PR: the diff stat and the acceptance criteria of the issue it closes. Classify each change as **user-visible** (something renders differently), **behavioural but invisible** (a rule, a guard, a contract) or **internal** (refactor, tests, tooling, docs). The files decide the class — not the title, not a worker's report.
3. **VISIBLE?** For every user-visible change, name exactly where to look — route, screen, component, generated output — and whether a before/after already exists (captures attached to the PR, capture paths in its comments). When none exists, say so and give the one command or path that would show it. Do not start a server and do not take captures: that is a separate request the owner makes in their own turn.
4. **MEASURED, OR UNMEASURED.** When the work claimed a number — bytes, timings, counts, deleted lines, issues closed — report the measured value with its source (check output, gate log, PR body, `gh pr view --json`). A claimed number with no measurement behind it is reported as **unmeasured**, never rounded into a fact.
5. **NEXT.** From the epic, the milestone and the dependency graph (`../../reference/github-operations.md` § Issue dependencies): which items this set unblocked, which remain and in what order. **Three ranked items, one sentence of reasoning on the first.** Keep the decisions waiting on the human separate — an unanswered question, a `Blocking: yes`, a draft PR nobody marked ready.
6. **OUTPUT — the fixed shape.** Lead with the single sentence that matters most, then these sections in this order, short:

```
{resolved scope: PR numbers + state}
{the one sentence}

Achieved      — 2-5 bullets, in the owner's terms, not the repo's
Visible       — where to look, or "nothing visible" in those words
Measured      — value + source; unmeasured said plainly
Not landed    — open, draft, reverted, dropped from scope
Next          — 3 ranked, reason on the first
Decisions waiting on you
```

The prose obeys `/samuel:tldr`. An empty section is one line, not a heading with an apology under it. When the change is structural — a pipeline, a data flow, a file layout — **one** small tree or Mermaid diagram (`/samuel:mermaid`) replaces the paragraph; never both. No restating the question, no closing summary.

## Gotchas

_Add a line each time Claude trips on something._

- **The three questions travel together.** Measured over 30 days: 41 of 109 sessions, 102 turns, always "what did we gain / is it visible / what's next". Answering one and waiting to be asked the other two is the failure this skill removes.
- **"Visible" is the question a plain summary skips.** An internal refactor reported with enthusiasm reads as progress the owner then cannot find on screen. "Nothing visible" is a complete and correct answer — say it in those words when it is true.
- **A PR title is testimony.** It says what the author set out to do, and a draft carries the same title as a merged PR. Read `state`, `mergedAt` and the diff before writing a verb in the past tense.
- **"Tests pass" in a sub-agent or worker report is a claim.** Quote the check state from the PR (`gh pr view --json statusCheckRollup`), never from the report that asked to be believed.
- **The scope phrase is ambiguous across parallel sessions.** "This wave", "the last thing" resolve differently in two checkouts of the same repo. Printing the resolved PR list first is what makes a wrong scope cost one glance instead of a whole wrong answer.
- **Do not pad `Next`.** Three ranked items and the reason for the first; the full inventory of open work is `/samuel:progress`, and a twenty-item list buries the one that matters.

## Rules

- **Read-only.** No comment, no label, no file, no branch, no server, no capture. Everything reported comes from `gh` and the repo.
- **Evidence or silence.** Every claim names its source; a gap is reported as a gap, not smoothed over.
