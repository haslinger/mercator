defmodule MercatorWeb.Admin.IncidentIndexLive do
  @moduledoc """
  Incidents in the back office (`/admin/incidents`, #105): open ones first
  by default, filter by state and kind, 25 per page. `:new` records an
  incident by hand (#107); `?order=<number>`, `?offer=<id>`,
  `?conversation=<id>` or `?customer=<id>` link it from where it was started.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.IncidentComponents

  alias Mercator.Consulting.{Conversation, Desk, Offer, Offers}
  alias Mercator.Operations.{Incident, Incidents}
  alias Mercator.Sales.Order
  alias MercatorWeb.Format

  require Ash.Query

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Incidents"), customer_query: "", customers: [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:filter_params, Map.take(params, ["state", "kind"]))
      |> assign(:state, parse(params["state"] || "open", [:open, :resolved]))
      |> assign(:kind, parse(params["kind"], Incident.kinds()))
      |> assign(:page, max(parse_int(params["page"]), 1))
      |> load()

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    links = links(params)

    socket
    |> assign(:links, links)
    |> assign(:link_labels, link_labels(links))
    |> assign(:customer_query, "")
    |> assign(:customers, [])
    |> assign(:form, to_form(%{"title" => "", "description" => ""}, as: :incident))
  end

  defp apply_action(socket, _action, _params), do: assign(socket, :form, nil)

  defp load(socket) do
    filters = %{state: socket.assigns.state, kind: socket.assigns.kind}

    result =
      Incidents.list(socket.assigns.current_user, filters,
        limit: @per_page,
        offset: (socket.assigns.page - 1) * @per_page,
        count: true
      )

    socket
    |> assign(:count, result.count)
    |> assign(:pages, max(ceil(result.count / @per_page), 1))
    |> stream(:incidents, result.results, reset: true)
  end

  # "all" (or anything unknown) means no filter
  defp parse(value, allowed), do: Enum.find(allowed, &(to_string(&1) == value))

  defp parse_int(nil), do: 1

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 1
    end
  end

  # the record the incident is about, from the query string
  defp links(params) do
    order =
      params["order"] &&
        Order |> Ash.Query.filter(number == ^params["order"]) |> Ash.read_one!(authorize?: false)

    offer = get(Offer, params["offer"])
    conversation = get(Conversation, params["conversation"])

    %{
      order_id: id(order),
      offer_id: id(offer),
      conversation_id: id(conversation),
      customer_id:
        params["customer"] || Enum.find_value([order, offer, conversation], &customer_id/1)
    }
  end

  defp id(nil), do: nil
  defp id(record), do: record.id

  defp customer_id(%Order{user_id: id}), do: id
  defp customer_id(%{customer_id: id}), do: id
  defp customer_id(nil), do: nil

  defp get(_resource, nil), do: nil

  defp get(resource, id) do
    case Ash.get(resource, id, authorize?: false) do
      {:ok, record} -> record
      _not_found -> nil
    end
  end

  defp link_labels(links) do
    [
      links.order_id &&
        gettext("Order %{number}", number: get(Order, links.order_id).number),
      links.offer_id &&
        gettext("Offer %{number}",
          number: Offer.display_number(get(Offer, links.offer_id))
        ),
      links.conversation_id && gettext("Conversation"),
      links.customer_id &&
        Desk.display_name(get(Mercator.Accounts.User, links.customer_id))
    ]
    |> Enum.filter(& &1)
  end

  @impl true
  def handle_info(:incidents_changed, socket), do: {:noreply, load(socket)}

  @impl true
  def handle_event("filter", params, socket) do
    query = params |> Map.take(["state", "kind"]) |> Map.reject(fn {_k, v} -> v == "" end)
    {:noreply, push_patch(socket, to: ~p"/admin/incidents?#{query}")}
  end

  def handle_event("find_customer", %{"q" => query}, socket),
    do: {:noreply, assign(socket, customer_query: query, customers: Offers.find_customers(query))}

  def handle_event("pick_customer", %{"id" => id}, socket) do
    links = Map.put(socket.assigns.links, :customer_id, id)

    {:noreply,
     assign(socket,
       links: links,
       link_labels: link_labels(links),
       customers: [],
       customer_query: ""
     )}
  end

  def handle_event("save", %{"incident" => params}, socket) do
    attrs =
      params
      |> Map.take(["title", "description"])
      |> Map.merge(Map.new(socket.assigns.links, fn {k, v} -> {to_string(k), v} end))

    case Incidents.create(attrs, socket.assigns.current_user) do
      {:ok, incident} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Incident recorded."))
         |> push_navigate(to: ~p"/admin/incidents/#{incident.id}")}

      {:error, error} ->
        {:noreply,
         assign(socket, :form, to_form(params, as: :incident, errors: form_errors(error)))}
    end
  end

  defp form_errors(%Ash.Error.Invalid{errors: errors}) do
    for %{field: field, message: message} = error <- errors, field do
      {field, {message, Map.to_list(Map.new(error.vars || []))}}
    end
  end

  defp form_errors(_error), do: []

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
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Incidents")}</h1>
        <div class="flex items-center gap-3">
          <span class="text-sm text-base-content/70" id="incident-count">
            {ngettext("1 incident", "%{count} incidents", @count)}
          </span>
          <.link patch={~p"/admin/incidents/new"} class="btn btn-primary btn-sm" id="new-incident">
            <.icon name="hero-plus" class="size-4" /> {gettext("New incident")}
          </.link>
        </div>
      </div>

      <form id="incident-filters" phx-change="filter" class="flex flex-wrap gap-2">
        <select name="state" class="select select-sm w-40" id="filter-state">
          <option value="all" selected={is_nil(@state)}>{gettext("All states")}</option>
          <option :for={state <- [:open, :resolved]} value={state} selected={@state == state}>
            {state_label(state)}
          </option>
        </select>
        <select name="kind" class="select select-sm w-48" id="filter-kind">
          <option value="">{gettext("All kinds")}</option>
          <option :for={kind <- Incident.kinds()} value={kind} selected={@kind == kind}>
            {kind_label(kind)}
          </option>
        </select>
      </form>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
        <table class="table">
          <thead>
            <tr>
              <th>{gettext("Incident")}</th>
              <th class="hidden md:table-cell">{gettext("Concerns")}</th>
              <th>{gettext("State")}</th>
              <th class="text-right">{gettext("Last occurred")}</th>
            </tr>
          </thead>
          <tbody id="incidents" phx-update="stream">
            <tr class="hidden only:table-row" id="no-incidents">
              <td colspan="4" class="text-center text-base-content/70">
                {gettext("No incidents. All is well.")}
              </td>
            </tr>
            <tr
              :for={{dom_id, incident} <- @streams.incidents}
              id={dom_id}
              class="hover:bg-base-200"
            >
              <td>
                <.link navigate={~p"/admin/incidents/#{incident.id}"} class="link font-semibold">
                  {incident.title}
                </.link>
                <div class="flex flex-wrap items-center gap-1 text-xs text-base-content/70">
                  <.kind_badge kind={incident.kind} />
                  <span :if={incident.occurrences > 1}>
                    {ngettext("1 time", "%{count} times", incident.occurrences)}
                  </span>
                </div>
              </td>
              <td class="hidden md:table-cell text-sm">
                <span :if={incident.order}>{incident.order.number}</span>
                <span :if={incident.customer} class="block text-base-content/70">
                  {Desk.display_name(incident.customer)}
                </span>
              </td>
              <td><.state_badge state={incident.state} /></td>
              <td class="text-right text-sm whitespace-nowrap">
                {Format.datetime(incident.last_occurred_at)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@pages > 1} class="join self-center" id="incident-pages">
        <.link
          :for={page <- 1..@pages}
          patch={~p"/admin/incidents?#{Map.put(@filter_params, "page", page)}"}
          class={["join-item btn btn-sm", page == @page && "btn-active"]}
          id={"incident-page-#{page}"}
        >
          {page}
        </.link>
      </div>

      <div :if={@form} class="modal modal-open" id="new-incident-modal">
        <div class="modal-box max-w-2xl">
          <h2 class="text-lg font-bold">{gettext("New incident")}</h2>

          <div :if={@link_labels != []} class="mt-2 flex flex-wrap gap-1" id="incident-links">
            <span :for={label <- @link_labels} class="badge badge-outline">{label}</span>
          </div>

          <div :if={is_nil(@links.customer_id)} class="mt-3">
            <form id="customer-search" phx-change="find_customer" phx-submit="find_customer">
              <label class="input input-sm w-full">
                <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
                <input
                  type="search"
                  name="q"
                  value={@customer_query}
                  placeholder={gettext("Customer (optional): email or name")}
                  phx-debounce="300"
                />
              </label>
            </form>
            <ul class="menu w-full p-0" id="customer-results">
              <li :for={customer <- @customers}>
                <button
                  type="button"
                  phx-click="pick_customer"
                  phx-value-id={customer.id}
                  id={"customer-#{customer.id}"}
                >
                  <span class="font-medium">{customer.name || customer.email}</span>
                  <span :if={customer.name} class="text-xs opacity-70">{customer.email}</span>
                </button>
              </li>
            </ul>
          </div>

          <.form for={@form} id="incident-form" phx-submit="save" class="mt-3">
            <.input field={@form[:title]} label={gettext("Title")} required />
            <.input
              field={@form[:description]}
              type="textarea"
              rows="5"
              label={gettext("Description")}
            />
            <div class="modal-action">
              <.link patch={~p"/admin/incidents"} class="btn">{gettext("Cancel")}</.link>
              <button type="submit" class="btn btn-primary" id="save-incident">
                {gettext("Save")}
              </button>
            </div>
          </.form>
        </div>
        <.link patch={~p"/admin/incidents"} class="modal-backdrop"></.link>
      </div>
    </Layouts.admin>
    """
  end
end
