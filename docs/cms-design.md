# CMS design (phase 5) — draft

Status: **agreed 2026-10-14** (#76–#92 answered).

## 1. Goal

Content managers maintain the non-shop pages of a customer's site without a developer: start page, "about us", the sawmill, FAQ, contact, legal pages (imprint, privacy). Pages can show shop content (products, categories), and texts are written in **Markdown** (#13).

## 2. What the Rails app did

| Rails | What it did | Problems |
|---|---|---|
| `Webpage` | Page tree (ancestry), slug, title de/en, SEO description, states draft / published / published_but_hidden / archived | fine as a concept |
| `PageTemplate` | **DRYML/ERB written by content managers, stored in the DB and rendered at runtime**, with placeholder names (`<container name="text1"/>`, `<photo>`, `<document>`) and Bootstrap 3 grid markup | code in the DB (security, breaks on upgrades), content managers had to write HTML grids |
| `ContentElement` | Reusable piece of content in a folder: CKEditor HTML de/en, or a photo, or a document | HTML from a WYSIWYG editor; reuse via names |
| `PageContentElementAssignment` | Fills a template placeholder of a page with a content element | indirection that was hard to understand |
| `Folder` | Tree to organise content elements | |
| `Blogpost`, `PostCategory`, `Comment`, `Podcast`, `Chapter` | Blog and podcasts (informatom) | customer-specific |
| `Submission` | Contact form, spam check "answer must contain 8" | |

## 3. Proposal: pages built from blocks (#76)

Instead of templates with placeholders, a **page is an ordered list of blocks**. Each block has a type with its own fields, and the shop renders it with fixed, theme-aware components (DaisyUI). Content managers choose and arrange blocks; they never write markup.

Block types for a start:

| Block | Fields |
|---|---|
| **Text** | Markdown (de/en) |
| **Hero** | image, headline, Markdown text, button (label, link) |
| **Text with image** | Markdown, image, image left/right |
| **Image** | image, caption |
| **Gallery** | images |
| **Columns** | 2–3 columns, each Markdown (e.g. three advantages with icons) |
| **Products** | product numbers, or a category, or bestsellers/new arrivals, as tiles |
| **Categories** | selected categories as tiles |
| **Call to action** | headline, text, button |
| **Download** | document (PDF) from the media library |
| **FAQ** | question/answer pairs (Markdown), as an accordion |
| **Contact form** | intro text (#83) |
| **Shared block** | a reference to a reusable block (e.g. opening hours, used on several pages) |

- New block types are added in code, per product version or per customer module. That replaces user-written templates (#9).
- **Shared blocks** replace the reuse of Rails content elements: maintained once, placed on many pages.
- Blocks are sorted by `position` with drag and drop (the SortableJS hook from the back office, #62).

## 4. Resources (domain `Mercator.Content`)

- **Page:** title, slug, SEO description (all translated), parent (tree, like categories), position, state (`draft`, `published`, `hidden` = reachable by URL but not in menus, `archived`; AshStateMachine), menu placement (main navigation / footer / none), optional `key` for pages the code links to (`home`, `imprint`, `privacy`, `contact`).
- **Block:** page (or shared), type, position, `data` (map with the type's fields; translated texts as `%{"de" => …, "en" => …}` inside), validated per type by an Ash type or a change.
- **Asset** (media library): images and documents, stored with `Mercator.Uploads` and converted with libvips like product images; title and alt text (translated); **tags, at least one required**, free text with suggestions from existing tags, and search (#85).
- **Submission:** contact form entries (#83).
- Policies: **contentmanager** and **administrator** edit; everyone reads published pages; content managers also see drafts, with a "draft" banner.

## 5. Markdown (#13, #77, #78)

- Stored as Markdown in the translated maps; rendered to HTML on display, **sanitized** (no raw HTML from content, no scripts), with Tailwind Typography-like styles from the theme.
- Library (#77): **MDEx** (CommonMark + GitHub extensions such as tables, built-in sanitizing, fast, precompiled Rust NIF) — or **Earmark** (pure Elixir, simpler, slower, no built-in sanitizing).
- Editor (#78): a textarea with a small toolbar (bold, italic, heading, list, link, image from the media library) and a live preview next to it (side by side on wide screens, tabs on phones). One component, used everywhere.
- *Implemented (step 1, 2026-10-14):* the editor is **OverType** (MIT, self-hosted in `priv/static/overtype`, as in the pan project): it shows the formatting inline while typing and has a toolbar, so no separate preview pane is needed. Rendering in `MercatorWeb.Markdown` (raw HTML escaped, unsafe links dropped, sanitized; single line breaks kept).
- Fields that switch to Markdown (#79): product description and long description, category **long** description (shown below the products; the short description stays plain text for tiles), GTC text (today a minimal parser for headings and paragraphs), and later offers and messages.

## 6. URLs and navigation (#80, #81)

- Pages live under **`/pages/`** with paths from the tree, e.g. `/pages/ueber-uns/team` (#80). Routes are intentionally English (German visitors are used to English URLs, English visitors would be puzzled by German ones); the slugs themselves are content.
- The start page `/` becomes a CMS page (key `home`) built from blocks (hero, bestseller products, categories, text). The fixed home template goes away (#81).
- Main navigation (#93, 2026-10-14): on wide screens a **second row below the header** with the published pages marked for the main navigation and the main categories; on phones in the "⋯" menu. Footer: pages marked for the footer (imprint, privacy, GTC, contact).

## 7. Back office

- `/admin/pages`: page tree with drag and drop (like the category tree), state changes, "new page".
- `/admin/pages/:id`: page settings (title, slug, SEO, menu, state) and the block list: add a block by type, edit it in place, reorder, delete; preview of the page as visitors see it.
- `/admin/shared-blocks`, `/admin/media` (upload, folders/tags, alt texts), `/admin/submissions` (contact form entries).
- History (#84): every saved change of a page is kept; content managers can view and restore older versions.

## 8. Implementation order (one commit each, with tests)

*Status 2026-10-14: steps 1–8 done (the GTC editor, #92, follows separately). Additional block types beyond the list in section 3 were not needed. Shared blocks are pages of kind `shared` (same working copy, publishing and history).*


1. Markdown rendering component and editor component; switch product, category and GTC texts to Markdown.
2. Content domain: Page with tree and states, public page route and rendering with the Text block.
3. Back office: page tree and page editor with the Text block.
4. Media library (Asset) and the image blocks (Hero, Text with image, Image, Gallery, Download).
5. Shop blocks (Products, Categories, Call to action), Columns, FAQ, Shared blocks.
6. Start page as CMS page; navigation and footer from pages.
7. Contact form and submissions.
8. Demo content for Biber Holz: start page, Über uns, Unser Sägewerk, FAQ, Kontakt, Impressum, Datenschutz.

## 9. Questions

Answered 2026-10-14:

- ~~**#76**~~ *(yes)* Pages as an ordered list of typed blocks; new block types in code. Also answers #9 (no templates in the DB).
- ~~**#77**~~ *(yes)* MDEx for Markdown.
- ~~**#78**~~ *(yes)* Textarea with toolbar and live preview, no WYSIWYG.
- ~~**#79**~~ *(yes)* Product, category and GTC texts become Markdown in step 1.
- ~~**#80**~~ *(prefix)* Pages under `/pages/…`; routes intentionally in English. Makes one domain easy.
- ~~**#81**~~ *(yes)* The start page is a CMS page built from blocks.
- ~~**#82**~~ *(no)* No blog and no podcasts; removed from the roadmap.
- ~~**#83**~~ *(yes)* Contact form: submissions stored and emailed; honeypot and rate limiting (how: #87).
- ~~**#84**~~ *(now)* Version history of pages with restore, built right away.
- ~~**#85**~~ *(tags)* Media library with tags and search; at least one tag per asset.
- ~~**#86**~~ *(yes)* One domain; #20 is dropped.

Follow-ups, answered 2026-10-14:

- ~~**#87 Rate limiting in the app:**~~ *(yes, 2026-10-14)* Hammer plus `Plug.RewriteOn`; also for sign-in, registration, password reset and magic links. Proposal: with **Hammer** (a counter per key and time window in ETS, i.e. in the app's memory; a Redis backend exists for several nodes) and the client IP taken from the proxy's `X-Forwarded-For` header (Plug's `Plug.RewriteOn`, only from the trusted proxy). Contact form e.g. 5 per hour per IP. Apply the same to sign-in, registration, password reset and magic-link requests (today only the proxy could do that)?
- ~~**#88 English shop routes too:**~~ *(yes, 2026-10-14)* All shop routes in English. Proposal: following #80, rename the German routes: `/kategorien` → `/categories`, `/produkte` → `/products`, `/suche` → `/search`, `/warenkorb` → `/basket`, `/kasse` → `/checkout`, `/kasse/anmelden` → `/checkout/sign-in`, `/agb` → `/terms`. Now, before CMS content starts linking to them?
- ~~**#89 Blocks stored inside the page:**~~ *(yes, 2026-10-14)* Blocks embedded in the page. Proposal: the block list as one embedded list on the page (JSONB) instead of a separate table. Then one saved version is the whole page, and history and restore (#84) are simple and exact. Shared blocks stay a resource of their own, with their own history, and are referenced by id.
- ~~**#90 Working copy and publish:**~~ *(yes, 2026-10-14)* Working copy plus publish; history of published versions. Proposal: edits to a published page go into a working copy; visitors keep seeing the published version until "Veröffentlichen". The history records every published version (and lets you restore one into the working copy). Or edit live?
- ~~**#91 SEO basics now:**~~ *(yes, 2026-10-14)* SEO basics as recommended. Proposal: `sitemap.xml` (pages, categories, products), meta description and Open Graph image per page, canonical URLs — as part of step 6?
- ~~**#93 Main navigation:**~~ *(b, 2026-10-14)* A second row below the header on wide screens (pages and main categories), the "⋯" menu on phones. (A left sidebar was considered.)
- ~~**#92 GTC and legal pages:**~~ *(yes, 2026-10-14)* Imprint and privacy as CMS pages; GTC editor with versions in the back office. Proposal: imprint and privacy policy become normal CMS pages (with keys, linked in the footer). The GTC stay versioned in Sales (orders store the accepted version) and get a back-office editor: new version with a valid-from date, Markdown text. In this phase?
