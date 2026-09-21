---
name: cascade
description: "Run one item down the intelligence tiers and back up: this session (the owner's flagship model) frames the problem and answers the planner's checkpoints, a high-tier planner writes the Executor Plan, a medium-tier implementer executes it, a fresh high-tier reviewer audits the diff, and this session does the final read and gives a merge verdict. Trigger on 'cascade', 'tiered run', 'plan with opus execute with sonnet', 'you coordinate, opus plans'."
allowed-tools: Bash(orca *) Bash(gh *) Bash(git fetch *) Bash(git status *) Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git rev-parse *) Bash(git worktree *) Bash(grep *) Bash(awk *) Bash(head *) Bash(wc *) Bash(xargs *) Bash(date *) Read Edit Write Skill Agent SendMessage AskUserQuestion PushNotification
---

# Cascade (Tiered Plan → Execute → Review → Final Read)

Work flows **down** the tiers and judgment flows back **up**. The scarce model is spent where a wrong call is most expensive — framing the problem, ratifying the plan, and the last independent read — and nowhere else. Planning goes to a high-tier model, typing goes to a medium-tier one, and the review goes to a high-tier instance that never saw the code being written.

| Tier | Role | Default | Owns |
|---|---|---|---|
| **top** | coordinator + final analyst | this session — the strongest model the owner has | framing, the planner's checkpoints, plan ratification, the final read, the verdict |
| **high** | planner · reviewer (two separate instances) | `opus` — plan at effort `high`, review at `xhigh` | the Executor Plan · the audit of the frozen diff |
| **medium** | implementer | `gpt-5.6-luna` at effort `high` through the Codex runtime, for size S and M with a closed spec · the high tier (`opus`, `high`) for size L, user-facing work, or when Codex has no quota or cannot run the tests | executing a plan that leaves no design decision open |

**The medium-tier implementer is a deliberate exception.** Every other skill here keeps a worker that ships code on the high tier (`../iaas/references/phase-contracts.md` § Model routing). Cascade may go lower because two things sit above the implementer that those skills do not have: a plan ratified by the top tier before any code exists, and two independent reads after. Take either away and the exception is gone — run `/samuel:iaas` instead. **The audit never drops a tier**: an under-powered auditor returns "no findings" and looks identical to a clean pass. **Which cheaper engine is a measured choice, not a price list:** the one matched run so far put `gpt-5.6-luna` level with `opus` on a medium fix at half the output tokens, and put `sonnet` behind both at a higher token count — so `sonnet` is an explicit `--medium sonnet:high` for size S, not the default. The numbers, and what reopens them: `../iaas/references/phase-contracts.md` § Model routing.

Briefs, the ratification checklist and the final-read checklist live in `references/tier-briefs.md`. Dispatch mechanics are not repeated here: Orca workers follow `../coordinate/references/dispatch-protocol.md` and the six-slot brief in `../coordinate/references/worker-brief.md`; the audit and address rounds are `/samuel:iaas` with this table as its routing override.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

**Boundary.** `/samuel:coordinate` splits one task across workers and reads their reports, opening the diff only on risk; `/samuel:iaas` runs the implement–audit–address–simplify loop for an item that already has a plan; `/samuel:plan` writes a plan with the human answering its checkpoints. Cascade is the chain around them for an item that has **no ratified plan yet** and whose owner wants the top tier's judgment at both ends: it adds a dispatched planner whose questions come here instead of to the human, a ratification step before code, and a final read that **always** opens the diff. It reimplements none of them and, like them, it never merges on its own.

## Mode

```
/samuel:cascade <issue N | task text>       — the full chain
/samuel:cascade N --from execute            — the item already carries a ratified Executor Plan
/samuel:cascade N --from review             — a branch or draft PR exists; start at the audit
/samuel:cascade N --final                   — another session ran the loop; do only the final read and the verdict
/samuel:cascade N --transport orca|agents   — Orca workers (default when Orca is up) or in-session sub-agents
/samuel:cascade N --medium <model>:<effort> — override the implementer tier for this run
```

