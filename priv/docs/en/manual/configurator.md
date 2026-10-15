---
title: Configurator
roles: [productmanager]
order: 52
---
Configurable products are made to measure: the customer chooses options and enters dimensions, and the shop calculates the price at once. Examples from the demo are the made-to-measure table top (per m²), structural timber cut to size (per m³) and battens cut to length (per running metre). It is set up in the **Configurator** tab of the product editor; the product must be of the kind **configurable** (see [Products](products.md)).

## The building blocks

### Pricing

What the base price is calculated by:

| Pricing | Measure per piece | needs the dimensions |
|---|---|---|
| per m³ (length × width × thickness) | length × width × thickness | length, width, thickness |
| per m² (length × width) | length × width | length, width |
| per running metre (length) | length | length |
| per piece | 1 | none |

Dimensions are entered in millimetres and converted to metres for the calculation.

### Options

An option is a question to the customer. It is either a **choice** (e.g. wood species: oak, walnut, stone pine) or a **number** (e.g. length in mm). Every option has a **role in the price**:

| Role in the price | Kind | Effect |
|---|---|---|
| **Base price** | choice | each choice carries a *base price per unit (net)*, e.g. oak €320 per m². Exactly one such option per product |
| **Surcharge** | choice | each choice may have a *surcharge in %* (of the base amount) and/or a *surcharge per piece (net)*, e.g. "planed +15 %", "live edge +€90"; a choice without surcharge costs nothing extra |
| **Length**, **Width**, **Thickness** | number | the dimensions for the pricing, with *minimum*, *maximum*, *step* and *default value* |
| **No effect on price** | either | information for production only, e.g. "drill holes" |

Every option and choice has a **key** (e.g. `species`, `oak`). It is stored in baskets and orders and makes up the configuration number; do not change it once the product is on sale. The displayed names (German, English) can be changed at any time.

Among choices one is the **default choice**, numbers have a **default value**: together they form the **default configuration**, which the product page starts with and whose price category pages show as the "from" price. Drag options and choices to order them; the shop shows them in that order.

### Product settings

| Setting | Effect |
|---|---|
| **Round dimensions up to (mm)** | dimensions are rounded up to a multiple, e.g. 10 = whole centimetres: 1795 mm becomes 1800 mm |
| **Minimum billed quantity** | the smallest quantity charged (in m³, m², lfm or pieces), for the whole line |
| **Minimum order value (net)** | a line below it is raised to this value |
| **Cutting fee per piece (net)** | a fixed amount per piece for cutting |

## How the shop calculates

1. Round the dimensions up, then work out the measure per piece from the pricing.
2. Billed measure = measure per piece × number of pieces, at least the *minimum billed quantity*.
3. **Base amount** = billed measure × base price of the chosen base-price choice.
4. **Percent surcharges** apply to the base amount; **surcharges per piece** and the **cutting fee** are multiplied by the number of pieces.
5. If the sum is below the **minimum order value**, the difference is added as a line of its own.
6. VAT from the tax class, everything rounded to cents.

### Example: table top made to measure

Pricing per m², dimensions rounded up to 10 mm, minimum order value €150. Ordered: 1 piece, oak, 1795 × 905 mm, thickness 40 mm, bevelled edge, white oil.

| Line | Calculation | net |
|---|---|---|
| Dimensions | rounded up to 1800 × 910 mm = 1.638 m² | |
| Base price oak | 1.638 m² × €320.00 | €524.16 |
| Thickness 40 mm | +25 % of the base amount | €131.04 |
| Bevelled edge | +€35.00 × 1 piece | €35.00 |
| White oil | +8 % of the base amount | €41.93 |
| **Total** | | **€732.13** |

Plus 20 % VAT (€146.43), gross **€878.56**.

A small stone pine top of 600 × 400 mm (0.24 m² × €280 = €67.20) is below the minimum order value: the line "minimum order value" raises it by €82.80 to €150.00 net.

## What the customer sees

- **Product page:** choices with their price effect (e.g. "Oak – €384.00/m²" gross, "40 mm (+25 %)"), dimension fields with the allowed range, the number of pieces and below it the calculation line by line. Every change recalculates at once; invalid input (too large, too small, not a number) is shown right at the field.
- **Configuration number:** the article number plus a short code, e.g. `BH-TISCHPLATTE-MASS-D2FF1D`. The same configuration always gives the same number, so production can recognise identical orders.
- **Basket:** the line with its configuration as text; the price is recalculated every time it is shown.
- **Order and order confirmation:** the configuration as text in German and English, the configuration number and the price at the time.
- **Offers:** configured products get into an offer through **Take over basket**: the customer configures in the shop, the consultant takes over the basket and adjusts prices and discounts.

## Tips

- Start with the base-price option and the dimensions, then the surcharges. The preview in the tab calculates the default configuration and shows what is still missing ("Not calculable yet: …").
- Limit the dimensions with minimum and maximum to what production can make; the shop allows nothing else.
- Percent surcharges apply to the base amount only, not to each other: +25 % and +8 % together are +33 % of the base amount.
