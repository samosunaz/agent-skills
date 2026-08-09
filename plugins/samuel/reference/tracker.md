# Tracker — GitHub as the Source of Truth

The samuel pipeline tracks work in **GitHub Issues + Pull Requests**, operated through the `gh` CLI. One Issue = one work item: body = Brief + Executor Plan (`<!-- samuel:brief -->` / `<!-- samuel:plan -->`), status = `pipeline:*` labels, closed by a PR `Closes #N`. The exact commands, label transitions, and PR ops live in the adapter: `reference/github-operations.md`. The single-tracker decision is ADR 0002 (`docs/decisions/0002-single-tracker-github.md` in this repo).

There is **no alternate tracker backend** and no offline fallback.

## Repo config — `.claude/samuel.md`

A tiny, durable, per-repo config read by skills that run **before** a task exists (`/samuel:next`, `/samuel:progress`, `/samuel:kickoff`). Frontmatter + `awk` (no `jq`, no shell expansion — same discipline as `task-context.md`):

```markdown
---
tracker: github            # legacy detection key — anything else means "not migrated"
repo: owner/name           # the explicit owner/name for gh (never parsed from the SSH-alias origin)
security_scan: gitleaks git --redact --no-banner   # optional — the security step /samuel:validate runs
# signoff: gh signoff gate # optional — uncomment to opt in; the command /samuel:done runs after the push
# autonomy: attended-auto  # optional — uncomment to opt in; absent = interactive
---

# samuel config
Per-repo pipeline defaults. `repo` is the explicit owner/name for gh —
never parsed from the SSH-alias origin.
```

`repo` is the field that matters — `gh` needs the explicit `owner/name` because SSH-alias origins break `git remote` parsing (run `gh repo set-default {repo}` once per clone). `tracker:` remains only as a **legacy detection key**: `github` (or a fresh file) means the repo is migrated; anything else marks a pre-migration context (see Legacy contexts below).

