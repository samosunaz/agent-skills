#!/usr/bin/env bash
# Asserts every plugin conforms to Agent Plugins 1.0.0 (agent-plugins.org).
# Four rules a client enforces at load time, so a violation must never reach main:
#   1. Root plugin.json — closed field set, canonical $schema, name constraints (§5).
#   2. Skills are immediate children of skills/; deeper SKILL.md is never found (§7.1).
#   3. No package path resolves outside its plugin root — symlinks included (§4.1).
#   4. Every relative path a skill cites resolves — the flat layout moved every
#      SKILL.md one level up, so a stale `../../../` reads as prose, not a 404.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import json, os, re, sys, glob

SCHEMA = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
PORTABLE = {"$schema", "name", "version", "description", "author",
            "homepage", "repository", "license", "keywords", "extensions"}
NAME_RE = re.compile(r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$')
REF_RE = re.compile(r'(?:\.\./)+[A-Za-z0-9._/-]+\.(?:md|sh|yml|yaml|txt|json|py)')

# (file, ref) pairs that are templates quoted for another file's depth, not links.
EXEMPT_REFS = {
    ("plugins/samuel/reference/interaction-tools.md", "../../reference/interaction-tools.md"),
}

errors = []
plugins = sorted(d for d in glob.glob("plugins/*") if os.path.isdir(d))

for root in plugins:
    # --- 1. manifest ---------------------------------------------------------
    manifest = f"{root}/plugin.json"
    if not os.path.isfile(manifest):
        errors.append(f"{root}: missing root plugin.json (§5.1)")
        continue
    try:
        m = json.load(open(manifest))
    except json.JSONDecodeError as e:
        errors.append(f"{manifest}: invalid JSON ({e})")
        continue

    unknown = set(m) - PORTABLE
    if unknown:
        errors.append(f"{manifest}: non-portable top-level fields {sorted(unknown)} (§5.2)")
    if m.get("$schema") != SCHEMA:
        errors.append(f"{manifest}: $schema must be exactly {SCHEMA} (§5.2)")
    name = m.get("name", "")
    if not (isinstance(name, str) and 1 <= len(name) <= 64
            and NAME_RE.match(name) and "--" not in name and ".." not in name):
        errors.append(f"{manifest}: name {name!r} violates the name constraints (§5.5)")

    # Claude Code reads .claude-plugin/plugin.json; the symlink keeps one manifest.
    claude = f"{root}/.claude-plugin/plugin.json"
    if os.path.lexists(claude):
        if not os.path.islink(claude):
            errors.append(f"{claude}: must be a symlink to ../plugin.json, not a second copy")
        elif os.readlink(claude) != "../plugin.json":
            errors.append(f"{claude}: symlink must point at ../plugin.json")

    # --- 2. skill discovery depth -------------------------------------------
    skills = f"{root}/skills"
    if os.path.exists(skills):
        if not os.path.isdir(skills):
            errors.append(f"{skills}: exists but is not a directory (§6.2)")
        else:
            for found in glob.glob(f"{skills}/*/*/**/SKILL.md", recursive=True):
                errors.append(f"{found}: below the immediate children of skills/ — never discovered (§7.1)")
            for child in sorted(os.listdir(skills)):
                d = f"{skills}/{child}"
                if os.path.isdir(d) and not os.path.isfile(f"{d}/SKILL.md"):
                    errors.append(f"{d}: child of skills/ without SKILL.md (§7.1)")

    # --- 3. package containment ---------------------------------------------
    real_root = os.path.realpath(root)
    for dirpath, dirnames, filenames in os.walk(root):
        for entry in dirnames + filenames:
            path = os.path.join(dirpath, entry)
            if not os.path.islink(path):
                continue
            target = os.path.realpath(path)
            if not os.path.exists(target):
                errors.append(f"{path}: broken symlink -> {os.readlink(path)}")
            elif os.path.commonpath([target, real_root]) != real_root:
                errors.append(f"{path}: resolves outside the plugin root -> {target} (§4.1)")

    # --- 4. relative references ----------------------------------------------
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            if not fn.endswith((".md", ".sh", ".yml", ".yaml", ".txt")):
                continue
            path = os.path.join(dirpath, fn)
            try:
                body = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            for ref in sorted(set(REF_RE.findall(body))):
                if (path, ref) in EXEMPT_REFS:
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(dirpath, ref))):
                    errors.append(f"{path}: relative reference does not resolve -> {ref}")

if errors:
    print("Agent Plugins 1.0.0 conformance violations:\n")
    print("\n".join(f"  {e}" for e in errors))
    sys.exit(1)
print(f"Agent Plugins conformance OK ({len(plugins)} plugin{'s' if len(plugins) != 1 else ''})")
PY
