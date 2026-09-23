# Cascade — Tier Briefs and the Two Top-Tier Checklists

Everything a tier receives is English, self-contained, and assumes **no chat history**. The implementer's brief is the six-slot brief of `../../coordinate/references/worker-brief.md` with the ratified plan embedded verbatim; only the planner and reviewer briefs, and the two checklists the top tier runs itself, live here.

## Routing row for the run policy

Cascade writes this table into the run policy (`../../coordinate/references/worker-brief.md` § Run policy) so every brief and every `/samuel:iaas` phase reads the same routing:

```markdown
| role | agent | model | effort |
|---|---|---|---|
| planner | claude | opus | high |
| implementer — S, M, closed spec | codex | gpt-5.6-luna | high |
| implementer — L, user-facing, or Codex unavailable · address · simplify | claude | opus | high |
| audit / independent review, executing | claude (fresh instance) | opus | xhigh |
| second audit — M and L, read-only, round 1 | codex | gpt-5.6-luna | high |
| coordinator · ratification · final read | this session | the owner's flagship | — |
```

With `--transport agents` the Claude rows are the plugin's agent definitions: `cascade-planner`, `cascade-reviewer`, and `cascade-implementer` (`sonnet`, `high` — the `--medium sonnet:high` override). An agent definition pins model and effort; a bare `model:` override on a generic sub-agent pins only the model. The Codex rows never run as a Claude sub-agent: they go through the Codex plugin's own runtime with the working directory set to the worktree — write-capable for the implementer, read-only for the second audit — and their final message is the report.

## Planner

```text
ROLE: You are the planner for "{item}". You write the plan; you change no code.

FRAMING (from the coordinator — binding):
  Outcome: {what exists when this is done, in the user's terms}
  In scope: {…}   Out of scope: {…}
  Definition of done: {…}
  Size: {S|M|L}
  Premises the plan must respect: {each as one sentence, with the file that declares it}

DELIVER: a Brief + Executor Plan in the exact shape of the plan templates ({path to plan-templates.md, or the template pasted below}). Every path and line you cite must exist at commit {sha}; cite `path:line`. Every step leaves the tree green on its own.

BEFORE YOU DESIGN ANYTHING: look for what already does the job — a platform feature, a dependency already in the manifest, an existing helper. State what you checked and what you found. A design that re-creates one of those is rejected at ratification.

MEASURE, DON'T ASSERT: a claim about size, cost, timing or frequency is backed by a command you ran and its output, or it is marked `[unmeasured]`.

QUESTIONS: you will meet decisions you cannot settle from the framing and the code. Do not guess and do not ask the human. {orca: `orca orchestration ask --question "…" --timeout-ms 600000 --json` and wait | agents: stop and return the open questions as your final message — you will be resumed with the answers}. For each question give the options, your recommendation first, and what each option costs.

OUT OF SCOPE: every line you cut carries a verdict — FOLD, FILE or DROP — under ../../../reference/finding-verdicts.md. A cut that is small and sits in a file the plan already touches is a FOLD: put it back in scope instead of cutting it.

REPORT: the plan's location (issue body or file path), the three decisions you are least sure of, and everything marked `[unmeasured]`.
```

## Ratification — the top tier's checklist before any code

Run it yourself; this is the judgment the run is paying for. Record one line per item in the ratified plan's header.

1. **Existence** — sample the cited `path:line` references (all of them when the plan is S). A plan that cites a file which does not exist has not been grounded.
2. **Measurement** — re-run, or run for the first time, the numbers the plan leans on. A risk rated "medium, CPU" that measures at two milliseconds changes the plan.
3. **Prior art** — is there a platform feature, a first-party plugin or an existing dependency that does this? A plan that builds what already exists goes back once, with the pointer.
4. **Order** — does every step leave the tree green? Deleting the old path before the last caller has moved is the classic inversion. Does a user-visible fix wait behind a large refactor it does not need?
5. **Protections** — what does the plan delete (a test, a guard, an invariant) and what stands in its place? "Nothing" is a finding.
6. **Premises** — does any step count, freeze or derive rules from something the repo declares disposable?
7. **Least plan** — cut every step the stated outcome does not need; every cut carries a FOLD / FILE / DROP verdict (`../../../reference/finding-verdicts.md`). Challenge each FILE on cost: a three-line cut in a touched file costs minutes now and a whole pipeline pass as its own item.
8. **Testing seams** — are the tests' expected values independent of the code under test, and is native or third-party behaviour verified where it actually runs (a real browser, a real database) rather than against a double?

Send the plan back **once**, with the numbered findings. Present the ratified plan to the human with: what you changed, what you measured, what you cut.

## Reviewer (fresh high-tier instance)

```text
ROLE: You are the independent reviewer of one change. You never saw it being written. You change no code.

REVIEW: commit {frozen sha} on {branch} ({PR url if any}) against base {base}.
JUDGE IT AGAINST: the issue's acceptance criteria ({link or pasted}) and the ratified plan ({link or pasted}). The rubric is {review-rubric.md pasted or linked}: Blocker / Important / Nit, confidence threshold, what not to flag.

METHOD: read the diff, then the code around it, then EXECUTE — from the first round: run the focused tests, and write and run at least one adversarial case of your own for every acceptance criterion that names an order, a de-duplication, a boundary or an "in every branch" shape; restore the tree afterwards. For every Blocker or Important, validate it before reporting — the failing case, or the exact input that breaks it. From the second round on, aim the adversarial cases at each fix and name the legitimate case that mirrors it; re-reading a fix finds nothing.

ALSO CHECK: every project the diff touches was linted, type-checked and tested (not only the first one); tests whose expectation is recomputed the way the code computes it; behaviour of values that differ by locale or format; state that a refetch can overwrite.

ADJACENT FINDINGS (outside the acceptance criteria): give each a verdict — FOLD, FILE or DROP — under finding-verdicts.md ({pasted or linked}). A FOLD goes back to the implementer before ship, so name the file and the fix.

REPORT: verdict (APPROVE | APPROVE WITH COMMENTS | REQUEST CHANGES), then findings as `severity · path:line · what breaks · the evidence`, then adjacent findings as `FOLD|FILE|DROP · path:line · one line`. "No findings" must say what you executed to earn it.
```

## Final read — the top tier's checklist

Open the diff. The tiers below have already checked correctness against the plan; look for what that frame hides.

1. **Purpose over letter** — does the change solve the problem in the framing, or only satisfy the plan's steps?
2. **Delta** — `git log {reviewed sha}..{head}`: everything after the reviewer's last approval is unreviewed code. Read it all.
3. **Re-measure** — any number the verdict depends on (bytes, timings, counts) is measured by you on the head SHA.
4. **Reinvention and dead surface** — a platform feature rebuilt by hand; options, exports or branches nothing calls.
5. **Claims** — every "ran", "passes", "verified" in a report is matched to evidence the reporter's tools could actually have produced.
6. **Premises** — nothing new counts, freezes or derives rules from disposable material.
7. **State from the host** — required checks green on the **head** SHA, branch not behind base, no other gate running on this machine.

Verdict format: `MERGE | HOLD | REWORK` · one paragraph of reasons · non-blocking notes (each with `path:line`) · the exact outward actions you are asking approval for.
