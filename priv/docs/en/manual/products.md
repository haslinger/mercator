---
title: Products
roles: [productmanager]
order: 50
pages: [admin/products, admin/products/new, admin/products/:id]
---
**Catalogue → Products** is where you maintain the range.

## The list

Search by title or article number, filter by category (including subcategories), state and product kind. Products can be **activated** or **discontinued** right in the list; a link leads to the product in the shop.

| State | Meaning |
|---|---|
| Draft | work in progress, not visible in the shop |
| Active | visible and orderable in the shop |
| Discontinued | no longer in the range |

**New product** asks for article number, title, product kind and tax class, then opens the product editor.

## Product kinds

| Kind | What the customer chooses | Price |
|---|---|---|
| simple | nothing | one price |
| with variants | a variant, e.g. length 4 m or 5 m | per variant, with graduated and promotion prices |
| configurable | options and dimensions, e.g. wood species and length × width × thickness | calculated, made to order |

**Change kind** switches the kind; the tabs follow at once. Nothing is lost; what no longer fits is only hidden.

## The product editor

- **General:** title, subtitle and descriptions in German and English (Markdown), highlights (one per line), article number, address in the shop (made from the title), tax class, shipping method, the **New** and **Bestseller** flags, and the categories.
- **Price & stock** (simple products) or **Variants & prices:** sort variants by dragging; per variant stock, delivery time, weight and prices, net or gross, with graduated prices, validity and promotion price.
- **Item & delivery time** and **Configurator** (configurable products): the pricing model (per m³, m², running metre or piece), the options and their choices, each with a base price or surcharge, minimum quantities and a cutting fee; a preview calculates an example price.
- **Images:** drop several images at once; they are resized and stored. The first image is the main one; drag to change the order.
- **Properties:** values such as wood species or thickness, grouped; they appear on the product page and as filters on category pages.
- **Relations:** accessories, recommendations (with a reason) and similar products, found by a search.
