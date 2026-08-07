---
name: api-request
description: "Spec an endpoint a client needs from the backend, from the web frontend OR native mobile (iOS/Android) perspective. Output is an inline copy-paste block by default. Trigger on 'api request', 'i need an endpoint', 'request endpoint', 'spec for backend', 'new endpoint from front/mobile'."
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git status *) Bash(git config *) Bash(git merge-base *) Bash(awk *) Bash(grep *) Bash(gh issue *) Read Grep Glob Agent AskUserQuestion
---

# API Request

Generate a structured API spec: what a **client** — web frontend **or** native mobile (iOS/Android) — needs from the backend. Endpoints, data shapes, flows, error→UI mapping. Output is **agent-to-agent and inline by default** (a fenced copy-paste block for the backend agent); persisting to GitHub is opt-in.

**Direction:** `web | mobile → backend`. Counterpart: `/samuel:api-contract` (backend → client).

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Git user: !`git config user.name 2>/dev/null || echo "unknown"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Merge base: !`git merge-base origin/main HEAD 2>/dev/null || echo "NO_BASE"`
- Files changed: !`git diff --name-only origin/main..HEAD 2>/dev/null || echo ""`

## Pre-requisites

Read as needed:
- `../../reference/contract-templates.md` — templates (full + compact), platform axis, size heuristic, file patterns
- `../../reference/github-operations.md` — only if the user opts to persist

## Process

### 1) DETECT

- **Item**: from Context (`item`) > branch > ask. Optional — a spec can exist with no tracked item.
- **Requesting platform**: `web` or `mobile` (native iOS/Android). Resolve: `--platform` flag → repo markers (`package.json` with a web framework = web; `*.xcodeproj`/`Package.swift`/`build.gradle` + `*.swift`/`*.kt` = mobile) → else ask **"From web or mobile?"**. This drives type generation and platform concerns downstream.
- **What's being built**: if files changed, spawn a `component-locator` (sonnet) to identify components/screens being modified, the services/stores that make API calls, and existing calls in the changed files. If speccing before any code exists, skip the agent and ask **"Which flow or screen are you building?"**

### 2) GATHER

**From code** (if files changed): what the UI renders, what calls already exist, what data is missing.

**From user** (confirm/supplement, keep it tight — present inferences instead of asking blank):

> "For the spec, confirm:
> 1. **Flow** — describe it (or confirm what I infer from the code)
> 2. **Missing data** — what don't you have yet?
> 3. **Priority** — high / medium / low
> 4. **Edge cases** — empty, error, loading, permissions?"

**If platform = mobile**, also probe the mobile-specific concerns from `contract-templates.md` (Platform axis): pagination/infinite-scroll, payload size, image variants, backward compatibility with old app versions, offline handling.

### 3) SIZE — pick format (both inline)

Score: endpoints needed (+3 each), data points (+1 each), flow branches (+1 each).

- **< 4** → **compact** inline block.
- **≥ 4** → **full** inline spec.

No persistence yet — both outputs are copy-paste blocks.

### 4) GENERATE (inline)

Build from the **Client → Backend Spec** template (full or compact) in `contract-templates.md`.

- **Mermaid mandatory** for full scope — `sequenceDiagram` for linear flows, `flowchart` for branching. One focused diagram per flow, drawn to `../../reference/mermaid-style.md` (hub `/samuel:mermaid`).
- Proposed paths follow REST conventions and match existing route patterns (spawn `pattern-scanner` if unsure of the API's structure).
- Response shapes: exact fields with types — be precise, never "all the user data".
- Error handling: map each error to concrete client behavior (toast, inline, redirect, retry, offline).
- **Client Context**: web → ASCII component sketch; mobile → screen + section description. The backend agent needs to see WHY the shape matters.
- Open Questions: genuine unknowns the backend must decide.

Present the block **inline, fenced for copy-paste**. Then: "Review the spec. Changes? (OK / edit)" — **WAIT.**

### 5) PERSIST (opt-in)

Ask once: **"Keep it in the chat, or save it to GitHub? (chat / save)"**. Only on "save": `gh issue comment {item}` with the block, or a new `pipeline:triage` Issue `API Spec: {name}` if none.

Close with: `Spec {inline | issue #N} · platform {web|mobile} · {N} endpoints, {N} data points · the backend agent can consume it directly.`

## Gotchas

_Add a line each time Claude trips on something._

- Default is **chat/inline** — do NOT comment on the Issue unless the user explicitly opts in at step 5.
- Mermaid must be valid — declare every `participant` in sequence diagrams before use.
- Don't propose endpoints that already exist unchanged — spawn `pattern-scanner` to check current routes first if in a full-stack/backend repo.
- ASCII UI sketches: use box-drawing chars (─ │ ┌ ┐ └ ┘), not dashes/pipes.
- Mobile ≠ mobile web — it's native iOS/Android. Ask which platform; the concerns (nullability, backward-compat, payload size) differ from web.
- If the user is in early ideation (no code), skip `component-locator` and go straight to the gather conversation.
