---
tracker: github            # legacy detection key — anything else means "not migrated" (ADR 0002)
repo: owner/name           # explicit owner/name for gh (NEVER parsed from the SSH-alias origin)
security_scan: gitleaks git --redact --no-banner   # optional — exact scan command /samuel:validate runs when present
# autonomy: attended-auto  # optional — uncomment to opt in; absent = interactive
---

# samuel — per-repo pipeline config

Copy this to `.claude/samuel.md` in a repo to pin the pipeline config. Keep `.claude/` gitignored.

- **`repo`** — the field that matters. The origin may be an SSH alias (`git@github.com-acct:owner/repo.git`) that breaks owner/repo detection, so it's stored explicitly and never parsed from `git remote`. Also run once per clone: `gh repo set-default owner/name`.
- **`tracker`** — always `github` (Issues + PRs via `gh` are the only SoT; ADR 0002). Kept as a **legacy detection key**: anything else marks a pre-migration context — see `plugins/samuel/reference/tracker.md` § Legacy contexts.
- **`security_scan`** — optional. The **exact** command `/samuel:validate` runs as a security step (secret scan / SAST): `gitleaks git --redact --no-banner`, `semgrep ci`, `bun run scan`, whatever this repo actually has. It must **exit non-zero on findings** — validate reads the exit code, not the output. Delete the line if the repo has no scanner: absent is the default, and validate then says so explicitly rather than silently skipping. Repo-scoped on purpose — the gate command comes from the plan, this one doesn't change per task.
  - The value **must not contain `#`** — the reader strips from the first `#` as a trailing comment, so `--exclude "#tmp"` would silently truncate the command. Wrap such an invocation in a repo script and point `security_scan` at that.
  - An **autonomous** run needs the command in the conductor's permission allowlist too, or it is denied and reports as skipped — `plugins/samuel/skills/conductor/references/autonomous-run.md` § Permission allowlist.
- **`autonomy`** — optional, and **shipped commented out on purpose**: a repo that copies this file verbatim must get today's behaviour, not eight checkpoints silently switched off by a template it never read. Uncomment to opt in. How a **soft** checkpoint behaves: `interactive` asks and waits (the default, and what you get by deleting the line); `attended-auto` takes the obvious default and announces it in one line instead. Hard stops — plan-reality mismatch, constitution violation, red gate, incomplete DoD, any outward action — keep waiting at every level. Gate-by-gate table and the recording contract: `plugins/samuel/reference/autonomy.md`.
  - **`autonomous` is not settable here.** That level belongs to `/samuel:conductor`, which earns it by passing a SAFETY GATE (isolated worktree or CI runner, never a local `main`); a file that granted it would hand an ordinary session the conductor's authority with none of its guard. The reader enforces this — `autonomous`, a typo, or an empty value all resolve to `interactive`.
  - The only field here with a **global fallback**: `~/.claude/samuel.md` supplies it for every repo that doesn't override it, because it describes how its owner likes to work rather than anything about the repo. A conductor-driven run ignores it in both directions.

Skills that run before a task exists (`/samuel:next`, `/samuel:progress`, `/samuel:kickoff`) read this file directly (same awk-on-frontmatter pattern as `task-context.md`, no `jq`, no shell expansion). `/samuel:start-task` copies `repo` into `.claude/task-context.md` so the rest of the pipeline reads a single file.

If this file is absent, skills ask for `owner/name` once and offer to write it.
