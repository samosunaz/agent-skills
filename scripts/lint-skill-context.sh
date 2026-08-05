#!/usr/bin/env bash
# Lints the injected context commands (!`...`) of every SKILL.md. Two rules
# (CLAUDE.md § Shell Commands for Runtime Context):
#   1. Statically analyzable — no $( ) / ${ }: the permission engine rejects
#      them on machines without a matching allowlist; the skill crashes
#      before the fallback can run.
#   2. Never exit non-zero — an `|| echo "FALLBACK"` rescue or an
#      echo-terminated compound (the runner treats non-zero as an error).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, glob, sys

inj = re.compile(r'!`([^`]+)`')
errors = []
for path in sorted(glob.glob('plugins/**/SKILL.md', recursive=True)):
    for i, line in enumerate(open(path), 1):
        for cmd in inj.findall(line):
            c = cmd.strip()
            if c in ('pwd', 'date') or c.startswith('date '):
                continue
            if '$(' in c or '${' in c:
                errors.append(f'{path}:{i}: not statically analyzable ($() or ${{}}): {c[:90]}')
                continue
            last = c.split(';')[-1].strip()
            if '||' not in c and not last.startswith('echo'):
                errors.append(f'{path}:{i}: can exit non-zero (no || echo fallback): {c[:90]}')

if errors:
    print('Injected context commands violating CLAUDE.md rules:\n')
    print('\n'.join(errors))
    sys.exit(1)
print('Context commands OK')
PY
