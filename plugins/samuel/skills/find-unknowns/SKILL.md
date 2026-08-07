---
name: find-unknowns
description: "Map-vs-territory audit — surface known unknowns, unknown knowns, and unknown unknowns of an idea, Issue, or diff before they get expensive. Modes: audit (default), preflight (Issue N), teach (--teach «domain»), quiz (--quiz [N]). Standalone — no task-context required. Trigger on 'find unknowns', 'unknowns', 'blind spot', 'what am i missing', 'quiz me'."
allowed-tools: Bash(gh issue view *) Bash(gh issue comment *) Bash(gh pr view *) Bash(gh pr diff *) Bash(git diff *) Bash(git log *) Bash(git branch *) Bash(git rev-parse *) Bash(awk *) Bash(date *) Read Grep Glob Agent Write Edit AskUserQuestion
---

# Find Unknowns (Map vs Territory)

The prompt, Brief, or plan is the **map**; the codebase and domain are the **territory**. Work quality is bottlenecked by the gaps between them — the unknowns (Anthropic, *A Field Guide to Claude Fable*). This skill hunts those gaps while they are cheap to fix: before implementation (audit), before unattended pickup (preflight), before entering an unfamiliar domain (teach), and before merging work you didn't write line-by-line (quiz).

**Not `/samuel:analyze`** — analyze checks artifacts against each other (spec↔plan↔constitution). This skill checks the *human's map* against the *territory*: what the input never mentions, never decided, or can't articulate.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Pipeline Position

Standalone — runs with zero pipeline state, in any repo or none. When `.claude/task-context.md` or an Issue exists, it enriches the audit; it never requires them. Preflight is the natural pre-`pipeline:ready` companion (wrong assumptions are the top failure mode of unattended runs).

## Context

- Date: !`date '+%Y-%m-%d'`
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Repo (repo config): !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Active item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Phase: !`awk '/^phase:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_PHASE"}' .claude/task-context.md 2>/dev/null || echo "NO_PHASE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE_DIR"`

## Input resolution

| Input | Mode |
|---|---|
| Free text (an idea, a goal, a half-formed feature) | **AUDIT** the idea |
| Bare number `N` | **PREFLIGHT** Issue N (`gh issue view N` Brief + Executor Plan vs territory) |
| Nothing, with an Active item in Context | **AUDIT** the active feature at its current phase |
| `--teach «domain»` | **TEACH** the domain's unknown unknowns |
| `--quiz [N]` | **QUIZ** on PR N's diff, else current branch vs default branch |

## The four quadrants

| Quadrant | Question | Hunt technique |
|---|---|---|
| Known knowns | What does the map actually say? | Restate it — contradictions surface here |
| Known unknowns | What do I know I haven't decided? | **Interview** — one question at a time, architecture-first |
| Unknown knowns | What's so obvious I'd never write it down? | **Recognition** — contrasting variations to react to, not articulate |
| Unknown unknowns | What am I not considering at all? | **Blind-spot pass** — territory scan diffed against the map |

## AUDIT

1. **Restate the map.** ≤10 bullets of what the input actually pins down (known knowns). Flag contradictions and vagueness inline — a fuzzy map is itself a finding.
2. **Scan the territory.** When code is involved, spawn `component-locator` + `pattern-scanner` in ONE message (add `implementation-analyzer` when a specific module is named). When no repo is relevant, the domain itself is the territory — skip agents, use domain knowledge.
3. **Hunt the quadrants** — blind-spot first (it can invalidate everything else):
   - **Blind-spot pass**: list what the territory demands that the map never mentions — adjacent modules, existing conventions and similar implementations, auth/permissions, migrations, state transitions, race conditions, rate limits, i18n, rollout/rollback. Score each by blast radius.
   - **Interview** (known unknowns): ONE question per turn, max 5, ranked by "would the answer change the architecture?". Stop early once answers stop moving the design. Batch questions are forbidden — sequencing lets each answer reshape the next question.
   - **Recognition** (unknown knowns): where the map hides taste/subjective criteria (API shape, naming, UX flow, visual tone), offer 2-3 contrasting variations to react to. Recognition beats articulation.
