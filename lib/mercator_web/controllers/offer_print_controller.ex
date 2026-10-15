defmodule MercatorWeb.OfferPrintController do
  @moduledoc """
  The printable offer (#99): a document page without the shop's navigation,
  for printing, and the offer as a Typst PDF (#17). `customer` / `customer_pdf`
  for the customer's own offers, `staff` / `staff_pdf` for the back office.
  """
  use MercatorWeb, :controller

  alias Mercator.Consulting.{Offer, Offers, OfferTotals}
  alias MercatorWeb.Documents

  @staff [:sales, :sales_manager, :administrator]

  def customer(conn, %{"id" => id}), do: as_customer(conn, id, &show/2)
  def customer_pdf(conn, %{"id" => id}), do: as_customer(conn, id, &pdf/2)
  def staff(conn, %{"id" => id}), do: as_staff(conn, id, &show/2)
  def staff_pdf(conn, %{"id" => id}), do: as_staff(conn, id, &pdf/2)

  defp as_customer(conn, id, fun), do: with_offer(conn, id, conn.assigns[:current_user], fun)

  defp as_staff(conn, id, fun) do
    case conn.assigns[:current_user] do
      %{roles: roles} = user when is_list(roles) ->
        if Enum.any?(roles, &(&1 in @staff)),
          do: with_offer(conn, id, user, fun),
          else: not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  defp with_offer(conn, _id, nil, _fun), do: redirect(conn, to: ~p"/sign-in")

  defp with_offer(conn, id, user, fun) do
    case Offers.get(id, user) do
      {:ok, %Offer{} = offer} -> fun.(conn, offer)
      _ -> not_found(conn)
    end
  end

  defp show(conn, offer) do
    # the document is in the customer's language, also for staff
    Gettext.put_locale(MercatorWeb.Gettext, offer.locale)

    conn
    |> put_root_layout(html: {MercatorWeb.Layouts, :print})
    |> put_layout(false)
    |> render(:offer,
      offer: offer,
      address: Documents.billing_address(offer.customer_id),
      totals: OfferTotals.calculate(offer.items, offer.discount_percent),
      page_title: gettext("Offer %{number}", number: Offer.display_number(offer)),
      locale: offer.locale
    )
  end

  defp pdf(conn, offer) do
    case Documents.offer_pdf(offer) do
      {:ok, pdf} ->
        # shown in the browser's PDF viewer (a new tab), not saved silently;
        # the shop's CSP (object-src 'none') would block that viewer
        conn
        |> delete_resp_header("content-security-policy")
        |> send_download({:binary, pdf},
          filename: Documents.offer_filename(offer),
          content_type: "application/pdf",
          disposition: :inline
        )

      {:error, message} ->
        Documents.report_failure(
          Documents.offer_filename(offer),
          message,
          %{offer_id: offer.id, customer_id: offer.customer_id},
          :download
        )

        conn
        |> put_status(:internal_server_error)
        |> text(gettext("The PDF could not be created."))
    end
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> text("Not Found")
end
