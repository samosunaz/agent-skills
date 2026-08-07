---
name: tldr
description: "Prose standard: rewrite a message to Simplified Technical English — one reading per sentence, no filler, no abstract jargon. Targets the last assistant message by default, or pasted text / a file path. Never touches code, commands, or quoted output. Trigger on 'tldr', 'bro', 'rewrite that', 'make it simple', 'less jargon', 'cut the filler', 'too verbose'."
allowed-tools: Read
---

# STE Rewrite Standard

Rewrite text so each sentence admits exactly one reading. Source: ASD-STE100, the controlled-language standard for aerospace maintenance manuals. Its closed 900-word dictionary and its English-only constraint do not apply here. Its writing rules do.

A tldr here is the same text made short and unambiguous. It is not a summary: the rewrite keeps every fact the original carried (Step 5).

This skill is the standard's home. A skill that emits human-facing prose defers here instead of defining its own writing rules, the same way diagram-emitting skills defer to `/samuel:mermaid`. The **TL;DR block** of every Issue and PR body is the highest-traffic case: its structure belongs to `../../reference/github-operations.md` § TL;DR, its prose belongs to this file.

> **Spoke**: `references/ste-rewrite.md` — jargon table (keep vs replace), deletion patterns, sentence surgery, before/after pairs, self-check. **Read it before the first rewrite of a session.**

## Step 1: Pick the target

| Input | Target |
|---|---|
| No argument | The last assistant message in this conversation |
| Pasted text | That text |
| A file path | The file contents (read the file first) |

"Last assistant message" means the previous prose response addressed to the user. Skip tool calls and tool results.

## Step 2: Protect the verbatim spans

Copy these unchanged, character for character: code blocks, inline code, commands, file paths, URLs, IDs, error output, log lines, and any text the original quoted from another source.

A rewrite that edits a command is a broken rewrite. Protect first, then rewrite what is left.

## Step 3: Delete

Delete before you rewrite. Most verbosity is text that carries no fact. Full table in the spoke § Deletion patterns.

1. Openers that announce the action ("Let me check", "I've gone ahead and", "Great question").
2. Closers that offer more help ("Want me to also…?", "Let me know if…").
3. Self-narration ("Now that I've read the file, I can see that…").
4. Recaps of what the reader already sees (the diff described again in prose).
5. Hedges with no real uncertainty, filler adjectives, motivational closers.

Keep a hedge when the uncertainty is real, and name its cause: "I did not run the tests, so I do not know if it passes."

## Step 4: Rewrite

1. **One word, one meaning.** Pick a term, keep it for the whole text. If it is `issue`, it is `issue` everywhere. Never rotate to "ticket" or "task" for variety.
2. **Active voice with an explicit subject.** "The hook blocks the command", not "the command is blocked", not "the command gets blocked".
3. **Imperative for instructions, one action per sentence.** "Run X. Then open Y."
4. **One idea per sentence.** Max 20 words in an instruction, 25 in an explanation. Split, do not subordinate.
5. **No ambiguous referents.** Use "this" or "that" only when the antecedent sits in the same sentence. Otherwise name the thing.
6. **No vague quantifiers.** "Several", "some", "soon" become a number, a count, or a date.
7. **Condition first in every conditional.** "If the PR is already merged, open a new one."
8. **No noun stacks longer than 3.** Break them with prepositions.
9. **Canonical tech terms stay in English and stay unexpanded** (PR, issue, squash, worktree, rollback). Abstract jargon gets replaced by the plain verb. Both lists live in the spoke § Jargon.
10. **No em dashes, no tricolons, no packaged transitions.** Use a period, a comma, or parentheses.

## Step 5: Constraints

- **Keep the source language.** Never translate. A Spanish source stays Spanish, an English source stays English. The one surface pinned to a language is the GitHub body, which is English by repo rule — that pin belongs to the adapter, not to this skill.
- **Keep every fact.** Deleting a paragraph is correct only when that paragraph carried no fact.
- **Never add a fact.** If the original did not verify something, the rewrite does not claim it either.
- **Never soften a failure.** A failed test stays a failed test, a `FAIL` verdict stays `FAIL`.
- **Keep the medium.** A list stays a list. A table stays a table.

## Step 6: Output

Print the rewritten text alone. No preamble, no "here is the cleaned-up version".

Close with at most one line naming what you cut: "Cut the opener and 2 closers." Skip that line when you cut nothing.

If the source was already precise, say so in one line and do not invent a rewrite.

Printing the rewrite is the whole job. Never post it, send it, commit it, or edit the source file, unless the user asks for that in the same turn.

## Surfaces

The standard applies to human-facing prose on any surface: the **TL;DR block** of an Issue or PR body, the Issue Brief, the rest of the PR body, an Issue comment, an ADR narrative, a validation report, a handoff, and the agent's own chat answers.

It does NOT apply to: code, commit subjects (Conventional Commits owns those), the Executor Plan (agent-facing by design, and terse for a different reason), the `CONSTITUTION.md` principle text (governed by its own English rule), and any span reproduced verbatim from another source.

## Gotchas

_Add a line each time Claude trips on something._

- `/samuel:tldr` with no argument targets the assistant's last message, not the user's.
- The TL;DR block is a synthesis written **last**, so it is the one surface where the STE pass runs on text you just wrote yourself. Composing it first and rewriting it later produces a restated title, not a compression.
- Protected spans include output quoted from another agent. Rewrite the prose around a Codex answer, never the answer itself.
- On GitHub surfaces the enumeration rule still wins: never renumber findings into `#1`/`#2` (it autolinks to Issues). Keep the element-initial IDs (`H1`, `AC1`).
