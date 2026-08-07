# STE rewrite guide

Spoke of `/samuel:tldr`. Operational rules for rewriting prose to the Simplified Technical English standard.

Table of contents:

1. Jargon: keep vs replace
2. Deletion patterns
3. Sentence surgery
4. Before/after pairs
5. Self-check

## 1. Jargon: keep vs replace

"Tech jargon" is two different problems. One list stays. The other goes.

### Keep, in English, unexpanded

These name exactly one thing. A translation invents a second name for it, which is the failure this standard exists to prevent.

`PR` · `issue` · `branch` · `worktree` · `commit` · `squash` · `rebase` · `merge` · `rollback` · `deploy` · `CI` · `lint` · `gate` · `hook` · `endpoint` · `payload` · `schema` · `migration` · `cache` · `race condition` · `timeout` · `prompt` · `subagent` · `diff` · `stack trace`

The rule holds when the surrounding text is in another language. Writing in Spanish does not license "solicitud de extracción" for `PR` or "rama" for `branch`.

### Replace or delete

These name nothing. Each one hides the fact the reader wants.

| Jargon | Use instead |
|---|---|
| leverage, utilize | use |
| surface (verb) | show |
| streamline | simplify |
| facilitate, enable, unlock | let, or delete |
| architected | designed |
| delve into, deep dive | review |
| align on | agree on |
| circle back | return to X on {date} |
| bandwidth | time |
| low-hanging fruit | name the task |
| best practices | name the practice |
| robust, solid, powerful | say what it withstands, or delete |
| seamless, elegant, clean | delete |
| comprehensive | give the scope ("covers all 12 endpoints") |
| significant, substantial | give the number |
| performant | give the metric ("200 ms p95") |
| scalable | say up to what load |
| production-ready | say what is missing |
| properly, correctly | delete |
| in order to | to |
| basically, essentially | delete |
| it's worth noting that | delete |
| as mentioned above | name the thing |
| at the end of the day | delete |
| landscape, ecosystem (metaphor) | name the real system |

`orchestrate` is the edge case. Keep it when it names agent or workflow orchestration, which is a real thing in this stack (`/samuel:team-orchestrate`). Replace it with "coordinate" anywhere else.

## 2. Deletion patterns

| Pattern | Example | Action |
|---|---|---|
| Opener | "Let me look at the file to understand…" | Delete. Show the result. |
| Closer | "Want me to update the tests too?" | Delete, unless it is a real blocking question. |
| Self-narration | "Now that I've read `auth.ts`, I can see that…" | Delete the clause, keep the finding. |
| Recap | Prose describing the diff shown above it | Delete. |
| Empty hedge | "I think this could probably…" | Delete the hedge, state the fact. |
| Filler adjective | "a robust and elegant solution" | Delete both adjectives. |
| Motivational closer | "Production-ready!" | Delete. |
| Tricolon | "fast, simple and reliable" | Keep the one item that carries a fact. |
| Em dash | "The hook fails — the path does not exist" | "The hook fails because the path does not exist." |

A real hedge survives, with its cause attached. "I did not run the tests, so I do not know if it passes" is precise. "I think it should work" is not.

## 3. Sentence surgery

**Split a subordinated chain.**

- Before: "Given that the worktree already exists and the branch is created, the next step would be to run the implement, although it would first be advisable to check that the context is loaded."
- After: "The worktree and the branch already exist. Verify that the context is loaded. Then run the implement."

**Name the referent.**

- Before: "That breaks the earlier one."
- After: "The `parseUser` rename breaks the import at `auth.ts:14`."

**Put the condition first.**

- Before: "Open a new PR if the previous one is already merged."
- After: "If the previous PR is already merged, open a new one."

**Break the noun stack.**

- Before: "GitHub issue pipeline label sync workflow"
- After: "the workflow that syncs the `pipeline:*` labels on issues"

**Give the number.**

- Before: "Several tests failed."
- After: "3 of 41 tests failed."

## 4. Before/after pairs

### Pair A: agent status report

Before:

> Perfect, I've gone ahead and implemented the requested changes. Basically what I did was refactor the authentication module to make it more robust and maintainable, leveraging the repository pattern that already existed in the codebase. This should significantly improve testability. It's worth noting that I also updated a few tests that were failing. Would you like me to look at anything else?

After:

> I refactored `auth/` to the repository pattern `orders/` already used. I fixed 4 failing tests. I did not run the full suite.

### Pair B: instructions

Before:

> In order to proceed correctly with the deploy, it would be advisable to first validate that the CI pipeline has passed successfully, and once you have verified that, you could consider merging the PR, keeping in mind that if there are conflicts they would need to be resolved beforehand.

After:

> Verify that CI passed. If there are conflicts, resolve them first. Then merge the PR.

### Pair C: diagnosis

Before:

> After a comprehensive investigation of the codebase, it appears that the root cause is likely related to a race condition that surfaces when multiple concurrent requests attempt to leverage the same cache instance, which is not particularly robust under load.

After:

> `CacheStore.get` has a race condition at `cache.ts:88`. Two concurrent requests write the same key. The second write wins and drops the first result.

### Pair D: protected span

Before:

> Basically you'll want to run the following command in order to properly reset things:
> ```bash
> git reset --hard origin/main
> ```
> This should essentially get you back to a clean state.

After:

> ```bash
> git reset --hard origin/main
> ```
> This command deletes your local changes.

The command block is identical in both. The prose around it changed. That is the rule.

### Pair E: the TL;DR block of a PR

Structure and chips: `../../../reference/github-operations.md` § TL;DR. This pair is about the prose inside it.

Before:

> **What:** This PR implements the plan from #47, adding comprehensive support for a robust new caching layer.
> **Why:** To significantly improve performance.
> **Caveat:** There are a few things that could potentially be affected, and it's worth noting the migration should probably be run first.

After:

> **What:** Adds a Redis read-through cache to `GET /events/:id`.
> **Why:** That endpoint was 340 ms p95 and it fronts the event page.
> **Caveat:** Run migration `0031` before deploying. The cache key includes the tenant id.

`What` restates neither the title nor the issue number. `Why` carries the number the word "performance" was hiding. The vague `Caveat` became two facts a reviewer can act on.

## 5. Self-check

Run these 6 questions over the rewrite before printing it.

1. Does any sentence admit two readings?
2. Does every term appear with the same word every time?
3. Is any fact from the source missing?
4. Did I add a claim the source did not make?
5. Are all code blocks, commands, and paths byte-identical to the source?
6. Is the rewrite in the same language as the source?

A "yes" on 1, 3, or 4, or a "no" on 2, 5, or 6, means the rewrite is not done.
