---
name: done
description: "Close the loop — open a PR (Closes #N), mark the item done, and clean up. Supports --draft for autonomous runs. Trigger on 'done', 'terminé', 'ship it', 'crear PR'."
allowed-tools: Bash(git branch *) Bash(git config *) Bash(git rev-parse *) Bash(git remote *) Bash(git log *) Bash(git diff *) Bash(git merge-base *) Bash(git checkout *) Bash(git push *) Bash(git pull *) Bash(gh pr *) Bash(gh issue *) Bash(gh label *) Bash(awk *) Read Agent AskUserQuestion
---

# Done — Close the Loop

Open the PR, mark the Issue done, and clean up. The inverse of `start-task`. Supports `--draft` for unattended runs (the agent opens a draft PR, CI runs, the human merges).

> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../reference/interaction-tools.md`.
> **Autonomy:** which gates below auto-advance, and what gets recorded instead of asked — `../../reference/autonomy.md`. Every outward action in this skill (push, PR, merge, ready) stays gated at **every** level. An **unattended** run — headless `claude -p`, CI, or `/samuel:conductor` — is `autonomous` and ignores the `Autonomy:` value in Context.

## CRITICAL RULES

1. **Run `/samuel:validate` first.** If no validation report exists / the journal isn't sealed, warn and recommend it. Do not open a non-draft PR on a red local gate.
2. **Never force-push, delete branches, or remove worktrees without explicit confirmation.**
3. **No AI attribution in PRs.** No "Generated with Claude Code", no "Co-Authored-By".
4. **Push/PR only with authority** — interactive user-approved, or an autonomous run explicitly launched with that goal. `attended-auto` grants **no** push authority: it auto-advances soft gates, never an outward action, so Step 2's DoD gate waits for it exactly as it does at `interactive`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Autonomy: !`awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)exit 1}' .claude/samuel.md 2>/dev/null || awk '/^autonomy:[ \t]*attended-auto[ \t]*(#.*)?$/{print"attended-auto";f=1;exit} /^autonomy:/{print"interactive";f=1;exit} END{if(!f)print"interactive"}' ~/.claude/samuel.md 2>/dev/null || echo "interactive"`
- Repo: !`awk '/^repo:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_REPO"}' .claude/task-context.md 2>/dev/null || echo "NO_REPO"`
- Item: !`awk '/^item:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_ITEM"}' .claude/task-context.md 2>/dev/null || echo "NO_ITEM"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`
- Feature dir: !`awk '/^feature_dir:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_DIR"}' .claude/task-context.md 2>/dev/null || echo "NO_DIR"`
- HEAD SHA: !`git rev-parse HEAD 2>/dev/null || echo "NO_HEAD"`
- Commits since main: !`git log --oneline origin/main..HEAD 2>/dev/null || echo "No commits"`
- Files changed: !`git diff --stat origin/main..HEAD 2>/dev/null || echo ""`

> **Tracker**: `../../reference/tracker.md`. Adapter: `../../reference/github-operations.md`. **Journal**: `../../reference/implementation-notes.md`. **State**: `../../reference/task-context.md`.

## Step 1: DETECT & CONFIRM

Resolve the item: parameter → `Item` from task-context → branch name → ask.

**Then verify it is still open** — `.claude/task-context.md` is only deleted with the worktree, so in a plain checkout it survives the merge still pointing at the finished item (`reference/task-context.md` § Lifecycle):

```bash
gh issue view {item} -R {repo} --json state,title --jq '"\(.state) — \(.title)"'
```

`CLOSED` = orphaned context, **not** the current task. Do not compose `Closes #{item}` on it: report the mismatch, re-resolve from the branch name, and if that yields nothing, stop and ask — a plan-reality mismatch, handled like any other. When the resolved item is closed *and* the branch has no Issue at all, offer to open one retroactively (Brief + AC derived from the actual diff) so `Closes #N` still holds.

```
Closing #{item} — {title}
Branch: {branch}   →   PR into main   {(draft) if --draft}
Correct? (Y/N)
```

**WAIT.** (Autonomous: proceed; `--draft` implied. An orphaned context is a hard stop even unattended — a wrong `Closes #N` is not recoverable by the human at review time.) (attended-auto: proceed, announcing the resolved item and branch in one line, and record a `D-NNN` when the item came from anywhere other than `task-context.md`. The orphaned-context stop binds here too, for the same reason.)

## Step 2: GATHER & SYNTHESIZE

Build the PR body from, in priority order:

- **The journal** `{feature_dir}/implementation-notes.md` (sealed) — the primary "why": `D-NNN` decisions, `T-NNN` tradeoffs, `V-NNN` deviations (+ linked decisions), answered `Q-NNN`. If it's still `status:living`, `/samuel:validate` didn't run — warn.
- **The Brief** (TL;DR + Acceptance Criteria → the test plan).
- **`validation.md`** (PASS/FAIL + manual checklist).
- **Commits & diff** (Context above).

Synthesize: Summary (2–3 sentences), Key files + why, Decisions, Plan deviations (cite the decision).

**Then compress once more into the TL;DR** — four lines, the first block of the PR body (spec: adapter § TL;DR). It is written *after* everything above, from those sources, never from the branch name or the Issue title:

- **What** — what the merged diff changes, observably. Not "implements the plan of #N".
- **Why** — the pain it removes. Usually already stated in the Issue's TL;DR; if the implementation changed the answer, the PR's version wins and the divergence is worth a sentence in `## Summary`.
- **Caveat** — the one thing that could bite a reviewer: a breaking change, a `V-NNN` deviation from the plan, a migration, an AC met differently than specified. Journal `V-`/`Q-` entries and `validation.md` findings are the honest source. `None` when there genuinely is nothing.
- **Chips** — `{n} files · +{a}/-{b}` (from the Context diff stat) · `risk {low|medium|high}` · `review ~{n} min`. Risk is about blast radius, not diff size: a two-line change to auth is `risk high`; a 400-line docs-only PR is `low`.

### DoD checklist

```
## DoD
- [x] Local gate green   - [x] AC verified   - [ ] {any unchecked}
Proceed? (Fix / Proceed)
```

**WAIT.** (Autonomous: proceed if all checked; else stop and hand off.) This gate **waits at every level, including `attended-auto`** — Step 3 has no checkpoint of its own, so this is the last stop before `git push` and `gh pr create`, and CRITICAL RULE 4 gates outward actions at every level.

## Step 3: PR

Check for an existing open PR for the branch (`gh pr list --head {branch} -R {repo}`) → reuse its URL. Check a remote exists.

```bash
git push -u origin {branch}
gh pr create -R {repo} --base main --head {branch} \
  {--draft when autonomous / requested} \
  --title "{type}({scope}): {description}" \
  --body "$(printf '%s\n' \
    '> **What:** {…}' '> **Why:** {…}' '> **Caveat:** {…}' '> `{chips}`' '' \
    '## Summary' '{…}' '' '## Changes' '{…}' '' '## Test plan' '- [ ] {AC}' '' 'Closes #{item}')"
```

- **`Closes #{item}`** is mandatory — it auto-closes the Issue on merge.
- **Title** = valid conventional commit (matches commitlint if present). **No AI attribution.**
- **Body opens with the TL;DR** — the body is a human surface; the title is pinned to conventional-commit form.
- Code cited in the body → **SHA permalinks** (adapter § Linking); the push above just made the branch SHA linkable.
- Then: `gh issue edit {item} -R {repo} --add-label pipeline:in-review --remove-label pipeline:in-progress`.

Present the PR URL (note **draft** if applicable: "CI will run; mark ready & merge when satisfied").

When the run was **autonomous** (the diff is agent-authored), additionally suggest the human run `/samuel:find-unknowns --quiz {PR}` before reviewing or merging — a comprehension gate on code nobody read line-by-line. The agent never runs it on its own work: a quiz the author grades itself is theater.

## Step 4: MARK COMPLETE

The `Closes #{item}` link closes the Issue at merge; until then it sits `pipeline:in-review`. Do **not** manually close it (let the merge do it). Report epic/related progress via `gh issue list` if relevant.

### Pipeline phase

Set `.claude/task-context.md` → `phase: end`, `last_updated: {today}` (worktree cleanup deletes it anyway; the PR/Issue is the surviving record).

### Durable knowledge at close (storage map: `../../reference/tracker.md`)

Homes for what outlives the task — evaluate each. Source: the journal (D/V/T/Q), `validation.md`, + this session.

**1. ADRs** (`docs/decisions/`) — the *reasoning*. Confirm any *durable/architectural* decision was written as an ADR (`docs/decisions/NNNN-slug.md`) committed on the branch, not left only as an Issue comment. If one was escalated in the journal but no ADR exists, write it now so it rides this PR.

**2. Dossier** (`docs/product/`) — the *product*. If `/samuel:validate` flagged a **product-behavior change**:
- *Interactive*: surface `/samuel:feature-dossier "{capability}"` so the dossier (`docs/product/<capability>/`) + README/CLAUDE.md pointer land in **this** PR.
- *Autonomous (`--draft`)*: don't run the heavy dossier pass — open a follow-up Issue:
  ```bash
  gh issue create -R {repo} --title "docs: dossier — {capability}" \
    --label "type:docs,pipeline:triage" \
    --body "Update the feature dossier for **{capability}** — changed by #{item} (PR {url}). Run /samuel:feature-dossier \"{capability}\"."
  ```

**3. CLAUDE.md learnings** — the *operating instruction*. Scan the journal + session for a **project-wide, generic** learning that would help *future* implementations — a build/test gotcha, a config/env quirk, a discovered command or workflow, a convention or re-architecture. **NOT** the task itself, **NOT** a one-off fix, **NOT** an architectural decision (that's an ADR) or a product capability (that's the dossier). Adopt `claude-md-management`'s discipline: keep only what's project-specific, recurring, and concise — **one line per concept** (`pattern` — brief why); drop obvious info, generic best-practice, and one-offs (the validation bar: "would a new session find this helpful, and is it the most concise form?").
- *Interactive*: propose the exact diff to the right file — root `CLAUDE.md` (team, in git), a module `CLAUDE.md`, or `.claude.local.md` (personal/gitignored) — each with a one-line **Why**, forced checkpoint, **never auto-edit**. Approved edits ride this PR. If `claude-md-management` is installed, you may delegate the refinement to `/claude-md-management:revise-claude-md`.
- *Autonomous (`--draft`)*: do **NOT** edit CLAUDE.md (global, high-impact, affects every future session). List the candidate line(s) + target file in the stop report and PR body for human review.

**4. README.md** — the *human front door*. Did this change alter how a human **installs, configures, runs, or understands** the project? (A new dependency/prerequisite, a required env var, a new command/script, a significant user-facing capability, changed setup/quickstart.) If yes, propose a **surgical** update to the matching section per `../../reference/readme-guidelines.md` (structure + philosophy + the promotion filter). **NOT** internal refactors/bugfixes (invisible to a getting-started human), a gotcha for agents (→ CLAUDE.md), or a capability's deep doc (→ its dossier — the README gets only the one-line pointer, handled by `/samuel:feature-dossier`).
- *Interactive*: propose the exact diff to the right section with a one-line **Why**, forced checkpoint, **never auto-edit**; approved edits ride this PR.
- *Autonomous (`--draft`)*: list the candidate + target section in the PR body / stop report; don't edit unattended.

**5. REVIEW.md** (root, when present) — the *reviewer override*. Propose **one surgical bullet** in the fitting section when this cycle surfaced a repo-wide review rule: a Convention finding in `validation.md`, a Step 2.5 reviewer finding that generalizes beyond this diff, or a `remove-slop` pattern that keeps coming back. Cite the evidence (journal entry ID / validation finding) at the checkpoint; the committed bullet stays flat (schema v1) and respects the ≤30-line budget — **replacing a weaker rule beats growing the file**. Generation/regeneration stays `/samuel:create-review-md`; this is an append, never a rewrite.
- *Interactive*: propose the bullet + its section, forced checkpoint; approved edits ride this PR.
- *Autonomous (`--draft`)*: list the candidate bullet in the PR body; don't edit unattended.

**CONSTITUTION.md is detect-and-route, never edited here** — amendments carry governance (semver + Sync Impact Report) owned by `/samuel:update-constitution`. Candidate signals: a `Decision — constitution` comment on the Issue, a journal `V-NNN` referencing a MUST, a Complexity Tracking justification that recurs across items. *Interactive* → offer the skill as a post-close step. *Autonomous* → follow-up Issue titled `governance: constitution — {principle}`.

### Promo markers — what shipped, and how it was built

Two independent axes, evaluated separately. Both are metadata, not content: **autonomous runs apply them too** (same class as the pipeline flip). Confirmed → apply here (Step 3 already flipped the status label; this is a separate edit). Neither label may exist in older repos and `--add-label` fails on unknown labels, so create idempotently first.

**`promo:blog` — user-facing.** The shipped change is user-visible (a new capability, a design/UX change, pricing/billing, anything a user would notice). Marks the feature for release-time content; precision comes from marking here, where the context lives, not from parsing changelogs later.

```bash
gh label create promo:blog -R {repo} -c D4AF37 -d "User-facing: blog/social candidate at release" 2>/dev/null || true
gh issue edit {item} -R {repo} --add-label promo:blog
```

**`promo:bip` — building in public.** The *cycle* is the story, for other builders: a hard number of your own (USD/turns/tokens/ms/counts — the run report of an autonomous run is a ready-made one), a change to the system itself (a skill, a workflow, model routing, governance), an autonomous run that shipped solo or failed instructively, or a reversal worth telling. The journal is the source — `T-NNN` rejected alternatives and `V-NNN` deviations are where the story usually is. Skip it on routine work with no process story, and skip it when the material can't be told without internal company data.

Applying it posts the **angle comment** in the same turn (format + harvest query: adapter § `promo:bip`) — a bare label loses *why* it was marked:

```bash
gh label create promo:bip -R {repo} -c C77DFF -d "Building in public: process/tooling story for LinkedIn/X" 2>/dev/null || true
gh issue edit {item} -R {repo} --add-label promo:bip
gh issue comment {item} -R {repo} --body "$(cat <<'EOF'
<!-- samuel:bip -->
**Pillar:** {A autonomous runs | B system/skills | C product}
**Hook:** {one line carrying the hard number}
**Evidence:** {journal D-003, V-001 · PR #N · run report}
EOF
)"
```

## Step 5: CLEANUP

```
Return to main? 1) Yes (PR is open)   2) Stay on the branch for post-review changes
```

If yes: `git checkout main && git pull origin main 2>/dev/null || true`. Never delete the branch/worktree without explicit confirmation. (attended-auto: take option 1 and say so — the PR is open, so the branch is preserved either way and the choice is reversible with one `git checkout`. Branch/worktree deletion keeps its confirmation at every level.)

### Final summary

```
{item} closed.
- PR: {url}  {(draft — CI running)}
- Issue: #{item} → in-review, closes on merge
- Branch: {on main | on branch}

Next: /samuel:next  ·  /samuel:progress
{- /samuel:feature-dossier "{capability}"  ← only if this changed product behavior}
```

## Pipeline Position

```
/samuel:implement → /samuel:validate → /samuel:done
                                            ↑ YOU ARE HERE
```

## Gotchas

_Add a line each time Claude trips on something._

- Don't manually `gh issue close` — `Closes #N` in the merged PR does it. Manually closing orphans the PR link.
- **`phase: end` in task-context means "suspect", not "current".** Outside worktree mode nothing deletes the file, so it survives the merge pointing at the finished item. In #37 (`promo:bip`) the context still read `item: 25`, closed two PRs earlier — one unverified step from a `Closes #25` on unrelated work. Step 1's state check exists for exactly this.
- The PR's TL;DR is not a copy of the Issue's. The Issue's was written before the work; this one reports what the work actually did — including where it diverged.
- On an autonomous `--draft` run the TL;DR matters more, not less: it's the only part of a PR nobody watched being written that a human is guaranteed to read.
- `--draft` is the autonomous default: the agent opens the PR, the human marks ready (`gh pr ready N`) + merges. Interactive runs may open ready-for-review.
- PR title must satisfy commitlint if the repo has it.
- `.claude/` is local — keep `.claude/` gitignored so task-context/samuel.md never land in a commit.
- Push only with authority. The conductor opens the PR as the *last* autonomous step, never mid-implement.
