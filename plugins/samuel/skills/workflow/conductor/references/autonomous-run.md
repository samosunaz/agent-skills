# Autonomous Run — Launch Recipe & Guardrails

How to run `/samuel:conductor` unattended — on a **remote droplet** (the primary target: SSH in, read Issues, execute) or a **local Mac** (overnight). The conductor is the orchestration; this is the wrapper that keeps the blast radius contained.

> Ship mode writes code **and opens a draft PR** without per-phase human review. Everything below is the price of that. Do not skip the isolation or the allowlist. Merge always stays human.

## 0. Automatic trigger (upstream)

This recipe is the **manual** launch (you start `claude -p`). To have GitHub fire the loop on its own — on a schedule or the moment an issue becomes `pipeline:ready` — see `../../../../reference/automated-trigger.md`. It ships a committed workflow template (`../assets/conductor.yml`) that runs **exactly** the `claude -p` invocation in §4 below; the isolation and the allowlist here still apply (in CI, the ephemeral runner + a dedicated branch are the equivalent isolation). Everything below is what that trigger drives.

## 1. Isolate the blast radius (mandatory)

Drive inside a dedicated git worktree on a feature branch — never the primary checkout, never `main`. `/samuel:conductor {item} --ship` will bootstrap the worktree via `/samuel:start-task`; or pre-create it:

```bash
git worktree list                        # the conductor must run inside one of these
git -C <worktree> branch --show-current  # must be a feature/* branch
```

The SAFETY GATE aborts on a local main checkout or `main`/`master` (in CI, a non-main branch on the ephemeral runner is equivalent isolation — see `../../../../reference/automated-trigger.md`).

## 2. Permission allowlist (instead of --dangerously-skip-permissions)

Prefer a tight `allow`/`deny`. Put this in the worktree's `.claude/settings.json`. Note the **draft-PR authority** for ship mode, and that merge/ready/close are denied:

```jsonc
{
  "permissions": {
    "allow": [
      "Read", "Edit", "Write", "Glob", "Grep", "Skill", "Agent",
      "Bash(git add *)", "Bash(git commit *)", "Bash(git status *)",
      "Bash(git diff *)", "Bash(git log *)", "Bash(git branch *)",
      "Bash(git push *)",                       // ship mode pushes the feature branch
      "Bash(gh issue view *)", "Bash(gh issue list *)", "Bash(gh issue edit *)",
      "Bash(gh issue comment *)", "Bash(gh issue create *)",
      "Bash(gh pr create *)", "Bash(gh pr view *)", "Bash(gh pr list *)", "Bash(gh pr checks *)",
      "Bash(gh repo view *)", "Bash(gh label *)",
      "Bash(bun *)", "Bash(npm *)", "Bash(pnpm *)", "Bash(node *)",
      "Bash(gitleaks *)", "Bash(semgrep *)"  // the security_scan command — see below
    ],
    "deny": [
      "Bash(gh pr merge *)", "Bash(gh pr ready *)", "Bash(gh issue close *)",
      "Bash(git push --force*)", "Bash(git push -f*)",
      "Bash(rm -rf *)", "Bash(curl *)", "Bash(wget *)", "WebFetch",
      "Bash(* migrate deploy*)", "Bash(* db:drop*)"
    ]
  }
}
```

`deny` wins over `allow`. The conductor can open a **draft** PR but cannot mark it ready, merge it, or close the Issue — those are the human's. Adjust build commands to your toolchain. (Review mode: drop `git push *` and the `gh pr *` allows entirely.)

**If `.claude/samuel.md` sets `security_scan`, its command must be allowlisted here.** A headless run cannot prompt for approval, so an unlisted scanner is denied, `/samuel:validate` reports the scan as skipped, and a `SKIP` weighs nothing in `Overall` — the run passes without ever scanning, in the one mode where nobody is watching. The two entries above cover `gitleaks`/`semgrep`; a repo-script wrapper (`bun run scan`) is already covered by the toolchain allows.

## 3. No production credentials in the environment

The environment must be unable to touch prod even if the agent misbehaves: local/disposable DB or read-only creds, no deploy tokens, no payment keys, no real secrets in `.env`. On a shared droplet, scope the `gh` token to the single repo if possible.

