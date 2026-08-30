#!/usr/bin/env bash
# Verifies the attended-auto autonomy level is wired consistently across the
# skills that read it (plugins/samuel/reference/autonomy.md defines the level).
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

# G1 — checkpoint coverage: every SKILL.md carries the standard phrase or is
# listed in checkpoint-exclusions.txt. The check passes on EMPTY OUTPUT and its
# own pipeline exits 1 while doing so, so never branch on that exit code.
unclassified=$(comm -23 <(find plugins -name SKILL.md | sort) \
                        <(grep -rl 'interaction-tools' --include=SKILL.md plugins | sort) \
               | grep -vxFf plugins/samuel/reference/checkpoint-exclusions.txt)
if [ -n "$unclassified" ]; then
  echo "G1 FAIL — SKILL.md without checkpoint classification:"; echo "$unclassified"; fail=1
else
  echo "G1 PASS — checkpoint coverage clean"
fi

# G2 — every skill that reads the key also points at the spoke, and vice versa.
targets="plugins/samuel/skills/implement/SKILL.md
plugins/samuel/skills/done/SKILL.md
plugins/samuel/skills/next/SKILL.md
plugins/samuel/skills/start-task/SKILL.md
plugins/samuel/skills/session-handoff/SKILL.md"
missing=0
for f in $targets; do
  grep -q '^- Autonomy: ' "$f" || { echo "G2 FAIL — no Autonomy context read: $f"; missing=1; }
  grep -q 'reference/autonomy.md' "$f" || { echo "G2 FAIL — no autonomy.md pointer: $f"; missing=1; }
done
[ "$missing" -eq 0 ] && echo "G2 PASS — 5/5 skills read the key" || fail=1

# G2b — the shipped read lines are byte-identical to the one autonomy.md
# documents. Without this the G4 probe below tests a private copy: a skill can
# silently lose the whitelist while every value assertion still reports PASS.
canon=$(grep -h '^- Autonomy: !' plugins/samuel/reference/autonomy.md | head -1)
drift=0
if [ -z "$canon" ]; then
  echo "G2b FAIL — autonomy.md § Resolution documents no read line"; fail=1; drift=1
else
  for f in $targets; do
    [ "$(grep -h '^- Autonomy: !' "$f")" = "$canon" ] \
      || { echo "G2b FAIL — read line drifted from autonomy.md § Resolution: $f"; drift=1; }
  done
  [ "$drift" -eq 0 ] && echo "G2b PASS — 5/5 read lines match the documented one" || fail=1
fi

# G2c — every skill states the unattended override next to its pointer. The read
# cannot detect a headless run (no env signal is expressible in an injected
# command), so the rule has to reach the agent as text in the skill it is
# already reading — a sentence living only in the spoke filters nothing.
over=0
for f in $targets; do
  grep -q 'is `autonomous` and ignores the `Autonomy:` value' "$f" \
    || { echo "G2c FAIL — no unattended-precedence clause: $f"; over=1; }
  # the clause must enumerate headless runs too — narrowing it back to the
  # conductor alone reinstates the hole G7 closes in the spoke
  grep -q 'claude -p' "$f" \
    || { echo "G2c FAIL — unattended clause names only the conductor: $f"; over=1; }
done
[ "$over" -eq 0 ] && echo "G2c PASS — 5/5 skills carry the unattended override" || fail=1

# G3 — the spoke exists.
[ -f plugins/samuel/reference/autonomy.md ] \
  && echo "G3 PASS — autonomy.md present" \
  || { echo "G3 FAIL — plugins/samuel/reference/autonomy.md missing"; fail=1; }

