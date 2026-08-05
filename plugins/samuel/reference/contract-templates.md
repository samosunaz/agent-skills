# Contract Templates

Templates for cross-layer API contracts between the **backend** and its **clients** (`web` frontend and native `mobile` — iOS/Android). Output is agent-to-agent: structured, machine-readable, no prose.

Two directions, two skills:

| Skill | Direction | Producer → Consumer |
|---|---|---|
| `/samuel:api-contract` | `backend → web \| mobile` | Backend documents an endpoint it built, for the client(s) that consume it |
| `/samuel:api-request` | `web \| mobile → backend` | A client specs an endpoint it needs from the backend |

## Inline-first principle

**Default output is an inline, fenced copy-paste block in the chat** — the human pastes it into the other agent's session. Persisting to GitHub (Issue comment) is **opt-in**, asked once at the end. The size heuristic below chooses **compact vs full format**, not chat-vs-document — both are inline.

## Platform axis (web vs mobile)

Every contract/spec is scoped to one or more **consumers**. Mobile is native (iOS/Android), not a mobile web view — that changes what matters:

| Concern | `web` (frontend) | `mobile` (iOS/Android nativo) |
|---|---|---|
| **Backward compat** | fixes deploy on both sides together | **old app versions live in the wild** — never remove/retype existing fields; additive only, version the endpoint on breaking change |
| **Nullability** | TS optional `?` is forgiving | Swift `Optional` / Kotlin nullable — a wrongly non-null field **crashes** the app. State null vs non-null exactly |
| **Types** | TypeScript interface | Swift `struct` + Kotlin `data class` — enums MUST map to native enums (list every value, stable order) |
| **Pagination** | offset acceptable | prefer cursor / infinite-scroll for long lists |
| **Payload size** | tolerant | minimize (mobile data + battery); return only needed fields |
| **Images** | responsive `srcset` | explicit size variants (thumb/full) + pixel dimensions |
| **Dates / money** | ISO 8601 / centavos | same — but state timezone handling explicitly |
| **Errors** | toast / inline | same + offline / no-connection state |
| **Push / deep-links** | rarely relevant | note trigger events + payload params if the flow uses them |

When `consumers = both`, generate types for **both** web and mobile and call out any field where nullability/backward-compat matters more for mobile.

## Backend → Client Contract

Full format for medium/large scope changes.

```markdown
# API Contract: {Feature Name}

**Item**: {#N | TASK-id | N/A}
**Branch**: {branch}
**Date**: {ISO date}
**Consumers**: {web | mobile | both}
**Scope**: {brief — "2 new endpoints, 5 modified fields" | "breaking change in Order response"}

---

## Endpoints

### {N}. {Endpoint Title}

**`{METHOD} {path}`** — {new | modified | context-only}

{One-line purpose.}

#### Request

\`\`\`json
{example body — realistic domain data, not lorem ipsum}
\`\`\`

| Field | Type | Required | Description |
|---|---|---|---|
| `field` | `string` | yes | {description} |

#### Response ({status})

\`\`\`json
{example response}
\`\`\`

| Field | Type | Nullable | Description |
|---|---|---|---|
| `field` | `string` | no | {description} |

#### Validations

- `field`: {rules — e.g., required|string|max:255, min:1}

#### Errors

| Code | Condition | Body |
|---|---|---|
| 422 | {cause} | `{ "message": "...", "errors": { "field": ["..."] } }` |
| 404 | {cause} | `{ "message": "..." }` |
| 403 | {cause} | `{ "message": "..." }` |

---

## Client Types

{Generate ONLY for the listed consumers.}

### TypeScript (web)

\`\`\`typescript
{interfaces — one per resource/entity; strict types, no Record<string, any>}
\`\`\`

### Swift (mobile — iOS)

\`\`\`swift
{struct(s) conforming to Codable; Optional only where the field is truly nullable}
\`\`\`

### Kotlin (mobile — Android)

\`\`\`kotlin
{data class(es); nullable (?) only where truly nullable; enum class for enums}
\`\`\`

## Client-Side Logic

{Only if the backend returns raw data needing non-trivial client processing. Pseudocode or snippet. Omit for standard CRUD.}

## Values & Conventions

{Monetary unit (centavos/cents), date format (ISO 8601 + timezone), enum values, pagination style. Only what's relevant to THIS contract.}

## Migration Notes

{Per-field: what changed, defaults, backward compatibility. Flag breaking changes.}

- `field_name` — **NEW**: {type}, default `{value}`. {compat note}
- `field_name` — **CHANGED**: was {old}, now {new}. **BREAKING**: {what breaks} {— if mobile is a consumer, flag whether old app versions break}
- `field_name` — **REMOVED**: {what to use instead}
```

## Client → Backend Spec

Full format for medium/large scope requests.

