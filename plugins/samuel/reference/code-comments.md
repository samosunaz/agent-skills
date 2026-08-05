# Timeless Code Comments

The single source of truth for what a pipeline-written comment is allowed to say. Consumed by **`/samuel:implement`** (prevents the anti-practices at the point code is written) and **`/samuel:remove-slop`** (detects them after the fact, on a branch diff). One taxonomy — update here, both consumers follow.

## The test a comment must pass

A comment earns its tokens only if it states a **constraint the code cannot show on its own** — a non-obvious invariant, a workaround for a specific bug, a "why" a reader could not derive from the code itself. If removing the comment would not confuse a future reader, it fails the test and should not exist.

A comment that fails this test is usually doing one of two things instead: narrating *the change* rather than describing *the result*, or restating what the code already says. Both are covered below.

## The five anti-practices

Harvested from a real pipeline run on a payments codebase. Examples are paraphrased into a neutral domain; issue refs are wrapped in backticks so GitHub does not autolink them from this file.

| ID | Anti-practice | Example | Why it's slop |
|---|---|---|---|
| A1 | Change narrative | `"Single source of truth — the cached total is retired (#412)"` — repeated 3 times in one PR | Speaks to the diff's reviewer, not the future reader; duplicates git blame/PR/Issue; "is retired" is diff-relative — meaningless once the diff is history |
| A2 | References that rot | `(#412)`, `(#398)` in docblocks and comments | See below — issue refs are one case of a broader problem |
| A3 | Docblock restating the signature | `"Total refunded, derived from refund rows (Σ amount)"` over `sum('amount')` | States "what it does" over already self-descriptive code |
| A4 | Diff-relative language | `"the (derived) refundable amount"`, `"never mutate the money columns"` | Only parses if you know the code that used to be there |
| A5 | Plan/AC banners in tests | `// ---- AC-1: refund is recorded as its own row ----` | Executor-Plan scaffolding leaking into source; `validation.md` already maps tests → AC — the banner is a duplicate with no reader |

### A2, widened: references that rot

`A2` is not just "issue refs" — it's any reference whose target can change or disappear out from under the comment, of which an internal issue ref is one case:

- **Internal issue refs** — `` `#412` `` — mean something only inside the tracker, and the tracker's state moves on.
- **Counts snapshots** — `153/153 migrations` — true the day it was written, silently wrong the next time a migration lands.
- **Line ranges** — `PaymentAction.php:35-40` — drift the moment the file is edited above that range.

**Stays** (stable, external, a reader can open it): repo paths (`.github/workflows/ci.yml`, `tsconfig.json`), doc sections (`CLAUDE.md § Database Conventions`), specs, RFCs, upstream bug trackers.

## Why this is worse in committed artifacts than in source

The same anti-practices surface in **committed repo artifacts** the pipeline generates — a `REVIEW.md` shipped with a PR ref per bullet, for example — and the damage there is worse than in source, for a reason that doesn't apply to code:

- `#N` autolinks only inside Issues, PRs, and comments. In a repo `.md` blob it is dead text — GitHub never resolves it.
- An artifact like `REVIEW.md` is not read by a human clicking through GitHub. It is **injected into a reviewer's prompt** (`/code-review`, `/samuel:validate` Step 2.5, `/samuel:pr-self-audit`). An agent holding `` `#398` `` in its context window cannot resolve it to anything. That is worse than noise — it is an authoritative-looking citation that verifies nothing.

The scope of this rule is therefore **code comments and committed repo artifacts** the pipeline generates — `REVIEW.md`, ADRs, `CLAUDE.md`, generated docs — not source alone.

## Contrast — comments that DO earn their tokens

From the same run, left untouched:

- `"does NOT reuse scopeRefunds(), which filters type=REFUND only (excludes PARTIAL_REFUND)"` — states a non-obvious constraint the code cannot show by itself.
- `"Memoized per instance so the appended accessors share one query"` — explains a "why" no signature or type would surface.

The artifact-level equivalent — stable paths a reviewer can actually open:

- `.github/workflows/ci.yml`
- `tsconfig.json`
- `CLAUDE.md § Database Conventions`

## The rule, stated once

**Keep** a reference if it is stable and external — a spec, an RFC, an upstream bug, a repo path a reader can open — and it carries the reason, not just the pointer. **Remove or replace** a reference that rots — an internal issue ref, a counts snapshot, a line range — with the reason it was encoding. The reason survives; the pointer doesn't have to.

## Gotchas

_Add a line each time Claude trips on something._

- When quoting an example issue ref in prose (this file, a skill, a PR description), wrap it in backticks — otherwise GitHub autolinks it and the "this is dead text" point disproves itself.
- `A2`'s three rotting-reference kinds (internal issue ref, counts snapshot, line range) are not exhaustive by construction — the shared property is "can change without the comment being touched." New kinds get added here, not re-derived per consumer.
