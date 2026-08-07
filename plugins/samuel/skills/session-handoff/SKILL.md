---
name: session-handoff
description: Create or resume handoff documents for context compaction between sessions. Use when context is large, switching sessions, or resuming previous work.
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git status *) Bash(git merge-base *) Bash(gh *) Bash(awk *) Bash(printf *) Read Write AskUserQuestion
---

# Session Handoff

Create or resume handoff documents for Frequent Intentional Compaction (FIC) — a committed file. Enables seamless continuation across sessions (including headless/cloud) without losing context.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
> **Autonomy:** which gates below auto-advance, and what gets announced instead of asked — `../../reference/autonomy.md`. An **unattended** run — headless `claude -p`, CI, or `/samuel:conductor` — is `autonomous` and ignores the `Autonomy:` value in Context.

## Modes

```
/samuel:session-handoff create                  — create handoff from current session
/samuel:session-handoff create TASK-123         — create handoff for specific task
/samuel:session-handoff resume DOC-003          — resume from handoff document
/samuel:session-handoff resume "feature name"   — search and resume by keyword
/samuel:session-handoff resume                  — list recent handoffs and pick one
```

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Autonomy: !`awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)exit 1}' .claude/samuel.md 2>/dev/null || awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)print"interactive"}' ~/.claude/samuel.md 2>/dev/null || echo "interactive"`
- Commits since main: !`git log --oneline origin/main..HEAD 2>/dev/null || echo "No commits"`
- Files changed: !`git diff --stat origin/main..HEAD 2>/dev/null || echo ""`
- Git status: !`git status --porcelain 2>/dev/null || echo ""`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Phase: !`awk '/^phase:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_PHASE"}' .claude/task-context.md 2>/dev/null || echo "NO_PHASE"`

> **Tracker**: `../../reference/tracker.md`. The handoff persists as a committed file `{feature_dir}/handoff-{phase}.md`.
> **Pipeline state**: `../../reference/task-context.md`. Inside a flow feature, the handoff MUST capture the current `phase` and the status of every feature-dir artifact (spec, research, plan, implementation-notes journal, validation) so a fresh session can resume from the exact pipeline point. Note the journal's open questions and `living/sealed` status explicitly.

---

# CREATE HANDOFF

## When to Create

- Context is getting large and response quality may degrade
- `/samuel:implement` completes a phase and you want a clean break
- User explicitly requests a handoff
- Switching to a different task/session

## Step 1: Gather Current State

### Identify current task

If a task ID provided as parameter, use it. Otherwise, resolve the active item from `.claude/task-context.md` (`item`).

### Categorize progress (from the Executor Plan's Steps)

- **Completed**: Steps already closed
- **Current**: the Step in progress
- **Remaining**: everything else

## Step 2: Extract Key Information

### From completed tasks

For each completed task, extract:
- Key file changes (from git or task notes)
- Decisions made
- Patterns discovered

### From current task (if in progress)

- What's been done vs what remains
- Any blockers or open questions
- Relevant file:line references

### From plan document

Load the Executor Plan section from the Issue body (`gh issue view {item} --json body`).

### From git

Commits and file stats are available in Context above.

### From project stats

Read the Acceptance Criteria checkboxes from the Issue body (`gh issue view {item} --json body`) for completion stats. Include in the handoff Progress Summary.

## Step 3: Create the handoff document

Persist the handoff so the next (possibly headless) session reads it on the branch:

A committed file `{feature_dir}/handoff-{phase}.md` (`Write`), committed on the feature branch. The resume path is the file.

**Document structure:**

