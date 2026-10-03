# Dispatch Protocol — one task, briefed workers, proven starts, no silent waits

The executable recipes behind `/samuel:coordinate`. The coordinator is a live session in the repo's primary checkout (or its own Orca worktree); workers are agent terminals in Orca — Claude or Codex — each launched with an explicit model and effort. The two engines take different lanes: a **Claude worker** starts with its brief as the `claude` argument and is supervised through `SendMessage` + `notify_when_idle`, with no Task and no Dispatch; a **Codex worker** is Orca-supervised (Task, Dispatch, `check --wait`, `worker_done`), because Codex cannot receive a peer message. Each section below says which lane a step belongs to; the **frozen commit on the worker's branch** is the durable artifact, readable from the coordinator's checkout because Orca worktrees share the repo's object store.

Every command below assumes Orca ≥ 1.4.193 (`worker-start --model/--effort`, `worker-read`, `worker-release`). Resolve the executable once per the `orca-cli` skill (`orca`, or `orca-ide` on Linux outside Orca). Orca errors return `ok:false` with **exit code 0** — check `.ok`; `worker-start` alone exits non-zero on anything but `ready`.

## C0 — Preconditions

```bash
orca status --json | jq -r '.result.runtime.state'            # "ready" or stop
orca orchestration task-list --brief --json | jq -r '.ok, (.error.code // "-")'
                                                                 # false + run_required ⇒ no Run bound yet (C1/C2), NOT orchestration off
                                                                 # false + any other code ⇒ Orchestration is off in Orca Settings — stop
orca agent hooks status --json | jq -r '.result.enabled, (.result.statuses[] | "\(.agent) \(.state)")'
                                                                 # enabled + target agent "installed", else `orca agent hooks on`
                                                                 # (and `agent hooks prepare-codex` before a two-step Codex launch):
                                                                 # without hooks there is no transcript read and no agentWait
claude auth status --json | jq -r .email ; codex login status  # the ambient login every worker will burn (Orca imposes none when activeAccountId is null)
orca account list --json | jq -c '.result | {claude:[.claude.accounts[].email], codex:[.codex.accounts[].email]}'
                                                                 # the accounts Orca can switch a worker TO — the fallback set, not the active one
gh auth status                                                   # only if the task touches GitHub
git status --porcelain | grep '^??'                              # untracked files a worktree worker will never see
```

Substrate facts behind these (hooks, accounts, cards, sandbox): `../../../reference/orca-substrate.md`.

Untracked files that a brief depends on are committed (or stashed and named in the brief) before any worktree is created. The human had to point this out once; the coordinator does it by default.

## C1 — Inventory and reuse

```bash
orca orchestration run-current --json           # already bound? reuse the Run
orca orchestration run-list --json | jq -r '.result.runs[] | "\(.id) \(.objective)"' | head
orca orchestration task-list --brief --json     # open dispatches from a previous turn or session
orca orchestration worker-list --json           # live worker terminals and their state
orca worktree ps --limit 20 --json               # worktrees with a branch for this task already
orca terminal list --json | jq -r '.result.terminals[] | "\(.handle) \(.title)"'
```

Claude workers have no Dispatch, so the orchestration lists do not show them: `ListAgents` does (rows named `{task}-{role}-{model}`), together with their briefs under `.claude/briefs/{run_id}/` and reports under each worktree's `.claude/reports/`.

Reuse rules: an **idle worker of the same task** takes the next Task via `worker-start --task <new> --terminal <handle>` (Orca transfers cleanup ownership); a worktree that already holds the task branch is the worktree, not a new one. Prior state from an interrupted run: settle it first — `worker-show --dispatch <id>` per open dispatch, then release, retry (`--retry-of`), or abandon (§ Recovery). Never `orchestration reset` while anything is active.

## C2 — Run, policy, tasks

```bash
orca orchestration run-create --objective "coordinate: {task, one line}" --json     # or run-use --id <run_id>
```

Take the Run id from the `run-create`/`run-current` receipt and write `.claude/run-policy/{run_id}.md` if absent (template in `worker-brief.md`; `mkdir -p .claude/run-policy` first); read it back before writing each brief. Never `.claude/run-policy.md`: that path is shared by every session in the checkout and was overwritten by a sibling mid-brief. Then the brief, one per worker. A **Claude worker's** filled brief is a file, `.claude/briefs/{run_id}/{name}.md` in this checkout (`mkdir -p` first) — the launch passes it as the `claude` argument, and no Task is created. A **Codex worker** gets one Task with the filled brief as the spec, dependencies mirrored:

