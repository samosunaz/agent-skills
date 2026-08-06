---
name: plan
description: Create a self-contained plan (human Brief + Executor Plan) through 5 interactive phases with forced human checkpoints. Writes to the GitHub Issue body. Use when planning a feature, refactor, or initiative before implementation.
allowed-tools: Bash(gh *) Bash(which *) Bash(printf *) Bash(awk *) Bash(test *) Read Write Edit Agent ExitPlanMode AskUserQuestion Skill
---

# Create Plan

5 interactive phases, forced human checkpoints. The output is a **self-contained artifact** — a human **Brief** + an **Executor Plan** written for a context-less agent — persisted to the Issue body. Format: `../../../reference/plan-templates.md`.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it, and gate plan approval with `ExitPlanMode`; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Critical Rules

1. **No Open Questions**: unresolved questions at end of Phase 2 → STOP and loop back. A plan with ambiguity cannot be picked up unattended.
2. **Forced Checkpoints**: every phase ends with a user prompt. Do NOT auto-advance (except under `/samuel:conductor`, which records assumptions instead).
3. **Self-contained bar**: the Executor Plan must pass the quality bar in `plan-templates.md` — a fresh agent finishes it with no chat history.
4. **Sub-agent model**: always `model: "sonnet"` for codebase agents.

## Context

- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- Constitution: !`test -f CONSTITUTION.md && echo "present" || echo "none"`

> **Tracker**: `../../../reference/tracker.md`. Adapter: `../../../reference/github-operations.md`. **Plan format**: `../../../reference/plan-templates.md`. **Pipeline state**: `../../../reference/task-context.md`. If a `spec.md` exists, read it first — its FR/SC gate this plan.

## Phase 1: UNDERSTAND

**Goal**: complete context, no assumptions.

1. Read all referenced files/items in main context. If the item already has a **Brief** (created at triage), read it. If `docs/features/{slug}/spec.md` exists, read it FIRST. If `Constitution: present`, read `CONSTITUTION.md` and add a Constitution Check to Phase 2. Read the Issue's **comments** too (`gh issue view {item} -R {repo} --json body,comments`): `**Decision` records and `**Upstream decision` impact notices are standing constraints on the design — fold them in before choosing an approach. If the Issue has a parent (GraphQL `parent` — recipe: adapter § Blast radius), skim it and any ADR it references.
2. Spawn parallel sub-agents in a **single message**:

   | `subagent_type` | `model` | Purpose |
   |---|---|---|
   | `component-locator` | sonnet | WHERE relevant files/components live |
   | `implementation-analyzer` | sonnet | HOW current code works |
   | `pattern-scanner` | sonnet | existing patterns to follow |

3. Wait for ALL. Synthesize.

**Checkpoint 1**: present understanding + findings + questions. **WAIT.**

## Phase 2: DESIGN

**Goal**: explore options, pick one, zero open questions.

1. Identify 2–3 approaches from Phase 1 + answers.
2. Evaluate trade-offs with `file:line` evidence.

**Checkpoint 2**: options with pros/cons/effort, recommend one. **WAIT for choice.**

Record the decision: `gh issue comment {item} -R {repo} --body "**Decision:** {chosen approach} — {why}. (phase: plan)"`

**No Open Questions Gate**: verify all ambiguities resolved. If ANY remain → ask now. (An undecided plan is not pickup-ready.)

## Phase 3: STRUCTURE

**Goal**: agree on the skeleton before writing detail.

1. Break the design into ordered **Steps** (and phases for larger work) — each names files, the change, and a verification.
2. Identify dependencies between Steps — **and between this item and sibling issues** (an epic split, an upstream decision, another open item whose merged code this plan assumes). Step order lives in the plan; inter-issue order is a native `blockedBy` edge, declared in Phase 4.
3. Define **success criteria**: automated (the gate command) + manual. If the target repo has an e2e app, decide the journey's **e2e tier** now (green/yellow/manual-only, per the repo's e2e standard doc) and record it in the plan's Validation section.

**Checkpoint 3**: present Steps, criteria, out-of-scope. **WAIT for approval.**

## Phase 4: WRITE

**Goal**: persist the Brief + Executor Plan to the Issue body. Build both sections per `plan-templates.md` (decisive, self-contained, evidence-backed, guardrails embedded, exact gate command).

**Write the TL;DR last** (four lines, top of the brief section — spec: adapter § TL;DR). It's a compression of the finished plan, so it can only be written once the plan exists. Its `Caveat:` line is where the plan's one real hazard surfaces — the breaking change, the still-open dependency, the decision that constrains siblings. If nothing qualifies, say `Nada`; inventing a hazard trains the reader to skip the line.

1. If `Item` ≠ `NO_ITEM`: fetch the current body, preserve/refresh the `<!-- samuel:brief -->` section, fill the `<!-- samuel:plan -->` section. Write the composed body to a temp file (`Write`), then:
   ```bash
   gh issue edit {item} -R {repo} --body-file /tmp/issue-{item}.md
   gh issue edit {item} -R {repo} --add-label pipeline:planned --remove-label pipeline:triage
   ```
2. If `Item` = `NO_ITEM` (planning without a started item): create one —
   ```bash
   gh issue create -R {repo} --title "{type}: {summary}" --label "type:{t},priority:{p},pipeline:planned" --body-file /tmp/issue-new.md
   ```
   then record the new issue number back into `.claude/task-context.md` (`item:`).
3. **Declare inter-issue edges**: for each sibling dependency identified in Phase 3, declare the native `blockedBy` edge — read-then-add, never blind-add (adapter § Issue dependencies). `/samuel:waves` computes execution order from this graph; a dependency that lives only in the plan's prose is invisible to it.