`security_scan` is **optional** and **repo-scoped**: the exact secret-scan / SAST command `/samuel:validate` runs as part of its gate step, which must exit non-zero on findings. Absent is the default and the common case — validate then reports the skip explicitly instead of staying quiet about it. Unlike the build gate (which comes from the plan's `Validation → Automated` line and can differ per task), the scanner is a property of the repo, so it lives here. Full gloss: `template/samuel.md`.

`signoff` is **optional** and **repo-scoped**: the exact command `/samuel:done` runs after the push (Step 3) to assert the local gate on the pushed commit — `gh signoff gate` and friends, when the repo has deliberately traded a CI job for the local one. Absent is the default and the common case: CI alone is the remote checkpoint. Two rules travel with it, both in `reference/github-operations.md` § CI as the merge gate: it names **only** the contexts the local gate actually covers, and it is not emitted when `HEAD` moved past the SHA `/samuel:validate` gated. Full gloss: `template/samuel.md`.

`autonomy` is **optional** and selects how the run treats a soft checkpoint: `interactive` (ask — the default when absent) or `attended-auto` (take the obvious default and announce it). It is the one field here that also has a **global** fallback: `~/.claude/samuel.md` supplies it for every repo that doesn't override it, since it describes how its owner likes to work rather than anything about the repo. `autonomous` is deliberately not settable — that level belongs to `/samuel:conductor` and its SAFETY GATE. Levels, the gate-by-gate table, and the recording contract: `reference/autonomy.md`.

Read a field in a skill's `## Context` (expansion-free):

```markdown
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Security scan: !`awk '/^security_scan:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_SCAN"}' .claude/samuel.md 2>/dev/null || echo "NO_SCAN"`
```

`autonomy` is the exception to that one-file shape — it falls through to the global file before defaulting, so it reads as a chain (the exact line lives in `reference/autonomy.md` § Resolution and is what `scripts/lint-autonomy.sh` checks for).

**The second `sub()` is not optional on any field of this file.** `template/samuel.md` ships every field with an inline gloss, and a repo that copies it verbatim keeps them — so an unstripped read of `repo` returns `owner/name           # explicit owner/name for gh (…)`, which `gh` rejects. One idiom for every command-valued field (`tracker`, `repo`, `security_scan`, `signoff`), so the next skill that copies a read can't pick the wrong one. The awk program stays single-quoted, so its `$` never reaches the shell.

> This applies to `.claude/samuel.md` only. `.claude/task-context.md` is written by the skills and never carries an inline gloss — its reads stay at the single `sub()` documented in `reference/task-context.md`.

When `repo` resolves to `NO_REPO`, ask once and persist the answer to `.claude/samuel.md`. `/samuel:start-task` copies `repo`+`item` into `.claude/task-context.md` so the rest of the pipeline reads one file.

## Storage map — three axes, three homes

Committed artifacts live by **scope**, not lumped under one dir. Three orthogonal axes:

| Axis | Answers | Home | Lifetime |
|---|---|---|---|
| **Work** (per task) | "how I built *this*" | `feature_dir` — `docs/features/<slug>/` | local; historical after merge |
| **Architecture** (chronological) | "why we decided *X*" | `docs/decisions/NNNN-slug.md` (ADRs) | durable, git-versioned, supersedible |
| **Product** (per capability) | "what *Y* does & how it works" | `docs/product/<capability>/README.md` (dossiers) | living, spans many tasks |

The rule that keeps them apart: **task-scoped → `feature_dir` (or an ephemeral Issue comment); project-scoped → a global committed collection.** A decision or capability that outlives the task does **not** go under `features/<task-slug>/` — that buries it where no other task can find it.

- `feature_dir` holds **process** artifacts: research, the journal (`implementation-notes.md`, schema in `reference/implementation-notes.md`), validation. Derive it from `task-context.md`; never re-type it. (The Issue body holds the Brief + Executor Plan.)
- `docs/decisions/` holds **ADRs** — the durable decision index. Format: `github-operations.md`.
- `docs/product/` holds **dossiers** — one per capability, versioned. Owned by `/samuel:feature-dossier`.
- `CLAUDE.md` (root / module / `.claude.local.md`) holds **operating guidance for agents** — project-wide gotchas, discovered commands, config/env quirks, conventions or re-architectures that change *how* future sessions work here.
- `README.md` holds the **human front door** — what the project is, how to install / configure / run / use it. Structure + philosophy + promotion filter: `reference/readme-guidelines.md`.
- `REVIEW.md` / `CONSTITUTION.md` (root) hold the **substrate rules** — reviewer overrides (schema v1) and non-negotiable principles. The pipeline reads them at its gates. At close, `/samuel:done` may *propose* a REVIEW.md bullet on the branch; constitution amendments always route through `/samuel:update-constitution` (semver + Sync Impact Report), never a drive-by edit.

Each home answers a different question: an ADR records a *decision* (why), a dossier describes a *capability* (what), `CLAUDE.md` *instructs the agent* (how to work here), `README.md` *onboards a human* (how to start), `REVIEW.md`/`CONSTITUTION.md` *bind the reviewer and the pipeline* (what may not slip). `/samuel:done` scans the journal + session at close and proposes promotions to the right home (forced checkpoint, never auto-edit; autonomous runs only list candidates).

What stays in the tracker (never a file): **ephemeral, task-scoped** signals — status labels, the Brief + Executor Plan (Issue body), task-level decision comments, the validation-summary comment. The durable layer is always committed to the repo.

**Discovery (the roadmap)** also lives in the tracker: bets are `roadmap:now|next|later` issues — *they* are the SoT for "what to build next" (mutually exclusive with `pipeline:*` on an issue; committing a bet swaps `roadmap:*` for `pipeline:triage`). An optional `docs/product/ROADMAP.md` is a **projection** regenerated from those issues, never the source. Owned by `/samuel:roadmap`; mindset in `reference/product-ownership.md`.

## Legacy contexts

A `.claude/task-context.md` (or `.claude/samuel.md`) whose `tracker` key is anything other than `github` is a **pre-migration context**, not a supported mode. A pipeline skill that meets one stops and offers the migration path: write `.claude/samuel.md` with `tracker: github` + `repo`, and re-capture any open work as Issues (`gh issue create`, Brief from the old task body). Never silently fall back to another storage backend.

## How a skill uses this

1. Resolve `repo` + `item` from `.claude/task-context.md` (or `.claude/samuel.md` pre-task) — surface them in `## Context`.
2. Open `reference/github-operations.md` for the exact `gh` invocation.
3. The *process* (research → plan → implement → validate → done, human checkpoints, the committed journal) is the pipeline's; the adapter only says where state lives.

## Gotchas

_Add a line each time Claude trips on something._

- `gh` needs `repo` (owner/name) explicitly — the SSH alias breaks origin parsing. See `github-operations.md`.
- No `gh` available or unauthenticated: stop and tell the user to install/auth `gh`. There is no offline tracker fallback (ADR 0002) — offline work continues on the branch; item state syncs when back online.
- Don't store `repo` only in `task-context.md` — pre-task skills (`next`, `progress`, `kickoff`) need it from `.claude/samuel.md`.
- The journal and `validation.md` are **committed files** — a skill that writes them into the tracker is wrong. Files are the durable layer; the tracker holds only ephemeral, task-scoped state.
