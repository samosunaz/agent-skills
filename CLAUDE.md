# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) and Codex when working with code in this repository. `AGENTS.md` is a symlink to this file — single source of truth for instructions.

## What This Is

A skill registry for AI coding agents (Claude Code + Codex) for Samuel Osuna's personal/indie hacker projects. Organized as a plugin monorepo. Skills are folders of instructions and resources that agents load dynamically for specialized workflows. No build system, no tests — this is a content repo of markdown-based skill definitions.

## Multi-Platform Support

This repo targets **Claude Code** and **OpenAI Codex** from one shared skill source, and conforms to [**Agent Plugins 1.0.0**](https://github.com/agentplugins/agent-plugins-spec) — the portable package standard both clients read (ADR 0005). Each plugin under `plugins/<name>/` carries a portable root manifest plus one client-specific file; the `SKILL.md` files are shared verbatim.

| Aspect | Claude Code | Codex |
|---|---|---|
| Discovery | `.claude-plugin/marketplace.json` | `.agents/plugins/marketplace.json` |
| Plugin manifest | `plugins/*/.claude-plugin/plugin.json` → symlink to `plugins/*/plugin.json` | `plugins/*/.codex-plugin/plugin.json` |
| Skill source | Shared `SKILL.md` format | Shared `SKILL.md` format |
| Agents | `agents/*.md` per plugin | Not supported |
| Instructions | `CLAUDE.md` | `AGENTS.md` (symlink → `CLAUDE.md`) |

Adding or renaming a skill needs no sync step — the plugin dir is the only source. Adding a **plugin** touches five files: both marketplaces, its root manifest, its Codex manifest, and `release-please-config.json` `extra-files` (a manifest missing from `extra-files` freezes that plugin's version silently; `scripts/validate-plugins.sh` fails the pre-commit hook on that gap and on version drift).

Codex ignores Claude-specific frontmatter fields (`allowed-tools`, `model`). Skills that shell out with `${CLAUDE_PLUGIN_ROOT}` (`repo-audit`, `create-review-md`) resolve only under Claude Code — Codex needs the path passed another way.

**Three manifest files, two contents.** `plugin.json` at the plugin root is the portable one (§5): a **closed** field set — `$schema`, `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `extensions`, and nothing else. `.claude-plugin/plugin.json` is a **symlink to `../plugin.json`**, so Claude Code and a conformant client never drift. Codex needs two fields the closed schema forbids, so `.codex-plugin/plugin.json` stays a separate regular file:

| Field | `plugin.json` (portable) | `.codex-plugin/plugin.json` |
|---|---|---|
| `skills` | not permitted — discovery is positional (§7.1) | **string** path (`"./skills/"`) |
| `interface` | not permitted | required block: `displayName`, `shortDescription`, `longDescription`, `developerName`, `category`, `capabilities`, `defaultPrompt` |

`scripts/check-agent-plugins.sh` gates the four rules a client enforces at load time (root manifest, skill depth, path containment, resolvable relative references) in the pre-commit hook.

The Codex marketplace entry needs `policy.installation` **and** `policy.authentication` (`ON_INSTALL` \| `ON_USE`) plus `category` on every plugin — the validator mirrors the workspace ingestion schema. Its `source.path` is relative to the **repo root**, not to the marketplace file: `./plugins/<name>`, never `../../plugins/<name>`. Spec: [`plugin-json-spec.md`](https://github.com/openai/codex/blob/main/codex-rs/skills/src/assets/samples/plugin-creator/references/plugin-json-spec.md).

Codex's optional companion files are `.mcp.json` (`mcpServers`) and `.app.json` (`apps`) — this repo declares neither, and `hooks` is rejected outright by the validator. There is no OpenAPI document anywhere in the plugin contract; the only YAML is a per-skill `<skill>/agents/openai.yaml` carrying Codex-side presentation metadata (`interface.display_name`, `interface.short_description`, optional `icon_small`/`icon_large`/`brand_color`/`default_prompt`, `policy.allow_implicit_invocation`, `dependencies.tools`). It is optional and unused here; the `agents/` directory at plugin root is Claude sub-agents, unrelated.

## Repository Structure

```
agent-skills/
├── CLAUDE.md                     # Instructions source of truth
├── AGENTS.md                     # Symlink → CLAUDE.md (Codex entry point)
├── .claude-plugin/
│   └── marketplace.json          # Claude Code marketplace
├── .agents/
│   └── plugins/marketplace.json  # Codex marketplace
├── plugins/
│   └── samuel/                   # Personal dev workflow skills
│       ├── plugin.json           # Portable manifest (Agent Plugins 1.0.0)
│       ├── .claude-plugin/plugin.json   # Symlink → ../plugin.json
│       ├── .codex-plugin/plugin.json    # Codex-only: skills string + interface
│       ├── agents/               # Sub-agent definitions (3)
│       ├── reference/            # Shared reference docs (tracker, github-operations, task-context, implementation-notes, plan-templates)
│       └── skills/               # 33 skills, one dir each (flat — §7.1)
├── template/                     # SKILL.md + CONSTITUTION.md templates
└── docs/decisions/               # ADRs (repo-level decisions)
```

Skills are flat because §7.1 discovers only the immediate children of `skills/`. The **groups** they used to sit in survive as documentation — the section headings below, and the tables in `README.md`:

| Group | Skills |
|---|---|
| pipeline | codebase-documentation, spec, plan, refine-plan, analyze, implement, validate |
| git | create-atomic-commit, remove-slop, pr-self-audit, address-pr-comments, session-handoff |
| workflow | roadmap, kickoff, next, start-task, conductor, waves, wave-prep, done, progress, retro, team-orchestrate |
| product | feature-dossier, mermaid |
| design | motion-brief |
| contract | api-request, api-contract |
| meta | find-unknowns, repo-audit, create-review-md, create-constitution, update-constitution |

## Skill Anatomy

Every skill lives in `plugins/samuel/skills/<name>/` with a required `SKILL.md` containing YAML frontmatter (`name`, `description`, `allowed-tools`) and agent instructions. Optional subdirectories: `scripts/`, `references/`, `assets/`. Nothing below that first level is discovered, so a skill never nests another skill.

Skills are namespaced by plugin: `/samuel:commit`, `/samuel:plan`, etc.

Sub-agent definitions live in `plugins/samuel/agents/`. Claude Code discovers them automatically when the plugin is installed. Codex does not use agents.

Register new plugins in **both** marketplaces (`.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json`). Use `template/SKILL.md` as starting point for new skills.

## Core Pipeline: R → [S] → P → [A] → I → V

A spec-driven pipeline with two optional gates (`[S]`pec and `[A]`nalyze) — bring them in when they de-risk the work, skip them for bugs and small features. State flows through `.claude/task-context.md` frontmatter (`repo`, `item`, `phase`, `feature_slug`, `feature_dir`, `spec_required`, `constitution`); see `plugins/samuel/reference/task-context.md`. Per-repo config (`repo` for `gh`) lives in `.claude/samuel.md` — see `plugins/samuel/reference/tracker.md`. Committed feature artifacts (journal, validation) live under `feature_dir`: `docs/features/<slug>/`.

> **Flow diagrams**: `plugins/samuel/reference/pipeline.md` has Mermaid diagrams for entry points, the full pipeline, the phase state machine, the journal lifecycle, the autonomous conductor, and feature-dir artifacts. Read it before driving or extending the pipeline.

1. **`/samuel:codebase-documentation`** (Research) — Parallel sub-agent codebase exploration. Documents findings without suggesting changes. Writes `research.md` inside a feature; sets `phase: research`.
2. **`/samuel:spec`** (optional) — Generate a Spec (User Stories P1/P2/P3, FR-### MUST, SC-### measurable, Edge Cases) with up to 5 clarifications. Runs only when `spec_required: true`. WHAT/WHY, not HOW.
3. **`/samuel:plan`** — 5-phase interactive planning with forced human checkpoints. Reads the spec when present + runs a Constitution Check when `CONSTITUTION.md` exists. Writes the **Brief + Executor Plan** to the GitHub Issue body; see `reference/plan-templates.md`. Waves-aware: declares native `blockedBy` edges to sibling issues at write time (`reference/github-operations.md` § Issue dependencies).
4. **`/samuel:refine-plan`** — Surgical edits to existing plans based on feedback.
5. **`/samuel:analyze`** (optional, read-only) — Cross-artifact consistency check (spec/research/plan/tasks/constitution). Severity-tagged findings, no auto-edits. Recommended for multi-story or constitution-sensitive features.
6. **`/samuel:implement`** — Sequential task execution with human verification between phases. Keeps a **living Implementation Notes journal** (`implementation-notes.md`: D/V/T/Q entries) for sub-threshold choices. Monitors context for FIC handoff triggers.
7. **`/samuel:validate`** — Verifies implementation against success criteria, resolves the journal's open questions, **seals** the journal, and runs documentation impact analysis. Runs an optional repo-scoped **`security_scan`** (secret-scan/SAST command in `.claude/samuel.md`) alongside the gate — a non-zero exit is a FAIL, an absent field an explicit SKIP.

### The Implementation Notes journal

`/samuel:implement` opens a per-feature journal — a **plain committed file** at `{feature_dir}/implementation-notes.md` — that captures choices below the decision threshold: silently-resolved ambiguities (`D-NNN`), rejected alternatives (`T-NNN`), small deviations (`V-NNN`, linked to a recorded decision when escalated), and open questions (`Q-NNN`). Escalated decisions are recorded as GitHub Issue comments. `/samuel:validate` resolves open questions and seals it; `/samuel:done` synthesizes it into the PR body. Schema: `plugins/samuel/reference/implementation-notes.md`.

## Autonomous Runs: the Conductor

- **`/samuel:conductor`** — Drives the pipeline unattended phase-by-phase for cloud/overnight runs (`claude -p` + `/goal`; droplet or `caffeinate`). Two ceilings: **review mode** (default) runs up to `validate` then HARD-STOPS before any PR; **ship mode** (`--ship`) drives through `validate`, runs the gate, and opens a **draft PR** via `/samuel:done --draft` — the human marks ready & merges. Can **bootstrap from an item id**: `/samuel:conductor 42 --ship` = item → branch → implement → validate → draft PR (the headless SSH loop). SAFETY GATE: isolated worktree **or a CI runner on a non-main branch** (equivalent isolation), never a local `main`; review never pushes, ship opens only a draft (never merges/ready/closes). Records every assumption to the Issue + journal + handoff. Recipe + allowlist + multi-item loop: `plugins/samuel/skills/conductor/references/autonomous-run.md`. **Automatic heartbeat** — GitHub fires the loop on a schedule / `issues:labeled` (closing the manual-trigger gap), opening a draft PR via a committed workflow template (`plugins/samuel/skills/conductor/assets/conductor.yml`): `plugins/samuel/reference/automated-trigger.md`. **Run accounting** — every run captures cost/turns/tokens per item (`--max-budget-usd` + `stream-json`), enforces a per-item and a per-sweep budget cap, and posts one run report to a rolling `conductor:log` issue shared by CI and SSH launches; cost-per-accepted-change is computed at the morning review.

## Meta Skills

- **`/samuel:find-unknowns`** — Map-vs-territory audit: surface known unknowns, unknown knowns, and unknown unknowns before they get expensive. 4 modes: **audit** (an idea/feature), **preflight** (Issue N — Brief+Plan vs today's territory, verdict READY/HOLD), **teach** (`--teach «domain»`), **quiz** (`--quiz [PR]` — comprehension gate before merging agent-authored work). Standalone, no task-context required. Wired into the pipeline via **observable-heuristic seams** (canonical table: `reference/pipeline.md` § The unknowns seam): *suggested* in interactive mode, *mandatory* in autonomous mode — `pipeline:ready` promotion and a drifted pickup require a preflight `READY`; the quiz is human-only. Never gate on self-reported confidence.
- **`/samuel:repo-audit`** — Substrate drift detector for consumer repos: a deterministic script (samuel.md, gh, labels, `.claude` gitignored, CLAUDE.md; optional constitution/REVIEW.md/conductor-CI/release-please/squash) + a semantic pass over CLAUDE.md. Report-only; Issue filing is opt-in.
- **`/samuel:create-review-md`** — Generate a consumer repo's root `REVIEW.md` (schema v1, `template/REVIEW.md`): deterministic evidence digest (repo type, gate signals, CI job names, **solo review history** — committed `validation.md` verdicts, journal V-/Q- entries, pr-self-audit comments on merged PRs) + a semantic pass that derives the 5 override sections citing evidence per bullet (checkpoint-only citation table; the file itself carries no tracker refs). Existing `REVIEW.md` → `--check` conformance report, never a silent overwrite. Serves the three review surfaces: `/samuel:validate` Step 2.5, `/samuel:pr-self-audit`, native `/code-review`.

## Optional Governance

- **`/samuel:create-constitution`** / **`/samuel:update-constitution`** — Ratify and amend a repo-root `CONSTITUTION.md` (3-5 non-negotiable principles, semver, Sync Impact Report). Entirely optional — the pipeline's Constitution Checks degrade to no-ops when the file is absent.

## Workflow Skills

- **`/samuel:roadmap`** — Product Ownership / **discovery** session (upstream of everything): reads the product's real state (dossiers, vision, open/closed issues, ADRs) and proposes prioritized **bets** — what to build next and *why* — persisted as `roadmap:now/next/later` issues. Committing a bet promotes it to `pipeline:triage` → `/samuel:plan`; multi-item commits declare native `blockedBy` edges at promotion (waves-aware). `roadmap:*` (discovery) and `pipeline:*` (delivery) are mutually exclusive on an issue. Mindset + lenses: `plugins/samuel/reference/product-ownership.md`.
- **`/samuel:kickoff`** — Initialize a new project: vision doc, MVP scope, tech decisions, writes `.claude/samuel.md` (repo config), and seeds initial Issues.
- **`/samuel:next`** — Pull the next prioritized item (GitHub Issues).
- **`/samuel:start-task`** — Pick an item, create branch/worktree, bootstrap `.claude/task-context.md` (`repo`/`item`) + feature dir.
- **`/samuel:done`** — Open a PR (`Closes #N`, `--draft` for autonomous runs) synthesizing the journal, mark the item done, cleanup. At close it scans the journal for **durable knowledge** to promote to its proper home (storage map in `reference/tracker.md`): ADRs (`docs/decisions/`), dossiers (`docs/product/`), **CLAUDE.md** operating learnings (project-wide gotchas/config/conventions), **README.md** human getting-started updates (install/config/commands/capabilities; structure + philosophy in `reference/readme-guidelines.md`), and a **REVIEW.md** bullet when the cycle surfaced a repo-wide review rule (cited to a validation/journal finding; ≤30-line budget — replace a weaker rule rather than grow the file) — forced checkpoint, never auto-edit; autonomous runs only list candidates. `CONSTITUTION.md` is **detect-and-route** (amendments carry semver + Sync Impact Report → `/samuel:update-constitution`), never edited at close. It also proposes the two **promo markers** — `promo:blog` for user-facing changes (what shipped) and `promo:bip` for building-in-public material (how it was built: a hard number, a system change, an autonomous run, a reversal — the label carries an angle comment so the story survives the close). Metadata, applied in every mode.
- **`/samuel:progress`** — Personal dashboard: item status, velocity, blockers (GitHub Issues).
- **`/samuel:retro`** — Personal retrospective from GitHub Issues/PRs + git history.
- **`/samuel:team-orchestrate`** — Spawn multi-session Claude Code agent teams (review/debug/feature/research archetypes). Use for parallel work streams that need peer messaging and persistent sessions. Different from `/samuel:codebase-documentation`, which is a one-shot subagent fan-out.
- **`/samuel:waves`** — **Attended multi-issue wave coordinator** over Orca: computes execution waves from GitHub's **native `blockedBy` graph** (`reference/github-operations.md` § Issue dependencies), dispatches one Orca worktree + worker per unblocked `pipeline:ready` issue (Codex default; claude-conductor variant for taste/hard items), supervises to **draft PRs**, and the **human merge releases the next wave** from fresh `origin/main`. Two human gates (WAVE PLAN approval, merge-as-release); authority ceiling per ADR 0004; run report to `conductor:log` (ADR 0003). Boundary: `/samuel:conductor` is the per-item engine it dispatches (never reimplements); `/samuel:team-orchestrate` is Claude peers that converse — wave workers are isolated implementers. Anti-double-scheduler: an Orca automation may invoke waves; waves never schedules itself. Attended-only until #29 (TTL). Protocol: `plugins/samuel/skills/waves/references/wave-protocol.md`.
- **`/samuel:wave-prep`** — **Backlog → wave-set preparer**, the retro sweep waves' passive INTAKE assumes already happened: sweeps open `pipeline:*` issues (or `label:`/`milestone:`/explicit set), classifies wave-ready / plan-missing / excluded, infers inter-issue dependencies from the Executor Plans (explicit refs > artifact sequencing > file overlap — overlap is a **soft conflict**, reported but never declared as an edge), and after the **EDGE PLAN checkpoint** (with cycle check — GitHub accepts cycles; waves would deadlock) declares the missing native `blockedBy` edges read-then-add via the adapter. Routes at close: dispatch `/samuel:waves <set>` / `/samuel:plan N` for the unplanned. Writes edges only — never labels, comments, or dispatch; `--dry-run` writes nothing. Complements birth-time declaration (`plan` Phase 4, `roadmap` multi-item): prep writes the graph, waves reads it.

## Product Documentation

- **`/samuel:feature-dossier`** — Create/update a **living feature dossier** for a platform capability: enriched markdown + Mermaid diagrams/flows, evidence `file:line`, and an append-only changelog. Persists to a versioned **product catalog** (`docs/product/` in the product repo, organized by capability — distinct from `docs/features/<task-slug>/` task artifacts; see the Storage map in `reference/tracker.md`) with a master index, and propagates a one-line pointer to the root `README.md`/`CLAUDE.md` when the capability is significant (link, don't duplicate) — reference for humans **and** AI before future modifications. On-demand, and recommended at close by `/samuel:validate` (doc-impact) and `/samuel:done` when a change alters product behavior. Distinct from `feature-brief` (audience-tailored comms, archived) and `codebase-documentation` (transient research). Template + catalog format + section→diagram mapping: `plugins/samuel/reference/feature-dossier.md`.
- **`/samuel:mermaid`** — The **diagram style standard**: semantic shapes + one-emoji vocabulary + `classDef` palette (triple encoding, so a diagram survives dark mode, colorblind readers, and renderers that drop styles). Single home for HOW every Mermaid diagram is drawn — dossiers, contracts, RFCs, Issue/PR bodies. Every diagram-emitting skill points here instead of defining its own rules: `plugins/samuel/reference/mermaid-style.md`. `%%{init}%%`/`themeVariables` are NOT blessed (GitHub forces its own theme).

## Contract Skills

The backend ↔ client API handoff, in both directions. Agent-to-agent output, **inline by default** (a fenced copy-paste block to paste into the other agent's session); persisting to the tracker is opt-in. Client axis is `web` (frontend) **or** `mobile` (native iOS/Android) — mobile changes what matters (nullability, backward-compat with old app versions, payload size, native types). Templates + platform axis + size heuristic: `plugins/samuel/reference/contract-templates.md`.

- **`/samuel:api-request`** — `web | mobile → backend`. A client specs an endpoint it needs: flow (mermaid), data requirements, proposed endpoints, error→UI mapping, client context (web ASCII / mobile screen), open questions. Uses `component-locator`/`pattern-scanner`.
- **`/samuel:api-contract`** — `backend → web | mobile`. The backend documents an endpoint it built: routes, validations, response shapes, and **native types** (TypeScript + Swift/Kotlin for the resolved consumers), migration/breaking-change notes. Uses `implementation-analyzer`.

## Git Skills

- **`/samuel:create-atomic-commit`** — Atomic conventional commits, no AI attribution, requires user approval.
- **`/samuel:pr-self-audit`** — High-signal PR review: bugs, security, logic errors. Inline GitHub comments with suggestion blocks.
- **`/samuel:address-pr-comments`** — Author side of the PR review gate: fetch feedback since the last pass (incremental, ID-based markers), verify each finding against the code, triage → fix → reply → resolve, close the pass with ONE `Resolution` comment. Primary scenario: addressing human review comments on agent-authored draft PRs (conductor/waves).
- **`/samuel:session-handoff`** — Context compaction (FIC) for long sessions.
- **`/samuel:remove-slop`** — Remove AI-generated code slop from the current branch. Checks dependency manifests for reinvented wheels and hallucinated imports.

## Sub-Agent Architecture

Agent definitions live in `plugins/samuel/agents/`. Claude Code discovers them automatically.

| `subagent_type` | Model | Purpose |
|-----------------|-------|---------|
| `component-locator` | sonnet | Find files/components relevant to a feature |
| `implementation-analyzer` | sonnet | Analyze implementation details of specific components |
| `pattern-scanner` | sonnet | Find similar implementations and usage patterns |
| `implementation-reviewer` | opus | Independent adversarial review of a diff vs spec/AC (`validate` Step 2.5) |

### Key rules

- Spawn ALL initial agents in a **single message** for parallelism.
- Use the `model` specified in the table above (sonnet for the retrieval agents; `implementation-reviewer` is opus).
- Wait for ALL agents before synthesizing results.
- The retrieval agents are retrievers, not analysts — synthesis happens in the main context. **Exception**: `implementation-reviewer` is a deliberate analyst/critic — it returns an independent verdict, not raw findings — the plugin's one adversarial agent, used only by `/samuel:validate` Step 2.5.

## Source of Truth: GitHub Issues + PRs (single tracker)

Work is tracked in **GitHub Issues + PRs** via the `gh` CLI (**no GitHub MCP**) — the only SoT (ADR 0002, `docs/decisions/0002-single-tracker-github.md`). Built for unattended/cloud sessions and CI-gated merge. A work item is one Issue whose body serves three reading speeds: a ten-second **TL;DR**, the human **Brief**, and the self-contained **Executor Plan** (markers `<!-- samuel:brief -->` / `<!-- samuel:plan -->`); status is `pipeline:*` labels; a PR `Closes #N`; decisions are Issue comments. Hub + storage map: `plugins/samuel/reference/tracker.md`. Adapter: `reference/github-operations.md`. The SSH-alias origin breaks owner/repo parsing → always use the stored `repo` + `gh repo set-default`, **never parse `git remote`**.


The committed layer (always files, never tracker state):
- **Plan format** — TL;DR + Brief + Executor Plan (`reference/plan-templates.md`), in the Issue body.
- **Journal** — `{feature_dir}/implementation-notes.md`, a **plain committed file** edited with Read/Edit/Write.
- **Validation** — `{feature_dir}/validation.md`, committed.
- **Acceptance Criteria / DoD** — Brief checkboxes in the Issue body.

`feature_dir`: `docs/features/<slug>/`. Always derive it from `task-context.md`, never re-type it.

## Critical Patterns

- **Forced human checkpoints**: Every pipeline phase requires explicit user approval before advancing, unless the run's **autonomy level** says otherwise — `interactive` (the default) asks and waits, `attended-auto` takes the obvious default at a *soft* gate and announces it in one line, `autonomous` records and proceeds. Hard stops bind at all three: plan-reality mismatch, constitution violation, red gate, incomplete DoD, orphaned context, any outward action. Levels, the gate-by-gate table, and the recording contract: `plugins/samuel/reference/autonomy.md`. **How** a checkpoint is rendered is one convention: `AskUserQuestion` (or `ExitPlanMode` for plan approval) when the runtime exposes it, numbered-text fallback when it doesn't — `plugins/samuel/reference/interaction-tools.md`. Every `SKILL.md` either carries the standard phrase or is listed in `reference/checkpoint-exclusions.txt` with a reason (the coverage check is the complement of that file, never a grep for gate phrases). Autonomous runs invoke no interaction tool at all — they record and proceed.
- **Route, don't print a menu**: a skill that produces an artifact asks where it goes next in the same turn, while the context that produced it is alive (`/samuel:plan` Phase 5 § ROUTE). Answering "now" means *dispatching* the next skill, not telling the user to type it.
- **Every Issue and PR opens with a TL;DR**: four lines — *What / Why / Caveat* + metadata chips — read in ten seconds, written **last** as a compression of the finished body (`plugins/samuel/reference/github-operations.md` § TL;DR). The rest of the artifact is agent-facing by design; without the block the only way to triage is to read it at agent volume, which makes the human the bottleneck in a pipeline built to run without one. `Caveat: None` is a valid and frequent answer — a manufactured hazard trains the reader to skip the line.
- **Evidence-based references**: Always cite `file:line` — no vague claims about the codebase. On GitHub surfaces (Issue bodies/comments, PR bodies, review findings) the citation is a **SHA permalink** when the commit is on the remote (`plugins/samuel/reference/github-operations.md` § Linking).
- **`#` is for GitHub artifacts only**: never enumerate findings/criteria/lists with `#{n}` on GitHub surfaces (it autolinks to Issues/PRs). Element-initial IDs instead — `B1`/`I1`/`N1`, `AC1`, `U1` (see § Enumeration IDs in `plugins/samuel/reference/github-operations.md`).
- **`gh --jq '.[0].x'` on an empty list prints the string `null`**, not an empty string — in shell, branch on `case "$V" in ""|null)`, never on `[ -n "$V" ]`. Every find-or-create recipe in this repo (`conductor:log`, labels, PR lookup) depends on getting this right. **String interpolation defeats that guard**: `.[0]|"#\(.number)"` on an empty list yields `"#null null"`, which passes any `null` check — write `.[0]//empty|"…"` so the pipeline emits nothing at all.
- **`grep -c` prints `0` *and* exits 1** when nothing matches, so the reflexive `n=$(grep -c … || echo 0)` yields the two-line value `"0\n0"` and every later `[ "$n" -eq … ]` dies with `integer expected`. Write `n=$(grep -c … 2>/dev/null); n=${n:-0}` — the rescue is what breaks it, not the absence of one. Same shape as the `--jq` trap above: the failure is in the guard, and it fails loudly enough to look like the real bug.
- **Plan-reality mismatch**: Stop execution immediately, present the mismatch, and ask the user how to proceed. Never silently work around it.
- **Blast radius**: a decision recorded mid-issue that constrains sibling/dependent issues gets propagated — impact map, human checkpoint, one `Upstream decision` comment per affected issue (`plugins/samuel/reference/github-operations.md` § Blast radius). Unattended runs never cross-post.
- **FIC (Frequent Intentional Compaction)**: At high context usage, run `/session-handoff create` and recommend a new session.

## Skill Authoring Guidelines

Best practices for writing skills in this repo.

### Architecture: Hub-and-Spoke

SKILL.md is a **compact hub** (~80-120 lines) that dispatches to spoke files for detail. The hub defines the process (intent-based steps), the spokes contain templates, payloads, and format specs.

**Reference files live in `plugins/samuel/reference/`** and are referenced directly from SKILL.md. Each skill references only the specific sub-files it needs. One source of truth, update once.

### Description: Concise with Trigger Words

```yaml
# Good — action-oriented, key triggers only
description: "Review a PR for bugs, security, and logic errors. High-signal only. Trigger on 'review pr', 'code review', 'revisar pr'."
```

### Intent Over Prescription

Don't micromanage what Claude already knows. Declare the goal and constraints.

### Shell Commands for Runtime Context

Use `!` backtick pattern to inject runtime data before Claude reads the prompt.

**Every command MUST have `2>/dev/null || echo "FALLBACK"` to prevent shell runner errors.** Exception: `pwd` and `date` never fail — no fallback needed.

**NO shell expansion in inline `!` commands.** The permission checker rejects any inline command containing command substitution `$(...)` / backticks, parameter expansion `${v:-X}`, or variables `$VAR` — it fails with `Contains expansion` and the command never runs (a fallback does NOT save it). To read `.claude/task-context.md` frontmatter, use the `$`-free `awk` one-liner documented in `reference/task-context.md` (the awk program is single-quoted, so its `$`/braces never reach the shell). Compound checks that need a value interpolated into a path (e.g. "does `features/<slug>/spec.md` exist?") cannot be expressed `$`-free — do those in the skill body with `Read`/`Glob`, not in `## Context`.

### Gotchas Section (Evolving)

Every skill has a `## Gotchas` section that grows over time. Add a line each time Claude trips on something.

### General Rules

- Every paragraph must justify its token cost in the context window.
- Text for flexible guidance, pseudocode for patterns, scripts for deterministic ops.
- Core instructions in `SKILL.md`, details in `references/`, code in `scripts/`.
- No auxiliary files (READMEs, changelogs) inside skill folders unless essential.
- `allowed-tools` in frontmatter — declare every tool the skill needs.
- **Subagents get no plugin base-dir at runtime** — inject reference content (e.g. a rubric) into the subagent's prompt; a relative path in an agent def won't resolve in the target repo.
- All skills must have `## Gotchas` — starts empty, grows with use.
