---
feature: {feature_slug}
item: {GitHub issue number, or "none"}
status: Draft
priority: {P1 if MVP, P2 if v2, etc.}
created: {YYYY-MM-DD}
last_updated: {YYYY-MM-DD}
constitution_check: {aligned / N violations / N/A}
---

# Spec: {Feature Name}

## User Scenarios

### User Story 1 — {Brief Title} (Priority: P1)

{Describe the user journey in plain language. 2-3 sentences max.}

**Why this priority**: {Why it's P1. Business value, risk, user pain.}

**Independent Verification**: {How to verify this story works on its own, without other stories implemented. If this story can't be verified alone, reconsider the decomposition.}

**Acceptance Scenarios**:

1. **Given** {initial state}, **When** {action}, **Then** {expected outcome}.
2. **Given** {initial state}, **When** {action}, **Then** {expected outcome}.

---

### User Story 2 — {Brief Title} (Priority: P2)

{Same structure.}

---

{Add P3 if needed. Stop when the next story is no longer core to the feature value.}

### Edge Cases

- {What happens when {boundary condition}?}
- {How does the system handle {error scenario}?}
- {What if {concurrent action / race condition}?}

## Requirements

### Functional Requirements

- **FR-001**: System MUST {specific capability}.
- **FR-002**: Users MUST be able to {key interaction}.
- **FR-NNN**: ...

If the work item has acceptance criteria, use them as a starting point, then refine to spec-level precision.

### Key Entities (include only if data involved)

- **{Entity Name}**: {What it represents, key attributes WITHOUT implementation. e.g., "Order: belongs to a User, has a total amount, transitions through pending → paid → fulfilled."}

## Success Criteria

Each criterion MUST be measurable AND technology-agnostic.

- **SC-001**: {Measurable outcome with a number or threshold}. Example: "Users complete checkout in under 3 minutes."
- **SC-002**: {Measurable outcome}. Example: "95% of imports succeed on the first attempt."
- **SC-NNN**: ...

### Anti-examples (DO NOT WRITE)

- ❌ "API response time under 200ms" — implementation detail. Use: "Users see results within 1 second".
- ❌ "Database handles 1000 TPS" — implementation detail. Use a user-facing metric.
- ❌ "React components render efficiently" — framework-specific.

## Assumptions

- {Each assumption documents a default the spec chose without explicit user confirmation. Example: "Data retention default is 90 days, industry standard for e-commerce."}
- {Each NEEDS CLARIFICATION marker that did not fit in the 5-question budget gets noted here with the chosen default.}

## Out of Scope

- {What this spec EXPLICITLY does NOT cover. Prevents scope creep.}
- ...

## Clarifications

### Session {YYYY-MM-DD}

{Empty until Phase 3 (CLARIFY) runs. Bullet list of resolved Q&A.}
