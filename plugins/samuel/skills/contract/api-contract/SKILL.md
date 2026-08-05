---
name: api-contract
description: "Document an endpoint the backend built, for the client(s) that consume it — web frontend and/or native mobile (iOS/Android). Emits TS + Swift/Kotlin types. Output is an inline copy-paste block by default. Trigger on 'api contract', 'contrato api', 'documentar endpoint', 'contract for frontend/mobile'."
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git status *) Bash(git config *) Bash(git merge-base *) Bash(awk *) Bash(grep *) Bash(gh issue *) Read Grep Glob Agent AskUserQuestion
---

# API Contract

Generate a structured API contract: what the backend built, for the **client(s)** that consume it — web frontend and/or native mobile (iOS/Android). Routes, validations, response shapes, and **native types** (TypeScript + Swift/Kotlin). Output is **agent-to-agent and inline by default** (a fenced copy-paste block for the client agent); persisting to GitHub is opt-in.

**Direction:** `backend → web | mobile`. Counterpart: `/samuel:api-request` (client → backend).

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Git user: !`git config user.name 2>/dev/null || echo "unknown"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Merge base: !`git merge-base origin/main HEAD 2>/dev/null || echo "NO_BASE"`
- Files changed: !`git diff --name-only origin/main..HEAD 2>/dev/null || echo ""`

## Pre-requisites

Read as needed:
- `../../reference/contract-templates.md` — templates (full + compact), platform axis, type generation, size heuristic, file patterns
- `../../reference/github-operations.md` — only if the user opts to persist

## Process

### 1) DETECT

- **Item**: from Context (`item`) > branch > ask. Optional.
- **Backend repo**: verify this is a backend (Laravel: `artisan`/`composer.json` `laravel/framework`; Node: `express`/`@nestjs/*`). If a client repo is detected, suggest `/samuel:api-request` instead.
- **Consumers**: who will consume this — `web`, `mobile`, or `both`. Resolve: `--consumers` flag → else ask **"¿Quién consume este contrato? web / mobile / ambos"**. This decides which native types to emit (TS / Swift+Kotlin / both).
- **API changes**: use "Files changed" from Context (filter with the backend globs in `contract-templates.md`). If none, ask which endpoints to document — the user may be documenting an existing API, not a diff.

### 2) ANALYZE

Spawn agents in a **single message** (all sonnet):

| `subagent_type` | Task |
|---|---|
| `implementation-analyzer` | Read each modified controller/resource/request. Extract: routes, methods, request validation rules, response shape, error handling, status codes. |
| `implementation-analyzer` | Read modified migrations and enums. Extract: new/changed fields, types, defaults, nullable status. |

If a diff is available (not documenting an existing API), also identify: new endpoints, modified response shapes (fields added/removed/changed), new validations, new error responses, semantic changes (a field's meaning changed).

**Wait for ALL agents before proceeding.**

### 3) SIZE — pick format (both inline)

Apply the heuristic in `contract-templates.md`:

- **< 4** → **compact** inline block.
- **≥ 4** → **full** inline contract.

No persistence yet.

### 4) GENERATE (inline)

Build from the **Backend → Client Contract** template in `contract-templates.md`.

- Every field in every table has type **and** nullability **and** description. No `any`/`mixed` unless truly dynamic.
- **Client Types** — generate ONLY for the resolved consumers: TypeScript (web), Swift `struct` + Kotlin `data class` (mobile). Mark `Optional`/nullable **exactly** as the API behaves — a wrong non-null crashes native clients.
- Monetary values: state the unit (centavos/cents). Dates: ISO 8601 + timezone. Enums: list every value (stable order — they map to native enums).
- Migration notes only for changes; omit for fully new endpoints. **Flag breaking changes**, and when `mobile`/`both`, call out whether old app versions break (they can't be force-updated).
- Client-side logic: only if the backend returns raw data needing non-trivial processing. Response examples: realistic domain data, not lorem ipsum.

Present the block **inline, fenced for copy-paste**. Then: "Revisa el contrato. ¿Cambios? (OK / editar)" — **WAIT.**

### 5) PERSIST (opt-in)

Ask once: **"¿Lo dejo en el chat o lo guardo en GitHub? (chat / guardar)"**. Only on "guardar": `gh issue comment {item}` with the block, or a new Issue `API Contract: {name}` if none.

Close with: `Contrato {inline | issue #N} · consumers {web|mobile|both} · {N} endpoints, {N} campos · el/los agente(s) cliente pueden consumirlo directamente.`

## Gotchas

_Add a line each time Claude trips on something._

- Default is **chat/inline** — do NOT comment on the Issue unless the user explicitly opts in at step 5.
- Nullability is not cosmetic for mobile — Swift/Kotlin crash on a null where the contract said non-null. Read the actual Resource/serializer, don't guess from the migration.
- Form Request / validator rules are the source of truth for validations, not controller comments.
- Enum values: read the actual Enum class, not the migration column type.
- Response examples must match the actual Resource output — read the Resource file.
- Breaking changes with a mobile consumer are higher-stakes than web — old app versions persist; prefer additive changes or a versioned endpoint.
- If no API-relevant files in the diff, don't assume nothing to document — the user may want an existing endpoint documented.
