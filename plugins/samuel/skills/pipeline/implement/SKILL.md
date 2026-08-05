---
name: implement
description: Execute a self-contained Executor Plan step-by-step with human verification between phases, keeping a living Implementation Notes journal. Use when ready to implement a planned item.
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git status *) Bash(git add *) Bash(git commit *) Bash(gh *) Bash(backlog *) Bash(awk *) Bash(test *) mcp__backlog__task_list mcp__backlog__task_view mcp__backlog__task_edit mcp__backlog__task_search Read Edit Write Agent AskUserQuestion
---

# Implement Plan

Execute the **Executor Plan** for the active item, step by step, with human verification between phases. The plan lives in the Issue body; the **journal is a committed file**.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.
> **Autonomy:** which gates below auto-advance, and what gets recorded instead of asked — `../../../reference/autonomy.md`. An **unattended** run — headless `claude -p`, CI, or `/samuel:conductor` — is `autonomous` and ignores the `Autonomy:` value in Context.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Autonomy: !`awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)exit 1}' .claude/samuel.md 2>/dev/null || awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)print"interactive"}' ~/.claude/samuel.md 2>/dev/null || echo "interactive"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- Constitution: !`test -f CONSTITUTION.md && echo "present" || echo "none"`

> **Tracker**: `../../../reference/tracker.md`. **Adapter**: `../../../reference/github-operations.md`. **Journal**: `../../../reference/implementation-notes.md` (a committed file). **State**: `../../../reference/task-context.md`.

## Step 0: Load the plan, open the journal, set phase

1. **Load the Executor Plan** for the item: `gh issue view {item} -R {repo} --json body,title` → parse the `<!-- samuel:plan -->` section (Steps, guardrails, validation, DoD) and the `<!-- samuel:brief -->` AC.
2. **Set phase**: edit `.claude/task-context.md` → `phase: implement`, `last_updated: {today}`.
3. **Read `CONSTITUTION.md`** if present — a MUST violation is a hard STOP (record a decision + `V-NNN`).
4. **Open the journal** at `{feature_dir}/implementation-notes.md` (create the dir if needed). `Write` the stub from `../../../reference/implementation-notes.md`. Plain file — **no backlog doc, no two-call dance**. Populate D/V/T/Q **proactively** as you work.

## Step 1: Present the execution plan

Show the ordered inline plan Steps with status, then:

```
Plan for {item} — {title}

Steps:
- ⏳ Step 1: {title}
- ⏳ Step 2: {title} (depends on Step 1)

1) Execute all steps sequentially   2) A specific step
Proceed? (Y/N)
```

**WAIT.** (Conductor: proceed with option 1.) (attended-auto: proceed with option 1, announcing it in one line; no journal entry — executing the agreed plan is not a decision, and Step 0 has already opened a journal that would otherwise fill with them (`../../../reference/autonomy.md` § Recording contract).)

> Big plan? At your discretion, dissect the Steps into local backlog subtasks for dependency ordering and local ticks — `../../../reference/backlog-operations.md` (derivable, disposable, read back by nobody).

## Step 2: Sequential execution with phase pauses

For each Step in order (skip any with an unmet dependency → blocked list):

**a. Implement** the change described — exact files, following the plan's Guardrails. Comments you write are **timeless**: they state a constraint the code can't show, never the narrative of this change (taxonomy + examples: `../../../reference/code-comments.md`). Stay inside the plan; if reality diverges, go to (e).

**b. Verify** the Step's automated check. Run it; capture output.

**c. Track acceptance criteria** as outcomes are met: flip the matching Brief AC `- [ ]`→`- [x]` (fetch body → splice → `gh issue edit --body-file`). Optionally `gh issue comment` a short progress note for big steps.

**d. Journal**: append any `D/V/T/Q` surfaced this step to `{feature_dir}/implementation-notes.md` with their fields — `D`/`V` entries also carry `Affects` (issues outside this one the entry constrains, or `none`; a non-`none` value triggers e.1); re-render the counter line. Keep it append-only (supersede via `Status`, never renumber). When the re-rendered counter shows **open `Q-NNN` ≥ 3**, suggest pausing for `/samuel:find-unknowns` (audit) before the next phase — questions accumulating faster than they resolve is a map-quality signal, not bookkeeping. A suggestion only; per-entry `Blocking: yes` remains the sole gate.

**e. Plan-reality mismatch → HARD STOP.** If the plan doesn't match the codebase:

```
PLAN-REALITY MISMATCH
Expected (plan): {…}
Found (codebase): {…}
Impact: {…}
1) Update plan to match, then continue   2) Discuss   3) Abort & re-plan
```

**Do NOT improvise around it.** Before option 3 (re-plan), consider `/samuel:find-unknowns` (audit) first — a mismatch is evidence the map is stale, and a plan rewritten from the same map inherits the same blind spot. On resolution, record a decision (`gh issue comment`) **and** a `V-NNN` in the journal with `Linked decision`. If the decision is **durable/architectural** (constrains future work, not just this task), write an ADR `docs/decisions/NNNN-slug.md` on the branch instead of only a comment — see `../../../reference/github-operations.md` (Decisions — three levels). (Conductor: choose the conservative option, record it, continue; if `Blocking: yes`, stop and hand off.)

**e.1. Assess the blast radius (after any recorded decision):**

A decision recorded in (e) — or any journal `D`/`V` entry whose `Affects` is not `none` — may constrain work **outside this Issue**: sibling sub-issues under the same parent, or issues that declare `Depends on:` the current one. Discover the affected set (parent → siblings → dependents recipes: `../../../reference/github-operations.md` § Blast radius), read each candidate's Brief + Executor Plan, and classify: unaffected · aware (comment only) · invalidated (comment + label).

Present the impact map:

```
BLAST RADIUS — decision {V-NNN · comment URL / ADR}

