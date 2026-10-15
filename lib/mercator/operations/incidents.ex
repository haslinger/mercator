defmodule Mercator.Operations.Incidents do
  @moduledoc """
  Reporting and counting incidents (#105).

  The system calls `report/1` where it would otherwise only log an error.
  A report is never allowed to break the caller: errors while reporting are
  logged and swallowed. Changes are broadcast on the PubSub topic
  `"incidents"` as `:incidents_changed`, so the admin sidebar badge updates.
  """
  require Ash.Query
  require Logger

  alias Mercator.Operations.Incident

  @pubsub Mercator.PubSub
  @topic "incidents"

  @doc """
  Reports a problem. `attrs`: `:kind` (`:pdf`, `:email`, `:job`, `:payment`,
  `:other`), `:title`, `:description`, `:details`, and optionally
  `:customer_id`, `:order_id`, `:offer_id`, `:conversation_id` and a
  `:fingerprint` (default: kind, title and the linked record). If an open
  incident with the same fingerprint exists, it counts up instead.
  Returns `{:ok, incident}` or `:error`.
  """
  def report(attrs) do
    attrs = attrs |> Map.new() |> Map.put_new_lazy(:fingerprint, fn -> fingerprint(attrs) end)

    result =
      case open_with_fingerprint(attrs.fingerprint) do
        nil ->
          Ash.create(Incident, attrs, action: :report, authorize?: false)

        incident ->
          Ash.update(incident, Map.take(attrs, [:details]), action: :recur, authorize?: false)
      end

    case result do
      {:ok, incident} ->
        broadcast()
        {:ok, incident}

      {:error, error} ->
        Logger.error("Incident could not be reported: #{inspect(attrs)}: #{inspect(error)}")
        :error
    end
  rescue
    error ->
      Logger.error("Incident could not be reported: #{Exception.message(error)}")
      :error
  end

  @doc """
  Runs `fun` in the shop's default language: texts of system-reported
  incidents are stored in it, whoever triggered the problem.
  """
  def in_shop_locale(fun) do
    locale = Application.get_env(:mercator, MercatorWeb.Gettext)[:default_locale] || "de"
    Gettext.with_locale(MercatorWeb.Gettext, locale, fun)
  end

  @loads [:customer, :order, :offer, :conversation, :reported_by, :resolved_by]

  @doc "Incidents for the back office list; `filters` may hold `:state` and `:kind`."
  def list(actor, filters \\ %{}, page \\ [limit: 25]) do
    Incident
    |> Ash.Query.for_read(:search, Map.take(filters, [:state, :kind]), actor: actor)
    |> Ash.Query.load(customer: [], order: [])
    |> Ash.read!(page: page)
  end

  @doc """
  An incident with everything it points to. Read with the actor's policies;
  the linked records without (sales staff may not read user accounts).
  """
  def get(id, actor) do
    with {:ok, incident} <- Mercator.Operations.get_incident(id, actor: actor) do
      Ash.load(incident, @loads, authorize?: false)
    end
  end

  @doc "Staff record an incident (#107); `attrs` may link a customer, order, offer or conversation."
  def create(attrs, actor),
    do:
      Incident
      |> Ash.Changeset.for_create(:create, attrs, actor: actor)
      |> Ash.create()
      |> changed()

  @doc "Changes title, description or the resolution draft."
  def update(incident, attrs, actor),
    do: incident |> Ash.update(attrs, action: :update, actor: actor) |> changed()

  @doc "Resolves an incident with a resolution text."
  def resolve(incident, resolution, actor),
    do:
      incident
      |> Ash.update(%{resolution: resolution}, action: :resolve, actor: actor)
      |> changed()

  @doc "Opens a resolved incident again."
  def reopen(incident, actor),
    do: incident |> Ash.update(%{}, action: :reopen, actor: actor) |> changed()

  defp changed({:ok, incident}) do
    broadcast()
    {:ok, incident}
  end

  defp changed(error), do: error

  @doc "The number of open incidents the actor may see (for the sidebar badge)."
  def open_count(actor) do
    Incident
    |> Ash.Query.filter(state == :open)
    |> Ash.count!(actor: actor)
  end

  @doc "Receive `:incidents_changed` whenever an incident is reported or changed."
  def subscribe, do: Phoenix.PubSub.subscribe(@pubsub, @topic)

  @doc "Tells subscribers that incidents changed."
  def broadcast, do: Phoenix.PubSub.broadcast(@pubsub, @topic, :incidents_changed)

  defp open_with_fingerprint(fingerprint) do
    Incident
    |> Ash.Query.filter(state == :open and fingerprint == ^fingerprint)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end

  defp fingerprint(attrs) do
    subject =
      Enum.find_value([:order_id, :offer_id, :conversation_id, :customer_id], "", fn key ->
        attrs[key] && "#{key}=#{attrs[key]}"
      end)

    String.slice("#{attrs[:kind]}|#{attrs[:title]}|#{subject}", 0, 500)
  end
end
