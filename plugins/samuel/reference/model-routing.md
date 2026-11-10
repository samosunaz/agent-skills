# Model Routing & Token Economy

Personal model-routing policy. Load before selecting a model or effort for delegated work. The local entry point is `~/.claude/context/model-routing.md`.

These rules take precedence over project CLAUDE.md files (those govern code conventions, not model routing). Goal: reserve Claude capacity for high-judgment work; push mechanical volume to cheaper engines.

## Routing scores

Higher = better, on a 1–10 scale. These are coarse routing estimates informed by the sources below, not benchmark scores or measured probabilities. All capability scores are provisional until local task evaluations; a one-point difference is not a statistically established gap. Scores describe the model's demonstrated capability with sufficient effort, not every effort setting.

- **Cost preference** is personal policy: OpenAI allowance is generous and Claude capacity is scarce. It is not API price or measured subscription consumption. OpenAI models share a 9 until local quota measurements justify a distinction; Claude preferences retain the personal budget ordering.
- **Intelligence** estimates task complexity: 10 = the hardest technical projects, long unattended runs, and leading many workers; 9 = hardest open-ended work; 8 = complex implementation; 7 = scoped multi-step work; 6 = focused routine work. This is a routing rubric, not a universal intelligence ranking.
- **Taste** estimates original visual composition: 9 = strongest creative candidate in the reviewed evidence; 8 = strong alternative; 7 = eligible implementer with review; 5–6 = reference-constrained work. Evidence is mainly Code2Video-AA; it does not establish equivalent API-design, prose, or code-quality rankings. `unrated` means insufficient evidence, not poor quality.

| Model | Cost preference | Intelligence (estimated) | Visual taste (estimated) | Initial effort by role | Escalation | Default role |
|-------|-----------------|--------------------------|--------------------------|------------------------|------------|--------------|
| fable-5.2 | 3 | 10 | unrated | `high` for unattended runs, agentic work and review; `medium` for interactive sessions | `xhigh` only with a measured gain; `max` only to measure the ceiling | Hardest technical work, long unattended runs, coordinating many workers; the first step past Opus `high` |
| opus-5.5 | 4.5 | 9 | 9 | `medium` implementation; `high` general | `medium` → `high`; past `high`, Fable 5.2 before Opus `xhigh`/`max` | Implementation, coordination, final review |
| gpt-6-astra | 9 | 9 | 8 | `high` for the escalation role | `xhigh`; `max` for the hardest unresolved work | GPT escalation for reasoning and design |
| sonnet-5.5 | 5 | 8 | 8 | `medium` when explicitly routed | `high`; then Opus at `medium` | Scoped implementation and polished deliverables |
| gpt-6.1-sol | 9 | 8 | 7 | `medium` implementation | `high` for harder implementation; `xhigh` for demanding deliverables; Astra for unresolved complexity | General GPT implementer |
| gpt-6.1-terra | 9 | 7 | unrated | `medium` | `xhigh` for a still-bounded coding problem; Sol/Astra if scope or ambiguity grows | Visual QA, application use, bounded fixes |
| haiku-5.5 | 8 | 6 | 6 | `medium`; `low` for file location and other explicitly routed mechanical work | Sonnet 5.5, or the main model, when a wrong answer would be expensive to spot | Retrieval subagents (locate, read logs, summarize), focused extraction, mechanical work |
| gpt-6-luna | 9 | 6 | 5 | `high`; `low` only for explicitly routed mechanical work | Sol for implementation; Terra for visual/application work | Focused extraction, transformations, repetitive work |

Effort columns are operating recommendations, not measured score mappings. The capability estimates describe model potential; a `medium` run does not inherit a `max` benchmark result. Start directly at the effort appropriate to the task; escalation is not a requirement to exhaust every intermediate level. Explicit role settings take precedence over the general Opus `high` default; defined-agent contracts remain binding. Model/effort selection does not authorize additional delegation.

### Calibration basis

Sources retrieved 2026-10-26 unless marked; detailed limitations and weekly evidence are below.

