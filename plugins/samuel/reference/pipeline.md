# Pipeline Flows — Reference Diagrams

Visual reference for the `samuel` plugin pipeline. These Mermaid diagrams are the canonical map of how the skills chain, which artifacts each produces, and how the `.claude/task-context.md` `phase` advances. They double as agent documentation — read this before driving the pipeline or building on it.

Bracketed steps `[ ]` are **optional gates** (`spec`, `analyze`). The pipeline degrades gracefully when they — and `CONSTITUTION.md` — are absent.

Related contracts: `tracker.md` (GitHub as SoT), `task-context.md` (frontmatter + phase), `plan-templates.md` (Brief + Executor Plan), `implementation-notes.md` (the journal), `github-operations.md` (the adapter).

## 1. Entry points — where to start

The `feature dir` and `phase` tracking are bootstrapped by `/samuel:start-task`. Without a task there is no `task-context.md`, so skills run **standalone** (write to `docs/research/` loose, no phase). Pick the entry that matches your situation.

```mermaid
flowchart TD
    Start{"Where do I start?"}:::decision
    Start -->|"New project, empty repo"| Kickoff["⚙️ /samuel:kickoff<br/>tracker + vision + MVP + seed items"]:::svc
    Start -->|"Not sure what to build next"| Roadmap["⚙️ /samuel:roadmap<br/>product ownership: propose bets<br/>→ roadmap:now/next/later issues"]:::svc
    Start -->|"Concrete work to build"| Create[("🗂️ capture an item<br/>gh issue create")]:::db
    Start -->|"Just exploring to decide"| Standalone["⚙️ /samuel:codebase-documentation<br/>standalone, no item"]:::svc

    Kickoff --> Next["⚙️ /samuel:next"]:::svc
    Roadmap -->|"commit a bet → promote to pipeline:triage"| Next
    Create --> StartTask["⚙️ /samuel:start-task {item}"]:::svc
    Next --> StartTask
    Standalone -->|"decided what to build"| Create

    StartTask --> Pipeline["📄 Full pipeline (diagram 2)"]:::doc
    classDef decision fill:#f1f5f9,stroke:#475569,color:#0f172a
    classDef svc fill:#e0e7ff,stroke:#4f46e5,color:#312e81
    classDef db fill:#ccfbf1,stroke:#0d9488,color:#134e4a
    classDef doc fill:#f5f5f4,stroke:#78716c,color:#292524
```

> A TL;DR block and a one-line Brief are enough to capture an item — the plan fills the rest later. The TL;DR is the floor, not extra ceremony: an item too vague to state as *what / why / caveat* isn't captured, it's a note to self.

> **Discovery vs delivery.** `/samuel:roadmap` is upstream of everything else: it decides *what* to build (bets as `roadmap:*` issues). Committing a bet promotes it to `pipeline:triage`, where delivery begins. `/samuel:kickoff` seeds the first bets at project start; `/samuel:roadmap` keeps the direction fresh after.

> Anti-pattern: researching and planning at length in standalone mode, then trying to fold it into the pipeline. You end up reconciling loose docs against the feature dir. A one-line task up front avoids it.

## 2. Full pipeline — R → [S] → P → [A] → I → V

The happy path bracketed by `start-task` and `done`. Each skill owns its phase and advances `task-context.md`.

```mermaid
flowchart LR
    next["⚙️ /samuel:next"]:::svc --> start["⚙️ /samuel:start-task<br/>phase: setup"]:::svc
    start --> research["⚙️ /samuel:codebase-documentation<br/>phase: research"]:::svc
    research --> specQ{"spec_required?"}:::decision
    specQ -->|yes| spec["⚙️ /samuel:spec<br/>phase: spec"]:::svc
    specQ -->|no| plan["⚙️ /samuel:plan<br/>phase: plan"]:::svc
    spec --> plan
    plan <--> refine["⚙️ /samuel:refine-plan"]:::svc
    plan --> analyzeQ{"non-trivial<br/>feature?"}:::decision
    analyzeQ -->|yes| analyze["⚙️ /samuel:analyze<br/>read-only"]:::svc
    analyzeQ -->|no| implement["⚙️ /samuel:implement<br/>phase: implement<br/>+ living journal"]:::svc
    analyze --> implement
    implement <--> handoff["⚙️ /samuel:session-handoff<br/>FIC"]:::svc
    implement --> validate["⚙️ /samuel:validate<br/>phase: validate<br/>seals journal"]:::svc
    validate --> done["⚙️ /samuel:done<br/>phase: end<br/>PR + cleanup"]:::svc
    classDef svc fill:#e0e7ff,stroke:#4f46e5,color:#312e81
    classDef decision fill:#f1f5f9,stroke:#475569,color:#0f172a
```