4. **Deliver the Unknowns Map** — format in `references/formats.md`: per finding, quadrant × cost-if-ignored × resolution path (answer / prototype / spike / accept-risk), closing with the **rewritten brief**: the sharper prompt the user should have written. That rewrite is the deliverable — the audit exists to produce it.
5. **Persist by context.** Feature dir present → offer `{feature_dir}/unknowns.md` (committed). Issue given → offer ONE consolidated comment on the Issue (decision surface). Bare idea → inline only.

## PREFLIGHT (audit an Issue before autonomy)

AUDIT with input = the Issue's Brief + Executor Plan (`gh issue view N --json title,body,comments`). Two additions:

- Check the plan against the territory **as of today** — files it names that moved, conventions it predates (the drift dimension: `git log` since the plan was written, over the files the plan names).
- End with a verdict (format in `references/formats.md`):
  - **READY** — no open architecture-changing unknowns; safe to promote to `pipeline:ready` / unattended pickup.
  - **HOLD** — blocking unknowns listed as questions (U1, U2, …); offer to post them as one Issue comment. **An Issue with open architecture-changing unknowns MUST NOT be promoted to `pipeline:ready`.**

## TEACH

For a domain the user flags as unfamiliar (`--teach color-grading`, `--teach webhooks de Stripe`):

1. **Mental model** — how practitioners actually think about the domain, in one screen.
2. **The vocabulary that steers** — the 5-10 terms that act as prompt handles; knowing the word is owning the dial.
3. **What good looks like** vs the common failure smells.
4. **Three example prompts** the user could now write that they couldn't before.

Then offer to apply it: generate contrasting variations over the user's actual artifact — teaching ends in recognition, not theory.

## QUIZ (comprehension gate)

Read the diff (`gh pr diff N`, else `git diff` against the default branch). Then:

1. **Change report**: context → intuition (why this shape and not another) → what changed → **how it interacts with existing code paths** — the part the diff doesn't show.
2. **5-8 behavioral questions** — "what happens if X", edge cases, interactions with existing behavior. Never trivia (no "what's the function called"). Every question answerable from report + diff.
3. **WAIT** for answers. Grade honestly. Failed topics → explain, then one re-quiz round on those topics only.
4. Verdict rule: no clean pass → recommend **not merging yet**. Built for reviewing agent-authored PRs: the human keeps the understanding while the loop does the work.

## Autonomy

Under `/samuel:conductor` (or headless CI, `GITHUB_ACTIONS=true`):

- **Interview OFF** — answer each known unknown from the territory when the evidence supports it; the rest land as questions on the decision surface (journal `Q-NNN` / Issue comment), never invented.
- **Recognition OFF** — conservative pick + record, per the conductor's assumption protocol.
- **Blind-spot pass ON** — it is the point of running this skill unattended.
- **PREFLIGHT verdict is a hard gate** — `HOLD` ends the run with the unknowns recorded; the conductor never argues past it.
- **QUIZ is human-only** — a quiz the author grades itself is theater; never run it unattended.

## Gotchas

_Add a line each time Claude trips on something._

- Quiz questions test behavior, not recall — a question answerable without understanding the change is a bug.
- Enumerate findings/questions as `U1`/`Q1`, never `#{n}` — `#` autolinks on GitHub surfaces (§ Enumeration IDs, `reference/github-operations.md`).
- Pass `-R {repo}` (Context) on every `gh` write; never parse `git remote`.
- Pure-domain audits (no repo) spawn no agents — domain knowledge is the territory.
- Preflight on an Issue that already has an in-flight branch is drift-checking, not planning — don't rewrite the plan, report against it.