## Context

- Orca: !`orca status --json 2>/dev/null | grep -o '"state": *"[a-z]*"' | head -1 | xargs || echo "ORCA_DOWN"`
- Other sessions in this checkout: !`orca terminal list --worktree current --json 2>/dev/null | grep '"handle"' | wc -l | xargs || echo "0"`
- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Untracked files here: !`git status --porcelain 2>/dev/null | grep '^??' | wc -l | xargs || echo "0"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Date: !`date +%Y-%m-%d`

## Process

1. **FRAME** (top) — before anyone plans: the outcome in the user's terms, scope, what is explicitly out, the definition of done, the size chip, and the **premises** the plan must respect (the repo's declared ones, `/samuel:premise list`). If this session is not the owner's flagship model, say so now: a mid-tier model ratifying and signing off is the failure this skill exists to avoid. **Direct lane:** an S with no behaviour change is done in this session — a cascade costs more than the change.
2. **PLAN** (high) — dispatch the planner with the framing (brief in `tier-briefs.md` § Planner). It produces a Brief + Executor Plan in the shape of `../../reference/plan-templates.md`. **Its checkpoints come to this session, not to the human**: answer from the framing and the code; forward to the human only what is genuinely theirs — scope, a product premise, anything outward or irreversible — and forward it once, with your recommendation first. The human is never the message bus between two sessions.
3. **RATIFY** (top) — challenge the plan before it costs an implementation (`tier-briefs.md` § Ratification): spot-check that cited paths and lines exist, **measure** what the plan asserts instead of accepting it, look for the platform feature or existing dependency that already does the job, check that every step leaves the tree green, check the premises, and cut what the outcome does not need. One send-back at most; a second means the framing was wrong — fix that. Present the ratified plan with what you changed and why. **WAIT for approval** unless the human already handed you the item end to end in this run; then announce it in one line and continue.
4. **EXECUTE** (medium) — before the brief, run one focused test through the implementer's own sandbox: an engine that cannot execute the project's tests from a worktree writes blind, and the medium tier is `opus` for that run. Then one implementer, its own worktree, the ratified plan embedded verbatim in the six-slot brief, least-code rule stated, VERIFY listing the real checks of **every** project the plan touches. It ends at a draft PR or a frozen commit and a six-line report. It asks rather than improvises: a plan–reality mismatch comes back up, it is not worked around.
5. **REVIEW** (high, fresh instance) — never the planner's instance and never a continuation of the implementer: the audit judges the diff against the issue's acceptance criteria and the plan, under `../../reference/review-rubric.md`. Rounds are `/samuel:iaas N --from audit` with this skill's table as the routing override: the audit on the high tier at `xhigh` **executing from round 1**, the read-only second audit by another model family on size M and L, and address and simplify on the high tier until a matched run measures them lower. Its ceiling and stop rules apply unchanged. From round 2 the adversarial cases target the fix itself, not a re-read of it.
6. **ESCALATE, DON'T GRIND** — the medium tier failing the same step twice, or a Blocker rooted in a misunderstood design, moves **that step** up to the high tier. More rounds on the lower tier buy the same argument again at the same price.
7. **FINAL READ** (top) — read the diff yourself, always (`tier-briefs.md` § Final read). Report first would be the coordinator's habit; here the independent read is the product. Look for what the tiers below structurally cannot see: the outcome met in letter but not in purpose, a premise violated, a platform feature reinvented, dead surface left behind, a claimed number nobody re-measured, and the **delta** between the SHA the reviewer approved and the PR head. State comes from `gh`, never from a report: required checks green **on the head SHA**, commits behind base, draft or ready.
8. **VERDICT** — `MERGE`, `HOLD` (what is missing, who can supply it) or `REWORK` (which tier, which step), with the reasons and the non-blocking notes. Posting notes on the PR, marking it ready and merging are outward actions: present them together and **WAIT** once. A merge grant the human gave earlier in this run, in their own words, is that approval given early — quote it in the report; it covers only a `MERGE` verdict on the verified head (`gh pr merge --match-head-commit`), and it lapses on anything else. Then `PushNotification` one line.
9. **CLOSE THE RUN** — run `/samuel:land --dry-run` and print what it returns: the train this run's PRs would join and the branches, worktrees and merged leftovers it would sweep. It merges and deletes nothing; it exists so the run's exit state is a list the human can approve later, not something to rediscover by hand. A run that ends at a verdict leaves its PR, branch and worktree behind — seven open PRs and twelve worktrees accumulated in one week that way.

## Gotchas

_Add a line each time Claude trips on something._

- The owner relayed a planner's checkpoints to a second session by copy-paste — twice in one evening, and in four sessions over a month — to get the top tier's opinion. Step 2 exists so that traffic never touches the human.
- A plan reviewed by the top tier before code existed changed direction on three of four items in one run: a delivery model that measurement showed was the reinvented wheel, a dependency order that was inverted, and a protection the plan deleted with nothing in its place. None of the three would have been caught by reviewing the diff.
- Two of two fast, clean audits ("no findings" in under three minutes) sat on diffs that carried a real state bug; the coordinator's own read caught both. A clean audit closes the round, never the review.
- This skill was born with `sonnet` as its medium tier and the first matched run did not back it: five implementers, one plan, blind audit — `sonnet` used the most output tokens (43k against `opus` at 30k and `gpt-5.6-luna` at 15k), left two declared test seams unproven and broke one brief rule. One task is not a verdict, so the override stays; the default moved.
- Sub-agent reports invent execution claims: "I ran it" from an agent with no shell is inference. Check the claim type against the agent's tools before relaying it, and re-measure any number that carries the verdict.
- Review notes that were marked non-blocking but never posted are lost at merge. Post them, or fold them into a follow-up issue, inside the step-8 approval.
- The fix of one round is where the next round's bug is born (2 of 2 measured). The delta read in step 7 is not optional on a PR that went through an address round.
- In auto-permission mode the runtime may refuse to launch Orca workers; the same briefs run as in-session sub-agents (`--transport agents`) with the plugin's `cascade-*` agent definitions, which pin model and effort.
- An in-session sub-agent cannot be asked a follow-up after it returns unless it is continued by name; a planner that needs answers returns its open questions as its final message and is resumed with `SendMessage`.
- Gates run one at a time on a shared machine. When another session is running the loop, wait on the required check of the head SHA through `gh`, never on the other session's terminal text — finished teammates stay listed as idle and read as running.
- A "no behaviour change" premise in a ratified plan is proven by executing the mechanism that decides it, never by reading it. 21 of 108 "duplicate class" deletions changed a computed style because the class-merge library resolves conflicts across groups; the planner, a coordinator-side classifier and a reviewer's read had all passed them, and the implementer's mechanical pass caught them. Make that pass a plan step, not an acceptance-criterion option.
- A Blocker on a string the ratified plan dictated verbatim belongs to the plan and the ratification, not to the implementer that copied it. Say so in the verdict and in any benchmark row; the fix still goes through the implementer.
- A stacked item's plan carries line numbers from the base it was written against; the sibling landing underneath it shifts them. The brief says "locate every site from the inventory and the code, not from the plan's numbers".
- An in-session agent's final message reaches the coordinator truncated at a few kilobytes. A long deliverable (a plan) is read from the sub-agent transcript under `~/.claude/projects/<project>/<session>/subagents/` — the last assistant message — not requested again in chunks.
- `setsid` does not exist on macOS. A detached ship script launched through it never starts, and a monitor on its log watches nothing for as long as its timeout. `nohup bash <script> &` alone, then read the log once before arming the monitor.

## Rules

- The top tier never implements and never skips the final read; the medium tier never decides design; the reviewer never shares context with the implementer.
- A premise the run discovers is written down with `/samuel:premise`, not re-explained in the next brief.
- No push, no PR state change, no merge, no publish without the human's approval — batched into one WAIT, never removed.
