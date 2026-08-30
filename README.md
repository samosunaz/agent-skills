# Agent Skills

> A skill registry and sub-agents for **Claude Code** and **OpenAI Codex** from one shared skill source, built for solo and indie hacker projects. A spec-driven pipeline with a living implementation journal, plus git and project-management skills. **GitHub-native** — work items are GitHub Issues carrying a human **Brief** + a self-contained **Executor Plan**, driven by an autonomous conductor that can ship draft PRs for headless/cloud runs. GitHub is the only tracker.

<div align="center">

<!-- x-release-please-start-version -->

![Version](https://img.shields.io/badge/version-4.3.0_-seagreen?style=for-the-badge&logo=git&logoColor=seagreen)

<!-- x-release-please-end -->

[![Agent Plugins](https://img.shields.io/badge/Agent_Plugins-1.0.0-blueviolet.svg?style=for-the-badge&logo=json&logoColor=blueviolet)](https://github.com/agentplugins/agent-plugins-spec)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757.svg?style=for-the-badge&logo=anthropic&logoColor=D97757)](https://claude.ai/code)
[![Codex](https://img.shields.io/badge/Codex-plugin-000000.svg?style=for-the-badge&logo=openai&logoColor=white)](https://developers.openai.com/codex)
[![release-please](https://img.shields.io/badge/release--please-enabled-mediumseagreen.svg?style=for-the-badge&logo=googlecloud&logoColor=mediumseagreen)](https://github.com/googleapis/release-please)
[![License](https://img.shields.io/badge/license-MIT-slateblue.svg?style=for-the-badge&logo=opensourceinitiative&logoColor=slateblue)](LICENSE)

</div>

## Prerequisites

- **[Claude Code](https://claude.ai/code)** or **[Codex](https://developers.openai.com/codex)** — both load this plugin.
- To run the pipeline in a project: the [`gh` CLI](https://cli.github.com), authenticated.
- **[Bun](https://bun.sh)** `1.2.4+` to work on this repo itself.

## Installation

### Claude Code

#### First-time setup

Add the marketplace and install the plugin:

```
/plugin marketplace add samosunaz/agent-skills
/plugin install samuel@samuel-skills
```

#### Per-project setup

Add to `.claude/settings.json` in the target project repo:

```json
{
  "extraKnownMarketplaces": {
    "samuel-skills": {
      "source": {
        "source": "github",
        "repo": "samosunaz/agent-skills"
      }
    }
  },
  "enabledPlugins": {
    "samuel@samuel-skills": true
  }
}
```

Skills are namespaced by plugin: `/samuel:plan`, `/samuel:implement`, `/samuel:create-atomic-commit`, etc.

### OpenAI Codex

Clone or copy this repo and Codex discovers the plugin via `.agents/plugins/marketplace.json`.

Skills use the same `SKILL.md` format — Codex ignores Claude-specific frontmatter fields (`allowed-tools`, `model`). Codex does not load the sub-agents in `plugins/samuel/agents/`, and skills that shell out with `${CLAUDE_PLUGIN_ROOT}` (`repo-audit`, `create-review-md`) need that path passed another way.

## Source of Truth

Each plugin under `plugins/<name>/` is its own source of truth (skills, agents, references).

- Claude Code reads `plugins/*/.claude-plugin/plugin.json`
- Codex reads `plugins/*/.codex-plugin/plugin.json`
- Instructions live in `CLAUDE.md`; `AGENTS.md` is a symlink to it

## Configuration

Per repo where you use the pipeline, pin the repo config in `.claude/samuel.md`:

```markdown
---
tracker: github            # legacy detection key — always github
repo: owner/name           # explicit owner/name for gh
# autonomy: attended-auto  # optional — uncomment to opt in; absent = interactive
---
```

`autonomy` selects how a **soft** checkpoint behaves: `interactive` asks and waits (the default), `attended-auto` takes the obvious default and announces it in one line. Hard stops — plan-reality mismatch, red gate, incomplete DoD, any outward action — keep waiting either way, and `autonomous` is not settable here (it belongs to `/samuel:conductor`). Gate-by-gate table: [`reference/autonomy.md`](plugins/samuel/reference/autonomy.md).

Also run once: `gh repo set-default owner/name` (works behind SSH-alias / multi-account remotes — owner/repo is never parsed from origin). `/samuel:kickoff` and `/samuel:start-task` write this for you. Full model: [`reference/tracker.md`](plugins/samuel/reference/tracker.md).

## Usage

The pipeline runs **work item → plan → implement → validate → PR**:

```
/samuel:roadmap          # decide what to build next: propose bets (roadmap:* issues)
/samuel:kickoff          # new project: config + vision, seed work items
/samuel:next             # pull the next ready item (promote a roadmap bet if none)
/samuel:start-task 42    # branch/worktree + context for issue 42
/samuel:plan             # write the Brief + self-contained Executor Plan
/samuel:implement        # execute, with a living decision journal
/samuel:validate         # run the gate, verify criteria, seal the journal
/samuel:done             # open the PR (Closes #42), promote durable knowledge
```

**Autonomous (headless / droplet)** — drive an item to a draft PR unattended:

```bash
gh repo set-default owner/repo
claude -p "/samuel:conductor 42 --ship /goal ship a draft PR with a green gate; never merge." \
  --max-budget-usd 10 --output-format stream-json --verbose > /tmp/conductor-42.jsonl
```

Every run is capped and accounted for: the last line of the transcript carries `total_cost_usd`, `num_turns` and `usage`, and the run report lands on a rolling `conductor:log` issue. Loop over the `pipeline:ready` inbox to clear a backlog overnight. Recipe + guardrails: [`autonomous-run.md`](plugins/samuel/skills/conductor/references/autonomous-run.md). Or let GitHub fire the loop on its own — on a schedule or when an issue becomes `pipeline:ready` — with the committed workflow template: [`automated-trigger.md`](plugins/samuel/reference/automated-trigger.md).

**Sessions that interrupt each other** *(Claude Code ≥ 2.1.224, macOS/Linux)* — a run no longer has to wait for the next Issue read to learn that the ground moved. A merge tells the sibling worktree to rebase; a decision tells the session executing the invalidated plan to stop; an unattended conductor escalates a blocker and keeps working instead of guessing or stopping. GitHub stays the source of truth and every flow still works when a message is dropped: this is the interrupt, not the record. A message never satisfies a checkpoint, never raises a run's autonomy, and is verified against the Issue before anyone acts on it ([ADR 0006](docs/decisions/0006-cross-session-message-is-an-input-never-a-checkpoint.md)). One trap does need wiring — a headless `claude -p` worker holds every inbound message forever unless it is launched with `--settings '{"crossSessionInbound":"accept"}'`. Addressing, the message contract, and the safety rules: [`cross-session.md`](plugins/samuel/reference/cross-session.md).

## Structure

```
agent-skills/
├── CLAUDE.md                     # Instructions source of truth
├── AGENTS.md                     # Symlink → CLAUDE.md (Codex entry point)
├── .claude-plugin/
│   └── marketplace.json          # Claude Code marketplace (samuel-skills)
├── .agents/
│   └── plugins/marketplace.json  # Codex marketplace (samuel-skills)
├── plugins/
│   └── samuel/                   # Personal dev workflow plugin
│       ├── plugin.json           # Portable manifest (Agent Plugins 1.0.0)
│       ├── .claude-plugin/plugin.json   # Symlink → ../plugin.json
│       ├── .codex-plugin/plugin.json    # Codex-only: skills string + interface
│       ├── agents/               # Sub-agent definitions (3)
│       ├── reference/            # Shared reference docs (tracker, github-operations, task-context, plan-templates, ...)
│       └── skills/               # 35 skills, one directory each
├── template/                     # SKILL.md, CONSTITUTION.md, REVIEW.md, samuel.md templates
└── docs/decisions/               # ADRs (repo-level decisions)
```

The plugin conforms to [Agent Plugins 1.0.0](https://github.com/agentplugins/agent-plugins-spec), so `skills/` is flat: a client discovers only its immediate children. The tables below keep the groups the skills are organized by.

## Skills

All skills live in the `samuel` plugin. Invoke as `/samuel:<skill-name>`.

### Core Pipeline: R → [S] → P → [A] → I → V

A spec-driven pipeline with two optional gates (`[S]`pec and `[A]`nalyze) — bring them in when they de-risk the work, skip them for bugs and small features. State flows through `.claude/task-context.md`; per-repo config (`repo` for `gh`) lives in `.claude/samuel.md`. Committed feature artifacts (journal, validation) live under `docs/features/<slug>/`.

| Skill | Purpose |
|-------|---------|
| [`/samuel:codebase-documentation`](plugins/samuel/skills/codebase-documentation/SKILL.md) | Parallel sub-agent codebase exploration. Documents findings without suggesting changes. |
| [`/samuel:spec`](plugins/samuel/skills/spec/SKILL.md) *(optional)* | Generate a Spec (User Stories, FR-### MUST, SC-### measurable, Edge Cases). WHAT/WHY, not HOW. |
| [`/samuel:plan`](plugins/samuel/skills/plan/SKILL.md) | 5-phase interactive planning with forced human checkpoints + Constitution Check. |
| [`/samuel:refine-plan`](plugins/samuel/skills/refine-plan/SKILL.md) | Surgical edits to existing plans based on feedback. |
| [`/samuel:analyze`](plugins/samuel/skills/analyze/SKILL.md) *(optional)* | Read-only cross-artifact consistency check (spec/research/plan/tasks/constitution). |
| [`/samuel:tdd`](plugins/samuel/skills/tdd/SKILL.md) *(optional)* | Write tests at the seams the plan declared, one behaviour per red-green cycle. Refuses an unconfirmed seam. |
| [`/samuel:implement`](plugins/samuel/skills/implement/SKILL.md) | Sequential task execution with human verification + living Implementation Notes journal. |
| [`/samuel:validate`](plugins/samuel/skills/validate/SKILL.md) | Verifies against success criteria, seals the journal, runs documentation impact analysis. |

### Workflow

| Skill | Purpose |
|-------|---------|
| [`/samuel:roadmap`](plugins/samuel/skills/roadmap/SKILL.md) | Product Ownership / discovery: read the product's state, propose prioritized **bets** (`roadmap:now/next/later` issues) — what to build next and why. Upstream of `plan`. |
| [`/samuel:kickoff`](plugins/samuel/skills/kickoff/SKILL.md) | Initialize a new project: vision, MVP scope, tech decisions, initial task breakdown. |
| [`/samuel:next`](plugins/samuel/skills/next/SKILL.md) | Pull the next prioritized work item (GitHub Issues). |
| [`/samuel:start-task`](plugins/samuel/skills/start-task/SKILL.md) | Pick an item, create branch/worktree, bootstrap task-context + feature dir. |
| [`/samuel:conductor`](plugins/samuel/skills/conductor/SKILL.md) | Drive the pipeline unattended (cloud/overnight); `--ship` opens a draft PR. Safety gate: isolated worktree or a CI runner on a non-main branch. Budget caps + a run report per run. |
| [`/samuel:done`](plugins/samuel/skills/done/SKILL.md) | Open a PR (`Closes #N`, `--draft` for autonomous runs) synthesizing the journal; mark the item done; cleanup. |
| [`/samuel:progress`](plugins/samuel/skills/progress/SKILL.md) | Personal dashboard: item status, velocity, blockers (GitHub Issues). |
| [`/samuel:retro`](plugins/samuel/skills/retro/SKILL.md) | Personal retrospective from GitHub Issues/PRs + git history. |
| [`/samuel:team-orchestrate`](plugins/samuel/skills/team-orchestrate/SKILL.md) | Spawn multi-session Claude Code agent teams for parallel work streams — when you need a shared task list and a lead-controlled lifecycle, not just sessions that talk (that works on its own since 2.1.224). |
| [`/samuel:waves`](plugins/samuel/skills/waves/SKILL.md) | Attended multi-issue wave coordinator: parallel waves from the native `blockedBy` graph over Orca — one worktree + worker per issue (Codex default), draft PRs, the human merge releases the next wave. |
| [`/samuel:wave-prep`](plugins/samuel/skills/wave-prep/SKILL.md) | Backlog → wave-set preparer: sweep open issues, infer inter-issue dependencies from their plans, declare missing `blockedBy` edges (human-approved, cycle-checked), hand the ready set to `/samuel:waves`. |

### Product

| Skill | Purpose |
|-------|---------|
| [`/samuel:feature-dossier`](plugins/samuel/skills/feature-dossier/SKILL.md) | Create/update a living feature dossier (enriched markdown + Mermaid, evidence `file:line`, changelog) in a versioned product catalog. |
| [`/samuel:mermaid`](plugins/samuel/skills/mermaid/SKILL.md) | The diagram style standard: semantic shapes, one-emoji vocabulary, `classDef` palette. Single home for how every Mermaid diagram in the pipeline is drawn. |
| [`/samuel:tldr`](plugins/samuel/skills/tldr/SKILL.md) | The prose standard (Simplified Technical English): rewrite text so each sentence admits one reading. Single home for how every Issue/PR TL;DR, brief, and chat answer is written. |

### Design

| Skill | Purpose |
|-------|---------|
| [`/samuel:motion-brief`](plugins/samuel/skills/motion-brief/SKILL.md) | Refine a natural-language animation/transition description (+ screenshots, diagrams, references) into an implementation-ready Motion Brief with canonical motion nomenclature and a paste-ready agent prompt. |

### Git & Dev

| Skill | Purpose |
|-------|---------|
| [`/samuel:create-atomic-commit`](plugins/samuel/skills/create-atomic-commit/SKILL.md) | Atomic conventional commits, no AI attribution, requires approval. |
| [`/samuel:pr-self-audit`](plugins/samuel/skills/pr-self-audit/SKILL.md) | High-signal PR review: bugs, security, logic errors. |
| [`/samuel:address-pr-comments`](plugins/samuel/skills/address-pr-comments/SKILL.md) | Author side of the review gate: triage, verify, fix, reply, resolve PR comments in incremental passes. |
| [`/samuel:session-handoff`](plugins/samuel/skills/session-handoff/SKILL.md) | Context compaction (FIC) for long sessions. |
| [`/samuel:remove-slop`](plugins/samuel/skills/remove-slop/SKILL.md) | Remove AI-generated code slop from the current branch. |

### Contract

The backend ↔ client API handoff, in both directions. Agent-to-agent output, inline by default (a fenced block to paste into the other agent's session). Client axis is `web` or `mobile`.

| Skill | Purpose |
|-------|---------|
| [`/samuel:api-request`](plugins/samuel/skills/api-request/SKILL.md) | `web \| mobile → backend`: spec an endpoint a client needs — flow diagram, data requirements, proposed endpoints, error→UI mapping, open questions. |
| [`/samuel:api-contract`](plugins/samuel/skills/api-contract/SKILL.md) | `backend → web \| mobile`: document an endpoint you built — routes, validations, response shapes, native types (TypeScript + Swift/Kotlin), breaking-change notes. |

### Meta

| Skill | Purpose |
|-------|---------|
| [`/samuel:find-unknowns`](plugins/samuel/skills/find-unknowns/SKILL.md) | Map-vs-territory audit: audit / preflight (Issue N, READY-or-HOLD) / teach / quiz. Preflight gates autonomous `pipeline:ready`; quiz is the human comprehension gate before merging agent-authored PRs. |
| [`/samuel:repo-audit`](plugins/samuel/skills/repo-audit/SKILL.md) | Substrate drift detector for consumer repos: deterministic checks + semantic CLAUDE.md pass. Report-only. |
| [`/samuel:create-review-md`](plugins/samuel/skills/create-review-md/SKILL.md) | Generate a repo's root `REVIEW.md` (schema v1): deterministic evidence digest + semantic derivation of repo-specific review rules, cited per bullet. |

### Governance *(optional)*

| Skill | Purpose |
|-------|---------|
| [`/samuel:create-constitution`](plugins/samuel/skills/create-constitution/SKILL.md) | Ratify a repo-root `CONSTITUTION.md` (3–5 non-negotiable principles, semver). |
| [`/samuel:update-constitution`](plugins/samuel/skills/update-constitution/SKILL.md) | Amend the constitution with a Sync Impact Report. |

## Agents

Sub-agents are spawned by skills for parallel data retrieval. They are retrievers, not analysts — synthesis happens in the main context. The one exception is `implementation-reviewer`, a deliberate adversarial critic that returns an independent verdict (used only by `/samuel:validate` Step 2.5).

| Agent | Model | Purpose |
|-------|-------|---------|
| `component-locator` | sonnet | Find files/components relevant to a feature |
| `implementation-analyzer` | sonnet | Analyze implementation details of specific components |
| `pattern-scanner` | sonnet | Find similar implementations and usage patterns |
| `implementation-reviewer` | opus | Independent adversarial review of a diff vs spec/AC (`validate` Step 2.5) |

## Source of truth — GitHub Issues + PRs

Work is tracked in GitHub Issues + PRs via the `gh` CLI (no GitHub MCP) — the only tracker (ADR 0002). A work item is one Issue whose body serves three reading speeds: a ten-second **TL;DR** (*What / Why / Caveat* + chips) so a human can triage without reading agent-facing prose, the human **Brief**, and the self-contained **Executor Plan**. PR bodies open with the same block. Status is `pipeline:*` labels; a PR `Closes #N`; the conductor's `--ship` mode opens draft PRs for headless/cloud runs. Owner/repo is explicit (never parsed from origin), so it works behind an SSH-alias / multi-account setup. Hub + storage map: `plugins/samuel/reference/tracker.md`.


## Creating a new skill

```bash
mkdir -p plugins/samuel/skills/my-skill
cp template/SKILL.md plugins/samuel/skills/my-skill/SKILL.md
bash scripts/check-agent-plugins.sh
```

### Authoring guidelines

- **Hub-and-spoke**: `SKILL.md` is a compact hub (~80–120 lines); detail lives in `plugins/samuel/reference/`.
- **Flat `skills/`**: one directory per skill, directly under `skills/`. A `SKILL.md` any deeper is never discovered.
- **Intent over prescription**: declare the goal and constraints, don't micromanage steps Claude already knows.
- **Concise descriptions**: action-oriented with key trigger words, not exhaustive lists.
- **Shell context**: use the `!` backtick pattern to inject runtime data — every command needs a `2>/dev/null || echo "FALLBACK"`, and no shell expansion in inline commands.
- **Gotchas section**: every skill has a `## Gotchas` section that grows over time with learned edge cases.
- **`allowed-tools`**: declare every tool the skill needs in frontmatter.

See [`CLAUDE.md`](CLAUDE.md) for the full architecture, pipeline diagrams, and authoring guidelines.
