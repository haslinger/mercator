defmodule MercatorWeb.CheckoutController do
  @moduledoc """
  Entry to the checkout for visitors: remembers the checkout as the page to
  return to after signing in (#66), then shows the sign-in page.
  """
  use MercatorWeb, :controller

  def sign_in(conn, _params) do
    conn
    |> put_session(:return_to, ~p"/kasse")
    |> redirect(to: ~p"/sign-in")
  end
end
