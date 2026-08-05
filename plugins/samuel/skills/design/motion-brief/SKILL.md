---
name: motion-brief
description: Refine a natural-language description of a desired animation, transition, or motion effect — optionally with screenshots, diagrams, GIFs, or reference videos — into a precise, implementation-ready Motion Brief using canonical animation nomenclature. Use when the user describes motion loosely ("the cards should kind of cascade in", "make it feel bouncy like iOS"), shares a visual reference of an effect to reproduce, or asks to polish an animation idea into an agent-ready prompt.
allowed-tools: Read Glob Grep Write AskUserQuestion
---

# Motion Brief

Translate loose motion intent ("it should kind of float in") into an unambiguous spec that an implementing agent or developer can build without guessing. The deliverable is a **Motion Brief** that ends in a paste-ready agent prompt.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Process

1. **Ingest** every input
2. **Extract the five facets** — trigger, cast, choreography, feel, purpose
3. **Name every effect** → [references/vocabulary.md](references/vocabulary.md)
4. **Resolve feel into numbers** → [references/feel-to-parameters.md](references/feel-to-parameters.md)
5. **Fold in project constraints**
6. **Write the brief**

### 1) Ingest

Read everything provided: text, screenshots (identify which elements move and their start/end states), diagrams, GIFs/videos (name the source effect when recognizable — "that's the Dynamic Island morph"). If the user references a screen in the current repo, locate the component (Glob/Grep) and use real element/file names in the brief.

### 2) Extract the five facets

- **Trigger** — what starts it: load, enters viewport, click/tap, hover, scroll, drag, state change, route change.
- **Cast** — what moves, what stays, and stacking (what passes over what).
- **Choreography** — simultaneous vs staggered vs sequenced; what leads, what follows.
- **Feel** — the user's adjectives ("bouncy", "calm", "snappy"). Adjectives never survive into the final brief.
- **Purpose** — feedback, spatial orientation, hierarchy, or delight. Purpose sets the restraint level.

### 3) Name every effect

Load [references/vocabulary.md](references/vocabulary.md). Replace every vague phrase with its canonical term ("grows out of the button" → *origin-aware scale-in*). Disambiguate close pairs (*morph* vs *crossfade* vs *shared element transition*). Never invent terms — compose from the glossary instead ("a stagger of scale-in entrances").

### 4) Resolve feel into numbers

Load [references/feel-to-parameters.md](references/feel-to-parameters.md). Every adjective becomes easing + duration (+ spring parameters where relevant). No "fast" or "smooth" in the output — only values.

### 5) Fold in project constraints

Check the working repo before writing: motion rules in CLAUDE.md, motion guardrails/lint, banned easings, design tokens for durations, and the animation stack already installed (`package.json`: gsap, motion/framer-motion, react-spring, CSS-only, …). The brief must comply with what exists — never propose a new animation library when the project already has one.

### 6) Write the brief

Sensible default structure — adapt sections to the effect, keep the Agent prompt block always:

```markdown
# Motion Brief: <short name>

**Purpose**: <why this motion exists — one line>
**Trigger**: <what starts it>

## Cast
| Element | Role |
|---------|------|
| <element> | moves / static / scrim / trigger |

## Choreography
1. <element> — **<canonical term>** — <from → to> — <duration> @ <delay>, <easing>
2. …

## States & interruptions
- **Exit / reverse**: <what happens on dismiss or state revert>
- **Interruption**: <interruptible mid-flight? retarget or snap?>
- **Reduced motion**: <prefers-reduced-motion fallback>

## Constraints
- <project motion rules found + performance notes>

## Assumptions
- <defaults chosen where input was silent>

## Agent prompt
<fenced block: self-contained, paste-ready prompt>
```

## Example

Input: *"When the dashboard loads I want the stat cards to kind of fall into place one after another. Alive, but not clownish."* + screenshot of 4 cards in a row.

Key output lines:

```markdown
## Choreography
1. stat-card 1–4 — **staggered entrance** (**fade in** + **slide in** from below):
   opacity 0→1, translateY 16px→0 — 350ms each @ 60ms stagger (DOM order), back.out(1.2)

## States & interruptions
- **Exit / reverse**: none — one-shot on mount.
- **Reduced motion**: 150ms opacity fade, no translate.

## Agent prompt
Implement a load entrance for the four stat cards in dashboard-overview.tsx:
staggered entrance in DOM order with a 60ms gap; each card fades in (opacity 0→1)
and slides in from 16px below over 350ms with a slight overshoot settle
(GSAP back.out(1.2) or spring stiffness 300 / damping 24). One-shot on mount, no exit.
Respect prefers-reduced-motion: 150ms opacity fade only. Animate transform/opacity only.
```

"Alive, but not clownish" resolved to a *slight overshoot* (back.out(1.2)), not a full *bounce* — that disambiguation is the job.

## Gotchas

- Screenshots show the END state — confirm the start state or record an assumption.
- Arrows in diagrams mean direction of travel; numbered annotations mean sequence order. Don't conflate them.

## Rules

- Ask at most 3 questions, only when the answer changes implementation; otherwise pick a default and list it under Assumptions.
- The agent prompt must be self-contained — no references to "the screenshot" or "as discussed above".
- Always specify exit/reverse behavior, interruption behavior, and the `prefers-reduced-motion` fallback.
- Animate only compositor-friendly properties (transform, opacity) unless the effect genuinely requires more — then flag the cost explicitly.
- Scrubbed (scroll-linked) effects get progress mappings (e.g. "0–40% of section scroll"), not durations.
