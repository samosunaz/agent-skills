# IAAS phase contracts and the launch recipe

> Spoke of `../SKILL.md`. The hub decides which phase runs next and when the loop stops; this file
> carries what each phase is told, how the processes are chained, and the model routing.

## Why the contract is a file, not an argument

Each phase is a separate process with **no memory of the previous one**. Everything it needs travels
in two places: this contract on **stdin**, and the state already on GitHub (the Issue body, the PR
diff, the previous pass's marker comment). A multi-paragraph contract passed as a command-line
argument hits the shell's quoting rules and length limits, so write it to a file and pipe it in.

Write the contracts under a run-scoped directory (`/tmp/iaas-{item}/`) so a second item running in
parallel cannot overwrite them.

## Standing rules — every phase gets this block appended

```markdown
## Standing rules (all phases)

- Work ONLY inside this worktree. Never touch the main checkout or another worktree.
- Never run `git merge`, `git rebase`, `git gc`, or `git stash -u`. Never switch branches.
  Repairing a branch after a mid-run change to the base is the coordinator's job, not yours.
- Read the repo `CLAUDE.md` (auto-loaded) plus any nested `CLAUDE.md` covering the files you touch,
  BEFORE editing them.
- Gate discipline: run the repo gate redirected to a file and read the exit code — never pipe it.
  A red gate blocks the phase: fix and rerun, do not proceed.
- Signing: after every push of new commits run the repo's signoff command when `.claude/samuel.md`
  declares one. Never sign a SHA the gate did not run against.
- PR bodies and comments: English, impersonal, no AI attribution, no names. Reference the item with
  "Part of #<item>" — never "Closes #<item>", which would close it on merge before review.
- Premises marked [verify] are the coordinator's, not ground truth. If the code contradicts one, do
  NOT force the plan: adapt when the fix is obvious, otherwise stop and explain the contradiction.
- Reserve budget to finish. Committing, pushing, and the phase's required GitHub action must all
  happen before the turn limit.
- Your final message is read by a machine: what you did, the PR URL, gate status, deviations, open
  concerns. No padding.
```

## Phase 1 — IMPLEMENT

Runs `/samuel:implement`, then `/samuel:done --draft`.

```markdown
# Phase 1 — IMPLEMENT item #{N}

You are in worktree {path} on branch {branch}, based on origin/{default}.

Task: implement item #{N} end to end. Start by reading the Issue — its body is the spec, and its
Executor Plan is self-contained.

Design latitude: {what the executor may choose, and the constraint that bounds it}.
[verify] {premises the coordinator believes but has not confirmed}.

Definition of done:
- Every Acceptance Criterion in the Brief met.
- Tests only at the seams the plan declared in `### Testing seams` (see `/samuel:tdd`); a Step that
  needs an undeclared seam is a plan-reality mismatch — stop and say so.
- The repo gate green.
- Commit, push the branch, sign the gate, then open a DRAFT PR titled "{type}: {summary}" with a
  concise body carrying "Part of #{N}".
```

## Phase 2 — AUDIT (round P)

Runs `/samuel:pr-self-audit`. **This phase changes no code.**

```markdown
# Phase 2 — AUDIT item #{N}, round {P}

You are in the worktree for branch {branch}. A draft PR exists for it.

Task: adversarial review of the PR against item #{N}. Read the Issue, the full diff, and the code in
the tree — verify claims by reading, and by running targeted tests where that is cheap. Hunt for:
Acceptance Criteria not actually met, bugs the diff introduces, contract violations (CLAUDE.md,
REVIEW.md, CONSTITUTION.md), vacuous tests, silent behavior changes outside scope, and solution fit
(a reinvented wheel, a needless dependency, speculative generality, a broken public contract).

Severity, categories, the 80% confidence bar and what is NOT worth flagging: the review rubric.
Judge honestly — a clean implementation deserves a short clean verdict, and "no findings" is a
complete result. Never pad with nits to look thorough.

{if P > 1:} Round {P} is a DELTA. Review what changed since round {P-1}'s reviewed SHA, and
re-verify that round's findings ({IDs}) against the code at the current head. The author's
resolution comment says where to look; it is never the evidence. The rest is not re-litigated.

Deliverable: exactly ONE PR review whose body opens with the pass marker, carries the scope line
when this is a delta, and states **Verdict: APPROVE | APPROVE WITH COMMENTS | REQUEST CHANGES**,
then each finding with its ID (B{n}/I{n}/N{n}), severity, category, file:line, impact naming the
inputs that trigger it, and a concrete fix.

You change NO code in this phase.
```

## Phase 3 — ADDRESS (round P)

Runs `/samuel:address-pr-comments`.

```markdown
# Phase 3 — ADDRESS item #{N}, round {P}

You are in the worktree for branch {branch}, with an open draft PR carrying round {P}'s audit.

Task: resolve every finding of that round. For each: fix it, or decline with a one-line technical
reason when the finding is factually wrong — **verify against the code, not against authority; the
auditor can be wrong.** Blockers and Importants get fixed, not declined, unless provably incorrect.

Do not act outside the round's scope. Anything new you notice goes to a follow-up item, not to this
branch — a phase that widens its own scope makes the next audit review something nobody asked for.

If the verdict was APPROVE with no findings: spot-check that this is plausible against the Issue,
change nothing, and post one line saying the audit stands.

Definition of done when changes were made: gate green, commit, push, sign, then ONE
`## Resolution — pass {P}` comment with the disposition table (finding → fixed with its permalink,
or declined with the reason) and the processed review IDs.
```

## Phase 4 — SIMPLIFY

Runs `/samuel:remove-slop`.

```markdown
# Phase 4 — SIMPLIFY item #{N}

You are in the worktree for branch {branch}, with an open draft PR whose audit rounds are resolved.

Task: a de-slop pass over the BRANCH DIFF ONLY. Remove comments that narrate the change or restate
the obvious, defensive code for impossible states, duplicated logic, unnecessary indirection, and
naming that drifted from the surrounding code. Check dependency manifests for a reinvented wheel or
a hallucinated import.

Do NOT add features, do NOT restructure beyond the diff's own footprint, do NOT touch a file this
branch never modified. If the diff is already clean, say so and change nothing — an empty simplify
pass is a valid outcome, and inventing work here undoes an audit that already passed.

Definition of done: if anything changed — gate green, commit, push, sign. In all cases post ONE
`**Simplify pass:**` comment summarizing what was removed, or "no changes needed".
{if --ready:} Then mark the PR ready for review.
```

## The chain

One process per phase, chained so a failure stops everything after it. A phase that runs on top of a
failed predecessor audits a tree nobody built.

```bash
cd {worktree}
for p in 1-implement 2-audit 3-address 4-simplify; do
  echo "=== PHASE $p start $(date +%H:%M:%S)" >> ~/iaas-{N}.log
  claude -p --model {model} --effort {effort} \
    --output-format stream-json --verbose \
    < /tmp/iaas-{N}/$p.md >> ~/iaas-{N}.jsonl 2>>~/iaas-{N}.log \
    || { echo "=== PHASE $p FAILED $(date +%H:%M:%S)" >> ~/iaas-{N}.log; exit 1; }
  echo "=== PHASE $p done $(date +%H:%M:%S)" >> ~/iaas-{N}.log
done
```

With a ceiling above 1 the middle of that list repeats — `2-audit-1 3-address-1 2-audit-2 …` — and
the hub decides after each audit whether the next pair is written at all (`../SKILL.md` § When the
loop stops). **Do not pre-generate rounds that convergence may cancel**; each audit contract is
written after the previous round closed, because a delta round needs the previous pass's IDs.

The headless run needs the permission barrier every unattended run needs: bypass mode plus the
committed deny list, never a bare allowlist. Recipe and the reason:
`../../conductor/references/autonomous-run.md` § 2.

**Supervision** is `Monitor` over the `.jsonl`, reading `result` lines for cost, turns and outcome.
Each phase's own final message is the machine-read report the standing rules ask for.

## Model routing

| Phase | Default | Why |
|---|---|---|
| Implement | opus-5, effort high | the delegation default for any subagent that ships code |
| **Audit** | opus-5, effort **xhigh** | the adversarial phase — the one whose misses cost a whole round |
| Address | opus-5, effort high | bounded work: the findings name what to change |
| Simplify | opus-5, effort high | taste-sensitive, but scoped to the diff |

Routing is overridable per run. Never silently drop a phase below opus-5 to save tokens; the audit
is where an under-powered model quietly returns "no findings" and looks identical to a clean pass.