**Minimum happy path** (bug / small feat): `next → start-task → plan → implement → validate → done`.
**Full path** (feature with stakeholders): add `codebase-documentation`, `spec`, and `analyze`.

## 3. Phase state machine

The `phase` key in `.claude/task-context.md` is the single source of truth for where a feature is. This is what `/samuel:conductor` reads to decide the next step.

```mermaid
stateDiagram-v2
    [*] --> setup: /samuel:start-task
    setup --> research: /samuel:codebase-documentation
    research --> spec: /samuel:spec when spec_required
    research --> plan: /samuel:plan otherwise
    spec --> plan: /samuel:plan
    plan --> plan: /samuel:refine-plan
    plan --> implement: /samuel:implement
    implement --> validate: /samuel:validate
    validate --> closed: /samuel:done
    closed --> [*]
    note right of plan
        /samuel:analyze runs here.
        Read-only, does not change phase.
    end note
    classDef ok fill:#dcfce7,stroke:#16a34a,color:#14532d
    class closed ok
```

## 4. Implementation Notes journal lifecycle

`/samuel:implement` opens a living journal for sub-threshold choices that don't reach a recorded Issue decision. `/samuel:validate` resolves and seals it; `/samuel:done` synthesizes it into the PR body. Schema: `implementation-notes.md`.

```mermaid
stateDiagram-v2
    [*] --> living: /samuel:implement Step 0 creates it
    living --> living: append D/V/T/Q entries per phase
    living --> resolving: /samuel:validate Step 0
    resolving --> sealed: PASS, no blocking open Qs, no reviewer Blocker
    resolving --> living: FAIL, back to implement
    sealed --> [*]: /samuel:done reads it for the PR body
    note right of living
        D-NNN decisions, T-NNN tradeoffs,
        V-NNN deviations, Q-NNN open questions.
        Committed file; Status:living in the
        body callout, append-only.
    end note
    classDef ok fill:#dcfce7,stroke:#16a34a,color:#14532d
    class sealed ok
```

## 5. Autonomous run — the conductor

> **Autonomy is a three-level scale, and this section is its top end.** Between the default (`interactive`, ask and wait) and the conductor (`autonomous`, record and continue) sits **`attended-auto`** — the human is present, so the run takes the obvious default and *announces* it instead of asking. It moves eight soft gates across `implement`, `done`, `next`, `start-task` and `session-handoff`; every hard stop below binds at all three levels. Switched on with `autonomy:` in `samuel.md`, never by a skill deciding for itself. Levels, the gate-by-gate table, and the recording contract: `autonomy.md`.

`/samuel:conductor` chains the pipeline unattended for cloud/overnight runs (`claude -p` + `/goal`; droplet or `caffeinate`). It can **bootstrap from an item id**, drives up to `validate`, then branches by mode: **review** (default) hard-stops before any PR; **ship** (`--ship`) runs the gate **and the independent reviewer** (validate Step 2.5), opening a **draft PR** via `/samuel:done --draft` only on `Overall: PASS`. The loop is started manually (`claude -p` over SSH) **or automatically** by GitHub (schedule / `issues:labeled`). Recipe + allowlist + multi-item loop: `skills/workflow/conductor/references/autonomous-run.md`. Automatic trigger (the heartbeat) + workflow template: `automated-trigger.md`.

```mermaid
flowchart TD
    trigger["🌐 Automatic trigger (heartbeat)<br/>GitHub schedule / issues:labeled<br/>conductor.yml"]:::ext --> launch
    manual["👤 Manual: SSH / routine<br/>claude -p"]:::actor --> launch
    launch["⚙️ /samuel:conductor [item] [--ship] + /goal"]:::svc --> gate{"SAFETY GATE<br/>isolated worktree OR CI runner?<br/>not on main?<br/>state or item present?"}:::decision
    gate -->|no| abort["❌ ABORT<br/>print reason, exit"]:::fail
    gate -->|"yes · no state + item given"| boot["⚙️ /samuel:start-task {item}<br/>worktree bootstrap"]:::svc
    boot --> loop
    gate -->|"yes · has state"| loop["⚙️ Read phase →<br/>dispatch next /samuel:* skill"]:::svc
    loop --> fic{"context<br/>pressure?"}:::decision
    fic -->|yes| handoff["⚙️ /samuel:session-handoff create"]:::svc
    handoff --> loop
    fic -->|no| advance{"phase ==<br/>validate?"}:::decision
    advance -->|no| loop
    advance -->|yes| mode{"--ship?"}:::decision
    mode -->|"no — review"| stop["🛑 HARD STOP<br/>final handoff + exit"]:::warn
    mode -->|"yes + Overall: PASS"| ship["⚙️ /samuel:done --draft<br/>open draft PR"]:::svc
    stop --> human1(["👤 Human → /samuel:done, manual PR"]):::actor
    ship --> human2(["👤 Human → review, mark ready, merge"]):::actor
    classDef ext fill:#ffedd5,stroke:#ea580c,color:#7c2d12,stroke-dasharray:5 4
    classDef actor fill:#e0f2fe,stroke:#0284c7,color:#0c4a6e
    classDef svc fill:#e0e7ff,stroke:#4f46e5,color:#312e81
    classDef decision fill:#f1f5f9,stroke:#475569,color:#0f172a
    classDef warn fill:#fef9c3,stroke:#ca8a04,color:#713f12
    classDef fail fill:#fee2e2,stroke:#dc2626,color:#7f1d1d
```

