---
name: start-task
description: Pick a work item (GitHub Issue), create a branch, and inject task context. Use when a dev is ready to start implementing an item.
allowed-tools: Bash(git branch *) Bash(git config *) Bash(git status *) Bash(git checkout *) Bash(git stash *) Bash(git rev-parse *) Bash(git worktree *) Bash(gh *) Bash(awk *) Bash(test *) Bash(printenv *) Bash(which *) Bash(orca repo *) Bash(orca worktree *) Bash(jq *) Read Write Edit AskUserQuestion
---

# Start Task

Pick a work item, prepare the dev environment (branch/worktree), and inject pipeline state. The step between picking work and planning/implementing it. The SoT is GitHub Issues (`reference/tracker.md`).

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
> **Autonomy:** which gates below auto-advance, and what gets announced instead of asked — `../../reference/autonomy.md`. An **unattended** run — headless `claude -p`, CI, or `/samuel:conductor` — is `autonomous` and ignores the `Autonomy:` value in Context.

## Pipeline Position

```
/samuel:next → /samuel:start-task → /samuel:plan ⇄ /samuel:refine-plan → /samuel:implement → /samuel:validate → /samuel:done
                     ↑
               YOU ARE HERE
```

## Critical Rules

1. **Never create a branch without user confirmation** — present detected values and wait. The wait is skipped under `/samuel:conductor` autonomous bootstrap, and under `attended-auto`, which announces the mode and reason instead of asking (`../../reference/autonomy.md` § Which gates move). Renaming the branch stays a question at every level.
2. **The Issue is the source of truth** — item details come from it, not from memory.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Autonomy: !`awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)exit 1}' .claude/samuel.md 2>/dev/null || awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)print"interactive"}' ~/.claude/samuel.md 2>/dev/null || echo "interactive"`
- Working tree: !`git status --porcelain 2>/dev/null || echo ""`
- Repo (repo config): !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Legacy tracker key: !`awk '/^tracker:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"none"}' .claude/samuel.md 2>/dev/null || echo "none"`
- gh default repo: !`gh repo set-default --view 2>/dev/null || echo "NONE"`
- CWD: !`pwd`
- Worktrees: !`git worktree list 2>/dev/null || echo ""`
- CI runner: !`printenv GITHUB_ACTIONS 2>/dev/null || echo "false"`
- Orca worktree: !`printenv ORCA_WORKTREE_ID 2>/dev/null || echo "none"`
- Orca CLI: !`which orca >/dev/null 2>&1 && echo "present" || echo "none"`

> **Tracker**: `../../reference/tracker.md`. Adapter: `../../reference/github-operations.md`.
> **Pipeline state**: this skill bootstraps `.claude/task-context.md` — see `../../reference/task-context.md`.

---

## Step 0: RESOLVE REPO

If `Legacy tracker key` is anything other than `github` or `none`, STOP — pre-migration context; point at `reference/tracker.md` § Legacy contexts.

Ensure `Repo` is known. If `NO_REPO` and no `gh default repo`, ask for `owner/name`, run `gh repo set-default owner/name`, and offer to write `.claude/samuel.md` (with `tracker: github` + `repo`) so future runs are deterministic. Verify access: `gh repo view owner/name`. One-time per repo: create the pipeline labels (see `github-operations.md` label block) if missing.

## Step 1: IDENTIFY THE ITEM

**Parameter** = the Issue number (`42`). If none provided, route to `/samuel:next`.

Load the Issue (`gh issue view {item} -R {repo} --json title,body,labels,comments`) and extract:

- **Title, Type** (from `type:*` label / title), **Priority**
- **Brief** — TL;DR, Scope, Acceptance Criteria
- **Plan presence** — is the Executor Plan section filled? (`pipeline:planned` label / non-stub `<!-- samuel:plan -->` body.) If absent, note that `/samuel:plan` runs next.
- **Dependencies** — "Depends on:" in the Brief / linked issues. **Verify all are closed.** If a blocker is open, stop and report.
- **Comments** — scan for `**Decision` records and `**Upstream decision` impact notices (§ Blast radius): standing constraints on the plan; they feed the drift check below.
- **Plan drift** (when a plan exists): `git log --oneline` since the plan was written, over the files the plan names — any hit is drift evidence. **Decision drift**: a `**Decision`/`**Upstream decision` comment postdating the plan and not folded into it is drift too, even when no named file moved — the map changed upstream, not the territory. Same escalation path. *Interactive*: surface it and suggest `/samuel:find-unknowns {item}` (preflight). *Autonomous bootstrap*: drift **escalates** to the preflight — `READY` proceeds recording the accepted drift; `HOLD` refuses the pickup (clean exit, unknowns recorded). Never execute a plan unattended once its map no longer holds.

