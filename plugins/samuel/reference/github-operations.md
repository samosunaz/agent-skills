# GitHub Operations

**GitHub Issues are the single source of truth** for the samuel pipeline, and the `gh` CLI is the only interface (**no GitHub MCP**). A work item is one Issue; its body carries both the human **Brief** and the self-contained **Executor Plan**; a PR closes it; green CI is the merge gate. Built for unattended/cloud sessions.

## Why gh-only (no MCP)

The target environment has `gh` authenticated but **no GitHub MCP server**. Do not search for or assume `mcp__github__*` tools. Everything is `gh` subcommands, which work headless (droplet, cron, `claude -p`).

## Repo resolution — the SSH-alias problem

The origin remote may be an SSH alias (e.g. `git@github.com-samosunaz:owner/repo.git`, not literal `github.com`). This **breaks naïve owner/repo detection** — never parse `git remote get-url`. Resolve the repo two ways, both explicit:

1. **One-time setup (idiomatic):** `gh repo set-default owner/repo`. This writes an explicit resolution into git config and bypasses URL parsing, so subsequent `gh issue`/`gh pr` commands work **without `-R`** even behind the alias. Run it once per clone/worktree.
2. **Per-command (belt-and-suspenders):** pass `-R owner/repo` on every **write** (`issue create/edit/comment`, `pr create`). The pipeline stores `repo: owner/name` in `.claude/task-context.md` frontmatter (set by `/samuel:start-task`); read it in the skill body and pass it as `-R`.

> **Multi-account note.** `gh` may be authenticated as a personal identity (e.g. `samosunaz`) distinct from a work identity that has **no access** to the repo. Trust `gh auth status` + `gh repo view owner/repo`, not the git user.email. If `gh repo view owner/repo` fails with 404, it is an auth/account problem, not a missing repo.

### Detection at skill start

```bash
gh auth status                       # confirm authenticated
gh repo view owner/repo --json nameWithOwner -q .nameWithOwner   # confirm access (explicit owner/repo)
```

If `gh` is missing → tell the user: `"gh CLI required. Install: https://cli.github.com"`. If `gh repo view owner/repo` 404s → wrong account or no access; stop and report. If no default is set and no `repo` is known → ask the user once, then `gh repo set-default owner/repo`.

## TL;DR — the human scan block

**Every Issue and PR body opens with it.** Four lines, read in ten seconds, that answer: do I engage with this now, and how hard?

The rest of the body is written for agents — a cold executor needs the full plan, the reviewer needs the diff rationale. A human deciding whether to *enter* needs neither. Without the block, the only way to triage is to read agent-facing prose at agent-facing volume, which is where the human becomes the bottleneck.

```markdown
> **What:** {the observable change — one sentence, start with the verb}
> **Why:** {the pain it removes, or the bet it opens}
> **Caveat:** {the one thing that can bite — breaking change, pending decision, risk. "None" is a valid and frequent answer}
> `{chips}`
```

Chips differ by surface, everything above them doesn't:

| Surface | Chips | Written by |
|---|---|---|
| Issue (`pipeline:*`) | `` `{S\|M\|L}` · `risk {low\|medium\|high}` · `~{estimate}` `` | `/samuel:plan`; `kickoff` and `repo-audit` at capture |
| Roadmap bet (`roadmap:*`) | `` `{S\|M\|L}` · `confidence {high\|medium\|low}` · `{now\|next\|later}` `` | `/samuel:roadmap` |
| PR | `` `{n} files · +{a}/-{b}` · `risk {low\|medium\|high}` · `review ~{n} min` `` | `/samuel:done` |

Estimates go in concrete units (`~2 h`, `~1 afternoon`), never "some work" — the number is what a context-switch decision is made on.

Size chip on an Issue doubles as a split signal: **S** = 1–2 files, local, no design decision · **M** = 3–4 files or one design decision · **L** = beyond that, so check § Sizing in `plan-templates.md` before planning it.

### What kills a TL;DR

- **Restating the title.** The reader just read it. Add the thing the title couldn't fit.
- **Listing files or steps.** That's the Executor Plan / the diff, two scrolls down.
- **Opening with "Este PR implementa…" / "Este issue busca…".** Start at the change itself.
- **Writing it first.** It's a *synthesis*: compose the body, then compress downward. On a PR that means after the journal and `validation.md` are read, not before.
- **A `Caveat:` that needs two lines.** That's not a warning, that's an unscoped item — split it or plan it.

