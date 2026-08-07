---
name: roadmap
description: "Product Ownership session — read the product's real state and propose prioritized bets (what to build next and why), persisted as roadmap:* issues ready to promote into the pipeline. Discovery, upstream of plan. Trigger on 'roadmap', 'product direction', 'what to build next', 'what is next for the product', 'upcoming capabilities', 'opportunities', 'where to take this'."
allowed-tools: Bash(gh *) Bash(git log *) Bash(git branch *) Bash(awk *) Bash(test *) Bash(ls *) Bash(date *) Read Write Edit Glob Agent AskUserQuestion
---

# Roadmap — Product Ownership

A recurring **discovery** session with a Product Owner's mindset: read where the product actually is, then propose a short, prioritized set of **bets** — what to build next and *why* — persisted as `roadmap:*` issues. This is upstream of delivery: bets get committed later via promotion → `/samuel:plan`. The opposite of `/samuel:next` (which pulls already-committed work).

> **Mindset spoke**: `../../reference/product-ownership.md` — the discovery lenses, prioritization, and the bet shape. Read it before generating bets.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Critical Rules

1. **Discovery, not delivery.** Output is bets (problem + outcome + why), never plans or code. The Executor Plan comes later, at `/samuel:plan`.
2. **Outcomes over output, build less.** Every bet states a measurable outcome and ties to the north star. The list's value is what it *excludes* — cut hard.
3. **The founder holds market context.** Surface options and trade-offs; do **not** invent market facts, user demand, or revenue claims. Ask; weight the founder's signal heavily.
4. **Forced checkpoints.** Confirm the north star and the shortlist before persisting anything. Never auto-create issues.
5. **Horizons, not dates.** Now / Next / Later. No fake timelines.

## Context

- Date: !`date '+%Y-%m-%d'`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/samuel.md 2>/dev/null || echo "NO_REPO"`
- Capability catalog: !`ls docs/product 2>/dev/null || echo "NO_CATALOG"`
- Vision doc: !`test -f docs/vision.md && echo "docs/vision.md" || echo "none"`
- Current roadmap (github): !`gh issue list --state open --label "roadmap:now" --label "roadmap:next" --label "roadmap:later" --json number,title,labels 2>/dev/null || echo "n/a"`
- Recently shipped (github): !`gh issue list --state closed -L 15 --json number,title,closedAt 2>/dev/null || echo "n/a"`
- Open delivery work (github): !`gh issue list --state open --label "pipeline:triage" --label "pipeline:planned" --json number,title 2>/dev/null || echo "n/a"`

> **Tracker**: `../../reference/tracker.md`. Adapter: `../../reference/github-operations.md` (roadmap labels + issue ops). **Bet shape + lenses**: `../../reference/product-ownership.md`.

## Phase 1: UNDERSTAND THE PRODUCT

**Goal**: an honest picture of where the product is today. No bets yet.

1. **Capabilities** — read the dossier catalog (`docs/product/README.md` + each `<slug>/README.md`): what the product *does* today, each capability's status/maturity. This is the richest input.
2. **Vision & front door** — `docs/vision.md` (if present) and the root `README.md`: what it's for, for whom.
3. **Momentum** — recently shipped issues (closed) = direction & velocity; open `pipeline:*` = what's already committed (don't re-propose it); current `roadmap:*` = standing bets to revise, not duplicate.
4. **Constraints** — skim `docs/decisions/` (ADRs) for what's locked in.
5. **Code gaps (optional)** — if the product state is unclear from docs, spawn `component-locator` / `pattern-scanner` (sonnet, single message) to find half-built areas, TODOs, or obvious friction. Retrievers only; synthesis here.

Synthesize a short **"product today"**: what exists, what's strong, what's thin.

**Checkpoint 1**: present "product today" + anything that surprised you. **WAIT** — the founder corrects the picture.

## Phase 2: NORTH STAR

**Goal**: agree on direction before generating bets.

State the north star from the vision/README; if absent or stale, propose one and ask. Capture the primary user job and the success signal (activation / retention / revenue / differentiation) the founder cares about *now*.

**Checkpoint 2**: confirm north star + the signal to optimize. **WAIT.**

## Phase 3: GENERATE BETS

Run the **discovery lenses** (`product-ownership.md`): capability completion · value/job · differentiation · friction/debt · adjacent expansion · founder/market signal. Generate a *wide* set of candidates (10–20), each as a one-liner: *job → outcome*. Don't filter yet. If a `--focus "{theme}"` arg was given, bias the lenses to it.

## Phase 4: PRIORITIZE

Narrow ruthlessly (`product-ownership.md` prioritization):
1. Drop anything not tied to the north star or a real job, and low-value/high-effort.
2. Assign each survivor a **horizon** (Now 1–2 max · Next · Later) and a rough **effort** (S/M/L).
3. Rank within horizon by value × effort × confidence × revenue-path.

Present the **shortlist** as a table: *Bet · Job/Outcome · Value · Effort · Horizon · Why now*. Recommend the Now bet(s) with reasoning; list Next/Later. Be honest about what you cut and why.

**Checkpoint 4**: the founder edits horizons, kills bets, adds their own. **WAIT for the agreed shortlist.**

## Phase 5: PERSIST

Persist the agreed bets to GitHub (confirm first — never auto-create):

One issue per bet: the TL;DR block + the `## Opportunity` mini-brief as the body (`product-ownership.md`). The TL;DR is what makes a shortlist of fifteen bets re-readable next month — write it from the lens that produced the bet, and put the assumption that would kill it in `Caveat:`.
```bash
gh issue create -R {repo} --title "{type}: {bet}" \
  --label "type:feat,roadmap:{now|next|later}" \
  --body-file /tmp/bet-{n}.md
```
Revise existing `roadmap:*` issues in place (re-horizon, update, or close a dropped one) instead of duplicating.