```bash
orca orchestration task-create --task-title "{name}" --spec "{brief with the run policy appended, verbatim}" --json
orca orchestration task-create --task-title "{name}-review" --spec "{review brief}" --deps '["<task_id_impl>"]' --json
```

**Idempotency before every `task-create`.** 18 % of measured briefs were byte-identical re-dispatches into a live worktree — seven full-strength simplify briefs into one checkout in 47 minutes, each running 70–90 turns, i.e. concurrent writers on one tree. Before creating a task, check that no open task with the same title exists and no active dispatch owns that worktree:

```bash
orca orchestration task-list --brief --json | jq -r '.result.tasks[] | select(.status=="dispatched" or .status=="ready") | "\(.id) \(.title // .spec[0:60])"'
orca orchestration worker-list --terminal-state active --json
```

A hit means resume that dispatch (`worker-read`, then a `send --to dispatch:<id>` follow-up if it needs new state), never a second copy.

`task-update` changes only `--status`; a wrong brief means a new task and the old one marked `failed`. Verify the created titles against the dispatch plan before launching.

## C3 — Launch, verify the launch, prove the start

### Claude workers — argv brief, no dispatch

```bash
# writer: its own worktree, then the agent with the brief as its first message
orca worktree create --name {task}-{role}-opus --repo id:<ORCA_REPO_ID> --no-parent --setup run --json
orca terminal create --worktree name:{task}-{role}-opus --title {task}-{role}-opus \
  --command 'claude --name {task}-{role}-opus --model opus --effort high --permission-mode auto "$(cat {abs path}/.claude/briefs/{run_id}/{task}-{role}-opus.md)"' --json

# reader (research, read-only review): the current worktree, no worktree create
orca terminal create --worktree current --title {task}-{role}-opus \
  --command 'claude --name {task}-{role}-opus --model opus --effort high --permission-mode auto "$(cat {abs path}/.claude/briefs/{run_id}/{task}-{role}-opus.md)"' --json
```

