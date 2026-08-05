# Autonomy Levels — when a checkpoint asks, announces, or records

A skill's checkpoint has three possible behaviours. Which one applies is a property of **the run**, not of the skill: the same `**WAIT.**` block asks a question, states an assumption, or writes a journal entry depending on the level in force.

| Level | Switched on by | At a soft checkpoint | Reviewed |
|---|---|---|---|
| `interactive` | the default — nothing set | **Asks** and waits for an answer | live, by answering |
| `attended-auto` | `autonomy: attended-auto` in `samuel.md` | **Announces** the default it took, then continues | live, by reading the announcement |
| `autonomous` | `/samuel:conductor` driving the run | **Records** the assumption and continues | afterwards, at the morning review |

The middle level exists because a large share of interactive acks answer questions whose answer was never in doubt. `attended-auto` keeps the human in the loop by *telling* rather than *asking* — the review still happens, one line later instead of one keystroke earlier.

## Resolution

0. **The run is unattended** — `/samuel:conductor`, any headless `claude -p` + `/goal` invocation, or `GITHUB_ACTIONS=true` — → `autonomous`, unconditionally. The file key is ignored for the duration of the run, in either direction: it cannot grant the level and it cannot take it away. Two failures this closes. A conductor run that read `attended-auto` would inherit that level's *waits* — the dirty-tree gate below is marked `**waits**`, while the conductor's own clause stashes and records — and an unattended run that waits stalls until it times out. A headless run that stayed on `attended-auto` would be worse than either level: it announces to a chat with no reader, and the recording contract below then has it write **no** journal entry and **no** Issue comment, so the assumptions leave no trace at all. `autonomous`'s "always journal" column exists for exactly that reader-less case.

Otherwise the key lives in `samuel.md`, resolved per-repo first, then globally, then defaulting off:

1. `.claude/samuel.md` in the repo — per-repo override
2. `~/.claude/samuel.md` — global default across every repo
3. absent from both → `interactive`

Skills read it in their `## Context` block with this line, which satisfies both rules in `scripts/lint-skill-context.sh` (no `$(`/`${`, terminates in an `echo` fallback):

```
- Autonomy: !`awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)exit 1}' .claude/samuel.md 2>/dev/null || awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)print"interactive"}' ~/.claude/samuel.md 2>/dev/null || echo "interactive"`
```

Accepted values are `interactive` and `attended-auto`. **`autonomous` is not settable from a file** — it belongs to `/samuel:conductor`, which earns it by passing a SAFETY GATE (isolated worktree or CI runner, never a local `main`). A file that could grant it would hand every ordinary session the conductor's authority with none of the conductor's guard.

