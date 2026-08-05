# Implementation Notes — Schema & Lifecycle

The `implementation-notes.md` is a **living journal** kept alongside `validation.md` (and any `spec.md`/`research.md`) inside `{feature_dir}/` — `docs/features/<slug>/`. It captures the small, high-context choices made during implementation that don't reach the threshold of a recorded **Issue decision**.

It is a **plain committed file** — created and edited with `Write`/`Edit`, committed on the feature branch so a resuming (or headless) session reads it directly. Created by `/samuel:implement` on entry, populated proactively during execution, read and sealed by `/samuel:validate`, synthesized into the PR body by `/samuel:done`.

## Why this exists

An **Issue decision** (a `gh issue comment`) only fires on hard STOP events (plan-reality mismatch, constitution violation). Smaller things get lost:

- Ambiguities in the spec/plan that were resolved silently.
- Alternatives considered but rejected.
- Open questions you want confirmed before merge.
- Sub-threshold deviations.

This file is the surface for all of them — one place per feature, append-only during implementation, sealed at validation. For a solo dev it doubles as the "what was I thinking" log when you come back days later.

## Doc-level state lives in the body callout

The journal is self-contained: its status and counters live in a **blockquote callout** at the top of the body (not in any external tag/frontmatter — there's nothing to wipe it). This callout is the canonical source.

```markdown
# Implementation Notes: {feature_slug}

> **Item**: #{item}  ·  **Plan**: {Issue body plan section}  ·  **Constitution**: {x.y.z or none}
> **Counters**: D:{n} V:{n} T:{n} Q:{n_total} (open_remaining: {n_open})
> **Status**: living | sealed
> **Flags**: {has-open-questions, has-deviations — or "none"}
```

Parsing recipe (for skills):

- `Counters`: regex `D:(\d+) V:(\d+) T:(\d+) Q:(\d+) \(open_remaining: (\d+)\)`.
- `Status`: `living` while implementing, `sealed` after a passing `/samuel:validate`. **Canonical** — no external tag.
- `Flags`: `has-open-questions` while any `Q-NNN` is `open`; `has-deviations` if any applied `V-NNN` exists. Recompute at phase close.
- `Item`, `Plan`, `Constitution` are static after creation.

## Section layout

Fixed four-section layout. Append-only within each section. Never delete entries — supersede them by marking `Status` and adding a follow-up.

```markdown
## Design Decisions
## Deviations
## Tradeoffs
## Open Questions
```

## Entry schema

Each entry has a **stable ID** and fixed fields. The ID prefix encodes the type:

| Prefix | Section | Meaning |
|---|---|---|
| `D-NNN` | Design Decisions | Choice made where the spec/plan was ambiguous |
| `V-NNN` | Deviations | Departure from the plan (sub-threshold or escalated) |
| `T-NNN` | Tradeoffs | Alternatives considered, rationale for choice |
| `Q-NNN` | Open Questions | Something to confirm or revise |

IDs are sequential within their section, zero-padded to 3 digits, never reused.

### Common fields (all entry types)

| Field | Required | Notes |
|---|---|---|
| `Phase` | yes | `setup`, `foundational`, `us1`, `us2`, `us3`, `polish` |
| `Step` | yes | the plan Step / subtask id |
| `When` | yes | ISO date (`2026-05-18`) |
| `Files` | when applicable | List of `path:line` references |
| `Status` | yes | See per-type values below |
| `Affects` | `D`/`V`: yes · `T`/`Q`: optional | Issues outside this one the entry constrains — `#N` list (+ propagation outcome once the blast-radius step runs), or `none` |

### Design Decisions (`D-NNN`)

```markdown
### D-001 · {short title}
- **Phase**: us1
- **Step**: 2
- **When**: 2026-05-13
- **Files**: `src/sort.ts:34`
- **Status**: applied | superseded
- **Affects**: {#N list · outcome | none}
- **Context**: {what was ambiguous in the spec/plan}
- **Decision**: {what you chose}
- **Why**: {reasoning}
```

### Deviations (`V-NNN`)

```markdown
### V-001 · {short title}
- **Phase**: foundational
- **Step**: 1
- **When**: 2026-05-13
- **Files**: `db/migrations/20260513-menu.sql`
- **Status**: applied | reverted
- **Linked decision**: {Issue comment URL, when escalated} | none
- **Affects**: {#N list · outcome | none}
- **Plan said**: {what the plan specified}
- **Did**: {what you actually did}
- **Why**: {reason for departure}
```

> **Escalation rule**: if the deviation is a hard STOP (plan-reality mismatch, constitution violation), `/samuel:implement` also records an **Issue decision** (`gh issue comment`). Record its ref under `Linked decision`. Otherwise leave as `none`.
>
> **Blast-radius rule**: a non-`none` `Affects` triggers `/samuel:implement`'s blast-radius step (e.1) — sibling/dependent issues get assessed and, with approval, an `Upstream decision` comment each (`github-operations.md` § Blast radius). Record the per-issue outcome back on the same line (e.g. `#45 (commented, demoted), #46 (unaffected)`).

### Tradeoffs (`T-NNN`)

```markdown
### T-001 · {short title}
- **Phase**: us2
- **Step**: 4
- **When**: 2026-05-14
- **Files**: `src/cache.ts`
- **Status**: applied | superseded
- **Chose**: {selected approach}
- **Considered**: {alternatives, one per line, with rejection reason}
- **Why**: {reasoning for the chosen one}
```

### Open Questions (`Q-NNN`)

```markdown
### Q-001 · {question phrased as a question}
- **Phase**: us3
- **Step**: 6
- **When**: 2026-05-14
- **Spec ref**: {spec.md FR-007 / Brief AC}
- **Question**: {full question}
- **Impact if wrong**: {what breaks if assumed wrong}
- **Suggested resolution**: {your best guess}
- **Blocking**: yes | no
- **Status**: open
- **Answer**: {filled in later; flip Status to "answered" or "deferred" when set}
```

Open Question lifecycle:
- `open` → freshly raised, awaiting answer.
- `answered` → `Answer` filled. Becomes input for follow-up code if needed.
- `deferred` → current behavior accepted, won't block merge. Must have rationale in `Answer`.

`open_remaining` in the callout reflects `Status: open` entries — count them.

## Lifecycle

```
/samuel:implement (on entry)
  → Write the stub file at {feature_dir}/implementation-notes.md  →  Status: living

/samuel:implement (per phase)
  → append D/V/T/Q entries proactively to the body
  → at phase close: re-render the callout (counters + flags), commit the file with the step

/samuel:validate (Step 0)
  → parse Q-NNN with Status: open; present them; answer/defer before sealing
  → cross-check V-NNN against recorded Issue decisions

/samuel:validate (on PASS / PASS WITH NOTES, no Blocking:yes open Qs)
  → Edit the callout: Status: sealed, drop has-open-questions

/samuel:done
  → journal is a primary source for the PR body synthesis
```

## Stub on create

```markdown
# Implementation Notes: {feature_slug}

> **Item**: #{item}  ·  **Plan**: {Issue body plan section}  ·  **Constitution**: {x.y.z or none}
> **Counters**: D:0 V:0 T:0 Q:0 (open_remaining: 0)
> **Status**: living
> **Flags**: none

Living journal kept during `/samuel:implement`. Sealed by `/samuel:validate`. Schema: `plugins/samuel/reference/implementation-notes.md`.

## Design Decisions

_None yet._

## Deviations

_None yet._

## Tradeoffs

_None yet._

## Open Questions

_None yet._
```

## Separation from a tracker decision

| Concern | Where it lives |
|---|---|
| Spec/plan ambiguities resolved silently | Journal — `D-NNN` |
| Alternatives considered, rejected | Journal — `T-NNN` |
| Open questions to confirm | Journal — `Q-NNN` |
| Sub-threshold deviations | Journal — `V-NNN`, `Linked decision: none` |
| Plan-reality mismatch (hard STOP) | **Issue decision** AND `V-NNN` referencing it |
| Constitution violation (hard STOP) | **Issue decision** AND `V-NNN` referencing it |
| Cross-issue impact of a decision | `Affects` line on the entry AND an `Upstream decision` comment on each affected issue (`github-operations.md` § Blast radius) |

No duplication: the journal is the notebook; the **Issue decision** (a comment) is the durable, visible record. Escalated deviations live in both, with a clear pointer.

## Filtering recipes (for humans + agents)

The journal is an on-disk markdown file under the feature dir — grep is the discovery surface:

| Goal | Command |
|---|---|
| All journals across features | `grep -rl '^# Implementation Notes:' docs/features 2>/dev/null` |
| Features awaiting confirmation | `grep -rl 'has-open-questions' docs/features 2>/dev/null` |
| Features with deviations | `grep -rl 'has-deviations' docs/features 2>/dev/null` |
| One feature's journal | `{feature_dir}/implementation-notes.md` |

## Gotchas

_Add a line each time Claude trips on something._

- The journal is a **plain committed file** — `Write` the stub, `Edit` to append.
- Doc-level state (Status, Counters, Flags) lives in the **body callout** — it is canonical. There is no external tag.
- Commit the journal on the feature branch as you go, so a resuming/headless session reads it. An uncommitted journal is invisible to the next session.
- Entry IDs are append-only. Obsolete entry → set `Status: superseded` and add a new one; never renumber.
- Open questions with `Blocking: yes` + `Status: open` are hard blockers for `/samuel:validate` — don't seal or PASS until answered/deferred.
- `Linked decision` is mandatory for any deviation that triggered a tracker decision. Without it, the journal and the decision drift apart.
- Re-render the callout at phase close (counters + flags) — a stale callout misleads the morning review.
- `Affects: none` is an explicit claim ("I checked, nothing outside this issue"), not a default to skip. A non-`none` value without a recorded propagation outcome means the blast-radius step never ran — finish it.
