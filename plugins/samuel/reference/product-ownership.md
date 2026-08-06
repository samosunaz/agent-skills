# Product Ownership — Discovery Lenses & Prioritization

The mindset spoke for `/samuel:roadmap`. This is **discovery** (what *could* we build, and why), upstream of **delivery** (`/samuel:plan` → `/samuel:implement`). The output is a small set of prioritized **bets**, persisted as `roadmap:*` issues, ready to be committed to the pipeline later.

## Philosophy

- **Outcomes over output.** A bet is justified by the *change it creates* (activation, retention, revenue, defensibility), not by the feature itself. "Add X" is not a bet; "cut checkout abandonment by letting users resume a payment" is.
- **North-star first.** Every bet ties back to where the product is going. If it doesn't move the north star or serve a real user job, it's noise — cut it.
- **Build less.** The default answer to "should we build this?" is *no*. The roadmap's value is what it *excludes*. A short, sharp list beats a long wish-list.
- **Horizons, not dates.** Now / Next / Later communicate sequence and confidence without fake commitments. A solo founder's roadmap is a hypothesis, not a promise.
- **Founder leverage (indie lens).** Prefer bets with a path to recurring revenue or compounding advantage. Time-to-market and focus beat completeness.
- **The roadmap is alive.** Bets are issues (the SoT), not a static doc that drifts. A `ROADMAP.md` is a *projection* of those issues, not the source.

## Discovery lenses — how to generate bets from today's state

Read the product as it exists (dossiers = capabilities, README/vision, open/closed issues, ADRs, the code), then run these lenses. Each surfaces a different kind of bet:

1. **Capability completion** — from the dossier catalog (`docs/product/`): which capability is half-built or mediocre? What would make it *excellent*? (e.g. checkout exists but has no payment retry.)
2. **Value / job opportunities** — what unmet user or business *job* would move activation, retention, or revenue? Frame as jobs-to-be-done, not features.
3. **Differentiation** — what would make the product unique or defensible — the "why us"?
4. **Friction & debt** — what frustrates users or throttles growth? UX breaks, performance, scalability ceilings that block the next stage.
5. **Adjacent expansion** — given what exists, what's the natural *next* capability? (whitelabel, multi-tenant, a new processor, an API.)
6. **Founder / market signal** — what the founder knows about the market and users that the code can't tell you. Weight this heavily; the agent surfaces options, the founder holds the context.

> The lenses generate *candidates*. Most get cut. The skill's job is to surface a wide set, then ruthlessly narrow.

## Prioritization

Two passes:

**1. Horizon (Now / Next / Later).**
- **Now** — the active bet(s), 1–2 max. What you'd commit next. High confidence in value, scoped enough to plan.
- **Next** — seriously considered, behind Now. Likely soon; value clear, scope or timing not yet.
- **Later** — parked, not dropped. Real options for the future; revisit, don't commit.

**2. Within a horizon — rank by:**
- **Value × effort** — impact vs. rough cost (S/M/L). Favor high-value/low-effort (quick wins) and a few high-value/high-effort (bets); drop low-value/high-effort.
- **Confidence** — how sure is the value? Low confidence → smaller probe first, or push to Next/Later.
- **North-star alignment** — does it advance the stated direction?
- **Revenue path** (indie lens) — direct or compounding path to money, even if indirect.

## Anti-patterns

- **Roadmap as a dated promise** → horizons, never dates.
- **Feature factory** (output with no outcome) → every bet states its measurable outcome.
- **Building without a why** → every bet links to the north star + a real job.
- **The long wish-list** → if everything is on the roadmap, nothing is. Cut hard.
- **Drift** → bets live as issues (SoT); the `ROADMAP.md`, if kept, is regenerated from them.

## A bet's shape (the `roadmap:*` issue body)

A bet is a *mini-brief* — enough to decide, not enough to build. The Executor Plan comes later (at `/samuel:plan`, after promotion).

```markdown
<!-- samuel:opportunity -->
> **What:** {the capability it opens — one sentence}
> **Why:** {the job it resolves, tied to the north star}
> **Caveat:** {what would kill it: a dependency, an unvalidated assumption, a market bet. "None" is valid}
> `{S|M|L}` · `confidence {high|medium|low}` · `{now|next|later}`

## Opportunity
**Problem / Job:** {the unmet user or business job}
**Outcome:** {the measurable change if we ship it}
**Value:** {why it matters — activation / retention / revenue / differentiation}
**Effort:** {rough — S / M / L}
**Why now:** {timing, dependency unlocked, momentum — or "Later: parked because …"}
**Horizon:** now | next | later
```

The TL;DR block is the same four lines every samuel Issue opens with (spec: `reference/github-operations.md` § TL;DR) — only the chips are bet-specific. A roadmap review means re-reading ten or twenty of these at once, which is exactly the scan the block is for. `confidence` is the discovery analogue of delivery's `risk`: how sure are we this is worth building, not how likely it is to break.

## The discovery → delivery handoff

```
/samuel:roadmap  →  roadmap:now|next|later issues (bets)
                       │  founder commits a bet
                       ▼
                    pipeline:triage  →  /samuel:plan (Brief + Executor Plan)  →  /samuel:implement → …
```

On promotion, the `## Opportunity` mini-brief is expanded into a full `## Brief` (Scope / Out of scope / Acceptance Criteria); the `roadmap:*` label is swapped for `pipeline:triage`. The TL;DR survives the promotion — rewrite its chips to the delivery shape (`risk`, estimate) and re-check `Caveat:`, since a bet's killer assumption often becomes the plan's real hazard. Discovery ends, delivery begins.
