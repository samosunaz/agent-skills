---
name: feature-dossier
description: "Create or update a living feature dossier — enriched markdown + Mermaid diagrams/flows — in a versioned product catalog. For big features that change product behavior; reference for humans and AI before future modifications. Output language configurable (--lang, default es). Trigger on 'feature dossier', 'documentar feature', 'documenta esta funcionalidad', 'dossier de feature', 'catálogo de features', 'actualizar dossier'."
allowed-tools: Bash(git log *) Bash(git diff *) Bash(git rev-parse *) Bash(git branch *) Bash(git remote *) Bash(gh pr *) Bash(gh issue *) Bash(gh release *) Bash(date *) Bash(awk *) Bash(test *) Bash(ls *) Read Write Edit Glob Agent AskUserQuestion
---

# Feature Dossier

Generate and maintain a **living dossier** per platform capability: enriched markdown with Mermaid diagrams/flows, `file:line` evidence, and an append-only changelog. Versioned in a central catalog in the product repo. The canonical reference for humans **and** AI before modifying something that already exists.

> **Spoke**: [feature-dossier.md](../../../reference/feature-dossier.md) — storage/catalog conventions, document template, changelog spine, section→diagram mapping. Read it before drafting.
> **Diagram standard**: [mermaid-style.md](../../../reference/mermaid-style.md) (hub `/samuel:mermaid`) — shapes, emoji vocabulary, classDef palette, gotchas. Read it before drawing.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- Date: !`date '+%Y-%m-%d' 2>/dev/null || echo "NO_DATE"`
- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Recent releases: !`gh release list --limit 5 2>/dev/null || echo "No releases"`
- Catalog present: !`test -d docs/product && echo "present" || echo "absent"`
- Existing dossiers: !`ls docs/product 2>/dev/null || echo "NO_CATALOG"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`

## Critical Rules

1. **As-is, not as-planned.** The dossier reflects the code that exists TODAY. The changelog records how it got there. If the RFC proposed X and Y shipped, document Y.
2. **Evidence-based.** Every code claim cites `file:line`. No vague claims.
3. **Living, never overwrite.** In UPDATE mode: revise sections in place AND **add** a changelog row. Never silently delete history.
4. **One dossier per capability**, not per PR. Multiple PRs of one capability → changelog entries of the same dossier.
5. **Forced checkpoint.** Present the draft (and, in UPDATE, which sections changed) and wait for approval before writing.
6. **Output language** — the dossier *artifact* is written in the `--lang` language (default `es` for the team; `en` available). These skill instructions are English; the written dossier follows `--lang`. Technical terms (APIs, components, paths) stay English regardless. Screenshots: Claude can't generate them — insert `[Screenshot: …]` placeholders and ask the user.
7. **Diagrams earn their place.** Mermaid for flows >3 steps, lifecycles (states), multi-service interaction, and the data model. Don't diagram the trivial.

## Invocation

```
/samuel:feature-dossier "Multi-gateway payments"     (by name)
/samuel:feature-dossier ENG-123                       (by tracker item)
/samuel:feature-dossier --pr 470                      (by PR)
/samuel:feature-dossier --lang en                     (output in English; default es)
/samuel:feature-dossier --root docs/capabilities      (override catalog root)
/samuel:feature-dossier                               (interactive / uses task-context if a feature is active)
```

---

## Phase 1: SCOPE

**Goal**: fix capability, mode, catalog root, and output language.

1. **Identify the capability** from the argument (name, `ENG-XXX`, `--pr`) or, if empty, from `Feature` in task-context; if nothing, ask the user.
2. **Resolve the catalog root.** Default `docs/product/`. If `Catalog present` = `absent`, Glob for an existing convention (`docs/`, `documentation/`) and confirm the root with the user before creating anything. Respect `--root`.
3. **Resolve the output language** from `--lang` (default `es`).
4. **Derive the slug** (kebab-case; reuse `feature_slug` if feature-aware) and **detect mode**:
   - Read/Glob `<root>/<slug>/README.md`. Exists → **UPDATE**. Doesn't → **CREATE**.
   - Before assuming CREATE, compare against `Existing dossiers` in case the capability is already documented under another slug; if matched, offer UPDATE.
5. **Confirm with the user**: capability, slug, root, mode (CREATE/UPDATE), output language. **WAIT.**

---

## Phase 2: GATHER

**Goal**: gather the real state of the capability. Priority: pipeline artifacts → git → live code.

1. **Pipeline artifacts** (in `{feature_dir}` — `docs/features/<slug>/`): read the **Brief + Executor Plan** of the work item (Issue body via `gh issue view`), `spec.md`/`research.md` if present, `implementation-notes.md` (D/V/T/Q decisions), `validation.md`. Also recorded decisions (Issue comments) and any ADRs in `docs/decisions/` touching this capability.
2. **Git / releases**: `gh pr view`, `git log` of the feature range, `gh release view` if applicable — for key PRs and the changelog.
3. **Live code — sub-agents** (retrievers, not analysts; spawn ALL in a **single message**, `model: "sonnet"`):

   **Round 1 — locators:**

   | `subagent_type` | Job |
   |-----------------|-----|
   | `component-locator` | WHERE the capability's components live (`file:line`) |
   | `pattern-scanner` | Related patterns/usages, tests that cover it |

   **Round 2 — analyzer** (only if Round 1 warrants it): `implementation-analyzer` over the most relevant files to understand HOW it works.

   **Wait for ALL agents** before synthesizing. In UPDATE, focus on what changed since the last changelog row.

---

## Phase 3: SYNTHESIZE

**Goal**: build/update the dossier from the spoke template, written in the `--lang` language.

