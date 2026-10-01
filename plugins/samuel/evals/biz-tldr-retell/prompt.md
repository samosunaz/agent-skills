---
max_turns: 6
allowed_tools: [Skill, Read]
---

I have to explain this to the agency partner who resells our plans, and they are not technical. Give me the business and the flow, not tables. Do not ask me questions: give me the version and mark your recommendation on each decision.

"Review of the custom-domain feature. `DomainService.attach()` (`domains.ts:41`) writes the CNAME target to `site_domain` and requests the TLS certificate from the provider inside the same request handler. The provider's ACME call has a hard 30 s timeout and no retry. No domain with more than 50 subdomains has been tested; the Agency plan allows up to 200. `isDomainVerified()` and the dashboard badge read `site_domain.status` separately, so the badge can say Connected while the site still serves the default subdomain. `attach` requires the `owner` role, but the pricing page says any editor on a Team plan can connect a domain. `e2e/domains.spec.ts` is skipped in CI."