## 3.5 Run accounting — what every recipe below captures

Every launch path records the same four numbers per item: **cost, turns, tokens, outcome**. The mechanism is one pattern, reused verbatim by the CI template (`../assets/conductor.yml`) and by the recipes below:

- **`--max-budget-usd <amount>`** — the native per-item spend cap. No custom logic needed; the CLI kills the run when it's hit.
- **`--output-format stream-json --verbose | tee <log>.jsonl`** — machine-readable output. **`stream-json` hard-errors without `--verbose`** (`stream-json requires --verbose`); the flag is not optional. The JSONL **replaces** the old plain-text log — it carries the same transcript plus the final `result` line, so raw debugging reads the same file.
- **`jq` over the last line** — the run's result object:
  ```json
  {"type":"result","subtype":"success","is_error":false,"total_cost_usd":0.4897,
   "num_turns":1,"duration_ms":12371,"usage":{"input_tokens":1200,"output_tokens":340}}
  ```
  Non-`success` subtypes exist (`error_max_turns`, budget kill). A run killed hard may emit **no** `result` line at all — treat that as `aborted` and charge the full item cap, so an accumulated budget never fails open.

Outcome, per item: **shipped** (a draft PR exists), **aborted** (`subtype` ≠ `success`, `is_error: true`, or no result line), **escalated** (finished but opened no PR — validation FAIL, blocker, preflight `HOLD`, review mode). *Accepted* is not observable here — it materializes when you merge, and is computed at the morning review (`../../../../reference/automated-trigger.md` § Morning review).

## 4a. Droplet — single item

A server doesn't sleep, so no `caffeinate`. Pick a ready item and ship it:

```bash
cd <worktree>
ITEM=42
claude -p \
  "/samuel:conductor $ITEM --ship
   /goal item $ITEM → branch → implement → validate with a real green gate → open a DRAFT PR.
   Record every unattended assumption to GitHub + journal + a handoff. Do NOT mark the PR
   ready, merge, or close the issue. Stop after 40 turns if not reached." \
  --max-budget-usd 10 \
  --output-format stream-json --verbose \
  | tee ~/conductor-$ITEM.jsonl

# What it cost and how it ended.
tail -n 1 ~/conductor-$ITEM.jsonl | jq -r 'select(.type=="result")
  | "cost $\(.total_cost_usd) · \(.num_turns) turns · \(.usage.input_tokens)/\(.usage.output_tokens) tokens · \(.subtype)"'
```

One item needs no accumulated cap — `--max-budget-usd` *is* the whole budget. The run report for a single item is the conductor's own Stop/Exit Report, which an autonomous run posts to the `conductor:log` issue on its way out (`../SKILL.md` § Stop / Exit Report).

## 4b. Droplet — the multi-item loop (the SSH workflow)

Process the whole `pipeline:ready` inbox, one isolated `claude -p` per item. The bash loop is the deterministic outer driver; each invocation is a fresh, bounded session:

```bash
gh repo set-default owner/repo
ITEM_BUDGET_USD=10          # per item  — enforced by the CLI
SWEEP_BUDGET_USD=40         # per sweep — enforced by this loop, between items
: > ~/conductor-report.tsv
SWEEP_SPENT=0

for n in $(gh issue list --state open --label "pipeline:ready" --json number --jq '.[].number'); do
  echo "=== item #$n ==="
  claude -p \
    "/samuel:conductor $n --ship
     /goal ship item $n as a draft PR with a green gate; record assumptions; never merge/ready.
     Stop after 40 turns." \
    --max-budget-usd "$ITEM_BUDGET_USD" \
    --output-format stream-json --verbose \
    | tee ~/conductor-$n.jsonl || true

  res=$(tail -n 1 ~/conductor-$n.jsonl 2>/dev/null || true)
  if ! printf '%s' "$res" | jq -e 'select(.type=="result")' >/dev/null 2>&1; then
    cost=$ITEM_BUDGET_USD; turns='?'; tokens='?'; outcome=aborted
  else
    cost=$(printf '%s' "$res" | jq -r '.total_cost_usd // 0')
    turns=$(printf '%s' "$res" | jq -r '.num_turns // "?"')
    tokens=$(printf '%s' "$res" | jq -r '"\(.usage.input_tokens // "?")/\(.usage.output_tokens // "?")"')
    # Each item ships from its OWN worktree, so the launcher's branch says nothing.
    # /samuel:done flips this label right after it opens the draft PR.
    if [ "$(printf '%s' "$res" | jq -r '.subtype')" != "success" ]; then
      outcome=aborted
    elif gh issue view "$n" --json labels --jq '.labels[].name' | grep -qx 'pipeline:in-review'; then
      outcome=shipped
    else
      outcome=escalated
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$cost" "$turns" "$tokens" "$outcome" >> ~/conductor-report.tsv

  SWEEP_SPENT=$(awk -v a="$SWEEP_SPENT" -v b="$cost" 'BEGIN{printf "%.4f", a+b}')
  if awk -v a="$SWEEP_SPENT" -v b="$SWEEP_BUDGET_USD" 'BEGIN{exit !(a>=b)}'; then
    echo "Sweep cap hit: \$$SWEEP_SPENT of \$$SWEEP_BUDGET_USD — stopping."
    break
  fi
done
```

