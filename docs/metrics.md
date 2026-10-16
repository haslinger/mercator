# Project metrics

A snapshot of the size and shape of the Mercator port. Numbers as of
**2026-10-16** (after commit `2954f97`, the end of phase 10), measured as
described at the end.

## History

| | |
|---|---|
| First commit | 2026-10-13 12:18 |
| Latest commit | 2026-10-16 11:11 |
| Commits | 295 (90 on 10-13, 90 on 10-14, 79 on 10-15, 36 on 10-16) |
| Working sessions (logs in `docs/sessions/`) | 8 (one of two minutes without a log) |
| Working time | **24 h 10 min** active (35 h 8 min from first to last message) |
| Questions decided (`#N`) | #1–#150 |
| Phases | 1–10 done |
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
| `fafce14e` | 2026-10-15 | 11:21 – 17:50 | 6:29 | 3:47 | demo mode, home server deployment, metrics, rate limits, Mollie |
| `5090fc35` | 2026-10-15 | 18:44 – 22:28 | 3:44 | 2:01 | Mollie test, back office payments, backlog, phase 9 documentation |
| `998a2b77` | 2026-10-15 | 22:36 – 22:38 | 0:02 | 0:02 | a question about the help links (no log) |
| `d377cff1` | 2026-10-16 | 07:24 – 11:15 | 3:51 | 3:51 | backlog, LiveDashboard, checkout address dialog, Docker docs, phase 10 video advice |
| **Total** | | | **35:08** | **24:10** | |

## Code size

Line counts include blank lines and comments. LiveView templates are inline
`~H` in `.ex` files, so they are counted under `lib`.

| Area | Files | Lines |
|---|---:|---:|
| `lib/` (Elixir, incl. templates) | 274 | 36,848 |
| ↳ `lib/mercator/` (domains, resources, seeds) | | 17,126 |
| ↳ `lib/mercator_web/` (LiveViews, components, controllers) | | 19,599 |
| `test/` (`.exs` tests + `.ex` support) | 127 | 12,243 |
| Migrations (`priv/repo/migrations/`) | 42 | 2,623 |
| Config (`config/`) | 6 | 728 |
| JavaScript (`assets/js/`, without colocated hooks) | 5 | 616 |
| CSS (`assets/css/`) | 1 | 278 |
| Typst document template (`priv/typst/`) | 1 | 112 |
| Translations (`.po`, de + en) | 6 | 12,039 |
| In-app documentation (`priv/docs/`, de + en) | 59 | 1,759 |
| Documentation (`docs/`, incl. session logs) | 19 | 10,469 |

Without blank lines `lib/` has 32,127 lines; tests are about 33 % of the
application code. The repository tracks 821 files; the demo photos
(`assets/img/`) are 105 MB. (The documentation is written one paragraph per
line, so its line counts say little; see the word counts below.)

## Structure

| | |
|---|---:|
| Ash domains | 6 |
| Ash resources | 35 |
| ↳ Catalog / Sales / Content / Consulting / Accounts / Operations | 13 / 7 / 5 / 5 / 3 / 2 |
| Actions | 204 |
| Attributes | 404 |
| Relationships | 82 |
| Resources with policies | 33 |
| Resources with a state machine | 8 (Category, Product, Order, Page, Conversation, Call, Offer, Incident) |
| Resources with history (AshPaperTrail) | 1 (Page) |
| Database tables | 40 |
| Elixir modules | 355 |
| LiveViews | 42 (22 in the admin area) |
| LiveComponents | 6 |
| Function component modules | 16 |
| Routes | 80 (61 LiveView) |
| Oban workers | 11 (3 cron jobs) |
| Direct dependencies (`mix.exs`) | 45 |

## Video advice (phase 10)

Self-hosted audio, video and screen sharing with Elixir WebRTC, from the
design draft (09:00) to the documented, deployed and tested phase (11:11) in
17 commits on 2026-10-16:

| Part | Lines |
|---|---:|
| Media relay (`Calls.Room`), call API (`Calls`), `Call` resource, watcher | 774 |
| Call area component | 119 |
| Browser side (`call.js`, `ringtone.js`) | 378 |
| Tests (incl. `FakeBrowser`, an ExWebRTC peer playing a browser) | 702 |

## Tests

| | |
|---|---:|
| Tests | 732 |
| Doctests | 16 |
| `describe` blocks | 95 |
| Test files | 118 |
| Full run (`mix test`) | about 40–65 s |

`mix precommit` runs all of them, plus compile with warnings as errors,
format check, Credo `--strict` and Sobelow.

## Translations

| Domain | Messages |
|---|---:|
| `default` (UI) | 1,038 |
| `errors` | 58 |
| `auth` (sign-in pages) | 26 |

German is complete; English uses the msgids, which are English.

## Demo data (seeds)

A clean seed (`Mercator.Seeds.run/0` on an empty database), plus the demo
photos:

| Products | Variants | Categories | Properties | Images | CMS pages | Orders | Conversations (messages) | Calls | Offers | Demo users |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 90 | 136 | 40 | 13 | 130 | 8 | 7 | 5 (34) | 2 | 5 | 7 |

*(The earlier snapshot counted the dev database, which also held data made by
hand: 10 pages, 15 orders, 9 conversations, 12 offers.)*

## Documentation

The documentation compiled into the app (`Mercator.Docs`), counted as shown
there (plain text, without front matter). The session logs as exported during
the work, before the final export of the last session.

| Part | Language | Chapters | Words |
|---|---|---:|---:|
| Back office manual (by role) | de / en | 17 / 17 | 4,099 / 4,293 |
| Operating guide | de / en | 6 / 6 | 1,608 / 1,716 |
| Shop help | de / en | 5 / 5 | 1,142 / 1,218 |
| Developers: overview and workflow | en | 2 | 853 |
| Developers: design documents and roadmap | en | 10 | 18,779 |
| Making-of: introduction and metrics | en | 2 | 901 |
| Making-of: session logs | en | 7 | 87,640 |
| **Total** | | **77** | **122,249** |

About 350 printed pages at 350 words each, nearly three quarters of it the
session logs. Every admin page (27 routes) has a manual chapter behind its "?".

## Compared with the Rails original

The Rails/Hobo shop (`mercator-src/mercator`), for orientation only. It also
contains parts that are not ported (ERP, Icecat and Bechlem integrations,
importer), and Hobo generates much of its UI.

| | Rails/Hobo (2013–2017) | Phoenix/Ash (2026) |
|---|---:|---:|
| Commits | 1,947 over 4 years | 295 over 4 days |
| Models / resources | 53 | 35 |
| Model code | 4,715 | 17,126 (`lib/mercator/`, incl. seeds) |
| Controllers, views (incl. DRYML), JS | 17,303 | 20,493 (`lib/mercator_web/`, JS, CSS) |
| Test code | 33,763 (`spec/`) | 12,243 |

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
# LiveViews and LiveComponents: the app's modules by their __live__ kind
{:ok, mods} = :application.get_key(:mercator, :modules)
Enum.count(mods, &(function_exported?(&1, :__live__, 0) and &1.__live__()[:kind] == :view))
```

Demo data counts come from a test that runs `Mercator.Seeds.run/0` in the
sandbox and counts the tables (rolled back afterwards); the images from the
dev database after `mix run priv/repo/seeds.exs`.

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