The whitelist is enforced **in the read itself**, not in prose: the first pattern matches only the exact literal `attended-auto` (with optional surrounding whitespace and the inline `#` gloss `samuel.md`'s documented example puts on every field), and the second catches every other `autonomy:` line — `autonomous`, a typo, an empty value — and prints `interactive`. A rule stated only in a paragraph is a rule the injected value does not obey: the raw string lands in `## Context` directly above parentheticals that branch on the literal word `Autonomous`. The first `awk` exits non-zero only when the repo file has **no** key at all, which is what hands control to the global file; a key with a rejected value resolves to `interactive` there and does not fall through.

## Which gates move

Only checkpoints whose default is genuinely obvious. Everything else keeps waiting at every level.

Cited by **section**, never by line: this table's own arrival shifted every line in the files it points at, and a stale citation in the one index that says where the gates live is worse than no index.

| Skill | Gate | `attended-auto` |
|---|---|---|
| `implement` | § Step 1 — execute the plan | option 1, sequential |
| `implement` | § Step 2 (g) — phase boundary | continue |
| `implement` | § Step 2 (e) — plan-reality mismatch | **waits** — hard stop |
| `implement` | § Step 2 (e.1) — blast-radius cross-post | **waits** — outward |
| `done` | § Step 1 — confirm the item | proceed |
| `done` | § Step 2 — DoD checklist | **waits** — outward: the last stop before § Step 3 pushes |
| `done` | § Step 4 — durable knowledge (dossier, CLAUDE.md, README, REVIEW.md) | **waits** — never auto-edit |
| `done` | § Step 5 — return to main | option 1 |
| `next` | § Process (2) — exactly one candidate | pull it |
| `start-task` | § Branch / worktree | the mode the context recommends |
| `start-task` | § Spec requirement | `false` |
| `start-task` | § Dirty working tree | **waits** — uncommitted work |
| `session-handoff` | § Step 3 — resume options (resume mode) | option 1, continue the task |

`implement` § Step 2 (c) is deliberately **not** in this table: flipping an AC checkbox on the current Issue has no checkpoint at any level. § Hard stops covers the outward actions that leave the current Issue.

**A full `implement` → `done` cycle under `attended-auto` still costs acks, by design — the two `done` rows above.** § Step 2 is the last stop before § Step 3 runs `git push` and `gh pr create`, and § Step 4 proposes edits to `CLAUDE.md` / `README.md` / `REVIEW.md` that are never auto-applied. Both were considered for auto-advance and rejected: a level built to remove acks that removes the one in front of publishing has inverted the guarantee it was supposed to preserve. Every other **soft** ack in the cycle is gone — the `**waits**` rows above (plan-reality mismatch, blast-radius cross-post, dirty working tree) bind at every level and this paragraph does not touch them.

`/samuel:create-atomic-commit` is likewise absent from the table on purpose. `implement` § Step 2 (f) cites it for the message convention and commits inline; the skill is never dispatched from that path, so its own confirmation is not a gate this level has to move.

Two of these reverse a rule that was written deliberately, so they are flagged rather than silently folded in:

- **`next` — "If only one is available, still confirm."** That rule exists so the skill never picks in silence. `attended-auto` announces what it picked, which satisfies the original intent by a different route.
- **`start-task` — worktree by default.** The conductor requires worktree isolation because its SAFETY GATE does. `attended-auto` has no such requirement, and forcing a worktree on an attended run costs a new session in another path — more friction, not less. It picks the mode the context recommends and says which.

## Hard stops — unchanged at every level

No level auto-advances any of these. They are not checkpoints to be optimised; they are the reason the pipeline can be trusted to run without one.

- Plan-reality mismatch
- `CONSTITUTION.md` MUST violation
- A red gate, or a `Blocker` from the independent reviewer
- An incomplete Definition of Done
- An open `Q-NNN` carrying `Blocking: yes`
- Orphaned context — a `task-context.md` pointing at a CLOSED item
- Any outward action: `git push`, opening or merging a PR, marking one ready, publishing `pr-self-audit` comments, cross-posting to another Issue

## Recording contract

What separates `attended-auto` from `autonomous` is *where the record goes*, and it follows from who is watching.

| | `attended-auto` | `autonomous` |
|---|---|---|
| Chat | one line naming the default taken — **always** | nothing; nobody is reading |
| Journal (`D-NNN`) | only when the default **resolved an ambiguity** — never for merely continuing | always |
| `gh issue comment` | **never** | on hard STOPs |

The chat line is the review surface. It names the gate and the value taken, in one line, at the moment it happens — not batched into a summary at the end, which is a report nobody reads against a decision nobody can still change cheaply.

The journal row is narrower than it looks, and deliberately so. Taking the obvious default at a gate is not a decision — that is the premise the whole level rests on — so twelve of the thirteen gates above write nothing: four resolve before any journal exists (`next`, both `start-task` gates, `session-handoff`), and the rest merely continue work already agreed. The exception is `done` § Step 1, which journals when the item was resolved from anywhere other than `task-context.md`: there the default picked *which issue the PR closes*, and that is an ambiguity with a wrong answer. Under `autonomous` the column is `always` because the chat line has no reader — the journal is the only surface left.

A run that writes a `D-NNN` per phase boundary is not being thorough; it is burying the entries that record real choices under a log of the level working as designed.

An `attended-auto` run that posts Issue comments for its assumptions is a bug, not extra diligence: the human who would read that comment is in the session watching the line go by.

## Boundary

| Question | Owner |
|---|---|
| **How** a checkpoint is rendered (tool vs text) | `interaction-tools.md` |
| **When** a checkpoint happens at all | each skill's phase structure (`pipeline.md`) |
| **Whether** a checkpoint is skipped, and what is recorded | **this file** |

Before `attended-auto` existed, the third row named `/samuel:conductor` — a skill, because it was the only bypass. With two, the rule belongs in one place that both read.

## Gotchas

_Add a line each time Claude trips on something._

- `autonomous` is not a value the file may set. Only `/samuel:conductor` reaches that level, and only after its SAFETY GATE passes.
- The level changes **which** branch of a checkpoint runs, never whether the checkpoint exists. Never delete a `**WAIT.**` block to implement a level — extend its parenthetical.
- The chat line is not optional under `attended-auto`. A default taken silently is indistinguishable from a checkpoint that was never there, and the next reader has no way to tell which happened.
- The key is per-machine: `.claude/` is gitignored in full, so neither `samuel.md` survives a clone. That is deliberate — the level is a personal working preference, not a property of the repo.
- A skill that reads the key must also point here; the two go together and `scripts/lint-autonomy.sh` checks for both.
- The gate table cites **sections, never lines**. Adding the two-line wiring block to a skill shifts every line below it, and this table is the only index of where the gates live — `lint-autonomy.sh` G6b rejects a `SKILL.md:NN` citation inside it.
- A rule about accepted values belongs in the `awk`, not in a paragraph next to it. The resolved string is injected verbatim into `## Context` above parentheticals that branch on the literal word `Autonomous`; prose does not filter it.
- Taking a gate default is **not** a `D-NNN`. Twelve of the thirteen gates write nothing — journal only when the default resolved a real ambiguity (§ Recording contract), or the entries that matter drown in a log of the level working.
- An **unattended** run is `autonomous` regardless of what the file says (§ Resolution, step 0) — and that means any headless `claude -p`, not just `/samuel:conductor`. The failures it prevents are both silent: a run that inherits `attended-auto`'s **waits** stalls at a gate nobody will answer, and one that keeps announcing writes its assumptions to a chat with no reader and no journal.
- A `**waits**` row must correspond to a real, marked stop in the skill — a `**WAIT**`, a `HARD STOP`, or a "forced checkpoint". A row asserting a guard that does not exist is worse than a missing row: it reads as a green tick to anyone auditing whether outward actions are gated.
- **This level grants no push authority.** `done` § Step 2 is the last stop before § Step 3 runs `git push` and `gh pr create`, and § Step 3 has no gate of its own. Auto-advancing the DoD checkpoint deletes the only confirmation in front of publishing — which makes the hard-stop list false in the one place it matters most. It was wired that way for one round and reverted.
