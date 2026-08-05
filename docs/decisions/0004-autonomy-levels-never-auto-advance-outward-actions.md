# 4. Autonomy levels never auto-advance an outward action

Date: 2026-07-28
Status: Accepted

## Context

The pipeline gained a third autonomy level in #27 — `attended-auto`, between `interactive` (asks and waits) and `autonomous` (`/samuel:conductor`, records and proceeds). Its purpose is measured: a 3-day sample found 93 prompts, 11.4% of all input, were bare acks answering checkpoints whose answer was never in doubt.

That purpose creates a pressure the earlier two levels never had. `interactive` asks about everything, and `autonomous` is fenced by a SAFETY GATE (isolated worktree or CI runner, never a local `main`) plus a draft-only PR ceiling. `attended-auto` has neither: a human is present but not gating, so every checkpoint looks like a candidate for removal, and the level's success metric is how many it removes.

The pressure produced the failure inside a single validation cycle. `/samuel:validate`'s AC1 said the cycle completes "sin un solo ack tecleado". The last checkpoint standing was `done` § Step 2's DoD gate — and `done` § Step 3 has no checkpoint of its own; it runs `git push -u origin` and `gh pr create` directly. Wiring the DoD gate satisfied the criterion literally and let an `attended-auto` run open a non-draft PR into `main` with no human confirmation. Five artifacts in the same diff asserted the opposite, including the skill's own header and the hard-stop list. The repo it shipped in already had the key switched on.

The gate did not catch it. Neither did the criterion — the criterion is what demanded it.

## Decision

**No autonomy level may auto-advance an outward action.** An outward action is anything that leaves the local working tree or the current Issue: `git push`, opening / merging / marking ready a PR, publishing `pr-self-audit` comments, cross-posting to another Issue.

Three consequences:

1. **A checkpoint that guards an outward action is a hard stop at every level**, listed as a `**waits**` row in `reference/autonomy.md` § Which gates move rather than omitted. An exclusion that is merely absent reads as an oversight; one that is documented states its reason.
2. **`attended-auto` grants no push authority.** `done`'s CRITICAL RULE 4 admits `interactive` (user-approved) and `autonomous` (a run explicitly launched with that goal), and nothing else.
3. **When an Acceptance Criterion and this rule conflict, the criterion is what was written wrong.** An AC is amended to concede the gate; the gate is not removed to satisfy the AC. AC1 was amended twice for exactly this — it had been written assuming every checkpoint in the cycle was soft, and two are not.

A `**waits**` row must correspond to a real, marked stop in the skill — a `**WAIT**`, a `HARD STOP`, or a "forced checkpoint". A row asserting a guard that does not exist is worse than a missing row: it reads as a green tick to anyone auditing whether outward actions are gated.

## Consequences

A full `implement` → `done` cycle under `attended-auto` still costs two typed acks: `done` § Step 2 (DoD, the last stop before the push) and `done` § Step 4 (durable knowledge, never auto-edited). That is the ceiling on what this level can deliver, and it is deliberate — a level built to remove acks that removes the one in front of publishing has inverted the guarantee it was meant to preserve.

The rule is prospective. Any future level, or any new gate added to an existing one, inherits it without renegotiation — including the RFC that carries `attended-auto` to the team's `flow` plugin, where the blast radius is a shared repo rather than one person's.

Enforcement is partly mechanical and partly not. `scripts/lint-autonomy.sh` G6 cross-checks that the `**waits**` rows and the wired `(attended-auto:` clauses agree in both directions, so flipping a row to "moving" without a clause — or adding a clause without a row — fails the gate. What no check can assert is whether a gate *should* be outward; that judgement stays with the human, which is why the DoD reversal was escalated rather than decided by the agent that caused it.

Related: ADR 0001 (independent adversarial reviewer). Three review rounds each returned a Blocker on this change, and the one recorded here was introduced by the previous round's fix. The reviewer found what the gate could not — the gate checked the shape of the change, not its truth.