# G4 — the read chain resolves. The probe is EXTRACTED from the documented line
# (G2b has just proved the five skills carry that same line), never retyped
# here: a hand-copied probe verifies itself and passes while the shipped read
# has lost its whitelist entirely.
probe() {
  local c=${canon#- Autonomy: \!\`}   # strip the injection wrapper
  c=${c%\`}
  c=${c//\~\/.claude\/samuel.md/@GLOBAL@}   # longest path first — the repo path is its suffix
  c=${c//.claude\/samuel.md/@REPO@}
  c=${c//@GLOBAL@/$2}
  c=${c//@REPO@/$1}
  eval "$c"
}
tmp=$(mktemp -d)
: > "$tmp/empty.md"
printf 'autonomy: attended-auto\n'                  > "$tmp/on.md"
printf 'autonomy: attended-auto   # inline comment\n' > "$tmp/commented.md"
printf 'autonomy: autonomous\n'                     > "$tmp/escalate.md"
printf 'autonomy: attendedauto\n'                   > "$tmp/typo.md"
printf 'autonomy:\n'                                > "$tmp/blank.md"
check4() { # id, actual, expected, label
  [ "$2" = "$3" ] && echo "G4$1 PASS — $4" || { echo "G4$1 FAIL — $4: expected '$3', got '$2'"; fail=1; }
}
check4 a "$(probe "$tmp/empty.md"     "$tmp/empty.md")" interactive   "no key -> interactive"
check4 b "$(probe "$tmp/on.md"        "$tmp/empty.md")" attended-auto "repo key wins"
check4 c "$(probe "$tmp/empty.md"     "$tmp/on.md")"    attended-auto "global fallback resolves"
check4 d "$(probe "$tmp/commented.md" "$tmp/empty.md")" attended-auto "inline comment stripped"
check4 e "$(probe "$tmp/escalate.md"  "$tmp/empty.md")" interactive   "autonomous is not settable from a file"
check4 f "$(probe "$tmp/typo.md"      "$tmp/empty.md")" interactive   "unrecognised value rejected"
check4 g "$(probe "$tmp/blank.md"     "$tmp/empty.md")" interactive   "empty value rejected"
# a rejected repo value must NOT fall through to a global attended-auto
check4 h "$(probe "$tmp/escalate.md"  "$tmp/on.md")"    interactive   "rejected repo value does not fall through"
rm -rf "$tmp"

# G5 — the conductor's own bypass is untouched: the repo-wide count of its
# parentheticals is fixed, so rewriting one to serve attended-auto trips this.
# The pattern must not match `# Conductor (Autonomous Pipeline Driver)`, the
# conductor's own H1 — counting a title as a bypass inflated this to 10.
# The number moves only when a skill gains a genuinely new autonomy gate, and
# the bump belongs in that skill's own commit: 9 → 10 for the /samuel:iaas
# round-ceiling CONFIRM.
marks=$(grep -rn '(Conductor: \|(Autonomous: \|(Autonomous bootstrap: ' --include=SKILL.md plugins | wc -l | tr -d ' ')
[ "$marks" -eq 10 ] \
  && echo "G5 PASS — conductor bypass intact (10 parentheticals)" \
  || { echo "G5 FAIL — expected 10 conductor/autonomous parentheticals, found $marks"; fail=1; }

# G6 — cross-check, not a count: read the gates autonomy.md promises to move
# (its table rows minus the ones marked **waits**) and require each skill to
# carry exactly that many clauses. A hardcoded total passes even when the
# clauses sit in the wrong files, which is how a table full of stale citations
# once sailed through green.
skill_file() {
  case "$1" in
    implement)       echo plugins/samuel/skills/implement/SKILL.md ;;
    done)            echo plugins/samuel/skills/done/SKILL.md ;;
    next)            echo plugins/samuel/skills/next/SKILL.md ;;
    start-task)      echo plugins/samuel/skills/start-task/SKILL.md ;;
    session-handoff) echo plugins/samuel/skills/session-handoff/SKILL.md ;;
    *)               echo "" ;;
  esac
}
promised=$(awk '/^## Which gates move/{s=1;next} /^## /{s=0} s && /^\| `/ && !/\*\*waits\*\*/ {gsub(/`/,"",$2); print $2}' \
             plugins/samuel/reference/autonomy.md | sort | uniq -c)
g6=0
while read -r want skill; do
  f=$(skill_file "$skill")
  if [ -z "$f" ]; then echo "G6 FAIL — autonomy.md names an unknown skill: $skill"; g6=1; continue; fi
  got=$(grep -c '(attended-auto:' "$f" 2>/dev/null); got=${got:-0}   # grep -c prints 0 AND exits 1; a `|| echo 0` rescue yields "0\n0"
  [ "$got" -eq "$want" ] || { echo "G6 FAIL — $skill: autonomy.md promises $want gate(s), $f wires $got"; g6=1; }
done <<< "$promised"
total=$(grep -rn '(attended-auto:' --include=SKILL.md plugins | wc -l | tr -d ' ')
sum=$(echo "$promised" | awk '{n+=$1}END{print n+0}')
[ "$total" -eq "$sum" ] || { echo "G6 FAIL — $total clauses repo-wide, but autonomy.md promises $sum (a clause lives in an unlisted skill)"; g6=1; }
[ "$g6" -eq 0 ] && echo "G6 PASS — $sum promised gates wired in the skills autonomy.md names" || fail=1

# G6b — the gate table cites sections, never lines. Line citations in that table
# go stale the moment anything is inserted above them, and the table is the only
# index of where the gates live.
stale=$(awk '/^## Which gates move/{s=1;next} /^## /{s=0} s' plugins/samuel/reference/autonomy.md \
        | grep -n 'SKILL\.md:[0-9]' || true)
if [ -n "$stale" ]; then
  echo "G6b FAIL — gate table cites line numbers:"; echo "$stale"; fail=1
else
  echo "G6b PASS — gate table cites sections, not lines"
fi

# G7 — an unattended run outranks the file key, and "unattended" must cover more
# than /samuel:conductor: interaction-tools.md defines it as the conductor OR a
# headless `claude -p` + /goal. A run that stays on attended-auto with no reader
# announces into the void and, per § Recording contract, records nothing at all.
resolution=$(awk '/^## Resolution/{s=1;next} /^## /{s=0} s' plugins/samuel/reference/autonomy.md)
g7=0
echo "$resolution" | grep -qi 'autonomous.*unconditionally' || { echo "G7 FAIL — § Resolution does not rank an unattended run above the file key"; g7=1; }
echo "$resolution" | grep -qi 'claude -p'                   || { echo "G7 FAIL — § Resolution's precedence rule names only the conductor, not headless runs"; g7=1; }
[ "$g7" -eq 0 ] && echo "G7 PASS — unattended precedence covers conductor + headless" || fail=1

# G8 — the template ships the key INERT. A consumer repo that copies it verbatim
# (which tracker.md explicitly anticipates) must get today's behaviour, not eight
# checkpoints switched off by a file nobody opted into.
if grep -q '^autonomy:' template/samuel.md; then
  echo "G8 FAIL — template/samuel.md ships autonomy switched on; comment the line out"; fail=1
else
  echo "G8 PASS — template ships the key commented out"
fi

exit "$fail"
