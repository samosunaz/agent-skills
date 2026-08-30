#!/usr/bin/env bash
# Lints the injected context commands (!`...`) of every SKILL.md. Three rules
# (CLAUDE.md § Shell Commands for Runtime Context):
#   1. Statically analyzable — no $( ) / ${ } / ( ): the permission engine
#      rejects substitutions on machines without a matching allowlist, and it
#      never decomposes a subshell, so no allowlist rule can ever match one.
#      Either way the skill crashes before the fallback can run.
#   2. Never exit non-zero — an `|| echo "FALLBACK"` rescue or an
#      echo-terminated compound (the runner treats non-zero as an error).
#   3. Every binary declared in the skill's own allowed-tools. An undeclared one
#      is denied on a repo with no matching allowlist, and headless that denial
#      is silent: exit 0, zero turns, empty output — an overnight run looks
#      successful having done nothing.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re, glob, sys

inj = re.compile(r'!`([^`]+)`')
# Shell builtins never reach the permission engine, so they need no declaration.
BUILTINS = {'echo', 'pwd', 'cd', 'true', 'false', ':'}
errors = []
# template/SKILL.md is the file every new skill is copied from — the exemplar of
# these rules has to sit inside the gate that enforces them.
for path in sorted(glob.glob('plugins/**/SKILL.md', recursive=True) + glob.glob('template/SKILL.md')):
    text = open(path).read()
    # Rule 3 needs the whole file: the declarations live in the frontmatter, the
    # commands anywhere below it. A bare `Bash` token authorizes every command,
    # which leaves nothing to declare.
    at = re.search(r'^allowed-tools:.*$', text, re.M)
    declared = None
    if at and not re.search(r'(?:^|\s)Bash(?:\s|$)', at.group(0)):
        declared = re.findall(r'Bash\(([^)]*)\)', at.group(0))
    for i, line in enumerate(text.splitlines(), 1):
        for cmd in inj.findall(line):
            c = cmd.strip()
            # Quoted strings are blanked once and reused by rules 1 and 3: an
            # awk program carries ( ) ; and | inside it, and reading those as
            # shell syntax would misjudge its own body.
            blanked = re.sub(r"'[^']*'|\"[^\"]*\"", "''", c)
            # `pwd`/`date` cannot fail, so rules 1-2 exempt them. Rule 3 still
            # applies: `date` is a binary and the permission engine checks it.
            if not (c in ('pwd', 'date') or c.startswith('date ')):
                if '$(' in c or '${' in c:
                    errors.append(f'{path}:{i}: not statically analyzable ($() or ${{}}): {c[:90]}')
                    continue
                if '(' in blanked:
                    errors.append(f'{path}:{i}: not statically analyzable (subshell ( ) — the permission engine cannot match one): {c[:90]}')
                    continue
                last = c.split(';')[-1].strip()
                if '||' not in c and not last.startswith('echo'):
                    errors.append(f'{path}:{i}: can exit non-zero (no || echo fallback): {c[:90]}')
            if declared is None:
                continue
            # One binary per pipeline segment.
            for seg in re.split(r'&&|\|\||\||;', blanked):
                seg = re.sub(r'^\d*>\S*\s*', '', seg.strip())
                m = re.match(r'[a-z][a-z0-9_.-]*', seg)
                if not m or m.group(0) in BUILTINS:
                    continue
                b = m.group(0)
                # Binary-level match, v1 limitation: a declared `Bash(git log *)`
                # satisfies any git command here, though the permission engine
                # can still deny the subcommand at runtime.
                if not any(d == b or d.startswith(b + ' ') for d in declared):
                    errors.append(f'{path}:{i}: `{b}` not in allowed-tools: {c[:70]}')

if errors:
    print('Injected context commands violating CLAUDE.md rules:\n')
    print('\n'.join(errors))
    sys.exit(1)
print('Context commands OK')
PY
