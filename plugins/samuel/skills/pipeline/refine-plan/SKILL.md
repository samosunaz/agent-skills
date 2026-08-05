---
name: refine-plan
description: Iterate on an existing plan based on feedback. Surgical edits to the Executor Plan (Steps, scope, criteria, approach). Trigger on 'iterate plan', 'cambiar el plan', 'ajustar fases'.
allowed-tools: Bash(gh *) Bash(which *) Bash(git config *) Bash(awk *) Read Write Edit Agent ExitPlanMode AskUserQuestion
---

# Refine Plan

Update an existing plan based on feedback. The plan lives in the `<!-- samuel:plan -->` section of the Issue body. The refinement loop between `/samuel:plan` and `/samuel:implement`.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it, and gate plan approval with `ExitPlanMode`; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## CRITICAL RULES

1. **Surgical edits over rewrites.** Preserve good content. Change only what the feedback requires.
2. **Forced checkpoints.** Present understanding before editing. Never update without confirmation.
3. **No open questions.** If the change raises ambiguity, ask before updating.
4. **Keep it self-contained.** After editing, the Executor Plan must still pass the `plan-templates.md` litmus test — a fresh agent finishes it with no chat.

## Context

- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`

> **Tracker**: `../../../reference/tracker.md`. **Adapter**: `../../../reference/github-operations.md`. **Plan format**: `../../../reference/plan-templates.md`. After applying edits, set `phase: plan` + `last_updated` in `.claude/task-context.md` (an iteration returns the pipeline to the plan gate).

## Step 1: LOCATE & LOAD

`gh issue view {item} -R {repo} --json body,title,comments` → parse the `<!-- samuel:plan -->` section (Context, Approach, Steps, Validation, DoD) and the Brief. Scan the comments for `**Decision` / `**Upstream decision` records — a standing upstream impact notice is driving feedback even when the user didn't restate it. Fold it into the iteration and name it in the changelog line.

Present:

```
Plan for {item} — {title}
Steps: {N}   ·   AC in Brief: {n}
What would you like to change?
```

**WAIT for feedback.** If feedback came with the invocation, proceed.

## Step 2: UNDERSTAND

Classify the change and decide if research is needed:

| Change type | Research? |
|---|---|
| Add a Step | usually yes |
| Modify a Step's change/criteria | maybe |
| Remove a Step | no |
| Scope change (add/remove feature) | usually yes |
| Criteria/validation update | no |
| Technical pivot (approach B not A) | yes |

If research is needed, spawn `component-locator` / `implementation-analyzer` / `pattern-scanner` (sonnet) in a **single message**; wait for ALL.

## Step 3: PROPOSE — CHECKPOINT

```
Proposed changes:
## Plan
1. {specific edit to a Step / Approach / Validation}
{if research} ## Findings — {discovery with file:line}
{if scope} ## Scope impact — {what enters/leaves}
Proceed? (Y/N/Edit)
```

**WAIT for confirmation.**

## Step 4: APPLY

Edit the plan surgically: fetch the body, edit only the affected Steps/sections inside `<!-- samuel:plan -->`, preserve the Brief verbatim, write back (`gh issue edit {item} -R {repo} --body-file`). If the approach changed, record a decision: `gh issue comment {item} --body "**Decision:** {new approach} — {why}."` Append a one-line changelog at the end of the plan section.

**Rules**: keep Steps ordered with explicit dependencies; keep automated (gate) vs manual criteria separated; new content carries `file:line` evidence; a removed Step goes to "out of scope" with a brief reason.

## Step 5: PRESENT

```
Plan updated: {item} — {title}
Changes:
- {change 1}
Re-mark pipeline:ready if it became pickable; the plan section now reflects the edits.
Next: /samuel:implement   ·   iterate again: /samuel:refine-plan
```

## Rules

- **Be skeptical.** Question vague feedback; point out conflicts with existing Steps.
- **Be surgical.** If only Step 3 changed, don't touch Step 1.
- **Maintain integrity.** Dependencies sensible, criteria measurable, Steps ordered, plan still self-contained.
- **Track provenance.** Note what changed and why as a short changelog line in the plan.

## Gotchas

_Add a line each time Claude trips on something._

- Editing the Issue body replaces it — re-emit the Brief section verbatim when you touch the plan section.
- Reordering Steps affects their dependencies — update them.
- An approach pivot must be recorded as an Issue comment decision, or `/samuel:validate` can't explain the change.
- After refining, re-check the self-contained bar — a half-edited plan that references the old approach will stall an unattended executor.
- An `Upstream decision` comment left unaddressed keeps re-triggering decision drift at pickup — every iteration either folds it into the plan or rebuts it in a reply comment.
