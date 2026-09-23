# Finding Verdicts — FOLD, FILE or DROP

Any tier that notices something outside the item's acceptance criteria gives it a verdict when it notices it. That covers the planner's out-of-scope cuts, the reviewer's side notes and the implementer's `Unresolved` line. "Follow-up" is not a verdict. A run that turns every observation into an issue grows the backlog faster than it closes it: one measured run closed 16 issues and surfaced 18 follow-ups, and none of the 18 was a regression the run introduced.

| Verdict | When | Where it goes |
|---|---|---|
| **FOLD** | Small (about 20 lines or fewer). It sits in a file the change already touches, or it is the same class of bug in a sibling file. Or it is the only way to verify the item, such as a broken test of the feature being changed. | The same PR, as its own commit. If it is found after merge, it goes to ONE closing fold PR with the same implementer → reviewer → final read. Not to `/samuel:polish`: polish freezes behaviour and reverts any new helper, and a fold is usually a fix or a dedup that adds one. |
| **FILE** | It changes a contract, users, security or data, and it costs more than a fold. Or it needs a judgement the run cannot make unattended, such as a visual check or a product call. | One issue per area, never one issue per finding. The issue carries the path, the evidence and why it is not a fold. |
| **DROP** | It has no user-visible effect before launch, carries no guardrail risk, and fixing it buys nothing measurable. | One line in the run ledger. No issue. |

## Rules

- **The planner writes a verdict on every out-of-scope line.** A cut marked FOLD is a smell: if it is small and in a touched file, it belongs in scope. Ratification challenges it: "cost now vs. cost as its own item". A separate item costs a plan, a worktree, a gate and a review.
- **A reviewer's FOLD is actionable.** It goes to the implementer as another commit before ship, on the same footing as a Nit the coordinator accepts. It is not parked.
- **Growing an item past its ratified scope is the owner's call.** The coordinator asks once, for the batch, with its recommendation. Within scope, folding needs no approval.
- **Measure the run by net delta: items closed minus issues filed.** Record it in the run ledger and the tracker's closing comment. A run whose net delta falls below half of what it closed has a verdict problem, not a code problem.