No HTML marker of its own: on an Issue it's the first block *inside* `<!-- samuel:brief -->`, on a PR it's the first block of the body. Skills that splice a section already carry it along verbatim.

**One exemption**, so the block stays signal and not ritual: a mechanical follow-up whose entire body is a single instruction line (`docs: dossier — {capability}`, `governance: constitution — {principle}`) is already its own TL;DR. Everything a human plans, reviews, or merges carries the block.

### The block only renders on GitHub conversational surfaces

Issue bodies, PR bodies, and comments render with **hardbreaks on** — each newline becomes a `<br>`, so the four lines stay four lines. Committed `.md` files don't: the same block collapses into one run-on paragraph. Verified against `gh api /markdown`:

```bash
gh api /markdown --method POST -f mode=gfm      -f text='> **What:** a
> **Why:** b'   # → <p>…a<br> …b</p>   ✅ four lines
gh api /markdown --method POST -f mode=markdown -f text='> **What:** a
> **Why:** b'   # → <p>…a …b</p>       ❌ collapsed
```

So the block belongs to Issues and PRs and nowhere else. Don't lift it into a dossier, `ROADMAP.md`, or any committed doc — those need explicit `<br>`, two trailing spaces, or a list, and at that point you want that file's own format, not this one.

### Holding the convention outside the skills

Items opened by hand in the GitHub UI never touch a skill, so they're where the convention rots first. `.github/ISSUE_TEMPLATE/work-item.md` and `.github/PULL_REQUEST_TEMPLATE.md` in this repo pre-fill the block (plus the brief/plan markers) — copy both into a consumer repo to get the same floor there. They don't interfere with the pipeline: `gh issue create --body` / `gh pr create --body` bypass templates entirely, so skills keep full control of the body they compose.

## The work-item model — one Issue, two sections

A samuel work item is a single GitHub Issue. Its **body** has two marker-delimited sections carrying three reading speeds, so one artifact serves a human triaging, a human reviewing, and an agent executing:

```markdown
<!-- samuel:brief -->
> **What:** {…}
> **Why:** {…}
> **Caveat:** {…}
> `{chips}`

## Brief
**Scope:** {1–2 lines, what's in}
**Out of scope:** {what's explicitly not}

### Acceptance Criteria
- [ ] AC1: {measurable outcome}
- [ ] AC2: {measurable outcome}

<!-- samuel:plan -->
## Executor Plan
> Self-contained. Assumes zero prior context. Written for an autonomous executor.
{full plan — see reference/plan-templates.md for the section schema}
```

Three reading speeds, one artifact:

- **TL;DR** = ten seconds. Triage: engage now or not.
- **Brief** = one screen, human-facing. Prioritize, review, check the AC.
- **Executor Plan** = agent-facing. Self-contained: a cold agent with no chat history executes from it alone.
- The `<!-- samuel:brief -->` / `<!-- samuel:plan -->` HTML-comment markers let skills locate and rewrite a single section without disturbing the other (GitHub renders them invisibly).
- A freshly-captured idea may have a TL;DR + Brief and **no plan yet** (`pipeline:triage`). `/samuel:plan` fills the Executor Plan section and flips the label to `pipeline:planned`.

Templates for both sections live in `reference/plan-templates.md`.

## Labels — the status & routing surface

Labels carry coarse status (the fine-grained `phase` stays local in `task-context.md`). Namespaced to avoid clashing with the repo's own labels. Create them once per repo:

```bash
gh label create "roadmap:now"          -R owner/repo -c 0E8A16 -d "Active bet — next to commit (discovery)" --force
gh label create "roadmap:next"         -R owner/repo -c FBCA04 -d "Seriously considered, behind Now (discovery)" --force
gh label create "roadmap:later"        -R owner/repo -c C5DEF5 -d "Parked option, revisit (discovery)" --force
gh label create "pipeline:triage"      -R owner/repo -c FBCA04 -d "Brief captured, no executor plan yet" --force
gh label create "pipeline:planned"     -R owner/repo -c 1D76DB -d "Executor plan written" --force
gh label create "pipeline:ready"       -R owner/repo -c 0E8A16 -d "Planned + unblocked — autopilot may pick it up" --force
gh label create "pipeline:in-progress" -R owner/repo -c D93F0B -d "Branch open, implementing" --force
gh label create "pipeline:in-review"   -R owner/repo -c 5319E7 -d "PR open, awaiting human merge" --force
gh label create "pipeline:blocked"     -R owner/repo -c B60205 -d "Blocked by a dependency or open question" --force
gh label create "promo:blog"           -R owner/repo -c D4AF37 -d "User-facing: blog/social candidate at release" --force
gh label create "promo:bip"            -R owner/repo -c C77DFF -d "Building in public: process/tooling story for LinkedIn/X" --force
```

