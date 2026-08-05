# Validation Report: 27 — samuel: modo attended-auto

**Date**: 2026-07-27   ·   **Item**: 27   ·   **Branch**: `feat/27-attended-auto`   ·   **Base**: `c03864b`

## Overall: PASS WITH NOTES

> Computed: gate green, security scan skipped (neutral), final independent review `APPROVE` with no Blocker and two Important findings — both fixed in the same pass. Journal **sealed**.

This report supersedes the round-1 version (`Overall: FAIL`, commit `b8888c8`), whose counts and assertion totals no longer describe HEAD.

## Gate

- **PASS** `bun run check:context && bun run check:plugins && bun run check:autonomy`
  - `check:context` → `Context commands OK`
  - `check:plugins` → `✔ Validation passed` (3 manifests)
  - `check:autonomy` → **18 assertions**, all PASS: G1 checkpoint coverage · G2 5/5 skills read the key and point at the spoke · G2b 5/5 read lines byte-identical to the documented one · G2c 5/5 carry the unattended override, naming headless runs · G3 spoke exists · G4a-h read-chain resolution across eight value states · G5 conductor parentheticals == 9 · G6 per-skill cross-check of promised gates vs wired clauses · G6b no line citations in the gate table · G7 unattended precedence covers conductor + headless · G8 template ships the key inert
- **SKIP** security: no `security_scan` field in `.claude/samuel.md` — no scan configured, skipping. Courtesy check: no `.gitleaks.toml` / `.semgrep*` at repo root, so nothing to wire.

## Independent Review — four rounds

| Round | Verdict | 🔴 | 🟡 | 🔵 | What it caught |
|---|---|---|---|---|---|
| 1 | REQUEST CHANGES | 1 | 5 | 1 | journal-contract contradiction; 12 stale `file:line` citations; the value whitelist existed only as prose |
| 2 | REQUEST CHANGES | 3 | 4 | 1 | **the gate was vacuous** — proven by mutation; AC1 unmet at `done`; two Critical Rules named the conductor as the only bypass |
| 3 | REQUEST CHANGES | 1 | 4 | 3 | round 2's own fix deleted the last confirmation before `git push` |
| 4 | **APPROVE** | 0 | 2 | 2 | commit-authority pointer ambiguous; a summary sentence overstated which acks are gone |

Every finding accepted was independently reproduced against the tree before being acted on — including round 2's central claim, which required reverting a shipped read line and watching the gate stay green.

## Criteria

| AC / DoD | Status | Evidence |
|---|---|---|
| AC1 — cycle without acks except the two `done` gates that wait at all levels | PASS | Path walk under the live key: `implement` §1 auto → §2 (a)-(d) no gate → (f) commits inline → (g) auto → §3 no gate → `done` §1 auto → **§2 waits** → §3 no gate → **§4 forced** → §5 auto. Two typed acks, exactly as amended. AC1 was amended **twice** — see Notes |
| AC2 — no key → `interactive`, checkpoints intact | PASS | `check:autonomy` G4a; every original checkpoint sentence retained with the clause appended, never replaced |
| AC3 — conductor bypass unrewritten, 9 parentheticals | PASS | G5 → `9 parentheticals`; the original count of 10 included the conductor's own H1 title, corrected in the AC |
| AC4 — hard stops halt at all three levels | PASS | 5 `**waits**` rows, each mapped to a real marked stop: `implement:64` HARD STOP, `implement:92` WAIT, `done:81` WAIT, `done:131/135/139` forced checkpoint, `start-task:66` WAIT |
| AC5 — three checks green | PASS | Full gate output above |
| DoD — key switched on | PASS | `.claude/samuel.md` (gitignored), chain resolves `attended-auto` live |
| DoD — journal records both reversals | PASS | V-002, V-003, both with `Linked decision` |

## Notes (not blocking)

- **N1 — AC1 was amended twice during validation.** First (D-003) to stop promising a `D-NNN` for every gate default; then (D-006) to concede the two `done` gates that wait at every level. Both amendments narrowed the criterion to match a guarantee that already existed elsewhere in the repo, rather than widening the implementation to meet it — but an AC touched twice in one validation deserves a second look at the next planning pass. The original was written assuming every checkpoint in the cycle was soft; two are not.
- **N2 — the scope landed at 8 gates, the number the plan specified**, after briefly reaching 9 (D-004) and reverting (D-006). `start-task`'s `spec_required` replaced the Issue's original enumeration of seven (D-002).
- **N3 — the gate is now mutation-tested, not just green.** Every assertion was made to fail deliberately: stripping the whitelist from one skill (G2b), corrupting the documented line (G2b ×5 + G4e), rewriting a conductor parenthetical (G5), moving or adding a clause (G6 ×2), flipping a `**waits**` row to moving (G6 ×2), reinstating a line citation (G6b), narrowing the override to the conductor alone (G2c), switching the template key on (G8). A count-only gate was what let round 1's twelve broken citations ship green.
- **N4 — `/samuel:validate` Step 1 spawned 2 of 3 research agents.** `pattern-scanner` was skipped: the plan specifies no tests, and this is a markdown repo with no test suite.

## Manual Testing Checklist

1. Run `/samuel:next` in a repo with exactly one `pipeline:ready` issue → expect it pulled without a menu, with a line naming what was pulled and that it was the only candidate.
2. Remove the key from `.claude/samuel.md`, re-run → expect the menu to render and wait.
3. Run `/samuel:start-task N` under the key → expect a mode chosen and announced with its reason, and the branch **not** forced to a worktree.
4. Dirty the working tree, run `/samuel:start-task N` under the key → expect it to still stop and ask about stashing.
5. Run a full `implement` → `done` cycle under the key → expect exactly two typed acks (DoD, durable knowledge) and no `D-NNN` entries recording mere continuation. **This is AC1's real test and the point of the one-week dogfood.**
6. Set `autonomy: autonomous` by hand in `.claude/samuel.md` → expect every skill's Context to read `interactive`.

## Journal: D:6 V:4 T:1 Q:0 (open: 0)  ·  Deviations: 4

Sealed. Six decisions, three of them corrections found by the independent reviewer rather than by the gate (D-001's whitelist, D-005's vacuous probe, D-006's push authority).

## Documentation impact

Checked: reference files, root `README.md`, root `CLAUDE.md`, `template/`, `.github/` workflows.

- Root `CLAUDE.md` § Critical Patterns — **updated in this change**: the forced-checkpoint bullet said "Never auto-advance", which the third level makes false in a repo that opts in. It now names the three levels and the hard stops that bind across all of them.
- `template/samuel.md` — **updated**: the field ships with its gloss and **commented out**, so a repo copying it verbatim keeps today's behaviour. G8 enforces this.
- `plugins/samuel/reference/tracker.md` — **updated**: the field documented in the schema, its example commented to match the template.
- `plugins/samuel/reference/interaction-tools.md` — **updated**: § Boundary's "whether a checkpoint is skipped" row handed from `/samuel:conductor` to `autonomy.md`.
- `plugins/samuel/skills/workflow/conductor/SKILL.md` — **updated**: states that a conductor run is `autonomous` regardless of any `autonomy:` key.
- `README.md` § Configuration — shows a `samuel.md` example with `tracker` + `repo` only, and also omits the pre-existing `security_scan`. Consistently minimal rather than newly stale. **No change proposed.**
- `.github/` — only `release-please.yml`; no CI runs any `check:*` script, so `check:autonomy` is unwired exactly like its two siblings. Pre-existing, not introduced here — worth a follow-up Issue.
- **Feature dossier**: not warranted. This changes the pipeline's own operation, not a user-facing product capability.
