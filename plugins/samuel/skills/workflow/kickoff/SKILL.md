---
name: kickoff
description: "Initialize a new indie project: vision doc, MVP scope, tech decisions, initial task breakdown. Trigger on 'kickoff', 'nuevo proyecto', 'start project'."
allowed-tools: Bash(gh *) Bash(which *) Bash(git branch *) Bash(git status *) Bash(ls *) Bash(awk *) Read Write Agent AskUserQuestion
---

# Kickoff Project

Initialize a new indie project with a clear vision, scoped MVP, and actionable task breakdown. Anti-over-engineering from day 1.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- CWD: !`pwd`
- Existing config: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"none"}' .claude/samuel.md 2>/dev/null || echo "none"`
- gh auth: !`gh auth status 2>/dev/null | head -1 || echo "gh not authenticated"`
- Git status: !`git status --porcelain 2>/dev/null || echo "Not a git repo"`

> **Tracker**: `../../../reference/tracker.md`. Adapter: `../../../reference/github-operations.md`. **Brief/plan format**: `../../../reference/plan-templates.md`.

## CRITICAL RULES

1. **MVP or nothing.** Every feature gets the question: "Can the product validate without this?" If yes, it's post-MVP.
2. **Revenue-aware.** Every project needs a clear path to money, even if it's indirect.
3. **Forced checkpoints.** Every phase needs user approval. Don't auto-advance.
4. **No fluff.** No mission statements, no brand manifestos. Concrete deliverables only.

---

## Phase 1: VISION — What and Why

**Goal**: Define the project clearly enough that a stranger could understand it in 30 seconds.

### Ask (if not already provided):

```
Tell me about the project:

1. What is it? (one sentence)
2. Who is it for? (target user)
3. How does it make money? (revenue model)
4. What problem does it solve that nobody else is solving well?
```

If the user already described the project, extract these answers from context. Don't re-ask what's already clear.

### Checkpoint 1 — Present vision:

```
## Project Vision

**What**: [one sentence]
**Who**: [target user]
**Revenue**: [model — subscriptions, one-time, ads, freemium, etc.]
**Differentiator**: [what makes this worth building]

Correct? Any adjustments?
```

**WAIT for user approval.**

---

## Phase 2: MVP SCOPE — What to Build First

**Goal**: Define the minimum feature set to validate the idea. Explicitly exclude everything else.

### Actions

1. Based on the vision, propose 3-7 core features for MVP
2. For each feature, rate: **Must Have / Nice to Have / Post-MVP**
3. Define success metrics: what tells you the MVP worked?

### Checkpoint 2 — Present scope:

```
## MVP Scope

### Must Have (ship-blocking)
1. [Feature] — [1 sentence what it does]
2. [Feature] — [1 sentence what it does]

### Nice to Have (include if easy, skip if hard)
- [Feature]

### Explicitly NOT in MVP
- [Feature] — [why it can wait]

### Success Metrics
- [Metric 1]: [target] (e.g., "10 paying users in first month")

### Tech Stack (recommended)
- **Frontend**: [recommendation with rationale]
- **Backend**: [recommendation with rationale]
- **Hosting**: [recommendation with rationale]
- **DB**: [recommendation with rationale]

Scope adjustments? Different stack?
```

**WAIT for user approval.**

---

## Phase 3: EXECUTE — Set up the repo & seed work

**Goal**: pin the repo config and turn the scope into actionable items.

### Step 0: Write config

Ask for `owner/name`, then write `.claude/samuel.md` (`tracker: github` + `repo` — see `reference/tracker.md`) so the config is pinned. Run `gh repo set-default owner/name`; verify `gh repo view owner/name`; create the pipeline + `roadmap:*` + `type:*`/`priority:*` + `promo:*` labels (idempotent `gh label create --force`, full block in `github-operations.md` § Labels).

### Step 1: Vision doc

Committed `docs/vision.md` (`Write`) — Vision + MVP scope + success metrics + tech decisions from Phases 1-2.

### Step 2: Seed one item per Must-Have feature (Brief only, no plan yet)

One Issue per feature, TL;DR + Brief only:
```bash
gh issue create -R {repo} --title "{type}: {feature}" \
  --label "type:feat,priority:high,pipeline:triage" \
  --body "{TL;DR block + Brief — Scope/Out of scope/Acceptance Criteria, per plan-templates.md}"
```
Items start at `pipeline:triage`. `/samuel:plan` fills the Executor Plan and promotes to `pipeline:planned`/`ready`.

Seeding is where the TL;DR earns the most: a fresh backlog is a dozen issues nobody has context on yet, and in a week the founder won't either. Estimates at this stage are guesses — say so in the chip (`~1 día?`) rather than omitting it.

### Checkpoint 3 — Present

```
## Project Initialized

**Config**: .claude/samuel.md   ·   **Vision**: docs/vision.md
**Seeded**: {N} items across {M} Must-Have features

| Feature | Item | Priority |
|---|---|---|
| {Feature 1} | #12 | high |

### Recommended start
{most foundational feature} — it unblocks the others.

### Next steps
1. Plan the first feature: `/samuel:plan {item}`  (turns a triage Brief into a planned item)
2. Or pick work: `/samuel:next`   ·   Progress: `/samuel:progress`
3. Once items are `pipeline:ready`, autonomous: `/samuel:conductor {item} --ship`
```

---

## Rules

- **Anti-scope-creep.** If the user starts adding features during kickoff, push back: "Is it a Must Have to validate the idea? If not, it goes to Post-MVP."
- **Tech pragmatism.** Recommend boring, proven tech for indie projects. Time-to-market > architectural purity.
- **Revenue first.** If there's no revenue model, ask. Ideas without revenue paths become side projects that die.
- **Start small.** 3-5 Must Have features max. If there are more, the scope is too big.
- **No perfect plans.** The kickoff creates enough structure to start. The plan will evolve.

## Gotchas

_Add a line each time Claude trips on something._

- Write `.claude/samuel.md` BEFORE seeding work — every later skill resolves `repo` from it.
- `gh repo set-default owner/name` once, so issue/PR commands work behind the SSH-alias origin. Create labels before the first `gh issue create`.
- `--labels`/`--label` are comma-separated, no spaces: `"type:feat,priority:high,pipeline:triage"`.
- If `Existing config` in Context isn't `none`, the repo is already initialized — confirm before overwriting `.claude/samuel.md`.
