# Implementation Notes: loop-hardening

> **Item**: #25  ·  **Plan**: Issue #25 body `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:4 V:4 T:1 Q:1 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

Living journal kept during `/samuel:implement`. Sealed by `/samuel:validate`. Schema: `plugins/samuel/reference/implementation-notes.md`.

## Design Decisions

### D-001 · Guard the branch before the shipped-vs-escalated PR lookup
- **Phase**: foundational
- **Step**: S1
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml:139-147`
- **Status**: superseded (by D-004 — the branch-based classifier it guarded is gone)
- **Affects**: none
- **Context**: the plan classifies **shipped** as "a PR exists for the run's branch (`gh pr list --head`)", but says nothing about what the branch is when the run aborted before `/samuel:start-task` created one.
- **Decision**: skip the lookup entirely when `git branch --show-current` returns empty, `main`, or `master` — those cases fall through to `escalated`.
- **Why**: an aborted run leaves the checkout on the default branch; `gh pr list --head main` is a meaningless query that can return an unrelated PR and mislabel a failed run as shipped. The classification is only meaningful on a feature branch.

### D-002 · SSH loop detects `shipped` by label, CI by branch head
- **Phase**: us2
- **Step**: S3
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/references/autonomous-run.md` (§ 4b sequential loop)
- **Status**: superseded (by D-004 — CI adopted this same label signal, so the CI-vs-SSH divergence this entry records no longer exists)
- **Affects**: none
- **Context**: the plan specifies one classifier — `gh pr list --head <branch>`. It works in CI, where `actions/checkout` gives a single workspace and the conductor branches inside it. It does **not** transfer to the SSH loop: there `/samuel:start-task` bootstraps a **separate worktree per item**, so the launcher's `git branch --show-current` reports the launcher's own branch, never the item's.
- **Decision**: the SSH sequential loop reads `gh issue view $n --json labels` and treats `pipeline:in-review` as `shipped`. CI keeps the branch-head lookup the plan specifies.
- **Why**: `pipeline:in-review` is flipped by `/samuel:done` immediately after it opens the draft PR (`reference/github-operations.md:338`), so it is the same event observed through a signal that survives the worktree boundary. The alternative — resolving each item's worktree path to run `git branch` inside it — adds a second thing that can go stale for no extra fidelity.

### D-003 · The `security_scan` read strips a trailing `# comment`
- **Phase**: us3
- **Step**: S6
- **When**: 2026-07-26
- **Files**: `plugins/samuel/reference/tracker.md`, `plugins/samuel/skills/pipeline/validate/SKILL.md:23`
- **Status**: applied
- **Affects**: none
- **Context**: the plan says to mirror the field-read recipe at `tracker.md:24-28` with key `security_scan` and sentinel `NO_SCAN`. That recipe is `sub(/^[^:]*: */,"")` only — it does **not** strip a trailing inline comment, and the plan simultaneously requires the template to ship the field *with* one ("comment-per-field pattern").
- **Decision**: the `security_scan` read adds a second `sub(/[ \t]*#.*$/,"")`. Verified: with the template's inline gloss it returns `gitleaks git --redact --no-banner`; without the field, `NO_SCAN`.
- **Why**: this is the only config field whose value is **executed**. A copier who keeps the template's gloss would otherwise hand validate a command with a comment glued to it. The awk stays single-quoted, so the added `$` never reaches the shell and the `## Context` lint still passes.

### D-004 · One outcome classifier for both launch paths: the `pipeline:in-review` label
- **Phase**: validate
- **Step**: S1 (revised after review)
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml:145-152`
- **Status**: applied
- **Affects**: none
- **Context**: the independent reviewer (validate Step 2.5) found the CI classifier never referenced the item it was classifying — it read one shared `git branch --show-current`. A `schedule` sweep runs every item in the **same** checkout (`start-task` does `git checkout -b` in CI), so once one item shipped, every later item that finished `success` without creating its own branch inherited the shipped item's branch and its open PR, and was recorded `shipped`. Reproduced with a mocked harness: 3 items, one stale PR → 3 `shipped` rows. D-001's `""|main|master` guard did not cover a stale *feature* branch.
- **Decision**: CI now uses the same item-scoped signal the SSH loop already used (D-002) — `gh issue view $n --json labels` matching `pipeline:in-review`. The branch lookup is gone from the classifier entirely.
- **Why**: the label is keyed to `$n`, so it is immune to the shared workspace by construction; `/samuel:done` sets it immediately after opening the draft PR, and a sweep only enumerates `pipeline:ready` issues, so it cannot be pre-set. It also collapses two mechanisms into one — the divergence D-002 documented no longer exists. Re-verified with the same harness: only the labelled item classifies `shipped`.

## Deviations

### V-001 · Single-item recipe gets the capture, not the TSV accumulator
- **Phase**: us2
- **Step**: S3
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/references/autonomous-run.md` (§ 4a)
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: "Sequential recipes (single item L56-68, `for` loop L70-83): TSV accumulation + sweep-budget break (same semantics as S1)".
- **Did**: § 4a gets `--max-budget-usd` + `stream-json --verbose` + a one-line `jq` summary. No TSV, no accumulator, no break.
- **Why**: a sweep of one has nothing to accumulate and no next item to stop — `--max-budget-usd` *is* the entire budget. The report for a single item is the conductor's own Stop/Exit Report (S4), which an autonomous run posts to `conductor:log`; the recipe now says so explicitly instead of carrying dead bookkeeping a reader would have to decide to ignore.

