# Interaction Tools at Checkpoints

How a skill **renders** a human checkpoint. These skills run across several runtimes — Claude Code, Codex, Cline — and only some expose native interaction tools. One convention covers both cases: use the native tool when the runtime has it, fall back to the structured text below when it doesn't.

## Boundary — what this file does not own

| Question | Owner |
|---|---|
| **How** a checkpoint is rendered (tool vs text) | **this file** |
| **When** a checkpoint happens at all | each skill's phase structure (`pipeline.md` § the phase state machine) |
| **Whether** a checkpoint is skipped, and where the record goes | `autonomy.md` — the three levels |

An autonomous run (`/samuel:conductor`, `claude -p` + `/goal`) invokes **no interaction tool at all**. Record-and-proceed does not ask — it adopts the recommended option, records the assumption on the Issue + journal + handoff, and continues. Reaching for `AskUserQuestion` in an unattended run is a bug: nobody is there to answer, and the run stalls until it times out.

`attended-auto` sits between the two: a human is watching, so the checkpoint still resolves without a tool call, but the default it took is **announced in one line** rather than recorded for a morning review. Which gates move, and which keep waiting at every level, is `autonomy.md` § Which gates move — not a per-skill judgement call.

## The tools

| Tool | Use it when | Notes |
|---|---|---|
| `AskUserQuestion` | A checkpoint offers **enumerable options** — the common case. The direct replacement for the plain-text question. | 1-4 questions per call. `multiSelect: true` when the choices aren't mutually exclusive. `preview` renders side-by-side mockups or code snippets — use it only when the user must *compare artifacts*, not for preference questions. Never add an "Other" option; the runtime supplies one. |
| `EnterPlanMode` / `ExitPlanMode` | A planning phase that ends in an approve-the-plan gate. | `ExitPlanMode` **is** the approval gate — don't ask for approval separately alongside it. Plan approval never auto-resolves on idle. |
| `TaskCreate` · `TaskGet` · `TaskList` · `TaskUpdate` | Multi-phase execution the user should be able to watch — long sweeps, multi-agent runs (`team-orchestrate`). | Not for one- or two-step work, where the checklist costs more than it shows. Superseded `TodoWrite`, which is disabled by default since Claude Code v2.1.142. |
| `PushNotification` | A long or background run finishes and the user has likely stepped away — `conductor`, overnight runs. | A notification is not a checkpoint. It announces; it does not collect an answer. |

Availability is a runtime fact, not a guess: if the tool isn't in the session's tool list (or its deferred index), it isn't there. Declare whichever ones a skill uses in its `allowed-tools` frontmatter.

## Textual fallback — defined once

When the runtime exposes no interaction tool, ask with **numbered options mirroring** what `AskUserQuestion` would have shown: the recommendation first, one line per option, and an explicit stop.

```
{One-sentence statement of the decision.}

1. {Label} (recommended) — {what it means, and the trade-off it accepts}
2. {Label} — {what it means, and the trade-off it accepts}
3. {Label} — {what it means, and the trade-off it accepts}

Which? (1/2/3)
```

**WAIT for the answer.** Rules that make the fallback equivalent to the tool, not a degraded cousin:

- The recommendation goes **first** and says why in its own line — never as a separate paragraph the reader has to reconcile.
- Options are mutually exclusive unless the question says otherwise; say "pick all that apply" for the multi-select case.
- Keep the options in the step body, not buried inside the sentence that names the tool. Both paths then read from the same list and can't drift.

This block is the only place the fallback format is defined. A skill that needs a variant adds it here; it does not inline its own.

## The standard phrase

One line per skill, near the top, in the dispatch block alongside the skill's other spoke pointers. Not one per checkpoint — the agent reads the whole SKILL.md before executing it.

```markdown
> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
```

Substitute the tool name when a skill's gate is a different one (a planning skill names `ExitPlanMode`). Adjust the relative path to the skill's depth. Everything else stays verbatim — that's what makes the convention greppable.

## Coverage check

Every `SKILL.md` either carries the standard phrase or is listed in `checkpoint-exclusions.txt` with a reason. Empty output = pass:

```bash
comm -23 <(find plugins -name SKILL.md | sort) \
         <(grep -rl 'interaction-tools' --include=SKILL.md plugins | sort) \
| grep -vxFf plugins/samuel/reference/checkpoint-exclusions.txt
```

## Gotchas

_Add a line each time Claude trips on something._

- **Not in autonomous runs.** `/samuel:conductor` records and proceeds; it never opens a question dialog.
- `TodoWrite` is **not** the progress tool anymore — disabled by default since Claude Code v2.1.142, replaced by the `Task*` family. Naming it in a new skill dates the skill on day one.
- `preview` is single-select only, and it's for comparing artifacts (mockups, snippets), not for dressing up a preference question.
- A skill that asks with the tool but writes its options only inside the tool call leaves the fallback path with nothing to print — options live in the step body.
- One line per skill, above the first checkpoint — not one per checkpoint. A skill with five gates still gets one, because the agent reads the whole SKILL.md before executing any of it.
- **Coverage is a complement, never a grep.** Gates get written as `**WAIT.**`, "Confirm:", "On confirmation", "requires approval" — every phrase list tried missed a real one, and reported green while doing it. The check above is the complement of the exclusions file, so a skill worded in a way nobody anticipated shows up as unclassified instead of passing silently.
- Waiting is not always a checkpoint. Collecting an open-ended input (`codebase-documentation` waits for the research question) or joining subagents is not a decision with options; those skills stay outside the convention deliberately.
