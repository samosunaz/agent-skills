---
name: pr-self-audit
description: "Review a PR for bugs, security, and logic errors. High-signal only. Trigger on 'review pr', 'code review', 'revisar pr'."
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git remote *) Bash(git rev-parse *) Bash(git config *) Bash(gh pr *) Bash(gh api *) Bash(head *) Read Grep Glob Agent AskUserQuestion
---

# PR Self Audit

Review a pull request for real bugs, security vulnerabilities, logic errors, and convention compliance. **High-signal only** — every flagged issue should be something a senior engineer would catch.

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Git user: !`git config user.name 2>/dev/null || echo "unknown"`
- Remote: !`git remote get-url origin 2>/dev/null || echo "No remote"`
- PR list: !`gh pr list --state open --json number,title,headRefName,url --limit 5 2>/dev/null || echo "No PRs or gh not configured"`
- Project CLAUDE.md: !`head -10 CLAUDE.md 2>/dev/null || echo "No CLAUDE.md"`
- REVIEW.md: !`head -20 REVIEW.md 2>/dev/null || echo "No REVIEW.md"`

## Pipeline Position

```
/samuel:validate → /samuel:done → [PR created] → /samuel:pr-self-audit → [approve → merge]
                                                          ↑
                                                    YOU ARE HERE
```

## Findings standard

Severity, categories, the confidence bar (≥80%), the diff boundary, what NOT to flag, and the "every finding has a fix" rule all come from the shared rubric: **`../../../reference/review-rubric.md`**. Read it and apply it — it is the same standard the `implementation-reviewer` agent uses pre-PR (`/samuel:validate` Step 2.5). This skill adds only the **PR-specific** mechanics below (GitHub diff, inline comments, publishing). A repo-root `REVIEW.md` overrides the defaults.

---

## Invocation Patterns

```
/samuel:pr-self-audit                    (auto-detect: current branch PR or ask)
/samuel:pr-self-audit 42                 (review PR #42)
/samuel:pr-self-audit https://github.com/org/repo/pull/42
```

---

## Step 1: IDENTIFY

### Find the PR

- **If PR number provided**: use it directly
- **If URL provided**: extract number
- **If no parameter**: check current branch from Context above
  - If branch has an open PR (from "PR list" in Context), use it
  - Otherwise: ask which PR to review

### Screening — skip if not worth reviewing

```bash
gh pr view {number} --json state,isDraft,additions,deletions,changedFiles
```

| Condition | Action |
|-----------|--------|
| `state` = CLOSED or MERGED | "This PR is already {closed/merged}." STOP. |
| `isDraft` = true | "This PR is a draft. Do you want to review it anyway?" |
| `additions + deletions` < 5 | "Trivial PR ({N} lines). Proceed?" |

---

## Step 2: GATHER

### Load PR context

```bash
gh pr view {number} --json title,body,headRefName,baseRefName,author,labels
```

### Load diff

```bash
gh pr diff {number}
```

### Load changed files

```bash
gh pr diff {number} --name-only
```

### Load project conventions

Read in priority order (stop at first found):
1. `REVIEW.md` — dedicated review rules (highest priority)
2. `CLAUDE.md` — project conventions
3. `.github/copilot-instructions.md` — if no CLAUDE.md

---

## Step 3: REVIEW

### Parallel analysis passes

Spawn review agents in a **single message** (model: sonnet) for maximum coverage:

| `subagent_type` | Focus | What to find |
|-----------------|-------|-------------|
| `implementation-analyzer` | **Bugs & Logic** | Null refs, off-by-one, wrong conditions, missing returns, dead code paths, type errors, incorrect imports. Wrong operator, inverted condition, missing edge case handling. |
| `implementation-analyzer` | **Security** | Injection (SQL, XSS, command), auth/authz gaps, secrets in code, unsafe deserialization, path traversal, missing input validation at system boundaries, data exposure in logs/responses. |
| `pattern-scanner` | **Convention compliance** | Does the PR follow patterns established in the codebase? New patterns that diverge from existing ones? CLAUDE.md/REVIEW.md rule violations? |

**Each agent receives:**
- The full PR diff
- Changed file list
- CLAUDE.md/REVIEW.md content (if found)

**Wait for ALL agents** before proceeding.

### Acceptance criteria check (if there is an associated work item)

