# Implementation Notes: attended-auto

> **Item**: #27  ·  **Plan**: Issue body `<!-- samuel:plan -->`  ·  **Constitution**: none
> **Counters**: D:6 V:4 T:1 Q:0 (open_remaining: 0)
> **Status**: sealed
> **Flags**: has-deviations

Journal kept during `/samuel:implement`, sealed by `/samuel:validate` (2026-07-27, `PASS WITH NOTES`). Schema: `plugins/samuel/reference/implementation-notes.md`.

## Design Decisions

### D-001 · `autonomous` is not a value the file may set
- **Phase**: foundational
- **Step**: 1
- **When**: 2026-07-27
- **Files**: `plugins/samuel/reference/autonomy.md` § Resolution, the read line in all five wired skills, `scripts/lint-autonomy.sh` (G4e-G4h)
- **Status**: applied (superseded the prose-only form — see the correction below)
- **Affects**: none — checked #29 (conductor TTL/auto-report) and #30 (Orca adoption); both adjacent, neither constrained by how the level is granted
- **Context**: the plan said to document "the three accepted values" without naming which are settable. Left as written, `autonomy: autonomous` in `samuel.md` would parse as valid.
- **Decision**: accept only `interactive` and `attended-auto` from the file; read anything else as `interactive`. `autonomous` is reachable only through `/samuel:conductor`.
- **Why**: the conductor earns that level by passing a SAFETY GATE (isolated worktree or CI runner, never a local `main`). A file that granted it would give any ordinary session the conductor's authority with none of its guard — and silently, since nothing else in the run would look different.
- **Correction (validate, same day)**: this entry was first marked `applied` while the rule existed **only as a sentence in `autonomy.md`** — the `awk` printed whatever the file said, so `autonomy: autonomous` resolved verbatim and landed next to parentheticals keyed on that word. Caught by the independent reviewer at `/samuel:validate` Step 2.5. The read is now a two-rule `awk` that matches the literal `attended-auto` and prints `interactive` for everything else, with G4e-G4h covering `autonomous`, a typo, an empty value, and the case where a rejected repo value must not fall through to a permissive global file. A decision is not `applied` until something other than prose enforces it.

### D-002 · `spec_required` counted as the eighth gate
- **Phase**: foundational
- **Step**: 1
- **When**: 2026-07-27
- **Files**: `plugins/samuel/reference/autonomy.md:48`
- **Status**: applied
- **Affects**: none
- **Context**: the Issue's original proposal enumerated seven checkpoints; `start-task`'s `spec_required` question was not among them, though it has the same shape (a known default, an obvious answer).
- **Decision**: include it, and correct the Brief + TL;DR from "siete" to "ocho" naming the addition explicitly rather than letting the count drift.
- **Why**: the plan's own Step 4 already covered it, so the artifact contradicted itself. A Brief that miscounts its own scope is the kind of small wrongness a cold executor propagates.

### D-003 · a gate default is not a journal entry
- **Phase**: gate
- **Step**: validation follow-up
- **When**: 2026-07-27
- **Files**: `plugins/samuel/reference/autonomy.md` § Recording contract, `plugins/samuel/skills/pipeline/implement/SKILL.md` § Step 1
- **Status**: applied
- **Affects**: none — the rule is internal to how this level records; no sibling issue reads it
- **Context**: the recording contract promised a `D-NNN` "when a journal is open", while `implement`'s Step 1 clause said "no journal entry". Step 0 opens the journal before Step 1 runs, so a journal is always open there — the two rules could not both hold, and AC1 sided with the contract. Found by the independent reviewer, not by the gate.
- **Decision**: narrow the contract — a `D-NNN` only when the default **resolved an ambiguity**, never for merely continuing. Eleven of the twelve gates therefore write nothing (four resolve before a journal exists at all); the single exception is `done` § Step 1, where the default picks which issue the PR closes. AC1 amended to match. (Counts as of this entry — `D-004` later added a ninth wired gate and a thirteenth table row; the rule is unchanged.)
- **Why**: taking the obvious default at a gate is not a decision — that is the premise the level rests on. The opposite resolution (journal every gate) would have been mechanically consistent and practically useless: a `D-NNN` per phase boundary buries the entries that record real choices under a log of the system working as designed. The narrow rule is also the one that survives the four gates that fire before `implement` Step 0.

