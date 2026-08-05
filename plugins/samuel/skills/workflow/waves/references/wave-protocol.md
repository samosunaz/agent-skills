# Wave Protocol — DAG-driven multi-issue execution over Orca

The executable recipes behind `/samuel:waves`. The coordinator is a **live attended session** in the target repo's primary checkout; workers are isolated implementers in Orca-managed worktrees. GitHub is the only durable state — the blockedBy graph, PR state, and labels survive any crash; Orca orchestration state is disposable provenance (see § State & recovery).

Boundary (anti-doble-scheduler, decided in #30): **waves = coordinator** (which items enter which wave, and when) · **conductor = per-item engine** · **Orca automations = calendar trigger**. An automation may *invoke* waves; waves never duplicates conductor's pipeline logic and never schedules itself.

Authority ceiling (ADR 0004): the launch itself grants each worker push + **draft** PR authority and the coordinator comment authority **on the issues being driven** — nothing else. Merge, `gh pr ready`, and issue close are the human's, at every step of this protocol.

## P0 — Preconditions

Run all five before proposing a wave plan; a failed precondition stops the run before any dispatch.

```bash
orca status --json                       # runtimeState + graphState must be "ready"
orca orchestration task-list --json      # errors ⇒ orchestration (Experimental) is off in Orca Settings
gh auth status                            # gh must be authenticated
orca repo list --json | jq -r '.result.repos[] | select(.path == "{ABS_REPO_PATH}") | .id'
                                          # → {ORCA_REPO_ID}. Resolve by PATH, never by name: the name:
                                          #   selector matches Orca's displayName (not the GitHub repo name),
                                          #   and one GitHub repo may back several Orca checkouts.
                                          #   Empty output ⇒ repo not registered in Orca — stop.
orca repo show --repo id:{ORCA_REPO_ID} --json
                                          # note worktreeBaseRef (set it if missing:
                                          #   orca repo set-base-ref --repo id:{ORCA_REPO_ID} --ref origin/main).
                                          # Orca errors return ok:false with EXIT CODE 0 — check .ok, not $?
gh repo set-default {OWNER}/{REPO}        # never parse the SSH-alias origin — use .claude/samuel.md `repo`
```

If prior wave state exists (`task-list` non-empty from an interrupted run), go to § State & recovery before creating anything.

## P1 — Intake & wave computation

**Input**: an explicit issue list, a label, or a milestone. **Eligible**: `pipeline:ready` only — promotion (plan present + preflight `READY`) happened upstream; waves never plans on the fly.

1. Fetch candidates + their plans + the graph (recipes: `reference/github-operations.md` § Issue dependencies — batch by alias, one call):
   - body must contain a filled `<!-- samuel:plan -->` section (an unplanned body says `_Not planned yet_` — exclude).
   - `blockedBy.nodes` with `number` + `state` per issue.
2. Partition into waves by **peeling**, two ordered passes: **(a) exclude** every candidate with an open (`state: OPEN`) blocker *outside* the candidate set — external dependency, park it and report it; **(b)** wave 1 = remaining candidates with **zero open blockers**. Remove them, treat them as satisfied-on-merge, peel again for wave 2, and so on. A cycle (no peelable issue while candidates remain) is a graph bug — stop and report the cycle members.
3. Report exclusions explicitly: not `pipeline:ready` · plan missing · blocked by an issue outside the candidate set · cycle member. Silent exclusion reads as "covered" — never do it.

The wave partition + per-issue engine proposal + concurrency cap is the **WAVE PLAN checkpoint** in the hub SKILL.md. Nothing is created or dispatched before it.

## P2 — Orca mirror

Mirror the approved DAG into orchestration state for provenance and as external memory:

```bash
orca orchestration task-create --spec "{issue-N worker contract — see P3}" --deps '["task_id_a","task_id_b"]' --json
orca orchestration task-list --ready --brief --json   # provenance / external memory — NEVER the dispatch trigger
```

Create tasks wave-by-wave or all upfront with `--deps` mirroring blockedBy (task ids, not issue numbers — keep a `#N → task_id` map in the session). Loop over the issue numbers themselves (`for n in 478 484 391`), never over C-style indices: under zsh, arrays start at 1, so `for i in 0 1 2 3 4` mints one task from empty strings and drops the last issue. Verify the created titles against the wave set before dispatching — `task-create` has no delete, and the repair is `task-update --status failed` plus a replacement task. **Orca readiness is not dispatchability**: a task completes — and its dependents turn `--ready` — when its worker sends `worker_done` at *draft-PR* time, hours before the human merge. Dispatch is decided exclusively by the GitHub graph (every blocker `CLOSED`, P5); `task-list` is the crash-recovery mirror of what was attempted, nothing more.

## P3 — Dispatch

### Baseline drift gate (before any worktree)

Plans cite `file:line`. `origin/main` moves while they sit in the backlog — and again while the WAVE PLAN checkpoint waits for the human. Diff the plan's baseline against the base ref the worktrees will branch from, then intersect with each plan's owner files:

```bash
git fetch origin
git diff --name-only {PLAN_BASELINE_SHA}..origin/main > /tmp/drift.txt
# per issue: grep its Executor Plan owner files against /tmp/drift.txt
```

A hit does not invalidate the issue — it invalidates the plan's references, and sometimes adds surface the plan never covered (a sibling PR that restructured the same file). Post the drift as a comment on the affected issues (coordinator comment authority, ADR 0004) and name it in the worker's launch prompt; the worker reads the issue, not this session. Zero hits is also a finding — say so instead of staying silent.

### Per issue

Per ready issue, up to the approved concurrency cap (default **3**; excess queues until a slot frees):

### Codex worker (default engine)

```bash
# Preferred: agent-first create — Codex lands in the first terminal, no fallback shell.
# Model/effort come from Orca Settings agentDefaultArgs (#30 P1).
orca worktree create --repo id:{ORCA_REPO_ID} --name issue-{N}-{slug} --issue {N} --no-parent --agent codex --json
# → copy the FULL worktree id `<repoId>::<path>` and startupTerminal.handle from the response
```

- **Two-step fallback** (agentDefaultArgs not configured — explicit model/effort argv; may leave a fallback shell, close it only after `terminal show` confirms it's an unused shell):
  ```bash
  orca worktree create --repo id:{ORCA_REPO_ID} --name issue-{N}-{slug} --issue {N} --no-parent --json
  orca terminal create --worktree id:{repoId}::{path} --title issue-{N} \
    --command 'codex --model gpt-5.5 -c model_reasoning_effort="high"' --json
  ```
- Then, for either path:
  ```bash
  orca terminal wait --terminal {handle} --for tui-idle --timeout-ms 60000 --json
  orca orchestration dispatch --task {task_id} --to {handle} --inject --json
  ```

`--no-parent` + no `--base-branch` = top-level worktree from the repo's default base — every wave starts from current `origin/main` by construction. `--issue {N}` links the card; `issue:{N}` becomes a valid worktree selector for the rest of the run.

### Worker contract (the task spec `--inject` delivers)

Fill and use as the `task-create --spec` text. It must be self-contained — Codex has no samuel skills, no chat history. The `{coordinator_handle}`, `{task_id}`, `{dispatch_id}` placeholders are resolved by the lifecycle preamble `dispatch --inject` prepends — the worker reads the concrete values there; keep the placeholders in the spec so the delivery steps stay explicit even if the preamble format changes:

```text
ROLE: You implement exactly one GitHub issue in this dedicated worktree, then stop.

ISSUE: #{N} — {title} ({url})

EXECUTOR PLAN (the contract — implement ONLY this scope):
{paste the issue's <!-- samuel:plan --> section verbatim}

DELIVERY:
1. Read the plan's Relevant code files before editing anything.
2. Implement the plan's Steps in order; run each Step's Verify.
3. Run the plan's gate command (Validation § Automated); fix failures until green.
4. Commit in atomic conventional commits. No AI attribution, no Generated-with footers.
5. Push the branch. Open a DRAFT PR: `gh pr create --draft --title "{type}: {summary}" --body "..."`
   — body opens with a 4-line Spanish TL;DR and contains `Closes #{N}`.
6. Update the card: `orca worktree set --worktree active --workspace-status in-review --comment "PR abierto: {pr-url}"`.
7. Report done (single message, from this terminal):
   `orca orchestration send --to {coordinator_handle} --type worker_done --subject "issue {N} shipped" --body "{3 sentences: did / found / left}" --payload '{"taskId":"{task_id}","dispatchId":"{dispatch_id}","prUrl":"{pr-url}","filesModified":[...]}' --json`
   Then idle. Do not poll.

SKILLS: any pipeline skill you invoke MUST come from the `samuel` plugin — `$samuel:<skill>` under Codex, `/samuel:<skill>` under Claude. Never a same-named skill from another installed registry: skill names overlap across registries, and the other variant assumes conventions this repo does not follow. If a cached index offers both, take `samuel`; when in doubt invoke nothing — this contract is self-contained.

LIMITS: never merge, mark ready, or close anything · scope beyond the plan is out — note it in the PR body instead ·
blocked ⇒ `orca orchestration ask --to {coordinator_handle} --question "..."` and wait · gate must be green before the PR.
```

### Claude worker (variant — taste ≥ 7 or genuinely hard items, chosen at the WAVE PLAN checkpoint)

Runs the full samuel pipeline per item — autonomous-run.md §4a verbatim, inside the Orca worktree. No orchestration inject (headless `claude -p` has no TUI to inject into); completion = process exit. Three steps, in order:

```bash
# 1. Guard the shell BEFORE create — you pick the name, so the path is known (dotenv gotcha).
printf '%s\n' "{WORKTREE_PATH}" >> ~/.oh-my-zsh/cache/dotenv-disallowed.list
orca worktree create --repo id:{ORCA_REPO_ID} --name issue-{N}-{slug} --issue {N} --no-parent --setup run --json
```

**2. Permission allowlist** — autonomous-run.md §2, written to **`.claude/settings.local.json`**, never `settings.json`: the tracked file would land in the worker's diff and ship inside its PR. `settings.local.json` is gitignored in most repos — confirm it, then verify `git status --porcelain` is still empty before launching. Author it with the **Write tool**; the auto-mode classifier denies permission config written through Bash.

```bash
# 3. Launch. --model is not optional: headless inherits the user's configured default,
#    which is not necessarily the engine approved at the WAVE PLAN checkpoint.
orca terminal create --worktree id:{repoId}::{path} --title issue-{N}-conductor \
  --command 'export GH_CONFIG_DIR="{gh_config_dir}"; claude -p "/samuel:conductor {N} --ship
  /goal ship item {N} as a draft PR with a green gate; record assumptions; never merge/ready. Stop after 40 turns." --model {model} --max-budget-usd {budget} --output-format stream-json --verbose | tee ~/conductor-{N}.jsonl' --json
orca terminal wait --terminal {handle} --for exit --timeout-ms 3600000 --json
tail -n 1 ~/conductor-{N}.jsonl | jq -r 'select(.type=="result") | .subtype'   # success | error_* | absent ⇒ aborted
```

Launch the **first** worker alone and confirm it booted before releasing the rest: the log's opening `{"type":"system","subtype":"init"}` line carries `model`, `cwd`, and the loaded plugins. No init line means the terminal died at shell start — fix that once instead of five times.

`--max-budget-usd` is a hard kill, not a report; the help text's `(only works with --print)` says where the flag applies, not what it does. A cap that fires mid-item leaves a half-done branch (autonomous-run.md § Failure modes), so size it above the item's expected cost and let the turn limit bind instead.

Autonomy resolves itself (headless `claude -p` = `autonomous`, `reference/autonomy.md` step 0) — no extra wiring. Outcome taxonomy and cost extraction: autonomous-run.md §3.5.

## P4 — Supervision

One rolling loop for the whole wave. N in-flight workers ⇒ up to N `check --wait` completions plus the claude-variant exit waits:

```bash
orca orchestration check --wait --types worker_done,escalation,decision_gate --timeout-ms 900000 --json
```

- **`worker_done`** → trust but verify: `gh pr view {prUrl} --json state,isDraft` (the PR must exist and be a draft), then `gh pr checks {n} --watch --interval 30` or poll per window. Card → the worker set `in-review`; fix it if it didn't.
- **Red CI** → distinguish a real failure from a run cancelled by a subsequent push. A real failure gets **one** re-dispatch to the same worker — same task, new dispatch, the failing check's output pasted into the prompt — then any second failure escalates to the human. The orchestration circuit breaker (3 failed dispatches → task `failed`) is the backstop, not the policy.
- **`decision_gate` / `ask`** → answer from the coordinator's context (`orca orchestration reply --id {msg_id} --body "..."`); anything touching scope, schema, or another issue's territory goes to the human first.
- **`escalation`** → park the issue (report row: `escalated`), free its concurrency slot, continue the wave.
- **Timeout** → a checkpoint, not a failure: inspect `task-list --brief` and `terminal read`; a live worker (output advancing, heartbeats) keeps running. Never kill a worker for slowness; 15-60 min tasks are normal.
- Dispatch queued issues as slots free. Update the coordinator's own card comment at wave milestones (`orca worktree set --worktree active --comment "onda 2: 3/4 PRs abiertos"`).

**Claude-variant supervision.** These workers send no orchestration messages, and `terminal wait --for exit` blocks on one worker at a time — useless for a fan-out. Watch the logs instead, as a single backgrounded poll that wakes the coordinator when the wave drains:

```bash
END=$(( $(date +%s) + 14400 ))
while [ "$(date +%s)" -lt "$END" ]; do
  n_done=0
  for n in {ISSUES}; do
    tail -n 3 ~/conductor-$n.jsonl 2>/dev/null | grep -q '"type":"result"' && n_done=$((n_done+1))
  done
  [ "$n_done" -ge {COUNT} ] && break
  sleep 90
done
for n in {ISSUES}; do
  tail -n 3 ~/conductor-$n.jsonl 2>/dev/null | jq -r 'select(.type=="result")
    | "#'"$n"' \(.subtype) · $\(.total_cost_usd) · \(.num_turns) turns"'
done
```

The result line is the outcome claim, not the outcome: a `success` subtype still needs the trust-but-verify PR check above.

## P5 — Release (the human merge gate)

The human merging the wave's draft PRs **is** the gate — the coordinator never asks to merge, never marks ready, only detects:

```bash
gh pr view {n} --json state,mergedAt --jq '"\(.state) \(.mergedAt)"'   # per wave PR, each supervision window
```

When every wave PR is merged (or explicitly parked by the human):

1. Clean the merged worktrees: `orca worktree rm --worktree issue:{N} --force --json` (landed-sweep is the backstop for stragglers; Orca metadata needs the Orca-side rm).
2. Mark mirrors: `orca orchestration task-update --id {task_id} --status completed --json` for merged items whose worker already sent `worker_done` under a prior dispatch — skip when the `worker_done` itself already completed the task.
3. Recompute the graph (§ Issue dependencies read recipes) — merged blockers are now `CLOSED`; peel the next wave.
4. `git fetch origin` in the primary checkout — the next wave's worktrees branch from the updated base ref by construction (P3), but the coordinator's own view should match reality.
5. Dispatch the next wave (P3). Partially-merged waves may release early: an issue whose *specific* blockers are all merged is dispatchable even if an unrelated wave-mate is still open — the graph, not the wave label, is the truth.

## P6 — Exit & report

Exit on: DAG exhausted · TTL/turn budget reached · user stop. Always leave a report — the run's narrative goes to the rolling `conductor:log` issue (ADR 0003), one comment:

```bash
gh label create conductor:log -c 0E8A16 -d "Rolling conductor run log" --force   # guard — the label may not exist yet
LOG=$(gh issue list --label conductor:log --state open --json number --jq '.[0].number')
case "$LOG" in
  ""|null) LOG=$(gh issue create --title "Conductor run log" --label conductor:log \
             --body "Rolling log — one comment per conductor run. Keep open." | sed 's#.*/##') ;;
esac
gh issue comment "$LOG" --body-file {report.md}
```

Report shape: header `**Waves run** — {repo} · {date} · {n} ondas`, one row per issue — `| issue | onda | engine | outcome | PR |` with outcome ∈ `shipped` (draft PR open) · `merged` (human accepted during the run) · `escalated` · `parked` (blocked external / cycle) · `aborted` — then totals and worktrees left alive. Escalated/parked rows name their reason; a truncated run says what it did not cover.

Cleanup: worktrees of unmerged PRs stay alive (the human reviews there); `orca orchestration reset --tasks --json` only when nothing is active and the report is posted.

## State & recovery

| State | Home | Survives crash |
|---|---|---|
| Dependency graph | GitHub native blockedBy | yes — SoT |
| Item plans + AC | Issue bodies | yes — SoT |
| PR / CI / merge state | GitHub | yes — SoT |
| Wave membership, dispatch, worker_done | Orca orchestration tasks | no — disposable mirror |
| Worker checkouts | Orca worktrees (`issue:{N}` selector) | yes — re-attachable |

Recovery = re-run `/samuel:waves` with the same input: P1 recomputes waves from GitHub; existing worktrees are re-attached by `issue:{N}` (a worktree with an open draft PR ⇒ its issue is `shipped`, don't re-dispatch); orphaned orchestration tasks are reset. Never reconstruct state from terminal scrollback.
