---
name: mermaid
description: "Mermaid diagram style standard: semantic shapes + emoji vocabulary + classDef palette. Invoke before authoring any Mermaid diagram (dossier, contract, RFC, Issue/PR). Trigger on 'mermaid', 'diagrama de flujo', 'diagram this', 'estándar mermaid'."
allowed-tools: Read
---

# Mermaid Style Standard

Draw every Mermaid diagram to one visual standard, so any diagram in any repo reads the same: same role → same shape, same emoji, same color. This skill is the standard's home; every diagram-emitting skill defers here instead of defining its own rules.

> **Spoke**: `../../reference/mermaid-style.md` — semantic vocabulary, palette (classDef preamble), per-type recipes, surfaces, gotchas. **Read it before drafting any diagram.**

## When to diagram

Diagrams earn their place: flows >3 steps, branching logic, lifecycles, multi-service interaction, non-trivial data models. Don't diagram the trivial — a 3-step linear flow is a numbered list.

## Type selection

| Intent | Type |
|--------|------|
| User flow with decisions / branches | `flowchart TD` |
| Component / service architecture | `flowchart LR` + `subgraph` |
| Cross-service interaction (request/response) | `sequenceDiagram` |
| Entity lifecycle (states) | `stateDiagram-v2` |
| Data model / relationships | `erDiagram` |

## Process

1. **Pick the type** from the intent table. One diagram per flow — never a mega-diagram.
2. **Draft with the semantic vocabulary** (spoke § Semantic vocabulary): shape + one emoji per node; the text must work without the emoji.
3. **Apply the palette** (spoke § The palette): copy only the `classDef` lines the diagram uses, assign with `:::`, every `fill` paired with `color`.
4. **Validate against the gotchas** (spoke § Gotchas): quoted labels, no lowercase `end`, declared participants, `-v2`.
5. **Surface check**: GitHub renders everything; other surfaces may drop the colors — never fork the diagram, semantics survive via shape + emoji.

## Consumers

Skills that emit diagrams reference this standard instead of embedding style rules: `/samuel:feature-dossier` (dossier diagrams) · `/samuel:api-request` / `/samuel:api-contract` (contract flows). A new skill that emits Mermaid MUST point at `reference/mermaid-style.md` rather than defining its own conventions.

## Gotchas

_Add a line each time Claude trips on something._

- The palette is classDef-only — `%%{init}%%`/`themeVariables` are not blessed (GitHub forces its own theme).
- The empirical base is a render canvas run against GitHub (a dedicated render-canvas PR against GitHub, branch `test/mermaid-render-check`). Re-run it against GitHub before changing any rendering assumption in the spoke.
- No checkpoint line here on purpose: this skill is reference material, listed in `checkpoint-exclusions.txt`.
