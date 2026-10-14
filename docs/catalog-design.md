# Catalogue design (phase 2)

Status: agreed (2026-10-13): all questions in section 9 answered as recommended. Decisions this builds on: #7 (translations), #39 (product kinds), #40 (units), #41 (demo catalogue). Open questions continue at **#49**.

## 1. Scope of phase 2

- New domain `Mercator.Catalog`: categories, products, variants, prices, units, tax classes, properties, highlights, product relations, configurable products.
- Public pages: category navigation, category page with filters, product page with variant selection and a **configurator with live price**, search.
- Demo catalogue for Biber Holz in the seeds (8 top categories, about 30 subcategories, 80–120 products, de/en, placeholder images).
- **Not** in phase 2: basket and checkout (phase 3; the product page gets a disabled "add to basket" button), back-office editing (phase 4; the catalogue is filled by seeds until then), product images and uploads (#11).

## 2. What changes compared with Rails

| Rails | Here | Why |
|---|---|---|
| `title_de` / `title_en` columns | one translated JSONB attribute per field (#7) | |
| `Inventory` (stock-keeping unit) with `Price` rows | **every product has at least one variant**; prices belong to variants | a simple product is just a product with one variant, so cart, stock and pricing code exist once |
| `Productrelation`, `Supplyrelation`, `Recommendation` (3 tables) | one `ProductRelation` with `kind` (`:related`, `:accessory`, `:recommended`) and an optional reason | the same structure three times |
| `Feature` (bullet points, own table) | `highlights`: a list of translated strings on the product | they are only ever shown with their product |
| Category `usage` (`mercator`, `auto`, `orphans`, `squeel`) | dropped | these served the ERP import (#15) |
| Neuheiten / Topseller (ERP flags as categories) | product flags `new?` / `bestseller?` (badges and filters); "on sale" is derived from promotion prices (#53) | |
| Filter caches on the category (`filters`, `filtermin`, `filtermax`) | computed by queries (aggregates) | no stale caches, no reindex job |
| FIFO selection among inventories | the customer chooses the variant | wood is chosen by species and dimensions, not by stock batch |
| Elasticsearch / Searchkick | Postgres full-text search (#10, #56) | |
| Lifecycles `new/announced/active/deprecated` | Ash state machine `draft → active → discontinued` (#52) | |

## 3. Resources (`Mercator.Catalog`)

### Translated text (#7)

`Mercator.Translated` is an Ash type: a map `%{"de" => …, "en" => …}` stored as JSONB. `Mercator.Translated.t(value, locale)` returns the text in the locale, falling back to `de`. Forms get one input per locale. Full-text search uses one expression index per language (`to_tsvector('german', title->>'de')`, `to_tsvector('english', title->>'en')`).

### Category

| Attribute | Type | Notes |
|---|---|---|
| `name`, `description`, `long_description` | translated | |
| `slug` | string, unique | from the German name; used in URLs `/categories/bauholz` |
| `parent_id`, `path` | tree (#49) | |
| `position` | integer | order among siblings |
| `state` | `:draft` / `:active` / `:hidden` | `hidden`: reachable by link, not in the navigation |
| `image` | placeholder for now (#11) | |

Many-to-many with products through `Categorization` (`position` = order of products within the category). A category page shows the products of the category **and its descendants**.

### Product

| Attribute | Type | Notes |
|---|---|---|
| `number` | string, unique | article number, e.g. `BH-KVH-001` |
| `title`, `subtitle`, `description`, `long_description`, `warranty` | translated | |
| `highlights` | list of translated strings | bullet points (Rails `Feature`) |
| `slug` | string, unique | `/products/kvh-fichte` |
| `kind` | `:simple` / `:variants` / `:configurable` (#39) | |
| `state` | `:draft` → `:active` → `:discontinued` (#52) | only `active` is visible to customers |
| `tax_class` | reference (#51) | |
| `new?`, `bestseller?` | boolean | badges, filters (#53) |
| `shipping` | `:parcel` / `:freight` / `:pickup_only` / `:none` | houses and full pallets: freight; services: none. Replaces Rails' `not_shippable`. |

### Variant (Rails: Inventory)

| Attribute | Type | Notes |
|---|---|---|
| `product_id` | | at least one per product |
| `number` | string, unique | SKU, e.g. `BH-TD-LAE-28-145-4000` |
| `name` | translated | e.g. "Lärche, 28 × 145 mm, 4 m" |
| `options` | map | e.g. `%{"species" => "larch", "length_mm" => 4000}`, used by the variant selector |
| `unit` | unit (#40) | sales unit, e.g. piece, m², rm |
| `stock` | decimal, nullable | `nil` = not tracked / made to order (#54) |
| `delivery_time` | translated | "sofort lieferbar", "2–3 Wochen" |
| `weight_kg` | decimal | for freight calculation in phase 3 |
| `position`, `state` | | |

### Price

| Attribute | Type | Notes |
|---|---|---|
| `variant_id` | | |
| `amount` | decimal (4 decimals), **net** (#50) | price per unit of the variant |
| `min_quantity` | decimal, default 1 | graduated prices (Rails `scale_from`/`scale_to`): the row with the highest `min_quantity` ≤ ordered quantity applies |
| `valid_from`, `valid_until` | date, nullable | time-limited prices |
| `promotion?` | boolean | promotion price; the regular price is shown crossed out |

Price determination: `Catalog.price_for(variant, quantity, date)` returns net, VAT and gross amounts. Customer-specific prices are out of scope (#57).

### Unit (#40)

`Mercator.Catalog.Unit` is an Ash enum with a symbol, translated names, a quantity dimension and whether decimals are allowed:

| Unit | Symbol | Dimension | Decimals |
|---|---|---|---|
| piece | Stk. | count | no |
| running metre (Laufmeter) | lfm | length | yes |
| square metre | m² | area | yes |
| cubic metre | m³ | volume | yes |
| Festmeter (solid wood) | fm | volume | yes |
| Raummeter (stacked wood) | rm | volume | yes |
| Schüttraummeter (loose wood) | srm | volume | yes |
| kilogram | kg | mass | yes |
| tonne | t | mass | yes |
| pallet | Pal. | count | no |
| sack | Sack | count | no |

Conversions (e.g. rm ↔ fm, which depends on the species) are out of scope.

### Tax class (#51)

`TaxClass`: name and rate. Every product has one. Prices are stored net; display net or gross is a shop setting (#50).

Austrian rates for the Biber Holz demo, per information from the Wirtschaftskammer (2026-10-13):

| Tax class | Rate | Products in the demo |
|---|---|---|
| Normalsatz | 20 % | everything not listed below, **including unprocessed logs and saw logs (Sägerundholz) that are not sold directly as fuel** |
| ermäßigt | 13 % | **firewood, wood pellets, Christmas trees** |

Briquettes, wood chips and sawdust sold as fuel are treated like firewood (13 %) in the demo. That is an assumption, not confirmed by the Wirtschaftskammer; sawdust sold as animal bedding gets 20 %.

### Properties (Rails PropertyGroup / Property / Value)

- `PropertyGroup`: name (translated), position. E.g. "Abmessungen", "Holz", "Oberfläche".
- `Property`: group, name, `kind` (`:text` / `:number` / `:boolean`), unit (for numbers), `filterable?`, position.
- `ProductProperty`: product, property, plus a text (translated), number or boolean value.

The product page shows them as a table grouped by property group. Filterable properties become filters on the category page, with their values computed from the products shown.

### Product relations

`ProductRelation`: product, related product, `kind` (`:related` / `:accessory` / `:recommended`), reason (translated, optional), position. E.g. terrace boards → accessory: terrace screws, substructure.

## 4. Configurable products (#39, #55)

Wood is sold cut to size. The customer chooses options and enters dimensions, and the price is calculated.

**Options** (`ProductOption`, per product):

- `kind: :choice` with `OptionChoice`s, e.g. species: spruce / larch / oak / Swiss stone pine; surface: rough-sawn / planed / oiled; drying: fresh / air-dried / kiln-dried.
- `kind: :number`, e.g. length, width, thickness in mm, with min, max, step and default.

**Pricing model** (per product, `pricing`):

| Model | Formula | Example |
|---|---|---|
| `:per_volume` | base price per m³ × L × W × T × quantity | construction timber, glulam |
| `:per_area` | base price per m² × L × W × quantity | three-layer panels, table tops |
| `:per_length` | base price per lfm × L × quantity | battens, profile boards |
| `:per_unit` | base price × quantity | standard parts with options |

- The **base price** comes from the choice of one designated option (normally the species, e.g. oak 1 450 €/m³, spruce 520 €/m³).
- Other choices add **surcharges**, either absolute (e.g. "+ 8 € per piece") or relative (e.g. "kiln-dried + 12 %").
- **Rules:** a minimum billing quantity (e.g. at least 0.1 m³), a minimum order value, rounding of dimensions (e.g. to whole cm) and an optional cutting fee per piece.

**Calculation:** `Catalog.quote(product, selections, quantity)` returns a quote with a breakdown (base price, volume or area, surcharges, fees, net, VAT, gross). The product page recalculates live via LiveView on every input. In phase 3, the basket line stores the configuration and the quote as a snapshot.

Each configuration has a generated article number (product number plus a short hash of the selections), so orders stay traceable.

Out of scope for now: the **house configurator** (floor plan, wall structure, bill of materials). That would be its own feature later; houses come as variants (sizes) first.

## 5. Permissions

- Read: everybody sees `active` categories and products. Drafts and discontinued products are visible to productmanager and administrator.
- Write: productmanager and administrator. The UI for this comes in phase 4; until then the actions are covered by tests and used by the seeds.

## 6. Public UI (LiveView, DaisyUI)

- **Navigation:** top categories in the navbar (dropdown), subcategories on the category page.
- **Category page** `/categories/:slug`:
  - breadcrumb and subcategory tiles
  - product grid with price "ab …", badges (new, bestseller, sale)
  - filters (price range, filterable properties, species) and sorting
  - filters live in the URL, so filtered views can be bookmarked
- **Product page** `/products/:slug`:
  - placeholder images, highlights, description, property table
  - accessories and related products
  - variant selector (only valid combinations selectable)
  - configurator with live price and breakdown
  - graduated prices table and delivery time
- **Search** `/search?q=…`: full text over title, number, description (de/en), plus prefix search on article numbers.

## 7. Biber Holz demo catalogue (#41)

| Top category | Subcategories (examples) | Product kinds and units |
|---|---|---|
| **Holzhäuser & Bausätze** | Blockhäuser, Gartenhäuser, Carports & Pergolen, Saunahäuser | variants by size (piece), freight |
| **Bauholz** | Konstruktionsvollholz (KVH), Brettschichtholz (BSH), Kanthölzer & Balken, Latten & Staffeln | configurable per m³ / lfm (species, cross-section, length) |
| **Platten & Bretter** | 3-Schicht-Platten, Rauspund & Schalung, Hobeldielen, Leimholz | configurable per m², variants |
| **Terrasse, Fassade & Garten** | Terrassendielen, Fassadenschalung, Zäune & Sichtschutz, Hochbeete | variants (species × length), accessories (screws, substructure) |
| **Edelholz & Tischplatten** | Eiche, Nuss, Zirbe, Tischplatten nach Maß | configurable per m² / piece (species, dimensions, edge, oil) |
| **Möbel & Wohnen** | Zirbenbetten, Tische & Bänke, Hocker, Küchenhelfer (cutting boards) | simple and variants (piece) |
| **Brennholz & Energie** | Scheitholz, Pellets, Briketts, Hackschnitzel, Säge- & Hobelspäne | variants in rm, srm, t, sack, pallet, kg ("from the house down to sawdust") |
| **Forst & Rundholz** | Rundholz ab Waldstraße, Christbäume, Zuschnitt- & Hobelservice | fm, piece; services without shipping. VAT contrast: round timber 20 %, firewood and Christmas trees 13 % (#51) |

The products get realistic names, dimensions, species and Austrian price levels. Prices are invented but plausible.

## 8. Implementation order (one commit each, with tests)

1. `Mercator.Translated` type with form component and helpers
2. Units, tax classes, the `Catalog` domain
3. Categories with tree, categorizations
4. Products, variants, prices, price determination (simple + variants)
5. Properties, highlights, product relations
6. Demo catalogue seeds (simple + variants)
7. Public pages: navigation, category page with filters, product page
8. Search
9. Configurable products: options, pricing, quote, configurator UI
10. Demo seeds for configurable products

## 9. Open questions

- ~~**#49 Category tree storage:**~~ *(answered 2026-10-13: as recommended)* `parent_id` plus a materialised path in Postgres `ltree` (fast "all descendants" queries for category pages; AshPostgres supports `ltree`), or `parent_id` only with recursive queries? Recommendation: `ltree`.
- ~~**#50 Net or gross:**~~ *(answered 2026-10-13: as recommended)* store prices net, and display net or gross by shop setting (B2C shop: gross, B2B: net)? Biber Holz demo: gross. Later per customer group, e.g. trade customers net.
- ~~**#51 Tax classes**~~ *(answered 2026-10-13, see section 3 "Tax class")*: 20 % standard; 13 % for firewood, wood pellets and Christmas trees; unprocessed logs / saw logs not sold as fuel 20 % (information from the Wirtschaftskammer).
- ~~**#52 States:**~~ *(answered 2026-10-13: as recommended)* products `draft → active → discontinued` (Rails' `announced` dropped), categories `draft / active / hidden`. OK?
- ~~**#53 Neuheiten / Topseller / Aktion:**~~ *(answered 2026-10-13: as recommended)* product flags `new?` and `bestseller?`, set by hand; "on sale" derived from current promotion prices. Shown as badges and filters, plus optional virtual categories ("Neuheiten") on the start page?
- ~~**#54 Stock:**~~ *(answered 2026-10-13: as recommended)* tracked per variant (`stock`, `nil` = made to order or not tracked), delivery time as text per variant. No reservations or FIFO. Enough for now?
- ~~**#55 Configurator scope:**~~ *(answered 2026-10-13: as recommended)* the pricing models in section 4 (volume, area, length, unit; base price from one option; surcharges; minimum quantities; rounding; cutting fee). Enough for the demo, with the house configurator as a later separate feature?
- ~~**#56 Search (#10):**~~ *(answered 2026-10-13: as recommended)* Postgres full-text search with per-language indexes, no extra service?
- ~~**#57 Customer-specific prices:**~~ *(answered 2026-10-13: as recommended)* Rails took them from the ERP. Out of scope for phase 2; later price lists per customer group?
