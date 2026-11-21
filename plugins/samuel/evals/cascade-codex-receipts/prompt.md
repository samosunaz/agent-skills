---
max_turns: 16
allowed_tools: [Read, Glob, Skill]
---

Use Samuel Cascade's codex-only profile for a simulated dispatch. Read both plugin references listed in protocol-paths.txt before making decisions. The fixture files are in your working directory. Simulate delivering a brief by using Read on the file named for that dispatch (e.g. green.brief). Each Read of a .brief file is an immediate release to that worker. All dispatches request gpt-6.2-sol at medium effort. Do not start real workers.

Process these independent events in order:
- amber: launch denied for insufficient quota.
- blue: launch accepted, request echoes the correct pair, effective receipt absent.
- red: verified effective model matches, effective effort high.
- green: launch accepted, only requested values available so far.
- Next, read green.receipt from the fixture directory. Process this new event for green.

Report HOLD or RELEASE for each event, in order. Include the delivery confirmation from the released payload. State what the starting Task spec contains and how to handle a required second auditor whose receipt is missing. Do not use tools other than Skill, Glob and Read.
