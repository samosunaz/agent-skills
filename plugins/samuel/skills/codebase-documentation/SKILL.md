---
name: codebase-documentation
description: Document codebase as-is through parallel sub-agent research and synthesis. Use when user asks to understand, explore, or document how code works without making changes.
allowed-tools: Bash(git rev-parse *) Bash(git branch *) Bash(date *) Bash(basename *) Bash(awk *) Read Write Agent
---

# Codebase Documentation

Conduct comprehensive research across the codebase by spawning parallel sub-agents and synthesizing their findings.

## Metadata

- Date: !`date '+%Y-%m-%d %H:%M:%S %Z'`
- Git commit: !`git rev-parse HEAD 2>/dev/null || echo "NO_HEAD"`
- Branch: !`git branch --show-current 2>/dev/null || echo "NO_BRANCH"`
- Repository root: !`git rev-parse --show-toplevel 2>/dev/null || echo "NO_REPO_ROOT"`
- Feature: !`awk '/^feature_slug:/{sub(/^[^:]*: */,"");print;f=1}END{if(!f)print"NO_FEATURE"}' .claude/task-context.md 2>/dev/null || echo "NO_FEATURE"`

## CRITICAL: YOUR ONLY JOB IS TO DOCUMENT AND EXPLAIN THE CODEBASE AS IT EXISTS TODAY

- DO NOT suggest improvements or changes unless the user explicitly asks for them
- DO NOT perform root cause analysis unless the user explicitly asks
- DO NOT propose future enhancements unless the user explicitly asks
- DO NOT critique the implementation or identify problems
- ONLY describe what exists, where it exists, how it works, and how components interact

## Initial Setup

When this skill is invoked, respond with:

```
I'm ready to research the codebase. Please provide your research question or area of interest, and I'll analyze it thoroughly by exploring relevant components and connections.
```

Then wait for the user's research query.

## Steps

1. **Read any directly mentioned files first:**
   - If the user mentions specific files, read them FULLY first (no limit/offset)
   - **CRITICAL**: Read these files yourself in the main context before spawning sub-agents

2. **Analyze and decompose the research question:**
   - Break down the user's query into composable research areas
   - Identify specific components, patterns, or concepts to investigate

3. **Spawn parallel sub-agents for comprehensive research:**

   **CRITICAL**: Spawn ALL agents in a **single message** for maximum parallelism. Use `model: "sonnet"` for each.

   **Round 1 — Locators** (all in one message):

   | `subagent_type` | Job |
   |-----------------|-----|
   | `component-locator` | Find WHERE files and components live |
   | `pattern-scanner` | Find examples of existing patterns |

   **Round 2 — Analyzers** (after Round 1, only if findings warrant deeper analysis):

   | `subagent_type` | Job |
   |-----------------|-----|
   | `implementation-analyzer` | Understand HOW specific code works (on most promising files from Round 1) |

4. **Wait for all sub-agents to complete and synthesize findings:**
   - Compile all sub-agent results
   - Connect findings across different components
   - Include specific file paths and line numbers
   - Answer the user's specific questions with concrete evidence

5. **Generate research document:**

   Persist to `{feature_dir}/research.md` — see `../../reference/tracker.md`:

   A committed file — `Write` to `docs/features/{slug}/research.md` (feature) or `docs/research/{topic}.md` (standalone). Commit it on the branch.

   Inside a flow feature (`Feature` ≠ `NO_FEATURE`), edit `.claude/task-context.md`: `phase: research`, `last_updated: {today}`. Standalone, skip the phase update.

   **Document structure:**

   ```markdown
   # Research: [User's Question/Topic]

   **Date**: [Current date and time]
   **Git Commit**: [Current commit hash]
   **Branch**: [Current branch name]

   ## Research Question

   [Original user query]

   ## Summary

   [High-level documentation of what was found]

   ## Detailed Findings

   ### [Component/Area 1]

   - Description of what exists (file.ext:line)
   - How it connects to other components

   ## Code References

   - `path/to/file.py:123` - Description
   - `another/file.ts:45-67` - Description

   ## Open Questions

   [Any areas that need further investigation]
   ```

6. **Present findings:**
   - Concise summary to the user
   - Include key file references
   - Mention the research doc was saved
   - Ask if they have follow-up questions

## Important notes

- **Parallel first**: Always spawn ALL research agents in a single message
- **Model selection**: Use `model: "sonnet"` for sub-agents
- Always run fresh codebase research
- Focus on finding concrete file paths and line numbers
- Research documents should be self-contained
- **CRITICAL**: You and all sub-agents are documentarians, not evaluators
- **File reading**: Always read mentioned files FULLY (no limit/offset) before spawning agents
- Round 2 agents are optional — only spawn if Round 1 findings warrant deeper analysis

## Gotchas

_Add a line each time Claude trips on something._

- Always read files FULLY (no limit/offset) before spawning agents — partial reads lead to missed context.
- Round 2 agents are optional — don't always spawn both rounds.
- Research docs are descriptive, not prescriptive. Document what IS, never suggest what SHOULD BE (unless user asks).
