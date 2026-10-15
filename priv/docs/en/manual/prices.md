---
title: Variants and prices
roles: [productmanager]
order: 51
---
The **Variants & prices** tab (for simple products **Price & stock**) of the product editor; [Products](products.md) explains the product kinds.

## Variants

A variant is what is actually sold, e.g. "Decking board larch 28 × 145 mm, 4 m". Drag variants to order them; the first is preselected in the shop.

| Field | Meaning |
|---|---|
| Article no. | the variant's unique article number |
| Name | what the variant is called in the shop, German and English |
| Unit | the unit it is sold in (see below) |
| Stock | quantity in stock; **empty = made to order** (no stock, made or procured) |
| Delivery time | text for the customer, e.g. "2–3 weeks" |
| Weight (kg) | stored; the shop does not calculate shipping costs from it yet |
| Active | inactive variants cannot be chosen in the shop |

Ordering reduces the stock, cancelling puts it back. Customers cannot order more than is in stock; "made to order" variants are unlimited.

### Units

Piece, running metre (lfm), m², m³, solid cubic metre (fm), stacked cubic metre (rm), loose cubic metre (srm), kg, t, pallet and sack. Pieces, pallets and sacks take whole quantities only, the others also decimals, e.g. 2.5 m³ of firewood.

## Prices

Each variant has one or more price rows, always **net per unit**; the shop shows them with the VAT of the tax class.

| Field | Meaning |
|---|---|
| Net price per unit | the price |
| From quantity | graduated price: applies from this order quantity |
| Valid from / Valid until | a price for a limited time (both optional) |
| Promotion price | a special price; the regular price is shown next to it crossed out |

**Which price applies:**

1. Rows that are valid today and whose "from quantity" is at most the ordered quantity qualify.
2. Among them, the one with the highest "from quantity" wins (the graduated price); on a tie, the cheaper one.
3. A promotion price only wins if it is cheaper than the regular one; then the shop shows it with the regular price crossed out and the **Sale** badge.

Example: €6.90 from 1 piece, €5.90 from 50 pieces. Ordering 60 pieces costs €5.90 each. The product page shows the graduated prices.

On category pages, products with several variants show "from" and the lowest price.

## What changes apply to

- **Baskets** always use current prices; a price change applies at once.
- **Orders** keep the texts, prices and VAT they were placed with.
- **Offers** keep their prices; **Copy** takes the new list prices (see *Offers*).
