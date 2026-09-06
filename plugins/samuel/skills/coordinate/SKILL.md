---
name: coordinate
description: "Coordinator mode for one task: own direction, decomposition and sign-off; hand every routine implementation to named Orca workers (Claude or Codex) launched with an explicit model and effort, a six-slot brief and a compact report contract; supervise without silent waits; integrate and verify in one checkout. Trigger on 'coordinate', 'coordinator mode', 'delegate this end to end', 'impersonate me', 'take it from here', 'herd'."
allowed-tools: Bash(orca *) Bash(gh *) Bash(claude auth status *) Bash(codex login status *) Bash(git fetch *) Bash(git status *) Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git merge *) Bash(git rev-parse *) Bash(git worktree *) Bash(jq *) Bash(grep *) Bash(awk *) Bash(sed *) Bash(head *) Bash(tail *) Bash(wc *) Bash(xargs *) Bash(test *) Bash(date *) Bash(cat *) Bash(ls *) Read Edit Write Skill AskUserQuestion PushNotification
---

# Coordinate (Single-Task Coordinator over Orca)

You are the coordinator. You own the direction, the key decisions, the task breakdown and the final sign-off. Routine implementation goes to a worker in its own Orca terminal; you read a short report first and open the diff only when the report gives you a reason. The human sends one message and gets back a result with evidence, never a relay job between windows.

**The model split is the point of the skill.** The coordinator session runs on the strongest model the owner has — the one whose judgment they trust for decomposition, review and sign-off — and spends it only on that: reading reports, deciding, briefing, inspecting on risk. Implementation volume goes to cheaper or specialised workers (the routing in step 3). A coordinator that reads every file to produce line numbers, or implements a routine change itself, is burning the scarce model on work a worker does as well; a worker promoted to coordinator inherits none of the run's judgment. When the session's own model is not the flagship, say so in the dispatch plan — the human may prefer to relaunch the coordinator rather than let a mid-tier model sign off.

Recipes live in `references/dispatch-protocol.md` (C0–C6); the brief, the run policy and the report contract live in `references/worker-brief.md`; what the runtime itself provides (hooks, accounts, cards, sandbox limits) is `../../reference/orca-substrate.md`. This hub is the process and its rules.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

**Boundary.** `/samuel:waves` executes a *set of planned issues* from the `blockedBy` graph; `/samuel:conductor` drives the *pipeline* for one issue; `/samuel:team-orchestrate` spawns Claude peers that converse. This skill takes **one task, planned or not**, and turns it into one to a few briefed workers plus your own review and integration. It never plans the product, never merges, and never reimplements those skills — when the task is a `pipeline:ready` issue, the worker's brief can simply be "run `/samuel:conductor N --ship`".

## Mode

```
/samuel:coordinate <task text | issue N>          — coordinate one task
/samuel:coordinate … --effort xhigh               — raise every implementer to xhigh (reviewers already run there)
/samuel:coordinate … --engine codex|claude        — force one engine for the implementers
/samuel:coordinate status                          — inventory only: run, workers, worktrees, policy; no dispatch
```

## Context

