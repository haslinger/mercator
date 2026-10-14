# Basket and checkout design (phase 3)

Status: agreed (2026-10-13): all questions in section 9 answered as suggested. Builds on #8 (session basket for visitors, moved to the user at login), #14 (online payment later), #50 (prices net, displayed gross), #51 (VAT per tax class), #55 (configurable products). Open questions continue at **#64**.

## 1. Scope

- **Basket:** add to basket from the product page (simple products, variants, configurations), change quantities, remove items, live totals.
- **Checkout:** sign-in, addresses, shipping method, payment method, acceptance of the terms (GTC), review, order.
- **After the order:** confirmation page and email, order history under "Mein Konto".
- **Back office:** order list and order detail for staff, with state changes (paid, shipped, cancelled).
- **Not in phase 3:** online payment (#14, later), offers and guided selling (phase 4 of the roadmap), PDF invoices (#17), ERP connection.

## 2. What changes compared with Rails

| Rails | Here | Why |
|---|---|---|
| Every visitor is a user row; the basket is an `Order` in state `basket` | **Basket** as its own resource, owned by a session token (visitor) or a user (#8) | no guest users in the user table |
| Basket and order are one table with ~10 states | **Basket** and **Order** are separate: the order is created at checkout as an **immutable snapshot** (texts, prices, VAT, addresses) | an order never changes when products, prices or addresses change later |
| Billing and shipping addresses copied field by field onto the order | **Address book** per user (`Address`), copied onto the order as a snapshot | |
| Payment methods as lifecycle transitions (cash, ATM, prepayment, e-payment) | Payment method as an attribute plus a state machine for the order | |
| Shipping costs per country and method in a table | **Shipping rates** per shipping method and country zone, possibly free above a threshold (#65) | |
| GTC acceptance stored on user and order, compared by version date | **GTC** versions; acceptance stored on the order (version and time) | |

## 3. Resources (new domain `Mercator.Sales`)

### Basket and basket items

- `Basket`: `session_token` (visitor) or `user_id`, timestamps. One open basket per user.
- `BasketItem`: basket, variant, quantity (decimal for measured units), and for configurable products the **configuration** (selections) plus configuration number.
- Prices are **not stored** in the basket. They are always calculated live (Pricing / Configurator), so the basket shows current prices until the order.
- **Moving at login** (#8): items of the visitor basket are added to the user's basket (same variant or configuration → quantities added), and the visitor basket is deleted.
- Abandoned visitor baskets are deleted after 30 days by an Oban job.

### Order and order items (snapshot)

- `Order`:
  - number (#68), user
  - billing and shipping address (copied)
  - shipping method, payment method
  - totals: net, VAT per rate, gross, shipping costs
  - GTC version accepted and time of acceptance
  - customer note
  - state (§4)
- `OrderItem`:
  - article number, title (de/en), configuration text, unit, quantity
  - unit price net, VAT rate, line net/VAT/gross
  - reference to variant and product (nullable, may be deleted later)

### Address book

- `Address`: user, name, company, street, postcode, city, country, phone, VAT ID (B2B, optional), flags `default_billing` / `default_shipping`.
- Countries: an ISO code list, with the delivery countries per shop configured (Biber Holz: AT, DE, IT, CH; #65).

### Terms (GTC)

- `Gtc`: version (date), text de/en. The newest version is the current one.
- Demo: placeholder GTC for Biber Holz. Later it's maintained in the CMS.

## 4. Order states

```
placed ─► confirmed ─► paid ─► shipped ─► completed
   │          │          │
   └──────────┴──────────┴─► cancelled
```

- **placed:** the customer has ordered; confirmation email sent.
- **confirmed:** staff have checked it (e.g. freight costs, delivery date for made-to-order items).
- **paid:** payment received. With prepayment that comes before shipping; with invoice after.
- **shipped / completed:** picked up or delivered.
- **cancelled:** with a reason.
- Stock is reduced when the order is placed (for variants with tracked stock, #54) and restored on cancellation.

## 5. Checkout steps (one LiveView, steps on one page)

1. **Sign in:** via magic link or password; visitors can register in the process. The basket moves over (#66).
2. **Addresses:** billing address (address book or new), optionally a different shipping address.
3. **Shipping method:** only the methods possible for all items, e.g. freight items exclude parcel, `pickup_only` forces pickup. Costs come from the shipping rates (#65).
4. **Payment method** (#64).
5. **Review:** all items with prices, shipping costs, VAT per rate, total; GTC checkbox; note; "Zahlungspflichtig bestellen" button.
6. **Confirmation:** page plus email (order number, items, payment instructions such as the bank details for prepayment).

## 6. Back office

- `/admin/orders` (sales, sales_manager, administrator): list with filters (state, period, search by order number or customer).
- Order detail: items, addresses, totals, state changes with notes, cancellation.
- *Implemented (step 6, 2026-10-14):* every state change is stored as an `OrderEvent` (from/to state, note, staff member) and shown as the order's history; cancelling needs a reason and puts tracked stock back; confirming an order with estimated freight costs requires the final shipping costs, and totals and VAT lines are recalculated from the order items.

## 7. Demo (Biber Holz)

- Shipping rates and payment methods as in #64 and #65, delivery countries AT, DE, IT, CH.
- A few demo orders for Karl Luchs and Lena Igel in different states, so the order history and back office have content.

## 8. Implementation order (one commit each, with tests)

1. Sales domain: basket, basket items, add to basket (product page), basket page with live prices, moving at login
2. Address book (account page) and countries
3. Shipping methods and rates, payment methods, GTC
4. Checkout steps and order snapshot, stock reduction, confirmation page and email
5. Order history in the account
6. Back office: orders list and detail with state changes
7. Demo data: shipping rates, GTC, demo orders

## 9. Open questions

- ~~**#64 Payment methods for now**~~ *(answered 2026-10-13: as suggested)* (online payment comes later, #14): **prepayment** (bank details in the confirmation), **invoice** (only for customers that staff have approved, e.g. trade customers) and **payment on pickup** (cash or card, only with pickup)? Or fewer, or others?
- ~~**#65 Shipping costs:**~~ *(answered 2026-10-13: as suggested)*
  - **Parcel:** flat rate per country zone (e.g. AT €9.90, DE/IT €14.90, CH €24.90), free from a configurable order value (e.g. €250 in AT).
  - **Freight:** flat rate per zone as a "from" price (e.g. AT from €89), with the actual costs confirmed by staff (order state "confirmed").
  - **Pickup:** free, at the sawmill (address from the brand config).
  - OK, or a different model, e.g. by weight?
- ~~**#66 Checkout only for signed-in customers?**~~ *(answered 2026-10-13: as suggested)* My recommendation: **yes**. The magic link keeps it painless (enter email, click the link, continue), and the order history, address book and later consultation (offers) need an account anyway. The alternative is a guest checkout with email only, which is more code, and customers would have no order overview.
- ~~**#67 Delivery countries:**~~ *(answered 2026-10-13: as suggested)* AT, DE, IT, CH for the demo? Orders from CH (outside the EU) would need export rules (VAT-free delivery, customs). My suggestion: **leave out CH for now**, and treat VAT for deliveries into the EU like domestic sales (Austrian VAT, which applies to private customers below the EU distance-selling threshold). That's a simplification you should check with the Wirtschaftskammer or your tax advisor. *(User: fine for the demo; a real customer's rules are implemented per deployment.)*
- ~~**#68 Order numbers:**~~ *(answered 2026-10-13: as suggested)* `<prefix>-<year>-<sequential number>`, e.g. `BH-2026-00042`, with the prefix from the brand config? Sequential without gaps per year.
- ~~**#69 B2B:**~~ *(answered 2026-10-13: as suggested)* do customers with a VAT ID (other EU countries) get a reverse charge invoice (net, without Austrian VAT)? That needs a VAT ID check (VIES); Rails used `valvat`. My suggestion: **later**, and for now show the VAT ID only on the order.
- ~~**#70 Order email:**~~ *(answered 2026-10-13: as suggested)* for now as text/HTML email with all items and payment instructions, without a PDF (PDF invoice later, #17)?