| Dimension | Labels | Owner |
|---|---|---|
| Roadmap *(discovery)* | `roadmap:now` → `roadmap:next` → `roadmap:later` | `/samuel:roadmap` — bets not yet committed |
| Status *(delivery)* | `pipeline:triage` → `planned` → `ready` → `in-progress` → `in-review` (close on merge) | the pipeline skills |
| Type | `type:feat` `type:fix` `type:refactor` `type:perf` `type:chore` `type:docs` `type:test` | maps to branch prefix + PR/commit type |
| Priority | `priority:high` `priority:medium` `priority:low` | sorting in `/samuel:next` |
| Promo *(release markers)* | `promo:blog` (what shipped) · `promo:bip` (how it was built) | proposed by `/samuel:done` Step 4 — metadata, applied in every mode |

> **`roadmap:*` (discovery) and `pipeline:*` (delivery) are mutually exclusive** on an issue. `/samuel:roadmap` proposes bets as `roadmap:*`; committing one swaps it for `pipeline:triage`. See `reference/product-ownership.md`.
> **`promo:blog` marks a shipped capability as user-facing** — precision comes from marking it at close, where the context lives, not from parsing changelogs at release time. It stacks on top of the status label and survives the close; it is not part of the status machine.
> **`promo:bip` marks the *making of*** — the same instinct on the process axis: this cycle produced a story for **other builders**, not for users. Orthogonal to `promo:blog`; a user-facing feature built in a notable way carries both.
> `pipeline:ready` is the autopilot inbox: an issue that is planned **and** has no unmet dependency. Only `ready` issues are eligible for unattended pickup.

### `promo:bip` — the building-in-public marker

Fires when the cycle produced at least one of: a **hard number of your own** (USD, turns, tokens, ms, counts), a change to the **system itself** (a skill created or improved, a workflow, model routing, governance), an **autonomous run** that shipped solo or failed instructively, or a **reversal/surprise** worth telling. It does *not* fire on routine feature work with no process story, and it does *not* fire on material that can't be told without internal company data — generalize it or leave the label off.

The label alone loses the angle: months later the only way to recover *why* it was marked is to re-read the whole PR. So applying it posts one comment, written where the context is alive:

```bash
gh issue comment N -R owner/repo --body "$(cat <<'EOF'
<!-- samuel:bip -->
**Pillar:** A (autonomous runs) · B (system/skills) · C (product)
**Hook:** {one line carrying the hard number}
**Evidence:** {journal D-003, V-001 · PR #N · run report}
EOF
)"
```

A `Hook` with no real number of your own is usually the tell that the item isn't a story yet. Harvest the queue with:

```bash
gh issue list -R owner/repo --state all --label "promo:bip" --json number,title,url,closedAt --jq 'sort_by(.closedAt)'
```

## Issue dependencies — the native DAG

GitHub Issues carry first-class dependencies (`blockedBy` / `blocking`), exposed on **both APIs**: REST for the single-issue read, GraphQL for the batched set query and the write mutations. They are the pipeline's dependency graph: declared explicitly at planning time, read by coordinators (`/samuel:waves`) to compute execution order. Never infer dependencies from titles or body text when the native edge can be declared.

### Read an issue's blockers

REST is the short path for one issue. Caution: REST `state` is lowercase (`open`/`closed`), GraphQL yields `OPEN`/`CLOSED` — never mix the two cases in one satisfaction check:

```bash
gh api repos/OWNER/REPO/issues/N/dependencies/blocked_by --jq '.[] | {number, state}'
```

The GraphQL shape (same fields; the building block for the batched set query below):

