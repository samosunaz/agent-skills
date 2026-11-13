# nx-panel

A Claude Code mod that draws a live band above the prompt while an Nx run is in progress: tasks done per target, failing tasks, elapsed time and machine load.

Claude Code only. It is a hooks module, so Codex does not load it.

## Install

```
/plugin install nx-panel@samuel-skills
/reload-plugins
```

## How a run has to be started

The band reads the run's log file every 2 seconds, so the command needs two things:

```bash
export NX_DEFAULT_OUTPUT_STYLE=stream; bun run gate > /absolute/path/run.log 2>&1
```

- **`NX_DEFAULT_OUTPUT_STYLE=stream`.** Without a TTY, Nx prints one summary line when the run ends. `stream` prints each task as it starts and finishes. `static` buffers a wrapped task until it ends.
- **A redirect to an absolute, literal path.** A `$variable` in the path is not resolved, and a run whose log does not exist after 15 seconds is dropped.

The mod does not add the export itself. A hook that rewrites a Bash command voids the auto-mode review of that command, and the call is refused once.

## What it detects

Commands at a command position that run `nx run`, `nx run-many`, `nx affected`, `bun run gate` or `bun run gate:signoff`, with or without `bunx` and a leading `export`. Text after the first `<<` is ignored, so a command quoted inside a heredoc does not start a band.

## What it shows

- One bar per target named in Nx's `Running targets` header. Totals come from `.nx/workspace-data/project-graph.json` and are used only when the header's project count equals the graph's; with `-p` the bar shows counts only.
- The gate's guardrail scripts as their own bar, one step per script.
- Failing tasks by name, the outcome when the run ends, and a Hide button.

## Manifest

`.claude-plugin/plugin.json` is a regular file identical to `plugin.json`, not a symlink: `claude plugin validate` loses a hooks module's state contract behind a symlinked manifest. `scripts/check-agent-plugins.sh` holds the two files equal.
