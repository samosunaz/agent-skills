# Testing Seams

The canonical source for where a test goes and what makes one worth keeping. `/samuel:tdd` is the hub; `plan`, `implement`, and the review rubric reference this file instead of restating it (CLAUDE.md § Architecture: Hub-and-Spoke).

## What a seam is

A **seam** is the public boundary where behaviour can be observed without reaching inside the unit that produces it. The term is Michael Feathers'; the pipeline adopts it because "where does the test go" is a design decision, and design decisions belong to the plan, not to whoever happens to be writing the assertion.

Seams by layer:

| Layer | The seam | Observed through |
|---|---|---|
| HTTP / RPC | route or method signature | a request, its status and body |
| Module | exported function or class | its arguments and return value |
| CLI | entry point | argv, exit code, stdout |
| Queue / event | consumer contract | publishing a message, reading the effect |
| Persistence | repository interface | a write followed by a read |

Not seams: a private method, an internal field, a collaborator replaced by a mock whose call count is the assertion. A test that reaches those observes construction, not behaviour, and it will fail the first time construction changes for a good reason.

**This is not the e2e tier.** The plan's `### Validation → e2e tier` line classifies the *journey* through a running app (green / yellow / manual-only) and belongs to the target repo's e2e standard. Testing seams place the tests **below** that: where a behaviour is observed without a browser. A yellow tier names the deterministic seam it starts from, and that seam belongs in this section too — the two lines agree or one of them is wrong.

## Choosing seams

Four rules, applied in order.

1. **Prefer an existing seam.** A seam already under test has proven it can be observed. Cite the prior art as `file:line` — the test that observes it today.
2. **A new seam goes at the highest point that still isolates the behaviour.** High means close to the caller: the route over the service, the service over the private helper. Lower seams buy precision and pay for it in coupling.
3. **Fewer seams is better.** Two tests at one seam beat one test at each of two seams; the second seam is a second thing to keep true.
4. **The human confirms the list before any test exists.** Seams are agreed at `/samuel:plan` Checkpoint 3 (STRUCTURE), alongside the Steps and success criteria, and persisted in the plan. **No test is written at a seam the human did not confirm** — when the plan declares none and a Step needs one, ask; do not pick one silently.

## The three anti-patterns

Each is named by its tell, because the tell is what an agent can check on its own work.

**implementation-coupled** — Tell: the test breaks when you refactor and the behaviour did not change. It asserts on internals (a private call, an intermediate shape, the order of two independent operations), so any restructuring reads as a regression. The cost lands later, on whoever refactors: they cannot tell a real break from a bookkeeping one, so they stop refactoring.

**tautological** — Tell: the assertion recomputes the expected value the same way the code does. `expect(total).toBe(items.reduce((a, i) => a + i.price, 0))` passes whether or not the sum is right, because both sides share the bug. It passes by construction, which is the worst possible property in a test: green forever, informative never. Write the expected value as a literal, or derive it from the requirement, never from the implementation.

**horizontal slicing** — Tell: every test is written first, then all the implementation. The tests then verify imagined behaviour, and the first real integration rewrites them. It also destroys the signal red is supposed to carry: a hundred failing tests say nothing about which one to fix next.

## The loop

Red, then green. One vertical slice per cycle.

- **Red first, and observed.** A test that was never seen failing has not proven it can fail. Run it, read the failure, confirm the message describes the missing behaviour rather than a typo or a missing import.
- **One vertical slice per cycle.** A slice is one behaviour end to end at its seam: red, then the smallest change that makes it green, then the next slice. This is the direct inverse of horizontal slicing.
- **Green means green.** A skipped, pending, or commented-out test is red wearing green.
- **Refactor is outside the loop.** Structural cleanup does not belong between red and green — it belongs to the review stage, where the tests that just went green are the safety net that makes it cheap. Folding refactor into the loop is how a cycle stops being a cycle.

## Emission

Seams persist in the Executor Plan under `### Testing seams`, between `### Approach` and `### Steps` — a design decision, read before the Steps, not a checklist item at the end. Format is one line per seam:

```
path or signature — existing | new — prior art file:line
```

**When the repo has no test runner, the section is emitted as `none — repo has no test suite` and no gate requires it.** The signal is the repo itself, read at Phase 3: a `test` script in `package.json`, a `phpunit.xml` / `pytest.ini` / `go.mod` with test files, or a test target inside the gate command the plan is about to name. There is no repo-scoped `verify` key in `.claude/samuel.md` to read — the gate command comes from the plan (`plan-templates.md` § Validation), so the runner is established from the repo's own configuration rather than from a field.

This is an **observable heuristic**, never the agent's assessment of whether tests "seem needed" — `pipeline.md` § The unknowns seam holds the doctrine: a trigger built on self-assessment is decorative, because an agent that must clear a bar learns to clear it.

Enforcement is asymmetric in surface, not in strength:

- **Interactive / attended-auto** — a plan in a repo with a runner that declares no seams gets the omission surfaced at Checkpoint 3. The human decides.
- **Autonomous** (`autonomy: goal`) — the omission is recorded on the Issue as an accepted risk and named in the run's decision trail. It is **not** a `pipeline:ready` gate: that promotion is already governed by the semantic preflight (`find-unknowns`), and a bare "does the section exist" check stacked on top is a mechanical gate holding veto over a semantic one.

## Consumers

- `/samuel:tdd` — the hub. Reads this file before writing any test.
- `/samuel:plan` — Phase 3 STRUCTURE derives the seam list and carries it to Checkpoint 3.
- `/samuel:implement` — writes tests only at declared seams; a Step needing an undeclared seam is a plan-reality mismatch. A plan carrying no section at all predates the contract: it asks rather than stopping.
- `reference/review-rubric.md` — a missing test is reportable only when the plan declared the seam and the diff left it uncovered.

A new consumer references this file. It does not restate the rules; an unannotated copy drifts.

## Gotchas

_Add a line each time Claude trips on something._

- `none — repo has no test suite` is a verdict about the repo, not about the change. A repo with a runner never emits it, however small the change.
- Prior art is a `file:line` citation, not a claim that a seam "is already tested" — the line is what makes the claim checkable.
- The `e2e tier` line and this section describe different altitudes. A yellow tier's deterministic seam appears in both; a green tier implies nothing about unit seams.
