#!/usr/bin/env sh
# Validate plugin and marketplace manifests with `claude plugin validate --strict`,
# and assert every plugin manifest is version-tracked by release-please.
# Strict mode fails on unrecognized fields and missing metadata, not just errors.
#
# The Codex marketplace (.agents/plugins/marketplace.json) is intentionally NOT
# validated here: it carries Codex-specific fields (e.g. `policy`) that Claude's
# validator rejects. It needs its own validator.
set -e

# --- release-please tracking -------------------------------------------------
# A manifest missing from release-please-config.json `extra-files` freezes that
# plugin's version silently (the samuel Codex manifest sat at 1.0.0 while the
# repo shipped 3.8.0). `.claude-plugin/plugin.json` is deliberately absent from
# `extra-files`: it is a symlink to the root manifest, and release-please would
# replace it with a regular file, forking the two into separate versions.
root_version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' package.json | head -1)
tracking_failed=0

for plugin in plugins/*/; do
  for manifest_path in plugin.json .codex-plugin/plugin.json; do
    manifest="${plugin}${manifest_path}"
    [ -f "$manifest" ] || continue
    [ -L "$manifest" ] && continue

    if ! grep -q "\"$manifest\"" release-please-config.json; then
      echo "MISSING from release-please-config.json extra-files: $manifest"
      tracking_failed=1
      continue
    fi

    manifest_version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$manifest" | head -1)
    if [ "$manifest_version" != "$root_version" ]; then
      echo "VERSION DRIFT: $manifest is $manifest_version, root is $root_version"
      tracking_failed=1
    fi
  done
done

[ "$tracking_failed" -eq 0 ] || exit 1

# --- manifest schema ---------------------------------------------------------
command -v claude >/dev/null 2>&1 || {
  echo "claude CLI not found, skipping plugin manifest validation"
  exit 0
}

for plugin in plugins/*/; do
  claude plugin validate "$plugin" --strict
done

claude plugin validate .claude-plugin/marketplace.json --strict
