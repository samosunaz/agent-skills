# Plan Templates — Brief + Executor Plan

A samuel work item carries **one artifact with two sections**: a human **Brief** and a self-contained **Executor Plan**. Both sections live in the Issue body; see `reference/tracker.md` for where it lands.

Three reading speeds, one artifact:

- **TL;DR** — ten seconds. The triage decision: engage now, or not. Four lines, Spanish, at the very top. Spec: `reference/github-operations.md` § TL;DR.
- **Brief** — a human prioritizing or reviewing. One screen. WHAT/WHY, never HOW.
- **Executor Plan** — an autonomous agent with **zero prior context** (a cold cloud/droplet session). It must execute correctly from this text + repo access alone. HOW, in full.

Each layer is written for a reader the next one down would starve. The plan is unreadable at triage speed; the TL;DR is unexecutable. Neither substitutes for the other.

## Section 1 — TL;DR + Brief (human)

```markdown
<!-- samuel:brief -->
> **Qué:** {el cambio observable — una frase, empieza por el verbo}
> **Por qué:** {el dolor que quita, o la apuesta que abre}
> **Ojo:** {lo único que puede morder — breaking change, decisión pendiente, riesgo. "Nada" es válido}
> `{S|M|L}` · `riesgo {bajo|medio|alto}` · `~{estimado en unidades concretas}`

## Brief

**Scope:** {what's in — 1–2 lines}
**Out of scope:** {what's explicitly excluded, to prevent scope creep}

### Acceptance Criteria
- [ ] AC1: {measurable, verifiable outcome — not a task}
- [ ] AC2: {measurable outcome}

**Type:** {feat|fix|refactor|perf|chore|docs|test}  ·  **Priority:** {high|medium|low}
**Depends on:** {#issue / task-id, or "none"}
```

The TL;DR absorbed the old `**Goal:**` line — same job, done in a shape that can be scanned instead of read. Don't reintroduce `Goal:` alongside it; two statements of the same outcome drift apart and the reader stops trusting either.

Acceptance Criteria are **outcomes** ("payment session expires after 10 min of inactivity"), not steps ("add a timer"). They become the PR's test plan and gate `/samuel:validate`. When an AC hides a stateful flow, its scenario decomposition (Given/When/Then) belongs in the Executor Plan's Validation → Manual, not here — the Brief stays one screen.

## Section 2 — Executor Plan (agent)

```markdown
<!-- samuel:plan -->
## Executor Plan
> Self-contained. Assumes zero prior context. Written for an autonomous executor.

### Context
{What this is and where it lives in the codebase. Restate enough that an agent
who never saw the chat understands the problem. No unresolved external references.}

### Relevant code
- `path/to/file.ts:42` — {what it does today, why it's relevant}
- `path/to/other.ts:88` — {current behavior the change touches}
{Evidence from research — concrete file:line, not "somewhere in the auth module".}

### Approach
{The chosen design, stated decisively. If alternatives were weighed, name the
choice and the one-line reason — the executor does not re-litigate it.}

### Steps
1. **{imperative title}** — `path/to/file.ts` — {exact change}.
   Verify: {command or observable result}.
2. **{title}** — `path/to/new.ts` (new) — {what to create, key shape}.
   Verify: {check}.
3. ...
{Ordered, concrete, small. Each step names files, the change, and a verification.
If a step depends on a prior one, say so. No "figure out X" — the plan decides.}

### Guardrails
{Repo conventions embedded so the executor needs no outside knowledge. e.g.:}
- kebab-case filenames; comments & docs in English.
- No tests unless a step explicitly adds one.
- Prefer platform-native primitives ({e.g. Cloudflare Workers/D1/DO}) over deps.
- Do not commit/push/PR outside the run's authority (the harness handles that).

### Validation
- **Automated (gate):** `{exact command, e.g. bun run gate}` — must pass before done.
- **Manual:** {steps a human/agent runs to confirm the AC behaviorally. For stateful or
  multi-step flows, write them as Given/When/Then scenarios — the executor runs a script
  instead of interpreting prose, and each scenario maps 1:1 to the e2e journey below}.
- **e2e tier:** {green|yellow|manual-only} — {one-line rationale; name the seam if yellow}.
  Required when the target repo has an e2e app (e.g. `apps/*-e2e`); omit this line otherwise.
  **Green** — full deterministic UI journey, no non-deterministic external in the path.
  **Yellow** — starts from seeded state past a non-deterministic external via a deterministic
  seam (a landed seam promotes yellow → green). **Manual-only** — a real third-party handoff
  (OAuth login, hosted checkout) that stays manual forever; only its logic is seam-tested.
  The full model lives in the target repo's e2e standard doc — don't duplicate it here.

### Definition of Done
- [ ] All Steps complete
- [ ] `{gate command}` green
- [ ] Every Brief AC met
- [ ] {feature-specific DoD}
- [ ] e2e journey authored/updated for the declared tier (repos with an e2e app)
```

### Quality bar — what makes a plan "self-contained"

A plan is ready for unattended pickup only if **all** hold. This is the improve-style discipline: write for a weak executor.

- **No dangling references.** Every "the X module", "the existing helper", "as discussed" is replaced by a concrete `path:line`. An agent can't resolve chat history or your memory.
- **Decisions are made, not deferred.** No open questions in the plan. If something is genuinely undecided, it belongs in the Brief as a blocker (`pipeline:blocked`), not in the plan.
- **Steps are independently checkable.** Each has a verification an agent can run. "Refactor the service" is not a step; "extract `parsePayload` from `handler.ts:40-72` into `parse.ts`, keep the signature; verify `bun run typecheck`" is.
- **The gate command is exact and present.** The executor must know precisely how to prove it's done.
- **Guardrails are embedded.** Repo conventions live in the plan, not in the executor's assumed knowledge.

> Litmus test: hand the Executor Plan to a fresh agent with only repo access and no chat. If it can finish without asking a question, the plan is good. If it would stall, the plan is incomplete — fix it before marking the item `ready`.

## Storage

Both sections are the **Issue body**, delimited by the `<!-- samuel:brief -->` / `<!-- samuel:plan -->` markers. `/samuel:plan` fills the plan section and flips `pipeline:triage` → `pipeline:planned`. Steps stay **inline** (no sub-issues). See `reference/github-operations.md`.

## Sizing

If a single work item needs >~200 lines of change or touches 4+ files, split it into multiple items/issues. A plan an agent can't hold in one focused pass is too big for unattended pickup.

The TL;DR's size chip is the cheap early warning: **S** = 1–2 files, local, no design decision · **M** = 3–4 files or one design decision · **L** = past that, so re-read this section before planning it. An `L` isn't forbidden, it's a prompt to check whether it's really one item.