- #45 {title} — INVALIDATED: {what no longer holds} → comment + demote ready→planned
- #46 {title} — aware: {context change} → comment only
- #47 {title} — unaffected

Post these updates? (Y/N/Edit)
```

**WAIT for approval.** Then post one `Upstream decision` comment per affected issue and apply the label rules (§ Blast radius), record the outcome on the journal entry's `Affects` line (e.g. `#45 (commented, demoted), #46 (commented)`), and suggest `/samuel:refine-plan {affected issue}` for each invalidated plan — never edit another issue's plan from here.

No parent and no dependents → note "blast radius: none" on the journal entry and move on. (Conductor: **never post to other issues unattended** — fold the impact map into the handoff/stop report; the human posts after review.)

**f. Commit the step** (when the run has commit authority — interactive user-approved, `attended-auto`, or autonomous; a local commit is not an outward action). `../../git/create-atomic-commit` is cited for the message convention, not dispatched as a gate — commit inline here with `git add`/`git commit`, so that skill's own confirmation is never rendered from this path: an atomic conventional commit (`../../git/create-atomic-commit`). Include the journal file. Never push / open a PR here.

**g. PAUSE for human verification** at each phase boundary:

```
Phase {N} complete.
Automated: {PASS/FAIL + details}   ·   AC: {n}/{total}
Manual checks:
- [ ] {from plan}
Continue to Phase {N+1}? (Y/N)
```

**WAIT.** (Conductor: continue, recording assumptions; FIC between phases.) (attended-auto: print the block, then continue — the phase summary IS the announcement, so state the unchecked manual items rather than dropping them. A red automated check is a hard stop at every level; FIC between phases still applies.)

## Step 3: Completion

When all Steps are done:

```
All steps complete for {item}.
AC: {n}/{total}   ·   Journal: D:n V:n T:n Q:{open}

NEXT (mandatory): /samuel:validate
```

## Context Management (FIC)

Monitor context after each phase. At high usage: run `/samuel:session-handoff create`, STOP, and recommend resuming in a fresh session. The journal + commits make resume clean. Never let degrading context produce sloppy code.

## Important Guidelines

1. **Plan is the contract** — the Issue's Executor Plan.
2. **Respect dependencies** — never run a Step with unmet deps.
3. **Pause between phases** for human verification (except under the conductor, or `attended-auto`, which prints the phase block and continues — `../../../reference/autonomy.md` § Which gates move). A red automated check is a hard stop at every level.
4. **STOP on mismatch** — never silently work around it.
5. **Journal proactively** — capture sub-threshold choices as they happen, not retroactively.
6. **Mandatory validation** after all steps.
7. **Declared e2e tier is a Step, not polish** — if the plan's Validation section carries an `**e2e tier:**` line, authoring or updating that journey is one of the Steps to execute, not optional follow-up.
8. **Blast radius before moving on** — a recorded decision isn't closed until its cross-issue impact is assessed (e.1); cross-issue comments always get a checkpoint.

## Gotchas

_Add a line each time Claude trips on something._

- The journal is a **plain committed file** (`{feature_dir}/implementation-notes.md`) — Write/Edit it directly.
- There is no per-step "Done" status — progress is the AC checkboxes + journal. The work item closes via the PR's `Closes #N`, not here.
- Checking an AC replaces the whole Issue body — re-emit both marker sections.
- Plan-reality mismatch is a HARD STOP. Surface it; record the resolution as a decision + `V-NNN`.
- A retroactive journal misses the small choices it exists to capture. Populate during the phase.
- FIC happens BETWEEN phases, never mid-phase. Finish the current phase first.
- **A decision's blast radius is part of recording it** (e.1) — unexamined cross-issue impact is how dependent issues execute stale plans. Cross-issue comments always get a checkpoint; the conductor never posts them (impact map goes to the handoff).
