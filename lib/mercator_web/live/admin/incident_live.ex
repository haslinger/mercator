defmodule MercatorWeb.Admin.IncidentLive do
  @moduledoc """
  One incident (`/admin/incidents/:id`, #105): what happened, what it
  concerns, technical details; edit title and description, resolve it with
  a resolution, or open it again.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.IncidentComponents

  alias Mercator.Consulting.{Desk, Offer}
  alias Mercator.Operations.Incidents
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Incidents.get(id, socket.assigns.current_user) do
      {:ok, incident} ->
        {:ok, socket |> assign(:page_title, incident.title) |> assign_incident(incident)}

      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Incident not found."))
         |> push_navigate(to: ~p"/admin/incidents")}
    end
  end

  defp assign_incident(socket, incident) do
    socket
    |> assign(:incident, incident)
    |> assign(
      :form,
      to_form(
        %{
          "title" => incident.title,
          "description" => incident.description,
          "resolution" => incident.resolution
        },
        as: :incident
      )
    )
  end

  defp reload(socket) do
    {:ok, incident} = Incidents.get(socket.assigns.incident.id, socket.assigns.current_user)
    assign_incident(socket, incident)
  end

  # another person changed it, or it recurred
  @impl true
  def handle_info(:incidents_changed, socket), do: {:noreply, reload(socket)}

  # the resolve button submits the form with action=resolve
  @impl true
  def handle_event("save", %{"action" => "resolve", "incident" => params}, socket),
    do: resolve(socket, params)

  def handle_event("save", %{"incident" => params}, socket) do
    attrs = Map.take(params, ["title", "description", "resolution"])
    run(socket, &Incidents.update(&1, attrs, &2), gettext("Incident saved."))
  end

  def handle_event("reopen", _params, socket),
    do: run(socket, &Incidents.reopen/2, gettext("Incident opened again."))

  defp resolve(socket, params) do
    case String.trim(params["resolution"] || "") do
      "" ->
        {:noreply, put_flash(socket, :error, gettext("Please describe the resolution first."))}

      resolution ->
        socket = save_texts(socket, params)
        run(socket, &Incidents.resolve(&1, resolution, &2), gettext("Incident resolved."))
    end
  end

  # title and description edited before resolving are kept
  defp save_texts(socket, params) do
    attrs = Map.take(params, ["title", "description"])

    case Incidents.update(socket.assigns.incident, attrs, socket.assigns.current_user) do
      {:ok, incident} -> assign(socket, :incident, incident)
      _error -> socket
    end
  end

  defp run(socket, fun, message) do
    case fun.(socket.assigns.incident, socket.assigns.current_user) do
      {:ok, _incident} ->
        {:noreply, socket |> put_flash(:info, message) |> reload()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("This change is not possible."))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      locale={@locale}
      active="incidents"
    >
      <.link
        navigate={~p"/admin/incidents"}
        class="link link-hover text-sm w-fit"
        id="back-to-incidents"
      >
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("Incidents")}
      </.link>

      <div class="flex flex-wrap items-center gap-2">
        <h1 class="text-3xl font-bold" id="incident-title">{@incident.title}</h1>
        <.state_badge state={@incident.state} id="incident-state" />
        <.kind_badge kind={@incident.kind} />
      </div>

      <div class="grid gap-6 lg:grid-cols-[1fr_20rem]">
        <section class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <.form for={@form} id="incident-form" phx-submit="save">
              <.input field={@form[:title]} label={gettext("Title")} required />
              <.input
                field={@form[:description]}
                type="textarea"
                rows="5"
                label={gettext("Description")}
              />
              <.input
                field={@form[:resolution]}
                type="textarea"
                rows="4"
                label={gettext("Resolution")}
                placeholder={gettext("What was done about it?")}
              />
              <div class="mt-2 flex flex-wrap justify-end gap-2">
                <button type="submit" class="btn btn-sm" id="save-incident">
                  {gettext("Save")}
                </button>
                <button
                  :if={@incident.state == :open}
                  type="submit"
                  name="action"
                  value="resolve"
                  class="btn btn-success btn-sm"
                  id="resolve-incident"
                >
                  <.icon name="hero-check" class="size-4" /> {gettext("Resolve")}
                </button>
                <button
                  :if={@incident.state == :resolved}
                  type="button"
                  phx-click="reopen"
                  class="btn btn-sm"
                  id="reopen-incident"
                >
                  {gettext("Open again")}
                </button>
              </div>
            </.form>

            <details
              :if={@incident.details}
              class="collapse collapse-arrow mt-4 bg-base-200"
              id="incident-details"
            >
              <summary class="collapse-title text-sm font-semibold">
                {gettext("Technical details")}
              </summary>
              <div class="collapse-content">
                <pre class="overflow-x-auto text-xs whitespace-pre-wrap">{@incident.details}</pre>
              </div>
            </details>
          </div>
        </section>

        <aside class="card h-fit bg-base-100 shadow-sm" id="incident-facts">
          <div class="card-body gap-3 text-sm">
            <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1">
              <dt class="text-base-content/70">{gettext("Reported")}</dt>
              <dd>{Format.datetime(@incident.inserted_at)}</dd>
              <dt class="text-base-content/70">{gettext("By")}</dt>
              <dd>
                {if @incident.reported_by,
                  do: Desk.display_name(@incident.reported_by),
                  else: gettext("the system")}
              </dd>
              <dt :if={@incident.occurrences > 1} class="text-base-content/70">
                {gettext("Occurred")}
              </dt>
              <dd :if={@incident.occurrences > 1} id="incident-occurrences">
                {ngettext("1 time", "%{count} times", @incident.occurrences)}, {gettext(
                  "last %{time}",
                  time: Format.datetime(@incident.last_occurred_at)
                )}
              </dd>
              <dt :if={@incident.resolved_at} class="text-base-content/70">{gettext("Resolved")}</dt>
              <dd :if={@incident.resolved_at} id="incident-resolved">
                {Format.datetime(@incident.resolved_at)}
                <span :if={@incident.resolved_by}>
                  · {Desk.display_name(@incident.resolved_by)}
                </span>
              </dd>
            </dl>

            <div class="flex flex-col gap-1" id="incident-concerns">
              <.link
                :if={@incident.order}
                navigate={~p"/admin/orders/#{@incident.order.number}"}
                class="link"
                id="incident-order"
              >
                <.icon name="hero-shopping-bag" class="size-4" />
                {gettext("Order %{number}", number: @incident.order.number)}
              </.link>
              <.link
                :if={@incident.offer}
                navigate={~p"/admin/offers/#{@incident.offer.id}"}
                class="link"
                id="incident-offer"
              >
                <.icon name="hero-document-currency-euro" class="size-4" />
                {gettext("Offer %{number}", number: Offer.display_number(@incident.offer))}
              </.link>
              <.link
                :if={@incident.conversation}
                navigate={~p"/admin/desk/#{@incident.conversation.id}"}
                class="link"
                id="incident-conversation"
              >
                <.icon name="hero-chat-bubble-left-right" class="size-4" /> {gettext("Conversation")}
              </.link>
              <span :if={@incident.customer} id="incident-customer">
                <.icon name="hero-user" class="size-4" />
                {Desk.display_name(@incident.customer)}
                <a href={"mailto:#{@incident.customer.email}"} class="link text-xs">
                  {@incident.customer.email}
                </a>
              </span>
            </div>
          </div>
        </aside>
      </div>
    </Layouts.admin>
    """
  end
end
