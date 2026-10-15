#!/usr/bin/env python3
"""Export a Claude Code session as a condensed Markdown log.

Only the conversation is kept: the user's messages and Claude's replies.
Thinking, tool calls, tool output, IDE notices and loaded skill texts are
left out.

Usage:
    scripts/export_session.py                     # list this project's sessions
    scripts/export_session.py <session-id> [out]  # export one session
    scripts/export_session.py latest [out]        # export the newest session
    scripts/export_session.py redact              # clean the logs in docs/sessions again

<session-id> may be a prefix of the id or a path to a .jsonl transcript.
The default output is docs/sessions/<date>-<id prefix>.md.

The logs are part of the documentation (the making-of, #131), so personal
details are replaced on export: local paths by the general rules below, and
names, addresses and infrastructure details by the rules in
scripts/session_redactions.local.tsv. That file is git-ignored, since it
holds exactly what should not be published: one rule per line, a Python
regular expression and its replacement separated by a tab; lines starting
with # are comments.
"""
import json
import re
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TRANSCRIPTS = Path.home() / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(REPO))

DROP_TAGS = re.compile(
    r"<(ide_opened_file|ide_selection|system-reminder|task-notification"
    r"|command-[a-z]+|local-command-[a-z]+)>.*?</\1>",
    re.S,
)
COMPACTED = "*(Context was compacted here; the conversation continued from a summary.)*"
LOCAL_RULES = REPO / "scripts" / "session_redactions.local.tsv"

# where the projects live on this machine, e.g. /home/<user>/src
BASE = str(REPO.parent.parent)
GENERAL_RULES = [
    (re.escape(BASE), "~/src"),
    (re.escape(re.sub(r"[^A-Za-z0-9]", "-", BASE)) + "-", "-src-"),
    (r"/home/[A-Za-z0-9_.-]+", "~"),
]


def rules():
    local = []
    if LOCAL_RULES.exists():
        for line in LOCAL_RULES.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                pattern, replacement = line.split("\t", 1)
                local.append((pattern, replacement))
    else:
        print(f"warning: {LOCAL_RULES.name} is missing, only general rules applied", file=sys.stderr)
    # the local rules first: they may name full paths or addresses
    return [(re.compile(p), r) for p, r in local + GENERAL_RULES]


def redact(text, compiled, counts):
    for pattern, replacement in compiled:
        text, n = pattern.subn(replacement, text)
        if n:
            counts[pattern.pattern] = counts.get(pattern.pattern, 0) + n
    return text


def report(counts):
    for pattern, n in counts.items():
        print(f"  replaced {n}x  {pattern}")


def sessions():
    return sorted(TRANSCRIPTS.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)


def find(arg):
    path = Path(arg)
    if path.suffix == ".jsonl" and path.exists():
        return path
    all_sessions = sessions()
    if arg == "latest":
        return all_sessions[0]
    matches = [p for p in all_sessions if p.stem.startswith(arg)]
    if len(matches) != 1:
        sys.exit(f"{len(matches)} sessions match {arg!r}")
    return matches[0]


def entries(path):
    for line in path.open(encoding="utf-8"):
        d = json.loads(line)
        if d.get("isSidechain") or d.get("isMeta") or d.get("type") not in ("user", "assistant"):
            continue
        if d.get("isCompactSummary"):
            yield "note", d["timestamp"], COMPACTED
            continue
        content = d["message"]["content"]
        if isinstance(content, str):
            content = [{"type": "text", "text": content}]
        texts = [DROP_TAGS.sub("", b["text"]).strip() for b in content if b.get("type") == "text"]
        text = "\n\n".join(t for t in texts if t)
        if text and not text.startswith("[Request interrupted"):
            yield d["type"], d["timestamp"], text


def render(path):
    items = list(entries(path))
    if not items:
        sys.exit(f"{path.name} has no conversation")
    first, last = items[0][1], items[-1][1]
    out = [
        f"# Session log: {first[:10]} ({path.stem[:8]})",
        "",
        f"Condensed export of Claude Code session `{path.stem}`, "
        f"{first[:10]} {first[11:16]} to {last[:10]} {last[11:16]} UTC. "
        "It contains only the conversation: the user's messages and Claude's replies. "
        "Thinking, tool calls and tool output are left out.",
        "",
    ]
    prev = None
    for kind, ts, text in items:
        if kind == "note":
            out += ["---", "", text, ""]
            prev = None
            continue
        if kind != prev:
            out += [f"### {'User' if kind == 'user' else 'Claude'} · {ts[11:16]}", ""]
        out += [text, ""]
        prev = kind
    return first[:10], "\n".join(out).rstrip() + "\n"


def main(args):
    if args == ["redact"]:
        compiled = rules()
        for log in sorted((REPO / "docs" / "sessions").glob("*.md")):
            counts = {}
            text = log.read_text(encoding="utf-8")
            cleaned = redact(text, compiled, counts)
            if cleaned != text:
                log.write_text(cleaned, encoding="utf-8")
                print(f"cleaned {log.name}")
                report(counts)
        return
    if not args:
        for p in sessions():
            mtime = datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
            print(f"{p.stem}  {mtime}  {p.stat().st_size // 1024:>7} KB")
        return
    path = find(args[0])
    date, markdown = render(path)
    counts = {}
    markdown = redact(markdown, rules(), counts)
    out = Path(args[1]) if len(args) > 1 else REPO / "docs" / "sessions" / f"{date}-{path.stem[:8]}.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(markdown, encoding="utf-8")
    print(f"wrote {out}")
    report(counts)


if __name__ == "__main__":
    main(sys.argv[1:])
