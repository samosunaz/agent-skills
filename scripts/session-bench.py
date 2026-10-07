#!/usr/bin/env python3
"""Benchmark the human side of Claude Code sessions over a time window.

Reads Claude Code transcripts (~/.claude/projects/<dir>/*.jsonl), separates the
turns a human typed from the ones the harness injected, and reports rates that
coordinate/waves are meant to drive down (bare acks, status polls, state relayed
by hand, retyped constraints, orchestration nags). Regexes match the owner's
Spanish and English; tune them, never the counts.

Usage:
  session-bench.py --since 2026-10-03 [--until 2026-10-06] DIR [DIR ...] [--json]
DIR is a project transcript directory. Entries are filtered by their own
timestamp, so a session that spans the window boundary counts only its part.
"""
import argparse, glob, json, os, re, sys
from collections import Counter

INJECTED = (
    "<task-notification", "Another Claude session", "[Image:", "This session is being continued",
    "<local-command", "[Request interrupted", "<system-reminder", "Caveat:", "<bash-",
    "[Cross-session", "<cross-session", "<teammate-message", "[Run these",
)
NAG = re.compile(r"orchestration message", re.I)
COMMAND = re.compile(r"<command-name>(.*?)</command-name>.*?(?:<command-args>(.*?)</command-args>)?", re.S)

ACK_WORDS = r"(y|yes|s[ií]|ok|okay|va|dale|adelante|aprobado|apruebo|procede|contin[uú]a|sigue|perfecto|listo|todo ok|go|de acuerdo|\d|\w+[aeií](lo|la|los|las))"
WORKER_BRIEF = ("You are working inside Orca", "FOLLOW-UP from the coordinator", "ROLE: You are", "You are a dispatched worker")
PASTED = re.compile(r"<pasted_content[^>]*>.*?</pasted_content[^>]*>", re.S)
CLASSES = {
    "ack": re.compile(rf"^\s*({ACK_WORDS}[\s,.!]*){{1,3}}$", re.I),
    "merge_order": re.compile(r"^\s*(adelante,?\s*)?(ready y )?(merge|mergea\w*)( (el|los) prs?| todo( lo mergeable)?)?[\s.!]*$", re.I),
    "status_poll": re.compile(r"c[oó]mo va|en qu[eé] qued[oó]|c[oó]mo qued[oó]|reanuda|\bestatus\b|\bstatus\b|qu[eé] pas[oó]|ya termin|sigues ah[ií]|c[oó]mo vamos", re.I),
    "state_relay": re.compile(r"\bmerged\b|mergead|ya (se )?merge|ya (se )?reinici|quota|cuota|l[ií]mite de uso|usage limit|ya est[aá] arriba|ya lo (cerr|actualic)", re.I),
    "constraint_retype": re.compile(r"menor cantidad de c[oó]digo|least code|imperson[aá]me|sin (legacy|compat)|no legacy|comentarios? (de )?narra", re.I),
    "model_effort": re.compile(r"\b(opus|sonnet|haiku|fable|gpt-?[\d.]+\w*|codex)\b[^\n]{0,40}\b(low|medium|high|xhigh|max|ultra)\b", re.I),
    "correction": re.compile(r"\bte equivocaste\b|\best[aá] mal\b|(^|[.,¿!]\s*)eso no\b|¿no era\b|^no,|por qu[eé] (hiciste|cambiaste)|\bwrong\b|\bno,? as[ií] no\b", re.I),
}
COORD_TOOL = re.compile(r"orca (orchestration|terminal create|worktree create)|worker-start")
QUOTA = re.compile(r"(usage|spend|session) limit (reached|hit)|hit your (usage )?limit|quota exhausted", re.I)


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in content):
            return None
        return "\n".join(x.get("text", "") for x in content if isinstance(x, dict) and x.get("type") == "text")
    return None


def scan(path, since, until):
    s = Counter(); human = []; coordinator = False; compactions = 0
    for line in open(path, encoding="utf-8", errors="replace"):
        try:
            o = json.loads(line)
        except ValueError:
            continue
        ts = (o.get("timestamp") or "")[:10]
        if not ts or ts < since or ts > until:
            continue
        t = o.get("type")
        if t == "assistant":
            s["assistant_turns"] += 1
            for b in o.get("message", {}).get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    inp = json.dumps(b.get("input", {}))
                    if b.get("name") == "SendMessage" or COORD_TOOL.search(inp):
                        coordinator = True
            continue
        if t != "user" or o.get("isSidechain"):
            continue
        content = o.get("message", {}).get("content")
        if isinstance(content, list) and any(isinstance(x, dict) and x.get("type") == "tool_result" for x in content):
            if QUOTA.search(json.dumps(content)[:20000]):
                s["quota_hits"] += 1
            continue
        txt = text_of(content)
        if txt is None or o.get("isMeta"):
            continue
        head = PASTED.sub("", txt).lstrip()
        if head.startswith(WORKER_BRIEF):
            s["worker_briefs"] += 1; continue
        if NAG.search(head) and len(head) < 200:
            s["orchestration_nags"] += 1; continue
        if head.startswith("This session is being continued"):
            compactions += 1; continue
        if head.startswith("<task-notification"):
            s["task_notifications"] += 1; continue
        if head.startswith(("Another Claude session", "[Cross-session", "<cross-session", "<teammate-message")):
            s["peer_messages"] += 1; continue
        if head.startswith(INJECTED):
            continue
        m = COMMAND.search(head)
        if m:
            s["slash_commands"] += 1
            head = (m.group(2) or "").strip()
            if not head:
                continue
        human.append(head)
    s["compactions"] = compactions
    return s, human, coordinator


def classify(turns):
    c = Counter(turns=len(turns))
    for t in turns:
        for k, rx in CLASSES.items():
            if rx.search(t) and not (k == "ack" and CLASSES["merge_order"].search(t)):
                c[k] += 1
    return c


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--since", required=True)
    ap.add_argument("--until", default="9999-12-31")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    groups = {"all": Counter(), "coordinator": Counter()}
    events = Counter(); sessions = Counter()
    for d in a.dirs:
        for f in glob.glob(os.path.join(d, "*.jsonl")):
            s, human, coord = scan(f, a.since, a.until)
            if not human and not s["assistant_turns"]:
                continue
            if s["worker_briefs"]:
                coord = False
            kind = "coordinator" if coord else ("worker" if "orca-workspaces" in d else "other")
            sessions[kind] += 1
            events += s
            c = classify(human)
            groups["all"] += c
            if coord:
                groups["coordinator"] += c

    out = {"window": [a.since, a.until], "sessions": dict(sessions), "events": dict(events), "turns": {}}
    for g, c in groups.items():
        n = c["turns"] or 1
        out["turns"][g] = {"human_turns": c["turns"], **{k: {"n": c[k], "pct": round(100 * c[k] / n, 1)} for k in CLASSES}}
    if a.json:
        json.dump(out, sys.stdout, indent=2); print(); return
    print(f"window {a.since} → {a.until} · sessions {dict(sessions)}")
    print("events " + " · ".join(f"{k} {v}" for k, v in sorted(events.items())))
    for g, row in out["turns"].items():
        print(f"\n[{g}] human turns {row['human_turns']}")
        for k in CLASSES:
            print(f"  {k:18} {row[k]['n']:5}  {row[k]['pct']:5.1f} %")


if __name__ == "__main__":
    main()
