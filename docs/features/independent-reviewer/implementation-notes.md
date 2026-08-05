# Implementation Notes: independent-reviewer

> **Item**: github#9  ·  **Plan**: Issue #9 body (Executor Plan)  ·  **Constitution**: none
> **Counters**: D:2 V:1 T:1 Q:0 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

Living journal kept during `/samuel:implement`. Sealed by `/samuel:validate`. Schema: `plugins/samuel/reference/implementation-notes.md`.

## Design Decisions

### D-001 · Reviewer receives the rubric via prompt, not a file path
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-15
- **Files**: `plugins/samuel/agents/implementation-reviewer.md`, `plugins/samuel/skills/pipeline/validate/SKILL.md`
- **Status**: applied
- **Context**: The plan says "the reviewer references the rubric". But a subagent gets no plugin base-dir at runtime, so a relative path (`../reference/review-rubric.md`) in the agent definition would not resolve reliably inside an arbitrary target repo.
- **Decision**: The rubric stays the single source in `reference/review-rubric.md`. `validate` (which has a skill base-dir) reads it via `../../../reference/` and **injects it into the reviewer's prompt**. The agent definition says "apply the rubric provided in your prompt".
- **Why**: Preserves single-source (Option 1), works at runtime in any target repo, and avoids duplicating the rubric in the agent def.

### D-002 · Reviewer runs `git diff` itself, not fed the diff in-prompt
- **Phase**: polish
- **Step**: 3 (post-review refinement)
- **When**: 2026-06-15
- **Files**: `plugins/samuel/skills/pipeline/validate/SKILL.md` (Step 2.5 inputs)
- **Status**: applied
- **Context**: Independent-review Nit — the agent declares `Bash(git diff *)`, but Step 2.5 also said it "passes the git diff in the prompt", making the grant redundant and risking a huge paste.
- **Decision**: Step 2.5 passes the **base ref**; the reviewer runs `git diff {base}...HEAD` itself (it has the tool). The diff is not pasted into the prompt.
- **Why**: Scales to large diffs, removes the redundancy the review flagged, and makes the `Bash(git diff *)` grant purposeful.

## Deviations

### V-001 · pipeline.md conductor diagram updated for the reviewer gate
- **Phase**: polish
- **Step**: 6 (post-review)
- **When**: 2026-06-15
- **Files**: `plugins/samuel/reference/pipeline.md:92,105,121,126`
- **Status**: applied
- **Linked decision**: none (independent-review finding, not a hard STOP)
- **Plan said**: Phase 1 deferred `pipeline.md` as "optional" (it lacks the roster table), though the task-context Scope listed it.
- **Did**: Updated the conductor flowchart edge (`gate green` → `Overall: PASS`), the conductor summary, the journal-seal state, and the ship-mode note to reflect Step 2.5.
- **Why**: The independent review flagged that `pipeline.md`'s conductor diagram contradicted SC-5 — per the old edge, a green gate with a reviewer Blocker would still open a draft PR. Deferring it left an active contradiction in the pipeline's own reference doc.

## Tradeoffs

### T-001 · pr-self-audit's subagent-spawn table left intact
- **Phase**: polish
- **Step**: 4
- **When**: 2026-06-15
- **Files**: `plugins/samuel/skills/git/pr-self-audit/SKILL.md` (Step 3 REVIEW spawn table)
- **Status**: applied
- **Chose**: Keep pr-self-audit's Step 3 "spawn agents / what to find" table as-is.
- **Considered**: Collapsing its "What to find" examples into `review-rubric.md` as well — rejected. That table is *operational* (how pr-self-audit distributes focus across sonnet sub-agents), not the *rubric definition* (severity/categories/confidence/what-not-to-flag), which is now single-sourced.
- **Why**: The AC ("no rubric duplication") targets the rubric definition; the spawn table is a distinct operational concern. Coupling it to the rubric file would over-extract.

## Open Questions

_None yet._
