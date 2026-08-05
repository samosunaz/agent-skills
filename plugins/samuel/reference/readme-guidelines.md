# README Guidelines — Structure, Philosophy & What to Promote

The README is the project's **front door for humans** — users and contributors. Not for agents (that's `CLAUDE.md`), not the product catalog (that's a dossier in `docs/product/`), not the reasoning (that's an ADR). `/samuel:done` checks at close whether a change altered how a human installs, runs, or understands the project, and proposes a surgical README update. `/samuel:kickoff` uses this structure to seed a new project's README.

## Philosophy

- **Audience: humans.** Someone evaluating, installing, or contributing — not an LLM. Optimize for a stranger's first 30 seconds.
- **Above the fold.** The first screen answers: *what is this, who is it for, why would I use it.* If a stranger can't tell in 30s, the top is wrong.
- **Functional quickstart.** The shortest copy-pasteable path from zero to "it runs". Commands that actually work — test them (same bar as CLAUDE.md).
- **Show, don't tell.** Concrete commands and examples over abstract prose.
- **Link, don't duplicate.** The README is the entry point, not the manual. Deep detail lives in `docs/`, dossiers, ADRs. A capability's full doc is its dossier; the README gets a one-line pointer.
- **Earn every line.** A bloated README goes unread. Cut anything a stranger doesn't need to start.
- **Stay true.** Out-of-date install/commands are worse than none — fix them when a change breaks them.

## Canonical structure (order)

Include what applies; omit the rest. Don't invent sections a small project doesn't need.

1. **Title + one-line description** — what it is, for whom. *(Required.)*
2. **Badges** *(optional)* — build/CI, version, license.
3. **Demo / screenshot** *(optional)* — for visual / user-facing products. Claude can't generate these; insert a `[Screenshot: …]` placeholder and ask the user.
4. **Features / what it does** — a concise bulleted list of capabilities. Significant ones link to their dossier.
5. **Prerequisites** — runtime versions, system deps, accounts/keys needed to run it.
6. **Installation** — the copy-pasteable happy path.
7. **Quickstart / Usage** — shortest path to a working result, with a real example.
8. **Configuration** *(if any)* — env vars, flags, options. Name + purpose, table form.
9. **Commands / scripts** *(if non-trivial)* — table of the scripts a human runs.
10. **Project structure** *(optional)* — a tree, only if it aids navigation.
11. **Contributing / development** *(optional)* — run locally, test, the dev loop.
12. **License** *(if open/shared)*.

## What to promote at close — the `/samuel:done` filter

Ask: **did this change alter how a human installs, configures, runs, or understands the project at a high level?** If yes, propose the update to the matching section.

| Change | README section |
|---|---|
| New runtime/system dependency or a version bump that gates running it | Prerequisites |
| New required env var / config to run | Configuration / Installation |
| New script or command a human runs (`bun run seed`, a CLI verb) | Commands / Usage |
| New significant **user-facing capability** | Features — a one-line entry; link its dossier if one exists |
| Changed setup or quickstart steps | Installation / Quickstart |
| New top-level module/dir worth navigating | Project structure |

**Not** README-worthy: internal refactors, bugfixes, anything invisible to a human getting started; an operating gotcha for agents (→ `CLAUDE.md`); the *why* of a decision (→ ADR); the deep *how* of a capability (→ its dossier — the README gets only the one-line pointer).

> **Overlap with the dossier.** A significant capability's full doc is its dossier (`docs/product/`), and `/samuel:feature-dossier` Phase 5 already proposes the README *pointer*. `done`'s README pass covers the rest — install / config / commands / prerequisites / quickstart — and, for a small user-facing feature with no dossier, the Features entry itself. Don't duplicate the dossier's content into the README.

## Mechanics (same as the CLAUDE.md pass)

- **Interactive**: propose the exact diff to the matching section with a one-line **Why**, forced checkpoint, **never auto-edit**. Approved edits ride the PR.
- **Autonomous (`--draft`)**: don't edit the README unattended — list the candidate change + target section in the PR body / stop report for human review.
- **Surgical, not rewrites**: touch only the affected section; preserve the rest. Keep the structure order above.
