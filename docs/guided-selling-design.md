# Guided selling design (phase 6) — draft

Status: **agreed 2026-10-14** (#94–#101 answered, section 6).

## 1. Goal

What set Mercator apart from a plain shop: customers can talk to a consultant while they shop, and the consultant can recommend products, show pages, share documents and make an **individual offer**, which the customer orders with one click. For Biber Holz: "Wie viel Lärche brauche ich für 40 m² Terrasse?", "Machen Sie mir ein Angebot für das Gartenhaus inklusive Fundament und Lieferung?"

## 2. What the Rails app did

From the models, the sales subsite and the sales process diagram (`mercator.wiki/images/verkaufsprozess.png`):

| Rails | What it did |
|---|---|
| `Conversation` | Customer, consultant, name; started from the shop; has messages, links, downloads, suggestions, offers |
| `Message` | Text chat between customer, consultant and a "robot" sender; realtime via Faye (private_pub) |
| Consultant assignment | Consultants log in to the sales desk (`logged_in`, `call_priority`); a new conversation rang the available consultants one after the other (5 s each); nobody → the robot apologised |
| `Link` (cobrowsing) | The consultant sent a URL; the customer's browser opened it |
| `Download` | Files (photos, documents) shared in the conversation |
| `Suggestion` | Products recommended by the consultant, shown in the conversation |
| Audio/video chat | A link to an external WebRTC service (palava) |
| `Feedback` | The customer could leave feedback on a conversation |
| `Offer` + `Offeritem` | Billing/shipping address, validity date, items (from products or free text, price, VAT, delivery time, per-item discount), overall discount; states in progress → pending approval → valid → invalid (expired) → revised; accepted offers became an order |

## 3. Proposal: one domain `Mercator.Consulting`

### 3.1 Conversations and messages

- **Conversation:** customer (a signed-in user, or a visitor session like the basket, #94), consultant (staff with the `sales` role), subject (optional, e.g. "Gartenhaus Kompakt"), the page it was started from, state `waiting` (no consultant yet) / `active` / `closed`, last activity.
- **Message:** sender (customer, consultant, or system), text, optional attachment (image or PDF, stored like media library files), read flag per side.
- **Realtime** with Phoenix PubSub + LiveView: no extra service. Typing indicator and read receipts are cheap to add.
- **Customer side:** a chat panel that can be opened on every shop page ("Beratung"), plus a prominent "Beraten lassen" button on product pages (starting the conversation with the product as subject). The conversation stays open while the customer moves through the shop.
- **Offline:** if no consultant answers, the conversation simply waits; customers get an email when the reply comes and they are not online (#97).

### 3.2 The sales desk (back office)

- `/admin/desk` for `sales` / `sales_manager`: a status switch **available / away**, the queue of waiting conversations, "my" conversations and all open ones. After signing in, consultants land on the desk and are available at once (`?available=true`); administrators without a sales role land on `/admin`. A page that asked for the sign-in (e.g. the checkout) wins.
- **Assignment (#95):** a new conversation notifies all available consultants (sound + browser notification while the desk is open); the first one to take it gets it. Others can still join or take over.
- **Conversation view** for the consultant: the chat, and next to it the customer context: **current page** in the shop (live), **basket** contents, previous **orders**, earlier conversations, addresses.
- **Recommend a product:** search, then post it into the chat as a product card with "In den Warenkorb" (for configurable products with a prepared configuration).
- **Share a link** (#96, the Rails "cobrowsing"): a page of the shop or any website, shown as a card in the chat and opened in a new tab.
- **Share files:** images and PDFs (uploaded, or from the media library) in the chat, with a preview.

### 3.3 Offers

- **Offer:** customer, consultant, conversation (optional), number (like order numbers, e.g. `BH-A-2026-00012`), validity date, items, overall discount, note, addresses (from the customer's address book).
- **Offer item:** a product variant (with configuration for configurable products, priced by the configurator) **or** a free-text position (e.g. "Fundament, Montage"), quantity, unit, unit price (from the price list, overridable), discount per item, VAT rate, delivery time.
- **States** (AshStateMachine): `draft` → (`pending_approval` →) `sent` → `accepted` / `expired` / `withdrawn`; a sent or expired offer can be **revised** into a new draft version (the history of versions stays).
- **Approval (#98):** offers whose discount exceeds a limit need a sales manager's approval before they are sent.
- **Customer side:** sent offers in the account (`/account/offers`) and as a card in the conversation; "Angebot annehmen" puts the items into the basket **at the offer's prices**, and the normal checkout (addresses, shipping, payment, GTC) follows; the order refers to the offer.
- **Offer document (#99):** a printable web page; PDF with Typst later (#17).

### 3.4 What we leave out or postpone

- **Audio/video chat (#100):** later, or a link to an external video service.
- Feedback: 1–5 stars and a comment per conversation (#101), part of step 6.
- Real co-browsing (the consultant sees the customer's screen) – not planned; "current page" and "show a page" cover the common case.

## 4. Resources (domain `Mercator.Consulting`)

`Conversation`, `Message`, `Offer`, `OfferItem`, plus a presence of available consultants (Phoenix.Presence, not a table). Policies: customers see their own conversations and sent offers; `sales` sees and works on conversations and offers; `sales_manager` approves; administrators everything.

## 5. Implementation order (one commit each, with tests)

1. Consulting domain: Conversation and Message; customer chat panel (signed-in customers and visitors, #94), realtime.
2. Sales desk: availability (presence), queue, taking conversations, chat, notifications in the desk.
3. Customer context for the consultant (current page, basket, orders), product recommendations, "show a page", files.
4. ✅ Offers: resource and editor in the desk (products, configurations, free positions, discounts, approval). Configured items come from the customer's basket; products added from the catalogue use the default configuration. Addresses are chosen at checkout, not on the offer.
5. ✅ Offers for customers: account and conversation, accept → checkout; order refers to the offer. *Changed while building:* accepting does not go through the basket but straight into the checkout with the offer as the source (its items at its prices, free-text items included, quantities fixed); the basket stays untouched. Offer items without a product are delivered like freight.
6. ✅ Emails: reply notifications for offline customers, offer sent, approval requests, new conversations while nobody is at the desk (#97); printable offer page (#99, Typst PDF later with #17); rating with 1–5 stars and a comment (#101).
7. ✅ Biber Holz demo data (`Mercator.Seeds.Consulting`): closed, active and waiting conversations (ratings, a callback request), offers sent, revised and ordered, expired and waiting for approval.

## 6. Questions (answered 2026-10-14)

- ~~**#94 Visitors**~~ *(yes)* Visitors start conversations tied to their browser session, like the basket; moved to their account on sign-in. Offers need an account.
- ~~**#95 Assignment**~~ *(all available consultants are notified, the first one takes it)* The customer sees a **countdown of 2 minutes**; if nobody takes the conversation by then: "Sorry, nobody is available right now – may we contact you?" with a small form for **email or phone** (a callback request). The conversation keeps waiting and can still be taken.
- ~~**#96 Sharing**~~ It was never meant as screen sharing: the intention was to show e.g. a manual that is online, in an iframe, which was unreliable (many sites forbid being embedded). Now: **links** appear in the chat as a card and open in a new tab; **documents** (PDFs from the media library or uploaded into the chat) show with a preview in the chat. Screen sharing would be nice but goes together with #100.
- ~~**#97 Emails**~~ *(yes)* Customers get an email about a reply when they are not online; consultants about new conversations when nobody is at the desk.
- ~~**#98 Approval**~~ *(yes)* A sales manager approves offers with a discount above a configurable limit (default 10 %, per item or overall).
- ~~**#99 Offer document**~~ *(web page now)* A printable offer page (print styles); a PDF with Typst later, together with order confirmations (#17).
- ~~**#100 Audio/video**~~ *(postponed)* Note: Elixir WebRTC (`ex_webrtc`, Software Mansion) would allow self-hosted audio, video and screen sharing; some networks then need a TURN relay server.
- ~~**#101 Feedback**~~ *(yes)* Customers rate a conversation with 1 to 5 stars and an optional comment.
