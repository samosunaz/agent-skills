<!--
Sync Impact Report — keep updated when amending
Version change: {old} -> {new}
Modified principles:
- {old name} -> {new name} (if renamed)
- {existing name} (if scope changed)
Added principles:
- {name}
Removed principles:
- {name}
Skills requiring review:
- ✅ updated: plugins/samuel/skills/plan/SKILL.md (Constitution Check)
- ✅ updated: plugins/samuel/skills/analyze/SKILL.md (Constitution detection pass)
- ⚠ pending: {file path} ({why})
Follow-up TODOs:
- {item} (if any placeholders deferred)
-->
# Constitution: [Repo Name]

**Version**: 1.0.0
**Ratified**: YYYY-MM-DD
**Last Amended**: YYYY-MM-DD

This document captures non-negotiable principles for engineering work in this repository. Principles are evaluated by `/samuel:plan` (DESIGN Constitution Check), `/samuel:analyze` (cross-artifact consistency), `/samuel:implement` (per-phase pre-check), and `/samuel:validate` (final compliance scan).

Violations require either explicit `Complexity Tracking` justification in the plan OR a constitution amendment via `/samuel:update-constitution`.

## Core Principles

### I. [Principle Name]

[Imperative description with MUST / MUST NOT / SHOULD language. State the rule, not the rationale, in the first sentence.]

**Rationale**: [Why this principle exists. Reference incidents, trade-offs, or strategic choices that produced this rule.]

### II. [Principle Name]

[Imperative description.]

**Rationale**: [Why.]

### III. [Principle Name]

[Imperative description.]

**Rationale**: [Why.]

[Add more principles as needed. Aim for 3-5 total. Beyond 7 becomes noise.]

## Architecture and Technology Constraints

[Optional section. Use when the repo has hard architectural boundaries that any plan must respect.]

Examples:
- Source layout: [e.g., apps in `apps/*`, shared packages in `libs/*`].
- Backend platform: [e.g., Cloudflare Workers, Laravel, Node + Express].
- Runtime / package manager: [e.g., Bun, npm, pnpm].
- Approved external services: [list].

## Development Workflow and Quality Gates

[Optional section. Use when the repo has standard quality bars for any change.]

Examples:
- Verification commands the plan MUST cite: `typecheck`, `lint`, `build`, `test`.
- Automated test policy: [tests required for X, optional for Y].
- Branch / commit conventions: [reference to repo CLAUDE.md if standardized].

## Governance

### Amendment procedure

1. Propose via `/samuel:update-constitution` (drafts the change with a Sync Impact Report).
2. The amendment is the artifact of record — commit it on its own.
3. MAJOR changes SHOULD include a brief migration note for in-flight features.

### Versioning policy

- **MAJOR**: backward-incompatible governance changes, principle removals, redefinitions that invalidate prior plans.
- **MINOR**: new principle added, or materially expanded guidance.
- **PATCH**: clarifications, typo fixes, non-semantic refinements.

### Compliance review

- `/samuel:plan` runs an explicit Constitution Check; violations require `Complexity Tracking` justification.
- `/samuel:analyze` cross-references all artifacts against the constitution.
- `/samuel:implement` re-checks before each phase.
- `/samuel:validate` scans the final diff against MUST principles.

Skip the constitution entirely (CONSTITUTION.md absent) for repos where lightweight delivery is preferred. The pipeline degrades gracefully — Constitution gates become no-ops.
