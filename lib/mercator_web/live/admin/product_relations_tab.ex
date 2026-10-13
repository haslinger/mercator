defmodule MercatorWeb.Admin.ProductRelationsTab do
  @moduledoc """
  Product editor tab "relations" (back office step 4e): accessories,
  recommendations (with reason) and similar products. The related product
  is found with a live search by title or article number.
  """
  use MercatorWeb, :live_component

  alias Mercator.Catalog
  alias Mercator.Translated

  @kinds [:accessory, :recommended, :related]

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:adding, fn -> nil end)
     |> assign_new(:query, fn -> "" end)
     |> assign_new(:results, fn -> [] end)
     |> assign_new(:chosen, fn -> nil end)
     |> load()}
  end

  defp load(socket) do
    product =
      Catalog.get_product!(socket.assigns.product_id,
        actor: socket.assigns.current_user,
        load: [relations: :related_product]
      )

    assign(socket, :product, product)
  end

  # --- events ---

  @impl true
  def handle_event("add", %{"kind" => kind}, socket)
      when kind in ~w(accessory recommended related) do
    {:noreply,
     assign(socket, adding: String.to_existing_atom(kind), query: "", results: [], chosen: nil)}
  end

  def handle_event("cancel", _params, socket),
    do: {:noreply, assign(socket, adding: nil, chosen: nil)}

  def handle_event("search", %{"query" => query}, socket) do
    results =
      if String.length(String.trim(query)) < 2 do
        []
      else
        query
        |> Catalog.search_products!(actor: socket.assigns.current_user)
        |> Enum.reject(&(&1.id == socket.assigns.product.id))
        |> Enum.take(8)
      end

    {:noreply, assign(socket, query: query, results: results)}
  end

  def handle_event("choose", %{"id" => id}, socket) do
    {:noreply,
     assign(socket, chosen: Enum.find(socket.assigns.results, &(&1.id == id)), results: [])}
  end

  def handle_event("save", params, socket) do
    attrs = %{
      product_id: socket.assigns.product.id,
      related_product_id: socket.assigns.chosen.id,
      kind: socket.assigns.adding,
      reason: params["reason"],
      position: length(socket.assigns.product.relations)
    }

    case Catalog.relate_products(attrs, actor: socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, socket |> assign(adding: nil, chosen: nil) |> load()}

      {:error, _} ->
        send(self(), {:flash, :error, gettext("This relation already exists.")})
        {:noreply, socket}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    relation = Enum.find(socket.assigns.product.relations, &(&1.id == id))
    Catalog.destroy_product_relation!(relation, actor: socket.assigns.current_user)
    {:noreply, load(socket)}
  end

  # --- rendering ---

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :kinds, @kinds)

    ~H"""
    <div id={@id} class="grid gap-4 lg:grid-cols-3">
      <section :for={kind <- @kinds} class="card bg-base-100 shadow-sm" id={"relations-#{kind}"}>
        <div class="card-body gap-2">
          <div class="flex items-center justify-between">
            <h2 class="card-title text-base">{kind_title(kind)}</h2>
            <button
              type="button"
              phx-click="add"
              phx-value-kind={kind}
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
              id={"add-relation-#{kind}"}
            >
              <.icon name="hero-plus" class="size-4" /> {gettext("Add")}
            </button>
          </div>
          <ul class="space-y-1">
            <li
              :for={relation <- Enum.filter(@product.relations, &(&1.kind == kind))}
              class="flex items-start gap-2"
              id={"relation-#{relation.id}"}
            >
              <div class="flex-1">
                <.link
                  navigate={~p"/admin/products/#{relation.related_product_id}"}
                  class="link link-hover"
                >
                  {Translated.t(relation.related_product.title, @locale)}
                </.link>
                <span class="font-mono text-xs text-base-content/50">{relation.related_product.number}</span>
                <p :if={relation.reason} class="text-xs text-base-content/70">
                  {Translated.t(relation.reason, @locale)}
                </p>
              </div>
              <button
                type="button"
                phx-click="delete"
                phx-value-id={relation.id}
                phx-target={@myself}
                class="btn btn-ghost btn-xs text-error"
                id={"delete-relation-#{relation.id}"}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </li>
          </ul>
        </div>
      </section>

      <div :if={@adding} class="modal modal-open" id="relation-modal">
        <div class="modal-box max-w-xl">
          <h2 class="text-xl font-bold">{kind_title(@adding)}</h2>

          <form
            id="relation-search-form"
            phx-change="search"
            phx-submit="search"
            phx-target={@myself}
            class="mt-4"
          >
            <label class="input w-full">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input
                type="search"
                name="query"
                value={@query}
                placeholder={gettext("Search products or article numbers")}
                phx-debounce="300"
                autocomplete="off"
                id="relation-search"
              />
            </label>
          </form>
          <ul
            :if={@results != []}
            class="menu mt-2 w-full rounded-box bg-base-200"
            id="relation-results"
          >
            <li :for={result <- @results}>
              <button
                type="button"
                phx-click="choose"
                phx-value-id={result.id}
                phx-target={@myself}
                id={"choose-#{result.id}"}
              >
                {Translated.t(result.title, @locale)}
                <span class="font-mono text-xs text-base-content/50">{result.number}</span>
              </button>
            </li>
          </ul>

          <form
            :if={@chosen}
            id="relation-form"
            phx-submit="save"
            phx-target={@myself}
            class="mt-4 space-y-3"
          >
            <p class="font-medium" id="chosen-product">
              {Translated.t(@chosen.title, @locale)}
              <span class="font-mono text-xs text-base-content/50">{@chosen.number}</span>
            </p>
            <div :if={@adding == :recommended} class="grid gap-2 sm:grid-cols-2">
              <input
                :for={locale <- Translated.locales()}
                name={"reason[#{locale}]"}
                placeholder={gettext("Reason") <> " (#{String.upcase(locale)})"}
                class="input w-full"
              />
            </div>
            <div class="modal-action">
              <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
                "Cancel"
              )}</button>
              <button type="submit" class="btn btn-primary" id="save-relation">{gettext("Add")}</button>
            </div>
          </form>

          <div :if={!@chosen} class="modal-action">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">{gettext(
              "Cancel"
            )}</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp kind_title(:accessory), do: gettext("Matching accessories")
  defp kind_title(:recommended), do: gettext("We recommend")
  defp kind_title(:related), do: gettext("Similar products")
end
