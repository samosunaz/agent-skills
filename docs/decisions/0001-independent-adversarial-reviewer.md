# 1. Independent adversarial reviewer in the validate gate

Date: 2026-06-15
Status: Accepted

## Context

The autonomous pipeline (conductor ship-mode) had the same agent implement, run `/samuel:validate`, and open the PR — self-preferential bias ("the maker grades its own homework"). The only independent checks were `/goal` (judges only what surfaces in the conversation) and CI (post-PR). The loop-engineering analysis in #8 identified this as gap #2.

## Decision

Add an **independent adversarial reviewer** to `/samuel:validate` as **Step 2.5**: a fresh-context `opus` subagent (`implementation-reviewer`) that reviews the diff against the spec/AC with a mandate to refute, and returns a structured verdict (`APPROVE | REQUEST CHANGES` + findings). A **Blocker** finding forces `Overall: FAIL` (no seal, no PASS); in the conductor it suppresses the draft PR → handoff.

The reviewer is the plugin's **first analyst/critic agent** — a deliberate exception to "agents are retrievers, not analysts". The findings rubric is single-sourced in `reference/review-rubric.md`, shared with `/samuel:pr-self-audit`.

## Consequences

- Independence is **context-level** (fresh subagent + objective inputs + on-disk verdict + mechanical hard-gate), **not process-level** — CI and a future event-driven trigger (gap #1) remain the process-independent layers.
- The reviewer can raise false-positive Blockers; mitigated by the rubric's ≥80% confidence bar and diff boundary, the human override (interactive), and conservative handoff (conductor).
- The rubric is **injected into the subagent's prompt** (not referenced by path), keeping it single-source while resolving at runtime in any target repo.
- Out of scope (future work): auto-fix loop (evaluator-optimizer), panel of N reviewers, and the event-driven trigger that would make the review process-independent.
