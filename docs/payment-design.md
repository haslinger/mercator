# Online payment (phase 7) – design

Draft of 2026-10-15, for discussion. Decisions so far: #108 Mollie first (the easier
integration), Stripe later; #109 the provider's hosted payment page first, an embedded
payment form later (as if it were a third provider); #110 online payment is one more
payment method, the concrete methods (cards, EPS, …) are chosen in the provider's
dashboard. mPAY24 and Liberapay are not used.

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
(later `Stripe`, and the embedded variant):

- `create_payment(order, urls)` → `{:ok, %{id, checkout_url, status}}`
  (`urls`: where the customer comes back, where the webhook goes)
- `fetch_payment(id)` → `{:ok, %{status, amount, method}}`
- `refund(payment, amount)` → `{:ok, refund_id}`

Statuses are mapped to our own: `open`, `pending`, `paid`, `failed`, `canceled`,
`expired`, `refunded`.

Config per deployment:

```elixir
config :mercator, :payment_provider, Mercator.Payments.Mollie
# runtime.exs: MOLLIE_API_KEY (test_… or live_…), never in the repository
```

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
   "Pay now" again (a new attempt).

Webhooks need a public URL: they are tested on the home server deployment (phase 8);
locally the return check (2.) is enough to go through the whole flow.

## 5. Back office

- The order page shows the payment attempts (status, method, provider id with a link
  to the provider's dashboard).
- Cancelling a paid online order offers "refund" (full amount) through the provider;
  the refund is recorded on the payment.
- Unpaid online orders are visible as such in the order list (filter).

## 6. Incidents (#105)

Kind `payment`, linked to the order and customer:

- a webhook for a payment we do not know
- paid amount differs from the order total
- payment arrives for an order that is already cancelled (refund needed)
- provider API errors when creating a payment or refunding (the customer sees a
  friendly message, staff the details)

## 7. Testing

- `Mercator.Payments.Fake` (config in tests): payments with scripted statuses, so
  checkout, return, webhook and refund are tested end to end without network.
- The Mollie adapter is tested against stubbed HTTP responses (`Req.Test`).
- Manually: Mollie test mode (test API key, Mollie's test page to choose "paid",
  "failed", "cancelled", …), first locally (return check), then on the home server
  with webhooks.

## 8. Steps (one commit each, with tests)

1. Provider behaviour, fake provider, `OnlinePayment`, payment method `:online`.
2. Checkout redirect, return page, "Pay now" again; order paid by the system.
3. Mollie adapter (create, fetch, webhook controller) with stubbed tests; manual test
   in test mode locally.
4. Back office: payment attempts on the order, refund on cancel, list filter;
   incidents; "payment received" email.
5. Phase 8 (Docker on the home server), then the webhook test there.
6. Later: Stripe; the embedded payment form.

## 9. Open questions

- **#111 Unpaid online orders:** the stock is reserved while the customer pays. If a
  payment never succeeds, cancel the order automatically after a while (e.g. 2 days,
  configurable, with an email) or leave it to staff?
- **#112 Freight orders** have only estimated shipping costs at checkout. Offer online
  payment only when the total is final, and for freight let the customer pay online
  after staff confirmed the costs ("Pay now" in the confirmation email and on the
  order page)?
- **#113 Refunds:** full refunds only (on cancellation), and partial refunds stay in
  the provider's dashboard?
