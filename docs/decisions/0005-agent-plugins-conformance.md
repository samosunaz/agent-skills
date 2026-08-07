# 0005. Conform to Agent Plugins 1.0.0, with a flat `skills/` and a symlinked Claude manifest

- **Status**: accepted
- **Date**: 2026-08-06

## Context

[Agent Plugins 1.0.0](https://github.com/agentplugins/agent-plugins-spec) published a portable package format for agent plugins: a manifest at the plugin root with a **closed** field set (§5.2), fixed component locations (§6.1), skills discovered at the immediate children of `skills/` with recursion explicitly forbidden (§7.1), and containment of every package path inside the plugin root (§4.1). Client-specific data lives under reverse-domain namespaces (§8), not in the portable manifest.

This repo predates it and failed three of those rules. Its manifests lived only in client directories — `.claude-plugin/plugin.json` carrying a `skills` **array** of group dirs, `.codex-plugin/plugin.json` carrying a `skills` **string** and an `interface` block — so neither was portable and neither declared `$schema`. Worse, all 33 skills sat at `skills/<group>/<name>/SKILL.md`. Under §7.1 a conformant client discovers **zero** of them: the layout that made the repo readable made the plugin invisible.

The grouping was never a runtime construct. It was a table of contents for a human reading `README.md`, and it cost nothing to keep in that form.

Alternatives considered. **Stay non-conformant** — the two clients we actually use both load the repo today, so nothing is broken; rejected because the standard is what any third client will implement, and the fix gets more expensive with every skill added. **Adopt the manifest only, keep the groups** — conformant metadata over an undiscoverable package, which is worse than either honest state. **Move `agents/` and `reference/` under `com.anthropic.claude-code/`** — §8 permits it, but neither is a v1 component type (§7, §11.3): the spec assigns no meaning to those directories at the plugin root, and relocating them would break the working client to satisfy a rule that does not exist.

## Decision

**One portable manifest per plugin at its root; `skills/` is flat; the Claude manifest is a symlink.**

- **`plugins/<name>/plugin.json`** is the portable manifest — the closed field set plus the canonical `$schema`. It is the version release-please stamps.
- **`.claude-plugin/plugin.json` is a symlink to `../plugin.json`.** Claude Code reads the path it always read, and there is exactly one manifest to keep correct. `claude plugin validate --strict` passes through the symlink.
- **`.codex-plugin/plugin.json` stays a separate regular file.** Codex requires `skills` and `interface`, which the closed schema forbids; a second file is the honest encoding of a genuine divergence.
- **The 33 skills move to `skills/<name>/`.** No name collided, so `/samuel:<name>` is unchanged for every caller. The seven groups survive as the tables in `README.md` and `CLAUDE.md`.
- **`agents/` and `reference/` stay at the plugin root.** Not v1 component types, so the spec is silent on them, and silence is not prohibition.
- **`scripts/check-agent-plugins.sh` gates it in the pre-commit hook** (`bun run check:portability`): root manifest shape, skill discovery depth, path containment, and — this repo's own fourth rule — that every relative reference a skill cites still resolves. The flatten moved every `SKILL.md` one level up, and a stale `../../../` degrades into prose rather than failing loudly, so it needs a machine to notice.
- **`.claude-plugin/plugin.json` is deliberately absent from release-please `extra-files`.** release-please writes the file at the path it is given, which would replace the symlink with a regular file and fork the two manifests at the next release. `scripts/validate-plugins.sh` skips symlinked manifests for the same reason.

## Consequences

**Enables:**
- Any conformant client — not just the two installed here — discovers all 33 skills.
- One manifest to edit instead of two that drifted by construction.
- The relative-reference gate catches a class of rot the repo previously had no check for, independent of this migration.

**Costs / accepted trade-offs:**
- **Breaking for external path references.** Anything pointing at `plugins/samuel/skills/<group>/<name>/` breaks; skill invocation does not. Shipped as `feat(plugins)!`, which takes the repo to 4.0.0.
- The group taxonomy now lives only in prose, so it can drift from the directory listing. Accepted: it is a reading aid, and a wrong one is a documentation bug, not a load failure.
- Committed feature artifacts under `docs/features/` keep the old paths. They are a record of what was true when written and were left alone.
- The reference adoption in `lizos-music/agent-skills` (ADR 0008 there) was unmerged when this landed. If its review changes the pattern, this repo inherits the divergence — knowingly.

## References

- Spec: <https://github.com/agentplugins/agent-plugins-spec> — §4.1 containment, §5 manifest, §6.1 component locations, §7.1 skill discovery, §8 extension namespaces.
- Gate: `scripts/check-agent-plugins.sh`; release-please interplay in `scripts/validate-plugins.sh`.
- Prior art: `lizos-music/agent-skills` ADR 0008, same decision across five plugins with cross-plugin symlinks this repo does not have.
