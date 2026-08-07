---
name: analyze
description: "Read-only cross-artifact consistency check across spec, research, plan, tasks, journal, and constitution. Severity-tagged findings, no auto-edits. Trigger on 'analyze', 'analizar consistencia', before implementing a non-trivial feature."
allowed-tools: Bash(gh *) Bash(which *) Bash(awk *) Bash(test *) Bash(date *) Bash(cat *) Bash(ls *) Read Agent
---

# Analyze (Cross-Artifact Consistency)

Read-only diagnostic. Runs after `/samuel:plan` and before `/samuel:implement` for any non-trivial feature. Detects inconsistencies, gaps, and conflicts between the spec, plan, tasks, and constitution.

A cross-artifact consistency pass over the work item (Brief + Executor Plan), any spec/research, the Issue's recorded decisions, and the repo-root `CONSTITUTION.md`. Optional for small features; valuable for multi-story work.

## Pipeline Position

```
/samuel:plan → /samuel:analyze? → /samuel:implement → ...
               ↑ YOU ARE HERE
```

## Critical Rules

1. **STRICTLY READ-ONLY.** Never edit any artifact. Never silently apply fixes. Output is a structured report + a remediation offer; the user runs the actual edits via `/samuel:refine-plan`, `/samuel:spec` (overwrite), or manual updates.
2. **Constitution is non-negotiable.** Any MUST principle violation is automatically `CRITICAL`. Do not soften, reinterpret, or work around it.
3. **Evidence-based findings.** Every finding cites a specific location (doc + section / task ID / file:line). Never report "this is vague" without quoting the vague text.
4. **High-signal output.** Cap findings at 50 rows; aggregate overflow in a summary. Don't pad with low-impact noise.
5. **Skip gracefully.** If only a plan exists (no spec), still run but report a smaller surface. If even the plan is missing, abort with instructions to run `/samuel:plan` first.

## Context

- Date: !`date '+%Y-%m-%d'`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- Phase: !`awk '/^phase:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_PHASE"}' .claude/task-context.md 2>/dev/null || echo "NO_PHASE"`
- Constitution: !`test -f CONSTITUTION.md && echo "CONSTITUTION.md present" || echo "none"`

> **Tracker**: `../../reference/tracker.md`. **State**: `../../reference/task-context.md`.

## Pre-checks

Resolve the plan and any spec/research from the Issue:

- **Plan** — the `<!-- samuel:plan -->` section of `gh issue view {item} -R {repo} --json body`. **If no Executor Plan exists** (item still `pipeline:triage`), abort: `"No Executor Plan for {item}. Run /samuel:plan first, then come back."`
- **Spec / research** (optional) — `{feature_dir}/spec.md`, `{feature_dir}/research.md` (Read/Glob).

If `Feature: NO_FEATURE`, abort: `"No active feature in .claude/task-context.md. Run /samuel:start-task first."`

## Phase 1: LOAD ARTIFACTS

Load only the minimal necessary slice from each artifact (progressive disclosure). Skip what doesn't exist.

| Artifact | Source | What to extract |
|---|---|---|
| Brief | item body `<!-- samuel:brief -->` | TL;DR, Scope, Acceptance Criteria (SC), type/priority |
| Executor Plan | item body `<!-- samuel:plan -->` | Context, Approach, Steps, Guardrails, Validation/gate, DoD, Constitution Check |
| `spec.md` (optional) | `{feature_dir}/spec.md` | User Stories with priorities, FR-###, SC-###, Edge Cases, Assumptions |
| `research.md` (optional) | `{feature_dir}/research.md` | Decisions, constraints, file references |
| Steps | inline plan Steps + AC | the granular units of work + their criteria |
| Decisions | `gh issue view {item} --comments` | Accepted decisions tied to this item |
| `CONSTITUTION.md` | Repo root | MUST and SHOULD principles |

## Phase 2: BUILD SEMANTIC MODELS

Build internal representations. Do NOT dump raw artifacts into the output report.

- **Requirements inventory**: keyed by `FR-###` / `SC-###` from spec. Capture the imperative for each.
- **User Story inventory**: keyed by US1/US2/US3. Capture priority, acceptance scenarios, independent verification.
- **Coverage map**: map each plan Step / Acceptance Criterion to one or more requirements or user stories. Use explicit refs / `phase:usN` labels first; keyword matching second.
- **Constitution rule set**: principle names + MUST/SHOULD imperatives.

## Phase 3: DETECTION PASSES

Cap total findings at 50 (aggregate overflow). Each finding gets a stable ID prefixed by category initial.

### A. Duplication
- Near-duplicate FRs (same intent, different wording); repeated User Story scenarios; duplicated task descriptions.

### B. Ambiguity
- Vague adjectives ("fast", "scalable", "robust", "intuitive") in FRs/SCs without measurable thresholds.
- Unresolved placeholders: `TODO`, `TKTK`, `???`, `[NEEDS CLARIFICATION]`.
- Acceptance Scenarios without measurable outcomes.

### C. Underspecification
- FRs with verbs but no object or measurable outcome.
- User Stories missing `Independent Verification`.
- Tasks referencing files/components not defined in spec/plan.

