defmodule Mercator.Mailer do
  @moduledoc """
  Swoosh mailer. The sender address is configured per deployment:

      config :mercator, :mail_from, {"Shop name", "noreply@shop.example"}
  """
  use Swoosh.Mailer, otp_app: :mercator

  @doc "The `{name, address}` used as sender for all system emails."
  def default_from do
    Application.fetch_env!(:mercator, :mail_from)
  end
end
