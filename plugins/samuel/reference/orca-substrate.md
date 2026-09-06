# Orca Substrate — what the runtime gives a coordinator, and what it does not

Facts about Orca (≥ 1.4.193) that more than one skill depends on: `coordinate`, `waves`, `team-orchestrate`, the conductor's launch recipes. One home so a runtime change is fixed once. Recipes that belong to a single skill stay in that skill's spoke; this file carries the substrate.

The version-matched command reference is served by the binary itself — `orca skills get orca-cli`, `orca skills get orchestration`, `orca agent-context --json` — and outranks anything written here when they disagree. Resolve the executable once per session (`orca`; `orca-ide` on Linux outside an Orca terminal, where bare `orca` is the GNOME screen reader).

## Identity comes from the worktree name

`worker-start --name X` / `worktree create --name X` yields path `~/orca/workspaces/<repo>/X`, branch `X` (no slash, no prefix), `displayName` `X`, and a sidebar card `X`. Nothing is renamed afterwards: `branch:X`, `name:X` and the card all key on it. Terminal titles are **not** identity — agent TUIs rewrite them every turn (Claude Code's `✳ summary`), so `terminal rename` is cosmetic for under a minute. A reader in a shared worktree has no card; its identity is the Task title plus the dispatch id.

`worker-start` has no `--issue`; link a card after creation with `orca worktree set --worktree name:X --issue N --json`. Cards carry two human-visible fields the coordinator owns: `--comment "<one line of state>"` and `--workspace-status todo|in-progress|in-review|completed` (the board columns). Moving the card at every state change is what lets the human read progress from the sidebar instead of asking.

## Agent status hooks — what makes workers observable

`orca agent hooks status --json` → `result.enabled` plus a per-agent `state` (`installed` / `not_installed`). With hooks on, two things exist that otherwise do not:

- `worker-read --dispatch <id>` returns the **exact provider transcript** (`source: "transcript"`) instead of a terminal tail. A cursor is pinned to its source; `source_changed` means start a fresh read.
- `worker-show --dispatch <id>` populates `observation.agentWait`: the worker is parked on a prompt only a human can answer, with the evidence that proved it (`hook`, `prompt-text`, or `title`). `null` = Orca looked and found no wait. **Absent** = Orca never looked (older host, unverifiable identity, unreadable pane) — absent never means "not waiting".

`agentWait` is the structured form of the lost-Enter and stuck-dialog checks: `prompt-text` with the brief still in the box is a lost Enter (one `terminal send --text "" --enter`); a Codex "Update available" dialog is a `2` (Skip); a permission prompt in a Claude worker is a launch bug (the allowlist was wrong), not something to answer by hand. Precondition for any run that supervises workers: `enabled: true` and the target agent `installed`; `orca agent hooks on` fixes the first, `orca agent hooks prepare-codex` repairs Codex hook trust before a shell launch (the two-step custom-argv path needs it).

## Accounts — quota is a first-class failure

Two different questions, two different commands. **Which account is a worker going to burn right now?** The ambient host login, which Orca terminals inherit: `claude auth status --json | jq -r .email` and `codex login status` (Codex prints the method, not the email). **Which accounts can Orca switch a worker to?** `orca account list --json` → `result.claude.accounts[]` / `result.codex.accounts[]` — only the accounts registered with `orca account add`, and `activeAccountId: null` means Orca imposes none, so the ambient login rules. An account can be active on the host and absent from Orca's list at the same time (measured: the host's active login was absent from `account list`); the list is the fallback set, never the current-account probe. A worker that dies with a dirty tree, no commits, and a spend-limit or usage-limit line in `worker-read` is a **quota death**: report it in one status line, then re-route — `worker-start --task <same> --retry-of <dispatch> …` on the other engine or under another registered account — and never sit on a wait window hoping for the reset unless the human said to wait. There is no `account use` in the CLI: the active managed account is set in the Orca app, and the ambient login with `claude login` / `codex login` — both are the human's pre-launch step, so an unattended run verifies the account in its precheck and refuses to start on the wrong one rather than trying to switch. Which account may be spent on which work is a per-owner policy (it lives in the owner's `CLAUDE.local.md` or global instructions, never in a skill); the coordinator reads that policy, states the account it is about to burn, and treats an unregistered account as unavailable rather than asking for a login mid-run.

## Worker lifecycle — the supervised loop

