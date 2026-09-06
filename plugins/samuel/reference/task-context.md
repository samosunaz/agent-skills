# `.claude/task-context/{item}.md` — Frontmatter Contract

The pipeline keeps one state file **per work item**, `.claude/task-context/{item}.md` (created by `/samuel:start-task`, `{item}` = the GitHub issue number), whose YAML frontmatter captures that item's state across skills. The frontmatter is the single source of truth for the feature slug, feature dir, and pipeline phase.

**Why a folder and not one file.** A checkout routinely hosts several sessions on different items at once (five or more coordinator and pipeline sessions in one primary checkout is the owner's normal day). One `.claude/task-context.md` per checkout was overwritten by whichever session wrote last, and a skill then read another session's item. Naming the file after the item makes a collision impossible by construction; resolving *which* file is this session's is the reader's job (§ Reading the Contract).

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

The frontmatter MUST appear at the top of the file before any prose. Existing task-context body content follows as-is after the closing `---`. The file name is the item number and nothing else (`.claude/task-context/42.md`); `item:` inside repeats it so the file is self-describing when read directly. `repo` is copied from `.claude/samuel.md` (repo config) by `/samuel:start-task` so the rest of the pipeline reads a single file.

**Legacy contexts (ADR 0002):** a task-context whose `tracker` key is anything other than `github` is pre-migration. Pipeline skills MUST NOT execute over it: stop and offer the migration path (`reference/tracker.md` § Legacy contexts).

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

### Resolving the item's file, then extracting a field (expansion-free)

Every read is one `awk` call carrying the **canonical resolver** below (byte-identical in every skill — `scripts/lint-skill-context.sh` rule 4 rejects a drifted copy) plus two `-v` variables: `k` = the key, `d` = the sentinel printed when the key or the file is missing. The resolver picks the file without any shell `$`:

1. the number in the current branch name (`feat/42-menu-import`, `issue-42-slug`, `42-impl-codex` all resolve to `42.md`);
2. else, if exactly one file exists under `.claude/task-context/`, that file;
3. else the legacy `.claude/task-context.md`, read but never written (§ Compatibility);
4. else the sentinel.

```markdown
## Context

- Repo: !`awk -v k=repo -v d=NO_REPO 'BEGIN{"git branch --show-current"|getline b;if(match(b,/[0-9]+/))f=".claude/task-context/"substr(b,RSTART,RLENGTH)".md";n=0;while(("ls .claude/task-context/ 2>/dev/null"|getline g)>0){n++;o=".claude/task-context/"g}if(f==""||(getline t<f)<0){close(f);f=(n==1)?o:".claude/task-context.md"}close(f);while((getline l<f)>0)if(l~"^"k":"){sub(/^[^:]*: */,"",l);print l;x=1}if(!x)print d}' 2>/dev/null || echo "NO_REPO"`
- Item: !`awk -v k=item -v d=NO_ITEM 'BEGIN{"git branch --show-current"|getline b;if(match(b,/[0-9]+/))f=".claude/task-context/"substr(b,RSTART,RLENGTH)".md";n=0;while(("ls .claude/task-context/ 2>/dev/null"|getline g)>0){n++;o=".claude/task-context/"g}if(f==""||(getline t<f)<0){close(f);f=(n==1)?o:".claude/task-context.md"}close(f);while((getline l<f)>0)if(l~"^"k":"){sub(/^[^:]*: */,"",l);print l;x=1}if(!x)print d}' 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk -v k=feature_slug -v d=NO_FEATURE 'BEGIN{"git branch --show-current"|getline b;if(match(b,/[0-9]+/))f=".claude/task-context/"substr(b,RSTART,RLENGTH)".md";n=0;while(("ls .claude/task-context/ 2>/dev/null"|getline g)>0){n++;o=".claude/task-context/"g}if(f==""||(getline t<f)<0){close(f);f=(n==1)?o:".claude/task-context.md"}close(f);while((getline l<f)>0)if(l~"^"k":"){sub(/^[^:]*: */,"",l);print l;x=1}if(!x)print d}' 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk -v k=feature_dir -v d=NO_DIR 'BEGIN{"git branch --show-current"|getline b;if(match(b,/[0-9]+/))f=".claude/task-context/"substr(b,RSTART,RLENGTH)".md";n=0;while(("ls .claude/task-context/ 2>/dev/null"|getline g)>0){n++;o=".claude/task-context/"g}if(f==""||(getline t<f)<0){close(f);f=(n==1)?o:".claude/task-context.md"}close(f);while((getline l<f)>0)if(l~"^"k":"){sub(/^[^:]*: */,"",l);print l;x=1}if(!x)print d}' 2>/dev/null || echo "NO_DIR"`
- Phase: !`awk -v k=phase -v d=NO_PHASE 'BEGIN{"git branch --show-current"|getline b;if(match(b,/[0-9]+/))f=".claude/task-context/"substr(b,RSTART,RLENGTH)".md";n=0;while(("ls .claude/task-context/ 2>/dev/null"|getline g)>0){n++;o=".claude/task-context/"g}if(f==""||(getline t<f)<0){close(f);f=(n==1)?o:".claude/task-context.md"}close(f);while((getline l<f)>0)if(l~"^"k":"){sub(/^[^:]*: */,"",l);print l;x=1}if(!x)print d}' 2>/dev/null || echo "NO_PHASE"`
- Constitution: !`awk -v k=constitution -v d=none 'BEGIN{"git branch --show-current"|getline b;if(match(b,/[0-9]+/))f=".claude/task-context/"substr(b,RSTART,RLENGTH)".md";n=0;while(("ls .claude/task-context/ 2>/dev/null"|getline g)>0){n++;o=".claude/task-context/"g}if(f==""||(getline t<f)<0){close(f);f=(n==1)?o:".claude/task-context.md"}close(f);while((getline l<f)>0)if(l~"^"k":"){sub(/^[^:]*: */,"",l);print l;x=1}if(!x)print d}' 2>/dev/null || echo "none"`
```

`item` holds the GitHub issue number. Skills that predate this contract may still read `task_id`; treat `item` as canonical.

How it stays expansion-free: the `git branch` and `ls` calls run **inside** awk (`"cmd" | getline`), so the shell sees only `awk`, `echo` and quoted strings; `match()` + `substr()` pull the number out of the branch; `getline < f` reads the chosen file line by line; `sub(/^[^:]*: */,"",l)` strips the `key: ` prefix; `x=1` records a hit and `print d` is the sentinel when nothing matched; the trailing `|| echo` covers awk itself failing. Output is always exactly one line. Declare `Bash(awk *)` in `allowed-tools` — `git` and `ls` never reach the permission engine because they are inside the awk program text.

**On a branch with no number and several context files** (a shared `main` with five items in flight) the read prints the sentinel on purpose: nothing in the environment says which item this session is, so the skill asks or takes an explicit argument rather than guessing. A skill that takes an item argument reads `.claude/task-context/{arg}.md` directly with `Read` after Context ran.

> **Why not `grep ... | cut | xargs || echo "X"`?** A pipe ending in `xargs` (or `cut`, or `tr`) exits 0 with empty input, so the trailing `||` never fires when the file or key is missing — you get an empty string instead of the sentinel. Capturing into a variable then defaulting with `${v:-X}` fixes the emptiness but is banned as expansion. The awk program solves both at once: correct default, zero shell `$`.

### Compound checks (does a doc exist?) — resolve in the body, not the shell

A check like "Spec doc present: yes/no" needs the slug interpolated into a path (`docs/features/<slug>/spec.md`), which requires a shell `$` and is therefore banned from inline commands. Do NOT try to compute it in `## Context`. Expose the slug via the `Feature:` line above, then let the skill body check the file with `Read`/`Glob` after resolving `{slug}`. Example body wording:

> If `Feature` is set, check whether `docs/features/{slug}/spec.md` exists; if so, ask iterate/overwrite/abort.

This is more robust than a glob (`features/*/spec.md` can't stay feature-specific on a multi-feature `main` checkout) and keeps the shell expansion-free.

## Writing the Contract

Skills update frontmatter via the `Edit` tool on `.claude/task-context/{item}.md` — the file the resolver chose, or the one named by the skill's item argument. The update MUST be atomic and surgical: change only the keys that the skill owns, do not rewrite the entire file.

Required pattern when updating:

1. Skill reads current frontmatter (via Context section or explicit Read).
2. Skill computes new value (e.g., `phase: plan` instead of `phase: research`).
3. Skill calls `Edit` with the old/new line pair for that single key.
4. Skill also updates `last_updated` to today's ISO date in the same Edit batch.

## Lifecycle

| Stage | Action |
|---|---|
| **Create** | `/samuel:start-task` writes the full frontmatter to `.claude/task-context/{item}.md` (`mkdir -p .claude/task-context` first) when the worktree is initialized. |
| **Update** | Each pipeline skill updates `phase` and `last_updated` when it runs. Other keys (`tracker`, `repo`, `item`, `spec_required`, `constitution`) are stable for the feature's lifetime. |
| **Archive** | `/samuel:done` reads the feature dir (spec, plan, research, journal, validation) to synthesize the PR body and final summary before cleanup. |
| **Delete** | `/samuel:done` removes `.claude/task-context/{item}.md` once the PR is open — safe now that the file holds one item and nothing else — and `git worktree remove` takes the folder with the worktree. The GitHub PR + repo `CONSTITUTION.md` are the surviving record. |

> **`phase: end` is still a staleness signal, not a state.** `done` deletes the file, but a crash between the PR and the cleanup, or a file written by an older plugin, leaves one behind. A skill that reads `item` while the phase is `end` MUST verify the item is still open (`gh issue view {item} --json state`) before acting on it. A `CLOSED` item means orphaned context: delete the file, re-resolve from the branch or ask, never trust it. This is how `/samuel:done` once came within one step of composing a `Closes` line for the wrong issue.

## Compatibility

**Legacy single file.** A `.claude/task-context.md` left by an older plugin is read by the resolver as the last fallback and never written. `/samuel:start-task` migrates it on sight: move it to `.claude/task-context/{item}.md` (the `item:` inside names the target) and say so in one line. Nothing else reads the old path.

Skills that predate this contract (or run standalone, outside a feature) MUST treat the frontmatter as optional. If no task-context resolves or it has no `feature_slug`, fall back to standalone behavior — resolve `repo` via `.claude/samuel.md` (see `reference/tracker.md`), and write committed artifacts (journal, validation) under `docs/features/<slug>/`.