Then post the run report to the same rolling log issue the CI template uses, so SSH and CI runs share one timeline:

```bash
gh label create conductor:log -c 0E8A16 -d "Rolling conductor run log" --force
LOG=$(gh issue list --label conductor:log --state open --json number --jq '.[0].number')
# `.[0].number` on an empty list prints the string "null", which is non-empty —
# match both, or the first-ever run posts to issue "null" instead of creating one.
case "$LOG" in
  ""|null) LOG=$(gh issue create --title "Conductor run log" --label conductor:log \
             --body "Rolling log — one comment per conductor run. Keep open." | sed 's#.*/##') ;;
esac

{
  printf '**Conductor run** — ssh sweep · %s\n\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
  printf '| item | cost (USD) | turns | tokens (in/out) | outcome |\n|---|---|---|---|---|\n'
  awk -F'\t' '{printf "| #%s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5}' ~/conductor-report.tsv
  awk -F'\t' '{n++; o[$5]++} END {printf "\n**Totals** — %d item(s) · shipped %d · escalated %d · aborted %d\n", n, o["shipped"], o["escalated"], o["aborted"]}' ~/conductor-report.tsv
  printf '\nBudget — spent $%s of $%s.\n' "$SWEEP_SPENT" "$SWEEP_BUDGET_USD"
} | gh issue comment "$LOG" --body-file -
```

Each item gets its own worktree (start-task bootstrap), branch, and draft PR. You wake to a stack of draft PRs with CI running, and one comment telling you what the night cost. (Only `pipeline:ready` is eligible — `planned`-but-blocked and `triage` items are skipped by design.)

**Parallel variant (resource-aware).** Items are already isolated (one worktree each), so they *can* run concurrently. But each worktree runs the **full gate** (typecheck+lint+build across every project) — N concurrent items = N× the build load. Cap it low, and only on a box with headroom:

Nesting the capture inside `xargs -I {} sh -c '…'` means three levels of quoting around the `jq` programs. Put the per-item logic in a helper instead — write it once, then fan out:

```bash
cat > ~/conductor-item.sh <<'SH'
#!/bin/sh
# One item, start to TSV row. Invoked once per issue by xargs.
n="$1"
claude -p "/samuel:conductor $n --ship
  /goal ship a draft PR with a green gate; never merge. Stop after 40 turns." \
  --max-budget-usd "${ITEM_BUDGET_USD:-10}" \
  --output-format stream-json --verbose \
  | tee "$HOME/conductor-$n.jsonl" || true

res=$(tail -n 1 "$HOME/conductor-$n.jsonl" 2>/dev/null || true)
if ! printf '%s' "$res" | jq -e 'select(.type=="result")' >/dev/null 2>&1; then
  cost="${ITEM_BUDGET_USD:-10}"; turns='?'; tokens='?'; outcome=aborted
else
  cost=$(printf '%s' "$res" | jq -r '.total_cost_usd // 0')
  turns=$(printf '%s' "$res" | jq -r '.num_turns // "?"')
  tokens=$(printf '%s' "$res" | jq -r '"\(.usage.input_tokens // "?")/\(.usage.output_tokens // "?")"')
  if [ "$(printf '%s' "$res" | jq -r '.subtype')" != "success" ]; then
    outcome=aborted
  elif gh issue view "$n" --json labels --jq '.labels[].name' | grep -qx 'pipeline:in-review'; then
    outcome=shipped
  else
    outcome=escalated
  fi
fi
# Own file per item — concurrent appends to one TSV interleave.
printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$cost" "$turns" "$tokens" "$outcome" > "$HOME/conductor-$n.tsv"
SH
chmod +x ~/conductor-item.sh

gh repo set-default owner/repo
rm -f ~/conductor-*.tsv
export ITEM_BUDGET_USD=10
gh issue list --state open --label "pipeline:ready" --json number --jq '.[].number' \
  | xargs -P 2 -I {} ~/conductor-item.sh {}

cat ~/conductor-*.tsv > ~/conductor-report.tsv    # aggregate once xargs returns
```

