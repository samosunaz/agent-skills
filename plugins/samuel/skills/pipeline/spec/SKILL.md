---
name: spec
description: "Generate a Spec doc (User Stories P1/P2/P3, FR-### MUST, SC-### measurable, Edge Cases) with up to 5 clarifications. Optional — only when spec_required. Trigger on 'create spec', 'crear spec', or after /samuel:start-task when spec_required."
allowed-tools: Bash(git rev-parse *) Bash(git branch *) Bash(date *) Bash(awk *) Bash(cat *) Read Edit Write Agent AskUserQuestion
---

# Spec

Generate the canonical Spec doc for a feature. The spec captures **WHAT** users need and **WHY** in plain language. Implementation details (HOW) belong in `/samuel:plan` later.

Optional by design: only runs when `spec_required: true` in `.claude/task-context.md`. Bugs and small features skip it entirely and go straight from `/samuel:start-task` to `/samuel:plan`.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Pipeline Position

```
/samuel:start-task → /samuel:codebase-documentation? → /samuel:spec → /samuel:plan → ...
                                                        ↑ YOU ARE HERE (only if spec_required)
```

## Critical Rules

1. **WHAT and WHY, not HOW.** No tech stack, no framework names, no API shapes, no code structure. Those belong in the plan doc.
2. **Spec gates the plan.** `/samuel:plan` reads this doc. A weak spec produces a weak plan.
3. **Clarifications cap at 5.** Only the top 5 by (Impact × Uncertainty) are asked; the rest get reasonable defaults documented in `## Assumptions`.
4. **SC-### must be technology-agnostic and measurable.** "API returns under 200ms" is wrong; "Users see results within 1 second" is right.
5. **Constitution awareness.** If `CONSTITUTION.md` exists at repo root, verify the spec does not violate a MUST principle. Surface conflicts; do not silently work around them.

## Context

- Date: !`date '+%Y-%m-%d'`
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- Spec required: !`awk '/^spec_required:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"unknown"}' .claude/task-context.md 2>/dev/null || echo "unknown"`
- Constitution: !`awk '/^constitution:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"none"}' .claude/task-context.md 2>/dev/null || echo "none"`

> **Tracker**: `../../../reference/tracker.md`. **State**: `../../../reference/task-context.md`. The spec is a committed file.

## Pre-checks

If `Feature: NO_FEATURE`, abort: `"Cannot create spec: run /samuel:start-task first to bootstrap the feature."`

If `Feature` is set, check whether `{feature_dir}/spec.md` exists (Read/Glob). If it does, ask:

```
A spec already exists at {feature_dir}/spec.md.
  1. Iterate mode (read + propose surgical edits + confirm). [default]
  2. Overwrite (treat current as draft scrap).
  3. Abort.
```

WAIT for choice.

## Phase 1: GATHER

1. **Read `.claude/task-context.md`** to confirm feature_slug, item, spec_required, constitution.
2. **Read the work item** — `gh issue view {item} -R {repo}` (the Brief seeds the requirements). Use its TL;DR/Scope/AC.
3. **Read the research doc** if `{feature_dir}/research.md` exists. Research informs scope but does NOT belong in the spec body — the spec stays implementation-agnostic.
4. **Read `CONSTITUTION.md`** if present. Extract MUST/SHOULD principles.

If there is no item content, proceed from the user's invocation prompt.

## Phase 2: DRAFT

Generate the spec following `references/spec-template.md` — frontmatter + User Scenarios (Story by priority with Independent Verification and Given/When/Then), Edge Cases, Requirements (FR-### MUST), Key Entities, Success Criteria (SC-### measurable + technology-agnostic), Assumptions, Out of Scope, Clarifications log.

### Drafting rules
- Make informed guesses from the task + research + context. Default to reasonable industry standards (and document the assumption).
- Maximum 3 `[NEEDS CLARIFICATION: question]` markers in the draft.
- Every FR must be testable. "User-friendly" is not testable; "Users can complete signup in 3 clicks" is.
- Every SC must be verifiable without knowing implementation details.

## Phase 3: CLARIFY (interactive, optional)

Scan for ambiguity across: functional scope, domain & data, interaction & UX, non-functional, integration, edge cases, constraints, terminology. For each `Partial`/`Missing` category, add a candidate question. Rank by (Impact × Uncertainty). Cap at 5.

Present **one question at a time** (multiple-choice with a Recommended option, or short-answer ≤5 words). After each answer: validate it, update the spec inline in the matching section, and append the Q&A to `## Clarifications > ### Session {YYYY-MM-DD}`. Save after each integration.

> Mirror of the interview technique in `../../meta/find-unknowns/SKILL.md` § The four quadrants — one question per turn, ranked by blast radius, because sequencing lets each answer reshape the next question.

Stop when: all critical ambiguities resolved, user says "done", or 5 questions reached. If no critical ambiguities exist, skip the loop entirely.

## Phase 4: VALIDATE

Run the Spec Quality Checklist: no implementation details, focused on user value, readable by non-technical stakeholders, all mandatory sections present, zero `[NEEDS CLARIFICATION]` remaining, every FR testable, every SC measurable + technology-agnostic, Given/When/Then scenarios, edge cases identified, scope bounded, assumptions documented. If `CONSTITUTION.md` present, verify no MUST violation.

| Outcome | Action |
|---|---|
| All pass | Proceed to PERSIST. |
| Failures | List failing items + issues; refine; re-run. Max 3 iterations, then document in Assumptions + warn. |
| `[NEEDS CLARIFICATION]` remain | Loop back to Phase 3 (within 5-question budget). |

## Phase 5: PERSIST

Persist the spec to `{feature_dir}/spec.md`: a committed file (`Write` to `docs/features/{slug}/spec.md`). Commit it on the branch so plan/analyze/validate and any headless session read it.

Update `.claude/task-context.md` frontmatter via Edit: `phase: spec`, `last_updated: {today}`.

## Phase 6: PRESENT

```
Spec created: {feature_dir}/spec.md

Summary:
- User Stories: {N} (P1: {n}, P2: {n}, P3: {n})
- Functional Requirements: {N} FR-###
- Success Criteria: {N} SC-###
- Edge Cases: {N} · Assumptions: {N}
- Constitution check: {aligned / N violations / N/A}
{if clarifications ran:} - Clarifications resolved: {N}/5

Next: /samuel:plan — decomposes the spec into a technical plan with phases.
```

## Pipeline integration

- **Read by**: `/samuel:plan` (UNDERSTAND), `/samuel:analyze` (consistency), `/samuel:validate` (independent verification).
- **Modifies**: `{feature_dir}/spec.md`, `.claude/task-context.md` frontmatter.
- **Triggered by**: `/samuel:start-task` when `spec_required: true`, or manual invocation.

## Gotchas

_Add a line each time Claude trips on something._

- WHAT and WHY only. Tech stack belongs in the plan doc, NOT here.
- `[NEEDS CLARIFICATION]` cap is 3 in draft, 5 total interactive Qs. Excess → document defaults in Assumptions.
- SC-### must be technology-agnostic. "API < 200ms" is wrong; "Users see results in < 1s" is right.
- User Stories without `Independent Verification` are a smell. Rewrite to be independent or merge into a parent story.
- The spec is a committed file — `Write`/`Edit` it, commit on the branch.
- Iterate mode reads the existing spec, proposes surgical edits, confirms, applies. Don't wholesale rewrite unless Overwrite was chosen.
- Spec is optional. If `spec_required: false`, this skill should not have been invoked — point the user to `/samuel:plan`.
