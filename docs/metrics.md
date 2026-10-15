# Project metrics

A snapshot of the size and shape of the Mercator port. Numbers as of
**2026-10-15** (after commit `7ca6fce`), measured as described at the end.

## History

| | |
|---|---|
| First commit | 2026-10-13 12:18 |
| Latest commit | 2026-10-15 13:15 |
| Commits | 219 (90 on 10-13, 90 on 10-14, 39 on 10-15) |
| Working sessions (logs in `docs/sessions/`) | 5 |
| Working time | **16 h 37 min** active (23 h 10 min from first to last message) |
| Questions decided (`#N`) | #1–#120 |
| Phases | 1–6 and 8 done, 7 (online payment) in progress |
| Demo | live at https://biber.mittenin.at since 2026-10-15 |

## Work sessions

From the timestamps of the Claude Code transcripts (local time). *Active*
counts the time between messages, leaving out pauses longer than 15 minutes.

| Session | Date | From – to | Span | Active | Main topics |
|---|---|---|---:|---:|---|
| `2a53ba5b` | 2026-10-13 | 11:57 – 18:52 | 6:55 | 5:36 | analysis of the Rails app, roadmap, foundation, catalogue, checkout (first steps) |
| `87be7c65` | 2026-10-13 | 19:13 – 19:19 | 0:05 | 0:05 | setting up the session log export |
| `3c7d3d68` | 2026-10-14 | 08:15 – 19:30 | 11:14 | 6:00 | checkout completion, CMS, guided selling (chat, offers, emails, print) |
| `4c06f629` | 2026-10-15 | 06:26 – 09:15 | 2:48 | 2:48 | backlog, incidents, online payment, Docker |
| `fafce14e` | 2026-10-15 | 11:21 – 13:27 | 2:05 | 2:05 | demo mode, home server deployment, metrics |
| **Total** | | | **23:10** | **16:37** | |

## Code size

Line counts include blank lines and comments. LiveView templates are inline
`~H` in `.ex` files, so they are counted under `lib`.

| Area | Files | Lines |
|---|---:|---:|
| `lib/` (Elixir, incl. templates) | 256 | 33,463 |
| ↳ `lib/mercator/` (domains, resources, seeds) | | 15,368 |
| ↳ `lib/mercator_web/` (LiveViews, components, controllers) | | 18,063 |
| `test/` (`.exs` tests + `.ex` support) | 110 | 10,192 |
| Migrations (`priv/repo/migrations/`) | 40 | 2,540 |
| Config (`config/`) | 6 | 677 |
| JavaScript (`assets/js/`, without colocated hooks) | 3 | 236 |
| CSS (`assets/css/`) | 1 | 257 |
| Typst document template (`priv/typst/`) | 1 | 112 |
| Translations (`.po`, de + en) | 6 | 11,113 |
| Documentation (`docs/`, incl. session logs) | 14 | 7,670 |

Without blank lines `lib/` has 29,221 lines; tests are about 30 % of the
application code. The repository tracks 717 files; the demo photos
(`assets/img/`) are 105 MB.

## Structure

| | |
|---|---:|
| Ash domains | 6 |
| Ash resources | 34 |
| ↳ Catalog / Sales / Content / Consulting / Accounts / Operations | 13 / 7 / 5 / 4 / 3 / 2 |
| Actions | 199 |
| Attributes | 393 |
| Relationships | 80 |
| Resources with policies | 32 |
| Resources with a state machine | 7 (Category, Product, Order, Page, Conversation, Offer, Incident) |
| Resources with history (AshPaperTrail) | 1 (Page) |
| Database tables | 39 |
| Elixir modules | 336 |
| LiveViews | 45 (26 in the admin area) |
| LiveComponents | 6 |
| Function component modules | 13 |
| Routes | 73 (55 LiveView) |
| Oban workers | 10 (3 cron jobs) |
| Direct dependencies (`mix.exs`) | 42 |

## Tests

| | |
|---|---:|
| Tests | 608 |
| Doctests | 13 |
| `describe` blocks | 78 |
| Test files | 103 |
| Full run (`mix test`) | about 35–45 s |

