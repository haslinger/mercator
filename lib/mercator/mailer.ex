defmodule Mercator.Mailer do
  @moduledoc """
  Swoosh mailer. The sender address is configured per deployment:

      config :mercator, :mail_from, {"Shop name", "noreply@shop.example"}
  """
  use Swoosh.Mailer, otp_app: :mercator
  use Gettext, backend: MercatorWeb.Gettext

  require Logger

  alias Mercator.Operations.Incidents

  @doc "The `{name, address}` used as sender for all system emails."
  def default_from do
    Application.fetch_env!(:mercator, :mail_from)
  end

  @doc """
  Sends an email that is sent directly, not by a background job (the
  sign-in emails, #120): if it cannot be delivered, the error is logged and
  reported as an incident instead of raised, so the action (e.g. the
  registration) still succeeds. `purpose` (`:confirmation`,
  `:password_reset`, `:magic_link`) names the email in the incident;
  `customer_id` links the user if there is one. Returns `:ok` or `:error`.
  """
  def deliver_or_report(email, purpose, customer_id \\ nil) do
    case deliver(email) do
      {:ok, _meta} ->
        :ok

      {:error, reason} ->
        recipients = Enum.map_join(email.to, ", ", fn {_name, address} -> address end)
        Logger.error("#{purpose} email to #{recipients} failed: #{inspect(reason)}")

        Incidents.in_shop_locale(fn ->
          Incidents.report(%{
            kind: :email,
            title: title(purpose),
            description: gettext("Not sent to %{recipients}.", recipients: recipients),
            details: inspect(reason),
            customer_id: customer_id
          })
        end)

        :error
    end
  end

  defp title(:confirmation), do: gettext("Confirmation email could not be sent")
  defp title(:password_reset), do: gettext("Password reset email could not be sent")
  defp title(:magic_link), do: gettext("Sign-in link email could not be sent")
end
