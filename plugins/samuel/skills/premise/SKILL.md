---
name: premise
description: "Burn a product fact agents keep re-deriving wrongly into the file they actually read, then sweep the repository for everything that contradicts it. Fires when the human corrects the same assumption a second time. Trigger on 'premise', 'burn this in', 'write this down where agents read it', 'you keep assuming that', 'I already said this last session', 'is there a mantra for this'."
allowed-tools: Bash(git rev-parse *) Bash(git ls-files *) Bash(git grep *) Bash(gh issue *) Bash(ls *) Bash(wc *) Bash(xargs *) Bash(awk *) Read Write Edit Grep Glob Agent AskUserQuestion
---

# Premise — state it once, then make the repository agree

A premise is a fact about the product that the code cannot show: the committed sample fixtures are disposable test data rather than a design baseline; a field exists for one caller and nothing else; a mode is temporary until a launch flag flips. Agents re-derive these facts from what they find on disk, and disk says the opposite — **whatever is committed reads as canonical**. So the correction gets typed again next session, to an agent that never saw the last one.

Measured over thirty days of one owner's sessions: a single premise was re-argued in **5 separate sessions across three weeks** (9–12 turns in total, escalating into capitals), and roughly a third of all preventable correction turns traced back to it. Meanwhile agents shipped tests, guardrails and plans that froze the very thing the premise calls disposable. This skill writes the fact once, in the place agents load, and finds everything already contradicting it in the same pass.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

**Boundary.** `/samuel:create-constitution` and `/samuel:update-constitution` own the MUST rules of *how code is written*; `/samuel:feature-dossier` owns a capability's reference; `/samuel:done` § Durable knowledge proposes what one finished item leaves behind; a memory note helps only the session that wrote it. This skill owns one thing: **a product fact, plus the sweep that makes the repository agree with it**. It does not fix the contradictions it finds — it lists them and files or proposes the follow-ups. A premise write that also rewrites eleven files is unreviewable, and an unreviewable diff is where the human stops reading and the premise stops being true.

## Mode

```
/samuel:premise "<the premise, in the human's words>"   — state it, find its home, sweep, propose the write
/samuel:premise                                          — derive the candidate from the correction just made, then confirm it
/samuel:premise --sweep-only "<premise>"                 — already written: re-run the sweep alone
/samuel:premise list                                     — print the premises this repo already declares
```

## Context

- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Root instruction files: !`ls CLAUDE.md AGENTS.md CONTEXT.md 2>/dev/null | xargs || echo "NO_ROOT_INSTRUCTIONS"`
- Nested instruction files: !`git ls-files '*/CLAUDE.md' '*/AGENTS.md' 2>/dev/null | wc -l | xargs || echo "0"`
- Premises already declared: !`git grep -l '^## Premises' -- '*.md' 2>/dev/null | wc -l | xargs || echo "0"`
- Sweep scope (top-level dirs): !`ls -d */ 2>/dev/null | xargs || echo "NO_DIRS"`
- Trees to exclude from the sweep: !`ls -d .claude/skills .agents/skills node_modules vendor 2>/dev/null | xargs || echo "NONE"`
- Tracker repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`

## Process

1. **STATE IT** — rewrite the premise as **one falsifiable sentence plus its consequence**: "X is Y; therefore no plan, test or guardrail may count, freeze or derive rules from X." Add the reason in one line, and — when the fact is temporary — the condition that retires it (a launch flag flipping, a migration landing), never a date. Read it back for approval: the sentence is the human's, and you are tightening its grammar and drawing out the consequence, not restating the argument in your own vocabulary. **WAIT.** Invoked with no argument, derive the candidate from the correction just made in this conversation, quote the turn that prompted it, and confirm that same sentence.

2. **FIND ITS HOME** — the file an agent loads when it works on the area the premise governs, most specific first: a nested instruction file next to the code, then the root instruction file, then a context/glossary file or an ADR when the repo keeps them. **One home.** Anywhere else that needs it links to the home rather than restating it — two copies drift, and the copy an agent happens to read is the one that wins. Never a memory note alone, never a comment in code.

3. **CHECK WHAT IS ALREADY WRITTEN** — search the instruction files, ADRs and dossiers for this premise *or its opposite*. Already stated ⇒ the finding is that agents are not reading it: report where it lives and go straight to the sweep. A statement of the **opposite** is the deliverable — report both with their locations and stop for the human to pick. Never settle a contradiction between two instruction files on your own judgement.

4. **SWEEP FOR CONTRADICTIONS** — everything in the repository that behaves as if the premise were false. The kinds worth naming, because they are what got built last time: tests that lock an inventory, a count or a hash of the thing; guardrails that enumerate it; docs that instruct a reader to treat it as canonical; plans and open issues whose acceptance criteria depend on it; code that reads a field nothing writes, or writes a field nothing reads. Scope code searches to the source directories in Context and exclude the vendored trees. Fan the search out to subagents on a large repo; what comes back per hit is `path:line`, one line of why it contradicts, and the **smallest** action — delete, rewrite, or re-scope the issue.

5. **COUNT READERS** — when the premise is "this concept earns its place" or "this field is needed", the sweep is a census: every non-test reader and every writer, each with `path:line`. A writer with no reader, or a reader behind a flag that is off in production, is reported as exactly that. A planned reader is not a reader — and neither is your own recommendation from earlier in the same session.

6. **PROPOSE THE WRITE** — show the exact text and the exact file, in the repo's block (create it if absent), then stop: **editing an instruction file is a hard stop at every autonomy level**. **WAIT.** On approval, write that block and nothing else — no reformatting of the file around it, no Step 4 fixes riding along.

   ```markdown
   ## Premises

   - **{The sentence, falsifiable.}** Therefore {what no plan, test, guardrail or doc may do}. {Reason, one line.} {Expires when … | Permanent.}
   ```

7. **FOLLOW-UPS AND REPORT** — contradictions become work, not prose: one issue per independent fix, or a checklist appended to one existing issue when they belong to a single piece of work — whichever the repo's tracker convention says (`../../reference/tracker.md`). **Cross-posting to an issue this session does not own is an outward action and waits**, as does opening issues in bulk. Close with four lines: the premise, its home, the contradiction count by kind, and what was filed.

## Gotchas

_Add a line each time Claude trips on something._

- **A correction the human makes twice is a missing premise, not a misunderstanding.** One premise was argued in 5 sessions across three weeks before anyone wrote it down; the owner asked mid-argument whether a place to burn it in even existed, and five hours later a different session ran the same argument from scratch. Offer this skill at the second correction, not the fifth.
- **Whatever is committed reads as canonical.** Test data, sample fixtures and seed content sitting next to real code get frozen by the next agent's tests and guardrails unless a file that agents load says they are disposable.
- **A premise written only into a session's memory is invisible.** Every other session, every worker and every other engine starts from disk; a memory note helps exactly one session — the one that wrote it.
- **"It must mean something."** A heading copied out of a reference product became a typed, required field with zero readers, because nobody counted. Step 5 exists for that, and it applies to your own recommendation from ten minutes earlier just as much as to inherited code.
- **A "superseded" banner is a deprecation shim in prose.** A doc that contradicts the premise stays discoverable by grep with the banner on it, and dead commands stay copy-pasteable; the sweep proposes deletion, not a header.
- **An unscoped repository-wide search counts vendored copies as real occurrences.** One "exactly one implementation left" check returned 17 lines instead of 2, because vendored skill trees carry their own source. Scope to the source directories — that is what the Context exclusion line is for.
- **A temporary premise with no expiry condition becomes the next stale instruction.** Pre-launch rules and temporary modes name the flag or the migration that retires them, inside the sentence itself.

## Rules

- One premise per invocation. Two facts are two sweeps, two approvals and two homes.
- The sweep reports; it never fixes. The premise block is the only edit this skill makes.
- A premise that cannot be falsified is a slogan. If no test, plan or doc could ever contradict it, it does not belong in an instruction file.
