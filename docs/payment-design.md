# Online payment (phase 7) – design

Agreed 2026-10-15. Decisions: #108 Mollie first (the easier
integration); #109 the provider's hosted payment page; #128 Mollie only: Stripe and
an embedded payment form are dropped; #110 online payment is one more
payment method, the concrete methods (cards, EPS, …) are chosen in the provider's
dashboard; #111 unpaid orders are left to staff; #112 freight costs are calculated
(final, not estimated); #113 full refunds only. mPAY24 and Liberapay are not used.

## 1. Goals

- A customer pays an order online right after placing it, on the provider's page.
- One deployment = one provider, chosen in config. The shop, the order states and the
  back office do not depend on the provider.
- Nothing gets lost: every payment status change is recorded; anything unexpected
  becomes an incident (#105).
- Testable without a real account (a fake provider in the tests) and with the
  provider's test mode (no fees, no real money).

## 2. Provider interface

A behaviour `Mercator.Payments.Provider`, implemented by `Mercator.Payments.Mollie`
and by the simulator (dev, tests, demo):

- `create_payment(order, urls)` → `{:ok, %{id, checkout_url, status}}`
  (`urls`: where the customer comes back, where the webhook goes)
- `fetch_payment(id)` → `{:ok, %{status, amount, method}}`
- `refund(payment, amount)` → `{:ok, refund_id}`

Statuses are mapped to our own: `open`, `pending`, `paid`, `failed`, `canceled`,
`expired`, `refunded`.

Providers are registered per deployment in config, with their credentials from the
environment; **administrators switch** between them in the back office
(`/admin/payment-providers`, the runtime setting `payment_provider`), or switch online
payment off. They do not configure anything there (2026-10-15). A payment keeps the
provider it was started with, so switching never breaks open payments.

```elixir
config :mercator, :payment_providers, [Mercator.Payments.Mollie]
# runtime.exs: MOLLIE_API_KEY (test_… or live_…), never in the repository
```

`Mercator.Payments.Simulator` is a provider without a provider: its payment page is
part of the shop, with a card form and test cards (`4242 4242 4242 4242` is paid,
`4000 0000 0000 0002` is declined, as at Stripe), EPS (fictional banks, a simulated
online banking with test login 12345678 / 1234, TAN 123456 confirms, 000000 is
rejected) and cancel. Every step says it is a simulation and that no real data may be
entered. Payments live in memory. Registered only in
dev, test and the demo, never in a real shop (customers could "pay" without paying).
It replaces a separate fake provider in the tests.

HTTP with `Req` (already a dependency); no provider SDK.

## 3. Data

- `PaymentMethod` gets `:online`, labelled "Online bezahlen" (with a hint such as
  "Karte, EPS, …" from config); enabled like the others in `config :mercator,
  :payment_methods`.
- A new resource `Mercator.Sales.OnlinePayment` (domain Sales): `order_id`, `provider`,
  `provider_id`, `status`, `amount`, `method` (e.g. `eps`, `creditcard`, as reported),
  `checkout_url`, timestamps. One order can have several attempts (after a failed or
  cancelled one); at most one is `paid`.
- The order keeps its states (`placed` → `paid` …); `mark_paid` is done by the system,
  with an order event "Online bezahlt (EPS)".

## 4. Flow

1. Checkout with "Online bezahlen": the order is placed as today (stock reserved), then
   a payment is created and the customer is redirected to the provider's page.
2. **Return** (`/account/orders/:number/payment`): the shop asks the provider for the
   status (never trusts URL parameters) and shows "paid", "processing" or "not paid –
   try again". This also makes local development work, where the provider cannot
   reach us.
3. **Webhook** (`POST /payments/mollie/webhook`, a plain controller): Mollie sends only
   the payment id; we fetch the status with our API key, so a forged call cannot fake
   anything. Idempotent: the same status twice changes nothing.
4. **Paid**: payment `paid`, order `mark_paid`, the order page and the back office show
   it; the customer gets an email "payment received".
5. **Failed / cancelled / expired**: the order stays `placed`; the order page offers
   "Pay now" again (a new attempt). The order is never cancelled automatically: as
   long as it is not cancelled, its goods stay reserved; staff decide (#111).
6. Online payment is offered only when the total is final, i.e. the shipping costs
   are not an estimate (#112).

Webhooks need a public URL: they are tested on the home server deployment (phase 8);
locally the return check (2.) is enough to go through the whole flow.

## 5. Back office

- The order page shows the payment attempts (status, method, provider id with a link
  to the provider's dashboard).
- Cancelling a paid online order offers "refund" (full amount) through the provider;
  the refund is recorded on the payment. Partial refunds are done in the provider's
  dashboard (#113).
- Unpaid online orders are visible as such in the order list (filter).

## 6. Incidents (#105)

Kind `payment`, linked to the order and customer:

- a webhook for a payment we do not know
- paid amount differs from the order total
- payment arrives for an order that is already cancelled (refund needed)
- provider API errors when creating a payment or refunding (the customer sees a
  friendly message, staff the details)

## 7. Testing

- `Mercator.Payments.Simulator` (registered in tests): checkout, return, webhook and
  refund are tested end to end without network.
- The Mollie adapter is tested against stubbed HTTP responses (`Req.Test`).
- Manually: Mollie test mode (test API key, Mollie's test page to choose "paid",
  "failed", "cancelled", …), first locally (return check), then on the home server
  with webhooks.

## 8. Freight costs (#112)

Freight costs are calculated per country zone, so the total is final at checkout and
can be paid online. First model: a fixed amount plus a percentage of the goods value
(gross), per rate:

```elixir
freight: [
  rates: [
    %{countries: ~w(AT), gross: "89", percent: "2"},
    %{countries: ~w(DE IT), gross: "189", percent: "3"}
  ]
]
```

`percent` works for every shipping method (parcel too) and is optional; `free_from`
stays. `estimate: true` remains possible per deployment; then online payment is not
offered for those orders, and staff confirm the costs as today. Later models (by
weight, by volume, with a maximum) can follow.

## 9. Steps (one commit each, with tests)

0. Freight costs: fixed amount plus percentage (#112); Biber Holz without estimates.
1. Provider behaviour, simulator, `OnlinePayment`, payment method `:online`, switching
   providers in the back office.
2. Checkout redirect, return page, "Pay now" again; order paid by the system.
3. ~~Mollie adapter~~ *(built 2026-10-15)*: `Mercator.Payments.Mollie` (API v2 with
   `Req`; create, fetch, refund; statuses mapped, `authorized` → pending, a fully
   refunded payment → refunded), registered in config.exs (dev: next to the
   simulator), key from `MOLLIE_API_KEY`; without a public HTTPS webhook URL
   (development) the payment is created without one. Tests with `Req.Test` stubs and
   an end-to-end webhook test. Tested by hand with the test key on 2026-10-15,
   locally (return page) and on biber.mittenin.at (webhook on paid and on expiry).
4. Back office: payment attempts on the order, refund on cancel, list filter;
   incidents; "payment received" email.
5. ~~Phase 8 (Docker on the home server), then the webhook test there~~ *(done
   2026-10-15)*.

## 10. Questions (answered 2026-10-15)

- ~~**#111 Unpaid online orders**~~ *(left to staff)* No automatic cancellation; as
  long as an order is not cancelled, its goods stay reserved. The order list can show
  unpaid online orders.
- ~~**#112 Freight orders**~~ *(calculate them)* Freight costs are derived
  automatically by country with a configurable model, first a fixed amount plus a
  percentage (section 8), so the total is final and can be paid online.
- ~~**#113 Refunds**~~ *(yes)* Full refunds on cancellation; partial refunds in the
  provider's dashboard.
