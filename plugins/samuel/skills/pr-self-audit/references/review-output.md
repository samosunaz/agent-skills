# Review output — comment format and publish mechanics

> Spoke of `../SKILL.md` (Steps 5 and 6). The hub decides what the verdict is; this file carries how
> the comment is shaped, how the publication checkpoint is rendered, and the API mechanics that send
> it. Checkpoint rendering itself is `../../../reference/interaction-tools.md`; the severity and
> category vocabulary is `../../../reference/review-rubric.md`.

## Passes — the marker and the scope

A PR gets reviewed more than once. The memory of that lives in GitHub, not in the session: the first
line of every review body is an HTML marker.

```
<!-- samuel:review-pass P={P} findings={B1,I2,N1} -->
```

It carries **only what GitHub does not store**. The reviewed SHA, the author, the state and the date
already come back in `reviews[]` (`commit.oid`, `author.login`, `state`, `submittedAt`); repeating
them here would be the redundancy the comment avoids in its visible half. `P` is the pass number,
`findings` the IDs that pass raised — `B{n}` · `I{n}` · `N{n}`, numbered within each severity
(§ Enumeration IDs in `../../../reference/github-operations.md`: `#` never enumerates on a GitHub
surface, it autolinks).

**It is an HTML comment on purpose.** It does not render, so the visible format can change without
breaking whoever reads it by machine — and someone does: the author side
(`../../address-pr-comments/references/pr-comment-resolution.md` § Pass markers) recognizes a review
from this skill by this marker, not by its heading.

**Reading it back.** Step 2's fetch already brought the payload; this is a filter over it, not a new
call:

```jq
.reviews[] | select(.body | startswith("<!-- samuel:review-pass"))
| {id, state, sha: .commit.oid, author: .author.login, marker: (.body | split("\n")[0])}
```

`startswith` on the **prefix**, never `contains("<!-- samuel:review-pass -->")`: the real marker
carries `P=` and `findings=` inside it, so the short closed form matches no body at all.

