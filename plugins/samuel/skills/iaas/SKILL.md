---
name: iaas
description: "Drive one item through Implement → [Audit → Address] × N → Simplify as chained headless phases, each with fresh context. The round ceiling comes from the plan's size chip or --rounds. Trigger on 'iaas', 'audit loop', 'run the audit rounds', 'implement audit address simplify'."
allowed-tools: Bash(git branch *) Bash(git rev-parse *) Bash(git status *) Bash(git log *) Bash(git diff *) Bash(gh *) Bash(awk *) Bash(test *) Bash(date *) Bash(tail *) Bash(jq *) Read Write Edit Skill Monitor AskUserQuestion
---

# IAAS — Implement · Audit · Address · Simplify

Drive **one work item** through an implementation and a convergent review loop, as separate headless phases. The adversarial value comes from the separation: the auditor runs in a **fresh process** that never saw the implementer's reasoning, so it judges the diff rather than the story behind it.

> **Phase contracts + the launch recipe**: `references/phase-contracts.md`.
> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
> **Autonomy:** which gates auto-advance and what gets recorded instead of asked — `../../reference/autonomy.md`.

## Mode

```
/samuel:iaas 42               — derive the round ceiling from the item's size chip
/samuel:iaas 42 --rounds 3    — ceiling of 3 [Audit → Address] rounds
/samuel:iaas 42 --rounds 0    — Implement + Simplify, no audit loop
/samuel:iaas 42 --from audit  — the branch and draft PR already exist; start at the loop
/samuel:iaas 42 --ready       — let Simplify mark the PR ready for review (off by default)
```

## This skill never reimplements a phase

Each phase is an existing skill, launched as its own process. IAAS reads state, decides the next phase, launches it, and reads the result off GitHub — the same shape as `/samuel:conductor`.

| Phase | Skill it runs | Leaves behind |
|---|---|---|
| **I**mplement | `/samuel:implement` then `/samuel:done --draft` | commits, a **draft PR** |
| **A**udit | `/samuel:pr-self-audit` | ONE PR review carrying a `<!-- samuel:review-pass P={P} … -->` marker |
| **A**ddress | `/samuel:address-pr-comments` | fixes + ONE `## Resolution — pass {P}` comment |
| **S**implify | `/samuel:remove-slop` | a de-slop commit over the branch diff, or nothing |

**GitHub is the channel between phases, not the session.** A fresh `claude -p` has no memory of the previous one, so the pass markers on the PR are the only thing that makes round 2 a delta instead of a repeat. That machinery already exists on both sides (`pr-self-audit` § Passes · `address-pr-comments` § Pass boundary) — IAAS depends on it and adds none of its own.

## The round ceiling

`--rounds N` wins when given. Otherwise derive it from the item's **size chip** in the Brief TL;DR (`../../reference/plan-templates.md` § Sizing) — a value the human already approved at plan time, which is why it is the heuristic here instead of the agent's read of "how complex this feels":

| Size chip | Ceiling |
|---|---|
| **S** — 1-2 files, local, no design decision | 1 |
| **M** — 3-4 files or one design decision | 2 |
| **L** — past that | 3 |

No chip on the item → treat as **M** and say so in the CONFIRM block. A ceiling is a maximum, never a target: rounds stop the moment the loop converges, because every extra audit is a full model run against real money.

**CONFIRM the item, the ceiling and its source before launching anything.** **WAIT.** (Autonomous: proceed on the derived ceiling and record it. attended-auto: announce the ceiling and its source in one line.)

## When the loop stops

Any one of these ends it. Report which one fired — "done" and "gave up" must never look the same.

1. **Converged** — the audit verdict carries no Blocker and no Important. Nits alone do not buy another round; the rubric already calls them informational (`../../reference/review-rubric.md` § Severity).
2. **Ceiling reached** — stop and report every finding still open. Do not quietly continue.
3. **Not converging** — round `N` raises findings at the same `file:line` the previous round claimed to have fixed. Another round costs the same money to produce the same argument, so stop and escalate with both rounds' findings side by side.
4. **Empty audit** — a phase that returns nothing is a **broken channel, not a clean verdict**. Re-launch it once; still empty → STOP and report. Never count it as converged. (`git diff {base}...HEAD` is also empty on a branch with no commits, which reads identically — check the branch has commits before believing an empty audit.)

## Authority ceiling

**Draft PR is where this skill stops.** `gh pr ready` runs only under `--ready`, and **merge is never automated at any level** — `/samuel:done`'s outward-action rules and ADR 0004 bind here unchanged. Every phase that pushes runs the repo gate first, and `gate:signoff` when `.claude/samuel.md` declares `signoff`; a phase never signs a SHA its gate did not run against.

## Run accounting

Capture cost, turns and tokens per phase (`--output-format stream-json`, read the `result` line), and post ONE run report to the rolling **`conductor:log`** issue — the same timeline the conductor and waves already write to (ADR 0003, format in `../../reference/automated-trigger.md` § The run report). Add a `rounds` column: the ceiling, how many actually ran, and which stop rule fired. Cost per accepted change is the number this makes visible; a wave of this shape has run $27-53.

## Gotchas

_Add a line each time Claude trips on something._

- **The audit must not share context with the implementer.** Launch it as its own process, never as a continuation — an auditor that watched the code being written reviews the reasoning, not the diff. Same doctrine as `/samuel:validate` Step 2.5, at process scale instead of subagent scale.
- **An empty phase return is indistinguishable from a clean one.** Rule 4 exists because both print nothing; the branch's commit count is what separates them.
- **A ceiling is not a target.** `--rounds 3` on a clean implementation should still stop after round 1.
- **The size chip is read, never re-judged.** If the item has no chip, say so at CONFIRM rather than inventing a complexity estimate — a heuristic built on the agent's self-assessment is decorative (`../../reference/pipeline.md` § The unknowns seam).
- Phase prompts go in via **stdin**, not as an argument — a multi-paragraph contract on the command line hits the shell's own limits and quoting rules.
- Chain phases so a failure stops the chain. A phase that runs on top of a failed predecessor audits a tree nobody built.
