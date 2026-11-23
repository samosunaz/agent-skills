#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import re
import sys
from pathlib import Path

posting_command = re.compile(
    rb"\bgh[ \t]+(?:issue[ \t]+(?:comment|create)\b"
    rb"|pr[ \t]+(?:create|review|comment|edit)\b"
    rb"|api[ \t]+[^\n]*\b(?:comments|reviews)\b)"
)
skills = {
    str(path): path.parent
    for path in Path("plugins/samuel/skills").glob("*/SKILL.md")
    if path.is_file()
}
candidates = set()
covered = set()
for skill, directory in skills.items():
    for path in directory.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        content = path.read_bytes()
        joined_content = re.sub(rb"\\\r?\n", b"", content)
        if posting_command.search(content) or posting_command.search(joined_content):
            candidates.add(skill)
        if b"samuel:run" in content:
            covered.add(skill)

exclusion_file = Path("plugins/samuel/reference/run-metadata-exclusions.txt")
lines = exclusion_file.read_text(encoding="utf-8").splitlines()
exclusions = set()
errors = []
for index, raw_line in enumerate(lines):
    skill = raw_line.strip()
    if not skill or skill.startswith("#"):
        continue
    location = f"{exclusion_file}:{index + 1}"
    reason = lines[index - 1].strip() if index else ""
    if not reason.startswith("#") or not reason[1:].strip():
        errors.append(f"{location}: missing reason for {skill}")
    if skill in exclusions:
        errors.append(f"{location}: duplicate exclusion for {skill}")
    if skill not in skills:
        errors.append(f"{location}: unknown skill path {skill}")
    exclusions.add(skill)

for skill in sorted(candidates - covered - exclusions):
    errors.append(f"{skill}: missing samuel:run reference or reasoned exclusion")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print("Run metadata coverage OK")
PY
