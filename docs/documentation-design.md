# Documentation (phase 9) – design

Agreed 2026-10-15. Decisions: #121 four audiences (shop owner and staff, operators,
developers, shop visitors); #122 Markdown in the repo, versioned with the code; #123
German and English, German first, German fallback; #124 "Hilfe" in the admin area with
table of contents, search and "?" links per page, filtered by role; #125 shop help at
`/help`, operator and developer chapters for administrators only; #131 the session logs
are cleaned of personal details; #132 a public "making-of" in the demo; #133 the
making-of stays English only.

## 1. Goals

- Every deployment documents exactly the version it runs: the documentation ships with
  the code, nothing is seeded or migrated.
- One source per text: manuals are written once in `priv/docs/`, the existing developer
  documents (`docs/*-design.md`) and the session logs (`docs/sessions/`) are used where
  they are, not copied.
- Broken documentation (missing title, unknown chapter in a "?" link) fails the build
  or a test, not a visitor's page.
- The making-of shows how Mercator was ported with AI: the cleaned session logs and the
  project metrics, so the story can be checked.

## 2. Sources

| Part | Source | Audience | Languages |
|---|---|---|---|
| Back office manual | `priv/docs/<locale>/manual/*.md` | staff, by role | de, en |
| Operating | `priv/docs/<locale>/operating/*.md` (from `DOCKER.md`) | administrators | de, en |
| Developers | `docs/*-design.md`, `docs/roadmap-*.md`, an overview page in `priv/docs/` | administrators | en |
| Shop help | `priv/docs/<locale>/help/*.md` | everybody (`/help`) | de, en |
| Making-of | `docs/sessions/*.md`, `docs/metrics.md`, an introduction in `priv/docs/` | everybody (`/making-of`, if enabled) | en (#133) |

Pages in `priv/docs/` start with a short header (front matter):

```markdown
---
title: Bestellungen bearbeiten
roles: [sales, sales_manager]
order: 30
pages: [admin/orders, admin/orders/:number]
---
```

`pages` names the admin routes whose "?" opens this chapter. Developer documents and
session logs need no header: their title is the first heading, their place is fixed by
the part they belong to (sessions by date).

## 3. Compiled in: `Mercator.Docs`

A module reads all sources **at compile time**, registers each file as an
`@external_resource` (editing one recompiles the module, also in dev), renders the
Markdown with `MercatorWeb.Markdown` and keeps for each chapter: part, slug, locale,
title, roles, order, admin pages, HTML, table of contents (headings) and plain text for
the search. Functions:

- `chapters(part, locale, actor)` – the table of contents, filtered by role, with
  German fallback per chapter
- `chapter(part, slug, locale)` – one chapter
- `for_page(route)` – the chapter for an admin page's "?"
- `search(query, locale, actor)` – chapters whose text matches, with a snippet

Why not the alternatives: seeding into the CMS creates editable copies that drift from
the code version (the CMS stays for customer-specific content, #125); reading the files
at runtime would need `docs/` in the release and shows errors only when a page is
opened. The Docker build copies `docs/` into the build stage (it is not in the release:
the content is compiled into the module).

## 4. Pages

- **Admin area** `/admin/help` (all staff): sidebar entry "Hilfe", table of contents by
  part, search, chapter pages with their own table of contents. Operators' and
  developers' parts only for administrators (#125). A "?" in the page header of each
  admin page links to its chapter (`for_page/1`); a test checks that every admin route
  with a "?" has a chapter.
- **Shop** `/help`: the shop help in the shop layout, linked from the footer, the
  checkout and the chat.
- **Making-of** `/making-of`: an introduction (what was ported, how, by whom: one person
  with Claude Code), the metrics, then one page per session with the conversation.
  Enabled per deployment (`config :mercator, :making_of, true`, set in demo mode);
  otherwise the routes answer 404 and nothing links to them.

## 5. Cleaning the session logs (#131)

Removed from `docs/sessions/*.md`: the user's name, infrastructure details of the home
server (host name, router, firewall, ports, local paths) and personal asides. Kept:
the public demo domain and demo accounts (the demo password is public anyway).

1. A one-time review of all existing logs, read in full (a word search does not find
   personal asides), with the replacements committed.
2. The same rules in `scripts/export_session.py` (a list of replacements), so future
   exports come out clean; the export prints what it replaced.
3. Earlier versions stay in the git history; that matters only if the repository is
   made public.

## 6. Steps (one commit each, with tests)

1. ~~Clean the session logs and extend the export script~~ *(done 2026-10-15)*.
2. ~~`Mercator.Docs` (compile-time loading, front matter, rendering, search) with tests~~
   *(done 2026-10-15; starter pages for every part in `priv/docs/`)*.
3. Admin "Hilfe" (table of contents, chapter, search, role filter) and the "?" links.
4. Shop `/help` and the links from footer, checkout and chat.
5. Making-of (`/making-of`, introduction, metrics, sessions; demo only).
6. Content: back office manual by role, operating (from `DOCKER.md`), developer
   overview, shop help, in German and English. The largest step, possibly split.
