# `.claude/task-context.md` — Frontmatter Contract

The pipeline extends `.claude/task-context.md` (created by `/samuel:start-task`) with YAML frontmatter that captures the active feature's state across skills. The frontmatter is the single source of truth for the feature slug, feature dir, and pipeline phase.

This is a **solo-developer** contract. Work items are **GitHub Issues** (`reference/tracker.md`; single-tracker per ADR 0002). The worktree, the feature dir, and the GitHub PR/Issue are the surviving records.

## Schema

```yaml
---
tracker: github                        # always "github" — anything else marks a legacy context (ADR 0002)
repo: owner/name                       # explicit owner/name for gh (NEVER parsed from the SSH-alias origin)
item: 42                               # GitHub issue number
feature_slug: menu-import              # kebab-case, derived from the item title
feature_dir: docs/features/menu-import # committed, rides the branch
branch: feat/42-menu-import            # {type}/<item>-<slug>
phase: setup                           # see Phase Values below
spec_required: false                   # whether /samuel:spec should run (default false)
constitution: none                     # path to CONSTITUTION.md, "none" if absent
created: 2026-05-21
last_updated: 2026-05-21
---
```

The frontmatter MUST appear at the top of the file before any prose. Existing task-context body content follows as-is after the closing `---`. `repo` is copied from `.claude/samuel.md` (repo config) by `/samuel:start-task` so the rest of the pipeline reads a single file.

**Legacy contexts (ADR 0002):** a task-context with `tracker: backlog` — or with no `tracker` key — is pre-migration. Pipeline skills MUST NOT execute over it: stop and offer the migration path (`reference/tracker.md` § Legacy contexts).

`spec_required` defaults to `false`: bugs and small features go straight from `/samuel:start-task` to `/samuel:plan`. Set it `true` only for features where capturing WHAT/WHY before HOW pays off.

`constitution` defaults to `none`: the pipeline degrades gracefully when there is no `CONSTITUTION.md`. When present, plan/implement/validate run a lightweight Constitution Check.

## Phase Values

| Phase | Set by | Meaning |
|---|---|---|
| `setup` | `/samuel:start-task` | Worktree ready, no artifacts yet |
| `research` | `/samuel:codebase-documentation` | Research doc drafted |
| `spec` | `/samuel:spec` | Spec doc drafted (only when `spec_required`) |
| `plan` | `/samuel:plan` | Plan doc drafted |
| `analyze` | `/samuel:analyze` | Cross-artifact analysis complete |
| `implement` | `/samuel:implement` | Implementation in progress |
| `validate` | `/samuel:validate` | Validation report produced |
| `end` | `/samuel:done` | Closing the loop |

Skills MUST update `phase` and `last_updated` when they advance the pipeline.

## Reading the Contract

Skills read frontmatter values in their `## Context` section using `!` inline bash commands.

**CRITICAL — no shell expansion.** Claude Code's permission checker rejects any inline `!` command containing shell expansion: command substitution `$(...)` / backticks, parameter expansion `${v:-default}`, or a variable `$VAR`. It fails with `Contains expansion` and the command never runs — a `|| echo` fallback does NOT rescue it. The old `v=$(grep ...); echo "${v:-X}"` pattern is therefore forbidden. Every inline command MUST be `$`-free.

### Extracting a single field (expansion-free)

`awk` does the match, trim, and default in one pass with no shell `$`. The awk program is single-quoted, so its braces and regex never reach the shell:

```markdown
## Context

- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- Phase: !`awk '/^phase:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_PHASE"}' .claude/task-context.md 2>/dev/null || echo "NO_PHASE"`
- Constitution: !`awk '/^constitution:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"none"}' .claude/task-context.md 2>/dev/null || echo "none"`
```

`item` holds the GitHub issue number. Skills that predate this contract may still read `task_id`; treat `item` as canonical.

Why it covers every case: the regex matches the key line and `sub(/^[^:]*: */,"")` strips the `key: ` prefix (preserving any colons inside the value); `f=1` records a hit; the `END` block prints the sentinel when the key is absent; the trailing `|| echo` prints the sentinel when the file itself is missing (awk exits non-zero). Output is always exactly one line. Declare `Bash(awk *)` in `allowed-tools`.

> **Why not `grep ... | cut | xargs || echo "X"`?** A pipe ending in `xargs` (or `cut`, or `tr`) exits 0 with empty input, so the trailing `||` never fires when the file or key is missing — you get an empty string instead of the sentinel. Capturing into a variable then defaulting with `${v:-X}` fixes the emptiness but is banned as expansion. The awk `END` block solves both at once: correct default, zero shell `$`.

### Compound checks (does a doc exist?) — resolve in the body, not the shell

A check like "Spec doc present: yes/no" needs the slug interpolated into a path (`docs/features/<slug>/spec.md`), which requires a shell `$` and is therefore banned from inline commands. Do NOT try to compute it in `## Context`. Expose the slug via the `Feature:` line above, then let the skill body check the file with `Read`/`Glob` after resolving `{slug}`. Example body wording:

> If `Feature` is set, check whether `docs/features/{slug}/spec.md` exists; if so, ask iterate/overwrite/abort.

This is more robust than a glob (`features/*/spec.md` can't stay feature-specific on a multi-feature `main` checkout) and keeps the shell expansion-free.

## Writing the Contract

Skills update frontmatter via the `Edit` tool on `.claude/task-context.md`. The update MUST be atomic and surgical: change only the keys that the skill owns, do not rewrite the entire file.

Required pattern when updating:

1. Skill reads current frontmatter (via Context section or explicit Read).
2. Skill computes new value (e.g., `phase: plan` instead of `phase: research`).
3. Skill calls `Edit` with the old/new line pair for that single key.
4. Skill also updates `last_updated` to today's ISO date in the same Edit batch.

## Lifecycle

| Stage | Action |
|---|---|
| **Create** | `/samuel:start-task` writes the full frontmatter when the worktree is initialized. |
| **Update** | Each pipeline skill updates `phase` and `last_updated` when it runs. Other keys (`tracker`, `repo`, `item`, `spec_required`, `constitution`) are stable for the feature's lifetime. |
| **Archive** | `/samuel:done` reads the feature dir (spec, plan, research, journal, validation) to synthesize the PR body and final summary before cleanup. |
| **Delete** | `git worktree remove` deletes `.claude/task-context.md` along with the worktree. The GitHub PR + repo `CONSTITUTION.md` are the surviving record. |

> **Delete only happens in worktree mode.** In a plain checkout nothing removes the file: it survives the merge still pointing at the finished item, and `phase: end` is indistinguishable from a task in progress. So **`phase: end` is a staleness signal, not a state** — a skill that reads `item` while the phase is `end` MUST verify the item is still open (`gh issue view {item} --json state`) before acting on it. A `CLOSED` item means orphaned context: re-resolve from the branch or ask, never trust the file. This is how `/samuel:done` came within one step of composing `Closes #25` for the work of #37.

## Compatibility

Skills that predate this contract (or run standalone, outside a feature) MUST treat the frontmatter as optional. If `.claude/task-context.md` is absent or has no `feature_slug`, fall back to standalone behavior — resolve `repo` via `.claude/samuel.md` (see `reference/tracker.md`), and write committed artifacts (journal, validation) under `docs/features/<slug>/`.
