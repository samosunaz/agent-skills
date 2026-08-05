# Team Archetypes

Four reusable team compositions. Each defines: when to pick it, sizing, role definitions, file ownership rules, spawn prompt template per role, and the lead's synthesis deliverable.

Read only the archetype matching the user's intent. Don't load all four.

---

## review-team

Parallel audit of a PR or component, splitting the review into independent dimensions so each gets full attention without anchoring bias.

### When

- "review this PR", "audit this module"
- The change has multiple independent risk surfaces (security + performance + correctness)
- A single reviewer would gravitate to one dimension and miss others

### Sizing

3 teammates by default. Add a fourth (`architecture-reviewer`) only when the change is structural, not just behavioral.

### Roles

| Name | Lens | Subagent type (optional) |
|---|---|---|
| `security-reviewer` | auth, input validation, secret handling, injection, sessions, rate limits | — |
| `performance-reviewer` | query plans, N+1, allocations, hot paths, caching, large payloads | — |
| `tests-reviewer` | coverage gaps, missing edge cases, brittle assertions, test quality | — |
| `architecture-reviewer` *(optional)* | layering, coupling, conventions, OCP/SOLID violations | — |

### File ownership

Read-only. No conflicts possible — skip the ownership map.

### Spawn prompt template

```
Role: {{role}}-reviewer for the team.
Scope: PR #{{number}} on {{repo}}, files listed below. Read only.

Files to review:
{{file_list}}

Context bundle:
- Branch: {{branch}}
- Linked issue: {{issue number, if any}}
- Acceptance criteria: {{from spec}}
- Stack: {{tech notes that matter for your lens}}

Lens: {{role-specific concerns — security/performance/tests/architecture}}.
Do NOT comment on style, linting, or pre-existing issues outside this PR.

When you have findings, send to team-lead with:
SendMessage(target="team-lead", value="
## {{role}} review
### Critical (block merge)
- file:line — issue — why it matters
### Should fix
- file:line — issue — why
### Nits (optional)
- file:line — note
### Confidence
- High / Medium / Low — and why
")

Stop condition: you've covered every file in scope. Mark task complete.
```

### Lead synthesis deliverable

A single PR review comment with:
1. Summary verdict (approve / request changes / block)
2. Critical findings deduplicated across reviewers (with file:line)
3. Should-fix findings, grouped by reviewer
4. Open questions for the author