### D. Constitution Alignment
- Any FR, plan element, or task conflicting with a MUST principle.
- Missing `Constitution Check` section in plan when `CONSTITUTION.md` exists.
- `Complexity Tracking` claimed with weak justification.

### E. Coverage Gaps
- FR-### with zero associated tasks.
- SC-### requiring buildable work (perf test, security audit, instrumentation) with no covering task.
- Tasks with no mapped requirement OR user story.
- User Story declared in spec but no Phase mapped in plan.

### F. Inconsistency
- Terminology drift across artifacts.
- Task ordering contradictions (integration before foundational without dependency note).
- Spec User Story priority order doesn't match plan phase order.
- Recorded Issue-comment decisions that contradict the plan's Approach.

## Phase 4: SEVERITY ASSIGNMENT

| Severity | Heuristic |
|---|---|
| **CRITICAL** | Violates a Constitution MUST principle, missing core spec artifact, or requirement with zero coverage that blocks baseline functionality. |
| **HIGH** | Duplicate or conflicting requirement, ambiguous security/performance attribute, untestable acceptance criterion, spec-plan inconsistency. |
| **MEDIUM** | Terminology drift, missing non-functional task coverage, underspecified edge case. |
| **LOW** | Style/wording improvements, minor redundancy that doesn't affect execution order. |

## Phase 5: REPORT

Output a structured Markdown report. Do not write files.

```markdown
## Cross-Artifact Analysis: {Feature Name}

**Date**: {YYYY-MM-DD}
**Feature**: {slug}
**Scope**: {spec ✓ / research ✓ / plan ✓ / tasks (N) ✓ / constitution ✓}

### Overall: {PASS | PASS WITH NOTES | FAIL}

**Counts**: {N CRITICAL} | {N HIGH} | {N MEDIUM} | {N LOW}

### Findings

| ID | Category | Severity | Location | Summary | Recommendation |
|----|----------|----------|----------|---------|----------------|
| A1 | Duplication | HIGH | spec.md FR-003 / FR-007 | "User can upload file" appears twice | Merge into FR-003 |
| C1 | Underspec | MEDIUM | spec.md SC-002 | "API performs well under load" — not measurable | Replace with "P95 < 500ms at 100 RPS" |
| D1 | Constitution | CRITICAL | Executor Plan Step 4 | Violates Principle III | Add Complexity Tracking OR revise |
| E1 | Coverage gap | HIGH | spec.md FR-005 | No plan Step covers it | Add a Step to Phase 2 or 3 |

### Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|---|---|---|---|
| FR-001 | yes | TASK-5, TASK-8 | Covered in Phase 3 (US1) |
| FR-005 | NO | — | Coverage gap — see E1 |

### Constitution Alignment

{Per-principle status if CONSTITUTION.md present, omit otherwise}

### Metrics

- Total Requirements (FR + SC): {N}
- Total Tasks: {N}
- Coverage: {%} (requirements with ≥1 mapped task)
- Critical Issues: {N}

## Next Actions

{If CRITICAL: "Resolve CRITICAL findings before /samuel:implement."}
{If HIGH only: "Address HIGH findings via /samuel:refine-plan before implementing."}
{If only LOW/MEDIUM: "Plan is implementable; polish the listed items but not blocking."}
{If PASS: "No critical issues found. Proceed to /samuel:implement."}

Suggested commands:
- `/samuel:refine-plan` — modify the plan (Issue body) to address findings
- `/samuel:spec` in iterate mode — revise spec ambiguities
- Manual edit to {file} — for specific Recommendation rows
```

## Phase 6: OFFER REMEDIATION

After the report, ask:

```
Want me to prepare concrete remediation edits for the top {N} findings?
(I will NOT apply them — I'll prepare the patches and you decide.)
```

If yes, for each top finding (CRITICAL → HIGH) prepare: the quoted current text, the proposed replacement, and the artifact + location. Output as a numbered list; the user runs `/samuel:refine-plan` or manual edits. If no, end the report.

## Pipeline integration

- **Reads**: the item Brief + Executor Plan (Issue body), optional `{feature_dir}/spec.md` + `research.md`, Issue decisions, `CONSTITUTION.md`.
- **Modifies**: NOTHING. Read-only.
- **Updates**: `.claude/task-context.md` is NOT touched by analyze (it's diagnostic). The conductor advances `phase` based on the user's follow-up action.
- **Triggered by**: manual invocation or the conductor after `/samuel:plan` for non-trivial features.

## Gotchas

_Add a line each time Claude trips on something._

- STRICTLY read-only. Never call `Edit`, `Write`, `gh issue edit`. Output is a report.
- Constitution violation severity is automatic CRITICAL. Don't downgrade based on subjective judgment.
- Coverage gaps where an SC requires buildable work (perf test, security audit, observability) are HIGH, not LOW.
- Post-launch outcome metrics ("Reduce support tickets by 50%") and business KPIs are EXCLUDED from buildable-work coverage — measured after release, no task needed.
- Don't hallucinate missing sections. If a section isn't there, report it missing; don't invent that "FR-007 is incomplete" when there is no FR-007.
- Findings table caps at 50 rows. On overflow, output an "Overflow summary" line.
