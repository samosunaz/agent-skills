---
name: land
description: "Land a set of finished pull requests as one train: read each PR's real state from the host, order them by file overlap, merge the whole set behind ONE approval, re-verify what each merge invalidates, then sweep the branches, worktrees and panes they leave behind. Trigger on 'land', 'land these', 'merge it', 'merge the set', 'ship the train', 'clean up everything cleanable'."
allowed-tools: Bash(gh *) Bash(git branch *) Bash(git status *) Bash(git fetch *) Bash(git log *) Bash(git diff *) Bash(git merge-tree *) Bash(git rev-parse *) Bash(git worktree *) Bash(git push *) Bash(orca *) Bash(awk *) Bash(grep *) Bash(head *) Bash(wc *) Bash(xargs *) Read AskUserQuestion
---

# Land — Merge the Train, Then Sweep

Take the pull requests that are already finished, put them on the base branch in the order that costs the fewest conflicts, and then remove exactly what those merges made obsolete. One approval covers the whole train and its cleanup, instead of one "merge it" per PR.

The skill exists because two pieces of reasoning were retyped by hand every time. Over 30 measured days, **109 of 1,265 typed prompts (8.6 %) were bare merge authorisations** — "merge it", "merged", "ready, merge it" — spread across **40 of 109 sessions**; **12 sessions had to ask first whether the PR had passed the whole review loop**; and **21 sessions ended with a hand-typed "clean up everything cleanable"** aimed at worktrees, panes and branches. The merge **order** and the sweep **scope** are what this skill holds so the human stops re-deriving them at every merge.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
> **Ordering algorithm, conflict prediction and stacked PRs**: `references/merge-order.md`.

**Boundary.** `/samuel:done` opens the PR and records durable knowledge for ONE item; `/samuel:iaas` and `/samuel:coordinate` stop at a draft PR and never merge; `/samuel:waves` executes a set of issues and treats the human's merge as its release gate. `land` starts where all of them stop: it takes PRs that **already exist and are believed finished**. It never implements, never reviews code and never fixes a red check — a PR that is not landable leaves the train with its reason attached and goes back to the skill that owns it.

## Mode

```
/samuel:land                  — every open PR authored by the current user that is not a release PR
/samuel:land 101 102 105      — the explicit set (order given here is a hint, not the merge order)
/samuel:land --dry-run        — collect, classify, order, print the plan; merge and delete nothing
/samuel:land --no-sweep       — land the train, leave every branch, worktree and pane alive
```

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Open PRs (mine): !`gh pr list --author @me --state open 2>/dev/null | head -20 || echo "NO_OPEN_PRS"`
- Base branch: !`gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo "NO_DEFAULT_BRANCH"`
- Merge methods allowed: !`gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed 2>/dev/null | xargs || echo "NO_MERGE_POLICY"`
- Local sign-off configured: !`awk '/^signoff:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_SIGNOFF"}' .claude/samuel.md 2>/dev/null || echo "NO_SIGNOFF"`
- Worktrees on this checkout: !`git worktree list 2>/dev/null | wc -l | xargs || echo "0"`
- Orchestration runtime: !`orca status --json 2>/dev/null | grep -o '"state": *"[a-z]*"' | head -1 | xargs || echo "NO_RUNTIME"`

## Authority ceiling

Merging is the one outward action this skill performs, and the step-4 approval is the whole grant — as well as its limit.

- **May**, after the WAIT: merge the PRs the plan named with the repo's merge method pinned to the approved SHA; update a train member from base and re-run the project's own gate; delete exactly the branches, worktrees and panes the sweep list named; move the issues those PRs close.
- **Never**, at any autonomy level: push to the base branch directly, override a failing required check (`--admin` or otherwise), mark a draft ready that was not in the plan, force-push a train member, merge a release PR that was not named explicitly, or touch a PR authored by someone else.
- If the plan changes after the WAIT — a head moved, a check went red, a new PR appeared — the **delta** goes back for approval. Re-asking is cheap; a merge nobody approved is not.

## Process