`run-create` → `task-create` → `worker-start` → `check --wait` → `worker_done` → `worker-release` (or `--terminal <handle>` reuse). Facts that bite:

- `worker-start` exits non-zero on anything but `ready` and returns `launch.requested` / `launch.effective` for model and effort — the receipt to check before dispatching anything else. `--effort` requires `--model`; neither combines with `--terminal`.
- Every other Orca command returns `ok:false` with **exit code 0** — branch on `.ok`.
- A dispatched worker cannot dispatch sub-workers (`nested_worker_depth_exceeded`, Settings → Orchestration → Nested worker depth). Briefs say "do not spawn sub-agents" for that reason and because Claude sub-agents inside a worker never complete under Orca.
- Codex's exec sandbox may not reach the Orca socket: a Codex worker's `worker_done` can fail while the work is fine. Read the branch and the terminal before concluding anything from an empty window.
- `check --wait` returns one batch and replays it until `--ack`; a timeout is a checkpoint, never a failure; heartbeats mean alive, not done.
- `worker-release` preserves an inspectable archive, then closes only the exact coordinator-owned agent terminal; `worker-list --terminal-state reclaimable` lists settled workers still holding a terminal — the cleanup sweep at the end of a run.

## Reviewing without pasting

`orca file open-changed --mode diff --worktree name:X --json` opens every git-changed file of a worker's worktree as diffs in the Orca editor; `orca file diff <path> --worktree name:X` opens one. That is how a human reviews a frozen commit visually, and how a coordinator points at it without dumping text. Diffs default to unstaged; `--staged` for the index.

## Visual evidence — the embedded browser

Scoped per worktree: `orca tab create --url … --worktree name:X`, `orca snapshot`, `orca full-screenshot --format png`, `orca pdf`, and — for a worker testing UI — `orca capture start --worktree name:X` before the test, then `orca console --limit 100` / `orca network` after it. A UI worker's VERIFY slot names these, and its report carries the capture paths; the human never pastes a screenshot in.

## Scheduling and remote runs

- **Automations** are Orca's cron: `orca automations create --name … --trigger hourly|daily|weekdays|weekly|<cron>|<RRULE> [--time HH:MM] --prompt "…" --provider claude|codex --repo id:<id> [--precheck <command>] [--disabled] --json`. `--repo` = a fresh worktree per run; `--workspace <selector>` = an existing one (`--reuse-session` optional). `--precheck` aborts the run when the command fails — the place for `orca status`, `gh auth status`, a quota probe. `automations runs --id <id>` is the run ledger. An automation is a **trigger**: it may invoke `/samuel:waves` or `/samuel:coordinate`; it never reimplements their logic (anti-double-scheduler).
- **Environments** are paired remote Orca runtimes: `orca environment add --name <n> --pairing-code <code>`, then `worker-start --task … --on <name> --worktree new-top-level --repo <exact remote selector>`. The Run stays on the local server; later commands route by dispatch id, so `--on` is passed once. Remote `current` / `new-child` are invalid.

## Publishing — gated by a human switch, on purpose

`orca artifacts share <file.md|.html>` publishes a public link; `orca skills share --skill <id> --bundle-name <n>` publishes an unlisted skill bundle. Both are off until the human enables them in the desktop app (Settings → Artifacts / Share Skills); a denial (`artifact_sharing_disabled`, `agent_skill_sharing_disabled`) is final for the run — deliver the file locally, do not retry.

## Agent Teams inside Orca

`orca claude-teams [claude args…]` from an Orca terminal starts Claude Code Agent Teams with teammates as native Orca splits — no tmux. `team-orchestrate` prefers it when the session already runs inside Orca.

## Gotchas

_Add a line each time Claude trips on something._

- Codex blocks startup on its "Update available" dialog with **Update now** preselected; `tui-idle` returns while it is up. Read the tail; send `2`.
- oh-my-zsh `dotenv` + a copied `.env` eats the first keystroke of Orca's injected startup command; pre-append the worktree path to `~/.oh-my-zsh/cache/dotenv-disallowed.list` before create.
- Orca workspaces live outside direnv scopes that export `GH_CONFIG_DIR`; export it inline in the worker command and verify `gh auth status` from inside an Orca terminal.
- `orca account list` rejects `--environment` / `--pairing-code`: accounts are per host, run it where the workers run.