> `--body` / `--body-file` replaces the WHOLE body — always include both marker sections.
> Code cited anywhere in the body → **SHA permalink**, never plain `path:line` (adapter § Linking) — the Issue outlives file moves. Exception: the plan's `### Relevant code` stays plain relative paths (the drift check machine-reads them).

Edit `.claude/task-context.md`: `phase: plan`, `last_updated: {today}`.

**Checkpoint 4**: confirm the artifact was written (Issue URL). **WAIT.**

## Phase 5: PRESENT

1. **Self-contained check**: re-read the Executor Plan against the `plan-templates.md` litmus test ("a fresh agent finishes it with no chat"). If it would stall, fix it before presenting.
2. Present: title, summary, the Steps table, key decisions. Show the Issue URL and note it's `pipeline:planned` (mark `pipeline:ready` once dependencies are clear, so autopilot can pick it up).
   - **The unknowns seam** (canonical heuristics: `../../../reference/pipeline.md` § The unknowns seam): if a heuristic fired while planning (AC empty/unmeasurable, `TBD` markers, `pattern-scanner` found nothing for code the plan assumes exists), suggest `/samuel:find-unknowns {item}` (preflight) before promoting — an offer, never a launch.
   - **Autonomous** (under `/samuel:conductor`): eligibility is necessary, not sufficient — promotion to `pipeline:ready` REQUIRES a preflight verdict `READY`. `HOLD` → stay `pipeline:planned`, post the unknowns comment.
3. **ROUTE — now or defer.** The plan does not end the turn. Ask where the item goes next, while the context that produced the plan is still in the session. Deferring is a valid answer; deferring **by default** is how the Executor Plan ends up carrying less than the conversation did.

   Ask with `AskUserQuestion` (**implement now** / **defer it**); runtimes without it present the same two options as text and **WAIT**. Lead with a recommendation and cite its evidence — whether any decision is still open (unresolved trade-off, an unmet dependency, or an AC that couldn't be written as a measurable outcome) and whether an unknowns heuristic fired above:

   | State | Recommendation |
   |---|---|
   | No open decision, no heuristic fired | **Now**. The plan is freshest right now and you already hold the context it assumes. |
   | A heuristic fired | **Preflight first** — `/samuel:find-unknowns {item}`, then decide. Don't promote to `pipeline:ready` on a `HOLD`. |
   | An open decision remains | **Defer** and close the decision first; a plan with ambiguity can't be picked up unattended (Critical Rule 1). |

   Then route:
   - **Now** → dispatch `/samuel:implement` in this same turn via the Skill tool (or `/samuel:analyze` first for multi-story / constitution-sensitive work). Don't restate the plan; implement's own phase gate is the next checkpoint.
   - **Defer** → the Executor Plan becomes the only carrier. Re-read it the way a cold agent would (the `plan-templates.md` litmus test) and patch whatever still lives only in this chat, then set `pipeline:ready` if it's unblocked — unblocked means no OPEN `blockedBy` blocker in the graph (adapter § Issue dependencies), not an impression from the body — so autopilot can pick it up.

## Gotchas

_Add a line each time Claude trips on something._

- The Executor Plan must be **decisive** — no "figure out X" / "the existing helper". Replace every dangling reference with a concrete `file:line`, or it can't run unattended.
- Editing the body replaces it — re-emit the Brief section verbatim when you fill the plan section. That includes the TL;DR block: it sits inside the brief markers and has none of its own.
- A TL;DR written from the chat instead of from the finished plan drifts from it silently — write it last, reading the plan, not your memory of the conversation.
- Re-planning an existing item **refreshes** the TL;DR; a stale `Caveat:` describing a hazard that got designed away is worse than no line at all.
- `pipeline:planned` ≠ pickable. Only `pipeline:ready` (planned + unblocked) is the autopilot inbox.
- Inter-issue dependencies go in the native `blockedBy` graph, never only in prose — `/samuel:waves` dispatches from the graph, so an edge described in the body but not declared puts two dependent items in the same wave. Re-adding an existing edge fails loudly: read-then-add (adapter § Issue dependencies).
- Step sizing: >~200 lines or 4+ files → split into Steps or separate items.
- Record the Phase-2 decision as an Issue comment — `/samuel:done` and `/samuel:validate` rely on that trail.
- Autonomous promotion needs a preflight `READY` (`/samuel:find-unknowns {item}`), not just eligibility — `HOLD` stays `planned`. Interactive runs only *suggest* the preflight, when a heuristic fired.
- The e2e tier is a plan-time decision — a plan without it is not pickup-ready in repos with an e2e app.
- Comments ride the fetch — an `Upstream decision` notice ignored at planning resurfaces as decision drift at pickup. Address it in the plan (or rebut it in a comment), don't skip it.
- **ROUTE is a question, not a menu.** Printing `/samuel:implement` as a suggestion and ending the turn is the behavior Phase 5 step 3 replaces: the default outcome was deferral, and the context that justified the design died with the turn.
- Answering "now" means **dispatching** `/samuel:implement` in the same turn, not telling the user to type it. Implement's own phase gate is the next checkpoint, so chaining skips no approval.
- The ROUTE recommendation must **cite** its inputs (open decision? heuristic fired?). An uncited "I'd leave it for later" is a guess the user cannot check.

## Sub-Agent Rules

- Spawn ALL agents in a **single message**. Focused prompts. Researchers, not decision-makers. Wait for ALL before synthesizing.

## Rules

- **Parallel first**, **evidence-based** (`file:line`), **incremental approval** (validate structure before writing 500 lines), **idempotent phases** before Phase 4.