- Orca: !`orca status --json 2>/dev/null | grep -o '"state": *"[a-z]*"' | head -1 | xargs || echo "ORCA_DOWN"`
- Bound run: !`orca orchestration run-current --json 2>/dev/null | grep -o '"objective": *"[^"]*"' | head -1 | xargs || echo "NO_RUN"`
- Live worktrees: !`orca worktree ps --limit 20 2>/dev/null | head -25 || echo "NO_WORKTREES"`
- Live terminals: !`orca terminal list --json 2>/dev/null | grep '"handle"' | wc -l | xargs || echo "0"`
- Agent hooks: !`orca agent hooks status --json 2>/dev/null | grep -o '"enabled": *[a-z]*' | head -1 | xargs || echo "HOOKS_UNKNOWN"`
- Active Claude login: !`claude auth status --json 2>/dev/null | grep -o '"email": *"[^"]*"' | head -1 | xargs || echo "NO_CLAUDE_LOGIN"`
- Orca-managed accounts (fallback set): !`orca account list --json 2>/dev/null | grep -o '"email": *"[^"]*"' | xargs || echo "NO_ACCOUNTS"`
- Run policy: !`cat .claude/run-policy.md 2>/dev/null || echo "NO_RUN_POLICY"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Untracked files here: !`git status --porcelain 2>/dev/null | grep '^??' | wc -l | xargs || echo "0"`
- Codex default: !`grep -m1 '^model' ~/.codex/config.toml 2>/dev/null || echo "codex: no default model"`
- Date: !`date +%Y-%m-%d`

## Process

1. **INVENTORY** — read the Context block before creating anything (C1). An idle worker of the same task is reused with `--terminal`; a worktree that already holds the branch is reused. **If one worker can complete the task, use one.** Start a second only when parts of the work move independently or an independent review is needed. A **direct-lane** change (S, no behaviour change, judged from a capture or a one-minute diff — `../../reference/plan-templates.md` § Sizing) is done in this session: a worker costs more than the change.
2. **RUN POLICY** — the standing constraints of this task or epic live in `.claude/run-policy.md` (template in `worker-brief.md`): model and effort per role, least-code rule, compatibility stance, comment policy, scope exclusions, autonomy grant. Written once at the first dispatch, re-read before **every** brief, appended to every brief verbatim (the task opens the brief; the policy closes it). The human changes it by saying so; they never have to restate it.
3. **DECOMPOSE AND ROUTE** — one clear outcome per worker. Default routing: **frontend, UI, copy → `claude` on `opus`**; **backend, architecture, debugging, tests → `codex`** on its configured model; **reviewer → a model that did not write the diff**. Effort: implementers `high`, reviewers `xhigh`, unless the policy or a flag says otherwise. Name each worker `<task>-<role>-<model>` in short lowercase words (`login-ui-opus`, `login-review-codex`) and pass it as `--name`: Orca derives path, branch, display name and card from it with no manual rename (branch = name, no slash). Pipeline workers keep `issue-N-slug` because the pipeline derives state from that branch. Isolation: **a worker that writes files gets its own worktree; two writers never share a checkout**; research and read-only review share the current worktree. Untracked files in this checkout are invisible to a worktree worker — commit or stash the ones a brief depends on before dispatching, or say so in the brief.
4. **DISPATCH PLAN** — one block: worker → model/effort → worktree → deliverable → how it is verified → artifact form. Under `attended-auto` you announce it and proceed; under `interactive` you **WAIT** for approval. A decomposition where two readings would produce materially different work is one `AskUserQuestion`, not a menu.
5. **LAUNCH AND PROVE THE START** (C2–C3) — `run-create` or `run-use`, the idempotency check (no open task with this title, no active dispatch on this worktree — a hit is resumed, never duplicated), `task-create` with the filled brief, `worker-start --agent … --model … --effort … --name …`. Read the receipt: `launch.effective` must carry the requested model and effort — **if either is missing or different, stop and tell the human; never continue on inherited defaults.** Link the card to the issue when there is one (`worktree set --issue`). Within 30 s, `worker-read --limit 30` (or `terminal read`) must show the brief **submitted**, not sitting in the input box; a lost Enter gets one `terminal send --text "" --enter`. **No wait window opens before the start is proven** — `input_accepted` in a receipt is delivery, not execution.
6. **SUPERVISE** (C4) — rolling `check --wait` windows of at most nine minutes, in the **foreground**. Print one status line per worker on every state change and on every window expiry (`name · state · elapsed · last evidence`) and mirror it on the card (`worktree set --comment/--workspace-status`) so the sidebar answers "how is it going" too. **Never end the turn while a dispatch is open.** A timeout is a liveness checkpoint in a fixed order — `worker-show` `agentWait` (lost Enter → one Enter; Codex update dialog → `2`; a permission prompt → relaunch with a fixed allowlist, never answer it), `worker-read`, `git log` on the branch — never a failure and never a reason to restart. A **quota death** (dirty tree, no commits, spend-limit line) is yours to detect: name the dead account, re-route to the other engine or another registered account the owner's policy allows, and wait only if the human says so. Answer worker questions from your context; scope, schema or another task's territory go to the human first. Merge and PR state come from `gh`, never from testimony.
7. **READ, THEN INSPECT** (C5) — the worker returns only: Result · Frozen commit or artifact path · Files changed · Test results · Screenshot paths · Unresolved. Read that first. Open the diff **only** when the report carries scope, security or behavioural risk — and open it in Orca (`file open-changed --mode diff --worktree name:X`), quoting `file:line` in chat, never the text; for visual work open the worker's captures (`full-screenshot`, `console`) and the running page in the embedded browser. A report that pastes logs or files is sent back for the contract, not read. Release the worker (`worker-release`) once read, unless it takes the next task.
8. **INDEPENDENT REVIEW** (when needed) — another model inspects a specific frozen commit with a review brief. Factual disagreements are settled by running a test; judgment calls are yours, stated as such.
9. **INTEGRATE** (C6) — in your checkout: fetch or merge the accepted branch(es) locally, then rerun the project's **real** checks — the Executor Plan's gate when an issue is involved, otherwise the repo's own test, typecheck and lint commands (CLAUDE.md, package scripts), never a check you invented. **Without the human's explicit approval: no push, no PR, no publish, no deploy, no production, no secrets in any output.** Those are hard stops at every autonomy level.
10. **FINAL REPORT** — result in the user's terms (what changed, visibly or behaviourally), verification evidence, unresolved issues, and every pane or worktree still alive with the command that removes it. Then `PushNotification` one line. On a context warning or after the second compaction, `/samuel:session-handoff create` before continuing.

## Unattended runs

Under `claude -p` (or any run whose autonomy resolves to `autonomous`, `../../reference/autonomy.md`) the process is the same with two differences: nothing is asked — the DISPATCH PLAN and every routing choice are **recorded** as the Run objective, the card comment and the final report instead of announced — and the run ends at C6 with the accepted work merged locally and verified, never pushed. The account is fixed at launch: C0 reads the ambient login, compares it with the owner's account policy for unattended runs, and refuses to start on the wrong one — mid-run switching does not exist. Hard stops hold: a permission prompt in a worker, a quota death with no allowed fallback account, a decomposition with two materially different readings, or any outward action ends the run with a report that names the stop. Budget the run in wait windows, not wall-clock (`N` windows ≈ `9N` minutes), and write the handoff before the second compaction. An Orca automation with `--precheck` (`orca-substrate.md` § Scheduling) is the trigger for these runs; it invokes this skill and never duplicates its loop.

## Gotchas

_Add a line each time Claude trips on something._

- `input_accepted` / `dispatch_input: accepted` is NOT proof the worker started. The Enter is lost often enough that two 50-min wait windows burned on workers that never ran (measured). Prove the submit with a read within 30 s, then wait.
- A `check --wait` longer than ~10 min is where the silence comes from: the human asked "how is it going" 30+ times in two weeks, always 30–90 min after the last coordinator line. Nine-minute windows, one status line per expiry.
- Ending the turn with a dispatch open makes the runtime nag `You have 1 orchestration message` into the human's stream — 124 times in one session set. The coordinator drains its own inbox.
- `worker-start --model` takes opaque provider ids (`opus`, `gpt-…`); `--effort` requires `--model`; neither combines with `--terminal` (reuse keeps the terminal's model). `worktree create --agent codex` accepts no model flags at all — that is why launches go through `worker-start`.
- Orca CLI errors return `ok:false` with **exit code 0** — branch on `.ok`, never on `$?`. `worker-start` is the exception: it exits non-zero on anything but `ready`.
- Codex's exec sandbox may not reach the Orca socket, so a Codex worker's `worker_done` can fail while the work is fine. When a window expires with no message, read the branch (`git log`) and the terminal before concluding anything, and tell Codex workers to skip Orca reporting after one failure.
- `codex` may block startup on an "Update available" dialog with **Update now** preselected; `tui-idle` returns while it is up. Read the tail before sending anything; answer `2` (Skip).
- A worker in a worktree never sees files that are only untracked in the primary checkout. The human had to point this out; the untracked count in Context exists for that.
- Standing constraints (least code, no legacy compatibility once ratified, no narration comments, the model table) were retyped by the human 9+ times across dispatches. They belong in `.claude/run-policy.md`, appended to every brief.
- The human killed 21–24 background subagents at once, twice. A coordinator that fans out research spawns them from the plan, capped, and says how many; it never leaves them running past the decision they served.
- An S with no behaviour change wrapped in worker phases took 30+ min and drew "¿no era solo agregar un background?". The direct lane exists for exactly that.
- Quota exhaustion (Codex or Claude account) shows up as a dead worker with a dirty tree and no commit. Detect it from `worker-read`, report it, re-route; never sit on a wait window hoping for the reset.
- "merged", "ya mergeado" typed by the human 16+ times in two weeks. Merge state is one `gh pr view --json state,mergedAt` away; poll it on every window.
- Worker names used to carry only the issue (`issue-N-slug`), so the implement, audit, address and simplify sessions of one item shared one name and nothing said who was who — the human asked "¿cómo se llama la terminal con la que te estás comunicando?". `<task>-<role>-<model>` exists for that; the role is part of the name, not a comment.
- Measured over 125 briefs: MUST-NOT-touch was stated 85 % of the time, MAY-change 37 %, verification 30 %, report shape 34 %, model/effort 0 %. Prohibition is the reflex; the six slots are there because the positive half is what went missing.
- Four consecutive re-arms of a wait window on one worker is a failure signal (measured: ~36 min of empty windows on one leg). After one empty window, read the worker; after two, act.
- 18 % of measured briefs were byte-identical re-dispatches into a live worktree (seven simplify briefs into one checkout in 47 min = concurrent writers on one tree). `task-list` + `worker-list` before every `task-create`; a re-send is a resume, not a new task.
- Six dedicated checkouts were created for briefs that said `READ ONLY`. Readers share `current`; only writers get a worktree.
- Agent TUIs rewrite the terminal title every turn (Claude Code's `✳ …`), so `terminal rename` is cosmetic for under a minute. Identity lives in the worktree name (writers) or the Task title + dispatch id (readers); never in a pane title.
- `worker-start --name X` → branch `X`, path `…/workspaces/<repo>/X`, displayName `X`. It has no `--issue` flag; link the card with `worktree set --issue N` after creation.
- `worker-show` `observation.agentWait` **absent** means Orca never looked, not "not waiting" — fall through to `worker-read`. `null` is the only "no wait".
- Without `orca agent hooks on`, `worker-read` is a terminal tail and `agentWait` never populates; check `agent hooks status` in C0, and run `agent hooks prepare-codex` before a two-step Codex launch.
- `orca account list` is the **fallback set** (accounts registered with `orca account add`), not the active login: with `activeAccountId: null` every worker inherits the host's ambient login, which `claude auth status` reports and the list may not contain. Name the ambient account in the dispatch plan; an account absent from the list cannot be switched to mid-run — say so, do not start a login.
- `grep -c` prints `0` and exits 1 on no match; a `|| echo 0` rescue yields `0\n0`. Pipe through `wc -l | xargs` instead (the Context lines do).