```bash
gh api graphql -f query='query {
  repository(owner: "OWNER", name: "REPO") {
    issue(number: N) {
      blockedBy(first: 50) { nodes { number state title } }
    }
  }
}' --jq '.data.repository.issue.blockedBy.nodes'
```

**Satisfaction rule:** a blocker is satisfied only when its `state` is `CLOSED`. For pipeline items that happens through the merged PR's `Closes #N` — so "blocker closed" and "blocker's code is on `main`" coincide by construction. An OPEN blocker parks the issue regardless of its labels: `pipeline:ready` + an open blocker means *eligible later*, not *dispatchable now*.

### Read the graph for a set (one call, no N+1)

Batch with aliases instead of looping single queries:

```bash
gh api graphql -f query='query {
  repository(owner: "OWNER", name: "REPO") {
    i42: issue(number: 42) { number blockedBy(first: 50) { nodes { number state } } }
    i43: issue(number: 43) { number blockedBy(first: 50) { nodes { number state } } }
  }
}' --jq '[.data.repository | to_entries[].value]'
```

### Declare an edge (write)

Two steps — resolve node IDs, then mutate. Re-adding an existing edge **fails loudly** (`Validation failed: Target issue has already been taken`, non-zero exit) while leaving the graph correct — no duplicate edge is created. So recipes must **read-then-add** (fetch current blockers, add only the missing edges), the same list-first idempotence rule as § Blast radius — never blind-add inside a loop that dies on the first existing edge:

```bash
gh api graphql -f query='query {
  repository(owner: "OWNER", name: "REPO") {
    blocked:  issue(number: N) { id }
    blocker:  issue(number: M) { id }
  }
}' --jq '.data.repository'
# then, with the two IDs:
gh api graphql -f query='mutation {
  addBlockedBy(input: {issueId: "ID_BLOCKED", blockingIssueId: "ID_BLOCKER"}) {
    issue { number }
  }
}'
```

`removeBlockedBy` takes the same input shape. Declare edges at planning time (`/samuel:plan`, `/samuel:roadmap` when committing a multi-item bet) — a graph declared after dispatch is a graph nobody executed.

> **Guards.** GraphQL emits real JSON `null`s, so `--jq` over these results doesn't hit the `gh --jq` empty-list trap directly — but the moment a recipe post-processes with `.[0]` or string interpolation, the repo rule applies unchanged: `.[0]//empty`, never a bare `.[0].x` (see CLAUDE.md § Critical Patterns). An issue with no blockers returns `nodes: []` — iterate it; don't index it.

## Issue operations

### List the autopilot inbox (pickable work)

```bash
gh issue list -R owner/repo --state open --label "pipeline:ready" \
  --json number,title,labels,assignees --jq 'sort_by(.number)'
```
Sort by `priority:*` then number. For a human menu in `/samuel:next`, also list `pipeline:planned` and `pipeline:triage`.

### Read a work item (the autonomous-pickup contract)

A cold agent gets **everything** from one call — no branch, no path, no chat history needed:

```bash
gh issue view N -R owner/repo --json number,title,body,labels,comments
```
The `body` contains Brief + Executor Plan. The `comments` contain recorded decisions, `Upstream decision` impact notices (§ Blast radius), and the validation summary. This single command is the contract that makes issue-as-SoT work for headless pickup — `comments` is part of it, not an extra.

### Create a work item

```bash
gh issue create -R owner/repo \
  --title "{type}: {imperative summary}" \
  --label "type:feat,priority:medium,pipeline:triage" \
  --body "$(cat <<'EOF'
<!-- samuel:brief -->
> **What:** ...
> **Why:** ...
> **Caveat:** ...
> `M` · `risk low` · `~2 h`

## Brief
...
<!-- samuel:plan -->
## Executor Plan
_Not planned yet — run /samuel:plan._
EOF
)"
```
Capture returns the issue URL/number — record it. The TL;DR is not optional at capture — an issue born without one gets triaged by reading its plan, which is the failure mode § TL;DR exists to prevent.

### Edit one body section (fetch → splice → write)

`gh` has no section-level edit. Fetch the body, replace the target marker block, write it back:

