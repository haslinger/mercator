---
title: Products
roles: [productmanager]
order: 50
pages: [admin/products, admin/products/new, admin/products/:id]
---
**Catalogue → Products** is where you maintain the range. Prices and variants are described in [Variants and prices](prices.md), made-to-measure products in [Configurator](configurator.md).

## The list

Search by title or article number, filter by category (including subcategories), state and product kind. Products can be **activated** or **discontinued** right in the list; a link leads to the product in the shop.

| State | Meaning |
|---|---|
| Draft | work in progress, not visible in the shop |
| Active | visible and orderable in the shop; needs at least one variant |
| Discontinued | no longer in the range |

**New product** asks for article number, title, product kind and tax class, then opens the product editor.

## Product kinds

Every product has at least one variant, which carries the article number, unit, stock and prices. The product kind decides what the customer chooses:

| Kind | Choice in the shop | Price | Stock |
|---|---|---|---|
| simple | nothing | one price | tracked (or "made to order") |
| with variants | a variant, e.g. length 4 m or 5 m | per variant, with graduated and promotion prices | per variant |
| configurable | options and dimensions, e.g. wood species and length × width | calculated by the configurator | none, made to order |

A product has either variants or a configurator, not both. To offer a board from stock and also cut to size, create two products and relate them (**Relations** tab).

**Change kind** switches the kind; the tabs follow at once. Nothing is lost; what no longer fits is only hidden. A product with several variants cannot become a simple one while the variants exist.

## The product editor

| Tab | Content |
|---|---|
| **General** | title, subtitle and descriptions in German and English (Markdown), highlights (one per line), article number, address in the shop (made from the title), tax class, shipping method, the **New** and **Bestseller** flags, categories |
| **Price & stock** | for simple products: the one variant with its prices |
| **Variants & prices** | for products with variants, see [Variants and prices](prices.md) |
| **Item & delivery time** | for configurable products: article number, unit, delivery time, no prices |
| **Configurator** | for configurable products, see [Configurator](configurator.md) |
| **Images** | drop several images at once; they are stored resized. The first is the main image; drag to change the order |
| **Properties** | values such as wood species or thickness, grouped; shown on the product page and used as filters on category pages |
| **Relations** | accessories, recommendations (with a reason) and similar products, found by a search; shown on the product page |

## Shipping and VAT

- **Shipping method:** parcel, freight or pickup only. A freight item in the basket rules out parcel shipping; a pickup item forces pickup.
- **Tax class:** sets the VAT rate, see *Tax classes*. Prices are maintained net and shown gross in the shop.
