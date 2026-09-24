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

Every phase also gets one **Run metadata** line, filled with the values this launch actually used
(never invented) — `{job_id}` is this iaas run's id when one is tracked, omitted otherwise:

```
Run metadata: agent=claude model={model} effort={effort} run={job_id}
```

Whatever the phase posts to GitHub (PR body, review, resolution comment, simplify-pass comment)
carries a `samuel:run` block built from that line, per `../../../reference/github-operations.md` §
Run metadata — `phase` is the one field the launcher does not inject, because it is the phase's own
identity (`implement` / `audit` / `address` / `simplify`) and the skill it runs already knows it.

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
- A message with no tool call ends this phase: `claude -p` exits 0 and the chain moves on. Do not end
  the turn with a summary that announces the next step, an offer to continue, or a list of choices
  that block nothing; put status notes in the same message as your next tool call.
- Your final message is read by a machine: what you did, the PR URL, gate status, deviations, open
  concerns. No padding.
```

## Phase 1 — IMPLEMENT

Runs `/samuel:implement`, then `/samuel:done --draft`.

```markdown
# Phase 1 — IMPLEMENT item #{N}

You are in worktree {path} on branch {branch}, based on origin/{default}.

Run metadata: agent=claude model={model} effort={effort} run={job_id}

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
  concise body carrying "Part of #{N}" and a `samuel:run` block stamped `phase: implement` from the
  Run metadata line above (`/samuel:done`'s § Run metadata rule).
```

## Phase 2 — AUDIT (round P)

Runs `/samuel:pr-self-audit`. **This phase changes no code.**

```markdown
# Phase 2 — AUDIT item #{N}, round {P}

You are in the worktree for branch {branch}. A draft PR exists for it.

Run metadata: agent=claude model={model} effort={effort} run={job_id}

Task: adversarial review of the PR against item #{N}. Read the Issue, the full diff, and the code in
the tree. Verify by EXECUTING, from round 1: run the item's focused tests, then write and run at
least one adversarial case of your own for every acceptance criterion that names an order, a
de-duplication, a boundary or an "in every branch" shape, and remove it again before you finish. A
verdict earned by reading alone must say so in its first line. Hunt for:
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
inputs that trigger it, and a concrete fix. Append a `samuel:run` block (`phase: audit`,
`round: {P}`) built from the Run metadata line above, as its own block after the pass marker.

You change NO code in this phase.
```

## Phase 2b — SECOND AUDIT (size M and L, round 1 only)

A second, **read-only** auditor from a **different model family**, launched beside Phase 2 on the same
frozen SHA. Two instances of one model share blind spots; two families do not (§ Model routing has the
measurement). It runs through the other engine's own runtime in read-only mode, never as a Claude
sub-agent, and it posts nothing: its final message comes back to the coordinator.

```markdown
# Phase 2b — SECOND AUDIT item #{N}

READ-ONLY review of commit {sha} on branch {branch} against item #{N}: its acceptance criteria and
its plan. You execute nothing and change no file. Apply the review rubric as written (Blocker /
Important / Nit, confidence bar, what not to flag). Trace the library source under the dependency
directory when a claim depends on how a library orders, parses or visits something. Validate every
Blocker or Important by citing the lines that prove it and the concrete input that breaks it.

Report: `VERDICT:` line, `COUNTS: B= I= N=` line, then each finding as
`ID · path:line · what breaks · the lines that prove it`. Under 3000 characters.
```

The coordinator **executes every Blocker and Important it returns** before anyone acts on it (a
read-only claim is a hypothesis), posts the confirmed ones as one PR comment headed
`## Second audit — confirmed findings`, and names that comment in the round's ADDRESS contract.
Convergence needs both lists empty of Blockers and Importants. Engine out of quota or unable to
start ⇒ skip 2b, write `second audit: skipped ({reason})` in the run report, and never substitute a
lower tier of the primary family for it.

## Phase 3 — ADDRESS (round P)

Runs `/samuel:address-pr-comments`.

```markdown
# Phase 3 — ADDRESS item #{N}, round {P}

You are in the worktree for branch {branch}, with an open draft PR carrying round {P}'s audit.

Run metadata: agent=claude model={model} effort={effort} run={job_id}

Task: resolve every finding of that round{if 2b confirmed any:}, plus the confirmed second-audit
findings in {comment url}{end}. For each: fix it, or decline with a one-line technical
reason when the finding is factually wrong — **verify against the code, not against authority; the
auditor can be wrong.** Blockers and Importants get fixed, not declined, unless provably incorrect.

Do not act outside the round's scope. Anything new you notice goes to a follow-up item, not to this
branch — a phase that widens its own scope makes the next audit review something nobody asked for.

If the verdict was APPROVE with no findings: spot-check that this is plausible against the Issue,
change nothing, and post one line saying the audit stands.

Definition of done when changes were made: gate green, commit, push, sign, then ONE
`## Resolution — pass {P}` comment with the disposition table (finding → fixed with its permalink,
or declined with the reason), the processed review IDs, and a `samuel:run` block (`phase: address`,
`round: {P}`) built from the Run metadata line above, appended after the `samuel:address-pass` marker.
```

## Phase 4 — SIMPLIFY

Three passes in a fixed order, each on the branch diff only, each allowed to change nothing: `/samuel:interrogate` (should this exist? — delete what serves no sentence of the purpose), then Claude Code's native `/simplify` (reuse, simplification, efficiency and altitude cleanups of what stays), then `/samuel:remove-slop` (what a senior developer would not have written: narration comments, defensive noise, type hacks, reinvented wheels). The order matters: cleaning or optimising a piece that the next pass would delete is wasted work, and slop removal is cosmetic and goes last.

```markdown
# Phase 4 — SIMPLIFY item #{N}

