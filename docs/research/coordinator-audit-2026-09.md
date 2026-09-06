# Coordinator audit — two weeks of Claude-as-coordinator over Orca

**Window**: 2026-08-22 → 2026-09-05 (transcripts modified in the window; first messages reach back to 08-20) · **Repos**: two personal repos (an AI site-builder web app and a 3D city experiment) · **Corpus**: 393 Claude Code sessions, 2 947 user-turn messages, of which 36 are coordinator sessions driven by the human (2 241 turns) and 337 are Orca worker sessions (628 turns, mostly the dispatch brief itself).

**Method**: user turns extracted per session (assistant text excluded, tool-use counts kept), split into four coordinator chunks and one worker-brief chunk, each read in full by an independent auditor (Opus 5, high); a fifth independent pass was planned on Codex and fell back to Sonnet when the Codex quota was exhausted. Counts below are the auditors'; quotes are the human's, verbatim.

## Headline

The coordinator's tooling was never the gap — Orca 1.4.193 already exposes `worker-start --model --effort` with a `launch.effective` receipt, `worker-read`, `worker-release`. The gap is **coordinator behaviour**, and it repeats identically across all four chunks:

| Pattern | Evidence (across chunks) |
|---|---|
| Silent waits | 55-min `check --wait` windows; "¿cómo va?", "reanuda", "en qué quedó" asked 30+ times, always 30–90 min after the last coordinator line; one session had 6 asks in 36 min with 5 assistant turns and zero tool calls |
| Coordinator does not drain its inbox | the runtime injected `You have 1 orchestration message. Run orca orchestration check` 124× in one chunk, 205× in another — the harness poking a coordinator that ended its turn with dispatches open |
| Unproven starts | two 50-min windows burned on workers that never ran (lost Enter, `input_accepted` taken as execution); "Revisa nuevamente codex, parece que se pausó" — the human saw it first |
| State relayed by hand | "merged" typed 16+×; Codex quota state 5× ("si te estoy mandando mensajes es porque ya se reinició"); pasted agent-to-agent reports; 108 screenshots in one chunk alone |
| Standing constraints retyped | model/effort table 6–8× ("todos con opus 5 high, el único con opus 5 xhigh es audit"); "menor cantidad de código posible" 9×; "impersóname" 8×; no-legacy-compat and no-narration-comments each restated after the fact — two dispatches cancelled purely over routing |
| Fan-out kills | 21 and 24 background subagents killed at once, twice |
| Direct-lane misses | an S with no behaviour change ran 30+ min in worker phases: "¿no era solo agregar un background y ya?" |
| Context | single sessions of 3 600–4 400 assistant turns with 6–7 compactions; the human runs `/samuel:session-handoff` on his own initiative |
| Re-armed waits | one worker leg produced four consecutive "report the expired window and re-arm a new 9-minute wait" cycles, ~36 min of empty windows; 34 of 58 background commands in that session were waits, re-arms or heartbeat acks |
| Outcome opacity | "tldr, ¿qué se logra con 1120? ¿hay cambio visual?" and six near-identical asks — reports described work, not the change |

Bare predictable acks ("adelante", "aprobado", "todo ok") are 11–12 % of the human's typed volume; merge orders (a legitimate gate) another ~5 %; the real decisions are long, dense, and where his attention belongs.

**Worker briefs** (125 coordinator-authored briefs with visible text, out of 341 worker sessions): one clear outcome 65 % · base branch or start SHA 58 % (an explicit SHA only 15 %) · files it MAY change 37 % · MUST NOT touch 85 % · how completion is verified 30 % · required report format 34 %. Prohibition was the reflex; positive scope, base commit and report shape were not. Model, effort and role appeared in **zero** opening briefs (only in corrective follow-ups such as "Restart the required independent implementation reviewer using Claude Opus 5 at high effort"), and zero of 87 workspace names encoded role or model — the four phases of one item shared an identical `issue-N-slug` name. Zero briefs told the worker not to paste logs, zero mentioned screenshots, and only 3 asked for the frozen SHA back. 20 % of workers got a second message, 13 % three or more; the largest follow-up class was subagent results relayed into the worker, then quota resumes (4) and re-sent preambles (4, the lost-Enter signature).

