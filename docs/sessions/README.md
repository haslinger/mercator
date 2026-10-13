# Session logs

Condensed logs of the Claude Code sessions that built Mercator. Each log contains only the conversation: the user's messages and Claude's replies. Thinking, tool calls and tool output are left out.

Export a session with:

```sh
scripts/export_session.py            # list this project's sessions
scripts/export_session.py latest     # export the newest one
scripts/export_session.py 2a53ba5b   # export by id prefix
```

Files are named `<date>-<session id prefix>.md`. Exporting the same session again overwrites its log, so a session that continues later can simply be exported again.