### D-004 · the DoD checkpoint is the ninth wired gate
- **Phase**: gate
- **Step**: validation follow-up (round 2)
- **When**: 2026-07-27
- **Files**: `plugins/samuel/skills/workflow/done/SKILL.md` § Step 2, `plugins/samuel/reference/autonomy.md` § Which gates move
- **Status**: superseded by D-006 — reverted the same day
- **Affects**: none
- **Context**: the second independent review showed AC1 was unmet regardless of the journal fix — `done` § Step 2's DoD checkpoint carried an `(Autonomous: …)` clause with no `attended-auto` counterpart, so a full `implement` → `done` cycle still required a typed ack at the gate immediately before the PR push. The gate table listed neither it nor `done` § Step 4 in **any** column, so the one blocker on the flagship cycle was invisible in the index built to catalogue exactly that.
- **Decision**: wire it as the ninth gate, conditioned on every DoD box being checked, and add `done` § Step 4 (durable knowledge) to the table as an explicit `**waits**` row. The plan's scope of eight gates grows to nine.
- **Why**: the alternative was amending AC1 a second time to excuse the gate, and an AC amended twice to fit the implementation has stopped being a criterion. The condition costs nothing: an unchecked DoD box is already on the hard-stop list, so the clause auto-advances exactly the case that was never in doubt. `done` § Step 4 stays waiting at every level because `CLAUDE.md` makes durable-knowledge edits a forced checkpoint, never auto-applied.

### D-005 · the gate verifies the shipped read line, not a copy of it
- **Phase**: gate
- **Step**: validation follow-up (round 2)
- **When**: 2026-07-27
- **Files**: `scripts/lint-autonomy.sh` (G2b, and the `probe()` extraction)
- **Status**: applied
- **Affects**: none
- **Context**: the reviewer mutation-tested the gate: reverting `implement/SKILL.md`'s read line to the whitelist-less form left `check:autonomy` green at exit 0 with all fifteen assertions passing — including `G4e PASS — autonomous is not settable from a file`. Reproduced before accepting. G4 was probing a hand-copied `awk` literal inside the script, so the level's only privilege guard had zero coverage of any of its six shipped copies.
- **Decision**: extract the read line from `autonomy.md` § Resolution, assert all five skills match it byte-for-byte (G2b), and build `probe()` from that extracted string by path substitution instead of retyping the program.
- **Why**: a check that re-implements what it verifies tests itself. Both attack paths now go red — stripping the whitelist from one skill trips G2b, and corrupting the documented line trips G2b five times *and* flips G4e to FAIL. This is the same lesson as `D-001`'s correction one round earlier, at one level of indirection: enforcing a rule in code is not the same as verifying the code that ships enforces it.

### D-006 · the DoD gate waits at every level — `attended-auto` grants no push authority
- **Phase**: gate
- **Step**: validation follow-up (round 3)
- **When**: 2026-07-27
- **Files**: `plugins/samuel/skills/workflow/done/SKILL.md` § Step 2 + CRITICAL RULE 4, `plugins/samuel/reference/autonomy.md` § Which gates move
- **Status**: applied — supersedes `D-004`
- **Affects**: none
- **Context**: `D-004` wired the DoD checkpoint to satisfy AC1 literally. The third review showed what that bought: `done` § Step 3 has **no checkpoint of its own** — it runs `git push -u origin` and `gh pr create` directly — so the DoD gate was the only confirmation in front of publishing, and auto-advancing it let an `attended-auto` run open a non-draft PR into `main` unattended. Five artifacts in the same diff said the opposite, including the skill's own header line and the hard-stop list. This repo already resolves `attended-auto`, so the next `/samuel:done` on this branch would have been the first case.
- **Decision**: revert. The gate keeps waiting at `attended-auto`, and the table carries it as a `**waits**` row rather than dropping it, so the exclusion is documented instead of merely absent. `done` § Step 4 (durable knowledge) likewise stays waiting. AC1 amended a second time: the cycle runs without acks *except* the outward-action gate. Escalated to the human as an outward-action call rather than decided here.
- **Why**: a level whose purpose is removing acks cannot buy its own acceptance criterion by removing the ack in front of `git push`. The AC was the thing that was wrong — it was written assuming every checkpoint in the cycle was soft, and two of them are not. Wiring the gate made the artifact self-consistent and the guarantee false, which is the more expensive of the two failures: `autonomy.md`'s own gotcha about rows that assert guards which do not exist had been added one round earlier, and applied here to the guard the fix removed.

## Deviations