`P` = your **own** previous passes + 1 (filter by the Context's `gh login`). With no marker of your
own, `P` = 1 and the run is a full sweep — the degenerate case needs no separate branch in the logic.

### The scope line

When the run is a delta, the comment opens by declaring what it covers. It is the only part of the
header not derivable from what GitHub already renders around it:

> Pass {P} (delta) against `{short sha}`. Re-verifies {IDs from the previous pass}; the rest is not re-litigated.

Without it, "no findings" reads as "I reviewed everything" when it can mean "I reviewed two nits".
Mandatory in delta mode, omitted entirely on the first pass.

## Review report format

**The first two lines are not optional.** The marker is what lets the next pass know this one existed;
without it `P` returns to 1 forever and the author side stops recognizing the pipeline. The scope line
appears only in delta mode.

**Every finding carries its ID in the heading.** That is the only thing making it addressable across
passes: without it you cannot compose `findings=`, and delta mode's "Re-verifies {IDs}" would point at
something the previous body never displayed. Never reuse an ID across passes on the same PR.

```markdown
<!-- samuel:review-pass P={P} findings={B1,I2,N1} -->
{if delta:} Pass {P} (delta) against `{short sha}`. Re-verifies {IDs from the previous pass}; the rest is not re-litigated.

## Review: {PR title} (#{number})

**Reviewer**: {git user}
**Branch**: {head} → {base}
**Item**: {#N with Issue link, or "—"}
**Files**: {N} modified, +{additions}/-{deletions}

---

### Verdict: {APPROVE | APPROVE WITH COMMENTS | REQUEST CHANGES}

{1-2 sentence summary}

---

{if findings:}
### Findings

#### 🔴 B{n} — {finding title}
**File**: [`{file}:{line}`](https://github.com/{owner}/{repo}/blob/{head_sha}/{file}#L{line})
**Category**: {Bug/Security/Logic/Convention/Fit}
**Impact**: {what happens if not fixed, naming the inputs or scenario that trigger it}

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

#### 🟡 I{n} — {finding title}
{same structure}

{end findings}

{if acceptance criteria found:}
### Acceptance Criteria

| Criterion | Status |
|---|---|
| {criterion 1} | ✅ Covered |
| {criterion 2} | ⚠️ Partial — {explanation} |
| {criterion 3} | ❌ Not covered in this PR |
{end acceptance criteria}

### Summary

| Severity | Count |
|---|---|
| 🔴 Blocker | {n} |
| 🟡 Important | {n} |
| 🔵 Nit | {n} |

{if no findings:}
### ✅ No issues found

The code looks good. The changes are coherent, follow the project's conventions, and introduce no evident bugs.
{end no findings}
```

## The event is derived from the verdict

The verdict is the decision; the native event is its mechanical consequence, not a second question.

| Verdict | `event` |
|---|---|
| APPROVE | `APPROVE` |
| APPROVE WITH COMMENTS | `COMMENT` |
| REQUEST CHANGES | `REQUEST_CHANGES` |

Two conditions alter the derivation, and both are stated out loud at the checkpoint:

- **Own PR** (the PR's `author.login` is the Context's `gh login`) → the event is forced to `COMMENT`
  without asking. GitHub answers 422 to an `APPROVE` or `REQUEST_CHANGES` on your own PR. It is an API
  constraint, not a choice: it does not count as an override and it asks for no reason. This is the
  common case for this skill — the name says self-audit.
- **Clearing your own block** → if `reviews[]` carries a previous `CHANGES_REQUESTED` of yours and this
  pass finds no 🔴 Blocker, the proposed verdict is APPROVE and the derived event `APPROVE`. The
  checkpoint says that event is the only thing lifting the block: resolving the threads does not, and
  neither does a `COMMENT`.
  **The proposal rests on first-hand verification.** Every finding from the previous pass is
  re-verified against the code at the current head. The author's resolution comment says where to
  look; it is never the evidence. Without re-verifying, it is not APPROVE.

## Present to user

```
Review complete for PR #{number}: {title}

Verdict: {verdict}  →  event {APPROVE | COMMENT | REQUEST_CHANGES}
{if own PR:} COMMENT forced — GitHub rejects APPROVE/REQUEST_CHANGES on your own PR.
{if previous CHANGES_REQUESTED of yours:} Your pass {P} left CHANGES_REQUESTED. Only an APPROVE releases it.
{n} findings: {n} 🔴, {n} 🟡, {n} 🔵

{full report}

---

Options:
1. Publish — sends {event} under your GitHub account
2. Change the verdict — the event recalculates on its own
3. Adjust findings before publishing
4. Show here only (do not publish)
```

The menu does not offer the event. It offers publishing or not, and discussing the verdict. Whoever
disagrees with `COMMENT` disagrees with "APPROVE WITH COMMENTS", and that is the disagreement option 2
collects.

**Override — publishing with no native event.** Outside the menu, on explicit human request. Ask for a
one-line reason; no reason, no override. The reason is written into the published body, not only in
the terminal:

> **Published with no native verdict** — {reason}. The PR's `reviewDecision` is left untouched.

A review with no event does not unblock, does not block, and for GitHub did not happen.

## Publish

Summary and every inline comment go in **one single** request to the reviews endpoint. The `event` is
the one derived above, already resolved at the checkpoint; nothing is decided again here. Under the
override, `event` goes as `COMMENT` and the reason line travels inside `body`.

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST --input - <<'JSON'
{
  "commit_id": "{head_sha}",
  "event": "{APPROVE | COMMENT | REQUEST_CHANGES}",
  "body": "{the body rendered from § Review report format — marker included, it is its first line}",
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

**`position`** = line number within the diff hunk, not the file. Count from the start of the hunk
including context lines: find the line in `gh pr diff` output and count its offset from the `@@`
header of its hunk.

**Do NOT use** `POST /pulls/{n}/comments` (the individual comment endpoint) — it does not accept
`line`, `side` or `subject_type`. Only the reviews endpoint supports inline comments with positioning.

**Suggestion blocks** (committable fixes):

````markdown
```suggestion
{fixed code}
```
````

## Confirm

The event you sent and the verdict GitHub recorded are not the same thing until you check. Read it, do
not assume it:

```bash
gh pr view {number} --json reviewDecision --jq '.reviewDecision'
```

```
Review published at: {pr-url} — event sent {APPROVE | COMMENT | REQUEST_CHANGES}
PR reviewDecision: {read back from GitHub}

{n} inline comments with suggestions.
{if REQUEST_CHANGES:} ⚠️ CHANGES_REQUESTED blocks the merge until this same reviewer re-approves (or the review is dismissed).
{if APPROVE after your own CHANGES_REQUESTED:} ✅ Your previous block is released.
{if override with no event:} ⚠️ Published with no native verdict — reviewDecision untouched. Reason: {reason}.
{if Blockers with a COMMENT event:} ⚠️ There are {n} blockers and the verdict does not travel in the event: it lives only in the body.
{if no Blockers:} ✅ No blockers.
```

**If the value you read does not match the event you sent, say so instead of reporting success.** An
`APPROVE` that leaves the PR at `REVIEW_REQUIRED` means another reviewer is pending or a branch
protection rule is in the way, and whoever just reviewed needs to know now, not when they try to merge.
It is a fact about the PR, not a publication failure: report it, do not retry.
