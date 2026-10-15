# Session logs

Condensed logs of the Claude Code sessions that built Mercator. Each log contains only the conversation: the user's messages and Claude's replies. Thinking, tool calls and tool output are left out.

Export a session with:

```sh
scripts/export_session.py            # list this project's sessions
scripts/export_session.py latest     # export the newest one
scripts/export_session.py 2a53ba5b   # export by id prefix
```

Files are named `<date>-<session id prefix>.md`. Exporting the same session again overwrites its log, so a session that continues later can simply be exported again.

## Cleaning (#131)

The logs are part of the documentation (the making-of), so personal details are replaced on export: local paths by general rules in the script, names, addresses and infrastructure details (host names, router, firewall, the public IP) by the rules in `scripts/session_redactions.local.tsv`. That file is git-ignored, because it contains exactly what should not be published. The script prints what it replaced.

```sh
scripts/export_session.py redact     # apply the rules again to all logs here
```

Logs exported before 2026-10-15 were read in full once and cleaned with these rules; their earlier versions remain in the git history.
