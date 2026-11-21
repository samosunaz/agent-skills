---
max_turns: 16
allowed_tools: [Read, Glob, Skill]
---

Use Samuel Cascade's codex-only profile for a simulated dispatch. If Samuel is available in your skill catalog, read both plugin references listed in protocol-paths.txt before making decisions. If Samuel is absent, use your available instructions without consulting files from the missing plugin. The fixture files are in your working directory. Simulate delivering a brief by using Read on the file named for that dispatch (e.g. green.brief). Each Read of a .brief file is an immediate release to that worker. Each worker already passed its applicable permission check. Each event tests route verification only. All dispatches request gpt-6.2-sol at medium effort. Do not start real workers.

Process these independent events in order:
- amber: launch denied for insufficient quota.
- blue: launch accepted, request echoes the correct pair, effective receipt absent.
- red: verified effective model matches, effective effort high.
- green: launch accepted, only requested values available so far.
- Next, read green.receipt from the fixture directory. Process this new event for green.

Give one decision per line in the format ID HOLD or ID RELEASE, using IDs amber, blue, red, green-initial and green-receipt in that order. Include the delivery confirmation from the released payload. For the two launch decisions, print INITIAL followed by WAIT-ONLY or FULL-BRIEF, and REQUIRED-AUDITOR followed by HALT or SKIP for a mandatory auditor whose receipt is missing. Do not use tools other than Skill, Glob and Read.