## Step 2: PREPARE ENVIRONMENT

### Dirty working tree

If "Working tree" is non-empty: offer **1) stash** (`git stash push -m "auto-stash before {item}"`) or **2) abort to commit first**. **WAIT.** (Autonomous bootstrap: stash automatically and record it.)

### Branch / worktree

Determine type from the item's `type:*` label or title (`feat`/`fix`/`refactor`/`perf`/`chore`/`docs`/`test`; default `feat`).

Proposed branch: **`{type}/{item}-{slug}`** (e.g. `feat/42-menu-import`).

```
Proposed branch: {branch}
Mode: 1) branch (git checkout -b)   2) worktree (isolated — required for autonomous runs)
Create it? (Y / Rename / choose mode)
```

**WAIT for confirmation.** (Autonomous bootstrap: default to **worktree** — the conductor's safety gate requires isolation.) (attended-auto: take the mode the context recommends and announce it with its reason — **branch** when the repo needs no dependency install and no session is live in a worktree, **worktree** otherwise. Not a fixed worktree: that is the conductor's SAFETY GATE talking, and an attended run that lands in a worktree costs a new session in another path — more friction, not less. Renaming the branch stays a question at every level.)

**Isolation is per environment.** The Context block detects which one hosts the session; the mechanism follows from it. Recipe and rationale: `../../reference/worktree-isolation.md`.

| Environment | Signal in Context | Mechanism |
|---|---|---|
| CI runner | `CI runner: true` | Branch in place, **never** `git worktree add` |
| Orca | `Orca worktree` and `Orca CLI` both ≠ `none` | `orca worktree create` — then normalize the branch it returns |
| Local | neither of the above | `EnterWorktree` where the harness exposes it, otherwise `git worktree add` |

**The table governs worktree mode only** — it says *how* to make a worktree once one is wanted, not whether to. Branch mode stays the interactive default and still means a branch in the current checkout. Codex has no `EnterWorktree`, which is why the Local row names `git worktree add` as the mechanism there.

CI is evaluated first — a runner is a runner even when an environment leaks `ORCA_*` into it. Orca needs both signals because either alone lies: `ORCA_*` is inherited by child shells, and the CLI on the `PATH` proves installation, not membership.

**In CI (`GITHUB_ACTIONS=true`):** skip the worktree — create the branch in the current checkout (`git checkout -b {branch}`). The ephemeral runner + a dedicated branch are the isolation the conductor SAFETY GATE accepts (see `../../reference/automated-trigger.md`); `gh` authenticates via the runner's `GH_TOKEN`, no interactive login.

