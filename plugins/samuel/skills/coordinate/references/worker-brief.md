# Worker Brief, Run Policy and Report Contract

The three texts the coordinator writes for a worker. All three are English, self-contained, and assume the worker has **no chat history, no samuel skills unless the brief names one, and no coordinator to ask casually** — a worker in another terminal knows only what the brief says.

## Run policy — `.claude/run-policy.md`

Written at the first dispatch of a task or epic, re-read before every brief, **appended** to every brief verbatim under `STANDING CONSTRAINTS` — appended, not prepended: Orca's lifecycle preamble already takes the opening of what the worker sees, and 63 % of measured dispatches spent their whole visible opening on protocol before the task appeared. The task goes first. It exists because the same five constraints were retyped by the human on almost every dispatch for two weeks; a constraint that lives here is stated once and inherited by every worker until the human changes it. `.claude/` is gitignored in consumer repos (`/samuel:repo-audit` checks it), so the file never lands in a diff.

```markdown
# Run policy — {task or epic} — {date}

## Routing
| role | agent | model | effort |
|---|---|---|---|
| frontend / UI / copy | claude | opus | high |
| backend / architecture / debugging / tests | codex | {model from ~/.codex/config.toml} | high |
| independent review | the model that did NOT write the diff | — | xhigh |

## Standing constraints (binding in every brief)
- Least code: the smallest change that meets the outcome, before any simplify pass.
- Compatibility: {none — pre-launch, legacy paths are removed | keep public contracts stable}.
- Comments state a constraint the code cannot show; never narrate the change.
- No AI attribution anywhere. Conventional commits.
- Scope exclusions: {e.g. "mobile is out of scope for this epic — register an issue, do not implement"}.

## Authority
- Workers: commit on their own branch in their own worktree. Never push, never open a PR, never merge, unless the brief says so explicitly.
- Coordinator: {attended-auto | interactive}. Push / PR / publish / deploy need the human's explicit approval in every mode.
```

Change it by editing the file and saying so in the next status line. Never silently.

## Worker brief — six slots, then the contract

Fill every slot. A slot you cannot fill is a decomposition problem, not something the worker should discover. The brief is the `--spec` text of `task-create`; Orca prepends the lifecycle preamble (task id, dispatch id, how to send `worker_done`) when it dispatches. **The task is in the first 200 characters** — ROLE and DELIVER open the brief; the policy closes it.

```text
ROLE: You are {name}, the {role} worker for "{task}". You implement exactly the outcome below in this worktree, then stop.

DELIVER: {one clear outcome, one sentence — what exists when you are done and how a user would notice it}

START FROM: commit {sha} on branch {branch} (worktree path: {abs_path}). Do not rebase or merge anything into it.

MAY CHANGE: {explicit files or directories}. New files only under {dir}.

MUST NOT TOUCH: {files, directories, schemas, public contracts, config, tests you are not the owner of}. If the outcome cannot be reached without touching one of these, stop and ask (see LIMITS) — do not work around it.

VERIFY: {the exact commands — unit/integration test, typecheck, lint, the project gate `{gate}`}. Run them yourself before reporting. For visual work: start the dev server, `orca capture start --worktree current --json`, open the page in the embedded browser (`orca tab create --url {url} --worktree current --json`), exercise the change, then `orca full-screenshot --format png --json` per state and `orca console --limit 100 --json`; save the capture paths — they are the Screenshot paths line of your report.

ARTIFACT: {a commit on {branch} — report its SHA | a file at {path} | a review comment list}. One commit per logical change, conventional message, no AI attribution.

REPORT (send exactly once, then idle): `orca orchestration send --type worker_done --subject "{name}: {done|failed}" --outcome {succeeded|failed} --task-id <from preamble> --dispatch-id <from preamble> --files-modified "{csv}" --body "<the six lines below>" --json`
  Result: {one sentence}
  Frozen commit / artifact: {sha or path}
  Files changed: {list}
  Test results: {command → pass/fail, counts}
  Screenshot paths: {paths or "none"}
  Unresolved: {list or "none"}
Do not paste logs, diffs or file contents into the report — the coordinator reads the commit. Before reporting, set your card: `orca worktree set --worktree current --workspace-status in-review --comment "{result, one line}" --json`.

LIMITS: never push, open a PR, merge, or touch anything outside MAY CHANGE · never spawn sub-agents; review your own diff directly · blocked or ambiguous ⇒ `orca orchestration ask --question "..." --timeout-ms 600000 --json` and wait for the reply · if `orca orchestration send` fails twice (sandbox cannot reach Orca), stop retrying: leave the six report lines as the last message in this terminal and idle — the coordinator reads the terminal.

STANDING CONSTRAINTS:
{run policy, verbatim}
```

### Role variants

- **Implementer** — the template above.
- **Reviewer** (independent, other model) — `DELIVER: a verdict on commit {sha} against {the DELIVER line of the implementer's brief}: APPROVE | REQUEST CHANGES, with findings as file:line + why + the smallest fix.` `MAY CHANGE: nothing — read-only.` `VERIFY: run {gate}; for any factual claim (a test fails, a path is dead) run the command and paste its one-line result.` Shares the coordinator's worktree (`--worktree current`); a reviewer that edits files is a second writer on a checkout.
- **Researcher** — read-only, shares the current worktree, returns conclusions with `file:line` evidence, never a file dump. Capped in number and released the moment the decision they served is taken.
- **Pipeline worker** (the task is a `pipeline:ready` issue) — the brief is the run policy plus `DELIVER: run /samuel:conductor {N} --ship in this worktree; the draft PR is the artifact.` The conductor's own contract covers the rest.

## Report contract — what the coordinator does with the six lines

| Line | Coordinator action |
|---|---|
| Result | Compare with DELIVER. Mismatch ⇒ one follow-up dispatch with the delta, not a new brief. |
| Frozen commit | `git log -1 {sha}` from your checkout (shared object store). Absent ⇒ the work does not exist yet — "complete but uncommitted" has been the signature of a worker killed by a quota limit. |
| Files changed | Intersect with MAY CHANGE / MUST NOT TOUCH. Any file outside ⇒ inspect the diff regardless of risk. |
| Test results | A claim. Rerun the gate at integration; a reviewer settles a disputed test by running it. |
| Screenshot paths | Open them for visual work; also open the running page. |
| Unresolved | Decide: follow-up dispatch, accept with a note in the final report, or escalate to the human. Never drop a line silently. |

Open the diff when: files outside the allowed set · security-sensitive paths (auth, secrets, payments, permissions) · behavioural change wider than DELIVER · a reviewer requested changes · the human asked. Otherwise the report is the review, and that is the point of the contract.

## Status line — what the human sees while waiting

One line per worker per state change and per expired wait window:

```
{name} · {dispatched|running|question|done|failed|released} · {elapsed} · {last evidence: "3 commits on branch", "tests running", "waiting on Enter (sent)"} · next: {check in 9 min | reading report | integrating}
```

Nothing else during supervision. No progress prose, no restating the plan. The final report is the only long message.
