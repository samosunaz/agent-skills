export type TargetProgress = { name: string; done: number; total: number | null }

export type NxRun = {
  log: string
  cwd: string
  label: string
  startedAt: number
  endedAt: number | null
  outcome: 'running' | 'passed' | 'failed'
  targets: TargetProgress[]
  failing: string[]
  load: string
}

declare module 'claude-code' {
  interface PluginState {
    'nx-panel': { run: NxRun | null }
  }
}