1. **COLLECT** — build the candidate set (every open PR authored by the current user minus release PRs, or the explicit list), then read each one's state **from `gh` only, never from testimony**: open/draft, `mergeable` and `mergeStateStatus`, the head SHA, how many commits it is behind base, and the review-loop evidence when the repo produces it (the pass markers and `## Resolution` comments `/samuel:iaas` leaves on the PR). Read **which checks the base branch actually requires** from the repo's branch protection or rulesets — a required check is a repo fact, not "CI presumably ran". Then check that the SHA those checks passed on is still the PR head.
2. **CLASSIFY** — every candidate becomes exactly one of: **ready**; **needs-update** (behind base, or a green check/signature that belongs to an older SHA); **blocked** (a red or missing required check, an unresolved Blocker in review, a draft with no review evidence). A blocked PR leaves the train carrying its reason and the skill that owns the fix. Nothing is repaired here.
3. **ORDER** — by file overlap, not by PR number or age. Take each PR's changed files (`git diff --name-only origin/{base}...origin/{head}`), intersect them pairwise, and put the PR that overlaps the most others **LAST**; independent PRs go first. Predict the conflicts with `git merge-tree --write-tree` before proposing anything, and name the files it flags. A **stacked** PR — its base is another PR's branch — is ordered after its base, and that base merges **without deleting its branch** until the host has retargeted the child. Algorithm, tie-breaks and the worked example: `references/merge-order.md`.
4. **PLAN + ONE WAIT** — present one table (order · PR · why this position · what gets re-verified after the previous merge), the dropped PRs with their reasons, and under it the **sweep list**: every branch, worktree, pane and issue transition the run would touch, each named. Merging is a hard stop at every autonomy level, so this gate always asks — the whole point of the skill is that it asks **once**, for the train and its cleanup together. **WAIT.** `--dry-run` ends here.
5. **RUN THE TRAIN** — merge one PR at a time with the repo's own merge method, pinned to the SHA that was verified (`gh pr merge {n} --match-head-commit {sha}`), so a push that lands between the plan and the merge fails loudly instead of merging unreviewed work. After each merge, every remaining PR that touched an overlapping file is updated from base, and its required check is **re-run and re-signed by the project's own gate command** — read from the repo's instruction file, never invented, and never signing a SHA the gate did not run against. Re-verifications run **serially**, one PR at a time. A failure stops the train where it is: report what landed, what did not, and why; never skip ahead to the next PR.
6. **SWEEP** — only what this train made obsolete, and only what step 4 listed: merged local and remote branches (never a stacked base another open PR still points at), worktrees whose branch is merged, agent terminals or panes attached to those worktrees when an orchestration runtime is present, and the linked issues' state. A worktree holding uncommitted or untracked files is **reported, not removed** — another session's work lives there. Anything not on the approved list is left alone: deleting is destructive, and the approval was for a named set. `--no-sweep` skips this step whole.
7. **REPORT** — three lists and nothing else: what landed (PR → merge SHA), what was dropped and why (naming the skill that owns the fix), and what is still alive with the exact command that removes it.

## Gotchas

_Add a line each time Claude trips on something._

- **Merge state was reported by the human because nothing polled it.** "merged", "already merged" typed 16+ times in two weeks while the session held a stale picture. `gh pr view {n} --json state,mergedAt` is the whole fix — poll it, never accept testimony, including your own memory of having merged.
- **The most entangled PR goes last** — and once a branch is updated from base, the previous green check and its signature prove nothing about the new SHA. Re-run the gate and re-sign before merging that PR.
- **`--delete-branch` on a stacked PR's base closes the child PR.** Measured once: the child closed the moment its base branch disappeared. Merge the base bare, let the host retarget the child, delete the branch later in the sweep.
- **A required check can be written by a local sign-off tool and never by CI.** The PR then sits behind a red required check with **no CI job that explains it** — which reads like a broken pipeline. Read *which* check the base branch requires before drawing any conclusion from a red PR.
- **Another session's untracked files fail your gate on your behalf**, and a sign-off tool refuses a dirty tree outright. Run re-verifications from a clean worktree whose branch tracks the remote, not from a shared checkout.
- **Parallel full gates saturate one machine** — several sessions running them at once is where the timeouts come from. A train re-verifies serially even when three PRs need it; that is the slower-and-finishes option.
- **A remote-cache hit line in CI output is not a green run of the task.** Reading "cache hit" and calling the check verified is how an unrun task passes for green.
- **A reset on a shared orchestration runtime is runtime-wide, not per run.** `reset --all` reaches every other session's runs and is not cleanup. Sweep by explicit id only, and only ids that appeared in the step-4 list.
- **"Did it pass the whole review loop?" was asked 12 times before an authorisation.** The evidence is already on the PR (pass markers, `## Resolution` comments); step 1 reads it so the plan answers the question instead of the human asking it at the gate.

## Rules

- Never implement, never review, never repair: a PR that is not landable leaves the train.
- Nothing merges that the plan did not name; nothing is deleted that the sweep list did not name.
- Every state claim comes from `gh` or `git` at the moment it is used — never from the session's memory of what it did earlier.
- A red required check is a stop, never an `--admin` override.