`-P 2` runs two items at a time. Do **not** raise it blindly — on a small droplet keep it `1` (sequential) or `2`; reserve higher fan-out for a runner with real cores. Each `claude -p` is independent, so a crash loses only its own item. The worktree isolation that makes this safe is the same SAFETY GATE the conductor enforces per item.

**Per-item caps only — there is no sweep cap here.** An accumulated budget can only stop the *next* item, and under `xargs` every item is already in flight; cutting mid-run would have to kill live agents. Total exposure is therefore bounded by **`items × ITEM_BUDGET_USD`** — size the per-item cap with the whole inbox in mind, or use the sequential loop when the ceiling matters more than wall-clock. Post the aggregated report with the same block as the sequential loop (substituting the aggregated total for `$SWEEP_SPENT`).

## 4c. Local Mac — overnight

Tie wake-state to the process so it releases when done:

```bash
cd <worktree>
caffeinate -i -- claude -p "/samuel:conductor 42 --ship /goal … Stop after 40 turns." \
  --max-budget-usd 10 --output-format stream-json --verbose \
  | tee ~/conductor-$(date +%F).jsonl
```

- Closed lid → Amphetamine's closed-display mode (plugged in, ventilated — builds run hot).
- `/goal` is condition-based and bounded (`stop after N turns`) — the brake against loops and runaway cost.

## 5. Morning review (the human half)

Ship mode leaves draft PRs. Review via `gh`:

```bash
gh issue list --label conductor:log -R owner/repo     # the rolling log — last comment = last run
gh pr list --draft -R owner/repo                      # the night's output
gh pr view <n> -R owner/repo                          # summary synthesized from the journal
gh pr checks <n> -R owner/repo                         # CI status (the remote gate)
gh issue view <item> -R owner/repo --comments          # decisions + validation summary, in order
# resume a fresh session if something needs hands:
/samuel:session-handoff resume <handoff-id>
# when satisfied:
gh pr ready <n> -R owner/repo                          # take it out of draft
gh pr merge <n> -R owner/repo --squash                 # merge → Closes #item auto-closes the issue
```

## Failure modes to expect

- **Drift across compactions** — mitigated by FIC handoffs, not eliminated. Keep items small (the plan sizing rule).
- **Confident wrong assumptions** run unattended — the cost of autonomy. GitHub issue comments + journal are the audit.
- **Red gate or reviewer Blocker, draft PR suppressed** — ship mode opens a PR only on `Overall: PASS` (gate green + no reviewer Blocker from validate Step 2.5); a red gate or an unresolved Blocker yields a handoff describing the failure instead. That's correct.
- **Machine/network death** — power loss, Wi-Fi drop, OS reboot kills the run. The droplet is more reliable than a laptop; the per-item loop means only the in-flight item is lost.
- **Validation false-positive** — `/goal`'s evaluator only judges what surfaces in the conversation; `validate` must print real gate output for the gate to mean anything.
- **`gh` default not set** — a fresh worktree may not inherit the repo default; `gh repo set-default owner/repo` at the top of the loop fixes it.
- **Budget cap kills a run mid-item** — `--max-budget-usd` stops the agent wherever it stands, often before it emits a `result` line and always before it writes a handoff. The item shows as `aborted` charged at the full cap, and its branch is left half-done; re-run it or reset the branch. Raising the cap is the fix only if the item was genuinely large — otherwise it's a plan-sizing problem.
