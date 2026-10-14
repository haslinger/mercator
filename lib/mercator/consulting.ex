defmodule Mercator.Consulting do
  @moduledoc """
  Guided selling (phase 6, docs/guided-selling-design.md): conversations
  between customers and consultants, and (later) offers.

  Customers reach their conversations through `Mercator.Consulting.Conversations`,
  which scopes everything to the owner (a visitor session or a user, #94),
  like `Mercator.Sales.Baskets`.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Mercator.Consulting.Conversation
    resource Mercator.Consulting.Message
    resource Mercator.Consulting.Offer
    resource Mercator.Consulting.OfferItem
  end
end
