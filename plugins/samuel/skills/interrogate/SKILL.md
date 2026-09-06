---
name: interrogate
description: "The agent's own first-principles pass before it reports work as done — self-invoked at every close-out (implement Step 3, validate Step 2, iaas Simplify, coordinate C6), rarely typed by a human: restate what the change is for, then challenge every piece against it — what is unnecessary, over-complicated or resting on a weak assumption; what can be deleted; what gets simpler once it is gone. Applies the cuts (delete > simplify > optimize > automate) and is allowed to conclude the work is fine and change nothing. Trigger on 'interrogate', 'first principles', 'challenge this', 'is this really done', 'what can we delete', 'cuestiona esto', 'qué sobra'."
allowed-tools: Bash(git branch *) Bash(git diff *) Bash(git merge-base *) Bash(git log *) Bash(git status *) Bash(tail *) Read Edit Write Grep Glob AskUserQuestion
---

# Interrogate (First-Principles Pass Before Done)

Think from first principles about what this change is trying to achieve, then interrogate what was built against that — before anyone calls it done. The output is a shorter, plainer change, or the honest finding that it is already as small as it should be.

**Who runs it: the agent, on its own work.** This is the question the author asks before saying "done", not a review the human requests. Every close-out in the pipeline invokes it (`implement` Step 3, `validate` Step 2, `iaas` Simplify, `coordinate` C6); a human types it only to point it at something specific (a path, a plan). Its verdict line rides in whatever report the calling skill was about to print — never a separate ceremony.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

**Boundary.** `/samuel:remove-slop` removes what a senior developer would not have *written* (narration comments, defensive noise, type hacks) without touching logic; `/simplify` cleans reuse and efficiency inside the code that stays. This skill questions whether the code should *exist*: the scope, the mechanism, the assumptions under it. `/samuel:find-unknowns` looks for what is missing; this one looks for what is surplus. Run it after the work compiles and the gate is green, before `validate` or the PR.

## Mode

```
/samuel:interrogate                      — the current branch diff against the base
/samuel:interrogate path/ …              — a file, directory or module, regardless of branch
/samuel:interrogate --plan               — the Executor Plan in the Issue body, before implementing
/samuel:interrogate --dry-run            — findings and verdicts only, no edits
```

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Merge base: !`git merge-base origin/main HEAD 2>/dev/null || echo "NO_MERGE_BASE"`
- Diff size: !`git diff --stat origin/main...HEAD 2>/dev/null | tail -1 || echo "NO_DIFF"`
- Changed files: !`git diff --name-only origin/main...HEAD 2>/dev/null || echo ""`
- Dirty tree: !`git status --porcelain 2>/dev/null | tail -5 || echo ""`

## Process

1. **Restate the purpose in one sentence**, from the user's side, not the code's: what must be true when this is done, and for whom. Take it from the Issue's TL;DR *What* line, the commit messages, or the human's words — not from what the diff happens to do. If the diff and the purpose disagree, that is the first finding.
2. **Interrogate**, one pass over every piece of the change (a function, a file, an option, a layer, a dependency, a test, a config key), asking three questions in this order and writing the answer down before moving on:
   - **Is it necessary?** Which sentence of the purpose does it serve? None ⇒ candidate for deletion. Name the assumption it rests on ("callers may pass null", "this will be reused", "the API might change") and say whether anything in the repo, the Issue or the conversation actually supports it. An assumption nobody stated and nothing evidences is weak, and a piece resting only on it goes.
   - **Can it be deleted entirely?** Not reduced — removed. Abstractions with one caller, options with one value, fallbacks for states that cannot occur, compatibility for versions that never shipped, tests that assert the mock, docs that restate the code.
   - **What gets simpler now that it is gone?** Deletions cascade: a removed branch makes a condition constant, a removed option flattens a config, a removed layer lets two files become one. Re-read the survivors after each cut.
3. **Verdict table** — one row per piece: `piece · verdict (delete | simplify | keep) · the reason in one line`. `keep` needs a reason as much as `delete` does; "it works" is not one. The table is the deliverable even when every row is `keep`.
4. **Apply**, in this order of preference and never skipping a rung: **delete** over **simplify**, simplify over **optimize**, optimize over **automate**. A cut that removes behaviour a test, a doc or another Issue references is a product decision: stop with one `AskUserQuestion` naming the behaviour and who depends on it. Everything else is reversible on the branch — apply it, then run the same gate the change already passed. Red after a cut means the cut was wrong or the test was asserting the surplus; say which.
5. **Report**: purpose · the table · what was removed (lines and files) · gate result · the assumptions that were challenged and what the evidence said. When nothing changed, say so in one line and stop — a clean pass that invents a cut to look useful is the failure this skill exists to prevent.

## Rules

- **Delete beats simplify beats optimize beats automate.** Reach for the next rung only when the previous one is exhausted.
- **It might already be done.** Leaving good work alone is a valid and frequent outcome; report it plainly.
- **Challenge the assumption, not the author.** Every `delete` names the assumption it removes and the evidence that failed it; a cut with no stated assumption is taste, and taste is `/samuel:remove-slop`'s job.
- **Purpose first, diff second.** Read the diff only after the purpose is written; otherwise the diff explains itself and every piece looks necessary.
- **No new code.** This pass adds nothing — no helper to "clean up" the deletion, no abstraction to "make it simpler". If a simplification needs new code, it is not a simplification.

## Gotchas

_Add a line each time Claude trips on something._
