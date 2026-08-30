---
name: tdd
description: "Write tests at the seams the plan declared, one behaviour per red-green cycle. Refuses to invent a seam the human never confirmed. Trigger on 'tdd', 'testing seams', 'write the tests'."
allowed-tools: Read Edit Write Bash(git diff *) AskUserQuestion
---

# TDD at Agreed Seams

Write tests where the plan says, one behaviour at a time, starting red. "Where does this test go" is a design decision: it belongs to the plan and its human checkpoint, not to whoever happens to be writing the assertion.

> **Spoke**: `../../reference/testing-seams.md` — what a seam is, the selection rules, the three anti-patterns with their tells, the loop rules, and the emission contract. **Read it before writing any test.**
> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## The hard rule

**No test is written at a seam the human did not confirm.**

Seams are agreed at `/samuel:plan` Checkpoint 3 and persist in the Executor Plan under `### Testing seams`. Before writing anything:

1. Read that section of the plan.
2. `none — repo has no test suite` → stop. The repo declares no runner, so there is nowhere for a test to live. Say so; do not create a suite to hold it.
3. Section present → every test lands at one of the seams it lists.
4. Section present but the behaviour you need has no listed seam → **ask**. Name the seam you would add and what it observes, then wait. Inside `/samuel:implement` this is a plan-reality mismatch and it stops the run.
5. Section missing entirely → the plan predates the contract, so it constrains nothing. Propose the seam and ask; do not stop the run.

Invoked standalone, with no plan in play, rules 4 and 5 collapse to one move: propose the seam, get confirmation, then write.

## The loop

One behaviour per cycle. Never batch.

1. **Pick one slice** — a single behaviour, end to end, observable at its seam.
2. **Write one failing test** there. Assert against the requirement, not against how the code will compute the answer.
3. **Run it and read the failure.** A red you never saw is not a red. Confirm the message describes the missing behaviour, not a typo, a bad import, or a misconfigured runner.
4. **Make it green with the smallest change** that satisfies the test. Nothing extra: unasked-for generality has no failing test holding it accountable.
5. **Run the full suite.** A green slice that reddened a sibling is not done.
6. **Next slice.** Refactoring is not part of this loop — it belongs to review, where the green suite is the safety net that makes it cheap.

Stop the loop and surface it when the same test goes red for a reason the plan did not anticipate. That is information about the plan, not an obstacle to route around.

## Anti-patterns

Three, each recognised by an observable tell: **implementation-coupled**, **tautological**, **horizontal slicing**. The tells and their costs are in the spoke (§ The three anti-patterns).

Read them before writing and check your own diff against them before declaring green. Self-check is cheap here precisely because the tells are observable — a test that recomputes its expected value is visible in the diff, no judgment call required.

## Consumers

- `/samuel:plan` — Phase 3 STRUCTURE derives the seam list and carries it to Checkpoint 3.
- `/samuel:implement` — writes tests only at declared seams; an undeclared seam stops the run (rule 4), a plan carrying no section at all asks instead (rule 5).
- `../../reference/review-rubric.md` — a missing test is reportable only when the plan declared the seam and the diff left it uncovered.

## Gotchas

_Add a line each time Claude trips on something._

- Running the suite goes through the permission prompt: the runner command is per-repo (`bun test`, `php artisan test`, `pytest`) and cannot be enumerated in `allowed-tools`. Same as how `/samuel:implement` runs a repo gate.
- The emission verdict is about the repo, not the change: a repo with a runner never emits `none`, however small the diff.
- This skill has no `## Context` block on purpose — it needs no runtime injection, which also keeps it outside `bun run check:context`.