- [Which Claude model should you build with?](https://claude.dev/blog/which-claude-model-should-you-build-with/) (Anthropic, retrieved 2026-11-09) recommends Opus 5.5 at `medium` as the starting point, Sonnet 5.5 for well-scoped work, Haiku 5.5 for high-volume work and retrieval subagents, and Fable 5.2 for the hardest technical work, when Opus at `high` falls short, and for long unattended runs. Its runs: on FrontierCode 2.0, Fable 5.2 `high` scored 45.3% against Opus 5.5 `max` at 45.5%, for about half the cost per task; on SWE-bench Pro, Opus 5.5 `medium` scored about 2.5 points below `high` at about 70% of its cost, `low` about 8 points below at about a third, and `xhigh` about 1.4 points above at 2.5×. These are the vendor's runs in its own harness; they set the routing order, not a local ranking.
- [Prompting Claude Fable 5.2](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-2) (Anthropic, retrieved 2026-11-10) places most of the capability gain at `high`, names `high` for agentic work and long unattended runs and `medium` for interactive work, and reports that the model ends a turn early more often at `low` and `medium`. It is the vendor's testing, not a local run.
- [Vals Index v2.2](https://www.vals.ai/benchmarks/vals_index) reports Sonnet 70.85%, Opus 70.18%, Astra 65.02%, Sol 63.94%, Haiku 58.71%, and Luna 52.32%. These mixed-work results support capability bands; they do not by themselves order open-ended judgment or justify a particular effort setting.
- [Artificial Analysis on Terra](https://artificialanalysis.ai/articles/gpt-6-1-terra-pushes-the-cost-efficiency-frontier) reports Coding Agent Index v2.0 scores of Terra 48, Sol 54, and Luna 31. This supports separating scoped execution from broader implementation.
- [Code2Video-AA](https://artificialanalysis.ai/articles/code2video-aa) reports Opus 1536, Sonnet 1443, Astra 1427, Sol 1369, Haiku 1192, and Luna 1030 Elo. Claude Opus/Sonnet use `max with fallback`; the GPT rows use `max`. Sonnet and Astra are within noise. These results anchor the visual-taste bands without converting Elo arithmetically into a 1–10 score. Terra is not listed.
- [OpenAI model selection](https://developers.openai.com/api/docs/guides/model-selection) and [Anthropic Opus results](https://www.anthropic.com/claude-opus-5-5) support the role split; neither source proves `max` always beats `medium`.

## How to apply

- These are defaults, not limits. Standing permission to override: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Cost is a tie-breaker only; for anything that ships, intelligence > taste > cost.
- Fable 5.2: the hardest planning, architecture, migrations and major refactors, ambiguous debugging, adversarial review, deep research and synthesis, long unattended runs, and coordinating many workers. Run it at `high` for unattended runs, agentic work and review, where it ends a turn early more often at lower effort; `medium` is for interactive sessions. It is the first step past Opus `high`; use Opus `xhigh`/`max` only when Fable is unavailable or a local comparison favors it. Pin the effort, because Claude Code defaults Fable to `medium`.
- Opus 5.5 at `medium` is an authorized implementer for bounded work with an approved spec, file scope, and acceptance checks, including user-facing implementation that needs taste. Escalate unresolved design choices or difficult diagnosis to Fable 5.2. Codex remains the default for bulk mechanical volume.
- Escalation ladder when output falls short: (1) give the model a way to check its own work (a test, a build, a script that calls the endpoint); (2) raise effort one level; (3) move to the next model up, at a lower effort than the smaller model used. Past `high`, one more level can cost as much as the bigger model, so test the bigger model first.
- Work with an automatic outcome check (passing tests, a row count, a closed ticket) runs at `low` first and re-runs only the failures at `high`. In the vendor's SWE-bench Pro run, Opus 5.5 run that way passed about 97% of tasks at about $0.17 each, against 95.3% at $0.29 with every task at `high`.
- Judge cost per finished task, not price per token, and price the hardest tasks in a sample: they carry most of the spend.
- GPT routing through Codex: Sol `medium` for general implementation; Astra for the hardest reasoning/design; Terra for bounded visual/application work; Luna for focused repetitive transformations. Escalate effort or model when acceptance checks fail. These are role alternatives to Claude, not claims of equal performance or matched effort levels.
- Bulk/mechanical work (clear-spec implementation, migrations, data analysis, log crunching): Codex — effectively free for me. Caveat: my OpenAI quota CAN run out (it did until 2026-07-28) — if a Codex call fails on usage limits, don't retry or wait: fall back to sonnet subagents at effort low, and mention the quota state so I know.
- Original visual work needs visual taste ≥ 7 plus review against the brief: Opus, Sonnet 5.5, Astra, or Sol. Terra and lower-rated models may implement a supplied design or perform visual QA with explicit checks. For copy, API design, and code quality, use the task-specific implementation/review routes; the visual score is not evidence of competence in those domains.
- Reviews of plans/implementations: Opus 5.5 `high`. The adversarial audit that executes (the `iaas` Audit phase, the `cascade` reviewer, the `coordinate` independent review) runs on Fable 5.2 `high`, with Opus `xhigh` when Fable is unavailable; optionally Codex as an extra independent perspective. A review lists only what would block the merge, each finding with file:line, why it is wrong, and how to show it fails.
- Broad read-only exploration (many files, unknown locations): subagents returning conclusions only. Reading a specific file to edit or quote it: read it directly. Never paste raw dumps into chat. Model: Haiku 5.5 through retrieval agents whose definitions declare it, including a user- or project-level agent named `Explore` with `model: haiku`, which overrides the built-in one (the built-in runs on the main model). Retrieval suits a small model because a wrong answer is cheap to spot; code edits and judgment calls stay on the main model, since a misread search sends it into the wrong file.
- Keep the main context lean; it matters more the bigger the main model is. On Opus 5.5 a turn's cache read costs about $0.03 at 150K tokens of context and about $0.004 at 20K.
- A lead with many cheaper workers pays only when the work exceeds one context window. In the vendor's run, an Opus 5.5 lead over up to 25 Sonnet 5.5 workers cost about a third less than Opus alone on a 22M-token defect search, at about the same score. For one chain of dependent steps, or work that fits one context, one agent wins.
- Not adopted as defaults: `opusplan` (it puts code edits on Sonnet, the reverse of this policy) and the advisor tool (the vendor's own pairing gained 1.7 points for 2.1× the cost, within run-to-run noise).
- Haiku 5.5 only where a wrong answer is cheap to spot: locating files, reading logs, extraction, summaries. Never for code edits or judgment calls; when in doubt prefer Codex or Sonnet.
- Token-hungry modalities (computer use, huge logs, long-document analysis): delegate to a cheaper engine and report conclusions back.

## Pipeline roles

Default model, effort and fallback for every role the pipeline skills dispatch (`iaas`, `cascade`, `coordinate`, `polish`). A skill that deviates from a row states the deviation and its reason in its own file. A run policy, routing table or brief that carries a model or effort is filled from this table when it is written.

| Role | Model | Effort | Fallback | Why |
|---|---|---|---|---|
| Coordinator · ratification · final read (`cascade`, `coordinate`) | the session itself — the strongest model the owner has | — | — | — |
| Planner (`cascade`) | opus-5.5 | high | — | — |
| Implement — size L, user-facing work, or an open design decision | opus-5.5 | high | — | the delegation default for any subagent that ships code |
| Implement — size S or M with a closed spec | gpt-5.6-luna, through the Codex runtime | high | opus-5.5 `high` | matched the reference on the one matched run at half the output tokens and no Claude quota (provisional, below) |
| Implement — frontend / UI / copy (`coordinate`) | opus-5.5 (`claude`) | high | — | — |
| Implement — backend / architecture / debugging / tests (`coordinate`) | Codex, on the model configured in `~/.codex/config.toml` | high | — | — |
| **Audit**, **with execution** · independent review by a Claude worker | fable-5.2 | **high** | opus-5.5 `xhigh` when Fable is unavailable | the adversarial phase — the one whose misses cost a whole round; past Opus `high` the next step is the bigger model, not more effort (§ How to apply) · not measured locally |
| Independent review by a Codex worker (`coordinate`) | Codex, on the model configured in `~/.codex/config.toml` | xhigh | — | — |
| Second audit, read-only, round 1 | gpt-5.6-luna, through the Codex runtime | `high` in `cascade`; not stated for `iaas` | — | a different family: its misses did not overlap the primary's |
| Address | opus-5.5 | high | — | bounded work: the findings name what to change · not measured |
| Simplify | opus-5.5 | high | — | taste-sensitive, but scoped to the diff · not measured |

The rows name opus-5.5 since 2026-09-24; the evidence below was measured on opus-5 and not re-run. The Audit row names fable-5.2 on the vendor's runs alone, so one matched audit where opus-5.5 `xhigh` finds what fable-5.2 `high` missed reopens it.

Routing is overridable per run. Never silently drop a phase below opus-5.5 to save tokens; the audit
is where an under-powered model quietly returns "no findings" and looks identical to a clean pass.
The Codex rows need two things to hold: quota, and a sandbox that can run the project's tests from
the worktree — a build tool whose lock lives in the main checkout denies a worktree-scoped sandbox.
Check it with one focused test before the first dispatch; either one missing ⇒ that row falls back to
opus-5.5, **never** to a lower Claude tier.

**Evidence — provisional, one task.** One matched run: five implementers on the same medium fix, same
plan, same base, blind audit. opus-5 came back with no finding at all; gpt-5.6-luna with one Nit and
5 of 5 on the coordinator's adversarial suite, in 15k output tokens against opus-5's 30k, written
without being able to run a test; gpt-5.6-sol failed 1 of 5 (a source-order defect); sonnet-5 wrote
correct code, left two declared test seams unproven, used 43k tokens and broke one brief rule;
gpt-5.6-terra shipped an inert check. Then the same five frozen diffs went to six auditors against a
ground truth confirmed by execution: opus-5 **with** execution found 4 of 5 real defects, opus-5
**read-only** missed the ordering defect the executing instance found, gpt-5.6-luna read-only found 4
of 5 — a different four — and the union was 5 of 5. Nobody invented a Blocker or an Important on the
two clean diffs. Severity drifted between instances of the same model (one defect: Nit in one review,
Important in another), which is why convergence counts confirmed findings, not labels. Three more
matched tasks with the same result make these rows permanent; one contrary task reopens them.
sonnet-5 holds no implementer row and gpt-5.6-terra holds no row until each gets a fair run.

## GPT-6.1 Terra routing

Use `gpt-6.1-terra` through the Codex plugin when the task has explicit inputs, a bounded outcome, and an observable acceptance check. Its cost score reflects my OpenAI allowance; intelligence is provisionally estimated; visual taste remains unrated and neither has a local evaluation.

| Task | Route | Acceptance check |
|------|-------|------------------|
| Visual QA against a supplied reference; reproduce a UI bug | Terra, `medium` | Inspect the relevant states and report reproducible differences |
| Read images or documents and transfer data across applications | Terra, `medium` | Verify the saved records against the source |
| Scoped code fix with a known reproduction | Terra, `medium` | Reproduce the failure and run the relevant regression checks |
| Draft factual documentation or a PR description from supplied evidence | Terra, `medium` | Check claims against that evidence; apply the existing taste rule before shipping |
| Implementation from an approved spec | Sol `medium` through Codex; Opus 5.5 `medium` is also authorized | Project gates and acceptance criteria |
| Architecture, ambiguous debugging, final review, or original UI/API/copy design | Opus 5.5 `high`, Fable 5.2 for the hardest; Astra as the GPT alternative | Existing review and taste requirements |

Terra can check a UI against explicit criteria; visual comprehension does not establish design taste. Existing ad-hoc subagent defaults and defined-agent models still apply, with Opus 5.5 `medium` explicitly allowed for implementers and Fable 5.2 for the hardest work. This route selects a Codex model when delegation is otherwise authorized; it does not authorize extra agents or replace the configured default. If the plugin cannot select Terra, use the existing Codex route and disclose the model used.

Start at `medium`. Escalate a failed scoped task to the existing stronger-model route with its reproduction and evidence. Use local completion quality, elapsed time, and review/retry work to judge adoption; benchmark scores do not replace acceptance checks.

### Evidence boundary

Sources retrieved 2026-10-26:

- [OpenAI launch](https://openai.com/index/introducing-gpt-6-1-terra/): Terra scores 50.3% on Terminal-Bench 4.0 at max effort; Agents' Last Exam reports about 9x lower cost per task than Opus 5.5. The reported 3x speed advantage is against Astra and Sol, not Claude.
- [Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5) and [Opus 5.5](https://www.anthropic.com/claude-opus-5-5): published Terminal-Bench 4.0 scores are 70.6% and 66.4%. Provider runs can differ in effort, harness, and fallback models; these scores support retaining stronger coding routes, not a universal ranking.
- [OpenAI model selection](https://developers.openai.com/api/docs/guides/model-selection): Terra is recommended for defined computer-use outcomes, supplied-material writing, and scoped code fixes. Local A/B results are required before treating routing estimates as validated for this workflow.

### Public benchmark update: 2026-10-20 through 2026-10-26

Sources retrieved 2026-10-26. Public results describe the evaluated model, effort, harness, and task set; they do not establish that higher effort always wins.

- [Artificial Analysis, Terra, Oct 26](https://artificialanalysis.ai/articles/gpt-6-1-terra-pushes-the-cost-efficiency-frontier): Coding Agent Index v2.0 scores Terra 48, Sol 54, and Luna 31. Terra `low`/`medium` are on the general intelligence cost frontier; `low`/`xhigh` are on the coding cost frontier. Keep `medium` as the initial operational route, not a claim that it is optimal for all coding.
- [Code2Video-AA, Oct 26](https://artificialanalysis.ai/articles/code2video-aa): Opus 5.5 `max with fallback` leads at 1536 Elo; Sonnet 5.5 scores 1443 and Astra 1427. The test uses 114 briefs, one-shot HTML/GSAP generation, and judge-based video comparisons. This supports the heavy creative route within that domain; Terra is not listed.
- [Vals Index v2.2, updated Oct 24](https://www.vals.ai/benchmarks/vals_index): Sonnet 5.5 scores 70.85%, Opus 5.5 70.18%. This mixed finance/coding/legal/tax index does not establish an Opus `medium` versus `max` ordering. An updated leaderboard date is not the execution date of every run.
- [Coding Agent Index v2.0 methodology](https://artificialanalysis.ai/methodology/coding-agents-benchmarking): equal weights for FrontierCode v1.1, Terminal-Bench 4.0, and SWE-Atlas-QnA-AA. Compare within v2.0 and the same agent configuration; v1.5 totals use different components. The live leaderboard was not accessible during this review, so its reported Opus ranking is not used here.
- Older supporting evidence, outside the weekly window: [Anthropic, Sep 22](https://www.anthropic.com/claude-opus-5-5) reports Opus 5.5 `medium` at 54.6% on FrontierCode and 52.5% on CursorBench. These vendor results support trying it as an implementer, not reducing all orchestration to `medium`. No new controlled `medium` versus `max` comparison was confirmed in the reviewed weekly sources.

## Effort discipline

- General session and ad-hoc subagent default: Opus 5.5 `high`. Route an implementer to `medium`, retrieval to Haiku 5.5, and the hardest work to Fable 5.2 explicitly; these are role-specific exceptions to the default.
- The hardest work goes to Fable 5.2 at `medium`, raised to `high` when that falls short; headless runs that require sustained judgment start at `high`, pinned. Duration alone does not justify it. `max` measures a model's ceiling; it is not a routing level. Opus `xhigh` only where a local run measured a gain over Fable 5.2 at a lower effort.
- Pin effort explicitly for implementers and headless launches. Ensure the runtime applies the requested setting rather than silently inheriting the coordinator's effort; preserve defined-agent contracts unless their instructions authorize a role override.
- Choose model and effort at session start; to escalate one question, use a subagent instead of `/model` or `/effort`. The prompt cache belongs to the model that wrote it, so the first turn on a new model pays the cache write on the whole conversation, and a move down a tier, or any move off Fable 5.2, also drops the earlier thinking. When a switch is needed, make it at a natural break: `/compact` first, or a fresh session from a written plan.
- Effort low only for workers Sam explicitly routes to cheaper engines for mechanical stages.

## Mechanics (my setup)

- Codex (model set in `~/.codex/config.toml`) runs through the **Codex plugin — ALWAYS prefer it over the raw `codex` CLI** (`codex exec` bypasses the plugin's job tracking, background runs, resumable threads, and structured review output; the plugin's own runtime contract forbids hand-rolled CLI strings). Routes: `codex:codex-rescue` agent (or `/codex:rescue`) for delegated implementation/diagnosis/research — covers investigation too; defaults to write-capable, so say "read-only" explicitly for advisory/diagnosis passes; supports `--background`, `--resume`/`--fresh` for thread continuity. `/codex:review` and `/codex:adversarial-review` for independent reviews — user-invoked only (`disable-model-invocation`); Claude suggests them, Sam fires them. `/codex:status` · `/codex:result` · `/codex:cancel` for job control; `/codex:transfer` hands the whole Claude session to a resumable Codex thread. Raw `codex exec` = last resort only if the plugin runtime is broken.
- Advisor / second opinion at decision points: FIRST check whether Codex is available and has the needed context; consult via the `codex:codex-rescue` agent with an explicit read-only advisory prompt. Fallback: an Opus 5.5 review worker at `high`, or Fable 5.2 for the hardest decisions, through an available authorized worker interface.
- Codex prompts must be self-contained: goal, constraints, relevant paths, acceptance criteria. Use the `codex:gpt-5-4-prompting` skill to shape them.
- Delegation transfers effort, not accountability: verify delegated output before reporting it done.
- Defined Claude agents own their model and effort in frontmatter; pass no `model` or `effort` when calling one, because a call-site value overrides the definition. Claude Code resolves a subagent's model in this order: the call's `model` (aliases `haiku`, `sonnet`, `opus`, `fable`), the definition's `model`, `CLAUDE_CODE_SUBAGENT_MODEL`, then the main model. The session effort does not carry over to a subagent on another model; set `effort` in its definition. Ad-hoc workers take `model` and `effort` on the Agent call.
- OpenCode Go: dropped 2026-10-17 (OpenCode Console breach, subscription canceled). Never route work to `opencode-go/*` or the `:go` profile.