- Apply the **Dossier Template** from `reference/feature-dossier.md`. Omit non-applicable conditional sections (Data model, States, Screenshots).
- **What it offers / Features**: user perspective. **Architecture / References**: `file:line`.
- **Mermaid diagrams** per `reference/mermaid-style.md` — shape + emoji + `classDef` for every node, palette lines copied only for the classes used, gotchas respected. The section→diagram mapping is in the dossier spoke.
- **"How to modify this capability"**: the future-reference payload — where to touch, what to break-carefully, what tests cover it. Write it so a future agent can start here.
- **UPDATE**: revise affected sections in place, **add** a changelog row, bump `Version` + `Updated`. Don't rewrite intact sections.

---

## Phase 4: CHECKPOINT & WRITE

1. **Present the full draft.** In UPDATE, explicitly list *which sections changed* and the new changelog row. Ask for screenshots if UI. **WAIT for approval.** Iterate on feedback.
2. **Write the dossier** with `Write` to `<root>/<slug>/README.md` (CREATE) or `Edit`/`Write` (UPDATE).
3. **Update the catalog** `<root>/README.md` (`Edit` the table, or `Write` if absent): the capability's row with status, 1-line summary, date, link. Newest-touched first.

---

## Phase 5: PROPAGATE (repo-level discoverability)

**Goal**: make the capability discoverable from the repo's front doors. Principle: **link, don't duplicate** — README/CLAUDE.md get a short pointer to the dossier; the dossier stays the single source of truth.

Evaluate whether the capability is significant enough to touch:

| Doc | When to propose an update | What to propose |
|-----|---------------------------|-----------------|
| **root `README.md`** | Has a features/capabilities list or "what the product does" section | A one-line entry + link to the dossier (`docs/product/<slug>/`). Skip if the README is minimal boilerplate. |
| **root `CLAUDE.md`** (and nested module `CLAUDE.md`) | The capability introduces architecture, modules, conventions, or an area future agents must know | A concise pointer to the dossier in the relevant section. **Highest value** for the "reference for AI" goal. |

Rules:
- **Forced checkpoint**: present the exact proposed diffs and **wait for approval**. Never auto-edit README/CLAUDE.md. Apply only the approved ones.
- **Don't duplicate**: a one-line pointer, not copied sections. If CLAUDE.md already mentions the capability, update the link/status instead of adding another entry.
- **Clean skip**: if N/A, report `No repo-level updates — checked README.md, CLAUDE.md`.
- Complements (doesn't duplicate) `/samuel:validate` Step 4 doc-impact: that detects impact of *code changes* (APIs, env, schema); this ensures *capability discoverability* from the front-door docs.

---

## Final output

```
Dossier [created | updated]: <root>/<slug>/README.md   (lang: es|en)
Catalog updated: <root>/README.md
Repo-level docs: [README.md ✎ | CLAUDE.md ✎ | no changes]
Status: [🟢 Live | 🟡 Beta | ...]   Version: [vX.Y]

Pending:
- [ ] Add real screenshots (if UI)
- [ ] Commit the dossier + docs (rides the task PR)
```

> This skill does **not** commit or PR — it leaves the files ready for the user to version (or run `/samuel:create-atomic-commit`). The dossier rides the task's PR.

---

## Distinction (don't confuse)

| Skill | Output | Life |
|-------|--------|------|
| **feature-dossier** (this) | Canonical technical+product reference, with diagrams | **Lives and accretes** in the repo |
| `feature-brief` | Audience-tailored one-pager | Published to a comms surface, archived |
| `codebase-documentation` | Read-only research feeding an in-flight feature | Transient (`research.md`) |

## Pipeline Hook

It's **on-demand** and also **suggested at close**: `/samuel:validate` (Step 4, doc impact) and `/samuel:done` recommend creating/updating the dossier when a change alters product behavior. It never runs on its own — the user always triggers it.

**Storage (don't confuse with the task's feature_dir):** the dossier lives in the **global product catalog** (`docs/product/<slug>/README.md`), versioned by *capability* — NOT in `docs/features/<task-slug>/` (that's task process: research/journal/validation). A capability evolves across many tasks; that's why it's global. Full map: `reference/tracker.md` (Storage map).

**Close:**
- **Interactive**: you run the dossier on the task branch → it's **committed and rides the same PR** (code + docs merge atomically), along with the README/CLAUDE.md pointer.
- **Autonomous (`/samuel:conductor --ship`)**: the dossier is heavy (sub-agents + Mermaid), so it does NOT run in the run; `/samuel:done` opens a **follow-up Issue** `type:docs` linked to the PR so it isn't lost.

## Gotchas

_Add a line each time Claude trips on something._

- It's CANONICAL and living: in UPDATE never rewrite the changelog or delete intact sections — revise in place and add a row.
- One capability = one dossier. If you arrive with a PR and the capability already exists, it's UPDATE, not a new file.
- The dossier lives in the PRODUCT repo, not in this skills repo.
- Confirm the catalog root before writing — `docs/product/` is default, but the repo may have another convention.
- **Output language follows `--lang` (default `es`); the skill instructions are English.** Technical terms stay English in any language.
- Screenshots: Claude doesn't generate them. Insert `[Screenshot: ...]` placeholders and ask the user.
- Sub-agents are retrievers — synthesis (and every `file:line`) happens in the main context.
- No commit/PR — leaves files ready. Versioning is the user's call (rides the task PR).
- README/CLAUDE.md (Phase 5): link, don't duplicate. A pointer to the dossier, never copied sections — the dossier is the single source of truth. Always with a checkpoint: never auto-edit those docs.
