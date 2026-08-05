# Implementation Notes: auto-trigger

> **Item**: github#12  ·  **Plan**: Issue #12 body (`<!-- samuel:plan -->`)  ·  **Constitution**: none
> **Counters**: D:6 V:1 T:0 Q:0 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

Living journal kept during `/samuel:implement`. Sealed by `/samuel:validate`. Schema: `plugins/samuel/reference/implementation-notes.md`.

## Design Decisions

### D-001 · "caps" in SC-1 = turn caps, not a token-budget cap
- **Phase**: foundational
- **Step**: 1
- **When**: 2026-06-16
- **Files**: `plugins/samuel/reference/automated-trigger.md`
- **Status**: applied
- **Context**: SC-1 asks to document "turn/cost caps" but the Brief puts "token-budget cap / cost-per-accepted-change metric" explicitly out of scope. Risk: an executor builds a real cost-enforcement mechanism. (analyze finding F1.)
- **Decision**: The reference documents the **turn cap** as the cost-control lever — `claude -p --max-turns` (hard backstop) + the `/goal` "Stop after N turns" brake. It states plainly that a token-budget/cost-per-change cap is out of scope (a separate item).
- **Why**: Turn caps are the proven, in-scope brake (`autonomous-run.md:107`); a token-budget cap is a different mechanism the Brief defers. Documenting the lever that exists, naming the one that doesn't, removes the ambiguity without expanding scope.

### D-002 · post-CI-check job scoped to single-issue events
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-16
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml`
- **Status**: applied
- **Context**: The `schedule` trigger loops over N `pipeline:ready` issues, but the post-PR job speaks in singular (one `<pr>`, one `<issue>`). It can't cleanly map 1 PR ↔ 1 issue across a multi-item schedule run. (analyze finding C1.)
- **Decision**: `ci-check` runs only for **single-issue** events (`issues:labeled` / `workflow_dispatch`) via `if: github.event_name != 'schedule'`. Schedule (multi-item) runs skip the per-PR comment and rely on the morning review (`autonomous-run.md:109-123`). Documented in the reference + a template comment.
- **Why**: A single downstream job can't fan out cleanly over an unbounded issue set, and the schedule path's natural review surface is already the morning `gh pr list --draft` sweep. Keeping `ci-check` single-issue keeps the template correct and simple; the labeled/dispatch paths (the real dogfood surface) get the issue comment.

### D-003 · ci-check resolves the PR by branch head, not job outputs
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-16
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml`
- **Status**: applied
- **Context**: `ci-check` (`needs: conductor`) needs the PR number, but the plan didn't say how it crosses the job boundary from `conductor`. The branch name embeds a slug the agent derives from the issue title, so it can't be predicted by the workflow up front. (analyze finding C2.)
- **Decision**: After `claude -p` runs, the `conductor` job captures the **actual** checked-out branch (`git branch --show-current`) and the issue number into `outputs.branch` + `outputs.issue`. `ci-check` then resolves the PR with `gh pr list --head <branch> --json number` (empty → no PR was opened; comment a handoff note and exit clean).
- **Why**: The PR number only exists mid-job and the slug isn't predictable, but the branch *is* known once the agent has created it (CI mode creates the branch in the current checkout, no worktree). Capturing it post-run and resolving by `--head` is the robust handoff — one `gh` query, no fragile capture of a value created deep inside the agent step.

### D-004 · default cron cadence `0 9,15 * * 1-5`
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-16
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml`
- **Status**: applied
- **Context**: Step 2 specifies `on.schedule: [cron]` without a concrete expression. (analyze finding C3.)
- **Decision**: Default to `0 9,15 * * 1-5` (09:00 & 15:00 UTC, Mon–Fri), commented as adjustable.
- **Why**: Twice-daily on weekdays is a sane heartbeat for a solo maintainer — frequent enough to clear the inbox, not so frequent it burns runner minutes overnight/weekends. A comment makes the cadence obviously tunable.

### D-005 · issues trigger fires only on the `pipeline:ready` label transition
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-16
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml`
- **Status**: applied
- **Context**: An `if: contains(labels.*.name, 'pipeline:ready')` re-fires on *any* label add while `pipeline:ready` is already present (e.g. adding `priority:high`). (analyze finding F2.)
- **Decision**: Gate the `issues` path on `github.event.label.name == 'pipeline:ready'` so it fires only at the exact moment the label is added; keep `workflow_dispatch`/`schedule` flowing via the `||` branch.
- **Why**: Firing on the transition (not on label-set membership) prevents redundant conductor runs on the same issue, saving runner minutes and avoiding duplicate draft PRs.

### D-006 · ci-check reports the conductor-failure path too (review Nit)
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-16
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml`
- **Status**: applied
- **Context**: Independent review (validate Step 2.5) flagged a 🔵 Nit: with `set -euo pipefail`, a turn-cap / agent-error stop aborts the `conductor` job before it writes `$GITHUB_OUTPUT`; `ci-check` then skips (default `needs:` semantics), so the loop posts **nothing** — contradicting the reference's "always comments green/red".
- **Decision**: Emit `outputs.issue` **before** `run_one` (so it survives a failed run); gate `ci-check` on `always() && (needs.conductor.result == 'success' || 'failure') && != 'schedule'` (still skips on a non-`pipeline:ready` skip); add a no-branch guard that posts a 🟡 "did not complete" comment. Reference updated to match.
- **Why**: A silent failure in an unattended loop erodes trust — for a template consumers copy, the loop must report *something* on every single-issue run. Cheap (~10 lines), preserves the authority ceiling (still never ready/merge), keeps `actionlint` green.

## Deviations

### V-001 · CI-adapted the allowlist copied into the template
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-06-16
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml`
- **Status**: applied
- **Linked decision**: none
- **Plan said**: reuse the `autonomous-run.md:22-44` allow/deny block verbatim in the pre-staged `settings.json`.
- **Did**: reproduced it with three minimal adaptations — added `Bash(git checkout *)` (CI creates the branch in the checkout with `git checkout -b`, no worktree), emitted it as strict JSON (dropped the JSONC `//` comments, which `~/.claude/settings.json` doesn't parse), and dropped `Bash(backlog *)` (the workflow is github-only). The `deny` list (no merge/ready/close) is verbatim.
- **Why**: "Verbatim" JSONC isn't valid in a JSON settings file, and CI branch creation needs `git checkout`. The authority ceiling (the `deny` block) is preserved exactly.

## Tradeoffs

_None yet._

## Open Questions

_None yet._
