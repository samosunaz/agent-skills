---
name: biz-tldr
description: "Retell a technical text (a review, plan, PR, or set of findings) for the person who owns the product: a headline, the flow end to end as who-does-what steps, what can go wrong and what it costs someone, internal-only fixes in one line, and the owner's decisions with a recommendation. Trigger on 'biz-tldr', 'business tldr', 'explain it for the business', 'in business terms', 'explain it as a flow', 'for a non-technical reader'."
allowed-tools: Read AskUserQuestion Bash(gh issue view *) Bash(gh pr view *)
---

# Business Retelling

Retell a technical text so the person who owns the product can decide from it. `/samuel:tldr` keeps the text and makes each sentence unambiguous. This skill changes the frame: from how the system works to who does what, what they get, and what can go wrong for them. It is a translation, not a summary. Every risk, warning and open decision in the source survives (Step 4).

**Boundary.** `/samuel:debrief` reports the outcome of merged work from its diffs. This skill retells any technical text, usually before a decision is made, and reads only what it is given.

> Spokes: `references/biz-tldr.md` (translation patterns, a worked example, self-check; **read it before the first retelling of a session**) · `../tldr/references/ste-rewrite.md` (sentence rules, owned by `/samuel:tldr`).
> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Step 1: Pick the target

| Input | Target |
|---|---|
| No argument | The last assistant message in this conversation |
| Pasted text | That text |
| A file path | The file contents (read the file first) |
| An issue or PR number | Its body and comments, read with `gh issue view` / `gh pr view` |

"Last assistant message" means the previous prose response addressed to the user. Skip tool calls and tool results.

## Step 2: Inventory before writing

List, for yourself, everything a person would act on:

- **Actors**: every person or role the text implies (end user, customer, operator, support, partner, the team).
- **The trigger** that starts the flow, and **the outcome** the end user sees at its end.
- **Every risk, warning, finding and unknown**, with its number or scope condition exactly as the source states it.
- **Every open decision**, and the options the source offers for it.
- **Internal-only items**: fixes that change nothing for any person.

This list is the contract for Step 4. A retelling that loses an item from it is wrong, however clear it reads.

## Step 3: Translate

Turn each technical item into its consequence for a named person. "The foreign key blocks the delete" becomes "a catalog manager who still owns a supplier cannot be removed until someone reassigns it". Patterns in the spoke § Translation patterns.

- **No identifiers.** Leave out file paths, line numbers, and table, column, function, endpoint and variable names. Keep one only when no business word exists, and then once, in backticks.
- **Numbers and scoped conditions stay exact.** "Up to 500 km" stays "up to 500 km". "Only for new customers" never widens to "for customers".
- **Mark what is unconfirmed** in plain words ("We do not know yet whether…"), and keep the source's own uncertainty.

## Step 4: Write the retelling

Five blocks, in this order:

1. **Headline**: exactly one sentence that says what this means for the business or the user, not for the code. A second sentence belongs in a later block.
2. **The flow**: numbered steps from the trigger to the end user's outcome. Each step opens with an actor doing something: a person, a role, an outside company, or the product acting for them. A screen, badge or message is never the actor; it is what someone sees ("The owner sees a Connected badge"). Add a sub-bullet only where the action differs by case (with or without the optional part).
3. **What can go wrong**: each risk as a bold lead-in, then what it costs a person. Unknowns are stated as unknowns. Nothing from the Step 2 list is dropped to keep this short.
4. **Internal only**: one line for the fixes that change nothing for anyone, so nobody reads them as product decisions. Omit the block when there are none.
5. **Decisions**: each choice the owner must make, with the recommended option first and one line of reasoning. Ask them with `AskUserQuestion` (1-4 questions, 2-4 options each, the recommendation labeled). When no decision is open, say so in one line.

Sentence-level rules (one idea per sentence, active voice, no filler, no ambiguous referents) are `/samuel:tldr`'s: follow `../tldr/references/ste-rewrite.md`, do not restate them here.

## Step 5: Constraints

- **Answer in the user's language.** These instructions are English; the retelling is in whatever language the user writes in.
- **Never add a fact.** If the source did not verify something, the retelling does not claim it.
- **Never soften.** A blocking finding stays blocking, and a failing check stays failing.
- **Never write anywhere.** Print the retelling. Never post it, comment it, or edit the source, unless the user asks in the same turn.
- **Ask nothing** in an unattended run (`/samuel:conductor`, any headless `claude -p`), when the retelling is for someone other than the user, or when the user says not to ask. List the decisions instead, with the recommended option marked as the assumption taken.

## Gotchas

_Add a line each time Claude trips on something._

- Dropping a risk to stay short is the failure this skill exists to prevent. Shorten the wording, never the list.
- "Internal only" is not a drawer for the uncomfortable items. A fix belongs there only when nothing changes for any person. If it changes who can do what, or what someone sees, it is a flow step, a risk, or a decision.
- Not every finding is a decision. A finding with one obvious fix is a risk and its fix. A decision is a choice the owner has to make between options.
- When the source is already framed for the business, say so in one line and do not invent a retelling.
