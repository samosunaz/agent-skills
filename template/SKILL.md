---
name: template-skill
description: Replace with description of the skill and when the agent should use it. Include 2-3 trigger phrases.
allowed-tools: Bash(git branch *) Read
---

# Skill Name

Brief description of what this skill does.

<!-- If this skill holds a human decision gate, keep the line below and add AskUserQuestion
     to allowed-tools. If it holds none (read-only, applies-and-reports, autonomous driver),
     delete it and add this SKILL.md to plugins/samuel/reference/checkpoint-exclusions.txt
     with a reason. One or the other — the coverage check has no third state. -->
> **Checkpoints:** ask with `AskUserQuestion` when the runtime exposes it; otherwise use the numbered-text fallback — `../../../reference/interaction-tools.md`.

## Context

- Current branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`

## Process

### Step 1: [Name]

[Intent-based instructions]

### Step 2: [Name]

[Intent-based instructions]

## Gotchas

_Add a line each time Claude trips on something._

## Rules

- [Key rule 1]
- [Key rule 2]