**Optional `ROADMAP.md`** (if the founder wants a strategic view): regenerate `docs/product/ROADMAP.md` from the `roadmap:*` issues — north star on top, a table per horizon linking each bet. It's a **projection**, not the source; note "generated from roadmap:* issues — don't hand-edit."

## Phase 6: PRESENT

```
Roadmap updated  ·  {date}

North star: {one line}
Now:   {bet} (#n)   ·   {bet} (#n)
Next:  {n bets}
Later: {n bets}
{ROADMAP.md regenerated: docs/product/ROADMAP.md}

Next:
- Commit a bet → promote it: see below, then /samuel:plan
- Execute committed work: /samuel:next
```

### Promoting a bet (discovery → delivery)

When the founder commits a bet, hand it to the pipeline: `gh issue edit {n} -R {repo} --add-label pipeline:triage --remove-label "roadmap:{horizon}"`, expand the `## Opportunity` mini-brief into a full `## Brief` (Scope / Out of scope / Acceptance Criteria) and re-chip its TL;DR to the delivery shape, then `/samuel:plan {n}`.

**Multi-item commit**: when the bet splits into several issues, or one committed bet depends on another, declare the native `blockedBy` edges at promotion — read-then-add, never blind-add (adapter § Issue dependencies). `/samuel:waves` computes execution order from this graph; an order that lives only in the horizon labels or the brief is invisible to it.

`/samuel:next` also surfaces `roadmap:now` bets and can route a chosen one through promotion.

## Gotchas

_Add a line each time Claude trips on something._

- Discovery ≠ delivery: never write an Executor Plan here. A bet is a mini-brief; the plan is `/samuel:plan` after promotion.
- Don't invent market demand or revenue numbers — that's the founder's context. Surface options, ask, weight their signal.
- Don't re-propose committed work (`pipeline:*`) or duplicate standing `roadmap:*` bets — revise in place.
- Now is 1–2 bets. A roadmap where everything is "Now" is not prioritized.
- `ROADMAP.md` is a projection of the issues — regenerate it, never hand-edit; the issues are the SoT.
- `roadmap:*` and `pipeline:*` are mutually exclusive on an issue — promotion swaps one for the other.
- A multi-item promotion without declared `blockedBy` edges collapses into one giant wave at dispatch — declare edges at promotion time, not after `/samuel:waves` already read the graph.
