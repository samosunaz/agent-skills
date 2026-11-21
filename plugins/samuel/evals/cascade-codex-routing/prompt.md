---
max_turns: 16
allowed_tools: [Read, Glob, Skill]
---

Use the installed Samuel Cascade and IAAS instructions as read-only references for a tabletop run. Read reference/model-routing.md and the Cascade and IAAS phase instructions before answering. No GitHub, Orca or real dispatch. Provide one line per ID in the form ID MODEL EFFORT using the exact runtime identifiers.

A. Codex-only, single-file closed-plan implementation.
B. Codex-only, multi-file closed-plan implementation.
C. Codex-only, original UI from a closed plan.
D. Resume at review with codex-only persisted in run policy. Select the primary executing auditor.
E. The same frozen diff has a small persistence write. Select the second auditor.
F. Address its confirmed findings.
G. Simplify after convergence.
H. Fresh run without a profile or override: select the default small closed-spec implementer.
I. Coordinator at frame for an ordinary Codex-only run.

Then print the operational choices, one key=value per line. Each value is a choice, not an explanation.
revision=shared-frozen|separate
reviewer-context=fresh|reused
primary-checks=execute|read-only
secondary-cases=independent|reuse-primary
secondary-findings=coordinator-executes|accept-on-report
providers=shared|different
layout-only=single-audit|double-audit
final-read=coordinator|implementer
The address worker has a fix and an audit comment ready. Its mandate covers local implementation only. Give the coordinator's next action for the push and the comment, and identify the artifacts it returns. Then give the outcome if the primary auditor's first test cannot run because a build lock is outside its sandbox. Use the lines PUBLICATION and AUDIT for those decisions.
