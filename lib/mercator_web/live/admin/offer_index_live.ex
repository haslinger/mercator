defmodule MercatorWeb.Admin.OfferIndexLive do
  @moduledoc """
  Offers in the back office (`/admin/offers`, guided selling step 4):
  filter by state, newest first, 25 per page. A new offer starts with
  choosing the customer (offers need an account, #94).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OfferComponents, only: [state_badge: 1, state_label: 1, states: 0]

  alias Mercator.Consulting.{Desk, Offer, Offers}
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Offers"),
       new?: false,
       customer_query: "",
       customers: []
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    state = Enum.find(states(), &(to_string(&1) == params["state"]))
    page = max(parse_int(params["page"]), 1)

    result =
      Offers.list(socket.assigns.current_user, %{state: state},
        limit: @per_page,
        offset: (page - 1) * @per_page,
        count: true
      )

    {:noreply,
     socket
     |> assign(:state, state)
     |> assign(:page, page)
     |> assign(:count, result.count)
     |> assign(:pages, max(ceil(result.count / @per_page), 1))
     |> stream(:offers, result.results, reset: true)}
  end

  defp parse_int(nil), do: 1

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 1
    end
  end

  @impl true
  def handle_event("filter", %{"state" => state}, socket) do
    query = if state == "", do: %{}, else: %{state: state}
    {:noreply, push_patch(socket, to: ~p"/admin/offers?#{query}")}
  end

  def handle_event("new", _params, socket),
    do: {:noreply, assign(socket, new?: true, customer_query: "", customers: [])}

  def handle_event("close_new", _params, socket), do: {:noreply, assign(socket, :new?, false)}

  def handle_event("find_customer", %{"q" => query}, socket),
    do: {:noreply, assign(socket, customer_query: query, customers: Offers.find_customers(query))}

  def handle_event("create", %{"id" => customer_id}, socket) do
    case Offers.create(customer_id, socket.assigns.current_user) do
      {:ok, offer} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/offers/#{offer.id}")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The offer could not be created."))}
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
      active="offers"
    >
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Offers")}</h1>
        <div class="flex items-center gap-3">
          <span class="text-sm text-base-content/70" id="offer-count">
            {ngettext("1 offer", "%{count} offers", @count)}
          </span>
          <button type="button" class="btn btn-primary btn-sm" phx-click="new" id="new-offer">
            <.icon name="hero-plus" class="size-4" /> {gettext("New offer")}
          </button>
        </div>
      </div>

      <form id="offer-filters" phx-change="filter" class="flex flex-wrap gap-2">
        <select name="state" class="select select-sm w-48" id="filter-state">
          <option value="">{gettext("All states")}</option>
          <option :for={state <- states()} value={state} selected={@state == state}>
            {state_label(state)}
          </option>
        </select>
      </form>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
        <table class="table">
          <thead>
            <tr>
              <th>{gettext("Offer")}</th>
              <th>{gettext("Customer")}</th>
              <th class="hidden md:table-cell">{gettext("Consultant")}</th>
              <th>{gettext("State")}</th>
              <th class="text-right">{gettext("Total")}</th>
            </tr>
          </thead>
          <tbody id="offers" phx-update="stream">
            <tr class="hidden only:table-row" id="no-offers">
              <td colspan="5" class="text-center text-base-content/70">
                {gettext("No offers found.")}
              </td>
            </tr>
            <tr :for={{dom_id, offer} <- @streams.offers} id={dom_id} class="hover:bg-base-200">
              <td>
                <.link navigate={~p"/admin/offers/#{offer.id}"} class="link font-semibold">
                  {Offer.display_number(offer)}
                </.link>
                <div class="text-xs text-base-content/70">
                  {gettext("valid until %{date}", date: Format.date(offer.valid_until))}
                </div>
              </td>
              <td>{Desk.display_name(offer.customer)}</td>
              <td class="hidden md:table-cell">
                {offer.consultant && Desk.display_name(offer.consultant)}
              </td>
              <td><.state_badge state={offer.state} /></td>
              <td class="text-right font-semibold whitespace-nowrap">
                {Format.money(offer.gross, @locale)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@pages > 1} class="join self-center" id="offer-pages">
        <.link
          :for={page <- 1..@pages}
          patch={~p"/admin/offers?#{%{state: @state || "", page: page}}"}
          class={["join-item btn btn-sm", page == @page && "btn-active"]}
          id={"offer-page-#{page}"}
        >
          {page}
        </.link>
      </div>

      <div :if={@new?} class="modal modal-open" id="new-offer-modal">
        <div class="modal-box">
          <h2 class="text-lg font-bold">{gettext("New offer")}</h2>
          <p class="text-sm text-base-content/70">
            {gettext("Who is the offer for? Customers need an account.")}
          </p>
          <form
            id="customer-search"
            phx-change="find_customer"
            phx-submit="find_customer"
            class="mt-3"
          >
            <label class="input w-full">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input
                type="search"
                name="q"
                value={@customer_query}
                placeholder={gettext("Email or name")}
                phx-debounce="300"
                autofocus
              />
            </label>
          </form>
          <ul class="menu mt-2 w-full p-0" id="customer-results">
            <li :for={customer <- @customers}>
              <button
                type="button"
                phx-click="create"
                phx-value-id={customer.id}
                id={"customer-#{customer.id}"}
              >
                <span class="font-medium">{customer.name || customer.email}</span>
                <span :if={customer.name} class="text-xs opacity-70">{customer.email}</span>
              </button>
            </li>
          </ul>
          <p
            :if={@customers == [] and String.trim(@customer_query) != ""}
            class="mt-2 text-sm text-base-content/60"
          >
            {gettext("No customers found.")}
          </p>
          <div class="modal-action">
            <button type="button" class="btn" phx-click="close_new">{gettext("Cancel")}</button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_new"></div>
      </div>
    </Layouts.admin>
    """
  end
end
