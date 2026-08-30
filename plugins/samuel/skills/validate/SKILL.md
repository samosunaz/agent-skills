---
name: validate
description: Validate the implementation against the plan, verify acceptance criteria, run the project gate, resolve & seal the journal, and analyze documentation impact. Mandatory final step before done.
allowed-tools: Bash(git branch *) Bash(git log *) Bash(git diff *) Bash(git rev-parse *) Bash(gh *) Bash(awk *) Bash(test *) Bash(bun *) Bash(npm *) Bash(pnpm *) Bash(node *) Bash(gitleaks *) Bash(semgrep *) Read Edit Write Agent AskUserQuestion
---

# Validate

Verify the implementation satisfies the plan and the Brief's Acceptance Criteria, **run the project gate** (the local half of the merge gate), resolve & seal the journal, and flag documentation impact. **Mandatory final step before `/samuel:done`.**

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- HEAD SHA: !`git rev-parse HEAD 2>/dev/null || echo "NO_HEAD"`
- Recent commits: !`git log --oneline -n 20 2>/dev/null || echo "No commits"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- Constitution: !`test -f CONSTITUTION.md && echo "present" || echo "none"`
- Review overrides: !`test -f REVIEW.md && echo "REVIEW.md present" || echo "none"`
- Security scan: !`awk '/^security_scan:/{sub(/^[^:]*: */,"");sub(/[ \t]*#.*$/,"");print;f=1}END{if(!f)print"NO_SCAN"}' .claude/samuel.md 2>/dev/null || echo "NO_SCAN"`

> **Tracker**: `../../reference/tracker.md`. **Adapter**: `../../reference/github-operations.md`. **Journal** (committed file): `../../reference/implementation-notes.md`. **State**: `../../reference/task-context.md`.

## Step 0: Resolve the journal

Run when `{feature_dir}/implementation-notes.md` exists (`Read` it). Skip otherwise.

1. **Open Questions**: for each `Q-NNN` with `Status: open`, present it (Impact-if-wrong + Suggested resolution); capture the answer → `answered`/`deferred`. **`Blocking: yes` + `open` is a hard blocker** — do not seal or PASS until resolved/deferred.
2. **Deviations**: each `V-NNN` that was a hard STOP must have a `Linked decision` (an Issue comment). If missing, record it now and flag a `WORKFLOW NOTE`.
3. Carry journal counts (D/V/T/Q, open_remaining) into the report.

The journal is **sealed in Step 5**, not here.

## Step 1: Gather evidence

Load the plan (Issue Executor Plan) and identify what should have changed. Spawn parallel research agents in a **single message** (all `sonnet`):

| `subagent_type` | Job |
|---|---|
| `implementation-analyzer` | planned changes landed in the specified files |
| `component-locator` | find all modified files for the feature |
| `pattern-scanner` | tests added/modified if the plan specified them |

**Wait for ALL.**

## Step 2: Run the gate + verify criteria

1. **Run the project gate** — the `Validation → Automated` command from the plan (e.g. `bun run gate`: typecheck+lint+build+guardrails). Capture real output **and the `HEAD SHA` it ran against** (Context). **This is the local merge gate** — a red gate blocks PASS. The SHA goes in the report: it is what `/samuel:done` compares against before emitting a `signoff` status, so a commit added after this step can never inherit this gate's verdict (adapter § Signed-off checks).
2. **Run the security scan** — `Security scan` in Context (from `.claude/samuel.md`, `../../reference/tracker.md`). A command → run it **exactly as written**; **non-zero exit = FAIL**, weighted like a red gate. `NO_SCAN` → skip **explicitly** ("no security scan configured — skipping"), the same degradable pattern as REVIEW.md below; never invent a command. Courtesy check on `NO_SCAN` only: if `.gitleaks.toml` / `.semgrep*` exists at the repo root, add an **informational** note — "scan config detected but not wired — add `security_scan:` to `.claude/samuel.md`" — and never gate on it.
3. **Verify each Brief Acceptance Criterion** and the plan's DoD: run the check, record pass/fail with actual output. Flip satisfied AC `- [ ]`→`- [x]` in the Brief (fetch body → splice → `gh issue edit --body-file`). If the plan declares an **e2e tier**: verify it was honored — the declared journey exists, runs green, and matches the tier (green/yellow/manual-only).
4. **Manual criteria**: list what needs human testing, with steps.
5. **Edge cases & mismatch**: error paths, regressions; cross-check deviations against recorded decisions. Unrecorded deviation → record retroactively + `WORKFLOW NOTE`.

## Step 2.5: Independent Review (adversarial)

The maker grades its own homework too kindly. After a green gate, spawn an **independent** reviewer with fresh context — it never saw the implementation reasoning, only objective inputs. This is the semantic layer the gate can't give ("does the diff satisfy the spec?"); it does **not** replace the gate.

**Ordering**: run only after Step 2's gate is green — a red gate is already FAIL, don't spend the review. In a repo with **no gate command** (e.g. a content/docs repo), run the review anyway and note "no objective gate" in the report.

Spawn ONE `implementation-reviewer` (single message; `model: opus`) and **wait** for it. Pass these objective inputs in the prompt (never the maker's narrative):

- the **base ref** so the reviewer runs `git diff {base}...HEAD` itself (it has `Bash(git diff *)`) — avoid pasting a large diff into the prompt;
- the Brief's Acceptance Criteria (+ `spec.md` FR/SC if present);
- the Executor Plan (the Steps the work was built from);
- the **real gate output** from Step 2 (or "no objective gate");
- the full text of the **review rubric** — `Read` `../../reference/review-rubric.md` and paste it in (a subagent has no plugin base-dir to read it itself);
- the repo's **`REVIEW.md`** when present (Review overrides in Context) — `Read` it and paste it in **after the rubric**, labeled as the project override; on conflict REVIEW.md wins (§ Project overrides, `../../reference/review-rubric.md`). Absent file → skip silently, the rubric alone governs.

The reviewer returns `APPROVE | REQUEST CHANGES` + findings (`severity · category · file:line · impact · fix`). Carry it into Step 3 verbatim — **you do not edit or soften the verdict**; it is the independent record. Any **Blocker** makes the overall result FAIL.

## Step 3: Validation report

```markdown
## Validation Report: {item} — {title}
**Date**: {ISO}   ·   **Item**: {item}