```markdown
# API Spec: {Feature Name}

**Item**: {#N | TASK-id | N/A}
**Branch**: {branch}
**Date**: {ISO date}
**Platform**: {web | mobile}
**Priority**: {high | medium | low}
**Requester**: {git user}

---

## User Flow

{Drawn to the diagram standard — `mermaid-style.md`, same `reference/` dir.}

\`\`\`mermaid
sequenceDiagram
    autonumber
    actor U as 👤 {User}
    participant C as {🖥️ | 📱} {Client}
    participant B as ⚙️ {Backend}

    U->>C: {action}
    C->>B: {API call}
    B-->>C: {response}
    C-->>U: {result}
\`\`\`

{Or flowchart for non-linear flows:}

\`\`\`mermaid
flowchart TD
    A(["👤 {start}"]):::actor --> B{"condition"}:::decision
    B -->|yes| C(["✅ {action}"]):::ok
    B -->|no| D(["❌ {action}"]):::fail
    classDef actor fill:#e0f2fe,stroke:#0284c7,color:#0c4a6e
    classDef decision fill:#f1f5f9,stroke:#475569,color:#0f172a
    classDef ok fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef fail fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
\`\`\`

## Data Requirements

| Data | Current Source | Sufficient? | What's Missing |
|---|---|---|---|
| {data point} | `GET /endpoint` | yes / no | {gap} |
| {data point} | not available | no | {full requirement} |

## Proposed Endpoints

### {METHOD} {suggested path}

**Purpose**: {what this enables in the UI/screen}

**Ideal Request**:
\`\`\`json
{what the client wants to send}
\`\`\`

**Ideal Response**:
\`\`\`json
{what the client needs back — field-level, with types}
\`\`\`

**Error Handling**:
| Error | Client Behavior |
|---|---|
| 404 | {how the client displays it} |
| 422 | {field-level error rendering} |
| 500 | {fallback / offline behavior} |

## Platform Concerns

{Only the relevant rows from the Platform axis table. For mobile: pagination style, payload size, image variants, backward-compat with old app versions, offline handling. For web: usually omit unless notable.}

## Edge Cases

- {scenario}: {expected backend behavior}
- {scenario}: {expected backend behavior}

## Client Context

{WHY the shape matters — where this data renders.}

- **web** → ASCII component sketch:

\`\`\`
┌──────────────────────────┐
│  {component name}        │
│  ┌────────┐ ┌────────┐  │
│  │ field_a │ │ field_b │  │
│  └────────┘ └────────┘  │
│  {field_c}: {value}      │
└──────────────────────────┘
\`\`\`

- **mobile** → screen + section description: "Pantalla {X}, sección {Y}: lista con {field_a} como título, {field_b} como subtítulo, {field_c} como badge."

## Open Questions

- {decision the backend needs to make — auth rules, rate limits, pagination strategy}
- {constraint the client doesn't know about}
```

## Compact Formats (inline, small changes)

Score < 4 → emit a compact block instead of the full template.

### Backend → Client (compact)

```markdown
**Contract Update** — {#N} · consumers: {web | mobile | both}
Branch: `{branch}`

**`{METHOD} {path}`** — {new | modified}
{one-line description}

| Campo | Tipo | Null | Nota |
|---|---|---|---|
| `field` | `type` | no | {NEW / CHANGED / REMOVED}: {detail} |

{TS interface snippet — add Swift/Kotlin if mobile consumes it}

Migration: {one-liner on backward compat — flag if it breaks old mobile versions}
```

### Client → Backend (compact)

```markdown
**API Request** — {#N} · platform: {web | mobile}
Branch: `{branch}`

Necesito: {one-line description}

**`{METHOD} {suggested path}`**
Request: `{ field: type, ... }`
Response: `{ field: type, ... }`

Contexto: {where this renders and why the shape matters}
```

## Size Heuristic

Score to choose **compact vs full** (both inline).

| Signal | Weight |
|---|---|
| New endpoint | +3 |
| Endpoint removed | +3 |
| Breaking change (field removed, type changed, semantic change) | +2 per field |
| New field in response | +1 per field |
| New field in request | +1 per field |
| New validation rule | +0.5 |
| New error code | +0.5 |

| Score | Format |
|---|---|
| < 4 | **Compact** inline block |
| ≥ 4 | **Full** inline template (all relevant sections) |

For `api-request`, score on: endpoints needed (+3 each), data points (+1 each), flow branches (+1 each).

## File Detection Patterns

### Backend

- **Laravel** (`artisan`, `composer.json` with `laravel/framework`): `routes/api.php`, `app/Http/Controllers/**/*.php`, `app/Http/Resources/**/*.php`, `app/Http/Requests/**/*.php`, `database/migrations/**/*.php`, `app/Enums/**/*.php`
- **Node** (`package.json` with `express`/`@nestjs/*`/`fastify`): `**/routes/**`, `**/*.controller.ts`, `**/dto/**`, `**/entities/**`

### Web frontend

- `src/components/**`, `src/app/**`, `src/pages/**`
- `**/*.service.ts`, `**/*.store.ts`, `**/api/**`
- `**/types/**/*.ts`, `**/interfaces/**/*.ts`

### Mobile (native)

- **iOS**: `*.xcodeproj` / `Package.swift`, `**/*.swift`, `**/Models/**`, `**/Networking/**`, `**/Services/**`
- **Android**: `build.gradle(.kts)`, `**/*.kt`, `**/data/**`, `**/network/**`, `**/model/**`

### Auto-detection

| Indicator | Client type |
|---|---|
| `package.json` with `angular` / `react` / `next` / `vue` / `nuxt` | web frontend |
| `*.xcodeproj`, `Package.swift`, or `*.swift` present | mobile (iOS) |
| `build.gradle(.kts)` + `*.kt` (with an app module) | mobile (Android) |
| `artisan` / `composer.json` `laravel/framework` | Laravel backend |

## Optional Persistence

Only when the user opts in (default is chat-only). See `reference/github-operations.md`:

Comment the block on the related Issue (`gh issue comment {item}`), or open a new `pipeline:triage` Issue titled `API Spec:` / `API Contract:` if none exists.

Link the persisted artifact back to the work item so the other agent finds it.