> Every unattended assumption is recorded to the Issue (comment) + the journal + a final handoff — that trail is the morning review. Ship mode opens a PR only on `Overall: PASS` — a red gate **or** a Step 2.5 reviewer Blocker yields a handoff instead.

## 6. Feature dir artifacts — who writes what

The **Brief + Executor Plan** live in the Issue body. The **journal and validation are committed files** under `feature_dir` (`docs/features/<slug>/`), derived from `task-context.md`. `/samuel:done` reads them all to synthesize the PR.

```mermaid
flowchart LR
    subgraph item["Work item — Issue body"]
      brief[("🗂️ Brief, human")]:::db
      plan[("🗂️ Executor Plan<br/>/samuel:plan")]:::db
    end
    research["⚙️ /samuel:codebase-documentation"]:::svc --> r["📄 research.md, optional"]:::doc
    spec["⚙️ /samuel:spec"]:::svc --> s["📄 spec.md, optional"]:::doc
    implement["⚙️ /samuel:implement"]:::svc --> j["📄 implementation-notes.md<br/>journal · committed"]:::doc
    validate["⚙️ /samuel:validate"]:::svc --> v["📄 validation.md<br/>committed"]:::doc
    done["⚙️ /samuel:done"]:::svc -.->|"reads all → PR body · Closes the item"| brief
    done -.-> plan
    done -.-> j
    done -.-> v
    done -.-> r
    classDef svc fill:#e0e7ff,stroke:#4f46e5,color:#312e81
    classDef db fill:#ccfbf1,stroke:#0d9488,color:#134e4a
    classDef doc fill:#f5f5f4,stroke:#78716c,color:#292524
```

## The unknowns seam (`find-unknowns`)

`/samuel:find-unknowns` (map-vs-territory audit — `skills/meta/find-unknowns/`) is wired into the pipeline as **suggested, never auto-run**, and only when an *observable* heuristic fires. The autonomous path is the exception — there the preflight verdict is a hard gate, because nobody is watching the assumption that turns out wrong.

**The asymmetry:**

- **Interactive** — a skill that sees a heuristic fire says so and offers the skill. The dev decides; the offer costs one line of transcript.
- **Autonomous** (under `/samuel:conductor`, or headless CI with `GITHUB_ACTIONS=true`) — the `planned→ready` promotion REQUIRES a preflight verdict `READY`, and a fired drift check at pickup escalates to the same preflight. `HOLD` stops the run with the unknowns recorded.

**The observable heuristics** (canonical list — skills reference this table, never copy it):

| Stage | Heuristic (any one fires) | Interactive | Autonomous |
|---|---|---|---|
| **plan** (`/samuel:plan`) | AC empty or unmeasurable · no Out-of-scope · `TBD` markers in the Brief · the `pattern-scanner` returns nothing for code the plan assumes exists · the `planned→ready` promotion itself | suggest PREFLIGHT before the dev approves promotion | PREFLIGHT **mandatory**; `READY` required to promote |
| **pickup** (`/samuel:start-task`) | the `git log` drift check fired (commits touching plan-named files since the plan was written) | surface the drift + suggest PREFLIGHT | PREFLIGHT **mandatory**; `HOLD` refuses the pickup |
| **implement** (`/samuel:implement`) | plan-reality mismatch · open `Q-NNN` ≥ 3 in the journal | suggest AUDIT before re-planning | (the hard gates already stop the run) |
| **close** (`/samuel:done`) | the PR is agent-authored | suggest `--quiz` to the human | suggest in the output; the agent never runs it |

**Never gate on self-reported confidence.** "I'm 80% sure" is uncalibrated — a model's stated confidence tracks its fluency, not its correctness, and an agent that must clear a confidence bar learns to clear it. Every heuristic above is observable by something other than the agent's opinion of itself: a missing section, a marker string, a `git log` with output, a counter in the journal callout.

## Maintenance

Keep these diagrams in sync with the skills. When a skill changes a phase transition, an artifact path, or a gate condition, update the matching diagram here and the phase table in `task-context.md`.
