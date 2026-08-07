---
name: create-review-md
description: "Generate a repo's schema-v1 REVIEW.md — deterministic evidence digest (repo type, gate signals, CI job names, validation/journal findings, self-review history) + semantic derivation of repo-specific rules, cited per bullet. Existing REVIEW.md → --check conformance report only. Trigger on 'create review md', 'generar REVIEW.md', 'review overrides'."
allowed-tools: Bash(bash *) Bash(gh api *) Bash(gh pr create *) Bash(git *) Bash(awk *) Bash(test *) Read Write AskUserQuestion
---

# Create Review MD

Generates the repo's root `REVIEW.md` (schema v1, `template/REVIEW.md`) in two layers: a deterministic evidence digest, then a semantic pass that derives repo-specific rules **citing evidence per bullet**. The file is flat and serves three review surfaces simultaneously: `/samuel:validate` Step 2.5 (`implementation-reviewer`), `/samuel:pr-self-audit`, and Claude Code's native `/code-review` (imports NOT expanded — never split this file). Solo adaptation: the review history that matters here is your own pipeline's — committed `validation.md` verdicts, journal deviations, and `pr-self-audit` comments — not teammate reviews.

> Script: `scripts/review-md.sh --evidence | --check`. Template: `assets/REVIEW.template.md` (mirror of `template/REVIEW.md`).

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Repo (samuel.md): !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_SAMUEL_MD"`
- REVIEW.md present: !`test -f REVIEW.md && echo "yes" || echo "no"`
- CONSTITUTION.md present: !`test -f CONSTITUTION.md && echo "yes" || echo "no"`
- gh identity: !`gh api user --jq .login 2>/dev/null || echo "NO_AUTH"`

## Process

### 1) GUARD

Run `bash "${CLAUDE_PLUGIN_ROOT}/skills/create-review-md/scripts/review-md.sh" --check` from the target repo's root. If `REVIEW.md` is absent → continue to EVIDENCE. If present → show the `[PASS|GAP]` conformance report and **stop**; regenerate only if the user explicitly asks (then continue to EVIDENCE, overwriting on WRITE).

### 2) EVIDENCE

Run `review-md.sh --evidence`. Present the digest verbatim — repo type, gate signals, CI job names, feature-artifact findings (validation verdicts, journal V-/Q- entries), PR review-comment excerpts. Read-only; the script never writes `REVIEW.md`.

Exit 3 = branch drift: HEAD is behind the default branch, so the working-tree half of the digest describes a different repo than the GitHub half. Re-run from a worktree cut off the default branch; use `--allow-branch-drift` only when the user accepts a possibly-wrong digest.

### 3) DERIVE

Classify the digest into the 5 H2 sections of `assets/REVIEW.template.md`, plus its `**Authority:**` and `**Repo context:**` lines:

- Gate signals + CI job names → **Repo context** (name the actual gate) and **Never flag** what the gate already catches.
- Reviewer findings that **recur across features** (validation.md Blockers/Importants, journal V- deviations) → **Always check**; a finding that appeared once is an anecdote, not a rule.
- Recurring Q- open questions → **Evidence bar** (what proof settles them next time).
- No matching evidence for a section → keep the template's generic default, don't invent repo specifics.

Draft every section, then present it **alongside a citation table** mapping each bullet to the evidence it came from (a validation.md path, a CI job name, a PR number, a journal entry) — this is the human checkpoint.

The table is a checkpoint artifact; it is not written to `REVIEW.md`. Inside the file a bullet may name **stable repo paths** it depends on (`.github/workflows/ci.yml`, `CLAUDE.md § Conventions`) — a reviewer can open those. It must NOT carry tracker refs (`#42`), snapshot counts, or line ranges: they rot, they don't autolink from a repo file, and the agents consuming this file cannot resolve them (`reference/code-comments.md` § committed artifacts). Provenance belongs in the PR body and the journal.

**WAIT for confirmation.**

### 4) WRITE

`Write` the confirmed draft to `REVIEW.md` (repo root). Re-run `--check` — must be all-PASS. Any GAP → fix and re-check before proceeding.

### 5) COMMIT + PR

Present the diff (new `REVIEW.md`, or the conformance fix on regenerate).

**WAIT for confirmation before committing and opening the PR.**

Branch (`chore/review-md`), conventional commit (`chore: add REVIEW.md review overrides`), then `gh pr create -R {repo}` with the TL;DR block on top (adapter § TL;DR) and the citation table below it — repo always from `samuel.md`, never parsed from the remote. Report the PR URL.

## Autonomy

Under `/samuel:conductor` (or headless `/goal`): Steps 1 (GUARD) and 2 (EVIDENCE) run straight through; Step 3 (DERIVE)'s WAIT becomes record-and-proceed — journal the draft + citation table as a pending confirmation, continue to WRITE. Step 5 always opens `--draft`. Checkpoint mode (default): Steps 3 and 5 WAIT as written.

## Gotchas

_Add a line each time Claude trips on something._

- GUARD stops on an existing REVIEW.md by design — an existing file gets a conformance report, never a silent overwrite.
- `review-md.sh` never writes `REVIEW.md` itself — only `Write` does, after the DERIVE checkpoint, so the evidence-citation gate stays meaningful.
- Solo evidence ≠ team evidence: recurrence across features is the signal. One validation.md Blocker is an incident; the same category in three features is a rule.
- Generate from a worktree cut off the **default branch**, never from a long-lived feature branch: the digest reads gate signals and CI jobs from the working tree but review history from GitHub. `--evidence` aborts (exit 3) on drift rather than emit a mixed digest.
- A repo's default branch is not always what `origin/HEAD` says locally — stale symrefs happen. The guard resolves it via `gh repo view`, and so should you.
- `detect_repo_type` probes composer.json before package.json (Laravel ships JS tooling) and react-native before generic Node (the mobile app ships a package.json too). Don't "simplify" the order.
- The Authority line names a **relationship** ("the reviewer's default rubric"), never a path. `REVIEW.md` is injected into three reviewers, one of them native `/code-review`, which cannot resolve `plugins/samuel/*` — and the file lands in repos that have no `plugins/` at all. `check_review_authority_paths` gaps on any backticked path the line names that is absent from its own repo.
- The evidence digest is full of PR numbers and feature paths; the generated `REVIEW.md` must contain no tracker refs. Citations prove the derivation at the checkpoint, then stay behind — a `#42` in a repo file doesn't autolink, rots, and means nothing to the agent that gets this file injected into its prompt.
- `gh api` leaks the raw error body to stdout on non-2xx even with `2>/dev/null` — the script tests exit status, never string emptiness.