Isolation ran both ways wrong: **18 % of visible briefs were byte-identical re-dispatches into the same live workspace** (seven full-strength simplify briefs into one checkout between 17:35 and 18:22, each 68–94 assistant turns — concurrent writers on one tree), while six dedicated checkouts were created for briefs that said `READ ONLY`. 63 % of dispatches spent their whole visible opening on the Orca preamble before the task appeared.

Brief quality, where a worker session captured the coordinator's brief, was otherwise **high** (worktree path, branch, base SHA, gate command, "the PR stays DRAFT", anti-padding clauses). What the human had to add afterward was always the same four: model/effort, least code, impersonation, scope exclusions. Consistency, not quality, is the gap.

## Independent pass (Sonnet, script-based)

Codex's job died on a usage limit at the first turn; the same six-part analysis ran on Sonnet with regex classifiers over the corpus (scripts under `/tmp/convo-audit/codex-scratch/`). It converges with the readers: 62 % of logged coordinator-session entries are harness injections (task notifications, orchestration nags, teammate relays), not the human; of the human's 886 turns, 15 % are state relay, 10.5 % bare acks, 5.3 % status polls, 1.7 % corrections. Top correction by count is "menor cantidad de código posible antes del simplify" (12×). Model and effort were overridden **proactively** 48× with **zero** reactive complaints — a per-dispatch tax the run policy removes. Quota/spend-limit hits: 10. The headless-worker-exits-while-a-background-gate-runs bug appeared 4× and was worked around by template text each time (already a `waves` gotcha). On fully captured briefs it measured allowed-files scope at **0 %** versus forbidden scope at 78 %.

Data caveat, mine: the extractor capped each message at 1 500 characters, so 89 % of worker briefs were truncated before the task text; the brief-anatomy numbers above rest on the 125 (readers) / 36 (scripts) briefs that fit. The two samples agree on the shape.

## What changed — `/samuel:coordinate`

The Herdr-style coordinator (Fable directs, Opus takes frontend, Codex takes backend/tests, a third model reviews, every worker in its own pane and worktree, short report back) mapped onto Orca:

| Herdr concept | Orca / skill equivalent |
|---|---|
| pane per worker, header shows name/model/effort | `orca orchestration worker-start --name <task>-<role>-<model> --agent … --model … --effort …`; the name becomes branch, path and sidebar card with no rename; receipt `launch.effective` checked, mismatch stops the run (pane titles are rewritten by the agent TUI, so identity lives in the card, not the title) |
| separate worktree for writers | `--worktree new-top-level` for writers, `--worktree current` for reviewers/researchers |
| short report first, diff on demand | six-line `worker_done` body; `git diff base..sha` from the coordinator's checkout only on scope/security/behaviour risk (worktrees share the object store) |
| wait for completion, follow up | rolling `check --wait` ≤ 9 min in the foreground, one status line per window, start proven with `worker-read` within 30 s, `worker-release` after reading |
| plan file with briefs and running list | Orca Run + Tasks as the running list; `.claude/run-policy.md` as the standing-constraints file appended to every brief; an idempotency check (`task-list` + `worker-list`) before every `task-create` |
| integrate in one checkout, real checks, no push | C6: local merge, the plan's gate or the repo's own checks, push/PR/publish gated on explicit approval |

Files: `plugins/samuel/skills/coordinate/SKILL.md` (hub), `references/dispatch-protocol.md` (C0–C6), `references/worker-brief.md` (run policy, six-slot brief, six-line report, status line). Registered in `README.md` and `CLAUDE.md`. All four repo gates pass.

