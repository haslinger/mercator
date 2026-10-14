defmodule MercatorWeb.Presence do
  @moduledoc """
  Who is at the sales desk (guided selling, #95): consultants with the desk
  open are tracked on `"desk:presence"` with `%{available: boolean, name: ...}`.
  Kept in memory across the cluster by Phoenix.Presence, not in the database.
  """
  use Phoenix.Presence, otp_app: :mercator, pubsub_server: Mercator.PubSub

  @topic "desk:presence"

  def topic, do: @topic

  @doc "Number of consultants at the desk who are available."
  def available_count do
    @topic
    |> list()
    |> Enum.count(fn {_id, %{metas: metas}} -> Enum.any?(metas, & &1.available) end)
  end
end
