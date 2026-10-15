defmodule MercatorWeb.PaymentWebhookController do
  @moduledoc """
  Webhooks of payment providers (docs/payment-design.md, section 4): the
  provider posts the id of a payment whose status changed (Mollie: form
  field `id`). We never trust the request: `Mercator.Payments.notify/2`
  fetches the status from the provider itself. Answers 200 for every
  payment, known or not (unknown ones become incidents), so the provider
  does not retry forever; 404 for providers this shop does not have.
  """
  use MercatorWeb, :controller

  alias Mercator.Payments

  def create(conn, %{"provider" => key, "id" => id}) when is_binary(id) do
    case Payments.provider(key) do
      nil ->
        send_resp(conn, 404, "")

      provider ->
        Payments.notify(provider.key(), id)
        send_resp(conn, 200, "")
    end
  end

  def create(conn, _params), do: send_resp(conn, 400, "")
end
