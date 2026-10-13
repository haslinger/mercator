# Mercator

Guided-selling web shop with a CMS: a port of the Rails/Hobo app "Mercator" to **Elixir / Phoenix 1.8 / Ash 3 / LiveView / DaisyUI 5 (Tailwind 4)** on PostgreSQL.

- Goal: a **generic product**, deployed as **one deployment per customer** (single tenant). Customer specifics come from runtime config, a DaisyUI theme and optional modules. See `docs/roadmap.md`.
- The plan, decisions and open questions live in [docs/roadmap.md](docs/roadmap.md). Questions are numbered globally (`#N`) and the numbering is never restarted.

@AGENTS.md

## Overrides to AGENTS.md

- **Use DaisyUI** components and themes; this is a project decision. Ignore the generated advice to avoid daisyUI. Tailwind utilities are fine on top.
- The UI is **LiveView-first**. Plain controllers are only for things like file downloads, payment callbacks and feeds.

## Toolchain

- asdf, always the latest stable versions, pinned in `.tool-versions` (currently Erlang 29.1.1, Elixir 1.20.4-otp-29).
- Run `mix precommit` before committing: compile with warnings as errors, format, **Credo `--strict`**, tests. Fix Credo findings; don't silence them without a reason.
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
| i18n YAML | Gettext. Locales are `de` (default) and `en`. |
| `Constant` key/value table | Typed runtime config where possible; a DB settings resource only for settings editable at runtime |

- Domains are planned roughly as Accounts, Catalog, Sales (orders/basket), Consulting (conversations/offers), Content (CMS) and Contracting. Agree on any new domain before adding it.
- Money and VAT: use `Decimal` (`:decimal` attributes), never floats.
- Generate migrations with `mix ash.codegen <name>` and review them. Never hand-edit resource snapshots.

## Testing

- **Always ship tests with new code**: resource/action tests (calling actions through the domain code interface), policy tests with different actors, and LiveView tests for pages.
- `mix test` must be green before committing. Report failures honestly.

## Working agreements

- The user runs the dev server (`mix phx.server`, port 4000) themselves. Don't start your own; ask the user to start or restart it when needed.
- Ask before installing software, adding infrastructure or creating long-lived setups.
- Questions and suggestions are welcome; number open questions (`#N`) and keep `docs/roadmap.md` up to date when decisions are made.
- **Commit often:** after each coherent, green step (`mix precommit` passes), with a descriptive message. Don't let changes pile up.
