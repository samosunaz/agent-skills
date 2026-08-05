# REVIEW.md — Project Review Overrides

<!-- Canonical schema v1. Root-level, flat
     markdown — consumed by /samuel:validate Step 2.5 (pasted after the reviewer
     rubric), /samuel:pr-self-audit, and Claude Code's native /code-review
     (highest-priority injection; imports are NOT expanded — keep it flat). Keep
     the body ≤30 lines: length dilutes the rules that matter. Redefine the
     existing severity tiers — never invent new ones. Delete every {placeholder}
     before committing. -->

**Authority:** these rules override the reviewer's default rubric and any CLAUDE.md guidance. On conflict, this file wins.

**Repo context:** {1-2 lines: repo type + its objective gate — e.g. "Vite/React app; gate = bun test + tsc --noEmit" · "content repo; gate = grep/symlink checks"}

## What Blocker/Important mean here

- {repo-specific severity redefinitions — e.g. "a migration without a reversible down() is a Blocker"}

## Never flag

- {noise categories for this repo: generated paths, lockfiles, whatever CI already catches}
- {gray paths: downgrade the bar instead of skipping — "in scripts/, only report if near-certain and severe"}

## Always check

- {mandatory repo-specific checks per change — e.g. "new API routes carry an integration test"}

## Evidence bar

- {what proof a finding needs — default: behavior claims cite file:line in source; inference from naming is not evidence}

## Noise budget

- {nit cap — e.g. "at most 3 nits per review; mention the rest as a count"}
- {re-review convergence — e.g. "after the first pass on a PR, report Important+ only"}