The session is interactive (no `-p`): the human reads the pane and can type into it, and the worker answers. `"$(cat …)"` passes the brief byte-exact — quotes, `$` and backticks included (measured, #63) — so the brief never sits in an input box and there is no lost Enter to check for. Keep the handle from the receipt (`.result.terminal.handle`).

### Codex workers — Orca dispatch

```bash
# Codex implementer (backend / architecture / debugging / tests by default)
orca orchestration worker-start --task <task_id> --worktree new-top-level --repo id:<ORCA_REPO_ID> \
  --name {task}-{role}-codex --agent codex --model {codex model} --effort high --setup run --json
```

`--name` is the whole identity, and Orca derives everything from it with no manual step: path `~/orca/workspaces/<repo>/{name}`, branch `{name}` (no slash, no prefix — measured), `displayName` `{name}`, sidebar card `{name}`. Never rename the branch or the card afterwards; that is what the sidebar, `branch:` and `name:` selectors key on. Neither launch takes an `--issue` flag: right after creation set the card — `orca worktree set --worktree name:{name} --issue {N} --workspace-status in-progress --comment "dispatched · {role} · {model}/{effort}" --json` (drop `--issue` when there is none). An issue task names its workers `issue-{N}-{role}-{model}` and briefs them with the Executor Plan (worker-brief.md § Issue worker) — a Claude worker reports through its report file, a Codex worker through `worker_done`. Only the opt-in `--via conductor` and `--via iaas` workers keep the pipeline's own `issue-{N}-{slug}`, because `start-task` and `done` derive state from that branch, and they report nothing through Orca: watch the branch and the log as waves P4 does for the claude variant, and for iaas the PR itself — its pass markers are the round log.

`--repo` is resolved **by path**, never by name (`orca repo list --json | jq -r '.result.repos[] | select(.path=="{ABS}") | .id'`). `new-top-level` with no `--base-branch` branches from the repo's default base — every worker starts from current `origin/main` unless the brief's START FROM says otherwise, in which case pass `--base-branch`.

### Readers — share the current worktree

```bash
orca orchestration worker-start --task <task_id> --worktree current --agent codex --model {codex model} --effort xhigh --json   # Codex reviewer
```

A Claude reader uses the `terminal create --worktree current` form above. A reviewer that would edit files is a second writer on a checkout: give it a worktree or make it read-only. The inverse waste was also measured — six dedicated checkouts created for briefs that said `READ ONLY` — so a read-only role never gets `new-top-level`.

### Verify the launch

**Claude worker** — within 30 seconds, `orca terminal read --terminal <handle> --json`: the footer names the requested model and effort (e.g. `Opus 5.5` and `◐ medium · /effort`), and the brief is rendered as a sent `❯` message followed by a tool call. A different model or effort ⇒ stop and tell the human. A bare **shell** prompt with no TUI above it is a dead agent (the binary crashed at launch): capture the tail, close the terminal, and run the same `terminal create` once more.

**Codex worker** — read the receipt before anything else:

```bash
# from the worker-start JSON
jq -r '.result | "\(.dispatch.id) \(.worker.agent_terminal_handle // .worker.agentTerminalHandle) model=\(.launch.effective.model) effort=\(.launch.effective.effort) stage=\(.stage)"'
```

`launch.effective.model` and `.effort` must equal what was requested. **Missing or different ⇒ stop, tell the human what the worker actually got, do not dispatch anything on inherited defaults.**

Who-is-who in the Orca UI comes from the worktree name, not from the terminal title: agent TUIs (Claude Code for certain, with its `✳ summary` titles) rewrite the terminal title on every turn, so a `terminal rename` is overwritten within a minute. Writers are identified by their card (`{task}-{role}-{model}`); a reader in the shared `current` worktree has no card of its own, so its identity is the Task title plus the dispatch id — put `{task}-{role}-{model}` in `--task-title` and let `worker-show --dispatch <id>` be the lookup. Progress the human can see at a glance goes on the card: `orca worktree set --worktree name:{name} --comment "{state, one line}" --json` at each status change.

### Prove the start — Codex workers, within 30 seconds

`worker-start` delivers the brief; delivery is not execution. The Enter is lost often enough to have burned two 50-minute wait windows on workers that never ran:

```bash
orca orchestration worker-read --dispatch <dispatch_id> --limit 30 --json     # transcript when Orca can prove the session, else terminal tail
```

Evidence of a start: the brief rendered as a **sent** message, a tool call, a file read, a `git` line. Two failure signatures look alike and take opposite fixes. The brief sitting in the input box of a live TUI is a lost Enter — one nudge, then read again. A bare **shell** prompt with no TUI above it is a dead agent (the binary crashed at launch; the tail shows the crash line, e.g. `segmentation fault`, right before the prompt): a nudge lands in the shell and does nothing, `worker-stop` answers "not stopping" because nothing is running, and the dispatch still reads `ready` / `live` because the pane is alive. Capture the tail now (an exited terminal later returns an empty tail), then `worker-start --task <same> --retry-of <dispatch_id>` with explicit worktree/agent/model. The lost-Enter nudge:

```bash
orca terminal send --terminal <handle> --text "" --enter --json
```

Codex's update dialog (**Update now** preselected) also passes `tui-idle`: if the tail shows it, send `2` before anything else. Only a proven start opens a wait window.

## C4 — Supervise

### Claude workers — idle notices, a liveness tick, the turn may end

Right after the start is verified, subscribe once per worker — no message, bare name (add the `[ref]` only when `ListAgents` shows two rows with that name):

```text
SendMessage({to: "{name}", notify_when_idle: true})
```

and arm **one** `Monitor` for the whole run that prints a liveness tick every nine minutes (`while true; do sleep 540; echo tick; done`, `timeout_ms` 1800000, re-armed on expiry). With only Claude workers open, an interactive coordinator **may end its turn** (under `claude -p` an ended turn ends the run — SKILL.md § Unattended runs): the harness wakes it with exactly one `[Cross-session idle notice]` per subscription, carrying the worker's last line, and no orchestration message exists to nag the human. A notice that fires while the coordinator is mid-turn arrives at its next turn boundary.

On each notice, branch on the last line:

- **`REPORT .claude/reports/{name}.md`** → C5.
- **`QUESTION: …`** → answer from your context with `SendMessage({to: "{name}", message: "…", notify_when_idle: true})`; scope, schema or another worker's files go to the human first, in one `AskUserQuestion`.
- **Anything else** → an early stop. Send one continue message that names the open items from the brief's DELIVER and VERIFY slots and asks what blocks any of them, with `notify_when_idle: true`. At most two per worker; a third stop goes to the human.

Every follow-up re-subscribes (`notify_when_idle: true` on the send): one subscription yields one notice. On a tick with no notice since the last one: `orca terminal read --terminal <handle> --json` and `git log --oneline -3 {branch}` per worker, one status line each, mirrored on the card (`orca worktree set --worktree name:{name} --comment "{state}" --json`). A **permission prompt** in the pane means the launch was wrong: close the terminal, fix the launch, relaunch — never answer it from here. Quota death has the same signature as below (dirty tree, no commits, a usage-limit line) and the same re-route.

### Codex workers — rolling `check --wait` windows

One rolling loop. Windows of **at most nine minutes**, in the foreground (the Bash tool caps at ten). Each window ends with one status line per worker whose state changed, or one line saying nothing changed and what the evidence was — the human never asks "how is it going" because the answer is already on screen.

```bash
orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 540000 --json
```

- **`worker_done`** → read the six-line body (C5). Then decide the terminal's next owner *before* acknowledging: `worker-start --task <next> --terminal <handle>` for an immediate follow-up by the same agent, else `worker-release --dispatch <id>`. Acknowledge with `check --ack <delivery_id> --wait …` and keep waiting for the rest.
- **`question`** → answer from your context with `reply --id <msg_id> --body "…"`; anything about scope, schema, or another worker's files goes to the human first, in one `AskUserQuestion`. A question the human has not answered before the worker gives up becomes a follow-up dispatch, not a late reply.
- **`escalation`** → park it in the final report, free the slot, continue.
- **Timeout / `{count:0}`** → a liveness checkpoint, in this order:
  1. `worker-show --dispatch <id> --json | jq '.result.observation.agentWait'` — `prompt-text` with the brief still in the box = lost Enter → one `terminal send --text "" --enter`; a Codex update dialog → `2`; a **permission prompt** = the launch allowlist was wrong → stop that worker, fix the launch, relaunch (never answer it by hand, that is permission laundering by keyboard); `null` = no wait; **absent** = Orca never looked, fall through to 2.
  2. `worker-read --dispatch <id> --limit 30 --json` — output advancing ⇒ keep waiting, status line `running · <evidence>`.
  3. `git log --oneline -3 {branch}` from your checkout — commits are evidence even when the socket is silent.
  4. Terminal gone, or dirty tree + no commits + a spend/usage-limit line in the tail ⇒ **quota death**: `orca account list --json`, one status line naming the dead account, then re-route — `worker-start --task <same> --retry-of <dispatch_id>` on the other engine or under another registered account allowed by the owner's account policy. Never sit on the window hoping for a reset unless the human said to wait.
  Each checkpoint updates the card: `orca worktree set --worktree name:{name} --comment "{state}" --json`.
- **Codex sandbox** → a Codex worker's `worker_done` may fail to reach Orca. Per window, also read `git log --oneline -3 {branch}` from your checkout and the terminal tail; a worker whose last message is the six report lines is done even if no message arrived. Settle its task with `task-update --status completed`.
- **GitHub state** → if the task involves a PR or a merge gate, `gh pr view <n> --json state,mergedAt,isDraft` per window. Never take "merged" from a message as news.
- **The turn does not end while a Codex dispatch is open.** Orca types `You have 1 orchestration message` into the coordinator's input box once per message that arrives — acked or not (measured, #63) — and without Enter, so the copies pile up unseen and land on the human's next submit; it appeared 124 times in one session set. If the human interrupts, settle or retain every open worker before stopping.

## C5 — Read the report, then decide what to inspect

The report is the review by default: for a Claude worker the file its last line names (`{worktree}/.claude/reports/{name}.md`, never committed), for a Codex worker the `worker_done` body. From your own checkout:

```bash
git log -1 --format='%H %s' {sha}                          # the frozen commit exists (shared object store)
git diff --stat {base}..{sha}                              # files changed vs MAY CHANGE / MUST NOT TOUCH
git diff {base}..{sha} -- {a file, only when the report gave a reason}
```

Open the full diff when: a file is outside the allowed set · security-sensitive paths · behaviour wider than DELIVER · a reviewer requested changes · the human asked. Open it **in Orca**, not in chat: `orca file open-changed --mode diff --worktree name:{name} --json` puts every changed file of the worker's worktree in the editor as diffs (one file: `orca file diff <path> --worktree name:{name}`); the human reviews there and the coordinator quotes only `file:line`. For visual work, open the worker's capture paths (`full-screenshot`, `console`, `network` from its VERIFY slot) and the running page (`orca tab create --url … --worktree name:{name}` + `orca full-screenshot`). A report that pastes logs or files is returned for the contract with one follow-up line, not read. On accept, `orca worktree set --worktree name:{name} --workspace-status in-review --json`.

**Independent review**: a second Task for the other model, `--worktree current`, `--effort xhigh`, brief = the reviewer variant on the frozen `{sha}`. Factual disagreement (a test fails or not, a path is dead or not) is settled by running the command once; judgment calls are the coordinator's and are stated as such in the final report.

Release every settled worker before the next wait unless it takes the next task. A Claude worker is released with `orca terminal close --terminal <handle> --json` (a second call when the first reports it still open) — or kept for a follow-up `SendMessage`; a Codex worker with `worker-release`, after which it stays readable through `worker-read`.

## C6 — Integrate, verify, report, clean up

In a checkout no other session is using — the coordinator's own when it is alone there, otherwise a fresh `orca worktree create --name integrate-{task} --no-parent --json` (a shared working tree during a merge is two writers on one checkout) — never in a worker's:

```bash
git fetch origin                                            # remote may have moved
git merge --no-ff {worker_branch}                           # or cherry-pick the frozen commits; worktrees share objects, no push needed
{the project's real checks: the plan's gate, or the repo's test / typecheck / lint commands}
```

Red ⇒ one follow-up dispatch to the owning worker with the failing output pasted, then a second failure escalates. Green ⇒ the human decides the outward step. **No `git push`, no `gh pr create`, no publish, deploy, production or secrets in any output without the human's explicit approval** — a hard stop at every autonomy level, and the one gate this skill always waits at.

Set every accepted card to `completed` (`worktree set --workspace-status completed`) and leave rejected ones `in-review` with a `--comment` naming why. Optional, only when the human has enabled Settings → Artifacts: `orca artifacts share {report.md}` publishes the final report as a link; a denial is final, deliver the file locally.

Final report (the only long message of the run): result in the user's terms (what changed, visibly or behaviourally) · verification evidence (commands and their one-line results) · unresolved issues · every pane and worktree still alive with the exact command that removes it (`orca worktree rm --worktree id:<id> --force --json`, `orca terminal close --terminal <handle> --json`). Then `PushNotification` one line.

Clean-up policy: worktrees of unmerged branches stay for review; released worker terminals are already closed; `orca orchestration worker-list --terminal-state reclaimable --json` lists settled workers still holding a terminal — release each; research/review terminals in the current worktree are closed at the end of the run. Orchestration state is left alone unless the human asks for a reset.

## Recovery

| Situation | Action |
|---|---|
| Session compacted or resumed mid-run | `run-current` + `task-list --brief` + `worker-list` rebuild the Codex side; `ListAgents` + `orca worktree ps` + the files under `.claude/briefs/{run_id}/` and each worktree's `.claude/reports/` rebuild the Claude side (re-subscribe each live worker); `.claude/run-policy/{run_id}.md` (id from `run-current`) rebuilds the constraints. Never reconstruct from scrollback. |
| Dispatch `outcome_unknown` | `worker-stop --dispatch <id>` then `worker-show`; still unknown ⇒ `worker-abandon` and say the terminal may be live. |
| Worker died (quota, crash) | Claude: close the terminal and run the same `terminal create` again. Codex: `worker-start --task <same> --retry-of <id>` with explicit worktree/agent/model; the dirty tree in the old worktree is inspected, not trusted. |
| Wrong brief | Claude: close the worker, write a new brief file, launch again. Codex: new task, old one `--status failed`. Never patch a running worker's contract through the terminal. |
| Human says "merged" / "approved" / "changed account" | Verify with `gh pr view` / `orca account list` / a `worker-read` before acting on it. Messages are inputs; state comes from the tools. |
