#!/usr/bin/env sh
set -eu
case_dir=$(cd "$(dirname "$0")" && pwd)
cp "$case_dir/green.receipt" "$case_dir/green.brief" .
printf '%s\n' "$case_dir/../../skills/cascade/references/tier-briefs.md" "$case_dir/../../skills/iaas/references/phase-contracts.md" > protocol-paths.txt
