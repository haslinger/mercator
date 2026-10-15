---
title: Orders
roles: [sales, sales_manager]
order: 10
pages: [admin/orders, admin/orders/:number]
---
**Sales → Orders** lists all orders, newest first, 25 per page.

## Finding orders

- **Search:** order number, the customer's name, company or email address.
- **Filters:** state, period (from – to) and **Unpaid online**: orders paid online that are not paid yet. The list marks them "unpaid".

## An order

The page shows the customer, the payment method, the customer's note, the items, addresses and totals. At the top are the **order confirmation (PDF)** and **Report incident**, for when something is wrong with the order.

## Changing the state

An order goes through these states:

| State | Meaning |
|---|---|
| Placed | just ordered, the goods are reserved |
| Confirmed | checked and accepted |
| Paid | payment received (for online payment the shop sets this itself) |
| Shipped | on its way; for pickup orders this state is **Ready for pickup** |
| Completed | delivered or collected |
| Cancelled | called off; the goods go back into stock |

The **Change state** box only offers the steps possible now, such as **Confirm**, **Mark as paid**, **Mark as shipped** (for pickup **Report ready for pickup**), **Complete** and **Cancel**.

- **Note:** stays internal. Only the reason for a cancellation is sent to the customer, and cancelling needs one.
- **Inform the customer by email:** confirming, paying, shipping or reporting ready for pickup, and cancelling send an email. Untick it to skip the email for one step.
- **Freight costs:** if the freight costs were only estimated at checkout, **Confirm** asks for the final shipping costs, and the total and VAT are recalculated.
- **History:** every change is listed with time, person and note.

## Online payments

For orders paid with **Pay online**, the page lists every payment attempt: time, status, method, amount and the payment's id at the provider, with a link to it in the provider's dashboard. If an attempt failed, the customer can choose **Pay now** on their own order page.

- **Cancelling a paid order:** the box "When cancelling: refund the online payment" is ticked, and the full amount goes back through the payment provider.
- **Refunding later:** if a cancelled order is paid, the payment attempt has a **Refund** button.
- Whether a refund has been paid out is shown in the provider's dashboard (the link at the payment attempt). If the provider refuses a refund, an incident is created.
