defmodule MercatorWeb.OrderPdfController do
  @moduledoc """
  The order confirmation as PDF (#17). The order is read with the signed-in
  user's policies: customers get their own orders, sales staff all.
  """
  use MercatorWeb, :controller

  alias Mercator.Sales
  alias MercatorWeb.Documents

  def show(conn, %{"number" => number}) do
    case conn.assigns[:current_user] do
      nil -> redirect(conn, to: ~p"/sign-in")
      user -> send_pdf(conn, Sales.get_order_by_number(number, actor: user, load: [:items]))
    end
  end

  defp send_pdf(conn, {:ok, order}) do
    case Documents.order_pdf(order) do
      {:ok, pdf} ->
        send_download(conn, {:binary, pdf},
          filename: Documents.order_filename(order),
          content_type: "application/pdf",
          disposition: :attachment
        )

      {:error, message} ->
        Documents.report_failure(
          Documents.order_filename(order),
          message,
          %{order_id: order.id, customer_id: order.user_id},
          :download
        )

        conn
        |> put_status(:internal_server_error)
        |> text(gettext("The PDF could not be created."))
    end
  end

  defp send_pdf(conn, {:error, _error}),
    do: conn |> put_status(:not_found) |> text("Not Found")
end
