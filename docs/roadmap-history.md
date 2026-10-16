# Mercator – Roadmap: history

What has been **done and decided** in the port of **Mercator** (Rails 4.2 + Hobo 2.2) to **Elixir / Phoenix / Ash / LiveView / DaisyUI** on PostgreSQL. What is still to come and to decide: [roadmap-future.md](roadmap-future.md).

Questions are numbered globally (`#N`); the numbering is never restarted. Designs of the phases: [catalog-design.md](catalog-design.md), [checkout-design.md](checkout-design.md), [cms-design.md](cms-design.md), [guided-selling-design.md](guided-selling-design.md), [payment-design.md](payment-design.md), [deployment-design.md](deployment-design.md), [documentation-design.md](documentation-design.md).

---

## Done

Status as of 2026-10-15:

- **Done:** 1 Foundation, 2 Catalogue, 3 Basket and checkout (steps 1–7 of [checkout-design.md](checkout-design.md), incl. back office orders, status emails #74, pickup = "ready for pickup" #75, local times #73), 4 Back office (catalogue, orders).
- **5 CMS, done** ([cms-design.md](cms-design.md)): Markdown with the OverType editor, pages with working copy, publishing and history, page tree and editor, media library, 13 block types incl. shared blocks and the contact form, start page from the CMS, shop navigation as a sidebar with page icons (#93), SEO basics (#91), rate limiting with Hammer (#87, proxy recommendations in the README), Biber Holz demo pages, GTC editor with fixed versions in force (#92).
- Also done along the way: header for phones (#72), back button, English routes (#88).
- **6 Guided selling, done** ([guided-selling-design.md](guided-selling-design.md), #94–#101): chat for customers and visitors, sales desk with availability, countdown and callback requests, customer context, recommendations, links and files as cards, offers (editor, approval above 10 %, revisions, copies, expiry), offers ordered through the checkout, emails, printable offer page, ratings, Biber Holz demo conversations and offers. Postponed: audio/video (#100).

- **9 Documentation, done** ([documentation-design.md](documentation-design.md), #121–#125, #131–#133): the documentation is compiled into the app from the repository (`Mercator.Docs`): "Hilfe" in the admin area with search and a "?" on every admin page (back office manual by role, operating guide, developer part with the design documents), the shop help at `/help`, and the making-of at `/making-of` (session logs cleaned of personal details, metrics; public in the demo). German and English, the developer part and making-of English only. 71 chapters, about 104,000 words (`docs/metrics.md`).
- **7 Online payment, done** ([payment-design.md](payment-design.md), #108–#113, #128–#130): Mollie only, with its hosted payment page (API v2 with Req, no SDK); a payment simulator for development, tests and the demo; administrators switch the active provider. Checkout redirect, return page and webhook (the status is always fetched from Mollie), "Jetzt bezahlen" after a failed or expired attempt, the order is marked paid by the system. Back office: payment attempts on the order with a link to the payment in Mollie's dashboard, full refund on cancel (checkbox) or with the "Erstatten" button, filter "Online unbezahlt"; incidents for unknown payments, wrong amounts, payments for cancelled orders and failed refunds; emails "Zahlung … erhalten" and, for cancelled online orders, which payment is refunded.
  - Tested by hand on 2026-10-15 with Mollie's test mode, locally and on biber.mittenin.at: EPS paid; an EPS payment marked "failed" stayed open at Mollie (the customer may try another method) and expired after its one-hour validity, and Mollie called the webhook about 5 minutes later; refund on cancel and with the button (Mollie shows the refund as pending until it is paid out); both emails. Locally there are no webhooks (Mollie refuses `localhost`); the return page syncs the status instead.
- **8 Deployment and demo mode, done** ([deployment-design.md](deployment-design.md), #114–#120, #126, #127): Docker image (release with Typst and fonts) and `docker compose` with PostgreSQL, migrations on start, operator guide in `DOCKER.md`. Demo mode: seeding on the first start, protected demo accounts with one-click sign-in, "Demo" badge, simulator, nightly reset. The demo runs at https://biber.mittenin.at on the home server behind the user's reverse proxy. Smoke test passed: registration with confirmation email (SMTP), simulator payment, the full advice process (chat, recommendation, offer, accepting it from the chat widget, print page), the offer PDF. Rate limits per client IP (#126).

Small improvements done along the way (from the backlog):

- ~~**Phoenix LiveDashboard for administrators**~~ *(done 2026-10-16)*: mounted in all environments at `/admin/system` (instead of `/dev/dashboard`), with the shop's CSP (nonce) and `on_mount` requiring the administrator role; linked as "System" under "Verwaltung" (sidebar and dashboard). Database page via `ecto_psql_extras` (#134). Left out: the request logger (its endpoint plug is gone too), environment variables and killing processes. OS data via `:os_mon` (in `extra_applications`; in Docker it shows the host's CPU and memory, and the disks as the container sees them). Described in the operating guide (maintenance).
- ~~**Unit symbols are not translated**~~ *(done 2026-10-16)*: `Unit.symbol/1` translates the counted units (`pgettext("unit symbol", …)`: Stk./pc., Pal./pallet, Sack/sack). lfm, fm, rm, srm and the SI units stay the same in both languages; their labels explain them.
- ~~**Flash toasts cover the top bar**~~ *(done 2026-10-16)*: the flash group sits below the navbar (`top-20`).
- ~~**Return to where we came from after editing addresses**~~ *(done 2026-10-16)*: the checkout links to the address book with `return_to` (the checkout path, including `?offer=`). After saving, the address book goes back there, and if there are no addresses yet it opens the form right away. Only local paths are accepted (`LiveUserAuth.local_path/1`).
- ~~**Missed Ash notifications in demo seeding**~~ *(done 2026-10-15)*: `Mercator.Demo` (seed and reset) and the seeded orders run in `Ash.transact/3` instead of a plain `Repo.transaction`; Ash collects the notifications and seeding drops them (nobody to notify). The test output no longer shows hundreds of warnings.
- ~~**Flaky test: deadlock on the offer number counter**~~ *(done 2026-10-15)*: the PostgreSQL log showed the other side, `products_unique_slug_index`: `product_fixture` derived the slug from fixed titles ("Zirbenbrett" in three async modules), so parallel tests waited for each other's uncommitted product while one of them held the offer counter. The fixture now gives each product a unique slug, and `gtc_fixture` a unique date (the GTC version is unique too). Eight full runs without a deadlock.

- ~~**PDF documents with Typst**~~ *(done 2026-10-15, #17, #104)*: offer PDF ("Download PDF" next to "Drucken") and order confirmation PDF (account and back office order pages), both attached to their emails; rendering errors are logged and the email goes out without the PDF.
- ~~**Product editor: tabs by product kind**~~ *(done 2026-10-15, #103)*: the kind is changed in its own dialog and saved at once (`Product :change_kind`), so the tabs follow immediately. Simple: "Preis & Lager" with exactly one variant; variants: as before; configurable: "Artikel & Lieferzeit" without prices, plus the configurator.
- ~~**Start page key for content managers**~~ *(done 2026-10-15)*: the page editor has "Als Startseite verwenden" for published pages (action `:make_start_page`, which moves the key `home` from the previous start page in one transaction). Other keys stay with administrators.
- ~~**Active entry in the shop sidebar**~~ *(done 2026-10-15)*: the sidebar highlights the page shown (or its closest menu page) and the main category of category and product pages; `@nav` carries the current path and the category trail (`MercatorWeb.Navigation`).
- ~~**Variants combined with a configurator**~~ *(dropped 2026-10-15)*: not done at all; a product is either variants or configurable (#39/#55). For a panel in stock that can also be cut to size, use two related products.
- ~~**Sign-out confirmation page**~~ *(done 2026-10-14)*: the user menu signs out directly with `DELETE /sign-out`; the confirmation page for `GET /sign-out` is our own translated `MercatorWeb.SignOutLive`.

## Demo customer: Biber Holz

The demo, built from seed/dummy data, shows the fictional company **Biber Holz**: "Österreichische Alpen-Forstwirtschaft · Seit 1928 · Qualitäts-Bau- und Edelholz". The company makes nearly everything out of wood and owns its own forests. Its range goes from **complete wooden houses down to sawdust**.

This makes it the test case for **configurable material**: wood species, dimensions, surface, drying and grading, sold in units such as m³, lfm, m², Festmeter, Raummeter and Schüttraummeter.

- Logo: `assets/img/logo.jpeg`, provided by the user. Its "transparent" background is baked into the JPEG pixels, so a cut-out PNG is needed (#37).
- Logo palette: cream `#efd7ab`, walnut `#67482d`, oak/bronze `#be9e73`, dark wood `#180d06`, plus forest-green accents.
- Mercator itself stays generic. Biber Holz is one deployment's branding and demo data (#28).
- The demo runs in production at **https://biber.mittenin.at**.

## Decisions

- **#6** (2026-10-13) Build a **generic multi-customer product**. The customer-system repos are reference material only (approaches, completeness); re-implementing those specific customers is very unlikely.
- **#21** (2026-10-13) **No data migration.** We create dummy/seed data instead. As a result, #11 (migrating files), #22 (migrating history) and #23 (keeping old passwords) only matter in their non-migration parts.
- **#28** (2026-10-13) **Single tenant: one deployment per customer.** Customer specifics come from runtime config, a DaisyUI theme and enabled modules. We design so a later move to Ash multitenancy stays possible: customer config lives in one place, and integrations are optional modules.
- **#14** (2026-10-13) mPAY24 **will be replaced**; we choose the provider when payment is implemented.
- **#15** (2026-10-13) **Mesonic ERP, Icecat and Bechlem will not be implemented.**
- **#26** (2026-10-13) `CLAUDE.md` written (it imports the generated `AGENTS.md`).
- **#27** (2026-10-13) Start with **phase 1**, pulling in phases 2 and 9 (seed data) as needed.
- **#29 / #30** (2026-10-13) Toolchain via **asdf**, always the latest stable release (Erlang 29.1.1, Elixir 1.20.4-otp-29). App generated with `mix igniter.new … --with phx.new` (Phoenix 1.8.15, Ash 3, AshPostgres, AshPhoenix, AshAuthentication(Phoenix), AshStateMachine, AshPaperTrail, Oban).
- **#7** (2026-10-13) **Translations:** UI texts use Gettext (in code). Translatable **content** is stored in the DB as **one JSONB map per attribute** (`%{"de" => …, "en" => …}`), with a calculation for the current locale that falls back to `de`. Search uses Postgres full-text search with one index per language (German/English stemming). Adding a language means config only, no migration.
- **#31** (2026-10-13) `usage_rules` added: Elixir/OTP and Phoenix rules are inline in `AGENTS.md`; Ash rules form the on-demand `ash-framework` skill.
- **#8** (2026-10-13) **No database user per visitor.** Anonymous visitors get a **session basket** that moves to the real user at login or registration. Login uses **password + magic link** (AshAuthentication). The session carries an anonymous session ID for later analytics.
- **#18 (analytics part)** (2026-10-13) General traffic stats live **outside the app** (proxy logs or Plausible/Umami/Matomo, chosen per customer). **Shop funnel events** (visit → basket → checkout → order) come later as an anonymous in-app event table (no personal data, no IPs). Blog and podcasts: no (#82); contact form: yes (#83). Still open: comments, Twitter, Gravatar.
- **#32** (2026-10-13) **Roles as one list attribute** (`roles: [:sales, :contentmanager]`) using the enum `Mercator.Accounts.Role`. Only administrators may change roles. Implemented in c85e2e8.
- **#33** (2026-10-13) **User profile:** an optional `name` (one field, no first/last split, no salutation or academic title), an optional `phone`, and `locale` (de/en, default de). Structured address data (company, recipient) belongs to billing and delivery addresses (phase 3).
- **#34** (2026-10-13) License: **GPL v3**, as in the Rails version (`LICENSE` copied from the Rails repository).
- **#35** (2026-10-13) License: **GPL v3 or any later version** (`GPL-3.0-or-later`).
- **#36** (2026-10-13) **Branding is per-deployment config** (`config :mercator, :brand`, see `Mercator.Brand`): name, tagline (de/en), contact data, images and DaisyUI themes. Mercator has a neutral default (globe logo, `light`/`dark`); dev uses the Biber Holz demo brand. Images are served under stable URLs `/brand/logo|pin|favicon|apple-touch-icon`.
- **#37** (2026-10-13) Biber Holz images: the medallion cut out with real transparency (`logo.webp`, `logo-256.png` for emails), the user's pin (`pin.webp`) for the navbar, and the user's favicon (SVG plus a 180 px apple-touch-icon). They live in `priv/static/images/brands/biberholz/`; the originals stay in `assets/img/` (not committed).
- **#38** (2026-10-13) DaisyUI themes `biberholz` and `biberholz-dark`, built from the logo palette. The system/light/dark toggle chooses a mode; the brand maps each mode to its themes.
- **#39** (2026-10-13) **Three product kinds:** simple, variants (own article number/stock/price) and configurable (price calculated by rules from options and dimensions). The data model covers all three from the start; implement simple + variants first, configurable right after.
- **#40** (2026-10-13) **Units:** piece, lfm, m², m³, Festmeter, Raummeter, Schüttraummeter, kg, t, pallet, sack. Prices per unit, decimal quantities.
- **#41** (2026-10-13) **Demo catalogue:** about 8 top categories, about 30 subcategories, 80–120 products, German and English. Product images start as placeholders.
- **#42** (2026-10-13, changed 2026-10-15) Demo users have `@mittenin.at` addresses everywhere (catch-all exists), e.g. `admin@mittenin.at`, `kunde@mittenin.at`; the shop's contact address is `service@mittenin.at`. Until the final domain is fixed, the shop runs on **biber.mittenin.at** (default of `PHX_HOST`). Other test data keeps `example.com`.
- **#43** (2026-10-13) The Biber Holz brand settings move to one shared file used by dev and production (`BRAND=biberholz`).
- **#44** (2026-10-13) Demo data in production through a release task, enabled with `DEMO_DATA=true`, plus a **regular (nightly) reset** of the demo, so visitors can freely try it out as **sales rep and customer**.
- **#45** (2026-10-13) **No public admin login**: it's a demo, not a trial. Visitors get public demo logins for non-admin accounts (sales rep, customer); the admin password comes from an environment variable. Truly interested companies get a trial instance on premises.
- **#46** (2026-10-13) Public demo accounts are protected in demo mode (no change of password, email or roles; no password reset). The user wants the demo clearly separated from production behaviour, see #48.
- **#47** (2026-10-13) **All non-admin demo accounts are public** (customers, sales, sales manager, content, products). The nightly reset repairs any changes; the login page says so.
- **#48** (2026-10-13) **Demo = production release + runtime switch `MERCATOR_MODE=demo`** (no separate Mix environment). `Mercator.Demo.enabled?()` bundles all demo behaviour: seeding, nightly reset, protection of the public accounts (#46), demo logins and reset hint on the login page, demo badge. Built together with deployment (#24).
- **#51** (2026-10-13) **VAT (Austria, per Wirtschaftskammer):** 13 % for firewood, wood pellets and Christmas trees; 20 % standard, including unprocessed logs / saw logs not sold directly as fuel. Details in catalog-design.md.
- **#49, #50, #52–#57** (2026-10-13) Catalogue design **as recommended** (see catalog-design.md): category tree with `ltree`; prices stored net, display net or gross by shop setting (demo: gross); products draft → active → discontinued; flags `new?`/`bestseller?` plus "on sale" derived from promotion prices; stock per variant (`nil` = made to order); configurator scope as in section 4 (house configurator later); Postgres full-text search (also answers #10); customer-specific prices later.
- **#58** (2026-10-13) Product and category images become **real uploads** (an image resource with upload and storage), not static files per brand.
- **#11** (2026-10-13) Uploaded files are stored on **local disk**.
- **#59** (2026-10-13) Demo images are **generated externally as photos** from the prompt list in `assets/lists/` (124 images), not as SVG illustrations. They are imported through the upload resource (#58).
- **#60** (2026-10-13) Image processing with the Elixir library **`image`** (libvips via `vix`, precompiled, nothing to install on servers).
- **#16** (2026-10-13) **One admin area `/admin`** with a sidebar that shows each person what their roles allow (instead of Rails' five subsites).
- **#61** (2026-10-13) AshAdmin only in development (`/dev/ash-admin`) as a raw-data tool; staff get proper pages.
- **#62** (2026-10-13) Drag & drop sorting with **SortableJS** (vendored).
- **#63** (2026-10-13) Back office order of work: admin layout → category tree → product list → product editor (general, variants & prices, properties, relations, images, configurator) → tax classes.
- **#64–#70** (2026-10-13) Basket and checkout **as suggested** (see checkout-design.md):
  - payment by prepayment, invoice (approved customers only) or on pickup
  - parcel flat rate per zone, free above a threshold; freight "from" price confirmed by staff; pickup free
  - checkout for signed-in customers only (magic link)
  - delivery countries AT, DE, IT (no CH), Austrian VAT; demo simplification, per-customer rules in code
  - order numbers `BH-2026-00042`
  - B2B reverse charge later
  - order email without PDF
- **#71** (2026-10-13) **Postcode formats** are checked for all billing countries (EU + CH, LI), defined in `Mercator.Countries.postcode_format/1`.
- **#72** (2026-10-14) **Header on phones:** below `md` (768 px) language and theme move into a "⋯" menu (shop and admin header), "Register" is hidden (the sign-in page links to it) and "Sign in" is an icon below `sm`; the search box shows from `lg`, an icon below.
- **#13** (2026-10-14) **Markdown instead of rich text** everywhere it applies (CMS content, product and category descriptions, GTC, later offers and messages): stored as Markdown in the translated JSONB maps, edited in a textarea with preview, rendered to sanitized HTML. No WYSIWYG editor. No CKEditor HTML needs to stay renderable (no data migration, #21).
- **#25** (2026-10-13) **No security risk:** none of the old systems are deployed any more. Secrets still go only into env/`runtime.exs` in the port.
- **#19** (2026-10-14) **No contracting module.** The printer and consumables leasing contracts were specific to one customer and are not needed; the phase is dropped.
- **#24** (2026-10-14) **Deployment with Docker**: Mercator runs as a Docker container (a Mix release in the image), set up in the deployment phase. The database connection sets `lc_messages=C`; on managed Postgres configure English server messages instead (see README).
- **#22** (2026-10-14) **Version history only where it is needed**, decided per resource: CMS pages keep every published version (AshPaperTrail, #84), the GTC are versioned by date (#92), orders keep their state changes with notes (OrderEvent), and offers will keep their revised versions. No history for the rest.
- **#18** (2026-10-14) **No Twitter integration, no podcasts and no blog** – ever. News go on a normal CMS page that editors keep up to date. Comments (they belonged to blog and podcasts) and Gravatar (no profile pictures are shown) are not needed either. Visitor tracking: see the analytics part of #18 above.
- **#17** (2026-10-14) **PDF documents with Typst** for **offers and order confirmations**. No contracts (#19) and **no invoices**: Mercator is not an accounting system (FI/CO); invoices come from the customer's accounting, also for the payment method "invoice". Typst is Apache 2.0, compatible with our GPL-3.0-or-later; called as a separate program, its license does not touch Mercator at all, and the documents produced are ours. Comes with the printable offer page (#99).
- **#102** (2026-10-15) The user's **name is mandatory**: staff address customers by name, and offers and orders need it. The registration form asks for it (an extra field via the `register_extra_component` override); users who sign up by magic link enter it on `/account/name` right after sign-in, and every page of the live session sends them there until they have (`LiveUserAuth :require_name`). The column stays nullable only for that moment.
- **#103** (2026-10-15) **Changing a product's kind keeps all data**: prices of a now-configurable product and configurator options of other kinds stay in the database, unused and hidden, so switching back restores them. Only variants → simple is refused while there is more than one variant (delete the others first). Switching to configurable starts with pricing per piece.
- **#104** (2026-10-15) **Typst runs as the `typst` program** (asdf, pinned in `.tool-versions`; the Docker image installs the same binary and a sans font such as Noto Sans or DejaVu Sans). `Mercator.Pdf` compiles `priv/typst/document.typ` in a temporary directory with `data.json` and the brand logo; texts are formatted and translated in Elixir (`MercatorWeb.Documents`).
- **#105** (2026-10-15) **Incidents** in a new domain `Mercator.Operations`: problems the system notices (a PDF that could not be created, a background job that failed for good) and problems staff record become incidents with title, description, technical details, resolution, state open/resolved, who resolved it and when, and links to customer, order, offer or conversation. The same open problem counts up instead of repeating. `/admin/incidents` with a live badge in the admin sidebar; "Report incident" on order, offer and conversation.
- **#106** (2026-10-15) Administrators see all incidents; sales staff those about a customer, order, offer or conversation, and the ones they reported.
- **#107** (2026-10-15) Staff can also record incidents by hand.
- **#108** (2026-10-15) **Online payment with Mollie first** (the easier integration: hosted page, webhook sends only an id), Stripe later. Liberapay is not suitable (donations, not shop payments) and dropped; mPAY24 is not used. Test mode costs nothing.
- **#131** (2026-10-15) The **session logs** become part of the documentation (the making-of). Removed from them: the user's name, infrastructure details of the home server (host name, router, firewall, ports, local paths) and personal asides; the public demo domain and demo accounts stay. The export script applies the same rules to future logs.
- **#132** (2026-10-15) The **making-of** (cleaned session logs and project metrics) is public in the demo shop (`/making-of`, linked from the footer), switched on per deployment; customer shops do not show it.
- **#133** (2026-10-15) The making-of stays **English only**; the rest of the documentation is German and English (#123).
- **#130** (2026-10-15) The **cancellation email** names the online payment when the order was paid online: "Ihre Online-Zahlung über … erstatten wir auf dasselbe Zahlungsmittel." (decided by a paid or refunded payment, since the email may go out before the refund is recorded); other orders keep "Falls Sie bereits bezahlt haben …".
- **#129** (2026-10-15) The shop does **not track refunds** after Mollie accepted them (pending, paid out, failed). Staff check them in Mollie's dashboard through the link on the payment attempt; the shop does not copy Mollie's refund logic.
- **#128** (2026-10-15) **Mollie is the only payment provider, with its hosted payment page.** Stripe and the embedded payment form are dropped: after the test on biber.mittenin.at, Mollie's integration, webhooks, payment page and dashboard all look professional. Replaces "Stripe later" in #108 and "embedded form later" in #109.
- **#109** (2026-10-15) The provider's **hosted payment page** first; an embedded payment form later, shown as if it were a third provider.
- **#110** (2026-10-15) Online payment is **one more payment method** next to prepayment, invoice and payment on pickup; the concrete methods (cards, EPS, …) are chosen in the provider's dashboard. Webhooks are tested on the home server deployment (phase 8). Design: [payment-design.md](payment-design.md).
- **#111** (2026-10-15) Unpaid online orders are left to staff: no automatic cancellation; goods stay reserved until the order is cancelled.
- **#112** (2026-10-15) **Freight costs are calculated**, by country zone with a configurable model; first a fixed amount plus a percentage of the goods value. The total is final at checkout, so freight orders can be paid online. Estimates (`estimate: true`) stay possible per deployment, without online payment.
- **#113** (2026-10-15) Refunds: full refunds on cancellation through the provider; partial refunds in the provider's dashboard.
- **#114** (2026-10-15) The home server's **existing reverse proxy** does HTTPS for biber.mittenin.at; the container publishes HTTP only.
- **#115** (2026-10-15) Emails are **really sent by SMTP**, also in the demo.
- **#116** (2026-10-15) The image is **built on the server** from a git checkout (like pan), no registry.
- **#117** (2026-10-15) The home server is x86_64 with Ubuntu 24.04 and Docker Compose v2. Design: [deployment-design.md](deployment-design.md).
- **#118** (2026-10-15) Emails are sent by the **mittenin.at mail server** (`box.mittenin.at`, port 465 with TLS), like pan.
- **#119** (2026-10-15) New dependency **`gen_smtp`** for Swoosh's SMTP adapter.
- **#121** (2026-10-15) Phase 9 **documentation** has four audiences: the shop owner and staff (back office manual by role), operators, developers (all in the admin area), and shop visitors (help in the shop, #125).
- **#122** (2026-10-15) The documentation is **Markdown in the repo**, versioned with the code and the same for every customer.
- **#123** (2026-10-15) Documentation in **German and English**, German first, shown in the user's language with German fallback.
- **#124** (2026-10-15) Admin area: a **"Hilfe" section** (table of contents, search) plus **context links** ("?") from each admin page to its chapter, chapters filtered by role.
- **#127** (2026-10-15) The demo shop keeps sending its emails (order confirmations, offers, staff notifications) to the demo addresses **as now**; the demo addresses stay as they are.
- (2026-10-15) **One-click demo sign-in:** the sign-in page showed the demo addresses, which spam bots harvested for the mittenin.at catch-all. It now shows buttons per demo account (name and role only) that post just the login key to `/demo/sign-in` (`AuthController.demo_sign_in/2`, demo mode and public accounts only). Not done: new demo addresses (#127); a mail-server filter for the old ones is up to the mail server.
- **#126** (2026-10-15) **Rate limits per client IP:** spam bots guessing passwords for the published demo addresses locked everybody out of these accounts (limit per address only). Now sign-ins count per address *and* IP (10 per 15 min) and per IP (30 per 15 min); auth emails per address and IP (3 per 15 min) and per address (10 per hour). Every limit reached is an incident, one per IP. The IP comes from `MercatorWeb.ClientIp` via the Ash context (`SignInLive`, `Plugs.AuthContext`).
- **#125** (2026-10-15) Help for **shop visitors** is generic help from the repo at `/help` (ordering, account, payment, chat, offers), linked from the footer, the checkout and the chat; customer-specific content (delivery areas, FAQ, GTC) stays in the CMS. Operator and developer chapters in the admin area are for **administrators only**.
- **#120** (2026-10-15) The **sign-in emails** (confirmation, password reset, magic link) stay sent directly, not by Oban: if delivery fails, the error is logged and reported as an incident (`Mercator.Mailer.deliver_or_report/3`), and the action (e.g. the registration) still succeeds. The page cannot show a message: AshAuthentication ignores what a sender returns.
- (2026-10-14) **Chat messages are sent with the button only**, not with Enter: many people don't know Shift+Enter for a new line. Enter makes a new line (customer chat and sales desk).
- **#134** (2026-10-16) The LiveDashboard gets its **database page** (`ecto_psql_extras`, `ecto_repos: [Mercator.Repo]`): table and index sizes, unused indexes, cache hit ratio, locks, long-running queries, vacuum statistics. The dashboard itself leaves out `kill_all` and `mandelbrot`. Query statistics (outliers, calls) would need the PostgreSQL extension `pg_stat_statements`, not set up.
- **#135** (2026-10-16) **No metrics history** in the LiveDashboard: it would need our own buffer process (`metrics_history:`), not worth it; the charts start empty on each visit.
- **#136** (2026-10-16) Every rate limit reached is also **logged as a warning** in a fixed format for fail2ban and `docker compose logs`: `rate limit reached: bucket=… ip=…`, without the email address (done in `Accounts.Preparations.RateLimit`).
- **#137** (2026-10-16) **Bandit updated to 1.13.1** (with Thousand Island 1.6) for two advisories in 1.12.5: CVE-2026-105659 (HIGH, HTTP/2 send deadlines; the app speaks HTTP/1.1 behind the proxy) and CVE-2026-105660 (MEDIUM, HTTP/1 request target could set `conn.host`/`conn.port`). `mix deps.get` reports no advisories since.

## Answered questions

The questions as they were asked, kept for the record (the decisions above are the short form).

### Scope and target
- ~~**#6**~~ *(answered, see Decisions)* Who is the port for? One customer installation (which one: ivellio-vellin?), or a generic product that again supports several customer systems with their own themes, config and modules? Should one instance serve several tenants? (→ no, see #28)
- ~~**#7**~~ *(answered, see Decisions)* Translations: keep the `_de`/`_en` column pairs, or move to one map/JSONB column per field? Will there only ever be de/en?
- ~~**#8**~~ *(answered, see Decisions)* Guest users: keep the Rails model, where every visitor gets a DB user? The alternative is a session-based anonymous basket that becomes a user at checkout or login. Do we keep email-link login and passwords?
- ~~**#9**~~ *(answered 2026-10-14 by #76: blocks instead of templates)* Page templates: the Rails app lets content managers write DRYML/ERB templates in the DB. Do we need user-editable templates (e.g. Liquid/Solid with `container`/`photo`/`document` tags), or are a few fixed HEEx layouts with named content slots enough?
- ~~**#10**~~ *(answered by #56: Postgres full-text search)* Search: Postgres full-text search (simplest, no extra service), or a dedicated engine (Meilisearch/Typesense/Elasticsearch)? How large is the catalogue (number of products/categories)?
- ~~**#11**~~ *(answered, see Decisions)* File storage: local disk or S3-compatible? ~~Do the existing Paperclip files have to be migrated?~~ (no, see #21)
- ~~**#12**~~ *(answered 2026-10-14 by #96 and #100: links and documents instead of an iframe; audio/video postponed)* Audio/video chat and cobrowsing: still wanted? If so, should WebRTC signalling run over Phoenix Channels? Cobrowsing in Rails worked by sending events to the customer's page. Is that still needed in the same form?
- ~~**#13**~~ *(answered 2026-10-14, see Decisions)* Which rich-text editor for content elements and descriptions (TipTap, Trix, or something else)? Must existing CKEditor HTML stay renderable as-is?
- ~~**#14**~~ *(answered, see Decisions)* Payment: is mPAY24 still the provider? (I couldn't confirm whether the SOAP API used in 2015 still exists.) Are other providers wanted (e.g. Stripe, PayPal)?
- ~~**#15**~~ *(answered, see Decisions)* Integrations: which are still in use? Is Mesonic ERP still the ERP, with MSSQL access still available? Are the Icecat and Bechlem accounts still active? (Their APIs/feeds have likely changed since 2016.)
- ~~**#16**~~ *(answered, see Decisions)* Back office UI: one unified admin area with role-based menus, or the five separate subsites as in Rails? Is AshAdmin acceptable for low-traffic CRUD screens?
- ~~**#20**~~ *(answered 2026-10-14 by #86: one domain)* Multi-domain setup (separate CMS, shop and podcast domains with session handover): still needed, or one domain?

- ~~**#17**~~ *(answered 2026-10-14: Typst, see Decisions)* PDF output: which documents are needed (offers, orders, contracts)? Which tool do you prefer (ChromicPDF needs headless Chrome; Typst is a single binary)?
- ~~**#18**~~ *(answered 2026-10-14, see Decisions)* Which of these features are still needed: blog, podcasts, comments, Twitter integration, Ahoy visitor tracking, the contact form with its captcha question, Gravatar?
- ~~**#19**~~ *(answered 2026-10-14: dropped, see Decisions)* Contracting module (printer/consumable leasing contracts): still needed? Who uses it? Should it stay a separate area?

### Data and operations
- ~~**#21**~~ *(answered, see Decisions)* Do we migrate existing production data from MySQL (users, orders, catalogue, CMS content), or start fresh? Is a recent DB dump available to develop against?
- ~~**#22**~~ *(answered 2026-10-14: only where needed, see Decisions)* Do we keep the version history (paper_trail) for all resources, or only for selected ones (orders, prices, products)? ~~Should the old history be migrated?~~ (no, see #21)
- ~~**#23**~~ *(obsolete because of #21)* Is there an existing user base whose passwords must keep working? Hobo stores crypted passwords; I'd need to check the hash algorithm. If they can't be verified, we'd force a reset.
- ~~**#73**~~ *(answered 2026-10-14: yes)* Time zone: `tz` package, shop time zone configurable (`:time_zone`, env `SHOP_TIME_ZONE`, default `Europe/Vienna`), see `Mercator.Clock`.
- ~~**#74**~~ *(answered 2026-10-14: yes)* Customers get an email when staff confirm, ship or cancel their order (with the reason).
- ~~**#75**~~ *(answered 2026-10-14: a)* For pickup orders the state `shipped` means **ready for pickup**: button "Abholbereit melden", label "Abholbereit", and an email to the customer with the pickup address (and the payment note for payment on pickup). "Completed" means picked up.

- ~~**#24**~~ *(answered 2026-10-14: Docker, see Decisions)* *(note: the DB connection sets `lc_messages=C`, which needs a superuser or `GRANT SET`; on managed databases configure English server messages instead)* Deployment target: where will it run (own server, Fly.io, Docker…)? Should a release or Docker setup be part of the first phase?

### Security note
- ~~**#25**~~ *(answered, see Decisions)* The customer-system repos (`systems/*/config/application.yml`, `database.yml`) contain **plaintext credentials**: DB, Mesonic ERP, mPAY24 merchant, Icecat, Bechlem and secret tokens. In the port, secrets will live only in environment variables or `runtime.exs`. Are any of these credentials still live? If so, they should be rotated, since they are in git history.

### Process
- ~~**#26**~~ *(answered, see Decisions)* Should I write a `CLAUDE.md` with project conventions (Ash domains layout, naming, testing, Rails source location) before we start coding?
- ~~**#27**~~ *(answered, see Decisions)* Which phase or feature should come first? (My suggestion: phases 1 and 2.)
- ~~**#31**~~ *(answered, see Decisions)* Should I add the `usage_rules` dev dependency? It syncs the official usage rules of Ash, AshPostgres, AshPhoenix, AshAuthentication, Oban and others into `AGENTS.md`. The generated `AGENTS.md` currently covers only Phoenix/Elixir, and the Ash rules help keep generated code idiomatic.
- ~~**#32**~~ *(answered, see Decisions)* Roles: replace the five Rails role booleans with one `roles` list attribute (e.g. `[:sales, :contentmanager]`)?
- ~~**#33**~~ *(answered, see Decisions)* Profile fields: first name, last name, phone, preferred language, plus salutation (Herr / Frau / divers / keine Angabe) and an optional academic title?
- ~~**#34**~~ *(answered, see Decisions)* License of the port: GPL v3 like the Rails version, another open-source license, or proprietary?
- ~~**#36**~~ *(answered, see Decisions)* Branding as per-deployment config (shop name, tagline, logo, DaisyUI theme, contact data). Mercator gets a neutral default; Biber Holz is the demo brand active in dev and seeds.
- ~~**#37**~~ *(answered, see Decisions)* Logo: use the cut-out round PNG with real transparency? For the navbar, a small medallion plus the text "Biber Holz" (the medallion text is unreadable at 40 px). Keep the original JPEG out of the repo?
- ~~**#38**~~ *(answered, see Decisions)* DaisyUI themes `biberholz` (light: parchment base, walnut primary, forest-green secondary, bronze accent) and `biberholz-dark` (dark wood).
- ~~**#39**~~ *(answered, see Decisions)* Product kinds: (a) **simple** products (one price, e.g. a stool or a pellet sack), (b) **variants** with their own article number, stock and price (e.g. "Terrassendiele Lärche 28×145×4000"; Rails' inventories), (c) **configurable** products where the customer enters dimensions and options and the price is calculated by rules (wood species price per m³ × volume + surcharges for surface or drying; minimum quantities, rounding). Design the data model for all three now, implement (a)+(b) first and (c) right after?
- ~~**#40**~~ *(answered, see Decisions)* Units: piece, lfm, m², m³, Festmeter (fm), Raummeter (rm), Schüttraummeter (srm), kg, t, pallet, sack. Prices per unit and decimal quantities (e.g. 2.5 m³)?
- ~~**#41**~~ *(answered, see Decisions)* Demo catalogue scope and images: about 8 top categories, about 30 subcategories and 80–120 products with German and English texts? Product images: none or neutral placeholders at first, or will you provide (e.g. AI-generated) images?
- ~~**#42**~~ *(answered, see Decisions)* Demo email addresses: make the domain configurable, `firstname.lastname@<domain>`. Keep `example.com` (reserved, never deliverable) in dev and tests, and use `mittenin.at` on biber.mittenin.at? This needs mailboxes or a catch-all on mittenin.at, otherwise confirmation, magic-link and reset emails bounce.
- ~~**#43**~~ *(answered, see Decisions)* Selecting the brand in production: move the Biber Holz brand settings from `config/dev.exs` to one shared place (e.g. `config/brands/biberholz.exs`) that dev and production (`BRAND=biberholz`) both use?
- ~~**#44**~~ *(answered, see Decisions)* Demo data in production: a release task (`bin/mercator eval "Mercator.Release.seed()"`) controlled by a flag such as `DEMO_DATA=true`. Should the demo be reset regularly (e.g. nightly), so that visitors' changes disappear?
- ~~**#45**~~ *(answered, see Decisions)* Public demo logins on biber.mittenin.at: which demo accounts may visitors use (shown on the login page)? The administrator account should **not** have a published password, since an admin can change roles and later everything else.
- ~~**#46**~~ *(answered, see Decisions)* Protect the public demo accounts: in demo mode, their password, email and roles can't be changed and no password reset can be requested for them, so one visitor can't lock out the next.
- ~~**#47**~~ *(answered, see Decisions)* Which accounts are public: Karl Luchs (customer, German), Lena Igel (customer, English), Sepp Fuchs (sales), Maria Hirsch (sales manager)? And also Klara Eichhorn (content) and Peter Dachs (products), to show CMS and product management, with the risk that visitors deface the shop until the next reset?
- ~~**#48**~~ *(answered, see Decisions)* The demo as a **production release with a runtime switch** `MERCATOR_MODE=demo` (one build artifact; `Mercator.Demo.enabled?()` bundles all demo behaviour: seeding, nightly reset, account protection, login hints, demo badge), rather than a separate Mix environment `demo`?
- ~~**#49–#57**~~ *(answered, see Decisions)* Catalogue design questions (tree storage, net/gross, tax classes, states, Neuheiten/Topseller, stock, configurator scope, search, customer prices): see [catalog-design.md](catalog-design.md#9-open-questions).
- ~~**#58**~~ *(answered, see Decisions)* Image storage: static files per brand, or real uploads?
- ~~**#59**~~ *(answered, see Decisions)* Demo images: SVG illustrations, or photos generated externally from a prompt list?
- ~~**#64–#70**~~ *(answered, see Decisions)* Basket and checkout questions (payment methods, shipping costs, signed-in checkout, delivery countries, order numbers, B2B reverse charge, order email): see [checkout-design.md](checkout-design.md#9-open-questions).
- ~~**#76–#92**~~ *(answered 2026-10-14)* CMS design questions: see [cms-design.md](cms-design.md#9-questions), including the follow-ups #87–#92.
- ~~**#94–#101**~~ *(answered 2026-10-14)* Guided selling questions: see [guided-selling-design.md](guided-selling-design.md#6-questions-answered-2026-10-14).

---

## Background (overview of 2026-10-13)

### What Mercator is

Mercator is a **guided-selling web shop**: a web shop combined with a sales consulting tool.
(The Rails wiki calls it "Beratungs- und Webshopsoftware".)

- Customers can shop on their own, or ask for a sales consultant.
- Customer and consultant communicate by text chat, audio/video chat (WebRTC) and **cobrowsing**: the consultant can remote-control the customer's browser.
- Consultants can build offers with the customer and share texts, links, documents and product suggestions.
- An accepted offer becomes an order, which then follows the normal checkout.
- The app also includes a CMS (pages, templates, content elements), a blog, podcasts, and a **contracting** module that calculates printer leasing and consumables contracts.

Sales process (from the Rails wiki, `mercator.wiki/images/verkaufsprozess.png`):

```
CMS pages → Promotions → Category ⇄ Product ⇄ Product comparison
Product → Basket → Billing address → Shipping address → Shipping method
        → Billing method → GTC → Review → (Order into ERP) → Payment
        → Confirmation | still in payment | Error (→ retry payment)
Product → Start conversation → Conversation → { Text chat, A/V chat, Cobrowsing,
          Documents, Product suggestions } → Offer → Basket
```

### Source inventory

Working copies are in `/daten/DATA/rails/mercator-src/`. The origins are the bare repos in `/daten/DATA/rails/mercator/`.

| Repo | What it is | Relevance |
|---|---|---|
| `mercator` | The shop. Rails 4.2.10, Ruby 2.3.5, Hobo 2.2.4. About 50 models, 160 specs, 202 migrations. `Gemfile`, `database.yml` and `routes.rb` are **symlinks into `vendor/customer`**, which is a customer-system repo. | **Core** |
| `systems/*` (11) | Per-customer config: Gemfile, routes, `application.yml`, theme (SCSS, fonts, logo), DRYML tag overrides, order confirmation view. Customers: informatom, ivellio-vellin, miranda, mercator-demo, plus the `mercator-customer` template. | Config and theming reference |
| `mercator_mesonic` | Engine for the Mesonic ERP, accessed directly on MSSQL through TDS. Handles product import (WEBARTIKEL view), customer accounts, customer-specific prices, and order export. | Integration |
| `mercator_icecat` | Engine for the Icecat product catalogue: XML import of texts, images, properties and relations. | Integration |
| `mercator_bechlem` | Engine for the Bechlem catalogue (local MySQL DB plus FTP import). Provides the printer → consumables finder (`/consumables`). | Integration |
| `mercator_mpay24` | Engine for mPAY24 e-payment over SOAP, with a confirmation callback and an admin payments view. | Integration |
| `mercator_legacy_importer` | One-off import from the older Opensteam-based shop. | Probably not needed |
| `miranda-weissenfeld` | That predecessor shop (Rails 2.3, Opensteam, 2012–2013). | Probably not needed |
| `hobo_bootstrap`, `hobo_bootstrap_ui`, `hobo_w2ui` | Hobo UI gems (Bootstrap 3 theme, w2ui grids). | Replaced by DaisyUI and LiveView |
| `mercator-faye` | Faye / private_pub server config for realtime messaging. | Replaced by Phoenix PubSub |
| `palava-machine` | WebRTC signalling server (EventMachine + Redis). | Replaced, or dropped (see #12) |
| `ember-contracting`, `ember-rails-contracting` | 2014 prototypes of the contracting UI, later superseded by the in-app w2ui version. | Probably not needed |
| `mesonic-browser` | Debug tool for browsing the Mesonic DB. | Probably not needed |
| `mercator.wiki` | German documentation: installation, modules, jobs, templates, and two diagrams. | **Reference** |

Customer systems and the modules they mount (the last commit date of each system is in brackets):

| System | Mesonic | Icecat | Bechlem | mPAY24 | Legacy importer |
|---|---|---|---|---|---|
| ivellio-vellin (dev/test/staging/prod) (2017-10) | ✓ | ✓ | ✓ | ✓ | |
| miranda (dev/staging) (2016-02) | ✓ | | | | staging only |
| mercator-demo (dev/prod) (2016-03) | ✓ | | | | ✓ |
| informatom (dev/prod) (2016-03) | | | | | |

### Architecture of the Rails app

#### Subsites (separate UI areas, each with its own layout and JS)
| Subsite | Users | Content |
|---|---|---|
| front (`/`) | everyone | Shop, categories, products, comparison, basket/checkout, offers, conversations, CMS pages, blog, podcasts, user account |
| `admin` | administrator | Hobo CRUD for all models, page templates, logs, payments, Icecat metadata |
| `sales` | sales, sales_manager | Conversation desk, offer editing, downloads, links, suggestions, feedback |
| `productmanager` | productmanager | Category tree (drag & drop), price manager, property manager, relation manager |
| `contentmanager` | contentmanager | Webpage tree, folder tree, content elements, assignments |
| `contracting` | sales? | w2ui single-page app for contracts, contract items and consumables, plus toner XLS upload |

#### Domain model (about 50 models; all versioned with paper_trail)
- **Catalogue:** Category (tree, states new/active/deprecated/switched_off, filters, Elasticsearch-indexed), Product (states new/announced/active/deprecated, Elasticsearch-indexed), Categorization (ordered), Inventory (stock-keeping variant of a product), Price (validity date range, quantity scale, VAT, promotion), Feature, PropertyGroup / Property / Value (typed: textual/numeric/flag), Productrelation, Supplyrelation, Recommendation.
- **Shop:** Order (state machine: basket, parked, archived_basket, accepted_offer, ordered, in_payment, payment_failed, paid, shipped), Lineitem, ShippingCost (per country and method), Address, BillingAddress (EU VAT number validation), Country, Gtc (versioned terms; acceptance is tracked on both user and order).
- **Sales:** Conversation, Message, Download, Link, Suggestion, Feedback, Offer (states in_progress, pending_approval, valid, invalid, accepted), Offeritem.
- **Contracting:** Contract, Contractitem, Consumableitem, Toner. Holds the calculation logic for monthly rates, balance, expenses and profit.
- **CMS:** Webpage (tree, slug, states draft/published/published_but_hidden/archived), PageTemplate (**DRYML/ERB stored in the DB and rendered at runtime**), ContentElement (CKEditor HTML, photo, document), PageContentElementAssignment, Folder (tree).
- **Blog/Podcast:** Blogpost, PostCategory (tree), Comment (threaded), Podcast (mp3/ogg), Chapter.
- **System:** User (roles as booleans: administrator, sales, sales_manager, contentmanager, productmanager; states inactive/guest/active), Constant (key/value settings), Logentry, Submission (contact form), Visit / Ahoy::Event (tracking).

#### Cross-cutting patterns
- **Translations:** `name_de` / `name_en` column pairs read through `traco`. Locales are de (default) and en.
- **Hobo lifecycles:** state machines with transitions restricted to particular users (e.g. `available_to: "User.sales"`).
- **Hobo permissions:** `*_permitted?` methods on every model.
- **Guest users:** every visitor automatically gets a real `User` row (surname "Gast", random email). The basket belongs to that user. Login via email link, password reset by key. A cleanup cron removes stale guests and empty baskets.
- **Special system users** are looked up by surname: "Job User", "Robot", "MPay24".
- **Trees:** `ancestry` gem, for categories, webpages, folders, post categories and comments.
- **Ordering:** `acts_as_list`.
- **Attachments:** Paperclip, with image styles.
- **Search:** Searchkick (Elasticsearch 1.x), with category facets/filters and price range filters.
- **Realtime:** private_pub over Faye, about 44 publish calls (chat, typing indicators, refreshes, consultant calls).
- **Background jobs:** delayed_job, plus cron/whenever for imports and cleanups.
- **PDF:** wicked_pdf (offers/orders).
- **Multi-domain:** separate domains for CMS, shop and podcast. A session handover uses a `remember_token` in the URL.
- **Customer-specific feature flags:** `config.erp == "mesonic"`, `config.payment == "mpay24"`, `config.icecat`, plus `Constant` keys (e.g. `display_only_brutto_prices`, `inventories_are_variations`).

#### External interfaces (from `mercator.wiki/images/schnittstellen.png`)
| Interface | Protocol | Phoenix candidate |
|---|---|---|
| Mesonic ERP | MSSQL over TDS (1433) | `tds` / `ecto_sql` TDS adapter, as a separate read-only Repo |
| mPAY24 | SOAP/HTTPS plus HTTP callback (IP-restricted) | Req plus a hand-built SOAP client, or another provider (see #14) |
| Icecat | XML over HTTP | Req plus an XML parser (Saxy/SweetXml), run as an Oban job |
| Bechlem | FTP download plus local MySQL DB | MyXQL repo, or import into Postgres (see #15) |
| Chat / cobrowsing | Faye websockets | Phoenix Channels / LiveView / PubSub |
| A/V chat | WebRTC with palava signalling plus Redis | Phoenix Channel as signalling server (see #12) |
| Search | Elasticsearch | Postgres FTS, or Meilisearch/Typesense (see #10) |
| Mail | SMTP via Postfix | Swoosh |
| Jobs | delayed_job on MySQL | Oban (Postgres) |

### Technology mapping (proposal)

| Rails / Hobo | Phoenix / Ash |
|---|---|
| Hobo models + `fields do` | Ash resources (AshPostgres) |
| Hobo lifecycles | `ash_state_machine` |
| `*_permitted?` | Ash policies (role checks on the actor) |
| Hobo auth, guest users, email key login | `ash_authentication` (password + magic link) plus a guest-user strategy (see #8) |
| paper_trail | `ash_paper_trail` |
| ancestry | Postgres `ltree` or `parent_id` with recursive CTEs |
| acts_as_list | `position` attribute plus reorder actions |
| traco `_de`/`_en` columns | Columns kept as they are, or a map/JSONB with a calculation (see #7) |
| Paperclip | Local or S3 storage plus image processing (see #11) |
| CKEditor | **Markdown** with a textarea editor and preview, no WYSIWYG (#13) |
| DRYML page templates in DB | A safe template language, e.g. Solid (Liquid), or fixed HEEx layouts (see #9) |
| w2ui / jQuery / fancytree admin UIs | LiveView + DaisyUI; AshAdmin for raw CRUD (see #16) |
| private_pub / Faye | Phoenix PubSub + LiveView |
| delayed_job / whenever | Oban + Oban.Plugins.Cron |
| wicked_pdf | ChromicPDF or Typst (see #17) |
| i18n YAML (de/en) | Gettext (default `de`) |
| Ahoy | Drop, or a simple event table (see #18) |
| Constants table | Keep as a resource; secrets go to `runtime.exs` / env vars |
| `vendor/customer` per-system repos | Runtime config, DaisyUI themes, feature flags (see #6) |