## Decisions taken while adapting (for the human to confirm or override)

1. **Effort default**: implementers `high`, reviewers `xhigh`. The Herdr text says xhigh everywhere; the human's own dispatches said "opus 5 high, audit xhigh" far more often, and his effort discipline puts subagents at high. `--effort xhigh` raises implementers when wanted.
2. **Codex model** is read from `~/.codex/config.toml` at launch (currently `gpt-6-astra`), not pinned in the skill; the routing table in the global CLAUDE.md still names `gpt-5.5`.
3. **Direct lane stays in-session**: the Herdr rule "never implement yourself" yields to the existing `direct` chip for an S with no behaviour change, because the audit shows a worker costs more than the change there.
4. **Coordinator = flagship, workers = the rest.** The hub states it explicitly: the session that decides, briefs and signs off runs on the strongest model available and never implements; a non-flagship coordinator says so in the dispatch plan so the human can relaunch. This is the Herdr premise (Fable directs, Opus and Codex build) and the owner's routing table (Fable = orchestrator, never on mechanical volume), written into the skill because the skill is public and cannot assume the owner's global instructions.
5. **Run policy lives in `.claude/run-policy.md`**, per repo, gitignored — not in `samuel.md` (which is config the classifier blocks Claude from writing) and not in chat (which compacts).

## Substrate hardening applied (2026-09-06, same session)

A pass over `orca skills get orca-cli|orchestration` and `orca agent-context --json` (232 commands) surfaced eight capabilities the harness was not using. Landed:

- New shared spoke `plugins/samuel/reference/orca-substrate.md` — identity from the worktree name (branch = name, titles are rewritten by the agent TUI), agent status hooks (`worker-read` transcripts, `worker-show` `observation.agentWait` with its absent-vs-null semantics), managed accounts as the quota-death fallback surface, cards (`--comment`, `--workspace-status`) as the kanban, `file open-changed --mode diff` for in-editor review, embedded-browser captures (`capture start`, `full-screenshot`, `console`, `network`), automations with `--precheck` as the nocturnal trigger, paired environments + `worker-start --on` for remote workers, artifacts/skills sharing behind the human-only switch, `orca claude-teams`.
- `coordinate`: C0 checks hooks and accounts; C3 sets the card (issue, status, comment); C4 liveness runs `agentWait` → `worker-read` → `git log` → quota-death re-route in a fixed order, and a permission prompt in a worker is a relaunch, never a keyboard answer; C5 opens diffs in Orca and reads the UI worker's captures; C6 moves cards to `completed`/`in-review`, sweeps `worker-list --terminal-state reclaimable`, optionally publishes the report; a new § Unattended run defines the headless behaviour (record instead of announce, budget in wait windows, hard stops named).
- `waves`: P4 timeout checkpoint starts with `agentWait`, names quota deaths; gotchas for `agentWait` and `agent hooks prepare-codex` on the two-step Codex path.
- `team-orchestrate`: detects an Orca-managed session and prefers `orca claude-teams` over tmux.
- Owner account policy (three accounts, Personal sessions burn the personal one first, work fallback only when asked) recorded in this repo's `CLAUDE.local.md` and in memory — never in a skill. Observed: `orca account list` is the switchable set Orca manages (two of the three accounts, no Codex), not the active login — the ambient `claude auth status` account (the work primary) is what every worker was inheriting, invisible to that list.

Not applied, candidates for issues: an Orca automation (`--precheck`) as the nocturnal waves/coordinate trigger replacing the droplet loop; a paired remote environment recipe; a Codex account registration step in the conductor's launch preflight.

## Not done here

- The `~/.claude/CLAUDE.md` Orca section still describes only the lost-Enter check; the skill supersedes it for coordination runs but the global file was not edited (auto-mode classifier blocks that write; the human edits it).
- No live run of the new skill yet — its first use is the acceptance test. Expect gotchas to land in `SKILL.md § Gotchas` on that run.
