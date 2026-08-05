# 0003. The conductor reports to a rolling `conductor:log` issue

- **Status**: accepted
- **Date**: 2026-07-26

## Context

The autonomous loop (`/samuel:conductor`, the heartbeat workflow, the SSH recipes) had no reporting surface. A run's cost, turn count and outcome existed only inside the transcript of whichever process happened to run it: an Actions step log that expires, or a `nohup` file on a droplet nobody logs into. Answering "what did the loop do last night, and was it worth the spend?" meant reading logs — so nobody asked, and the loop's own kill/keep rule (cost per *accepted* change, discovery #8) had no inputs.

Three launch paths produce runs — the scheduled workflow, a manual `workflow_dispatch`, and an SSH `claude -p` — and each would otherwise grow its own reporting. Two shapes of information come out of a run and they don't come from the same place: a **mechanical rollup** (one row per item: cost, turns, tokens, outcome) that only the launcher can produce, and a **narrative** (why it stopped, what it assumed, what the next human should look at) that only the conductor itself can produce.

Candidate homes considered: a committed file under `docs/` (a nightly loop writing to `main` on a repo it also branches from — merge conflicts and noise), the Actions run summary alone (correct for CI, invisible to the SSH path, and it expires), one issue per run (a backlog of dead issues on a repo whose issue list *is* the work queue), and a GitHub Discussion (a second surface with its own labels, and `gh` support is thinner than for issues).

## Decision

**One long-lived open issue per repo, labeled `conductor:log`, is the loop's reporting home.** Every run appends a comment to it; nothing overwrites, nothing rotates.

- **Both halves post to the same issue as separate comments.** The workflow posts the mechanical table (`if: always()`, so an aborted sweep still reports); the conductor posts its Stop/Exit Report when the run is autonomous. Interactive runs don't post — the report is already on screen.
- **Find-or-create, never assume.** `gh issue list --label conductor:log --state open --json number --jq '.[0].number'` → create with title `Conductor run log` if absent. Bootstrapping the label and the issue is part of activation, not a manual prerequisite.
- **The issue is append-only and permanent.** It is closed only when the loop is retired. Its comment history *is* the time series that the morning review reads to compute cost-per-accepted-change.
- **CI additionally mirrors the table to `$GITHUB_STEP_SUMMARY`** — free, and it puts the numbers where someone clicking a red run already is. The issue remains the durable copy.

## Consequences

**Enables:**
- One surface to subscribe to. Watching the issue is the whole notification story for the loop, on every launch path.
- The acceptance metric becomes computable: the log gives `shipped` per run, `gh pr list --state merged` gives accepted, and the ratio is a number instead of a feeling.
- A hard abort still reports. Because the mechanical half is produced by the launcher and not the agent, a run killed by the turn or budget cap still lands a row — the case where a narrative is impossible is exactly the case where the counters matter.

**Costs / accepted trade-offs:**
- The issue grows without bound. Accepted: comments are cheap, and a loop that ran long enough for this to hurt has earned a rotation policy it doesn't have yet.
- Lessons are best-effort by construction — the narrative half is missing whenever the process died where it stood. The counters are not best-effort; that asymmetry is deliberate and documented at the Stop/Exit Report.
- A repo that never bootstraps the label gets a log issue created by the first run, which will look like the loop filed a stray issue. The activation checklist covers it.

## References

- Implementation: `plugins/samuel/skills/workflow/conductor/assets/conductor.yml` (the `Post the run report` step), `plugins/samuel/skills/workflow/conductor/SKILL.md` § Stop / Exit Report, `plugins/samuel/skills/workflow/conductor/references/autonomous-run.md` § 4b.
- Caps, outcome taxonomy and the morning-review recipe: `plugins/samuel/reference/automated-trigger.md` § Caps & run accounting.
- Decided while implementing #25; constrains #29 (the loop's reporting/metrics follow-up).
