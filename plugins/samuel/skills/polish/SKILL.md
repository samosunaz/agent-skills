---
name: polish
description: "Run the whole simplification chain over a finished branch as ONE run — `/samuel:interrogate` (delete what should not exist) → the runtime's native `/simplify` (tidy what stays) → `/samuel:remove-slop` (strip the slop) — then re-run the project's real checks and report once. Takes several PRs as a blast, one worktree per run. Assumes the behaviour is already correct: it removes, it never fixes. Trigger on 'polish', 'simplify blast', 'run the simplification pass', 'remove-slop and simplify', 'tidy the branch before merge'."
allowed-tools: Bash(git branch *) Bash(git diff *) Bash(git merge-base *) Bash(git status *) Bash(git log *) Bash(git add *) Bash(git commit *) Bash(git push *) Bash(git worktree *) Bash(gh *) Bash(orca *) Bash(head *) Bash(tail *) Bash(wc *) Bash(xargs *) Read Edit Write Grep Glob Skill Monitor AskUserQuestion
---

# Polish (One Simplification Run Over a Finished Branch)

Three passes, one run, one report: `/samuel:interrogate` deletes what should not exist, the runtime's native `/simplify` tidies what stays, `/samuel:remove-slop` strips what a senior developer would not have written — in that order, over one branch diff, ending in the project's own checks and a single summary. The failure it removes is the owner re-typing the pairing: in a 30-day audit, 21 of 109 sessions (32 turns) re-specified "the same run, not two separate ones", re-named the model and effort, and then had to ask afterwards whether the pass had been run at all.

**Two runs are not the same as one.** Each re-reads the whole diff from scratch and the second one re-argues the first one's choices — a comment the first pass kept as load-bearing comes back as slop, an abstraction the first pass deleted gets reintroduced by a tidy-up that never saw the deletion. The chain is cheap precisely because the three passes share one read of the diff.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

**Boundary.** This skill runs three existing passes and reimplements none of them: `/samuel:interrogate` owns the deletion criteria, native `/simplify` owns the reuse and altitude cleanups, `/samuel:remove-slop` owns the slop taxonomy. `/samuel:iaas` owns the same chain whenever an item goes through the audit loop (`../iaas/references/phase-contracts.md` § Phase 4) — so a PR whose IAAS run will reach Simplify is never polished by hand: look for its simplify-pass marker first and stop when one is there. `/samuel:pr-self-audit` is the skill that finds defects; polish assumes behaviour is already correct and must leave it unchanged.

## Mode

```
/samuel:polish                             — the current branch diff against its base
/samuel:polish 101 102 105                 — a blast: one run per PR, own worktree each, serial
/samuel:polish 101 102 105 --parallel 2    — cap concurrent runs (default 1)
/samuel:polish --worker claude:opus:high   — dispatch each run to a worker instead of this session
/samuel:polish --dry-run                   — verdicts only: no edits, no commits, no push
```

`--worker` takes `<agent>:<model>:<effort>` and defaults to the Simplify row of `../iaas/references/phase-contracts.md` § Model routing. Launch through the protocol `/samuel:coordinate` already owns (`../coordinate/references/dispatch-protocol.md`); this skill never invents a launcher, and never drops a run below that default to save tokens.

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Merge base: !`git merge-base origin/main HEAD 2>/dev/null || echo "NO_MERGE_BASE"`
- Diff size: !`git diff --shortstat origin/main...HEAD 2>/dev/null | tail -1 || echo "NO_DIFF"`
- Changed files: !`git diff --name-only origin/main...HEAD 2>/dev/null | head -40 || echo ""`
- Dirty tree: !`git status --porcelain 2>/dev/null | wc -l | xargs || echo "0"`
- Simplify pass already posted: !`gh pr view --json comments --jq '[.comments[].body | select(contains("Simplify pass"))] | length' 2>/dev/null || echo "NO_PR"`

## Process

