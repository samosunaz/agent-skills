---
name: remove-slop
description: Remove AI-generated code slop from the current branch. Scans diff against base branch for unnecessary comments, defensive code, type hacks, and style inconsistencies introduced by AI tools.
allowed-tools: Bash(git branch *) Bash(git diff *) Bash(git merge-base *) Bash(cat package.json) Bash(cat composer.json) Bash(cat go.mod) Bash(cat Cargo.toml) Bash(cat requirements.txt) Bash(cat Gemfile) Bash(ls node_modules/*) Read Edit Glob
---

# Remove Slop

Reviews the diff of the current branch against `main` and removes AI-generated slop. Does not change logic or functionality — only cleans up what a senior dev would not have written.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Merge base: !`git merge-base origin/main HEAD 2>/dev/null || echo "NO_MERGE_BASE"`
- Changed files (default mode): !`git diff --name-only origin/main..HEAD 2>/dev/null || echo ""`

## Invocation

```
/samuel:remove-slop                    (full branch diff against main)
/samuel:remove-slop --staged           (only staged changes)
/samuel:remove-slop path/to/file.ts    (specific file)
```

## Process

### 0) Gather project context

Read dependency manifests to know what the project already has available. Check whichever exist:

- `package.json` → `dependencies` + `devDependencies`
- `composer.json` → `require` + `require-dev`
- `go.mod`, `Cargo.toml`, `requirements.txt`, `Gemfile` — as applicable

Build a mental map of installed capabilities: date libs (dayjs, date-fns, Carbon, Luxon), HTTP clients (axios, Guzzle), validation (zod, joi), string/collection utils (lodash, Str::, collect()), UUID generation, etc. This powers the "Reinventing the wheel" check in step 2.

### 1) Get the diff

Use Context above for default mode. For other modes:

```bash
# --staged: only staged
git diff --cached

# Specific file
git diff $(git merge-base origin/main HEAD)..HEAD -- {file}
```

For default mode, run: `git diff [merge-base from Context]..HEAD`

For each changed file, also read the **full file** (not just the diff) to understand existing style and patterns.

### 2) Scan for slop

Check every addition in the diff against these categories. **Only flag lines that were added in this branch** — never touch pre-existing code.

The anti-practices below come from the shared taxonomy — source of truth: `../../../reference/code-comments.md`. Kept inline (mirror, not pointer) because a detection checklist behind a link doesn't get scanned. Update the spoke first, then re-mirror here.

#### Comments that don't earn their tokens

Applies to code comments **and** to prose in committed repo artifacts the diff touches (`REVIEW.md`, ADRs, `CLAUDE.md`, generated docs) — not only to source.

- Change narrative instead of describing the result: `"… is retired (#786)"`, `"Single source of truth — X is retired"`
- Obvious comments restating the code: `// increment counter`, `// return the result`
- Signature restatement: a docblock that just restates the function's signature — `"Total refunded, derived from refund rows (Σ amount)"` over `sum('amount')`
- References that rot: internal issue refs (`` `#786` ``), counts snapshots (`153/153 migrations`), line ranges (`Action.php:35-40`) — anything whose target can change without the comment being touched
- Diff-relative language that only parses if you know the code that used to be there: `"the (derived) refundable amount"`, `"never mutate the payment's money columns"`
- Section banners a human wouldn't write: `// ===== Helper Functions =====`, including plan/AC scaffolding leaking into tests: `// ---- AC-1: refund is recorded as its own row ----`
- JSDoc/PHPDoc added to private/internal methods that didn't have them before (unless project convention requires it)
- Trailing comments on obvious lines: `const users = []; // initialize empty array`
- **Keep**: comments that explain _why_, TODOs with context, regulatory/business rule explanations, and stable external references (spec, RFC, upstream bug, a repo path a reader can open) paired with the reason
- **Remove**: a reference that rots — replace it with the reason it encoded, not the pointer

#### Defensive code that isn't needed

- Try/catch wrapping code that can't throw, or catching and re-throwing without transformation
- Null checks on values guaranteed by the type system or framework
- Redundant `?? undefined`, `|| null`, `?? []` on values already typed as non-nullable
- Fallback defaults that mask bugs instead of surfacing them early
- `if (!x) return;` guards at the top of functions called only by trusted internal callers
- **Keep**: validation at system boundaries (user input, external APIs, DB results), error handling that adds context

#### Type system hacks

- `as any`, `as unknown as X` — casts to dodge type errors instead of fixing the actual type
- `@ts-ignore` / `@ts-expect-error` without an explanation comment
- Overly broad types (`Record<string, any>`, `object`) where a specific interface exists
- `// @phpstan-ignore-next-line` without justification
- **Keep**: casts with a comment explaining why, legitimate `unknown` for dynamic data

#### Over-engineering

- Abstractions used exactly once (utility functions, helper classes, wrappers)
- Config/constants extracted for a single use site
- Generic parameters that could be concrete
- Factory patterns where direct instantiation works
- **Keep**: abstractions used 3+ times, genuine extension points documented in spec

#### Style inconsistencies

- Naming conventions that don't match the file (camelCase in a snake_case file, or vice versa)
- Import style that differs from existing patterns in the file
- Error handling patterns inconsistent with neighboring code
- String quote style mismatches (`"` vs `'` in the same file)
- **Keep**: intentional style improvements if they cover the whole file consistently

#### Emoji and filler

- Emoji in code comments, variable names, or log messages (unless the project uses them)
- Filler words in comments: "basically", "essentially", "simply", "just"
- Marketing language in comments: "robust", "seamless", "elegant", "powerful"
- Grandiose names for simple things: `AbstractStrategyManager` for a 20-line class

#### Reinventing the wheel

Use the dependency map from step 0. Flag when new code reimplements something an installed dependency already provides:

- Date formatting/parsing manually when dayjs, date-fns, Carbon, Luxon is installed
- Custom HTTP client wrappers when axios, Guzzle, ky is available
- Hand-rolled validation logic when zod, joi, yup, or similar exists
- Custom string helpers (slugify, truncate, capitalize) when lodash, Str:: is in deps
- Manual UUID generation when `crypto.randomUUID()`, `Str::uuid()`, or a uuid package exists
- Custom retry/backoff logic when a retry lib or framework feature is available
- **Keep**: cases where the custom version is intentionally simpler or avoids heavy dependency
- **How to fix**: replace with the library call. If the replacement changes the public API, flag to user

#### Hallucinated imports and APIs

AI models fabricate imports, methods, and package APIs that don't exist. Verify every new import/use added in the diff:

- Imports from packages not in the dependency manifest
- Imports of functions/classes that don't exist in the referenced package
- Framework methods that don't exist (e.g., `Model::findOrCreate()` when it's `firstOrCreate()`)
- **How to verify**: check `node_modules/<pkg>` exports, or read the actual source file being imported
- **How to fix**: replace with the correct import/method. If unsure, flag to user

### 3) Fix — don't flag

Apply all fixes directly. This is a cleanup tool, not a linter — remove the slop, don't create a report of it.

**Rules for fixing:**
- Remove slop lines entirely — don't replace a bad comment with a "better" one
- When removing defensive code, ensure the surrounding logic still flows correctly
- When removing type hacks, fix the actual type if possible. If not fixable, leave with `// TODO: fix type`
- Never change behavior or logic — only remove noise
- Don't touch imports unless they became unused after your removals
- When replacing reinvented wheels: add the library import, replace the custom code, remove the now-unused function
- When fixing hallucinated imports: verify the correct API exists before replacing. If unsure, flag to user
- Run `git diff` after fixes to verify no logic changed

### 4) Report

After all fixes, present a concise summary:

```
Deslop: {N} files cleaned

- Removed {n} unnecessary comments
- Removed {n} redundant defensive checks
- Fixed {n} type hacks
- Removed {n} over-engineered abstractions
- Fixed {n} style inconsistencies
- Replaced {n} reinvented wheels with library calls
- Fixed {n} hallucinated imports/APIs

No logic changes. Run tests to confirm.
```

Keep the report to **1-3 sentences** max if changes are minor.

## Gotchas

_Add a line each time Claude trips on something._

- Type casts with explanatory comments (`as X // reason`) are intentional — don't remove them.
- Reading the full file (not just diff) is critical to understand existing style before flagging inconsistencies.
- Some projects intentionally use `@ts-expect-error` with explanations — check before removing.
- Don't remove empty catch blocks that are intentional error swallowing (e.g., `try { optional() } catch {}`).
- "Reinventing the wheel" requires reading dependency manifests first — never flag without checking what's installed.
- A custom implementation may be intentional when the lib version is too heavy. When in doubt, flag to user.
- Hallucinated import detection must verify against actual installed packages, not just pattern matching.
- Don't confuse re-exports or barrel files with hallucinated imports.

## What this skill is NOT

- Not a refactoring tool — don't restructure code
- Not a linter — don't enforce rules on pre-existing code
- Not an optimizer — don't change algorithms or performance
- Not a style guide enforcer — match existing style, don't impose new one
