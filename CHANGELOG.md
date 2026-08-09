# Changelog

## [4.2.0](https://github.com/samosunaz/agent-skills/compare/v4.1.0...v4.2.0) (2026-08-09)


### 🚀 Features

* adopt cross-session messaging as the pipeline's interrupt channel ([#7](https://github.com/samosunaz/agent-skills/issues/7)) ([ce1a123](https://github.com/samosunaz/agent-skills/commit/ce1a1235e89ea3abd5999ad30a51b997d1990b9f))

## [4.1.0](https://github.com/samosunaz/agent-skills/compare/v4.0.0...v4.1.0) (2026-08-07)


### 🚀 Features

* **skills:** add tldr, the prose standard, and wire the TL;DR block to it ([#5](https://github.com/samosunaz/agent-skills/issues/5)) ([3de5856](https://github.com/samosunaz/agent-skills/commit/3de58562bfcdddcc03b1bfe1a4af812ab8185df3))

## [4.0.0](https://github.com/samosunaz/agent-skills/compare/v3.11.1...v4.0.0) (2026-08-07)


### ⚠ BREAKING CHANGES

* **plugins:** skills moved from plugins/samuel/skills/<group>/<name>/ to plugins/samuel/skills/<name>/. Any external path reference breaks; skill invocation does not.

### 🚀 Features

* **plugins:** conform to Agent Plugins 1.0.0 ([bbea2bb](https://github.com/samosunaz/agent-skills/commit/bbea2bbb9edf34df3a704b6ca500ca06187cc3f7))


### 📄 Documentation

* describe the flat skill layout and the portable manifest ([5a0e5c6](https://github.com/samosunaz/agent-skills/commit/5a0e5c6684ca4d301c09c17ab12aef6b425f9c63))
* **readme:** add version badges and drop the personalized framing ([#4](https://github.com/samosunaz/agent-skills/issues/4)) ([f1ff3ed](https://github.com/samosunaz/agent-skills/commit/f1ff3edb64a6f433928d907be1f559422abf77df))
* translate the diagram vocabulary and the last domain nouns ([d1333f2](https://github.com/samosunaz/agent-skills/commit/d1333f2cd8db6b507a94426444dc85fd94a15fba))


### ☁️ Continuous Integration

* gate Agent Plugins conformance in the pre-commit hook ([73ee363](https://github.com/samosunaz/agent-skills/commit/73ee363c795cba900f6a2556628e1a0f69c433f2))

## [3.11.1](https://github.com/samosunaz/agent-skills/compare/v3.11.0...v3.11.1) (2026-08-07)


### 📄 Documentation

* drop the author's first name from address-pr-comments ([f980901](https://github.com/samosunaz/agent-skills/commit/f980901932fbfea35278e7a912668465a012d936))
* finish the English pass — chips, dispositions, and the ROUTE prompt ([f220d43](https://github.com/samosunaz/agent-skills/commit/f220d43c15836a88ea7dfe8b8471a5619d64db9e))
* retire Backlog.md, link every skill from the README, and meet the Codex plugin schema ([6f3aea6](https://github.com/samosunaz/agent-skills/commit/6f3aea6cff2b472754335875714ac5b85ff2ab93))
* write the public registry in English end to end ([077eada](https://github.com/samosunaz/agent-skills/commit/077eada0028045fc19170389f158a3a5cc432f2a))


### ☁️ Continuous Integration

* allow release-please to be run manually ([e8dc536](https://github.com/samosunaz/agent-skills/commit/e8dc53648465f065616056e4cfdc519e64c453a0))

## 3.11.0 (2026-08-01)


### 🚀 Features

* **samuel:** add address-pr-comments — author side of the PR review gate

## 3.10.0 (2026-07-30)


### 🚀 Features

* **samuel:** optional Given/When/Then in plan manual validation

## 3.9.0 (2026-07-28)


### 🚀 Features

* add OpenAI Codex compatibility layer

## 3.8.0 (2026-07-28)


### 🚀 Features

* **samuel:** wave-prep — backlog to wave-set preparer, closes #52

## 3.7.0 (2026-07-28)


### 🚀 Features

* **samuel:** declare native blockedBy edges at plan and roadmap time

## 3.6.0 (2026-07-28)


### 🚀 Features

* **samuel:** waves — attended multi-issue wave coordinator over Orca

## 3.5.0 (2026-07-28)


### 🚀 Features

* **samuel:** attended-auto — a third autonomy level for soft checkpoints

## 3.4.0 (2026-07-27)


### 🧹 Miscellaneous Chores

* **samuel:** strip the inline gloss when reading .claude/samuel.md
* **samuel:** verify the item is open before composing Closes #N

## 3.3.0 (2026-07-27)


### 🚀 Features

* **conductor:** account for cost and outcome per run, report it, and scan in the gate, closes #25
* mirror upstream delta — interaction tools, mermaid standard, promo marker, close seams
* **samuel:** add promo:bip — the building-in-public marker
* **samuel:** open every Issue and PR with a human TL;DR block


## 3.2.0 (2026-07-16)


### 🚀 Features

* **samuel:** mirror upstream delta — enumeration IDs, SHA permalinks, blast radius

## 3.1.0 (2026-07-13)


### 🚀 Features

* **samuel:** add create-review-md — REVIEW.md generator

## 3.0.0 (2026-07-13)


### ⚠ BREAKING CHANGES

* **samuel:** the backlog tracker backend is no longer supported; repos with `tracker: backlog` in .claude/samuel.md must migrate their items to GitHub Issues.

### 🚀 Features

* **samuel:** mirror upstream delta — single tracker, unknowns seams, REVIEW.md canon

## 2.5.0 (2026-07-13)


### 🚀 Features

* **samuel:** require e2e tier decision at plan time


## 2.4.0 (2026-07-06)


### 🚀 Features

* **contract:** add api-request and api-contract skills

## 2.3.0 (2026-07-03)


### 🚀 Features

* add design skill

## 2.2.0 (2026-06-16)


### 🚀 Features

* **conductor:** automatic trigger (heartbeat) for the autonomous pipeline loop

## 2.1.0 (2026-06-15)


### 🚀 Features

* **validate:** independent adversarial reviewer (maker/checker gate)

## 2.0.0 (2026-06-15)


### ⚠ BREAKING CHANGES

* GitHub Issues is the new default source of truth. The state contract gains tracker/repo/item, feature_dir moves to docs/features/<slug>/, and the journal/validation become committed files in both trackers. Pin the backend per repo in .claude/samuel.md.

### 🚀 Features

* samuel v2, GitHub-native dual-tracker pipeline

## 1.3.0 (2026-06-14)


### 🚀 Features

* initial commit — personal agent skills registry
* **skills:** add /samuel:conductor for autonomous /goal pipeline runs
* **skills:** add /samuel:spec and /samuel:analyze pipeline skills
* **skills:** add feature-dossier for living product capability docs
* **skills:** add implementation-notes journal to implement & validate
* **skills:** add optional constitution governance skills
* **skills:** add team-orchestrate skill for multi-session agent teams
* **skills:** adopt team's backlog-aware methodology
* **skills:** port backlog 1.45.1 ops to English + add task-context & journal refs
* **skills:** thread feature dir + pipeline phase through existing skills


### 🩹 Fixes

* **skills:** correct broken backlog-operations reference paths
* **skills:** replace shell expansion in inline commands with $-free awk


### 📄 Documentation

* add README with installation, pipeline, and skill catalog
* add README with installation, pipeline, and skill catalog
* **claude:** document spec-driven pipeline, journal, and conductor
* **skills:** add Mermaid pipeline flow diagrams
* **skills:** translate skill prose to English, keep bilingual triggers


### ☁️ Continuous Integration

* configure release-please for automated versioning and releases
* configure release-please for automated versioning and releases


### 🧹 Miscellaneous Chores

* **samuel:** bump plugin to 1.1.0
* **samuel:** register meta skills and bump to 1.2.0
