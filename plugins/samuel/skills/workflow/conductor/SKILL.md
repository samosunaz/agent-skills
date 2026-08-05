---
name: conductor
description: "Drive the pipeline unattended phase-by-phase. Can bootstrap from an item id, drive research→…→validate, and (in --ship mode) open a draft PR. Can be fired automatically by GitHub (schedule / issue-labeled) — see reference/automated-trigger.md. Trigger on 'conductor', 'run pipeline', 'correr pipeline solo', overnight/autonomous runs paired with /goal."
allowed-tools: Bash(git branch *) Bash(git rev-parse *) Bash(git worktree *) Bash(git status *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(gh *) Bash(bun *) Bash(npm *) Bash(pnpm *) Bash(node *) Bash(grep *) Bash(xargs *) Bash(test *) Bash(awk *) Bash(printenv *) Bash(date *) Bash(cat *) Bash(ls *) Read Edit Skill Agent PushNotification
---

# Conductor (Autonomous Pipeline Driver)

Chains the `/samuel:*` pipeline so it advances **without per-phase prompting** — for unattended / cloud / overnight runs paired with `claude -p` + `/goal` + `caffeinate`. The conductor never reimplements a phase: it reads state, decides the next `/samuel:*` skill, invokes it, and persists state.

Two autonomy ceilings:

- **Review mode (default)** — drive up to `validate`, then **hard-stop before any PR**. The human runs `/samuel:done`.
- **Ship mode (`--ship`)** — drive through `validate`, run the gate, then open a **draft PR** via `/samuel:done --draft` and stop. This is the headline autonomous loop: *item → branch → implement → validate → draft PR*. The human reviews, marks ready, merges. Merge is never automated.

## Mode

```
/samuel:conductor              — drive the active feature (task-context) to the review gate
/samuel:conductor 42           — bootstrap from item 42 (runs /samuel:start-task), then drive
/samuel:conductor --ship       — drive AND open a draft PR at the end
/samuel:conductor 42 --ship    — full loop: item 42 → branch → implement → validate → draft PR
/samuel:conductor status       — print phase + planned next step, then exit (no execution)
```

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Worktree: !`git rev-parse --git-dir 2>/dev/null | grep -q worktrees && echo "isolated worktree" || echo "no worktree"`
- CI runner: !`printenv GITHUB_ACTIONS 2>/dev/null || echo "local"`
- Dirty files: !`git status --porcelain 2>/dev/null | wc -l | xargs || echo "0"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Phase: !`awk '/^phase:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_PHASE"}' .claude/task-context.md 2>/dev/null || echo "NO_PHASE"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Spec required: !`awk '/^spec_required:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"unknown"}' .claude/task-context.md 2>/dev/null || echo "unknown"`
- Constitution: !`test -f CONSTITUTION.md && echo "present" || echo "none"`

Read `../../../reference/task-context.md` (state) and `../../../reference/tracker.md` (tracker).

## SAFETY GATE — refuse to run autonomously unless ALL hold

Autonomous mode writes code unattended (and, in ship mode, opens a PR). Before dispatching ANY phase, verify and **abort with a clear message** if violated:

1. **Isolated workspace** — isolation is satisfied by EITHER (a) an **isolated worktree** (`git rev-parse --git-dir` resolves under `worktrees/`), OR (b) a **CI runner** (`GITHUB_ACTIONS=true` **and** the branch is not `main`/`master`) — the ephemeral runner + a dedicated branch are equivalent isolation (see `../../../reference/automated-trigger.md`). **NEVER** drive on a *local* `main`/non-worktree checkout — the CI relaxation is CI-only and does not weaken this. (`status` mode is exempt.)
2. **Not on `main`/`master`** — must be a feature branch (holds for both worktree and CI).
3. **State present** — `.claude/task-context.md` with a known `phase`. If absent and an **item id was given**, bootstrap via `/samuel:start-task {item}` (worktree mode) first — the pickup contract applies: **plan drift escalates to the `/samuel:find-unknowns` preflight, and a `HOLD` verdict refuses the pickup** (stale map). If absent and no item, stop and tell the user.
4. **Authority ceiling** — **Review mode never** runs `git push` / `gh pr` / `/samuel:done`. **Ship mode may** `git push` + open a **draft PR** (`/samuel:done --draft`), and **only** that — never `gh pr merge`, never a ready PR, never to `main`. This authority exists only because the run was launched with that explicit goal.

If launched non-interactively, assume the operator set an `allow`/`deny` allowlist + isolated worktree (see `references/autonomous-run.md`). Do not silently relax these.

## Process (intent, not prescription)

1. **Resolve state.** Read `phase`. If a recent handoff exists and `phase` looks stale, prefer `/samuel:session-handoff resume` to rehydrate. If bootstrapping from an item id, run `/samuel:start-task {item}` first.
2. **Pick the next step** from the phase map, honoring `spec_required` and the constitution.
3. **Dispatch the matching `/samuel:*` skill** via the Skill tool. Let it own its work and advance `phase`. Don't duplicate phase logic.
4. **Run through gates.** Phases that normally pause (spec, plan, implement) proceed on sensible defaults — but every assumption, deferred clarification, and deviation MUST be recorded (a `gh issue comment` for hard STOPs; the journal D/V/T/Q for everything else) and surfaced in the handoff. On genuinely ambiguous + high-impact choices, take the conservative option and flag it; never invent product requirements.
5. **FIC checkpoint.** Before context pressure degrades quality (long phase, large diff, natural boundary), invoke `/samuel:session-handoff create` so a fresh session resumes cleanly.
6. **Advance** until `phase` reaches `validate` with a real validation report (gate run, evidence printed).
7. **Terminate by mode:**
   - **Review**: final handoff, print the resume command, exit. Never open a PR.
   - **Ship**: confirm the validation report's **`Overall: PASS`** (objective gate green **and** the independent reviewer raised no Blocker); if FAIL, do NOT open a PR — hand off the failure (a reviewer Blocker is a handoff, same as a red gate). If PASS, dispatch `/samuel:done --draft`, then exit reporting the PR URL.

## Phase Map

| Current `phase` | Next action | Autonomy |
|---|---|---|
| *(no state, item given)* | `/samuel:start-task {item}` (worktree) | bootstrap |
| `setup` | `/samuel:codebase-documentation` | auto |
| `research` | `/samuel:spec` if `spec_required`, else `/samuel:plan` | auto (records assumptions) |
| `spec` | `/samuel:plan` | auto (records assumptions) |
| `plan` | `/samuel:analyze` for non-trivial, else `/samuel:implement` | auto |
| `analyze` | `/samuel:implement` | auto (FIC between plan phases) |
| `implement` | `/samuel:validate` once all steps closed | auto |
| `validate` | Review → **STOP** + handoff · Ship → `/samuel:done --draft` if `Overall: PASS` | gate (human merges) |
| `end` | already closed — nothing to do | — |

## Stop / Exit Report

On every termination, print:

```
Conductor stopped.
Mode:       [review | ship]
Reason:     [review-gate | shipped-draft-pr | turn-budget | safety-abort | blocker]
Item:       [id]
Phase:      [phase reached]
PR:         [draft url | none]
Handoff:    [doc-id]   (resume: /samuel:session-handoff resume [doc-id])
Journal:    D:[n] V:[n] T:[n] Q:[open]
Next human step: [review draft PR & merge | review artifacts then /samuel:done]
```

Then fire `PushNotification` with the Reason + Next human step — an overnight run ends while nobody is watching, and the report is worthless until someone knows it exists. It announces; it never collects an answer. The conductor asks nothing at all (`../../../reference/interaction-tools.md` § Boundary): record-and-proceed is the whole point of unattended mode, and opening a question dialog stalls the run until it times out. A conductor run is `autonomous` **regardless of any `autonomy:` key** in the repo's `.claude/samuel.md` — the file cannot grant the level and cannot take it away (`../../../reference/autonomy.md` § Resolution, step 0). The dispatched skills inject that key into their own context; ignore it.

**In an autonomous run** (CI or `claude -p`), also post the report as a comment on the rolling **`conductor:log`** issue — find the open issue labeled `conductor:log`, create it if absent (title `Conductor run log`, same label):

```bash
gh issue list --label conductor:log --state open --json number --jq '.[0].number'
```

This is the run's **narrative** half — the Reason, the assumptions taken, what the next human should look at. The mechanical rollup posted by the workflow (`assets/conductor.yml`, one table row per item) can't produce it, and the two are deliberately separate comments on the same issue. **Interactive runs don't post** — the report is already on screen. A hard abort (turn or budget cap killing the process) never reaches this step, so the log issue then carries only the mechanical rollup: lessons are best-effort by construction, the counters are not. Bootstrap of the label + issue is part of activation — `../../../reference/automated-trigger.md` § Caps & run accounting.

## Guidelines

1. **Orchestrate, don't reimplement.** Each `/samuel:*` skill owns its phase.
2. **Bias to stop over to guess.** A clean handoff with an open question beats code on a wrong assumption.
3. **Record everything.** Unattended decisions are invisible unless written to the tracker + journal + handoff. The morning review depends on this trail.
4. **GitHub is SoT** for items/decisions; task-context `phase` is SoT for pipeline position.
5. **Ship mode is gated on `Overall: PASS`.** That means the objective gate is green AND the independent reviewer (validate Step 2.5) raised no Blocker. A draft PR on a red gate or an unaddressed reviewer Blocker is worse than no PR — hand off the failure instead.

## Gotchas

_Add a line each time Claude trips on something._

- Refuse on a *local* `main`/non-worktree checkout — isolation is non-negotiable. The one exception is a CI runner (`GITHUB_ACTIONS=true` + non-main branch), which is equivalent isolation (`../../../reference/automated-trigger.md`).
- Review mode never pushes or opens PRs. Ship mode opens a **draft** PR only, never merges, never a ready PR.
- Ship mode requires the validation report's **`Overall: PASS`** (gate green + no reviewer Blocker) — don't open a PR off an unverified/red gate or an unresolved reviewer Blocker.
- `/samuel:plan` and `/samuel:implement` are built around human checkpoints; driving them trades review for a recorded-assumptions trail — the explicit cost of autonomy.
- FIC before, not after, quality degrades — a handoff from a drifted context inherits the drift.
- Open questions with `Blocking: yes` in the journal are a stop signal — hand off, don't guess past them.
- Bootstrap-from-item only works with an **item id** that exists as an Issue; without it and without task-context, abort. A fired drift check at pickup escalates to the `/samuel:find-unknowns` preflight — its `HOLD` refusal is a clean exit (stale map), not an error to work around.
- `--output-format stream-json` **hard-errors without `--verbose`** (`stream-json requires --verbose`). Every launcher that captures cost passes both — dropping `--verbose` kills the run before it starts, not silently.
- `budget-exhausted` is a rollup-only reason, deliberately absent from the `Reason:` enum above: the `--max-budget-usd` kill takes the process down where it stands, so this report is never printed or posted. The item surfaces only in the workflow's mechanical rollup, charged at the full cap.

## See Also

- `references/autonomous-run.md` — launch recipe: caffeinate / droplet + `claude -p` + `/goal` + gh permission allowlist + worktree isolation + the multi-item loop.
- `../../../reference/automated-trigger.md` — the **automatic trigger** (heartbeat): GitHub fires the loop on a schedule / `issues:labeled` and opens a draft PR. Ships the committed workflow template `assets/conductor.yml`. CI is equivalent isolation for the SAFETY GATE above.
