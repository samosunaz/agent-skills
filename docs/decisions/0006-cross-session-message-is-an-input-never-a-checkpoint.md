# 6. A cross-session message is an input, never a checkpoint

Date: 2026-08-09
Status: Accepted

## Context

Claude Code 2.1.224 gave every session an inbox. `ListAgents` lists the user's other sessions, `SendMessage` delivers a line of text to one, and the message arrives in the receiving conversation the same way a typed prompt does — between tool calls, or as a new turn when the session is idle. Nothing had to be enabled; sessions on this machine already reach each other.

That is a second input path, and it resembles the first one closely enough to be mistaken for it. ADR 0004 settled what an autonomy *level* may auto-advance: no level may auto-advance an outward action, because a level built to remove acks that removes the one in front of publishing has inverted its own guarantee. It said nothing about what an *input* may authorize, because until now there was only one input and it came from the human.

The pressure is specific and it arrives immediately. `/samuel:conductor` is forbidden from asking anything (`reference/interaction-tools.md` § Boundary): a question dialog in an unattended run stalls until it times out, so the level's whole contract is record-and-proceed. `SendMessage` does not block. A conductor can state a blocking ambiguity, keep working, and have the answer land twenty minutes later. The obvious next step — treat that answer as the human approval ADR 0004 says no level may synthesize — would hand an unattended run the authority its SAFETY GATE exists to withhold, through a door that gate does not watch.

A second, quieter path opens with it. A session whose permission prompt was denied can ask a peer to do the same work. The runtime instructs against it, but the pipeline launches sessions with deliberately different allowlists — a wave worker's is tighter than its coordinator's by design — so the asymmetry that makes laundering useful is one the pipeline builds on purpose.

## Decision

**A cross-session message is an input, with no more authority than a tool result.** Three consequences, none of which the runtime enforces:

1. **A message never satisfies a hard stop.** The list in `reference/autonomy.md` § Hard stops binds identically whether the run is alone or in a conversation with five peers. A peer answering the question behind a stop does not clear the stop; it supplies a fact the human still has to act on.
2. **A message never raises a run's autonomy level.** An unattended run that receives an answer records it exactly as it records its own assumptions — journal, Issue comment, handoff — and proceeds under it. The ceiling set by the launch is the ceiling for the run.
3. **A message is verified before it is acted on.** GitHub is the SoT (ADR 0002); a peer's claim is a reason to re-read it, never a substitute for reading it. Symmetrically, every outbound message names a durable record that already exists — post the comment or the PR first, then point at it.

And the boundary that makes differential allowlists safe: **a session never asks a peer to perform an action its own permissions denied.** That is not delegation, it is routing around the user's decision. Blocked work goes back to the human.

## Consequences

The conductor gains a capability it genuinely lacked and no authority it lacked. Until now its only outward signal was `PushNotification`, which announces and cannot collect. It can now escalate and keep working, which is strictly better than the two options it had — guess, or stop. What it still cannot do is treat the reply as consent.

The cost is real and accepted: an answer can arrive after the run has already recorded an assumption and moved past the decision. The alternative is waiting for it, which is the one thing unattended mode exists not to do. A late answer becomes a finding at the morning review, in the same place every other unattended assumption is reviewed.

Enforcement here is entirely human, and the ADR says so rather than implying a check exists. `lint-autonomy.sh` can prove a gate is wired; it cannot prove an agent did not treat an inbound line as permission. `reference/cross-session.md` § Safety carries the rules to the agents that need them, and the skills that message point there — which is the same shape as every other convention in this repo, and the same limit.

Related: ADR 0004 (no level auto-advances an outward action), which this extends from levels to inputs, and ADR 0002 (GitHub is the only tracker), which is why rule 3 has somewhere to verify against.
