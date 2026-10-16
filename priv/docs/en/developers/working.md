---
title: Working on the code
order: 1
---
## Setup

- Erlang and Elixir via asdf, versions pinned in `.tool-versions` (also Typst for the PDFs).
- PostgreSQL locally with `postgres`/`postgres`; `mix setup` installs dependencies, creates and migrates the database and seeds the Biber Holz demo (`priv/repo/seeds.exs`, idempotent).
- `mix phx.server` on port 4000, with the Biber Holz brand, the payment simulator and the making-of switched on (`config/dev.exs`).
- Dev tools: `/dev/mailbox` (sent emails), `/dev/ash-admin` (raw data), and the Tidewave MCP endpoint for AI assistants. The LiveDashboard runs in all environments at `/admin/system` (administrators only).

## Before every commit

```sh
mix precommit
```

It compiles with warnings as errors, checks formatting, runs Credo in strict mode, Sobelow (security) and all tests. Commit only when it passes, and check its exit status: a pipe hides it.

- **Sobelow:** reviewed false positives are fingerprinted in `.sobelow-skips` (by line, so they need re-marking when the line moves: `mix sobelow --config --mark-skip-all` after checking that nothing new is among them); the reasons are in `.sobelow-conf`.
- **Credo** findings are fixed, not silenced.

## Tests

Every change comes with tests: resource and action tests through the code interfaces, policy tests with different actors, LiveView tests for pages (against element ids, not text where possible). Two traps:

- **Unique values in async tests:** test modules run in parallel, each in its own transaction; two of them inserting the same value of a unique index wait for each other and can deadlock. Fixtures make unique keys unique themselves (product slugs, GTC dates); tests that create pages with fixed paths use paths of their own. The PostgreSQL log names the other side of a deadlock.
- **Global settings** (application config, the active payment provider) are changed only in tests with `async: false`, and restored exactly afterwards.

## Database changes

Change the resource, then `mix ash.codegen <name>` generates the migration and the snapshot; review the migration, never edit snapshots by hand.

## Translations

`mix gettext.extract --merge` adds new texts. Gettext marks guessed translations as *fuzzy*, and fuzzy entries are ignored at runtime: set every new German text explicitly and remove the flag. A test fails on missing or fuzzy German texts. Texts that mean different things in different places get a context (`pgettext`).

## Documentation

This documentation lives in the repository and is compiled into the app (`Mercator.Docs`):

- `priv/docs/<de|en>/<part>/*.md` for the manual, operating guide, shop help and making-of introduction, with a front matter (`title`, `roles`, `order`, `pages`);
- the design documents and roadmap (`docs/`) and the session logs (`docs/sessions/`) are read where they are.

`pages` in a chapter's front matter names the admin routes whose "?" opens it; a test checks that every admin page has one. Links between the Markdown files (`[Configurator](configurator.md)`) become links between chapters.

Session logs are exported with `scripts/export_session.py latest`, which replaces personal details by the rules in the git-ignored `scripts/session_redactions.local.tsv`.