**In Orca:** resolve the repo id by **path** (`--repo name:` matches Orca's `displayName`, not the GitHub repo), create with `--issue {item}`, then rename the returned branch with the **two-argument** `git branch -m {created} {wanted}`. The one-argument form renames the *calling* checkout's branch and succeeds silently. Full recipe: `../../reference/worktree-isolation.md`. If the create fails, **stop and report** — never fall back to the local mechanism.

```bash
# branch mode (and CI):
git checkout -b {branch}
# worktree mode, local:
git worktree add ../{repo}-{item} {branch}
# worktree mode, Orca: see reference/worktree-isolation.md
```

## Step 3: LABEL SETUP (first item of a new repo)

Ensure pipeline + `roadmap:*` + `type:*`/`priority:*` + `promo:*` labels exist (idempotent `gh label create --force`, full block in `../../reference/github-operations.md` § Labels). Skip whatever already exists.

## Step 4: INJECT CONTEXT

### Spec requirement

Ask once (default `false`): does this warrant a spec (WHAT/WHY before HOW)? Map to `spec_required: true|false`. (Autonomous bootstrap: respect a `spec_required` hint on the item; else `false`.) (attended-auto: same rule — honour a `spec_required` hint on the item, else `false`, announced in the setup summary. Nothing is lost by defaulting low: `/samuel:spec` runs standalone whenever the plan turns out to need it.)

### Write `.claude/task-context.md`

Derive `feature_slug` (kebab-case from the item title) and `feature_dir` = `docs/features/{slug}`. Detect `CONSTITUTION.md` at repo root → that path, else `none`.

```markdown
---
tracker: github
repo: {owner/name}
item: {42}
feature_slug: {slug}
feature_dir: docs/features/{slug}
branch: {branch}
phase: setup
spec_required: {true|false}
constitution: {CONSTITUTION.md | none}
created: {today ISO}
last_updated: {today ISO}
---

# Task Context

## Item
- **Id**: {item}  ·  **Type**: {type}  ·  **Priority**: {priority}
- **Title**: {title}

## Brief
{TL;DR / Scope / Acceptance Criteria from the item}

## Plan
{"Planned — see the Issue's Executor Plan section" OR "Not planned yet — run /samuel:plan"}
```

Create `.claude/` first if missing. The frontmatter MUST be at the very top — pipeline skills read it.

### Mark in-progress

`gh issue edit {item} -R {repo} --add-label pipeline:in-progress --remove-label pipeline:ready` (+ assign self).

## Step 5: PRESENT

```
Item ready: #{item} — {title}
Branch: {branch}   ·   Feature: {slug}   ·   Phase: setup   ·   spec_required: {bool}
Context: .claude/task-context.md

Next:
{if not planned:}  /samuel:plan          — write the Brief + Executor Plan
{if spec_required:} /samuel:spec          — capture WHAT/WHY first
- Understand the code: /samuel:codebase-documentation
- Autonomous run (worktree): /samuel:conductor
```

## Rules

- **Clean starts.** Always start from a clean working tree. Stash or commit first.
- **Branch naming.** `{type}/{item}-{slug}`, consistently.
- **Context injection.** Always write `.claude/task-context.md` — it's the handoff to future/headless sessions.
- **Status tracking.** Mark in-progress immediately so `/samuel:progress` reflects reality.

## Gotchas

_Add a line each time Claude trips on something._

- Never parse the origin remote for owner/repo (SSH alias breaks it) — use the stored `repo` + `gh repo set-default`.
- `.claude/` may not exist — create it before writing `task-context.md` or `samuel.md`.
- Worktree mode changes the CWD — remind the user to open a new session at the worktree path. Autonomous runs REQUIRE worktree isolation.
- **`git branch -m {name}` renames the CALLER, not the new worktree** — `orca worktree create` does not move the session, so the one-argument form retargets whatever the calling checkout has out, and succeeds silently because the wanted name is free. A pickup from a main checkout renames `main` and reports success. Always the two-argument form.
- **Orca renames the branch it creates** — it prefixes the `gitUsername` recorded on the repo (`orca repo list`) and collapses `/` to `-`. Read the real branch from the `--json` `result.worktree.branch`; reconstructing the rule breaks the next time the setting differs.
- **Orca errors return `ok:false` with exit code `0`** — branch on `.ok`, never on `$?`.
- **`ORCA_*` variables are inherited by child shells**, so the env var alone never proves the runtime is reachable — that is why detection needs the binary too.
- **`which` writes "not found" to stdout in zsh**, not stderr, so `2>/dev/null || echo "none"` leaks a second line in the branch the fallback exists for. Probe with `which x >/dev/null 2>&1 && echo "present" || echo "none"`.
- Label creation is one-shot per repo — skip if already present.
- `spec_required` defaults to `false`. Only `true` when capturing WHAT/WHY genuinely de-risks the work.
- `gh repo set-default --view` prints the resolved repo or errors — the `|| echo NONE` keeps Context clean.
- **Comments are part of the pickup contract** — an `Upstream decision` comment postdating the plan is drift (semantic, not file-based). Don't pick up on the body alone.