`mix precommit` runs all of them, plus compile with warnings as errors,
format check, Credo `--strict` and Sobelow.

## Translations

| Domain | Messages |
|---|---:|
| `default` (UI) | 953 |
| `errors` | 58 |
| `auth` (sign-in pages) | 26 |

German is complete; English uses the msgids, which are English.

## Demo data (seeds)

| Products | Variants | Categories | Properties | Images | CMS pages | Orders | Conversations (messages) | Offers | Demo users |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 90 | 136 | 40 | 13 | 130 | 10 | 15 | 9 (52) | 12 | 7 |

## Documentation

Phase 9, as of commit `8cd6127`: the documentation compiled into the app
(`Mercator.Docs`), counted as shown there (plain text, without front matter).

| Part | Language | Chapters | Words |
|---|---|---:|---:|
| Back office manual (by role) | de / en | 16 / 16 | 3,671 / 3,845 |
| Operating guide | de / en | 5 / 5 | 822 / 891 |
| Shop help | de / en | 5 / 5 | 1,019 / 1,083 |
| Developers: overview and workflow | en | 2 | 822 |
| Developers: design documents and roadmap | en | 9 | 15,493 |
| Making-of: introduction and metrics | en | 2 | 724 |
| Making-of: session logs | en | 6 | 75,868 |
| **Total** | | **71** | **104,238** |

About 300 printed pages at 350 words each, three quarters of it the session
logs. Written for the app in phase 9: 12,153 words (manual, operating guide,
shop help and developer overview in both languages); the design documents,
roadmap and session logs grew along with the work and are shown as they are.
Every admin page (27 routes) has a manual chapter behind its "?".

## Compared with the Rails original

The Rails/Hobo shop (`mercator-src/mercator`), for orientation only. It also
contains parts that are not ported (ERP, Icecat and Bechlem integrations,
importer), and Hobo generates much of its UI.

| | Rails/Hobo (2013–2017) | Phoenix/Ash (2026) |
|---|---:|---:|
| Commits | 1,947 over 4 years | 219 over 3 days |
| Models / resources | 53 | 34 |
| Model code | 4,715 | 15,368 (`lib/mercator/`, incl. seeds) |
| Controllers, views (incl. DRYML), JS | 17,303 | 18,556 (`lib/mercator_web/`, JS, CSS) |
| Test code | 33,763 (`spec/`) | 10,192 |

## How measured

```sh
git rev-list --count HEAD                                  # commits
git log --format=%ad --date=short | sort | uniq -c         # commits per day
find lib -name '*.ex' | xargs cat | wc -l                  # lines (same for other dirs)
grep -rE '^\s*test "' test | wc -l                         # tests
grep -c '^msgid' priv/gettext/*.pot                        # messages (+1 header each)
```

The Ash numbers come from introspection in the running app (Tidewave
`project_eval` or `iex -S mix`):

```elixir
domains = Application.get_env(:mercator, :ash_domains)
resources = Enum.flat_map(domains, &Ash.Domain.Info.resources/1)
length(resources)
resources |> Enum.flat_map(&Ash.Resource.Info.actions/1) |> length()
Phoenix.Router.routes(MercatorWeb.Router) |> length()
```

Demo data counts are from the dev database after `mix run priv/repo/seeds.exs`.

The documentation numbers come from `Mercator.Docs` (words of each chapter's
plain text, chapters in their own language only):

```elixir
admin = %{roles: [:administrator]}
for part <- Mercator.Docs.parts(), locale <- ["de", "en"] do
  chapters = part |> Mercator.Docs.chapters(locale, admin) |> Enum.filter(&(&1.locale == locale))
  {part, locale, length(chapters), chapters |> Enum.map(&length(String.split(&1.text))) |> Enum.sum()}
end
```

Session durations come from the `timestamp` of every entry in the transcripts
(`~/.claude/projects/<project>/*.jsonl`): the span is first
to last entry; active time sums the gaps between consecutive entries that are
at most 15 minutes long.
