# 0002. Single tracker — GitHub only; backlog demoted to local disector

- **Status**: accepted
- **Date**: 2026-07-12

## Context

samuel v2 made GitHub the default source of truth but kept Backlog.md as a second, interchangeable backend (`tracker: backlog`) — an "offline/solo fallback SoT". The upstream registry this pipeline is derived from retired its own dual-tracker in jul 2026 and explicitly carved out this personal blueprint as the place where the dual-tracker "remains valid". Revisiting that carve-out with real usage:

1. **The offline fallback buys nothing.** Both consumer repos (a web app + its mobile client) close every item through GitHub — the PR, the CI gate, the conductor heartbeat, the `Closes #N`. A tracker that cannot close an item is a detour that must be re-transcribed into GitHub anyway.
2. **The dual-tracker was never exercised.** No `backlog/` directory exists in any active consumer repo; the abstraction (selector, adapter contract, per-skill storage forks) has been pure carrying cost.
3. **Mirror friction.** Every port from upstream (which is single-tracker) had to be re-translated into dual-tracker language — the abstraction taxed exactly the workflow (mirroring upstream improvements) this repo exists for.
4. **Tracker ≠ disector.** The genuinely useful thing Backlog.md does for an agent — decomposing an Executor Plan into checkable local subtasks with dependency ordering — never needed it to be a *tracker*.

## Decision

**GitHub Issues + PRs are the only source of truth for the samuel pipeline.** The `tracker:` selector as an SoT switch is retired; the backlog storage forks are deleted (amputated, not relocated) from the pipeline skills.

- **Backlog.md is recast as the optional local disector**: the agent's private, implement-time scratchpad to decompose an Issue's Executor Plan into checkable subtasks. Created at will, thrown away at close, **read back by nobody** — not validate, not done, not a resuming session. Litmus test: derivable and disposable. Recipes: `plugins/samuel/reference/backlog-operations.md`.
- **`tracker:` survives only as a legacy detection key** in `.claude/samuel.md` / `.claude/task-context.md`: `github` (or a fresh file) means migrated; anything else marks a pre-migration context — skills stop and point at the migration path (`reference/tracker.md` § Legacy contexts). There is no legacy pipeline plugin here; the path is always "re-capture open work as Issues".
- **The universal layer is untouched** — the Brief + Executor Plan format, the committed journal (`implementation-notes.md`), committed `validation.md`, and ADRs. That layer, not a second backend, is the real portability insurance.

## Consequences

**Enables:**
- Pipeline hubs shrink; new pipeline features are specified once.
- Ports from upstream become near copy-paste (namespace rename), since both sides now share the single-tracker shape.
- The disector becomes honest: optional, local, in agent language, with zero durability expectations.

**Costs / accepted trade-offs:**
- No offline tracker mode. Offline work continues on the branch; item state syncs when back online.
- `tracker: backlog` contexts created before this ADR stop being executable — the legacy pointer is the migration path.

## References

- Upstream precedent: the source registry's own single-tracker ADR (jul 2026), which this decision mirrors and whose personal-blueprint carve-out it closes.
- Hub + storage map: `plugins/samuel/reference/tracker.md`. Disector recipes: `plugins/samuel/reference/backlog-operations.md`.