```bash
gh issue view N -R owner/repo --json body -q .body > /tmp/issue-N.md
# splice between <!-- samuel:plan --> and EOF (or the next marker) in the skill body using Read/Edit
gh issue edit N -R owner/repo --body-file /tmp/issue-N.md
```
Always preserve the other marker block verbatim. `--body` replaces the **entire** body — never pass a partial body without the brief.

### Transition status

```bash
gh issue edit N -R owner/repo --add-label "pipeline:planned" --remove-label "pipeline:triage"
gh issue edit N -R owner/repo --add-label "pipeline:in-progress" --remove-label "pipeline:ready"
```

### Check / uncheck acceptance criteria

AC live as a task-list in the Brief. To check one, fetch the body, flip `- [ ]` → `- [x]` for that line, write it back (same fetch→splice→write as above). The PR closing the issue is the durable record; this is for live visibility.

## Decisions — three levels by durability

GitHub has no native durable-decision index — Issue comments die when the Issue closes. So route decisions by **how long they matter**:

1. **Sub-threshold** (D/V/T/Q) → the committed **journal** `{feature_dir}/implementation-notes.md` (Read/Edit/Write directly). Schema: `reference/implementation-notes.md`.
2. **Task-level** (plan-reality mismatch, an approach pivot inside the task) → an **Issue comment**, visible in the timeline and folded into the PR body by `/samuel:done`:
   ```bash
   gh issue comment N -R owner/repo --body "**Decision (phase: {phase}):** {what} — **Why:** {why}."
   ```
   Also record the matching `D-NNN`/`V-NNN` in the journal, linking to the comment.
3. **Durable / architectural** — the ones you'll want to find months later, independent of this task ("D1 over KV", "multi-processor payments") → a committed **ADR** at `docs/decisions/NNNN-slug.md`. This is the **only durable record**: Issue comments die with the Issue; an ADR is git-versioned and persists. It rides the feature branch, so it merges atomically with the code it justifies. The Issue comment links to it.

> Rule of thumb: matters only to *this* task → a comment. Constrains *future* work → write the ADR. Most are comments; few are ADRs.

### ADR format (lightweight MADR)

```markdown
# {NNNN}. {title}

- **Status**: accepted | superseded by ADR-{MMMM} | deprecated
- **Date**: {ISO}
- **Item**: #{issue}

## Context
{the problem and the forces at play}

## Decision
{what was chosen}

## Consequences
{trade-offs — what this enables and what it costs}
```

Number sequentially (`0001-…`); the `docs/decisions/` directory is the index (GitHub renders it, `ls`/grep find it) — the durable layer for architectural decisions.

### Validation summary

Post the `/samuel:validate` PASS/FAIL + manual checklist as an Issue comment, so the timeline tells the whole story.

## Blast radius — propagating decisions across issues

A recorded decision sometimes constrains work **outside its own Issue**: sibling sub-issues under the same parent, or issues whose Brief declares `Depends on:` the current one. Comments and journals are per-issue surfaces — without an explicit push, the affected issues execute plans the decision just invalidated. `/samuel:implement`'s blast-radius step (e.1) owns the push; these are its recipes.

### Discover the affected set

```bash
# parent (is this a sub-issue?) — GraphQL only; REST doesn't surface it
gh api graphql -f query='query { repository(owner: "{owner}", name: "{name}") {
  issue(number: {N}) { parent { number title state } } } }'

# siblings — open children of that parent, minus self
gh api "repos/{owner}/{repo}/issues/{parent}/sub_issues" --jq '.[] | select(.state == "open") | {number, title}'

# dependents — issues declaring a dependency on this one (text search — confirm each hit's Depends-on line before trusting it)
gh issue list -R {owner}/{repo} --state open --search '"Depends on: #{N}" in:body' --json number,title,labels
```

### Assess, then post — one comment per affected issue

Read each candidate's Brief + Executor Plan and classify: **unaffected** (report only, no write) · **aware** (context changed, plan holds → comment only) · **invalidated** (approach/AC no longer hold → comment + label). The comment:

```markdown
**Upstream decision — from #{A}:** {the decision, one line}
**Why:** {reason}
**Impact here:** {what in this issue's Brief/plan is affected}
**Refs:** {decision comment URL · ADR path}

Re-plan before pickup: `/samuel:refine-plan {this issue}`.
```

