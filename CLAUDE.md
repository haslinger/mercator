# Mercator

Guided-selling web shop with a CMS: a port of the Rails/Hobo app "Mercator" to **Elixir / Phoenix 1.8 / Ash 3 / LiveView / DaisyUI 5 (Tailwind 4)** on PostgreSQL.

- Goal: a **generic product**, deployed as **one deployment per customer** (single tenant). Customer specifics come from runtime config, a DaisyUI theme and optional modules. See `docs/roadmap-future.md`.
- The plan lives in [docs/roadmap-future.md](docs/roadmap-future.md) (what is to be done and decided) and [docs/roadmap-history.md](docs/roadmap-history.md) (what is done and decided). Questions are numbered globally (`#N`) and the numbering is never restarted.

@AGENTS.md

## Overrides to AGENTS.md

- **Use DaisyUI** components and themes; this is a project decision. Ignore the generated advice to avoid daisyUI. Tailwind utilities are fine on top.
- The UI is **LiveView-first**. Plain controllers are only for things like file downloads, payment callbacks and feeds.

## Toolchain

- asdf (not mise), always the latest stable versions, pinned in `.tool-versions` (currently Erlang 29.1.1, Elixir 1.20.4-otp-29). Check with `asdf latest erlang` / `asdf latest elixir` and pick the Elixir build matching the Erlang major. The parent dir's `.tool-versions` pins older versions; the project file overrides it.- Run `mix precommit` before committing: compile with warnings as errors, format, **Credo `--strict`**, tests. Fix Credo findings; don't silence them without a reason.
- Dev DB: local PostgreSQL with `postgres`/`postgres` (`mercator_dev`, `mercator_test`). Use `mix ash.setup` to create and migrate.
- **Tidewave MCP** (dev only) runs at `http://localhost:4000/tidewave/mcp` and is registered in `.mcp.json`. It needs a running `mix phx.server`. Use it for logs, `project_eval`, SQL and docs. After changing deps or config, the server must be restarted.

## Rails reference sources (read-only)

- `/daten/DATA/rails/mercator-src/mercator`: the shop (Rails 4.2 + Hobo 2.2). Models are in `app/models`; Hobo declares columns inline in `fields do … end` blocks, and there is no `schema.rb`.
- `/daten/DATA/rails/mercator-src/mercator.wiki`: German documentation, including a sales-process diagram and an interfaces diagram in `images/`.
- `/daten/DATA/rails/mercator-src/systems/*`: old per-customer configs, kept for **reference only**.
- These will **not** be ported: the Mesonic ERP, Icecat and Bechlem integrations, the legacy importer and the miranda shop. mPAY24 will be replaced by a payment provider chosen later.
- No data migration. We build **seed/dummy data** in `priv/repo/seeds.exs` and keep it growing alongside each feature.

## Porting conventions (Rails/Hobo → Ash)

Translate concepts into idiomatic Ash rather than copying Rails patterns one-to-one:

| Rails / Hobo | Here |
|---|---|
| model + `fields do` | Ash resource with AshPostgres, inside a domain (`Mercator.<Domain>`) |
| Hobo `lifecycle` | `AshStateMachine` (states/transitions) plus update actions per transition |
| `*_permitted?` | Ash policies; the actor is the current user. Roles: administrator, sales, sales_manager, contentmanager, productmanager |
| `has_paper_trail` | `AshPaperTrail`, only where history matters (see #22) |
| `acts_as_list` | `position` attribute plus explicit reorder actions |
| `ancestry` trees | `parent_id` plus recursive queries (or `ltree`; decide per case) |
| delayed_job / cron | Oban workers / Oban cron |
| private_pub / Faye | Phoenix PubSub + LiveView |
| DRYML taglibs | Function components |
| i18n YAML (UI texts) | Gettext. Locales are `de` (default) and `en`. |
| traco `name_de`/`name_en` (content) | **One JSONB map attribute** per translatable field (`%{"de" => …, "en" => …}`), plus a locale calculation with `de` fallback; per-language full-text indexes (#7) |
| `Constant` key/value table | Typed runtime config where possible; a DB settings resource only for settings editable at runtime |

- Domains: Accounts, Catalog, Sales (orders/basket), Consulting (conversations/offers) and Content (CMS); no Contracting (#19). Agree on any new domain before adding it.
- Money and VAT: use `Decimal` (`:decimal` attributes), never floats.
- Generate migrations with `mix ash.codegen <name>` and review them. Never hand-edit resource snapshots.

## Usage rules

- Maintainers' rules for agents are synced by `usage_rules` (config in `mix.exs`, run `mix usage_rules.sync --yes` after dependency updates; it is interactive without `--yes`). Elixir/OTP and Phoenix rules are inlined in `AGENTS.md`; Ash, AshPostgres and AshPhoenix rules are in the **`ash-framework` skill** (`.claude/skills/`). Consult that skill for any Ash work.
- `ash_authentication` is only an indirect dependency, so it isn't synced. For authentication work, read `deps/ash_authentication/usage-rules.md`.
- Search the docs of dependencies with `mix usage_rules.search_docs "term" -p <package>`.

## Testing

- **Always ship tests with new code**: resource/action tests (calling actions through the domain code interface), policy tests with different actors, and LiveView tests for pages.
- `mix test` must be green before committing. Report failures honestly.

## Working agreements

- The user runs the dev server (`mix phx.server`, port 4000) themselves. Don't start your own; ask the user to start or restart it when needed.
  - If the server isn't reachable on port 4000, ask the user to start it. Before relying on the running app, check that the port responds.
  - After changing `application/0` in `mix.exs` while the server runs, the old server can rewrite `_build/dev/lib/mercator/ebin/mercator.app` and the change is silently missing. Fix: stop the server, run `touch mix.exs`, restart. To verify, grep the `.app` file.
  - Don't run `mix compile --force` while the user's server runs (it holds the build lock).
- Ask before installing software, adding infrastructure or creating long-lived setups, including clones or checkouts in the scratchpad. Propose the location and method first. For material needed repeatedly, propose a proper permanent setup.
- Questions and suggestions are welcome; propose idiomatic Phoenix/Ash/DaisyUI designs instead of copying Rails/Hobo/Bootstrap patterns.
- **Numbered questions:** number every open question `#N`, continuing across messages and sessions (the user answers with "#3 yes"). The last used number is kept in `docs/roadmap-future.md` under "Open questions"; update it when asking. Move answered questions to the history as decisions.
- **Commit often:** after each coherent, green step (`mix precommit` passes), with a descriptive message, without asking first. Tell the user the commit hash. Run the full `mix precommit` before every code commit, even small ones.
- **Check the precommit exit code explicitly.** Never pipe it or chain it with `;` or `grep … &&` into `git commit` (this let failing commits through three times). Use:
  `mix precommit > log 2>&1; status=$?; …; if [ $status -eq 0 ]; then git commit …; fi`
- Always quote shell heredocs (`<<'EOF'`) for scripts and commit messages; unquoted ones run backtick text as commands. Pass shell values to Python via argv, not `$VAR` interpolation.
- **Handover folder:** the user drops files for Claude (screenshots etc.) into `assets/handover/` (git-ignored). Look there when they mention a screenshot. Never commit its contents.
- **Session logs:** when a session wraps up ("enough for today" etc.), export it with `scripts/export_session.py latest` into `docs/sessions/` and commit it. Re-exporting overwrites the same file. The logs are published as the making-of: the script applies redaction rules (general ones in the script, personal ones in the git-ignored `scripts/session_redactions.local.tsv`) and prints the replacements. Read the new log for personal asides, credentials or infrastructure details the rules miss, and add rules for them. Never paste full push endpoints or VAPID private keys into the chat.
- Commands in docs that leave state on a server (firewall rules etc.) carry a comment naming their purpose, e.g. `ufw … comment mercator-calling`.

## Known pitfalls

- **Gettext fuzzy entries:** `mix gettext.merge` marks new msgids that resemble existing ones as `#, fuzzy`, and Gettext ignores them at runtime (silent English fallback). After every merge, strip fuzzy marks in **all** locales. `test/mercator_web/gettext_test.exs` fails on fuzzy or untranslated German entries.
  - The same msgid in two contexts needs `pgettext` (shop `pgettext("shop navigation", "Products")` → "Sortiment", admin "Products" → "Produkte").
  - After editing a `.po` file, the dev build can keep the old translations (Mix compares contents, so `touch` doesn't help). Fix: change the content of `gettext.ex` (add and remove a blank line), run `mix compile`, reload.
- **LiveView `_unused_` params:** form events contain `_unused_<name>` keys for untouched inputs. AshPhoenix forms ignore them, but params handled by hand (e.g. `highlights[de]` in the product editor) must be filtered to known keys (`Map.take(params, Translated.locales())`), or saving breaks. Test with `render_change` including `_unused_` keys. Flash an error when a submit fails without visible field errors.
- **Parallel tests and unique keys:** async test modules that insert the same value into a unique column (e.g. page path `ueber-uns`) can deadlock in Postgres (40P01). Give each test module its own slugs/titles; fixtures make unique keys unique themselves. To find the other side of a deadlock, read `/var/log/postgresql/postgresql-18-main.log` ("deadlock detected").
- **Presence tests** must wait for the `presence_diff` broadcast.
- **Postgres German locale:** the local server reports errors as "FEHLER". AshPostgres only recognises its own `ash_error` raises with severity "ERROR", so `config/config.exs` sets `parameters: [lc_messages: "C"]` on the repo. If Ash errors show up as raw Postgrex `ash_error` / UnknownError, check `lc_messages` first.
- **Tidewave browser:** `browser_eval` drives the user's own tab and only works while they have `http://localhost:4000/tidewave` open (call `help` first for the current session id; if "No browser is connected", ask them to reopen it). Use it to verify layouts after UI changes, then set the viewport back to 1280×900.
  - If the MCP connection failed at session start, POST JSON-RPC `tools/call` to `http://localhost:4000/tidewave/mcp` directly (headers `content-type: application/json`, `accept: application/json, text/event-stream`).
  - Sign the tab in via `#user-password-sign-in-with-password`; the demo password is `mercator-demo`. `/sign-out` is a confirmation page.
  - Rendering glitches and a `page-scanner-*.js` console error that only appear inside the Tidewave page are Tidewave's own. Camera and microphone don't work in its frame: test calls in a normal tab. The user's browser is Firefox at a non-100 % zoom.
  - A stale tab after many live reloads can ignore new hooks: reload first.
- Headless Chrome via CDP (a node script in the scratchpad) works for checking client JS. Never `pkill -f` a pattern that appears in your own command line.

## Demo: Biber Holz

The demo deployment is the fictitious customer **Biber Holz** ("Österreichische Alpen-Forstwirtschaft · Seit 1928 · Qualitäts-Bau- und Edelholz", Waldweg 1, 3914 Waldhausen). It is one deployment's branding and seed data (`BRAND=biberholz`); Mercator itself stays generic.

- Wood-themed range from complete wooden houses to sawdust: the use case for **configurable material** (wood species, dimensions, surface, drying, units like m³, lfm, m², Festmeter, Raummeter).
- Logo palette: cream `#efd7ab`, walnut `#67482d`, oak/bronze `#be9e73`, dark `#180d06`, plus forest-green accents. Brand files are in `priv/static/images/brands/biberholz/`. Source images in `assets/img/` stay in git on purpose: don't suggest Git LFS or moving them out.
- Demo people get German surnames of forest animals (Specht, Fuchs, Hirsch, Eichhorn, Dachs, Luchs, Igel, …). Keep this style for new demo persons.
- Demo VAT (#51): firewood, pellets and Christmas trees 13 %; everything else 20 %, including saw logs not sold as fuel. Briquettes, wood chips and sawdust as fuel at 13 % is an unconfirmed assumption.
- Contact data in the imprint is invalid on purpose (postcode 0000, +43 000 1234567); Informatom is named as operator. The website shows `service@example.com`; demo users keep `@mittenin.at` addresses because their emails must arrive.
- **Live at https://biber.mittenin.at** (the user's home server, docker compose, see `DOCKER.md`). Claude has no access to the server: give the user commands to run. Never suggest `docker compose down -v` or `docker volume prune` (deletes DB and uploads). Rollback tag is `mercator:previous`.
- Seeds don't overwrite existing pages: content changes reach the demo through the nightly reset (03:00) after a redeploy. `DEMO_KEEP_ACCOUNTS` (comma-separated emails in `.env`) keeps those accounts, sign-ins and push subscriptions through the reset.

## Related project: qed

The CMS was **copied and adapted** (no library, no umbrella) into `/daten/DATA/phoenix/qed`, a static site generator for podcasts (Ash with AshSqlite). The handover is `docs/cms-handover-qed.md`. If Mercator's CMS changes in a way that matters for the port, offer to update it. qed has its own question numbering, separate from Mercator's `#N`.
