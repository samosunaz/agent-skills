#!/usr/bin/env sh
set -eu
plugin=$(cd "$(dirname "$0")/../.." && pwd)
printf '%s\n' "$plugin/reference/model-routing.md" "$plugin/skills/cascade/SKILL.md" "$plugin/skills/iaas/references/phase-contracts.md" > protocol-paths.txt
