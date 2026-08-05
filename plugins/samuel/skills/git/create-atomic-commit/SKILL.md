---
name: create-atomic-commit
description: Create git commits with user approval and no AI attribution. Reviews changes, plans atomic commits following conventional commits, and executes upon confirmation.
allowed-tools: Bash(git branch *) Bash(git status *) Bash(git diff *) Bash(git log *) Bash(git add *) Bash(git commit *) Bash(git checkout *) Bash(cat *) Read Glob AskUserQuestion
---

# Commit Changes

Create git commits for the changes made during this session.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Working tree: !`git status --short 2>/dev/null || echo ""`
- Staged changes: !`git diff --cached --stat 2>/dev/null || echo ""`
- Unstaged changes: !`git diff --stat 2>/dev/null || echo ""`
- Recent commits (style reference): !`git log --oneline -5 2>/dev/null || echo "No commits"`
- Commitlint config: !`cat commitlint.config.mjs 2>/dev/null || cat commitlint.config.js 2>/dev/null || cat commitlint.config.ts 2>/dev/null || cat .commitlintrc.json 2>/dev/null || echo "No commitlint config found"`
- Task context: !`cat .claude/task-context.md 2>/dev/null || echo "NO_TASK_CONTEXT"`

## Pre-requisites

- If the project has a `commitlint.config.mjs` (or `.js`, `.ts`, `.json`), use the config from Context above.
- Read `references/commit-conventions.md` for general commit best practices. If already loaded, skip this step.

## Process

### 0) Branch guard

If current branch is `main` or `master`:
- **STOP. Do not commit.**
- Analyze the staged/unstaged changes to understand their intent.
- Suggest a branch name: `<type>/<short-description>` (e.g., `feat/session-persistence`, `fix/payment-timeout`).
- Ask: **"You're on main. I suggest creating branch `<suggested-name>` before committing. Want me to create it, or do you have a different name?"**
- Once the user confirms, run `git checkout -b <branch-name>` and proceed.

### 0.5) Detect pipeline mode

Determine if this commit is part of an active task pipeline:

- **Pipeline mode ON** if ANY of:
  - `.claude/task-context.md` exists and references `TASK-XXX`
  - Branch name matches `TASK-[0-9]+`
- **Pipeline mode OFF** otherwise (standard behavior, skip enrichment in step 1)

If pipeline mode ON, extract:
- **Task ID**: `TASK-XXX` from task context or branch name
- **Phase**: current phase number and total from the Executor Plan (task context or Issue body)
- **Task name**: from task context

### 1) Plan your commit(s)

Using the context above:

- Review the conversation history and understand what was accomplished
- Consider whether changes should be one commit or multiple logical commits
- Identify which files belong together logically
- Draft clear, descriptive commit messages using conventional commits format
- Focus on **why** the changes were made, not just what

**If pipeline mode is ON**, enrich the commit body with structured context:

```
<type>(<scope>): <description>

TASK-XXX | Phase N/M: <phase-name>

Decisions:
- <key technical decision and reasoning>

Next:
- <what remains in current phase or next phase>
```

Rules for pipeline body:
- First line after blank: `TASK-XXX | Phase N/M: <name>` — omit phase if unknown
- `Decisions:` only if non-obvious choices were made. Omit for trivial commits.
- `Next:` brief pointer to what follows. One or two lines maximum.
- Total body under 10 lines. It's a mini-handoff, not a full handoff.
- Trivial commits (typo, import cleanup): skip the enriched body even if pipeline mode is ON.

### 2) Present your plan to the user

List the files and commit message(s):

```
Commit 1:
  Files: src/auth/login.ts, src/auth/session.ts
  Message: feat(auth): add session persistence on login

Commit 2:
  Files: tests/auth/login.test.ts
  Message: test(auth): add session persistence tests
```

Ask: **"I plan to create [N] commit(s) with these changes. Shall I proceed?"**

### 3) Execute upon confirmation

- Use `git add` with **specific files** (never use `-A` or `.`)
- Create commits with planned messages
- Always use `--no-verify` unless the user explicitly requests hook validation
- Show the result with `git log --oneline -n [number]`

## Important

- **NEVER add co-author information or AI attribution** (Claude, Copilot, Grok, GPT, etc.)
- Commits should be authored solely by the user
- Do not include any "Generated with AI" messages
- Do not add "Co-Authored-By" lines
- Write commit messages as if the user wrote them

## Gotchas

_Add a line each time Claude trips on something._

- Commitlint config can live in `package.json` under `commitlint` key — not just dedicated files.
- `--no-verify` is the default here. If hooks fail unexpectedly, the user probably wants them — ask.
- When on main, always suggest a branch BEFORE committing. Never commit directly to main.
- Scope must match `scope-enum` in commitlint config. Check before using a scope.
- Pipeline body is for substantial commits only. Trivial changes (typos, imports) get standard one-line commits even in pipeline mode.
- `TASK-XXX` goes in the commit **body**, never in the subject — it breaks release-please parsing.
- If `NO_TASK_CONTEXT` appears in context, pipeline mode is OFF. Do not guess.

## Remember

- You have the full context of what was done in this session
- Group related changes together
- Keep commits focused and atomic when possible
- The user trusts your judgment — they asked you to commit