If the PR is linked to a work item (`Closes #N` in the body), read it — `gh issue view {N}` (the Brief's Acceptance Criteria) — and cross-check against its acceptance criteria:
- Which criteria are covered by the changes?
- Which criteria are NOT covered?
- Are there changes that go BEYOND the task scope?

This is informational, not blocking — present it as a separate section.

### Validate findings

Apply the rubric's four-point finding check (`../../../reference/review-rubric.md` → "Validating a finding"): in-diff, concrete (not speculative), ≥80% confidence, senior-worthy. Discard anything that fails.

---

## Step 4: CLASSIFY

Assign **severity** (🔴 Blocker / 🟡 Important / 🔵 Nit) and **category** (Bug / Security / Logic / Convention) per `../../../reference/review-rubric.md`. Only 🔴 Blocker blocks merge; 🔵 Nits are informational.

---

## Step 5: PRESENT — CHECKPOINT

### Build file link base

```bash
REPO=$(gh pr view {number} --json headRepository --jq '.headRepository.owner.login + "/" + .headRepository.name')
HEAD_SHA=$(gh pr view {number} --json headRefOid --jq '.headRefOid')
```

File link format: `[{file}:{line}](https://github.com/{REPO}/blob/{HEAD_SHA}/{file}#L{line})`

**Every file reference** in the review body MUST be a clickable GitHub link. Never render file paths as plain text.

### Review report format

```markdown
## Review: {PR title} (#{number})

**Reviewer**: {git user}
**Branch**: {head} → {base}
**Files**: {N} modified, +{additions}/-{deletions}

---

### Verdict: {APPROVE | APPROVE WITH COMMENTS | REQUEST CHANGES}

{1-2 sentence summary}

---

{if findings:}
### Findings

#### [severity] {finding title}
**File**: [`{file}:{line}`](https://github.com/{owner}/{repo}/blob/{head_sha}/{file}#L{line})
**Category**: {Bug/Security/Logic/Convention}
**Impact**: {what happens if not fixed}

**Current code:**
```{lang}
{problematic code from diff}
```

**Suggestion:**
```{lang}
{fixed code}
```

**Why**: {brief explanation}

---

### Summary

| Severity | Count |
|----------|-------|
| Blocker | {n} |
| Important | {n} |
| Nit | {n} |
```

### Present to user

```
Review complete for PR #{number}: {title}

Verdict: {verdict}
{n} findings: {n} 🔴, {n} 🟡, {n} 🔵

{full report}

---

Options:
1. Publish as review on GitHub (with inline comments)
2. Show here only (do not publish)
3. Adjust before publishing
```

**WAIT for user choice.**

---

## Step 6: PUBLISH (if user chooses)

### Post GitHub review with inline comments

Post the review summary AND all inline comments in a **single request** using the reviews endpoint:

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST --input - <<'JSON'
{
  "commit_id": "{head_sha}",
  "event": "COMMENT",
  "body": "{summary review}",
  "comments": [
    {
      "path": "{file}",
      "position": {position_in_diff},
      "body": "{finding with suggestion block}"
    }
  ]
}
JSON
```

**`position`** = line number within the diff hunk (not the file). Count from the start of the hunk including context lines.

**Do NOT use** `POST /pulls/{n}/comments` (individual comment endpoint) — only the reviews endpoint supports inline comments with positioning.

**Suggestion blocks** (committable fixes):

````markdown
```suggestion
{fixed code}
```
````

---

## REVIEW.md — project overrides

Projects can create a `REVIEW.md` at the repo root to customize review behavior; its rules **override** the rubric defaults (§ Project overrides, `../../../reference/review-rubric.md`). Canonical authoring schema: `template/REVIEW.md` in the plugin repo — root-level, flat markdown, ≤30 lines of body. Paste its content into every review subagent's prompt (a path reference resolves to nothing for a subagent).

---

## Gotchas

_Add a line each time Claude trips on something._

- `gh api` for inline comments needs `commit_id` (HEAD SHA of PR), not the merge base.
- `gh pr diff` output can be huge — for PRs with 50+ files, focus on the most critical ones first.
- REVIEW.md rules override defaults — always check if it exists before applying standard criteria.
- Suggestion blocks must match the exact line range in the diff — off-by-one causes GitHub to reject the comment.
- Draft PRs should prompt before reviewing — the author may not want feedback yet.
- `POST /pulls/{n}/comments` (individual) does NOT accept `line`, `side` or `subject_type` — only `position`. For inline comments, use `POST /pulls/{n}/reviews` with the `comments: [{path, position, body}]` array.
- `position` in the reviews API is the relative line within the diff hunk, not the file line number.
- File paths in the review body must be GitHub links, not plain text.

## Rules

The findings standard — false-positive bar, fix-with-every-finding, diff boundary, REVIEW.md override, nits-don't-block, anti-performative — lives in `../../../reference/review-rubric.md`. PR-specific:

- **Suggestion blocks are committable.** Use GitHub's `suggestion` syntax so fixes apply with one click.
- **Inline over summary.** Anchor each finding to its `file:line` as an inline comment, not a wall-of-text summary.
