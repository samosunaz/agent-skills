import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { NxRun, TargetProgress } from '../types'

const run = atom({ plugin: 'nx-panel', key: 'run' } as const, null)

// At a command position only: the same words inside a heredoc or a quoted string are text.
const NX_COMMAND =
  /(?:^|[;&|\n(]\s*)(?:export\s+[A-Z_]+=\S*;\s*)?(?:bunx\s+)?(?:nx\s+(?:run|run-many|affected)\b|bun run gate(?::signoff)?\b)/
// The first stdout redirect to an absolute path; `2>&1` and `/dev/null` are not logs.
const REDIRECT = /(?:^|[^0-9&>])>\s*(["']?)(\/[^\s"';|&<>$]+)\1/g
const ANSI = '\u001b\\[[0-9;]*m'
const MARKERS =
  '> nx run |NX   |^([a-z0-9-]+: )?\\$ |^([a-z0-9-]+: )?- [a-z0-9-]+:[a-z0-9:-]+$|Failed tasks|Signed off'
const BAR = 20
const ORDER = ['typecheck', 'lint', 'build', 'test', 'verify', 'guardrails']

function logOf(command: string): string | null {
  const heredoc = command.indexOf('<<')
  const shell = heredoc < 0 ? command : command.slice(0, heredoc)
  const at = shell.search(NX_COMMAND)
  if (at < 0) return null
  for (const match of shell.slice(at).matchAll(REDIRECT)) {
    const path = match[2]
    if (path && !path.startsWith('/dev/')) return path
  }
  return null
}

function labelOf(command: string): string {
  if (/bun run gate:signoff\b/.test(command)) return 'gate:signoff'
  if (/bun run gate\b/.test(command)) return 'gate'
  const nx = command.match(/nx\s+(?:run-many|affected|run)\s+[^>|;&\n]*/)
  return (nx ? nx[0].trim() : 'nx').slice(0, 48)
}

/** What the marker lines of a stream-style Nx log say so far. */
function parse(
  lines: string[],
  totals: Map<string, number>,
): Pick<NxRun, 'targets' | 'failing' | 'outcome'> & { projects: number | null } {
  const seen = new Map<string, Set<string>>()
  let guardrails = -1
  let asked: string[] | null = null
  let projects: number | null = null
  const failing: string[] = []
  let inFailed = false
  let outcome: NxRun['outcome'] = 'running'
  let isWholeWorkspace = false

  for (const raw of lines) {
    const isNested = /^[a-z0-9-]+: /.test(raw)
    const line = raw.replace(/^[a-z0-9-]+: /, '')
    const task = line.match(/^> nx run (?<project>[^\s:]+):(?<target>[^\s:]+)/)?.groups
    if (task?.project && task.target) {
      const tasks = seen.get(task.target) ?? new Set<string>()
      tasks.add(task.project)
      seen.set(task.target, tasks)
      inFailed = false
      continue
    }
    // `guardrails:all` chains its scripts, and Bun echoes each one's command as it starts.
    if (/^\$ bun run guardrails:[a-z0-9:-]+ &&/.test(line)) {
      guardrails = 0
      continue
    }
    if (line.startsWith('$ ')) {
      if (guardrails >= 0) guardrails += 1
      continue
    }
    if (line.includes('Failed tasks')) {
      inFailed = true
      continue
    }
    const failed = line.match(/^- ([a-z0-9-]+:[a-z0-9:-]+)$/)?.[1]
    if (failed && inFailed) {
      if (!failing.includes(failed)) failing.push(failed)
      continue
    }
    if (/Signed off/.test(line)) outcome = 'passed'
    const running = line.match(/NX\s+Running targets? (?<names>.*) for (?<count>\d+) projects?/)?.groups
    if (running?.names && running.count && running.names !== 'gate') {
      asked = running.names.split(',').map(name => name.trim())
      projects = Number(running.count)
      isWholeWorkspace = projects === totals.get('*')
    }
    if (!isNested && /NX\s+Successfully ran/.test(line) && outcome === 'running') outcome = 'passed'
    if (/NX\s+.*(failed|did not complete)/.test(line)) outcome = 'failed'
  }

  // The gate runs guardrails as a plain script after Nx, so its own task never appears.
  seen.delete('gate')
  const names = (asked ?? [...seen.keys()]).filter(name => seen.has(name)).sort(
    (a, b) => (ORDER.indexOf(a) + 1 || 99) - (ORDER.indexOf(b) + 1 || 99) || a.localeCompare(b),
  )
  const targets: TargetProgress[] = names.map(name => ({
    name,
    done: seen.get(name)?.size ?? 0,
    total: isWholeWorkspace ? (totals.get(name) ?? null) : null,
  }))
  if (guardrails >= 0) {
    targets.push({ name: 'guardrails', done: guardrails, total: totals.get('guardrails') ?? null })
  }
  if (failing.length > 0) outcome = 'failed'

  return { targets, failing, outcome, projects }
}

function clock(ms: number): string {
  const seconds = Math.max(0, Math.round(ms / 1000))
  return seconds < 60 ? `${seconds}s` : `${Math.floor(seconds / 60)}m${String(seconds % 60).padStart(2, '0')}s`
}

function bar(done: number, total: number | null): string {
  if (!total) return ''
  const filled = Math.min(BAR, Math.round((Math.min(done, total) / total) * BAR))
  return '█'.repeat(filled) + '░'.repeat(BAR - filled)
}

let timer: { cancel: () => void } | null = null
let totals = new Map<string, number>()
let isPolling = false
let reloads = 0

/** Projects per target, the project count under `*`, and the guardrail scripts in `guardrails:all`. */
async function loadTotals($: EngineInterface, cwd: string) {
  totals = new Map()
  const script =
    'cd "$1" 2>/dev/null || exit 0; ' +
    'jq -r \'.nodes | to_entries[] | (.value.data.targets // {} | keys | join(","))\' .nx/workspace-data/project-graph.json 2>/dev/null; ' +
    'printf "@@guardrails %s\\n" "$(jq -r \'.scripts["guardrails:all"] // ""\' package.json 2>/dev/null | grep -o "guardrails:[a-z0-9:-]*" | sort -u | wc -l | tr -d " ")"'
  const { stdout } = await $.process.run(['sh', '-c', script, 'sh', cwd], { timeoutMs: 20000 })
  let projects = 0
  for (const line of stdout.split('\n')) {
    if (line.startsWith('@@guardrails ')) {
      const count = Number(line.slice(13))
      if (count > 0) totals.set('guardrails', count)
      continue
    }
    if (line === '') continue
    const names = line.split(',')
    if (names.some(name => ORDER.includes(name))) projects += 1
    for (const name of names) totals.set(name, (totals.get(name) ?? 0) + 1)
  }
  totals.set('*', projects)
}

async function poll($: EngineInterface) {
  if (isPolling) return
  isPolling = true
  try {
    const current = await read($, run)
    if (current === null || current.outcome !== 'running') {
      timer?.cancel()
      timer = null
      return
    }
    const script = `[ -f "$1" ] || echo '@@missing'; LC_ALL=C sed 's/${ANSI}//g' "$1" 2>/dev/null | grep -aE '${MARKERS}'; printf '@@load %s\\n' "$(sysctl -n vm.loadavg 2>/dev/null || cut -d' ' -f1-3 /proc/loadavg)"`
    const { stdout } = await $.process.run(['sh', '-c', script, 'sh', current.log], { timeoutMs: 15000 })
    const lines = stdout.split('\n')
    const load = (lines.find(line => line.startsWith('@@load ')) ?? '').slice(7).replace(/[{}]/g, '').trim().split(/\s+/)[0] ?? ''
    // A run whose log never appears was not a run: drop it instead of counting forever.
    if (lines.includes('@@missing') && (await $.clock.now()) - current.startedAt > 15000) {
      await update($, run, value => (value?.log === current.log ? null : value))
      return
    }
    const markers = lines.filter(line => !line.startsWith('@@'))
    let { projects, ...parsed } = parse(markers, totals)
    // Nx rewrites its project graph as a run starts, after the totals were first read.
    if (projects !== null && projects !== totals.get('*') && reloads < 2) {
      reloads += 1
      await loadTotals($, current.cwd)
      ;({ projects, ...parsed } = parse(markers, totals))
    }
    const now = await $.clock.now()
    await update($, run, value =>
      value === null || value.log !== current.log
        ? value
        : { ...value, ...parsed, load, endedAt: parsed.outcome === 'running' ? null : now },
    )
    if (parsed.outcome !== 'running') {
      timer?.cancel()
      timer = null
      $.ui.toast(`${current.label} ${parsed.outcome} in ${clock(now - current.startedAt)}`)
    }
  } finally {
    isPolling = false
  }
}

function watch($: EngineInterface) {
  timer?.cancel()
  timer = $.clock.every(2000, () => void poll($))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    const current = await read($, run)
    if (current?.outcome === 'running') watch($)
    return started
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const log = logOf(e.command)
    if (log === null) return next(e)

    const cwd = e.command.match(/(?:^|[\s;&(])cd\s+(["']?)(\/[^\s"';&|)]+)\1/)?.[2] ?? (await $.session.cwd())
    reloads = 0
    const started: NxRun = {
      log,
      cwd,
      label: labelOf(e.command),
      startedAt: await $.clock.now(),
      endedAt: null,
      outcome: 'running',
      targets: [],
      failing: [],
      load: '',
    }
    await update($, run, () => started)
    void loadTotals($, cwd).then(() => watch($))

    // The command is left as written: a hook that rewrites it voids the permission review
    // it already passed. Nx streams each task only under NX_DEFAULT_OUTPUT_STYLE=stream.
    return next(e)
  }).catch(($, e, next) => (next.called ? { deny: `${$.plugin.name}: its hook failed after the command ran.` } : next(e)))

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const current = await read($, run)
    if (current === null || e.props.hasSurvey) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const now = current.endedAt ?? (await $.clock.now())
    const width = Math.max(...current.targets.map(target => target.name.length), 9)
    const tone = current.outcome === 'failed' ? 'red' : current.outcome === 'passed' ? 'green' : undefined

    return (
      <Box flexDirection="column">
        <Box>
          <Text weight="bold" color={tone}>
            {current.label}
          </Text>
          <Text dimColor>
            {'  '}
            {current.outcome}
            {'  '}
            {clock(now - current.startedAt)}
            {current.load ? `  load ${current.load}` : ''}
            {'  '}
          </Text>
          {current.outcome !== 'running' && (
            <Button key="hide" label="Hide" onPress={() => update($, run, () => null)} />
          )}
        </Box>
        {current.targets.map(target => (
          <Text key={target.name} mono>
            {target.name.padEnd(width)} {bar(target.done, target.total)}{' '}
            {target.total === null ? String(target.done) : `${Math.min(target.done, target.total)}/${target.total}`}
          </Text>
        ))}
        {current.failing.length > 0 && (
          <Text color="red" mono>
            {'failing'.padEnd(width)} {current.failing.slice(0, 6).join(', ')}
            {current.failing.length > 6 ? ` +${current.failing.length - 6}` : ''}
          </Text>
        )}
      </Box>
    )
  })
}
