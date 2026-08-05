# Output Formats — find-unknowns

## The Unknowns Map (AUDIT / PREFLIGHT)

```markdown
## Unknowns Map — {tema | Issue #N}

### The map, restated (known knowns)
- {≤10 bullets of what the input actually pins down}
- ⚠️ {contradiction or vagueness, flagged inline}

### Findings

| ID | Quadrant | Finding | Cost if ignored | Resolution |
|---|---|---|---|---|
| U1 | Unknown unknown | {what the territory demands that the map never mentions} | {blast radius: rework scope, prod risk} | answer / prototype / spike / accept-risk |
| U2 | Known unknown | {undecided question} | … | answer (interview) |
| U3 | Unknown known | {taste criterion detected} | … | prototype (variations) |

### Interview trail (if run)
- Q1: {question} → {answer} → {what it changed}

### The rewritten brief
> {The sharper prompt/Brief the user should have written — incorporates every
> resolved unknown, names the accepted risks, and scopes out what the
> interview eliminated. Copy-paste ready.}
```

Order findings by cost-if-ignored, highest first. An empty quadrant is reported as empty — silence reads as "not checked".

## PREFLIGHT verdict block

Appended after the Unknowns Map:

```markdown
### Preflight verdict: {READY | HOLD}

READY — no open architecture-changing unknowns. Safe for `pipeline:ready` /
unattended pickup. {n} accepted risks recorded above.

HOLD — blocking unknowns: {U1, U4}. Do NOT promote to `pipeline:ready`.
Next: answer the blockers (offer: post U-items as one Issue comment) or
resolve via prototype/spike, then re-run preflight.
```

The verdict considers only **architecture-changing** unknowns as blockers.
Cosmetic or deferrable unknowns are recorded as accepted risks, never blockers.

## QUIZ report

```markdown
## Change report — {PR #N | branch}

**Context** — {why this change exists, in the codebase's terms}
**Intuition** — {why this shape and not the obvious alternative}
**What changed** — {file-by-file, one line each}
**Interactions** — {how the change meets existing code paths — the part the diff doesn't show}

## Quiz ({k} questions — answer before merging)

Q1. {behavioral: "what happens when …?"}
Q2. {edge case: "if X arrives twice, …?"}
Q3. {interaction: "which existing flow also hits this path?"}
…
```

Grading: per question, ✅/❌ + one-line explanation for every ❌. Failed topics
get ONE re-quiz round (new questions, same topics). Verdict: clean pass →
"safe to merge from a comprehension standpoint"; anything else → "don't merge yet".

## TEACH structure

```markdown
## {Domain} — your unknown unknowns

**Mental model** — {one screen: how practitioners think about it}
**The vocabulary that steers** — {5-10 terms, each with the dial it controls}
**What good looks like** — {…} · **Failure smells** — {…}
**Three prompts you can now write**
1. "{…}"
2. "{…}"
3. "{…}"

Next: want {2-3} contrasting variations over your actual {artifact} to react to?
```
