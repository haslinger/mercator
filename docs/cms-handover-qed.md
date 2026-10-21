# Porting the Mercator CMS to qed

Handover written in the Mercator project on 2026-10-21, for a coding agent working in `/daten/DATA/phoenix/qed`.

## 1. Decision and goal

- The CMS is **copied and adapted**, not extracted into a shared library. The two apps differ too much (Postgres vs SQLite, one live site vs many static sites).
- Mercator (`/daten/DATA/phoenix/mercator`) is a **read-only reference**. Don't change it from the qed session.
- What qed needs: per podcast, editable site pages built from blocks. That covers the **landing page**, About, Imprint, Contributors and a **blog**. These pages are rendered into the **static site** together with the episodes (qed backlog #026).
- Background: `docs/cms-design.md` in Mercator (decisions #76–#93). Mercator's question numbers are not qed's; give new qed questions qed backlog numbers.

## 2. How the CMS works

**A page is an ordered list of typed blocks.** Editors pick and arrange blocks; they never write markup or templates. New block types are added in code.

- **Blocks** are an Ash union type (`Content.Block`, `storage: :map_with_tag`, tag key `"type"`). Each member is an embedded resource in `content/blocks/*.ex` and has its own `id`. The blocks are stored **embedded in the page** as one JSON array, not in a table of their own. So one version is the whole page, and history and restore stay simple.
- **Working copy and publish:** `title`, `seo_description` and `blocks` are the working copy. The `publish` action copies them into `published` (embedded `PageContent`), which is what visitors see. `changes_pending` is set whenever the working copy changes. `discard_changes` copies `published` back.
- **History:** AshPaperTrail in `:snapshot` mode, recording **only on `publish`**. `restore_version` copies a version into the working copy (not straight to published).
- **States** (AshStateMachine): `draft` (never published, staff only) → `published` / `hidden` (reachable by URL, not in menus) → `archived`. Only drafts can be deleted; anything else is archived. Pages below an offline page are offline too (`Content.reachable?/2`).
- **Tree:** `parent_id` + `position`, plus a materialised `path` made from the slugs (`ueber-uns/team`). `SetPagePath` keeps the paths of the page and all its descendants up to date, and writes a `PageRedirect` for each old path.
- **Kind `shared`:** a page whose blocks other pages embed through a `Shared` block (e.g. opening hours). It has the same working copy, publishing and history, but no URL of its own and isn't in menus.
- **`key`:** a stable handle the code links to (`home` = start page, `imprint`, `privacy`). `make_start_page` moves the `home` key from one page to another.
- **`menu`:** `:none | :main | :footer`, plus an optional Heroicon per page.
- **Media library (`Asset`):** images are converted with `image` (libvips) to WebP in the sizes `wide`/`large`/`thumb`; PDFs are kept as uploaded. Each asset has at least one tag and can be found by search. Blocks reference assets by `image_id` / `image_ids` / `document_id`. `Blocks.asset_ids/1` collects them, so a page loads all its assets with one query. An asset still used by a page can't be deleted.
- **Rendering:** `MercatorWeb.ContentComponents.block/1` has one function clause per block type. Data a block needs beyond its own fields (assets, products) is loaded **up front** by `MercatorWeb.BlockData.load/1` and passed in as `data`. Components never query.
- **Markdown** is used for every longer text: MDEx (raw HTML escaped, sanitized) in `MercatorWeb.Markdown`. The editor is OverType, self-hosted in `priv/static/overtype` and wrapped in the `MarkdownEditor` hook.

## 3. File map (paths relative to the Mercator root)

### Domain: `lib/mercator/content*`

| File | Purpose | For qed |
|---|---|---|
| `content.ex` | Domain, code interface, tree helpers (`place_page`, `ancestor_paths`, `reachable?`, `published_children`, `assets_for_blocks`) | **Adapt** (scope by podcast) |
| `content/page.ex` | Page resource: actions, states, paper trail, policies | **Adapt** |
| `content/page_content.ex` | Embedded published copy | Keep |
| `content/block.ex`, `content/blocks.ex` | Block union and helpers (`types`, `to_input`, `new`, `put`, `move`, `delete`, `asset_ids`) | Keep; change the list of types |
| `content/blocks/{text,hero,text_image,image,gallery,download,columns,column,faq,faq_item,call_to_action,shared}.ex` | Generic blocks | Keep |
| `content/blocks/{products,categories}.ex` | Shop blocks | **Drop**; replace with qed blocks (§5) |
| `content/blocks/{contact_form,contact_options}.ex` | Contact form, call/chat/video | **Drop** (a static site has no server) |
| `content/changes/publish.ex`, `discard_changes.ex`, `restore_version.ex`, `make_start_page.ex` | Lifecycle | Keep |
| `content/changes/set_page_path.ex` | Paths and redirects, **raw Postgres SQL** | **Rewrite** (§4) |
| `content/page_redirect.ex` | Old paths → page | Keep the idea; on a static site redirects become files (§5) |
| `content/asset.ex`, `changes/store_asset.ex`, `changes/normalize_tags.ex`, `validations/asset_unused.ex` | Media library | **Adapt**: drop `upload_for_chat`, `library` and the office flag; rewrite the SQL (§4) |
| `content/file_types.ex` | Office/CAD files in chats | Drop |
| `content/submission.ex`, `content/workers/send_submission.ex` | Contact form entries | Drop |

### Helpers outside the Content domain

| File | Purpose | For qed |
|---|---|---|
| `lib/mercator/translated.ex` | JSONB map per locale (`%{"de" => …, "en" => …}`) | **Drop**: a qed podcast has one `language`; use plain `:string` |
| `lib/mercator/uploads.ex` | Upload root directory, `url/1`, `resolve/1` (path traversal protection) | Copy or merge with qed's storage (qed backlog #001) |
| `lib/mercator/catalog/image_processing.ex` | libvips resizing to WebP | Copy (also useful for cover art, qed backlog #033) |
| `lib/mercator/catalog/slug.ex`, `catalog/changes/set_slug.ex` | Slugs | Copy; qed may already have its own slug code |
| `lib/mercator/accounts/checks/actor_has_role.ex` | Role check | Replace with `Qed.Podcasts.Checks.PodcastRole` |
| `lib/mercator/seeds/pages.ex` | Demo pages | Use as an example for qed seeds |

### Web

| File | Purpose | For qed |
|---|---|---|
| `lib/mercator_web/components/content_components.ex` | Block rendering (DaisyUI) | **Adapt** for static output (§5) |
| `lib/mercator_web/block_data.ex` | Loads what blocks need | Adapt: assets plus qed data (episodes, posts) |
| `lib/mercator_web/markdown.ex`, `components/markdown_components.ex` | Markdown rendering and editor input | Copy as is (also covers qed backlog #022, shownotes) |
| `lib/mercator_web/live/admin/page_tree_live.ex` | Tree with drag and drop, "new page" | Adapt (per podcast) |
| `lib/mercator_web/live/admin/page_edit_live.ex` (950 lines) | Settings, block list, block editor, asset picker, publish/history | Adapt; the largest piece |
| `lib/mercator_web/live/admin/page_components.ex` | State badge, menu options, icon picker | Copy |
| `lib/mercator_web/live/admin/media_live.ex` | Media library (upload, tags, search) | Adapt (per podcast) |
| `lib/mercator_web/live/page_live.ex`, `plugs/page_redirect.ex`, `seo.ex`, `controllers/sitemap_controller.ex` | Public pages served live | Not needed as LiveViews; the ideas move into the site generator (§5) |
| `assets/js/hooks/sortable.js` + `assets/vendor/sortable.esm.js` | SortableJS hook for flat and nested lists | Copy and register in `app.js` |
| `assets/js/hooks/markdown_editor.js` + `priv/static/overtype/` | Editor | Copy; if qed has a CSP, allow `/overtype` from `'self'` |

### Tests to port alongside

`test/mercator/content/page_test.exs`, `asset_test.exs`, `test/mercator_web/live/admin/page_admin_live_test.exs`, `media_live_test.exs`, `page_components_test.exs`, `start_page_test.exs`, `test/mercator/seeds/pages_test.exs`.

## 4. Postgres-specific code (qed uses AshSqlite)

| Where | What | SQLite replacement |
|---|---|---|
| `set_page_path.ex` | `UPDATE … RETURNING`, `gen_random_uuid()`, `= ANY($3)`, `ON CONFLICT … DO UPDATE`, `now() AT TIME ZONE` | Prefer Ash: read the descendants (`path LIKE old || '/%'`), update each one, upsert redirects with an identity + `upsert?`. Page trees are small. |
| `asset_unused.ex` | `blocks::text LIKE '%id%'` | Load the podcast's pages and use `Blocks.asset_ids/1` on `blocks` and `published.blocks` |
| `asset.ex` `:search` | `->>`, `ILIKE`, `array_to_string`, GIN index on `tags` | Without translations: filter `contains(title, ^q)` / `original_filename`; filter tags in Elixir, or keep tags as a JSON array and match in Elixir (libraries are small) |
| `content.ex` `asset_tags/0` | `unnest(tags)` | Read the assets and `Enum.flat_map(& &1.tags) \|> Enum.uniq() \|> Enum.sort()` |
| `postgres do … references` | `on_delete: :restrict/:delete` | `sqlite do references …` (supported by AshSqlite) |

- `{:array, union}` and embedded resources are stored as JSON text in SQLite; Ash handles that. Check that `mix ash.codegen` produces sensible columns.
- AshPaperTrail supports AshSqlite (it copies the data layer to the version resource). `belongs_to_actor` should point to `Qed.Accounts.User`.
- Every query is scoped to a podcast. Don't use bare `Ash.read!(authorize?: false)` on all pages, which Mercator can do because it has one site.

## 5. qed-specific changes

### One site per podcast

- `Page` and `Asset` get `belongs_to :podcast` (`allow_nil? false`).
- Identities become `[:podcast_id, :path]` and `[:podcast_id, :key]`.
- Policies use `PodcastRole`: owner and editor edit; reads go through membership. Note: `PodcastRole` today only handles changesets (create). Reads and updates need a filter check, e.g. `expr(exists(podcast.memberships, user_id == ^actor(:id)))`.
- Admin routes are nested under the podcast, e.g. `/podcasts/:slug/pages`, `/podcasts/:slug/pages/:id`, `/podcasts/:slug/media`.
- When a podcast is created, seed a `home` page (and possibly `imprint`) as drafts.

### Static output instead of LiveView

- Render blocks with the same function components, but to a string: `Phoenix.HTML.Safe.to_iodata(component.(assigns))` or a `~H` template and `Phoenix.HTML.Safe.to_iodata/1` (`rendered_to_string` exists only in LiveViewTest).
- Don't use `phx-*` or LiveView JS in blocks. The kept blocks already work without them: the FAQ uses `<details>` with DaisyUI `collapse`, and the gallery links each thumbnail to the large image. The only `JS.*` calls are in Contact options, which is dropped.
- URLs: `Asset.url/2` returns `/uploads/assets/<id>/large.webp`. The generator has to copy the files used into the site and point links at their place in the site, ideally as relative links so sites work in subdirectories (GitHub Pages).
- Only **published** pages that are reachable and of kind `page` go into the site, rendered from `published`, never from the working copy. `hidden` pages are written but not linked.
- Redirects: for each `PageRedirect`, write an `old/path/index.html` with `<meta http-equiv="refresh">` and `rel=canonical`. Or drop redirects for qed.
- Menus (`:main`, `:footer`) and icons come from the page attributes, as in Mercator's `MercatorWeb.Navigation`.
- SEO: `seo_description` → meta description; the first image of the page → `og:image` (see `seo.ex`). Add pages to the generated `sitemap.xml`.
- The admin preview can keep using LiveView: render the working copy with the same components inside the qed layout.
- Theming and CSS for the generated sites are still open (qed backlog #004). The block components use DaisyUI classes; if the sites use other CSS, the components have to change.

### New block and page types (to discuss in qed)

- **Landing page:** the page with key `home`. Useful blocks: Hero, **Latest episodes** (n episodes as cards, like Mercator's `Products` block with its loader in `BlockData`), **Subscribe** (feed URLs per audio format, Apple/other directory links from the podcast), Text, Call to action.
- **Contributors:** either a **Contributors block** (items: name, role, photo, Markdown bio, links; like `Faq` with `FaqItem`) or a real resource (`Contributor`) linked to episodes (Podcasting 2.0 `podcast:person`). The resource is more work, but feeds and episode pages could use it.
- **Blog:** two options:
  - (a) `kind: :post` on `Page` with `published_at` (exists), an author and a teaser, plus a **Post list** block.
  - (b) A separate `Post` resource that reuses the block list and the publish lifecycle.

  (a) reuses the editor, history and media library with little new code. Posts sit under a parent page `blog`, so their paths are `blog/<slug>`. An RSS feed for the blog is optional.
- **Episode page content:** shownotes stay Markdown on `Episode` (qed backlog #022). Optionally, an episode page could later get blocks too.

## 6. Suggested order (one commit each, with tests)

1. Markdown rendering and the editor component (MDEx, OverType hook), used for the episode shownotes (qed backlog #022).
2. `Qed.Content` domain: `Page` with the tree, states, working copy/publish, paper trail, scoped to a podcast; the Text block; policies with owners/editors/strangers; resource and policy tests.
3. Admin: page tree (Sortable hook) and page editor with the Text block; LiveView tests.
4. Media library (`Asset`, image processing, uploads) and the image blocks (Hero, Text with image, Image, Gallery, Download).
5. Columns, FAQ, Call to action, Shared; then the qed blocks (Latest episodes, Subscribe, Contributors).
6. Site generator integration: render published pages, menus, assets, redirects, sitemap.
7. Blog (after the decision in §5).
8. Seeds: a demo podcast with landing page, About, Contributors, Imprint and one blog post.

## 7. Lessons from Mercator

- **Forms built by hand for blocks:** filter the params to the block type's known keys before casting. LiveView sends `_unused_*` keys for untouched fields, and those broke Mercator's editor. See `block_params/2` and `clean/1` in `page_edit_live.ex`.
- Edits go through input maps (`Blocks.to_input/1`), not through `Ash.Union` structs. Nested items (`FaqItem`, `Column`) also become maps with string keys. `Content.update_page_blocks/3` is the pattern.
- `update` actions with custom changes need `require_atomic? false`.
- The Sortable hook pushes `{id, parent_id, index}`. The tree uses `Content.place_page/4`, which renumbers the siblings' positions.
- Tests run async: give values in unique columns (slugs, paths, keys) distinct values per test module, or tests block each other.
- Gettext: after merging, translations can end up `fuzzy` and are then ignored; remove the flag. Use `pgettext` for ambiguous short words ("Draft", "Published").
- The OverType hook loads its script lazily from `/overtype/overtype.min.js`. The editor element needs `phx-update="ignore"` and a stable id.
