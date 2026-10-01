---
type: llm
---

The reply retells a technical review for a non-technical reader. Judge the form only; any closing note the reply appends is expected and never decides the verdict.

PASS if all of these hold:
1. It opens with a one-sentence headline about what this means for the business or its people, not about code.
2. It describes the flow as numbered steps, and each step names who acts in it; word order does not matter. An actor is a person or role (the site owner, an editor, a visitor, the agency), an outside company (the certificate provider), or the product acting for them. A screen, badge or message is not an actor.
3. It does not mention file paths, line numbers, or code identifiers such as `DomainService.attach()`, `domains.ts`, `site_domain`, `isDomainVerified()` or `e2e/domains.spec.ts`.

FAIL if any of the three fails.