(The `#{A}` reference is deliberate — it plants a backlink on the deciding issue's timeline, so the propagation is navigable from both ends.)

Label rules, by the affected issue's state:

- `pipeline:ready` + invalidated → demote to `pipeline:planned` — the autopilot must never pick up a plan known to be stale.
- Now blocked on unresolved follow-up work → `pipeline:blocked`.
- `pipeline:in-progress` (another session is working it) → comment only; never touch its labels.

### Safety & idempotence

- **Checkpoint before writing**: posting to other issues is outward-facing — `/samuel:implement` presents the full impact map and WAITs for approval before any cross-issue write.
- **Never cross-post unattended**: a conductor run folds the candidate impact map into its handoff/stop report instead; the human posts after review.
- **Idempotent re-runs**: before posting on an issue, list its comments and skip if an `Upstream decision — from #{A}` for the same decision already exists (list-first, skip-and-report).

## Closing — dossier & doc follow-ups

When a change alters product behavior, the living **feature dossier** (`docs/product/<capability>/README.md`) and any README/CLAUDE.md pointer are **committed on the feature branch and ride the same PR** — code + docs merge atomically. Two paths at close:

- **Interactive** — `/samuel:validate` (doc-impact) and `/samuel:done` surface `/samuel:feature-dossier "{capability}"`; running it updates the dossier in the branch, so it lands in the PR.
- **Autonomous (`--ship`)** — don't inflate the run with the heavy dossier pass (sub-agents + Mermaid). Instead `/samuel:done` opens a **follow-up Issue** so it isn't lost:
  ```bash
  gh issue create -R owner/repo --title "docs: dossier — {capability}" \
    --label "type:docs,pipeline:triage" \
    --body "Update the feature dossier for **{capability}** — changed by #{item} (PR {url}). Run /samuel:feature-dossier \"{capability}\"."
  ```
  It enters the inbox as a normal work item, planned/executed later like any other.

## PR operations

```bash
gh pr create -R owner/repo --base main --head {branch} \
  {--draft for autonomous runs} \
  --title "{type}({scope}): {description}" \
  --body "$(cat <<'EOF'
> **What:** ...
> **Why:** ...
> **Caveat:** ...
> `4 files · +120/-30` · `risk low` · `review ~5 min`

## Summary
{synthesized from journal + brief + commits}

## Changes
{key files}

## Test plan
- [ ] {from acceptance criteria}

Closes #N
EOF
)"
```

- **`Closes #N`** in the body auto-closes the issue on merge — the link that ties PR ↔ issue. Always include it.
- **`--draft`** for unattended runs: the agent opens the PR, CI runs, the human reviews → marks ready → merges. Interactive runs may open ready-for-review directly.
- **Title** = valid conventional commit (matches commitlint if present). **No AI attribution**, ever.
- **Body** opens with the TL;DR block (§ TL;DR) — Spanish, four lines, written last. `## Summary` is the agent-facing layer underneath it, not a substitute: a summary explains the change, the TL;DR decides whether it gets read.
- After creating: `gh issue edit N --add-label "pipeline:in-review" --remove-label "pipeline:in-progress"`.

## Enumeration IDs — `#` is for GitHub artifacts only

On any GitHub-rendered surface (issue bodies, comments, PR bodies), `#{n}` is a **reference**, not a number — GitHub autolinks it to Issue/PR {n} and plants spurious backlinks on unrelated timelines. The rules:

- `#N` / `owner/repo#N` — **only** when referencing an actual Issue or PR.
- Everything else that needs enumeration uses **element-initial IDs**: `{INITIALS}{n}`.
- Table columns are `| ID |`, never `| # |`. Markdown ordered lists (`1.`) are fine — they don't autolink.

| Element | IDs | Surface |
|---|---|---|
| Review findings (severity in the ID) | `B{n}` `I{n}` `N{n}` (Blocker · Important · Nit) | validation report, PR comments |
| Brief Acceptance Criteria | `AC{n}` — issues born before 2026-07 carry `SC-{n}`; both readable | Issue body |
| Spec | `FR-###` (functional requirements) · `SC-###` (success criteria) | spec.md (committed) |
| Journal | `D-NNN` `V-NNN` `T-NNN` `Q-NNN` | implementation-notes.md (committed) |
| Unknowns audit | `U{n}` (unknowns) · `Q{n}` (quiz questions) | find-unknowns output |
| User Story priority | `P1` `P2` `P3` | spec.md |

## Linking — references that never rot

Dense linking is what makes the Issue-as-SoT navigable years later. The rules, by surface:

| Reference | Write it as | Why |
|---|---|---|
| Issue/PR, same repo | `#N` | GitHub autolinks + backlinks the timeline |
| Issue/PR, cross-repo | `owner/repo#N` | same, across repos |
| The delivering PR → its Issue | `Closes #N` — only in that PR | auto-close on merge; anything else uses plain `#N` |
| Code cited in **durable docs** (ADRs, dossiers) | **permalink with SHA** (recipe below) | a `blob/main/...` link rots when the file moves; the SHA link points at the exact code that motivated the decision, forever |
| Code cited on **GitHub conversational surfaces** (Issue Briefs & comments, PR bodies, review findings) | **permalink with SHA** when the commit is on the remote; plain `path:line` only while it isn't | plain text isn't clickable and rots silently; a permalink on its own line renders the snippet inline in the thread |
| Code in **living docs** (feature dir, journal) | `path/to/file.ts:42` relative | these ride the branch and should follow it |

```bash
# permalink to file:line at the current commit (durable docs + GitHub surfaces); line ranges: #L42-L57
echo "https://github.com/{owner}/{repo}/blob/$(git rev-parse HEAD)/path/to/file.ts#L42"
# human shortcut: open the file on GitHub and press "y" (canonicalizes the URL to the SHA)
```

Two guards on the permalink rule: the SHA must be **on the remote** — a permalink to an unpushed commit 404s, so pre-push surfaces (e.g. the `/samuel:validate` summary comment) fall back to plain `path:line`. And the Executor Plan's `### Relevant code` is the deliberate exception: plain relative paths, because the pickup drift check machine-reads them (`plan-templates.md`).

## CI as the merge gate

The repo's CI (e.g. `.github/workflows/ci.yml` running `bun run gate`) is the gate. Two checkpoints:

1. **Local, before the PR:** the conductor/validate runs the project's gate command (`bun run gate` or equivalent) and refuses to open a non-draft PR on a red gate. Fail fast, locally.
2. **Remote, on the PR:** CI re-runs on push. `gh pr checks N -R owner/repo` reports status. Merge only on green — that decision stays human.

## Gotchas

_Add a line each time Claude trips on something._

- **Never parse `git remote get-url`** for owner/repo — the SSH alias breaks it. Use `gh repo set-default` + explicit `-R`, or read `repo` from task-context.
- `-R owner/repo` is mandatory on writes when a default isn't set; harmless when it is. When in doubt, pass it.
- `gh issue edit --body` / `--body-file` **replaces the whole body**. Always include both marker sections — splicing one section means re-emitting the other unchanged.
- `gh repo view owner/repo` 404 = wrong `gh` account or no access (multi-account setup), not a missing repo. Check `gh auth status`.
- No `mcp__github__*` tools exist in this environment. Don't reach for them.
- `--jq` needs `gh`'s built-in jq expression syntax; pipe to a real `jq` only if installed.
- Draft PRs don't trigger some required checks until marked ready — `gh pr ready N` when the human is satisfied.
- `gh label create` is not idempotent without `--force` (errors if the label exists). Use `--force` in setup.
- Issue body task-lists (`- [ ]`) render as checkboxes only at the top level of the body; nested ones under a section still work but GitHub's progress bar only counts top-level. Keep AC at the Brief's top level.
- **Blast-radius comments are outward-facing writes** — human-approved, idempotent (list the target's comments first; skip when an `Upstream decision` for the same decision already exists), and never posted by an unattended run.
- The TL;DR block relies on GitHub's hardbreak rendering, which is **on** for Issue/PR bodies and comments and **off** for committed `.md` files (§ TL;DR). Same text, two renderings — verify with `gh api /markdown -f mode=gfm` before assuming a multi-line block survives.
- Issue and PR templates in `.github/` shape only the **web UI**; `gh issue create --body` / `gh pr create --body` ignore them entirely. A template can't break a skill, and a skill won't pick up a template's improvements — keep both in sync by hand.
- **An issue's `parent` is GraphQL-only** — `gh issue view` and the REST issue payload don't surface it; sibling discovery goes parent-first (GraphQL `parent`, then REST `sub_issues` on the parent).
