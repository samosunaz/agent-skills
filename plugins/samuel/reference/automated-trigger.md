# Automated Trigger — the Pipeline's Heartbeat

How to make the autonomous pipeline **start itself**. The conductor (`../skills/conductor/SKILL.md`) and its launch recipe (`../skills/conductor/references/autonomous-run.md`) already drive an item to a draft PR unattended — but the *trigger* is manual: a human SSHes into a droplet and runs `claude -p "/samuel:conductor N --ship"`, or a bash loop over `pipeline:ready`. This reference adds the missing **heartbeat**: GitHub (or a routine) fires the loop on its own. That closes gap #1 of #8 — the conductor goes from *context-independent* to *process-independent*.

> **This is a scaffold, not a live trigger.** The committed workflow **template** lives at `../skills/conductor/assets/conductor.yml`. A consumer repo copies it to `.github/workflows/`, wires the secrets, and turns it on. Nothing here arms a trigger automatically.

## The three mechanisms

| | Mechanism | When |
|---|---|---|
| **A** | **GitHub Action, GitHub-hosted runner** (`ubuntu-latest`) | Default. No dependency on the maintainer's hardware — the spirit of gap #1. |
| **B** | **GitHub Action, self-hosted runner** (the droplet) | When the gate needs the droplet's full environment (a real DB, prod-shaped services). |
| **C** | **Claude Code routine** (`/schedule`) | A lightweight cron that runs `claude -p` from an already-configured machine. Brief — see the end. |

A and B share **one** workflow file; switching is **only a `runs-on:` change** (see the table at the bottom and the comment in the template).

## A — GitHub Action on a hosted runner (the primary scaffold)

The template is a complete, commented workflow. Walked through:

### Triggers

```yaml
on:
  schedule:
    - cron: "0 9,15 * * 1-5"        # heartbeat — twice daily on weekdays (adjustable)
  issues:
    types: [labeled]                # fire the moment an issue becomes pipeline:ready
  workflow_dispatch:
    inputs: { issue: { description: "Issue number", required: true } }
```

- **`schedule`** is the heartbeat: it sweeps the whole `pipeline:ready` inbox (the query from `./github-operations.md` — `gh issue list --label "pipeline:ready"`).
- **`issues: [labeled]`** is event-driven: a single issue ships the moment it's marked ready. The job is gated on `github.event.label.name == 'pipeline:ready'` so it fires **only on that exact transition**, not on every later label change.
- **`workflow_dispatch`** is the manual escape hatch (ship one issue on demand).

### Job `conductor`