You are in the worktree for branch {branch}, with an open draft PR whose audit rounds are resolved.

Run metadata: agent=claude model={model} effort={effort} run={job_id}

Task, over the BRANCH DIFF ONLY, in this order:
1. /samuel:interrogate — restate the item's purpose from the Issue TL;DR, then delete every piece that
   serves no sentence of it or rests on an unevidenced assumption; simplify what the deletions leave.
2. /simplify — reuse, simplification, efficiency and altitude cleanups of the code that stays.
3. /samuel:remove-slop — comments that narrate the change or restate the obvious, defensive code for
   impossible states, duplicated logic, unnecessary indirection, naming that drifted from the
   surrounding code; check dependency manifests for a reinvented wheel or a hallucinated import.

Do NOT add features, do NOT restructure beyond the diff's own footprint, do NOT touch a file this
branch never modified. If the diff is already clean, say so and change nothing — an empty simplify
pass is a valid outcome, and inventing work here undoes an audit that already passed.

Definition of done: if anything changed — gate green, one commit per pass that changed something,
push, sign. In all cases post ONE `**Simplify pass:**` comment with one line per pass
(`interrogate: …` · `simplify: …` · `remove-slop: …`), "no changes needed" where a pass changed
nothing, and a `samuel:run` block (`phase: simplify`) built from the Run metadata line above —
this comment is a GitHub post like any other phase's, so it carries the block too.
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
| Implement — size L, user-facing work, or an open design decision | opus-5.5, effort high | the delegation default for any subagent that ships code |
| Implement — size S or M with a closed spec | gpt-5.6-luna, effort high, through the Codex runtime · fallback opus-5.5 high | matched the reference on the one matched run at half the output tokens and no Claude quota (provisional, below) |
| **Audit** | opus-5.5, effort **xhigh**, **with execution** | the adversarial phase — the one whose misses cost a whole round |
| Second audit (M, L) | gpt-5.6-luna, read-only | a different family: its misses did not overlap the primary's |
| Address | opus-5.5, effort high | bounded work: the findings name what to change · not measured |
| Simplify | opus-5.5, effort high | taste-sensitive, but scoped to the diff · not measured |

The rows name opus-5.5 since 2026-09-24; the evidence below was measured on opus-5 and not re-run.

Routing is overridable per run. Never silently drop a phase below opus-5.5 to save tokens; the audit
is where an under-powered model quietly returns "no findings" and looks identical to a clean pass.
The Codex rows need two things to hold: quota, and a sandbox that can run the project's tests from
the worktree — a build tool whose lock lives in the main checkout denies a worktree-scoped sandbox.
Check it with one focused test before the first dispatch; either one missing ⇒ that row falls back to
opus-5.5, **never** to a lower Claude tier.

**Evidence — provisional, one task.** One matched run: five implementers on the same medium fix, same
plan, same base, blind audit. opus-5 came back with no finding at all; gpt-5.6-luna with one Nit and
5 of 5 on the coordinator's adversarial suite, in 15k output tokens against opus-5's 30k, written
without being able to run a test; gpt-5.6-sol failed 1 of 5 (a source-order defect); sonnet-5 wrote
correct code, left two declared test seams unproven, used 43k tokens and broke one brief rule;
gpt-5.6-terra shipped an inert check. Then the same five frozen diffs went to six auditors against a
ground truth confirmed by execution: opus-5 **with** execution found 4 of 5 real defects, opus-5
**read-only** missed the ordering defect the executing instance found, gpt-5.6-luna read-only found 4
of 5 — a different four — and the union was 5 of 5. Nobody invented a Blocker or an Important on the
two clean diffs. Severity drifted between instances of the same model (one defect: Nit in one review,
Important in another), which is why convergence counts confirmed findings, not labels. Three more
matched tasks with the same result make these rows permanent; one contrary task reopens them.
sonnet-5 holds no implementer row and gpt-5.6-terra holds no row until each gets a fair run.
