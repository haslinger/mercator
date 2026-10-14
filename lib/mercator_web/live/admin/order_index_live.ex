defmodule MercatorWeb.Admin.OrderIndexLive do
  @moduledoc """
  Order list in the back office (`/admin/orders`, checkout step 6): filters
  by state, period and text (order number, customer name, company, email),
  newest first, 25 per page. Filtering happens in the database.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OrderComponents, only: [state_badge: 1, state_label: 1, states: 0]

  alias Mercator.Sales
  alias Mercator.Sales.Payment
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @filters ~w(q state from to)
  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Orders"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = params |> Map.take(@filters) |> Enum.reject(fn {_k, v} -> v == "" end) |> Map.new()
    page = max(parse_int(params["page"]), 1)

    result =
      Sales.search_orders!(search_input(filters),
        actor: socket.assigns.current_user,
        load: [:item_count],
        page: [limit: @per_page, offset: (page - 1) * @per_page, count: true]
      )

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:page, page)
     |> assign(:count, result.count)
     |> assign(:pages, max(ceil(result.count / @per_page), 1))
     |> stream(:orders, result.results, reset: true)}
  end

  defp search_input(filters) do
    %{
      query: filters["q"],
      state: Enum.find(states(), &(to_string(&1) == filters["state"])),
      from: parse_date(filters["from"]),
      to: parse_date(filters["to"])
    }
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_int(nil), do: 1

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 1
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    query =
      params |> Map.take(@filters) |> Enum.reject(fn {_k, v} -> v in [nil, ""] end) |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/admin/orders?#{query}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="orders">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Orders")}</h1>
        <span class="text-sm text-base-content/70" id="order-count">
          {ngettext("1 order", "%{count} orders", @count)}
        </span>
      </div>

      <form id="order-filters" phx-change="filter" phx-submit="filter" class="flex flex-wrap gap-2">
        <label class="input input-sm w-72">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input
            type="search"
            name="q"
            value={@filters["q"]}
            placeholder={gettext("Order number, customer or email")}
            phx-debounce="300"
            id="order-search"
          />
        </label>
        <select name="state" class="select select-sm w-40" id="filter-state">
          <option value="">{gettext("All states")}</option>
          <option
            :for={state <- states()}
            value={state}
            selected={@filters["state"] == to_string(state)}
          >
            {state_label(state)}
          </option>
        </select>
        <label class="input input-sm w-44">
          <span class="label">{pgettext("date range", "from")}</span>
          <input type="date" name="from" value={@filters["from"]} id="filter-from" />
        </label>
        <label class="input input-sm w-44">
          <span class="label">{pgettext("date range", "to")}</span>
          <input type="date" name="to" value={@filters["to"]} id="filter-to" />
        </label>
      </form>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
        <table class="table">
          <thead>
            <tr>
              <th>{gettext("Order")}</th>
              <th>{gettext("Customer")}</th>
              <th class="hidden md:table-cell">{gettext("Payment")}</th>
              <th>{gettext("State")}</th>
              <th class="text-right">{gettext("Total")}</th>
            </tr>
          </thead>
          <tbody id="orders" phx-update="stream">
            <tr class="hidden only:table-row" id="no-orders">
              <td colspan="5" class="text-center text-base-content/70">
                {gettext("No orders found.")}
              </td>
            </tr>
            <tr :for={{dom_id, order} <- @streams.orders} id={dom_id} class="hover:bg-base-200">
              <td>
                <.link navigate={~p"/admin/orders/#{order.number}"} class="link font-semibold">
                  {order.number}
                </.link>
                <div class="text-xs text-base-content/70">
                  {Calendar.strftime(order.inserted_at, "%d.%m.%Y %H:%M")} · {ngettext(
                    "1 item",
                    "%{count} items",
                    order.item_count
                  )}
                </div>
              </td>
              <td>
                <div>{order.billing_address["company"] || order.billing_address["name"]}</div>
                <div class="text-xs text-base-content/70">{order.email}</div>
              </td>
              <td class="hidden md:table-cell">{Payment.label(order.payment_method)}</td>
              <td><.state_badge state={order.state} /></td>
              <td class="text-right font-semibold whitespace-nowrap">
                {Format.money(order.gross, @locale)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@pages > 1} class="join self-center" id="order-pages">
        <.link
          :for={page <- 1..@pages}
          patch={~p"/admin/orders?#{Map.put(@filters, "page", page)}"}
          class={["join-item btn btn-sm", page == @page && "btn-active"]}
          id={"order-page-#{page}"}
        >
          {page}
        </.link>
      </div>
    </Layouts.admin>
    """
  end
end