1. **PRECONDITIONS** — the branch has commits over its base, the tree is clean, and the project's checks are **green before the first pass**. Another session's untracked files are reported by name and left where they are: never stashed, never committed, never deleted. A red start is a stop — a run that begins on a red tree owns nothing and proves nothing, and every later failure gets blamed on passes that did not cause it. An item whose PR already carries a simplify-pass marker is skipped and named in the report.
2. **SCOPE** — `base...HEAD`, nothing else. Context measures against `origin/main`; when the PR's base is another branch, recompute the diff against that base before judging anything. A file the branch never touched stays untouched even when the cleanest cut lives there; it becomes a follow-up line with the path and a one-line reason. Read each touched file whole before judging its style — a diff never shows the convention it is sitting inside.
3. **THE CHAIN, IN ORDER, ONE RUN** — `Skill`-invoke the three in this turn: `/samuel:interrogate`, then native `/simplify`, then `/samuel:remove-slop`. The order is the reason the run is cheap: tidying a piece the next pass would delete is wasted work, and slop removal is cosmetic, so it goes last and cleans what the first two wrote. Native `/simplify` fans out reviewer sub-agents — tell the run to **end its turn after launching them and resume when they report**, or it blocks waiting on itself; where sub-agents are unavailable (a headless or sandboxed worker), run its review angles inline instead. Any pass may legitimately change nothing.
4. **MINIMUM-CODE RULE** — the chain exists to remove. A pass that adds an abstraction, a helper, a constant or a configuration point "to simplify" has contradicted its own purpose: revert it. Behaviour, public contracts, test expectations and user-facing copy are frozen. **A test that had to change is a finding, not a simplification** — stop and report it.
5. **VERIFY** — re-run the project's **real** checks for **every** project or package the diff touches (lint, typecheck, unit tests), read off the repo's instruction file or its package scripts and never invented. Redirect the output to a file and read the exit code; a piped gate reports the pipe's status, not the gate's. On a machine several sessions share, run the cheap targeted tier here, leave the full gate to the integrator, and say in the report which tier ran.
6. **COMMIT + RECORD** — one commit per pass that changed something, named for that pass; a pass that changed nothing gets no commit and one plain line saying so. Where the branch has a PR, leave exactly ONE comment in the shape `/samuel:iaas`'s Simplify phase uses — one line per pass, "no changes needed" where that is the truth — carrying a `samuel:run` block stamped `phase: simplify` per `../../reference/github-operations.md` § Run metadata. **Pushing is an outward action and a hard stop at every autonomy level.** Batch the entire blast into ONE approval listing branch → commits → checks → what would be pushed. **WAIT.** After the push, run the repo's signoff command when `.claude/samuel.md` declares one, never against a SHA the checks did not run on.
7. **BLAST MODE** — for several items: intersect the changed-file lists first and order the runs so two branches sharing a file never run concurrently — two writers tidying the same file produce conflicting cuts and a merge nobody can review. Overlapping pairs go serial in the order the human gave them; the rest may run up to `--parallel N`. One worktree per run, cut from the branch head, and check for a live run on that branch before dispatching. Close with ONE table: item · lines removed/added · which passes changed something · checks · pushed?

## Gotchas

_Add a line each time Claude trips on something._

- The owner re-typed "the same run, not two separate ones" across 21 sessions. Splitting the chain is not a smaller version of it: each half re-reads the whole diff and the second half re-litigates the first half's calls.
- Native `/simplify` deadlocked twice waiting on reviewer sub-agents it had launched in the same turn, and the fix regressed once when the "end the turn after launching them" line was dropped from a dispatch. That line belongs in **every** dispatch, not just the first.
- Seven simplify briefs went into ONE checkout inside 47 minutes — concurrent writers on a single tree. One worktree per run, and a live-run check on the branch before any dispatch.
- A simplify pass once surfaced a fail-open bug. That is a defect report for the human — never folded silently into a "tidy" commit, where the next reader finds a behaviour change hiding in a cleanup diff.
- Least code is an instruction for the IMPLEMENT step. When a polish run has a lot to remove, the implement brief was missing that rule — say so in the report, so the fix lands upstream instead of recurring every branch.
- Linting only one of the touched projects let the integrator's full gate fail at the very end, after the run had already reported green. Every project the diff touches gets its own check.
- "Pre-existing failure" is a claim, and it requires reading the imports of the failing file before it can be made. A run that starts red cannot make it at all.

## Rules

- **One run, one report.** Three passes over one read of the diff — the pairing is the whole skill.
- **Subtractive only.** Lines removed is the metric; a net-positive pass needs its reason in the report.
- **"No change" is a complete result.** Padding a clean branch to look useful is the failure this chain most often produces.
