---
name: create-constitution
description: "Ratify the repo's CONSTITUTION.md (3-5 non-negotiable principles, semver, governance) at v1.0.0. Optional — the pipeline degrades gracefully without it. Trigger on 'create constitution', 'ratify principles', 'initial constitution'."
allowed-tools: Bash(git config *) Bash(git rev-parse *) Bash(date *) Bash(test *) Bash(cat *) Read Write Edit AskUserQuestion
---

# Create Constitution

Generate the initial `CONSTITUTION.md` at the repo root. Use once per repo. Subsequent amendments use `/samuel:update-constitution`.

Entirely optional: the pipeline (`/samuel:plan`, `/samuel:analyze`, `/samuel:implement`, `/samuel:validate`) runs Constitution Checks only when the file exists, and degrades to no-ops otherwise. Worth it for a project you're scaling; skip it for throwaway experiments.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Pipeline Position

Standalone setup skill. Run before adopting constitution-enforced delivery in a repo, OR retroactively when an existing project wants it.

## Critical Rules

1. **Repo root, not a scratch file.** `CONSTITUTION.md` lives at the repo root and is versioned in git — never in a gitignored local directory.
2. **3-5 principles is the sweet spot.** Beyond 7 becomes ceremony with diminishing returns. If you have 8 candidates, pick the 5 that matter most.
3. **Imperative language.** Every principle uses MUST / MUST NOT / SHOULD. "We try to" and "we prefer" are aspirations, not principles.
4. **Rationale is mandatory.** A principle without rationale gets violated the moment it's inconvenient.
5. **Initial version is 1.0.0.** Not 0.1.0. The constitution is binding from creation.
6. **English by default.** Principles, rationale, and governance are written in English regardless of the repo's spoken language.

## Context

- Date: !`date '+%Y-%m-%d'`
- Repo root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Git user: !`git config user.name 2>/dev/null || echo "unknown"`
- Existing constitution: !`test -f CONSTITUTION.md && echo "PRESENT — abort and use /samuel:update-constitution instead" || echo "absent — proceed"`
- Template: !`test -f template/CONSTITUTION.md && echo "template/CONSTITUTION.md available" || echo "use inline fallback below"`

## Pre-checks

If `Existing constitution: PRESENT`, abort: "CONSTITUTION.md already exists. To amend, use /samuel:update-constitution. To replace from scratch, delete the file first (git history preserves the prior version)."

If `Repo root: NO_REPO_ROOT`, abort: not a git repo.

## Phase 1: GATHER PRINCIPLES

Interactive collection. The user supplies 3-5 principles. For each: **Name** (≤5 words), **Imperative statement** (MUST / MUST NOT / SHOULD), **Rationale** (why it exists).

```
Let's ratify the constitution for [Repo Name].

The constitution captures 3-5 non-negotiable principles that /samuel:plan,
/samuel:analyze, /samuel:implement, and /samuel:validate verify on every feature.

For each principle I need: Name (≤5 words), Imperative rule (MUST / MUST NOT / SHOULD),
Rationale (why it exists).

What's the first principle?
```

WAIT for each. Stop when the user signals done OR at 5 principles.

### Optional sections

Ask whether the repo has hard **architectural constraints** (monorepo structure, framework, package manager, approved services) and standard **quality gates** (verification commands, testing policy, branch/commit conventions). WAIT for each; skip the section if none.

## Phase 2: DRAFT

Read `template/CONSTITUTION.md` if available; otherwise use the inline fallback. Fill placeholders with the gathered principles + optional sections. The Sync Impact Report at the top (HTML comment) lists which skills are constitution-aware: `/samuel:plan`, `/samuel:analyze`, `/samuel:implement`, `/samuel:validate`.

## Phase 3: PROPOSE — CHECKPOINT

Present the full drafted constitution. `Changes before writing? (Y / N / Edit)`. WAIT for approval.

## Phase 4: WRITE

Write to `CONSTITUTION.md` at the repo root (verify `git rev-parse --show-toplevel` equals cwd first). MUST be at repo root, not a subdirectory.

## Phase 5: PRESENT

```
CONSTITUTION.md written to {repo-root}/CONSTITUTION.md

Principles: I. {Name} · II. {Name} · ...
Version: 1.0.0 · Ratified: {today}

Next:
1. git add CONSTITUTION.md && git commit -m "docs: ratify constitution v1.0.0"
2. Set constitution: CONSTITUTION.md in .claude/task-context.md for active features (or it's auto-detected).
3. To amend later: /samuel:update-constitution
```

## Gotchas

_Add a line each time Claude trips on something._

- CONSTITUTION.md lives at REPO ROOT, NOT in a gitignored local directory or `plugins/`. It's a versioned git artifact.
- Initial version is 1.0.0. Not 0.1.0. Binding from creation.
- 3-5 principles. If the user lists 8, push back: a constitution with 8 principles is the same as one with none — nobody remembers them.
- Rationale is mandatory.
- Imperative language only. MUST / MUST NOT / SHOULD.
- Optional by design — don't push it on a small experiment. The pipeline works fine without it.