### Overall: [PASS | PASS WITH NOTES | FAIL]
> Computed: red gate, **failing security scan**, **or** any reviewer Blocker → FAIL · reviewer Important (no Blocker) → PASS WITH NOTES · else PASS. A `SKIP`ped scan is neutral.

### Gate
- **Gated SHA**: `{HEAD SHA at Step 2}`
- [PASS/FAIL] `{gate command}` — {summary of output}
- [PASS/FAIL/SKIP] security: `{security_scan command}` — {summary}   _(SKIP when no `security_scan` in `.claude/samuel.md`)_

### Independent Review (Step 2.5)
- **Verdict**: [APPROVE | REQUEST CHANGES]  ·  🔴 {n}  ·  🟡 {n}  ·  🔵 {n}   _(or "no objective gate — review-only")_

### Criteria
| AC / DoD | Status | Evidence |
|---|---|---|
| AC1 … | PASS | `{command/output}` |

### Manual Testing Checklist
1. {step-by-step} → expected {result}

### Issues (before merge)
- **{B|I|N}{n}** [🔴 Blocker | 🟡 Important | 🔵 Nit] {description} at `file:line` — {fix}   _(reviewer + manual findings, rubric severity; IDs by severity initial — never `#{n}`, § Enumeration IDs)_

### Journal: D:n V:n T:n Q:{open}  ·  Deviations: {n}
```

## Step 4: Documentation impact

Check whether behavior changed in ways docs must follow: API/endpoints, env/config, dependencies, public interfaces, DB schema. Spawn a `component-locator` to find docs referencing old behavior. Present each needed update with a concrete proposal (**never auto-apply** — ask Y/N/Edit). If none: state what was checked.

**Feature dossier**: if this **changes product behavior / adds a user-facing capability**, surface (don't run) `/samuel:feature-dossier "{capability}"`.

## Step 5: Present, persist, seal

1. **Persist the report** as a committed file `{feature_dir}/validation.md` (`Write`). Also surface it: `gh issue comment {item} -R {repo}` with the PASS/FAIL summary + the independent-review verdict + manual checklist (so the Issue timeline tells the story). Code refs in the comment follow the adapter § Linking: SHA permalinks if the branch is pushed, plain `path:line` otherwise (the usual case pre-`done` — don't push just to mint links).
2. **Present** the report (+ doc updates).
3. **Seal the journal** (only on PASS / PASS WITH NOTES, no `Blocking: yes` open questions, **and no unresolved reviewer Blocker**): `Read`+`Edit` the file → `Status: sealed`, drop `status:living`/`has-open-questions` from its body callout, keep `has-deviations` if applicable.
4. **Set phase**: `.claude/task-context.md` → `phase: validate`, `last_updated: {today}`.
5. Recommend: PASS → `/samuel:done`; FAIL → fix, re-run; PASS WITH NOTES → address, then `/samuel:done`.

## Important Guidelines

1. **Run the gate for real** — no PASS without the actual command output. The conductor's draft-PR step depends on this being honest.
2. **Independent review is mandatory (Step 2.5)** — the reviewer's verdict is the maker's checker, not advisory; a Blocker blocks PASS and (in the conductor) the draft PR. In a repo with no gate, it is the primary verification.
3. **Status per phase**, **severity per issue**, **actionable output**.
4. **Never auto-update docs**. **Doc impact (Step 4) is mandatory.**

## Gotchas

_Add a line each time Claude trips on something._

- The gate command comes from the plan's `Validation → Automated` line — if absent, the plan was incomplete; ask for it and note the gap.
- `security_scan` is **repo-scoped** (`.claude/samuel.md`), never plan-scoped — don't look for it in the plan's Validation section, and don't let a plan override it.
- A failing security scan computes into `Overall` exactly like a red gate: it is a FAIL, not a note. A missing field is a `SKIP` and weighs nothing.
- The scan command is repo-defined, so it won't match this skill's `allowed-tools` patterns beyond `gitleaks`/`semgrep`. Interactive runs prompt; an **autonomous** run needs the command in the conductor's allowlist (`../conductor/references/autonomous-run.md` § Permission allowlist, and the pre-staged block in `assets/conductor.yml`) or the scan dies unapproved and the run reads as skipped — a `SKIP` weighs nothing, so the gate passes without scanning.
- The field read strips from the first `#` (trailing-comment removal), so a command containing `#` is truncated. Documented at the field: `template/samuel.md`.
- Journal is a committed file — seal by editing it directly.
- Seal ONLY on PASS / PASS WITH NOTES with no `Blocking: yes` open question. FAIL leaves it living for the next implement pass.
- Posting the validation summary as an Issue comment is what makes the morning review legible — don't skip it.
- A green gate locally is necessary but not sufficient — remote CI re-runs on the PR. Don't claim "CI will pass", claim "local gate passed".
- Save the report file BEFORE presenting — prevents loss if the session ends.
- Step 2.5 spawns an **independent** reviewer (fresh context, `opus`). Pass it objective inputs only (diff/AC/plan/gate/rubric) — never the maker's narrative — and never edit/soften its verdict. A reviewer Blocker is a hard FAIL, exactly like a red gate.
- The reviewer needs the rubric **pasted into its prompt** (read `../../reference/review-rubric.md`) — a subagent can't resolve the plugin's relative path itself.
- `REVIEW.md` (when present) is pasted the same way, after the rubric and labeled as the project override — a path reference resolves to nothing for the subagent, and an unpasted override is a silent no-op.
- **Give the reviewer the real shape of the diff, not just the base ref.** On a branch with no commits `git diff {base}...HEAD` returns empty, and new untracked files are invisible to every `git diff` — the reviewer reviews nothing and returns "no findings", which reads exactly like clean. Enumerate the modified and the new files in the prompt, and say which command actually shows them.
- **A content-free subagent return is a broken channel, not a clean verdict.** Re-query the same agent by name before concluding it had nothing to say; an empty idle notification has hidden a full REQUEST CHANGES that arrived on a direct re-ask.