### V-001 · the read chain strips inline comments
- **Phase**: foundational
- **Step**: 2
- **When**: 2026-07-27
- **Files**: `plugins/samuel/reference/autonomy.md:34`, `plugins/samuel/reference/tracker.md:12-17`
- **Status**: applied
- **Linked decision**: none — sub-threshold; the plan body was refined in place rather than escalated
- **Affects**: none
- **Plan said**: use the `awk` line from § Approach verbatim: `awk '/^autonomy:/{sub(/^[^:]*: */,"");print;f=1}' …`
- **Did**: added a second substitution, `sub(/[ \t]*#.*$/,"")`, to both links of the chain, and propagated it to the Issue's Executor Plan (§ Approach and the embedded gate script) so a cold pickup gets the corrected line.
- **Why**: the plan was written against the `task-context.md` read recipe, which has no inline comments to strip. The key moved to `samuel.md`, whose documented example annotates every field (`tracker.md:12-17`) and whose own read recipe therefore strips them (`tracker.md:30-31`). Without the strip, `autonomy: attended-auto  # nota` resolves to the value with the comment attached and matches nothing. Verified across four states: with comment, plain, absent, and global-only.

### V-002 · `next` no longer confirms a single candidate
- **Phase**: wiring
- **Step**: 4
- **When**: 2026-07-27
- **Files**: `plugins/samuel/skills/workflow/next/SKILL.md:58`
- **Status**: applied
- **Linked decision**: https://github.com/samosunaz/agent-skills/issues/27#issuecomment-5097180483 (R1)
- **Affects**: none
- **Plan said**: reverse the standing rule `If only one is available, still confirm.` under `attended-auto`.
- **Did**: reversed it, and kept the original sentence in place with the reversal appended, so the rule and its exception are read together rather than one replacing the other.
- **Why**: the rule was written deliberately — its purpose is that the skill never picks in silence. Announcing the pull serves that purpose; it is the silence, not the confirmation, that the rule was protecting against. Deleting the sentence would have erased the reasoning a future reader needs to evaluate the exception. The menu still renders for two or more candidates at every level, since there is no obvious default to take.

### V-003 · `start-task` does not force a worktree under attended-auto
- **Phase**: wiring
- **Step**: 4
- **When**: 2026-07-27
- **Files**: `plugins/samuel/skills/workflow/start-task/SKILL.md:80`
- **Status**: applied
- **Linked decision**: https://github.com/samosunaz/agent-skills/issues/27#issuecomment-5097180483 (R2)
- **Affects**: none
- **Plan said**: the Issue's original proposal asked for «`start-task` → default worktree sin menú».
- **Did**: pick the mode the context recommends — branch when the repo needs no dependency install and no session is live in a worktree, worktree otherwise — and announce it with the reason.
- **Why**: the fixed-worktree default was inherited from the conductor, which needs isolation because its SAFETY GATE demands it. `attended-auto` has no such requirement, and a worktree on an attended run forces the human to open a session in another path — the opposite of the friction this level removes. Confirmed against live behaviour: this very issue was started in branch mode by explicit choice, which is what the context would have recommended.

### V-004 · the dogfood key is repo-scoped, not global
- **Phase**: gate
- **Step**: 7 (DoD)
- **When**: 2026-07-27
- **Files**: `.claude/samuel.md` (gitignored — not in the diff)
- **Status**: applied
- **Linked decision**: none — the plan's own § Validation offered the repo file as the narrower option
- **Affects**: none
- **Plan said**: create `~/.claude/samuel.md` with `autonomy: attended-auto`, making the level global across every repo.
- **Did**: wrote the key into this repo's `.claude/samuel.md` instead. The global file still does not exist, so every other repo resolves `interactive`.
- **Why**: the Issue's own sequence is «dogfood here for 1 week → propose it upstream». Turning the level on globally would debut it across 5+ parallel sessions on day one, which is a wide blast radius for a behaviour nobody has watched yet. The resolution chain was built precisely so this choice is a one-line move later. Verified live: the chain resolves `attended-auto` in this repo.

## Tradeoffs

### T-001 · the reversed rules keep their original sentence
- **Phase**: wiring
- **Step**: 4
- **When**: 2026-07-27
- **Files**: `plugins/samuel/skills/workflow/next/SKILL.md:58`, `plugins/samuel/skills/workflow/start-task/SKILL.md:80`
- **Status**: applied
- **Chose**: append the `attended-auto` exception after the standing rule, leaving the rule's text intact.
- **Considered**: rewriting each rule to state the new conditional directly — shorter, reads cleaner, and matches how a rule would be written if it were new today. Rejected: it deletes the reasoning that justified the original rule, and both of these were written deliberately (`next`'s "still confirm" exists so the skill never picks in silence).
- **Why**: a future reader deciding whether the exception still holds needs the original intent to judge it against. A rule rewritten to accommodate its exception reads as though it never had another shape, and the next person to touch it has no way to recover what it was protecting.

## Open Questions

_None yet._
