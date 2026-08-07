---
name: waves
description: "Attended multi-issue coordinator: executes a set of pipeline:ready issues in parallel waves computed from GitHub's native blockedBy graph — one Orca worktree + worker per issue (Codex default, claude-conductor variant), draft PRs, human merge releases the next wave. Trigger on 'waves', 'launch waves', 'run the epic', 'run the epic in parallel', 'wave run'."
allowed-tools: Bash(orca *) Bash(gh *) Bash(git fetch *) Bash(git branch *) Bash(git status *) Bash(jq *) Bash(sed *) Bash(tail *) Bash(head *) Bash(awk *) Bash(grep *) Bash(xargs *) Bash(test *) Bash(date *) Bash(cat *) Bash(ls *) Read Edit Write Skill AskUserQuestion PushNotification
---

# Waves (Multi-Issue Wave Coordinator)

Executes a **set** of planned issues as parallel waves over Orca: reads the native `blockedBy` graph, dispatches one isolated worker per unblocked issue, supervises to draft PRs, and — after the **human** merges — recomputes blockers and launches the next wave from fresh `origin/main`. Parallelism comes from the dependency graph, not the item count.

All executable recipes live in `references/wave-protocol.md` (P0–P6). This hub is the process and its gates.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

**Boundary.** Different from `/samuel:conductor` — the per-item engine waves dispatches (as the claude-worker variant) and never reimplements — and from `/samuel:team-orchestrate` — Claude peers that converse; wave workers are isolated implementers reporting lifecycle only. Anti-double-scheduler (#30): an Orca automation may *invoke* waves on a schedule; waves never duplicates conductor's pipeline logic and never schedules itself. This skill is **attended-only** — a live coordinator session with the human reachable; the unattended/nocturnal variant is blocked on #29 (TTL + auto-report).

## Mode

```
/samuel:waves 12 14 15 18            — explicit issue set
/samuel:waves label:epic-checkout    — every open pipeline:ready issue with the label
/samuel:waves milestone:"v2 launch"  — every open pipeline:ready issue in the milestone
/samuel:waves … --max-concurrent 2   — cap simultaneous workers (default 3)
```

## Context

- Orca: !`orca status 2>/dev/null | grep -E 'runtimeState|appRunning' | xargs | grep . || echo "ORCA_DOWN"`
- Orchestration state: !`orca orchestration task-list --brief 2>/dev/null | head -5 | grep . || echo "ORCHESTRATION_OFF_OR_EMPTY"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Date: !`date +%Y-%m-%d`

## Authority ceiling (ADR 0004)

Launching this skill is the explicit grant — and its limit:

- Each **worker** may push its branch and open a **draft** PR (`Closes #N`), only inside its own worktree.
- The **coordinator** may comment on the issues being driven and post the run report to `conductor:log` — nothing outside the wave set.
- **Never**, by anyone, at any step: `gh pr merge`, `gh pr ready`, closing issues, pushing to `main`. The human's merge IS the release gate (Step 6) — the coordinator detects it, never requests it, never performs it.

## Process

1. **PRECONDITIONS** — run P0 (Orca ready, orchestration on, `gh` authed, repo registered with base ref, `gh repo set-default`). Any failure stops before any dispatch. Prior orchestration state → § State & recovery first.
2. **INTAKE** — resolve the input to candidate issues; keep only `pipeline:ready` with a filled Executor Plan; fetch plans + `blockedBy` in one batched call (P1). Waves never plans on the fly — exclusions are reported, never silent.
3. **WAVE PLAN — checkpoint.** Present: the wave partition (issue → wave), per-issue engine proposal (Codex default; claude-conductor for taste ≥ 7 or genuinely hard items, per the model-routing table), the concurrency cap, and the exclusion list with reasons. **WAIT for approval.** Nothing is created or dispatched before it. Record the approved plan as one comment on the driving epic/first issue.
4. **DISPATCH** — mirror the DAG (`task-create --deps`, P2); per ready issue up to the cap: worktree linked via `--issue N` from the repo base ref, worker launched, contract delivered (`dispatch --inject` for Codex; §4a `claude -p` for the claude variant) (P3).
5. **SUPERVISE** — rolling `check --wait` loop (P4): verify each reported PR actually exists, watch CI, one bounded re-dispatch per real failure then escalate, answer worker `ask`s (scope/schema questions go to the human), park escalations, backfill freed slots. Timeouts are liveness checkpoints — never kill a live worker.
6. **RELEASE** — poll wave PRs for the human's merges (P5). When the wave's PRs are merged/parked: remove merged worktrees, recompute blockers from the live graph, launch the next wave. The graph, not the wave label, decides dispatchability — an issue whose specific blockers are merged may release early.
7. **REPORT / EXIT** — on DAG exhausted, budget/TTL, or user stop: post the run report to the rolling `conductor:log` issue (P6, ADR 0003) — per-issue outcome, engine, PR, totals, worktrees left alive — and `PushNotification` the summary. Unmerged-PR worktrees stay for review; reset orchestration state only after the report.

## Gotchas

_Add a line each time Claude trips on something._

- On Linux outside Orca-managed terminals the binary is `orca-ide` — bare `orca` is the GNOME screen reader.
- Always copy the FULL worktree id `<repoId>::<path>` from create responses; a bare repo id is not a worktree id.
- `startupTerminal.handle` is the sole worker handle; re-resolve via `terminal list` only on `terminal_handle_stale`, never dual-send.
- `worktree create --agent codex` accepts no model/effort flags — Settings agentDefaultArgs or the two-step fallback (P3).
- `check --wait` returns ONE message per call — N workers finishing needs N waits.
- `addBlockedBy` re-add fails loudly without duplicating — read-then-add (§ Issue dependencies).
- Do not add conductor/autonomous bypass parentheticals to this file — `lint-autonomy.sh` G5 counts a literal 9 repo-wide (and its grep matches the marker even inside a warning about the marker).
- Heartbeat ≠ done; a `check --wait` timeout is a checkpoint, not a failure — inspect, don't restart.
- Orca repo selectors: resolve the repo **id by path** (P0) and use `id:` everywhere — `name:` matches Orca's displayName, not the GitHub repo name; and Orca CLI errors return `ok:false` with **exit code 0**, so check `.ok`, never the exit status.
- oh-my-zsh `dotenv` plugin + a copied `.env` in the worktree: the "Source it?" prompt at shell init eats the FIRST keystroke of Orca's injected startup/setup commands (`bash …` → `ash: command not found`) — both the agent terminal AND the setup terminal die silently (no `bun install`, no `.done`). Pre-append the worktree dir (you pick the name, so the path is known) to `~/.oh-my-zsh/cache/dotenv-disallowed.list` BEFORE `worktree create`, and verify setup actually ran before dispatching.
- Multi-account `gh` via direnv: Orca workspaces (`~/orca/workspaces/…`) live OUTSIDE the direnv scope that exports `GH_CONFIG_DIR`, so workers resolve the wrong account and `gh pr create` dies on a repo the work account can't see (git push over SSH still works — the breakage is gh-API-only). Launch worker terminals with the right `GH_CONFIG_DIR` exported, and verify `gh auth status` shows the expected account from inside an Orca terminal before dispatching.
- Codex's exec sandbox can't reach the Orca app socket ("Orca is not running" while it plainly is) — workers CANNOT deliver `worker_done`/heartbeats/asks via `orca orchestration send`. Don't rely on `check --wait` alone: poll the branch/PR state per supervision window (trust-but-verify already covers it), and tell workers to skip orca reporting steps instead of retrying them.
- A Codex worker resolves a bare skill name against EVERY installed plugin, so on a machine carrying both registries it runs another registry's `implement-plan` instead of the `samuel` equivalent — a same-named variant from a different registry assumes conventions this monorepo does not follow. The worker contract must name the plugin explicitly (`$samuel:<skill>` under Codex, `/samuel:<skill>` under Claude) and forbid every other registry by name.
- Codex launched from a `trust_level = "trusted"` project runs `workspace-write`, which sets `network_access = false` — `gh auth status` fails with "error connecting to api.github.com" and the run dies at `git push` / `gh pr create`, long after dispatch. Pass `-c sandbox_workspace_write.network_access=true` on the terminal command; `worktree create --agent codex` accepts no such flag, so this forces the two-step fallback (already required for `GH_CONFIG_DIR`).
- `codex` blocks startup on its "Update available" NUX with **option 1 (Update now) preselected**, so a blind Enter upgrades the CLI mid-wave. `terminal wait --for tui-idle` returns `ok` while that dialog is up — read the tail, send `2` (Skip), and only then dispatch.
- `orca orchestration task-update` changes only `--status`; there is no `--spec`. Fixing a contract after `task-create` means creating new tasks and marking the old ones `failed`.
- Codex workers with the samuel-skills plugin cache may spawn the pipeline's review sub-agents (`implementation_analyzer`/`component_locator`/`pattern_scanner`) at self-review time — those never complete in a worker environment and the TUI loops "Waiting for agents / No agents completed yet" indefinitely (16+ min observed, #415). Put "do NOT spawn sub-agents; review your diff directly" in the worker contract, and treat that loop in a liveness read as a stall to nudge, not progress.
- The coordinator's own shell inherits direnv env (`GH_CONFIG_DIR`) from the primary checkout's parent dirs — `gh auth status` run there proves NOTHING about worker terminals. Verify from inside an Orca terminal, or simply always export `GH_CONFIG_DIR` inline in the worker `--command`. And forbid `gh auth status --show-token` in contracts: a worker debugging auth will print a live token into scrollback.
- zsh arrays are 1-indexed. A `for i in 0 1 2 3 4` over a `declare -a` issue list creates one task from empty strings and silently drops the last issue — the run then looks complete while one item never got a worker. Loop over the values (`for n in 478 484 391`), never over synthesized C-style indices; `task-create` has no delete, so the repair is `task-update --status failed` plus a new task.
- The auto-mode classifier blocks authoring permission config through Bash — a heredoc or `cp` of `.claude/settings.local.json` is denied even though the file is the worker's own allowlist. Write it with the Write tool, one call per worktree.
- `--max-budget-usd` is a hard kill, not a report. The CLI help's `(only works with --print)` says where the flag applies, not what it does — under `-p` the run dies mid-item at the cap, leaving a half-done branch. Size it so the turn budget is what binds.
- Between the plan write and the dispatch, `origin/main` can move. Diff the plan's baseline against the current base ref and intersect it with each plan's owner files before creating worktrees — a merged sibling PR that rewrote those files does not invalidate the issue, but it does invalidate every `file:line` in the plan. Report the drift as a comment on the affected issues so the worker reads it.