If two reviewers disagree (one flags, one doesn't), surface the disagreement explicitly — don't silently pick a side.

---

## debug-team

Investigation of an ambiguous bug where multiple causes are plausible. Each teammate owns one hypothesis and actively challenges the others. The theory that survives adversarial scrutiny is the most likely root cause.

### When

- Bug is intermittent, environment-specific, or has multiple plausible causes
- Single-agent investigation would anchor on the first plausible explanation
- "investiga teorías", "debug con hipótesis", "no sabemos por qué pasa esto"

### Sizing

3-5 teammates. One per credible hypothesis. Below 3 you don't get debate; above 5 the synthesis gets noisy.

### Roles

Each teammate is a `hypothesis-investigator` with a distinct theory. Name them after the theory, not the role: `tz-investigator`, `redis-ttl-investigator`, `clock-skew-investigator`, etc.

### File ownership

Read-only during investigation. If a fix is needed afterward, **the lead picks one implementer** — don't have multiple investigators write fixes in parallel.

### Spawn prompt template

```
Role: hypothesis-investigator for the team. Your hypothesis: {{theory}}.
Symptom under investigation: {{user-reported symptom, verbatim}}

Reproduction signals known so far:
{{frequency, environment, recent changes, error logs, etc.}}

Your job:
1. Investigate evidence FOR your hypothesis: read code, logs, config, recent commits.
2. After every team member has reported initial findings, READ the others' reports via TaskList + TaskGet.
3. Actively challenge their hypotheses. Try to disprove them with concrete evidence (file:line, log line, commit hash).
4. Defend your own hypothesis against their challenges.
5. Iterate until consensus or until evidence rules your theory out.

Reporting protocol:
- Initial findings: SendMessage to team-lead with evidence for/against your theory.
- Challenges to peers: SendMessage to the specific peer (not lead) with the counter-evidence. CC team-lead.
- Final verdict: when you can no longer defend or attack, report to team-lead with one of:
  - "Theory survives — root cause is X (evidence: ...)"
  - "Theory ruled out — evidence Y disproves it"
  - "Inconclusive — cannot prove or disprove with available data; here's what we'd need"

Do NOT propose fixes during investigation. Diagnosis only.

Stop condition: final verdict reported and no peer is currently challenging you.
```

### Lead synthesis deliverable

A diagnosis document with:
1. Symptom (verbatim)
2. Surviving theory (with evidence)
3. Ruled-out theories (each with the disproving evidence)
4. Inconclusive areas (with what data would resolve them)
5. Recommended fix path (single owner)

---

## feature-team

Cross-layer feature that touches independent modules. Each teammate owns one layer end-to-end, with strict file boundaries to prevent overwrites.

### When

- Feature spans frontend + backend + tests, or multiple independent modules
- Each layer has clear boundaries (separate repos, dirs, or packages)
- Spec is sharp enough that layers can advance in parallel without constant cross-talk

If the spec is vague, **do not spawn**. A vague spec paralleled across teammates produces 5× the rework. Use `/samuel:plan` first.

### Sizing

2-4 teammates. One per layer. Match the actual layer count — don't pad.

### Roles

Adapt to the project. Common shapes for indie projects:

| Name | Owns | Subagent type |
|---|---|---|
| `frontend-dev` | UI, state, API calls | `general-purpose` or domain-specific |
| `backend-dev` | endpoints, models, services, migrations | `general-purpose` |
| `tests-dev` | unit + integration + e2e | `general-purpose` |
| `infra-dev` *(optional)* | env vars, queues, deploy config | `general-purpose` |

For a game project you may collapse to `gameplay-dev` (mechanics, scene graph) and `tooling-dev` (build, asset pipeline, persistence). For a content-heavy web app: `web-dev` (Next/Remix) and `data-dev` (db schema + ETL). Pick the split that matches the natural seams of YOUR project.

### File ownership

**Mandatory** for this archetype. Print the map before spawning and confirm with the user.

Example for a multi-repo indie project:
```
frontend-dev → <workspace>/<project>/web/**
backend-dev  → <workspace>/<project>/api/**
tests-dev    → both repos but ONLY *.test.*, *.spec.*, tests/**, __tests__/**
```

Example for a monorepo:
```
frontend-dev → apps/web/**, packages/ui/**
backend-dev  → apps/api/**, packages/db/**
tests-dev    → **/*.test.*, **/*.spec.*, e2e/**
```

### Spawn prompt template

```
Role: {{layer}}-dev for the team.
Feature: {{feature name}}.
Spec: {{summary or link to the Issue's Executor Plan}}.

Files in scope (you own these — peers will not touch them):
{{ownership map for this teammate}}

Files OUT of scope (do not edit, but you can read for context):
{{paths owned by other teammates}}

Acceptance criteria for your layer:
{{layer-specific criteria}}

Cross-layer contract:
{{shared API shape, event names, types — agreed up front by lead before spawning}}

Plan approval: REQUIRED before any file write.
First step: produce a plan in plan-mode listing files you'll touch and why.
SendMessage(target="team-lead", value="<plan>") and wait for approval.

After approval:
1. Implement layer-by-layer per your plan.
2. Run your tests locally. Iterate until green.
3. SendMessage(target="team-lead", value="<implementation summary + diff stats>")
4. Mark task complete.

Coordination:
- Need data from another layer? SendMessage to that teammate by name. Do not block — keep working on independent pieces.
- API/contract change discovered mid-flight? Stop, message lead, do not unilaterally change shared types.

Stop condition: your tests are green and lead has acknowledged your summary.
```

### Lead synthesis deliverable

1. **Pre-spawn**: a sharp cross-layer contract (API shape, types, event names) that all layers agree on. Without this, do not spawn.
2. **Mid-flight**: approve plans, mediate cross-layer questions, hold the contract.
3. **End**: integrated diff summary, single PR or coordinated PRs, smoke test before handoff to user.

---

## research-team

Multi-angle exploration of an open problem, library, or design space. Each teammate explores one angle independently; the lead synthesizes a balanced view.

### When

- "explora X desde varios ángulos"
- Library / framework evaluation
- Pre-plan discovery for a technical decision
- A single investigator would skew toward one frame

### Sizing

3-4 teammates. One angle per teammate. Below 3 you don't get the multi-angle benefit; above 4 the synthesis dilutes.

### Roles

Define angles per the question. Examples:

| Question | Angles |
|---|---|
| "Should we adopt Inertia?" | DX, performance, ecosystem, migration cost |
| "How do we structure the marketplace fees?" | UX, revenue model, fraud risk, devil's advocate |
| "Pick a queue: Redis vs SQS vs Kafka" | each option as one teammate, plus a constraints/cost teammate |
| "Three.js vs React Three Fiber for a new game" | DX, performance ceiling, ecosystem, learning curve |

### File ownership

Read-only. No conflicts.

### Spawn prompt template

```
Role: {{angle}}-investigator for the team.
Question: {{user's research question, verbatim}}.

Your angle: {{angle}}.
You explore the question ONLY through this lens. Other angles are owned by peers.

Sources to consult (in order):
1. The codebase at {{repo path}} — what exists today
2. Issue comments / recorded decisions / past notes
3. External docs / web (only if relevant to your angle)

Produce findings as:
SendMessage(target="team-lead", value="
## {{angle}} angle
### Key facts (with file:line, doc URL, or issue ref)
- ...
### Implications for the decision
- ...
### Risks / unknowns
- ...
### My recommendation (within this angle only)
- ...
")

You may message peers if your angle conflicts with theirs — but do not try to converge. The lead synthesizes.

Stop condition: findings reported, peers findings read, any cross-angle clarifications resolved.
```

### Lead synthesis deliverable

A balanced decision document:
1. Question (verbatim)
2. Findings per angle (compressed, with refs)
3. Cross-angle tradeoffs (what one angle wants that another opposes)
4. Lead's recommendation with reasoning
5. Open questions / what would change the answer

If the user asked for a decision, give one. If they asked for exploration, leave the question open and surface the tradeoffs.

---

## Custom composition

If none of the four archetypes fits, design one. Required elements regardless:

- Clear distinct lens per teammate (no overlap)
- File ownership map (or "all read-only")
- Reporting protocol (`SendMessage` to `team-lead` with structured payload)
- Stop condition per teammate
- Synthesis deliverable defined upfront

Confirm the custom design with the user before spawning. Don't improvise on a 4×-token operation.
