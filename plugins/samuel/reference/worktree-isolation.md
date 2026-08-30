# Worktree Isolation — the mechanism per environment

A pickup needs an isolated checkout. *How* one is made depends on what is running the session, and the three answers are not interchangeable: each environment owns a mechanism that keeps the checkout inside the system that will later have to operate it. `/samuel:start-task` Step 2 holds the dispatch table; this file holds the recipe the table points at.

## Detection — two signals, never one

| Environment | Signal | Mechanism |
|---|---|---|
| CI runner | `GITHUB_ACTIONS` is set | Branch in place. **Never** a worktree — the runner's checkout already is the isolation the conductor SAFETY GATE accepts (`automated-trigger.md`), and a worktree on a shallow clone fails on the checkout depth. |
| Orca | `ORCA_WORKTREE_ID` is set **and** `orca` is on the `PATH` | `orca worktree create` — recipe below. |
| Local | neither of the above | `EnterWorktree` where the harness exposes it (Claude Code), otherwise `git worktree add`. Governs worktree mode only. |

CI is evaluated first: a runner is a runner even if an environment leaks Orca variables into it.

**Orca needs both signals because either alone lies.** `ORCA_*` variables are inherited by child shells, so a process launched from Orca but running where the runtime is not reachable still carries them; `orca` on the `PATH` only proves the CLI is installed, not that this session belongs to a managed worktree. A false positive sends the checkout to a runtime that is not running, which is the failure the guardrail exists to prevent. Both Context lines are declared in `plugins/samuel/skills/start-task/SKILL.md:4` — CLAUDE.md § Shell Commands for Runtime Context requires every injected binary to appear there.

## The Orca recipe

### 1. Resolve the repo by path, never by name

```bash
orca repo list --json | jq -r '.result.repos[] | select(.path == "{ABS_REPO_PATH}") | .id'
```

`--repo name:` matches Orca's `displayName`, not the GitHub repo name, and one GitHub repo may back several Orca checkouts — so the name selector can resolve to the wrong workspace or to nothing. Resolve to `{ORCA_REPO_ID}` and pass `--repo id:{ORCA_REPO_ID}` everywhere after. Empty output means the repo is not registered in Orca: stop, do not create.

Never omit the selector either. Orca then infers the repo from the current worktree, and a session carrying an inherited `ORCA_*` environment from another repo would build the checkout in that repo — the one thing this file's doctrine forbids.

**Orca errors return `ok:false` with exit code `0`.** Branch on `.ok` in the JSON, never on `$?`; a shell that trusts the exit code reads every failure as success.

### 2. Predict the destination before CONFIRM

`orca worktree list --repo id:{ORCA_REPO_ID} --json` returns this repo's managed worktrees with their `path`. Skip every entry whose `isMainWorktree` is `true`: a main worktree's parent is wherever the developer keeps their checkouts (`~/Developer`), not a workspace root. The parent of a **non-main sibling's** path is this repo's workspace root (`~/orca/workspaces/{repo}/`).

Name that root plus the intended leaf in the CONFIRM block. With no non-main sibling yet, name the root pattern and say it is predicted, not read — CONFIRM must not assert a path nobody verified.

### 3. Create

```bash
orca worktree create --repo id:{ORCA_REPO_ID} --name {type}/{N}-slug --base-branch origin/{default} --issue {N} --json
```

- `--issue {N}` links the Issue in Orca's metadata, and makes `issue:{N}` a valid worktree selector for the rest of the run. The traceability triangle stops depending on a naming convention: the card carries the link whatever the branch ends up called.
- `--base-branch origin/{default}` is explicit on purpose. Omitting it falls back to the repo's recorded `worktreeBaseRef`, and a stale one produces a checkout hundreds of commits behind with nothing in the output saying so.
- Orca records the new worktree as a child of the calling context when it can infer one. Pass `--no-parent` only for work genuinely unrelated to the current worktree. (`/samuel:waves` passes it always — each wave worktree is top-level by design.)

### 4. Normalize the branch — this step is not optional

**Orca renames the branch it creates.** It prefixes the `gitUsername` recorded on the repo (visible in `orca repo list`) and collapses `/` to `-`, so `--name feat/42-menu-import` produces a branch like `samosuna/feat-42-menu-import`.

Do not reconstruct that rule — read the result. The `--json` output carries the branch actually created at `result.worktree.branch` (a full ref, e.g. `refs/heads/samosuna/feat-42-...`) and the checkout at `result.worktree.path`. Strip the `refs/heads/` prefix, then rename with the **two-argument** form:

```bash
git branch -m {created branch, without refs/heads/} {type}/{N}-slug
```

**The one-argument form renames the caller, not the new worktree.** `orca worktree create` does not move the calling session — the CLI creates the worktree and its terminal without switching the active view. `git branch -m {new-name}` therefore renames whatever branch the *calling* checkout has out, and because the target name is always free (Orca created a differently-prefixed one), it succeeds silently with exit 0 instead of erroring. A pickup started from a main checkout renames `main` and reports success.

Orca tracks the worktree by path and reads the branch from git, so the rename does not disturb its metadata: the card keeps its `linkedIssue` and its `displayName` keeps the requested name. Without this step the branch breaks the Issue ↔ branch ↔ dir ↔ PR format the whole pipeline navigates by.

### 5. When the create fails

**Stop and report. Do not fall back to the local mechanism.** Inside Orca the local path lands the checkout outside the app that manages every other worktree on the machine — the orphaned state this whole file exists to prevent — so degrading there turns a visible failure into a silent one. Print what the CLI said and let the human choose. A pickup that degrades after announcing Orca in CONFIRM also makes that block a lie.

Never leave the pickup half-done: either a worktree exists and the task-context names it, or the pickup stopped and said why.

## What this file does not cover

`/samuel:waves` carries its own Orca protocol (`skills/waves/references/wave-protocol.md`) — it dispatches many worktrees per run with different defaults (`--no-parent` always, no branch normalization, an `--agent` selector) and it resolves the repo id in its own preflight. `/samuel:conductor` inherits whatever the pickup made. Consolidating either onto this table is separate work; the mechanism lives here so that adoption is a pointer, not a copy.
