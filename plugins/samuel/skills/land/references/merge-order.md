# Merge order — how the train is sequenced

The order is computed from **file overlap**, never from PR number, age or the order the human typed. Input is the `ready` + `needs-update` set from step 2; `blocked` PRs are already out.

## 1. Changed files per PR

```bash
git fetch origin
git diff --name-only origin/{base}...origin/{head}     # three dots: what the PR adds, not what base moved
```

Two dots would include everything base gained since the branch diverged, which inflates every overlap and makes an independent PR look entangled.

## 2. Overlap matrix

Intersect the file sets pairwise. For each PR record:

| Field | Meaning |
|---|---|
| `neighbours` | how many **distinct** other PRs it shares at least one file with |
| `shared_files` | total files it shares across all of them |
| `files` | its own changed-file count |

## 3. Sort

Ascending by `neighbours`, so **the PR that overlaps the most others merges LAST**. Ties break by `shared_files` ascending, then by `files` ascending, then by PR number ascending.

The reason is asymmetric cost: every merge invalidates the branches that touch the same files, and each invalidation costs a base update plus a full gate re-run. Landing the entangled PR first forces that cost on every other PR in the set; landing it last pays it once, on itself.

## 4. Stacked PRs override the sort

A PR whose `baseRefName` is another PR's head branch is **stacked**. Read it, never infer it:

```bash
gh pr view {n} --json number,baseRefName,headRefName,state
```

Constraints, in order of precedence over everything in §3:

- A stacked child merges **after** its base — always, whatever the overlap says.
- The base merges **without `--delete-branch`**. Deleting the branch a child PR points at **closes the child**.
- After the base lands, wait for the host to retarget the child (`gh pr view {child} --json baseRefName` shows the new base), then re-verify the child on its new base.
- The base branch is deleted in the sweep, once no open PR still points at it.

A cycle in the stack graph is a stop, not a puzzle to solve: report it.

## 5. Conflict prediction, before proposing anything

```bash
git merge-tree --write-tree --name-only origin/{base} origin/{head}
```

Exit `0` = clean, `1` = conflicts (the conflicted paths are printed), `>1` = the command itself failed (old git, bad ref) — which is not a clean result and must never be reported as one.

This prediction is pairwise against **today's base**. It cannot see the state after an earlier train member lands, so it is a planning signal, not a verdict: after each real merge, the authoritative check is the base update plus the gate re-run on the updated branch (`SKILL.md` step 5).

## 6. Re-verification set per merge

After PR *k* merges, the PRs that need base update + gate re-run + re-sign are exactly those later in the order whose file set intersects PR *k*'s. Everything else merges on the state it was already verified in. Compute this set at plan time and print it in the step-4 table — that column is what makes the human's single approval cover the re-verification work too.

## Worked example

Four PRs, base `main`:

| PR | files | overlaps with |
|---|---|---|
| #101 | `apps/web/login.ts` | — |
| #102 | `docs/setup.md` | — |
| #104 | `libs/core/index.ts`, `apps/web/app.ts` | #105 |
| #105 | `apps/web/app.ts`, `apps/web/nav.ts`, `libs/core/index.ts` | #104 |

Order: **#101, #102, #104, #105** — the two independents first (either order; PR number breaks the tie), then #104, and #105 last because it shares two files with #104. After #104 merges, #105 is updated from base and re-gated; #101 and #102 are never touched.

If #105's base were `feat/104-core` instead of `main`, it would be stacked: same last position, but #104 merges bare and #105 is re-verified only after GitHub retargets it to `main`.

## Gotchas

_Add a line each time Claude trips on something._

- Two dots instead of three in `git diff` counts base's own commits as the PR's changes and entangles everything with everything.
- A rename shows as two paths; a PR that renames a file the next PR edits conflicts even though the overlap matrix reports zero shared paths. `--name-only` on `merge-tree` is what catches it — run §5 even when §2 says the PRs are independent.
- `git merge-tree --write-tree` needs git ≥ 2.38; the older invocation silently means something else. Treat exit status `>1` as "unknown", never as "clean".
- The overlap matrix is computed once, at plan time, from the heads recorded in step 1. If a branch is pushed mid-train the plan is stale — the `--match-head-commit` pin in step 5 is what turns that into a loud failure instead of a surprise merge.
