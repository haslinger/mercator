#!/usr/bin/env python3
"""Export a Claude Code session as a condensed Markdown log.

Only the conversation is kept: the user's messages and Claude's replies.
Thinking, tool calls, tool output, IDE notices and loaded skill texts are
left out.

Usage:
    scripts/export_session.py                     # list this project's sessions
    scripts/export_session.py <session-id> [out]  # export one session
    scripts/export_session.py latest [out]        # export the newest session

<session-id> may be a prefix of the id or a path to a .jsonl transcript.
The default output is docs/sessions/<date>-<id prefix>.md.
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
    if not args:
        for p in sessions():
            mtime = datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
            print(f"{p.stem}  {mtime}  {p.stat().st_size // 1024:>7} KB")
        return
    path = find(args[0])
    date, markdown = render(path)
    out = Path(args[1]) if len(args) > 1 else REPO / "docs" / "sessions" / f"{date}-{path.stem[:8]}.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(markdown, encoding="utf-8")
    print(f"wrote {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
