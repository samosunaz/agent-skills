---
name: wave-prep
description: "Prepare the open backlog for a wave run: sweep pipeline issues, infer real inter-issue dependencies from their Executor Plans, declare the missing native blockedBy edges (human-approved), and hand the ready set to /samuel:waves. Trigger on 'wave prep', 'preparar ondas', 'preparar backlog para waves', 'aristas del backlog', 'qué issues se pueden paralelizar'."
allowed-tools: Bash(gh *) Bash(jq *) Bash(awk *) Bash(grep *) Bash(date *) Read Skill AskUserQuestion
---

# Wave Prep (Backlog → Wave Set)

Prepares a set of existing issues for `/samuel:waves`: reads the open backlog, infers the dependencies their plans actually imply, declares the missing native `blockedBy` edges after human approval, and routes the outcome — the ready set to waves, the unplanned remainder to `/samuel:plan`.

Edges are born with the issue (`/samuel:plan` Phase 4, `/samuel:roadmap` multi-item promotion). This skill is the **retro sweep** for everything those paths never touched: issues created by hand, planned before edges existed, or whose graph is incomplete. Without it, a wave run over old backlog collapses into one giant wave.

All `gh` recipes live in `../../../reference/github-operations.md` § Issue dependencies — reuse them, never restate them here.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

**Boundary.** `/samuel:plan` and `/samuel:roadmap` declare edges at issue birth; `/samuel:waves` reads the graph and executes it, never mutates it. Wave-prep sits between: it only writes the graph. It never plans on the fly, never promotes labels (`pipeline:triage → ready` stays plan + preflight work), and never dispatches workers — routing to waves means invoking the skill, not reimplementing its intake.

## Mode

```
/samuel:wave-prep                     — all open pipeline:* issues
/samuel:wave-prep label:epic-checkout — scope to a label
/samuel:wave-prep milestone:"v2"      — scope to a milestone
/samuel:wave-prep 12 14 15 18         — explicit issue set
/samuel:wave-prep … --dry-run         — report everything, write nothing
```

## Context

- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Date: !`date +%Y-%m-%d`

## Authority ceiling

Launching this skill grants exactly one write: `blockedBy` edges the human approved at the EDGE PLAN checkpoint. Never labels, never issue comments, never closing, merging, or dispatching. `--dry-run` revokes even that.

## Process

1. **SWEEP** — resolve the scope to candidate issues (`NO_REPO` → stop; run `gh repo set-default` with the stored repo first). Batch-fetch number, title, labels, body, and current `blockedBy` for the whole set in one call (adapter § Issue dependencies, batched read). Never fetch per-issue in a loop.
2. **CLASSIFY** — three buckets, each reported with reasons, never silently dropped:
   - **wave-ready** — `pipeline:ready` with a filled Executor Plan (`<!-- samuel:plan -->` section has real Steps).
   - **plan-missing** — `pipeline:triage`/`pipeline:planned` or an empty plan section: parallelizable *later*, routed to `/samuel:plan` at Step 6.
   - **excluded** — `pipeline:in-progress`/`in-review`/`blocked`, or outside the scope filter.
3. **INFER** — for the wave-ready set, derive candidate edges from three signals, ranked; every proposed edge carries one line of evidence:
   1. **Explicit references** — `Depends on: #N` in the Brief, blocker language in the plan.
   2. **Artifact sequencing** — issue B's Steps edit files or sections that issue A's Steps *create*: B is blocked by A.
   3. **File overlap** — two plans touching the same existing files is a **soft conflict**, not a dependency. Report it so the human can weigh serialization; never emit an edge from overlap alone.
   Only edges absent from the live graph survive (the sweep already fetched current blockers).
4. **EDGE PLAN — checkpoint.** Present: proposed new edges (`B blocked by A — evidence`), the cycle check on the union graph (existing + proposed — a cycle is a hard stop: drop or invert an edge before proceeding), the resulting wave partition preview, soft conflicts, and the plan-missing/excluded routing list. **WAIT for approval** — nothing is written before it. On `--dry-run`, this presentation is the deliverable; stop here.
5. **WRITE** — declare only the approved edges, read-then-add per the adapter's write contract. Re-verify with one batched read; report written vs skipped-as-existing.
6. **ROUTE** — same turn, context alive: offer dispatching `/samuel:waves <ready set>` now (answering "ahora" invokes the skill); list plan-missing issues as `/samuel:plan N` one-liners. If nothing is wave-ready, say so plainly — an empty set is a finding, not a failure.

## Gotchas

_Add a line each time Claude trips on something._

- File overlap is not a dependency — declaring edges from co-location serializes work that could run in parallel and pollutes the graph waves trusts. Soft conflicts are for the human's eyes.
- GitHub does not reject dependency cycles — a cycle written here deadlocks waves' dispatch (no issue ever unblocks). Check the union graph at EDGE PLAN, before any write.
- `addBlockedBy` on an existing edge fails loudly without duplicating — read-then-add, never blind-add in a loop (adapter § Issue dependencies).
