defmodule Mercator.Sales do
  @moduledoc """
  Sales domain: baskets and (later) orders. See docs/checkout-design.md.

  Baskets belong either to a browser session (visitors, identified by a
  token from the session) or to a signed-in user (#8). They are accessed
  only through `Mercator.Sales.Baskets`, which scopes every operation to
  the given owner.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Mercator.Sales.Basket
    resource Mercator.Sales.BasketItem
  end
end