- **`if:`** — `github.event.label.name == 'pipeline:ready' || github.event_name != 'issues'` (label transition, or any non-issue event).
- **`runs-on: ubuntu-latest`** — *change to `self-hosted` for option B; that is the only diff.*
- **`permissions:`** — `contents: write` (push the branch), `pull-requests: write` (open the draft PR), `issues: write` (comment / labels). The least set the draft-PR-only authority needs.
- **`env:`** — `GH_TOKEN: ${{ github.token }}` (the runner's token authenticates `gh`), `ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}`.

Steps:

1. **`actions/checkout@v4`** with `fetch-depth: 0` (the conductor needs full history for branching/diffs).
2. **Pre-stage `~/.claude/settings.json`** — there is no first-class "install plugin" Action input, so write the settings file the plugin runtime reads. It carries `extraKnownMarketplaces` + `enabledPlugins` (the shape from `README.md` "Per-project setup") **plus** the `permissions` `allow`/`deny` allowlist from `../skills/conductor/references/autonomous-run.md` (the same tight list that bounds a manual unattended run). `deny` keeps `gh pr merge`/`ready`/`issue close` off the table.
3. **`npm i -g @anthropic-ai/claude-code`** — the CLI is the invocation surface.
4. **Resolve the target issue and run the conductor headlessly** — `github.event.issue.number` for the labeled event, `inputs.issue` for dispatch, or the `pipeline:ready` loop for `schedule`. The command is **verbatim** the canonical recipe from `autonomous-run.md`:
   ```bash
   claude -p "/samuel:conductor <issue> --ship
     /goal ship a draft PR with a green gate; record assumptions; never merge/ready.
     Stop after 40 turns." --max-turns 50
   ```
   `--max-turns 50` is a hard backstop **above** the `/goal` "Stop after 40 turns" brake. No `--model` — IDs rotate; the template leaves a commented pin (`# --model claude-opus-4-8  # use the current Opus id`).
5. **Post the run report** (`if: always()`) — the `conductor:log` comment + `$GITHUB_STEP_SUMMARY` table described under § Caps & run accounting.
6. **Upload conductor transcripts** — `actions/upload-artifact@v4`, **private repos only**, 3-day retention. See the exposure note in § Caps & run accounting.

### Caps & run accounting

Four brakes, two of turns and two of money:

| Cap | Where | Default |
|---|---|---|
| `/goal` "Stop after N turns" | the agent's own brake, inside the prompt | 40 turns |
| `--max-turns` | CLI hard backstop above it | 50 turns |
| `--max-budget-usd` | CLI, **per item** — kills the run when spend hits it | `ITEM_BUDGET_USD: "10"` |
| sweep accumulator | the workflow's `schedule` loop, **between items** | `SWEEP_BUDGET_USD: "40"` |

Both budgets are job-level `env` in the template — tune them per repo. The sweep cap only ever stops the *next* item; it cannot cut a run already in flight, which is why the parallel SSH recipe has no equivalent (`../skills/conductor/references/autonomous-run.md` § Parallel variant).

**Capture.** Every `claude -p` invocation runs `--output-format stream-json --verbose` into a `.jsonl` — `stream-json` hard-errors without `--verbose`. The last JSONL line is the result object (`total_cost_usd`, `num_turns`, `usage.input_tokens`/`output_tokens`, `subtype`, `is_error`); `jq` reads it into one TSV row per item. A run killed by a cap can die **before** emitting `result` — that row is `aborted`, charged the full item cap, so the accumulator never fails open.

The two paths differ in one detail: the SSH recipes `tee`, because the file lands on your own droplet. **The CI template redirects (`> <log>.jsonl`) and never tees** — `--verbose` emits every message *and every tool result*, and a step log is world-readable on a public repo. For the same reason the `Upload conductor transcripts` step (`if: always() && github.event.repository.private`, 3-day retention) is gated to **private repos only**: artifacts get no secret masking at all, so on a public repo the transcript stays on the runner and dies with it.

**Outcome** per item: `shipped` (draft PR exists) · `aborted` (non-`success` subtype, `is_error`, or no result line) · `escalated` (finished, no PR — red gate, blocker, preflight `HOLD`). *Accepted* is deliberately **not** here: it only exists once a human merges, and is computed at the morning review below.

**The run report.** One comment per run on a rolling issue labeled **`conductor:log`** (title `Conductor run log`, found-or-created by the workflow): a header line (`event · UTC timestamp · Action run link`), a `| item | cost (USD) | turns | tokens (in/out) | outcome |` table, totals, and the budget status. The same table goes to `$GITHUB_STEP_SUMMARY`. The SSH recipes post to the **same** issue, so manual and automated runs share one timeline — that's the point of putting it on GitHub instead of in `$GITHUB_STEP_SUMMARY` alone.

**Bootstrap** (part of activation, alongside the secrets): nothing to do by hand — the workflow runs `gh label create conductor:log --force` and creates the issue on its first run. Create them early only if you want the issue pinned. Keep that issue **open**; closing it makes the next run open a second one and split the timeline.

The conductor also posts its own Stop/Exit Report there on autonomous runs — the narrative half (reason, assumptions, next human step) next to the mechanical rollup (`../skills/conductor/SKILL.md` § Stop / Exit Report).

### Post-CI-check job `ci-check`

A cheap `run:`-only job (`needs: conductor`) — no agent, no Opus sitting idle — that closes the loop:

- **Single-issue events only** (`github.event_name != 'schedule'`), and on conductor **success or failure** (`always()` + a `needs.conductor.result` guard) so a turn-cap / agent-error stop still surfaces on the issue rather than vanishing as a skipped job. A `schedule` run ships N issues; one downstream job can't fan out a per-PR comment cleanly, so multi-item runs lean on the morning review instead.
- Resolve the PR **by branch head** (`gh pr list --head <branch> --json number`), not via job outputs — the PR number only exists after `claude -p` runs. The `conductor` job emits `outputs.issue` **up front** (so a failed run can still be reported) and `outputs.branch` after the agent creates it.
- `gh pr checks <pr> --watch`, then `gh issue comment <issue>` with ✅ green / ❌ red + the checks URL. If the conductor produced no PR (red gate / blocker) or aborted (turn cap / error), it posts a 🟡 note instead — on a single-issue run the loop always reports *something*.
- It **never** calls `gh pr ready` or `gh pr merge` — marking ready and merging stay human.

### Required secrets

| Secret | Source | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | repo/org secret | Authenticates `claude -p`. **Subscription alternative:** `CLAUDE_CODE_OAUTH_TOKEN` (a Claude subscription OAuth token) instead of an API key. |
| `GH_TOKEN` | `${{ github.token }}` (no secret to create) | The runner's built-in token; authenticates `gh` for issue/PR ops. Scope it via the job `permissions:` block. |

## CI is equivalent isolation

A hosted runner uses a normal `actions/checkout` — **not** a git worktree — so the conductor's SAFETY GATE would abort in CI today (it requires a worktree under `worktrees/`). The gate is therefore extended (see `../skills/conductor/SKILL.md` SAFETY GATE and `../skills/start-task/SKILL.md`): isolation is satisfied by a worktree **OR** by `GITHUB_ACTIONS=true` **AND** a non-`main`/`master` branch. The ephemeral runner + a dedicated feature branch are equivalent isolation. A **local** `main`/non-worktree checkout is still refused — the relaxation is CI-only. In CI, `start-task` creates the branch in the current checkout (no `git worktree add`).

## Morning review

Same as a manual unattended run: the night leaves draft PRs; review them with `gh pr list --draft` / `gh pr view` / `gh pr checks` / `gh issue view --comments`, then mark ready + merge by hand. The full sequence is in `../skills/conductor/references/autonomous-run.md` ("Morning review"). Start from the `conductor:log` issue — its last comment says what the run cost and which items it claims to have shipped.

### Cost per accepted change

The loop's one honest number. `shipped` means the agent opened a draft PR; **accepted** means you merged it. Only the second is worth paying for, and only you can produce it — hence the metric is computed here, not automated:

```bash
gh issue list --label conductor:log --state open -R owner/repo          # find the log issue
gh issue view <log> -R owner/repo --comments | tail -40                 # last run: cost + shipped count
gh pr list --state merged -R owner/repo --search "merged:>=2026-07-26"  # what actually landed
```

**cost per accepted change = sweep cost ÷ merged PRs from that sweep.** Track the ratio alongside it: `merged ÷ shipped` is the **acceptance rate**. Below **50 %** the loop is losing — you are paying for draft PRs you then throw away, and reviewing them costs more attention than writing the change would have (the threshold comes from discovery #8). React by shrinking items (the plan sizing rule) or tightening the plans before the run, not by raising the budget.

A sweep whose items are all `escalated` costs money and produces nothing mergeable — that is the failure this metric exists to make visible, and it looks *identical* to a quiet night until you read the log.

## B — self-hosted runner (the droplet)

Identical workflow; **only `runs-on:` changes** to `self-hosted` (or a runner label). Because the invocation is `claude -p` either way, option B **is the maintainer's current manual droplet flow, just GitHub-triggered** — same command, same environment, no second invocation surface. Isolation on the droplet still uses a worktree (the filesystem persists across runs, unlike an ephemeral hosted runner), so the worktree branch of the SAFETY GATE applies there. The maintainer dogfoods B first.

### A vs B

| | A — GitHub-hosted | B — self-hosted (droplet) |
|---|---|---|
| Environment parity | Clean Ubuntu; install everything per run | Full droplet env (real DB / services) available to the gate |
| Runner minutes | Billed GitHub Actions minutes | $0 — the maintainer's hardware |
| Isolation model | Ephemeral runner + feature branch (CI-isolation rule) | Worktree on the persistent filesystem |
| Setup | Secrets only | Register a self-hosted runner once + secrets |
| Switch cost | — | **Only** `runs-on: self-hosted` |

## C — Claude Code routine (brief)

If a machine is already configured with the plugin + `gh` + the allowlist (e.g. the droplet, or a dev box), a Claude Code **routine** (`/schedule`) can run the same `claude -p "/samuel:conductor … --ship"` on a cron without any GitHub Actions YAML. Lightest weight, but it depends on that machine staying up and configured — it does **not** remove the hardware dependency the way A does. Use it for a quick local heartbeat; prefer A/B for a durable, repo-owned trigger.

## See also

- `../skills/conductor/assets/conductor.yml` — the committed workflow template (the artifact this reference explains).
- `../skills/conductor/references/autonomous-run.md` — the manual launch recipe, the permission allowlist, and the morning review (this reference is the automatic *trigger* upstream of it).
- `../skills/conductor/SKILL.md` — the conductor + the CI-aware SAFETY GATE.
- `./github-operations.md` — the `gh` adapter (`pipeline:ready` query, labels, PR ops).
