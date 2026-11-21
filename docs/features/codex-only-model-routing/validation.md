# Validation report for #103

**Date** 2026-11-21
**Overall** PASS
**Gated SHA** `89e8fca9d76b51ce89652a5eb4001052d39bd057`

## Gate

- **PASS**. `bun run check:context && bun run check:autonomy && bun run check:plugins && bun run check:portability && git diff --check`. The plugin checks inspected the materialized manifests in strict mode. The separate marketplace check reported its expected linked-source warnings. The full branch diff also passed `git diff --check` against `92370bc`.
- **PASS**. In isolated copies, the manifest gate rejected an incorrect link target, an unknown manifest field and a linked manifest directory.
- **SKIP**. The repository has no configured `security_scan`.

Both focused evals ran on the gated SHA with one run per arm. With the plugin, routing and receipts each scored 1.00. Without it, routing scored 0.25 and receipts scored 0.75. The launch check used simulated receipts and recorded actual file-read order. These scores describe the focused cases only.

## Acceptance criteria

| Criterion | Evidence |
|---|---|
| Canonical profile | The role table includes all eight role groups, effort selection and the benchmark harness and API cost context. |
| Profile across Cascade and IAAS | The routing case selects the expected implementation, review, address and simplify routes. It covers review resume, the default profile and coordinator selection. |
| Independent review | The simulation requires the frozen SHA, fresh reviewers, executing primary, independently selected secondary cases, shared provider disclosure, coordinator verification and a halt when the primary cannot execute tests. |
| Route refusal and approval | The receipts case grades the sequence of tool calls as well as the release result. The routing case requires holding both the pending push and the review comment for owner approval. |
| Local calibration | The routing reference specifies matched inputs and acceptance checks plus effective route, elapsed time, usage, retries, rework, verified findings and misses. Local comparative model performance remains unmeasured. |

## Live Orca evidence

1. Started a wait-only worker in run `run_f7880b224c7f`. The full receipt identified dispatch `ctx_8171562ae500` and effective `gpt-6-luna/low`.
2. After checking the pair, sent marker instructions to that dispatch in `msg_e12a652a2311`.
3. Received `worker_done` message `msg_f93f88282e00` from that dispatch with outcome `succeeded` and marker `RECEIPT103_OK`. Released the worker.
4. An exact transcript message ID matched one local Codex rollout. Its effective sandbox was `danger-full-access` with approval policy `never`. That configuration fails the restricted IAAS execution barrier. The live exercise covered the mechanical worker's launch and delivery. The phase matrix and negative receipts were simulated.

## Independent review

The first review requested changes. The execution probe, coordinator evidence, Codex permission barrier, Simplify instructions and approval scenario were revised. The first follow-up approved with a worker-thread lookup finding. The next review verified the dispatch-to-rollout join and the escalation policy field.

> Verdict: APPROVE. Both notes from 1ad2580 are fixed, and the delta adds no Blocker or Important. Counts: 0 Blocker, 0 Important, 1 Nit.

The reviewer inspected `ce60cb8`. Its remaining Nit concerned an empty transcript. The follow-up bounds that wait by the 30-second startup check and withholds the brief when the deadline expires.

## Scope and journal

The author review kept the canonical table, dispatch verification, IAAS phase contracts and focused eval fixtures. Each serves a separate acceptance criterion. The manifest fix restores the pre-existing gate. Journal counts are D:0 V:1 T:0 Q:0 with no open questions. The proposed update to the root instructions' eval inventory is separate from the feature gate.
