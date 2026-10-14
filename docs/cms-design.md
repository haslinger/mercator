# CMS design (phase 5) — draft

Status: **draft, 2026-10-14.** Open questions #76–#86 are in section 9.

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
- **Asset** (media library): images and documents, stored with `Mercator.Uploads` and converted with libvips like product images; title and alt text (translated), folder or tags (#85).
- **Submission:** contact form entries (#83).
- Policies: **contentmanager** and **administrator** edit; everyone reads published pages; content managers also see drafts, with a "draft" banner.

## 5. Markdown (#13, #77, #78)

- Stored as Markdown in the translated maps; rendered to HTML on display, **sanitized** (no raw HTML from content, no scripts), with Tailwind Typography-like styles from the theme.
- Library (#77): **MDEx** (CommonMark + GitHub extensions such as tables, built-in sanitizing, fast, precompiled Rust NIF) — or **Earmark** (pure Elixir, simpler, slower, no built-in sanitizing).
- Editor (#78): a textarea with a small toolbar (bold, italic, heading, list, link, image from the media library) and a live preview next to it (side by side on wide screens, tabs on phones). One component, used everywhere.
- Fields that switch to Markdown (#79): product description and long description, category description, GTC text (today a minimal parser for headings and paragraphs), and later offers and messages.

## 6. URLs and navigation (#80, #81)

- Pages live at **top-level paths from the tree**, e.g. `/ueber-uns`, `/ueber-uns/team`, via a catch-all route at the end of the router (shop routes take precedence; reserved slugs are rejected).
- The start page `/` becomes a CMS page (key `home`) built from blocks (hero, bestseller products, categories, text). The fixed home template goes away (#81).
- Main navigation: the shop menu ("Sortiment") plus published pages marked for the main navigation; footer: pages marked for the footer (imprint, privacy, GTC, contact).

## 7. Back office

- `/admin/pages`: page tree with drag and drop (like the category tree), state changes, "new page".
- `/admin/pages/:id`: page settings (title, slug, SEO, menu, state) and the block list: add a block by type, edit it in place, reorder, delete; preview of the page as visitors see it.
- `/admin/shared-blocks`, `/admin/media` (upload, folders/tags, alt texts), `/admin/submissions` (contact form entries).
- History (#84).

## 8. Implementation order (one commit each, with tests)

1. Markdown rendering component and editor component; switch product, category and GTC texts to Markdown.
2. Content domain: Page with tree and states, public page route and rendering with the Text block.
3. Back office: page tree and page editor with the Text block.
4. Media library (Asset) and the image blocks (Hero, Text with image, Image, Gallery, Download).
5. Shop blocks (Products, Categories, Call to action), Columns, FAQ, Shared blocks.
6. Start page as CMS page; navigation and footer from pages.
7. Contact form and submissions.
8. Demo content for Biber Holz: start page, Über uns, Unser Sägewerk, FAQ, Kontakt, Impressum, Datenschutz.

## 9. Open questions

- **#76 Blocks instead of templates:** pages as an ordered list of typed blocks, with new block types added in code, instead of user-editable templates with placeholders? This also answers #9 (no templates in the DB).
- **#77 Markdown library:** add **MDEx** (my recommendation: GitHub-flavoured Markdown, built-in sanitizing, fast; a precompiled Rust NIF, so nothing to compile locally) or Earmark (pure Elixir)?
- **#78 Editor:** textarea with a small toolbar and live preview, no WYSIWYG — OK?
- **#79 Markdown in existing fields:** switch product (description, long description), category description and GTC text to Markdown now, in step 1?
- **#80 URLs:** top-level paths from the page tree (`/ueber-uns/team`), or a prefix such as `/seite/ueber-uns`? Top-level is nicer for visitors and SEO, but needs reserved slugs.
- **#81 Start page:** build `/` from CMS blocks (recommended), or keep a fixed start page with a few editable blocks?
- **#82 Blog and podcasts:** the blog could be a later extension (pages of type "post" with date and category); podcasts were informatom-specific. My suggestion: **no blog and no podcasts for now**, both as optional modules later if a customer needs them.
- **#83 Contact form:** store submissions and email them to the shop address; spam protection with a honeypot field and rate limiting instead of the Rails question ("answer must contain 8")? Do we need more forms (e.g. a callback request) later?
- **#84 History:** keep a version history of pages and blocks (AshPaperTrail, see #22) with "restore this version", or later?
- **#85 Media library:** organise assets in **folders** (as in Rails) or with **tags and search** (my suggestion: tags and search; simpler and works across uses)?
- **#86 One domain:** shop and CMS on one domain (my suggestion), so #20 (multi-domain with session handover) is dropped?
