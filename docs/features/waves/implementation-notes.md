# Implementation Notes: waves

> **Item**: #46  ·  **Plan**: Issue body plan section  ·  **Constitution**: none
> **Counters**: D:0 V:3 T:0 Q:0 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

Sealed by `/samuel:validate` on 2026-07-28 (PASS). Schema: `plugins/samuel/reference/implementation-notes.md`.

## Design Decisions

_None yet._

## Deviations

### V-001 · addBlockedBy re-add is not a silent no-op
- **Phase**: setup
- **Step**: 1
- **When**: 2026-07-28
- **Files**: `plugins/samuel/reference/github-operations.md` (§ Issue dependencies — Declare an edge)
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: document the write as idempotent — "re-adding an existing edge is a no-op"
- **Did**: live verification showed re-add fails with `Validation failed: Target issue has already been taken` (non-zero exit) while creating no duplicate; documented the real contract + a read-then-add rule mirroring § Blast radius list-first idempotence
- **Why**: the section exists to be copy-runnable by cold agents; documenting the asserted (wrong) behavior would make every wave-coordinator loop die on the first existing edge

### V-002 · REST does expose issue dependencies
- **Phase**: validate (independent-review fix)
- **Step**: 1
- **When**: 2026-07-28
- **Files**: `plugins/samuel/reference/github-operations.md` (§ Issue dependencies)
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: dependencies are "GraphQL-only — REST does not expose them, the same gap as parent lookup"
- **Did**: reviewer verified `GET /repos/{owner}/{repo}/issues/{n}/dependencies/blocked_by|blocking` live (re-verified cold: 46 → 29, 30); rewrote the opener — REST is the single-issue read path, GraphQL stays for the batched query and the mutations — and added the case caution (REST `state` lowercase, GraphQL uppercase)
- **Why**: a shared adapter asserting a false constraint forecloses the simplest read path for every future consumer

### V-003 · Orca `name:` selector matches displayName, not the GitHub repo name
- **Phase**: validate (independent-review fix)
- **Step**: 2
- **When**: 2026-07-28
- **Files**: `plugins/samuel/skills/workflow/waves/references/wave-protocol.md` (P0, P3), `plugins/samuel/skills/workflow/waves/SKILL.md` (Gotchas)
- **Status**: applied
- **Linked decision**: none
- **Affects**: none
- **Plan said**: P0/P3 select the Orca repo with `--repo name:{REPO}` where `{REPO}` is the GitHub repo name
- **Did**: reviewer verified live that `name:agent-skills` returns `repo_not_found` (the registered displayName is `personal-agent-skills`) — and with exit code 0, so exit-status checks don't trip; P0 now resolves `{ORCA_REPO_ID}` by absolute path via `orca repo list`, every later selector uses `id:`, and the exit-code trap is a seeded gotcha
- **Why**: the recipe failed as written against the dogfood repo itself (AC2 cold-agent litmus), and `name:` ambiguity across two checkouts of the same GitHub repo can dispatch workers into the wrong checkout

## Tradeoffs

_None yet._

## Open Questions

_None yet._