```markdown
# Handoff: [Feature Name]

**Parent Task**: [parent-id] - [parent-title]
**Current Task**: [current-id] - [current-title]
**Created**: [ISO timestamp]
**Plan Doc**: [plan-doc-id]

## Progress Summary

- Total phases: [N]
- Completed: [X]
- Current: [task-title] (in progress / blocked)
- Remaining: [Y]

## Completed Phases

### [TASK-ID]: [Title] — Done

**Key Changes**:
- `file:line` — [brief description]

**Notes**: [relevant implementation notes]

## Current Task

**Task**: [current-id] - [title]
**Status**: In Progress

**What's Done**:
- [completed work items]

**What Remains**:
- [remaining work items]

**Blockers** (if any):
- [blocker description]

## Remaining Tasks

- [ ] [TASK-ID]: [title]
- [ ] [TASK-ID]: [title] (depends on [TASK-X])

## Key Learnings

**Technical Discoveries**:
- [pattern found at file:line]

**Decisions Made**:
- [decision]: [rationale]

**Issues Encountered**:
- [problem]: [resolution]

## Files Modified

- `path/to/file.ts` — [what changed]

## How to Resume

Option 1 — Continue current task:
  /samuel:session-handoff resume [this-doc-id]

Option 2 — Start next task:
  /samuel:implement [next-task-id]

Option 3 — Implement all remaining:
  /samuel:implement [parent-task-id]
```

## Step 4: Link to Parent Item

```bash
gh issue comment [item-number] --body "Handoff created: [handoff-path] on [date]. Resume with: /samuel:session-handoff resume [handoff-path]"
```

## Step 5: Present to User

```
Handoff created.

Document: [doc-id]
Progress: [X]/[N] phases completed
Current:  [current-task-title]
Remaining: [Y] phases

To resume in a new session:
  /samuel:session-handoff resume [doc-id]

Recommendation: start a new session for a clean context.
```

---

# RESUME HANDOFF

## Step 1: Find and Load Handoff

### If doc ID provided:

Load the document directly.

### If keyword provided:

Search committed handoff files under `docs/features/*/handoff-*.md` (Grep/Glob) for the keyword.

Filter results for matching handoffs. If multiple, present list. If one, load it.

### If no parameter:

Glob `docs/features/*/handoff-*.md`, present the list of available handoffs.

## Step 2: Verify Current State

Don't assume the handoff state is current. Use "All tasks", "Commits since main", and "Git status" from Context above to compare:
- Are completed tasks still Done?
- Did the current task status change?
- Were there commits after the handoff?

## Step 3: Present Status and Options

```
Resuming from handoff [doc-id] (created [date])

Progress:
  Completed: [X] phases
  Current:   [task-title] ([status])
  Remaining: [Y] phases

Changes since handoff:
  [any new commits or status changes, or "none"]

Key learnings from previous session:
  - [learning 1]
  - [learning 2]

Options:
  1. Continue current task: [current-task-id] - [title]
  2. Next available task: [next-task-id] - [title]
  3. Run all remaining: /samuel:implement [parent-task-id]
  4. Review plan first

How do you want to proceed?
```

**WAIT for user choice.** (attended-auto: take option 1 — continue the current task — and say which task and which handoff it resumed from. Resuming is what `resume` was invoked to do; the menu exists for the times that assumption is wrong, and naming the task is what lets the reader catch it. If the handoff's task is already closed, or option 1 cannot be resolved, fall back to asking: an unresolvable resume is a stale map, not an obvious default.)

## Step 4: Execute User Choice

Route to the appropriate action based on user selection.

---

## Error Handling

### Handoff not found

```
No handoff found for [id/keyword].

Available handoffs:
[list from docs/features/*/handoff-*.md]

Provide the exact path or search by keyword.
```

### Task state mismatch

```
Task state changed since the handoff:

Handoff said: [task-id] was [status]
Current state: [task-id] is [different-status]

This may indicate work in another session or manual changes.
Proceeding with current state.
```

---

## Guidelines

1. **Conciseness**: Include key information only. Reference files with `file:line`, not code blocks.
2. **Actionability**: Clear resume instructions with specific task IDs and commands.
3. **Context preservation**: Capture decisions, patterns, constraints, and blockers.
4. **Verify before assuming**: Always check current task state, don't trust handoff blindly.
5. **GitHub is the state surface**: items, decisions, and progress live in GitHub Issues, labels, and PRs; the journal and handoff are committed files in the worktree.

## Gotchas

_Add a line each time Claude trips on something._

- Handoff doc must be self-contained — the resuming session has zero context from this one.
- Always verify task state on resume — don't trust handoff blindly. Commits may have happened between sessions.

## Pipeline Integration

```
/samuel:plan → /samuel:implement → [handoff] → [new session] → /samuel:session-handoff resume → /samuel:implement → /samuel:validate → /samuel:done
```

Handoffs are natural breakpoints in the implementation flow. They happen between phases or when context gets large.
