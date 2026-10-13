defmodule Mercator.Sales do
  @moduledoc """
  Sales domain: baskets, terms (GTC) and (later) orders. See docs/checkout-design.md.

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

    resource Mercator.Sales.Order do
      define :list_my_orders, action: :mine
      define :get_order_by_number, action: :by_number, args: [:number]
    end

    resource Mercator.Sales.OrderItem

    resource Mercator.Sales.Gtc do
      define :current_gtc, action: :current, not_found_error?: false
      define :create_gtc, action: :create
    end
  end
end
