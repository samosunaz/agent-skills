# Review Rubric — Shared Findings Standard

The single source of truth for **how a code change is judged**: severity, categories, the confidence bar, the diff boundary, and what is *not* worth flagging. Consumed by both the **`implementation-reviewer`** agent (pre-PR, inside `/samuel:validate` Step 2.5) and **`/samuel:pr-self-audit`** (post-PR, GitHub inline comments). One rubric, two surfaces — update here, both follow.

> **High-signal only.** Every flagged issue must be something a senior engineer would stop a merge for (Blocker) or genuinely want addressed (Important). Noise erodes trust in the gate. "No findings" is a valid, complete result — never invent a finding to fill a report, and never stop at the first real one.

## Severity

| Severity | Emoji | Criteria | Blocks merge? |
|---|---|---|---|
| **Blocker** | 🔴 | Security vulnerability, data-loss risk, crash, incorrect business logic, an unmet Acceptance Criterion | **YES** |
| **Important** | 🟡 | Logic error, missing edge case, test gap on a critical path, convention violation | Discuss |
| **Nit** | 🔵 | Minor improvement, non-critical convention, optimization opportunity | NO |

In `/samuel:validate`, a single **Blocker** forces `Overall: FAIL` (no seal, no PASS — and in the conductor's ship mode, no draft PR). **Important** → `PASS WITH NOTES`. **Nit** → informational.

## Categories

| Category | Examples |
|---|---|
| **Bug** | Null reference, wrong return type, missing `await`, off-by-one, incorrect condition |
| **Security** | Injection (SQL/XSS/command), auth/authz gap, hardcoded secret, unsafe deserialization, path traversal, missing input validation at a boundary, data exposure in logs/responses |
| **Logic** | Wrong business rule, inverted condition, race condition, broken invariant |
| **Convention** | Divergence from an established codebase pattern, `CLAUDE.md`/`CONSTITUTION.md`/`REVIEW.md` violation |
| **Fit** | Reinvented wheel, needless new dependency, speculative generality, contract break without a back-compat path (§ Solution fit) |

## Solution fit

The *shape* of the solution is reviewable — with the same evidence bar as any finding. **Cite the concrete alternative or don't flag it**; a fit finding without its named alternative is the "subjective architecture opinion" this rubric filters out.

| Check | Flag when | Evidence the finding must name | Severity |
|---|---|---|---|
| **Reinvented wheel** | Hand-rolled code duplicates what the framework, stdlib, or an already-installed dependency provides | The exact existing API (`Str::mask()`, a validation rule, a collection method) | Important |
| **Dependency hygiene** | A new dependency lands for a trivial need, or from a source without active maintenance | What it replaces, plus the maintenance signal checked (release cadence, issue health) | Important |
| **Speculative generality** | New abstraction with a single caller or implementation; config or generality no present requirement asks for | The simpler equivalent already in the codebase | Important; Nit when the carrying cost is low |
| **Contract compatibility** | A public surface changes (API response shape, event payload, destructive migration) with no versioning or back-compat path | The consumer that breaks | Important; **Blocker on data loss** |

Fix preference order: framework built-in > existing dependency > actively-maintained community lib > hand-rolled. A repo standard (`REVIEW.md`, `CLAUDE.md`, an established codebase pattern) that endorses the flagged approach wins — suppress the finding.

## Confidence threshold

Report only findings you are **≥80% confident** are real problems. When in doubt, don't flag. **Zero false positives over completeness** — missing one real bug is better than flagging five non-issues that train the human to ignore the gate.

A finding just under the bar either becomes an **explicit question** to the author ("what happens when `items` is empty?" — labeled as a question, carrying no severity) or gets dropped. It is never stated as fact.

## Diff boundary

Review **only code added or modified** in this change. Never flag pre-existing problems in untouched code. (Exception: a pre-existing issue that this change *activates* or *depends on* — flag it with that link made explicit.)

## What NOT to flag

- Style preferences (naming, formatting) — a linter's job.
- Anything a linter / formatter / type-checker already catches.
- Pre-existing code not touched by this change.
- Speculative "could be a problem if…" without a concrete trigger.
- Missing tests, unless an Acceptance Criterion explicitly requires them.
- Subjective architecture opinions.

## Validating a finding (before you report it)

For each candidate, confirm all six — discard if any fails:

1. The code is actually in this change's diff (not pre-existing).
2. It's concrete, not speculation — you can name the inputs or scenario that trigger it, and a claim that other code is affected names the provably affected site.
3. Confidence ≥ 80%.
4. A senior engineer would flag it — and the author would plausibly fix it once aware.
5. The fix doesn't demand rigor the rest of the codebase doesn't practice.
6. It's clearly not an intentional change the author already weighed.

## Finding shape

Every reported finding carries: **severity** · **category** · **`file:line`** · **impact** (what happens if unfixed, naming the concrete inputs or scenario that trigger it — a trigger you cannot name is a finding you cannot make) · **suggested fix** (concrete — code or a precise instruction). A finding without a fix is a complaint, not a finding.

Enumerate findings by severity initial — `B{n}` / `I{n}` / `N{n}` (Blocker · Important · Nit) — **never `#{n}`**: on GitHub surfaces `#` autolinks to Issues/PRs (§ Enumeration IDs, `github-operations.md`).

## Anti-performative

No "Great work!", "Nice code!", praise, or hedging. State the verdict and the findings; stay silent on what's fine.

## Project overrides

A repo may carry a `REVIEW.md` at its root. Its rules **override** these defaults (e.g. "skip generated files under `src/gen/`", project-specific must-checks). This is wired, not aspirational: `/samuel:validate` Step 2.5 pastes `REVIEW.md` into the `implementation-reviewer` prompt after this rubric, and `/samuel:pr-self-audit` feeds it to every review subagent. On conflict, `REVIEW.md` wins. Authoring schema: `template/REVIEW.md` in the plugin repo.

## Gotchas

_Add a line each time Claude trips on something._

- This file is the **single source** for the rubric. Do not re-inline severity/categories/thresholds into a consuming skill or agent — link here (skills) or inject it via prompt (subagents).
- Severity drives `/samuel:validate`'s `Overall` verdict mechanically: any Blocker → FAIL. Keep the Blocker bar honest.
- "High-signal only" is the whole point — a rubric that flags nits at Blocker severity makes the gate worthless.
- A Solution-fit finding without its named alternative (the exact API, the simpler in-repo equivalent, the breaking consumer) is an architecture opinion — drop it before it reaches the report.
