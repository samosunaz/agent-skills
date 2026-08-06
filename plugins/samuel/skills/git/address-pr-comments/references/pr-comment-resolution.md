# PR Comment Resolution — gh / GraphQL snippets

Deterministic commands for fetching, replying to, and resolving PR comment threads. Used by `/samuel:address-pr-comments`.

> REST exposes comment bodies but **not** resolution state. GraphQL is required for `isResolved` / `isOutdated` and for resolving threads. Use both: REST for bodies + reply-by-id, GraphQL for thread state + resolve.

## Resolve owner/repo/number

```bash
REPO=$(gh pr view {number} --json headRepository,headRepositoryOwner \
  --jq '.headRepositoryOwner.login + "/" + .headRepository.name')
OWNER=${REPO%/*}; NAME=${REPO#*/}
HEAD_SHA=$(gh pr view {number} --json headRefOid --jq '.headRefOid')
```

Requires `gh repo set-default` in the repo (SSH-alias origin breaks gh's remote parsing — `reference/tracker.md`).

## FETCH — all comment surfaces

### 1. Review summaries (verdicts: APPROVED / CHANGES_REQUESTED / COMMENTED)

```bash
gh api repos/$OWNER/$NAME/pulls/{number}/reviews \
  --jq '.[] | {id, user: .user.login, state, body, submitted_at}'
```

### 2. Inline review comments (REST — bodies, path, line, reply chains)

```bash
gh api repos/$OWNER/$NAME/pulls/{number}/comments --paginate \
  --jq '.[] | {id, user: .user.login, path, line, body, in_reply_to_id, created_at}'
```

### 3. Conversation comments (top-level, not tied to code)

```bash
gh api repos/$OWNER/$NAME/issues/{number}/comments --paginate \
  --jq '.[] | {id, user: .user.login, body, created_at}'
```

### 4. Review threads with resolution state (GraphQL — the source of truth for what's open)

```bash
gh api graphql -F owner="$OWNER" -F repo="$NAME" -F number={number} -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first:50) {
            nodes { databaseId author { login } body createdAt }
          }
        }
      }
    }
  }
}'
```

Join key: the GraphQL `comments.nodes[].databaseId` == the REST comment `id`. Use the thread's `id` (a base64 node ID) for replies and resolution; use `databaseId` to match the REST body/line data.

## REPLY

### Reply to an inline review thread (REST, by comment id)

```bash
gh api repos/$OWNER/$NAME/pulls/{number}/comments/{comment_id}/replies \
  --method POST -f body="{reply text}"
```

### Reply to a conversation (top-level) comment

```bash
gh api repos/$OWNER/$NAME/issues/{number}/comments \
  --method POST -f body="{reply text}"
```

## RESOLVE

```bash
gh api graphql -F threadId="{thread_node_id}" -f query='
mutation($threadId:ID!) {
  resolveReviewThread(input:{threadId:$threadId}) {
    thread { isResolved }
  }
}'
```

Unresolve (if you resolved one by mistake): same mutation name `unresolveReviewThread`.

## RE-REQUEST REVIEW (after CHANGES_REQUESTED is addressed)

```bash
gh api repos/$OWNER/$NAME/pulls/{number}/requested_reviewers \
  --method POST -f 'reviewers[]={login}'
```

## Pass markers (incremental boundary)

Each `/samuel:address-pr-comments` pass closes by posting ONE consolidated `Resolution` comment that doubles as the next run's stop boundary. Detection is **ID-based** (which reviews/comments a pass processed), never timestamp-based — a review submitted mid-pass is absent from the marker and enters the next pass.

### Fetch prior markers

```bash
gh api repos/$OWNER/$NAME/issues/{number}/comments --paginate \
  --jq '[.[] | select(.body | contains("<!-- samuel:address-pass -->")) | {id, body, created_at}]'
```

Processed review IDs = union of the `Reviews:` lines across all markers; unprocessed = FETCH surface 1 minus processed. Same arithmetic for top-level comment IDs (`Comments:` line). Pass number `{P}` = prior marker count + 1.

### Marker format

```markdown
<!-- samuel:address-pass -->
## Resolution — pass {P}

| ID | Finding | Disposition | Detail |
|----|---------|-------------|--------|
| T1 | `a.ts:42` — missing await | ✅ Fixed | {SHA permalink} |
| T2 | prefer const | ❌ Rejected | already const after refactor ({permalink}) |
| T3 | why this approach? | 💬 Answered | trade-off: {one line} |
| T4 | leak on retry path | ⏳ Pending | valid — blocked on {reason}, thread left open |

Reviews: {review_id}, {review_id}
Comments: {comment_id}   (omit the line if none)
Commits: {short-shas}
```

Dispositions: ✅ Corregido · 💬 Respondido · ❌ Rechazado (citable reason) · 👌 Obsoleto/Ya atendido · ⏳ Pendiente (reviewer is right, fix blocked — thread stays open). Element-initial IDs (`T{n}`), never `#{n}` (autolink); code references are SHA permalinks (`reference/github-operations.md` § Linking).

### Post

```bash
gh pr comment {number} --body-file resolucion.md
```

Never edit a prior marker — each pass appends its own comment.

## Bot identification (for confidence weighting)

| Source | `user.login` pattern | Default confidence to auto-resolve |
|--------|---------------------|-----------------------------------|
| GitHub Copilot review | `copilot-pull-request-reviewer[bot]`, `Copilot` | High — nits/suggestions |
| CodeRabbit | `coderabbitai[bot]` | Medium — verify before resolve |
| `/samuel:pr-self-audit` | the author's own gh account, inline comments with suggestion blocks | Medium — author's own pipeline |
| `/codex:review` · ultrareview · native `/code-review` | the author's own gh account or the Claude GitHub app, relayed review output | Medium — verify before resolve |
| Human reviewer | a real login that is not the author's automation | Low — always reply explicitly, never silent-resolve |

## Gotchas

- REST `pulls/{n}/comments` returns **inline** comments only. Top-level PR comments live under `issues/{n}/comments`. Fetch both.
- `in_reply_to_id` chains replies — a thread is the root comment plus everyone with `in_reply_to_id` pointing up the chain. GraphQL `reviewThreads` already groups these; prefer it for grouping.
- The `replies` endpoint needs the **root** comment id of the thread, not a mid-thread reply id.
- `resolveReviewThread` needs the GraphQL node `id` (base64), not the REST numeric `databaseId`.
- `isOutdated: true` means the line moved or was deleted by later commits — the comment may already be moot. Surface it as "outdated" in triage, don't blindly resolve.
- Re-requesting a review from a bot reviewer usually fails silently — only re-request human reviewers who left CHANGES_REQUESTED.
- A PR review with `state: CHANGES_REQUESTED` keeps blocking until that same reviewer submits a new review or it's dismissed — resolving the inline threads is not enough. Reply, push fixes, then re-request.
- Own-pipeline reviews (`pr-self-audit`, relayed `codex:review`) post from the author's own account — distinguish them from the author reviewing by hand by body shape (review header/suggestion blocks), not by login alone.
