defmodule MercatorWeb.OfferPrintController do
  @moduledoc """
  The printable offer (#99): a document page without the shop's navigation,
  for printing or saving as PDF in the browser (a Typst PDF follows, #17).
  `customer` for the customer's own offers, `staff` for the back office.
  """
  use MercatorWeb, :controller

  require Ash.Query

  alias Mercator.Accounts.Address
  alias Mercator.Consulting.{Offer, Offers, OfferTotals}

  @staff [:sales, :sales_manager, :administrator]

  def customer(conn, %{"id" => id}), do: show(conn, id, conn.assigns[:current_user])

  def staff(conn, %{"id" => id}) do
    case conn.assigns[:current_user] do
      %{roles: roles} = user when is_list(roles) ->
        if Enum.any?(roles, &(&1 in @staff)), do: show(conn, id, user), else: not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  defp show(conn, _id, nil), do: redirect(conn, to: ~p"/sign-in")

  defp show(conn, id, user) do
    case Offers.get(id, user) do
      {:ok, %Offer{} = offer} ->
        # the document is in the customer's language, also for staff
        Gettext.put_locale(MercatorWeb.Gettext, offer.locale)

        conn
        |> put_root_layout(html: {MercatorWeb.Layouts, :print})
        |> put_layout(false)
        |> render(:offer,
          offer: offer,
          address: billing_address(offer.customer_id),
          totals: OfferTotals.calculate(offer.items, offer.discount_percent),
          page_title: gettext("Offer %{number}", number: Offer.display_number(offer)),
          locale: offer.locale
        )

      _ ->
        not_found(conn)
    end
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> text("Not Found")

  defp billing_address(user_id) do
    Address
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.Query.sort(default_billing: :desc, inserted_at: :asc)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
