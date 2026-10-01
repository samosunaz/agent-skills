# Business retelling guide

Spoke of `/samuel:biz-tldr`. How a technical finding becomes a flow step, a risk, a decision, or an internal-only line. Sentence rules are not here: they are `/samuel:tldr`'s, in `../../tldr/references/ste-rewrite.md`.

## 1. Translation patterns

Name the person first, then what happens to them. The right column is what the owner reads; the left column never reaches them.

| Technical shape | Business retelling | Where it goes |
|---|---|---|
| A foreign key, lock or constraint blocks a delete or an exit | "{person} cannot {leave / close / cancel} until {someone} {reassigns / releases} {thing}" | Risk, or a decision when the fix has options |
| Validation refuses bad input at creation time | "The error shows up when {the record} is registered, not on the day {it is used}" | Flow step, plus a risk for what must be redone |
| A timeout, rate limit or size nobody measured | "Nobody has measured whether {the biggest case, with its number} fits. The risk: {task} is slow or fails" | Risk, marked unknown |
| No bulk path for a large write | "Saving {N} {things} at once is not defined yet. {Onboarding the big one} may be slow or fail" | Risk |
| The same rule written in two places | "Two screens can disagree: {one} says 3, {the other} shows none" | Risk |
| A feature off when a key or setting is missing | "Where {the provider} is not set up, only {that feature} is off; everything else works" | Flow step, or nothing if no one notices |
| A read that is not scoped to the tenant or brand | "{Brand A's customers} can see {brand B's thing}" | Risk, often a decision |
| A permission level for an operation | "Who on the team may {do it}" | Decision |
| A missing record type nobody administers | "{Thing} has no owner: nobody registers {it}, and without it {consequence}" | Risk, then a decision on who owns it |
| A build check, test gap, rename, or doc fix | Nothing changes for anyone | Internal only |

When a finding fits no row, ask: who notices it first, and what do they fail to do? That sentence is the retelling.

## 2. Worked example

**Source (technical review excerpt):**

> The importer calls the supplier feed through the SDK before opening the transaction, then inserts one row per SKU into `product` and `product_variant`. There is no batch or `COPY` path. The SDK hard-codes a 10 s timeout, and no feed above 5,000 SKUs has been tested; the largest supplier sends 50,000. `publish_product` requires `admin`, while the spec says a catalog manager publishes. `archtest` needs `product_variant` added to its exemption list.

**Inventory:** actors: catalog manager, admin, shopper. Trigger: a new supplier. Outcome: the shopper sees the supplier's products. Risks: 50,000-SKU feeds untested against a 10 s limit; no bulk save. Decision: who publishes. Internal: the exemption list.

**Retelling:**

> **A catalog manager can bring a supplier's whole catalog into the store in one step, but a large supplier may not fit yet.**
>
> 1. The catalog manager pastes the supplier's feed link.
> 2. The store copies every product and variant from the feed at once.
> 3. Someone publishes the products, and shoppers see them.
>
> **What can go wrong**
> - **Large suppliers.** Only feeds up to 5,000 products have been tested, and the largest supplier sends 50,000. Nobody knows yet whether that fits the 10-second limit, or how 50,000 products are saved at once. The risk: onboarding the largest supplier is slow or fails.
>
> **Internal only:** one build check needs updating; nothing changes for anyone.
>
> **Decision:** who publishes imported products? Recommended: the catalog manager, because it is their daily work. The alternative is admin only, which makes every import wait on one person.

What moved where: the SDK, the transaction, the table names and the check's name disappeared. The two numbers (5,000 tested, 50,000 needed) and the 10-second limit stayed exact. The permission mismatch became a decision because it has two real options. The exemption list became internal only because no person notices it.

## 3. Self-check

Run through this before printing:

- [ ] The headline names an effect on a person or the business, not a component.
- [ ] Every flow step opens with an actor (a person, a role, an outside company, or the product acting for them), never with a screen or a badge.
- [ ] Every item from the Step 2 inventory appears, in the flow, a risk, the internal line, or a decision.
- [ ] Every number and scope condition matches the source exactly.
- [ ] Each unknown is stated as unknown.
- [ ] No path, line number, or table, function or endpoint name is left without need.
- [ ] Each decision has a recommended option first and a one-line reason.
- [ ] Nothing was posted, commented or edited.