### V-002 · Parallel recipe extracts a helper script instead of inlining `sh -c`
- **Phase**: us2
- **Step**: S3
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/references/autonomous-run.md` (§ Parallel variant)
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: keep the recipe's shape (`xargs -P 2 -I {} sh -c '…'`), adding per-item caps and a per-item TSV.
- **Did**: the per-item logic is a heredoc'd `~/conductor-item.sh`, and `xargs` calls that.
- **Why**: the capture needs `jq` programs containing both quote types inside `sh -c '…'` inside a markdown fence — three quoting levels, which the first draft got wrong in a way that parsed fine and would have produced empty fields at runtime. A recipe nobody can safely edit is worse than one extra block. `sh -n` over the extracted helper is now a real check; the inline form was unverifiable.

### V-003 · CI classifies by label, not by `gh pr list --head` as the plan specified
- **Phase**: validate
- **Step**: S1 (revised after review)
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml:145-152`
- **Status**: applied
- **Linked decision**: none — caught by the validate Step 2.5 reviewer, not a plan-reality mismatch at implement time
- **Affects**: none
- **Plan said**: Approach — "**shipped** — a PR exists for the run's branch (`gh pr list --head`)".
- **Did**: `gh issue view $n --json labels` matching `pipeline:in-review`.
- **Why**: the plan's classifier is not item-scoped in a multi-item sweep — full reasoning and the reproduction in D-004. The plan's intent (did this item produce a draft PR?) is preserved; only the signal changed.

### V-004 · CI redirects the transcript to a file instead of tee'ing it, and uploads it as an artifact
- **Phase**: validate
- **Step**: S1, S2 (revised after review)
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml:118-127`, `:230-239`
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: S1 — `--output-format stream-json --verbose | tee "/tmp/conductor-$n.jsonl"`.
- **Did**: `> "$log"` (stderr still to the console), plus an `actions/upload-artifact@v4` step with a 3-day retention.
- **Why**: the reviewer flagged that `--verbose` emits every message **and every tool result**, so `tee` publishes whatever the agent read into the step log — world-readable on a public consumer repo, and GitHub masks only registered secrets. The template ships to repos of unknown visibility. Nothing needs the stdout copy (`tail -n 1` reads the file); the artifact keeps post-mortems possible on an ephemeral runner while scoping them to people with repo access. stderr deliberately stays out of the file so a diagnostic line can't shadow the `result` line `tail` reads.

## Tradeoffs

### T-001 · Sweep spend reaches the report step through the TSV, not `$GITHUB_ENV`
- **Phase**: foundational
- **Step**: S1, S2
- **When**: 2026-07-26
- **Files**: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml:99-101`, `:186-215`
- **Status**: applied
- **Chose**: the report step re-sums the `cost` column of `/tmp/conductor-report.tsv` with `awk`, and detects a cut sweep by the presence of a `/tmp/conductor-capped` marker file.
- **Considered**:
  - `echo "SWEEP_SPENT=… >> $GITHUB_ENV"` at the end of the run step — rejected: the run step is `set -euo pipefail`, so a mid-sweep failure skips the write and the `if: always()` report step reads nothing. The aborted run is exactly the case that step exists to cover.
  - Job `outputs:` — same failure mode, plus outputs are only readable from a *downstream job*, and the report lives in the same job.
- **Why**: files on the runner survive whatever kills the run step; the TSV is already the report's input, so the totals have a single source and cannot disagree with the table above them.

## Open Questions

### Q-001 · Should the `repo:` read strip trailing comments too?
- **Phase**: us3
- **Step**: S6
- **When**: 2026-07-26
- **Spec ref**: none — surfaced while implementing S6
- **Question**: `template/samuel.md` ships `repo: owner/name  # explicit owner/name for gh (NEVER parsed…)`, but the documented read (`tracker.md`, and every skill's `## Context`) is `sub(/^[^:]*: */,"")` with no comment strip. Run against the template verbatim it returns `owner/name           # explicit owner/name for gh (NEVER parsed from the SSH-alias origin)`. Should `repo` (and `tracker`) get the same `sub(/[ \t]*#.*$/,"")` this issue added to `security_scan`?
- **Impact if wrong**: only bites a repo whose `.claude/samuel.md` was hand-copied from the template with the glosses kept — `/samuel:start-task` and `/samuel:kickoff` write clean values. The failure is loud (`gh` rejects the garbage repo string), not silent, so nothing corrupts. Leaving it means two field-read idioms coexist in the same file, which is the kind of inconsistency the next reader copies from at random.
- **Suggested resolution**: normalize all three reads in a follow-up chore — it touches every skill's `## Context` block, which is a wider blast radius than this issue's scope and deserves its own gate run.
- **Blocking**: no
- **Status**: deferred
- **Answer**: Deferred at validation (2026-07-26) and filed as #35 (`type:chore`, `priority:low`, `pipeline:triage`). Normalizing the three reads touches the `## Context` block of every skill that reads `.claude/samuel.md`, which is a wider blast radius than this issue's scope and deserves its own gate run. The failure it prevents is loud (`gh` rejects the malformed repo string), so nothing corrupts in the meantime.
