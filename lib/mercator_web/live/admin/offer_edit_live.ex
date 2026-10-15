defmodule MercatorWeb.Admin.OfferEditLive do
  @moduledoc """
  An offer in the back office (`/admin/offers/:id`, guided selling step 4).

  While it is a draft, the consultant edits validity, overall discount,
  note and items (changes are saved as they are typed), adds products from
  the catalogue, the customer's basket (configured items included) or
  free-text items. Then the offer is sent, or submitted for a sales
  manager's approval when the discount exceeds the limit (#98). Sent and
  expired offers can be revised into a new version.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OfferComponents

  alias Mercator.Catalog
  alias Mercator.Catalog.Unit
  alias Mercator.Consulting.{Desk, Offer, Offers, OfferTotals}
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @header_fields ~w(valid_until discount_percent note)
  @item_fields ~w(title description quantity unit unit_net discount_percent delivery_time)
  @required [:title, :quantity, :unit, :unit_net, :discount_percent, :valid_until]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Offers.get(id, socket.assigns.current_user) do
      {:ok, %Offer{} = offer} ->
        {:ok,
         socket
         |> assign(adding?: false, product_query: "", products: [], rejecting?: false)
         |> assign_offer(offer)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Offer not found."))
         |> push_navigate(to: ~p"/admin/offers")}
    end
  end

  defp assign_offer(socket, offer) do
    socket
    |> assign(:offer, offer)
    |> assign(:page_title, gettext("Offer %{number}", number: Offer.display_number(offer)))
    |> assign(:header_form, to_form(header_params(offer), as: :offer))
  end

  defp header_params(offer) do
    %{
      "valid_until" => Date.to_iso8601(offer.valid_until),
      "discount_percent" => Format.percent(offer.discount_percent),
      "note" => offer.note
    }
  end

  # --- events ---

  @impl true
  def handle_event("save_header", %{"offer" => params}, socket) do
    attrs = params |> Map.take(@header_fields) |> parse_attrs()
    socket.assigns.offer |> Offers.update(attrs, actor(socket)) |> result(socket)
  end

  def handle_event("save_item", %{"item_id" => id} = params, socket) do
    attrs = params |> Map.take(@item_fields) |> parse_attrs()

    case find_item(socket, id) do
      nil -> {:noreply, socket}
      item -> item |> Offers.update_item(attrs, actor(socket)) |> result(socket)
    end
  end

  def handle_event("remove_item", %{"id" => id}, socket) do
    case find_item(socket, id) do
      nil -> {:noreply, socket}
      item -> item |> Offers.remove_item(actor(socket)) |> result(socket)
    end
  end

  def handle_event("add_text", _params, socket) do
    socket.assigns.offer
    |> Offers.add_text(
      %{title: gettext("New item"), quantity: 1, unit: :piece, unit_net: 0},
      actor(socket)
    )
    |> result(socket)
  end

  def handle_event("import_basket", _params, socket) do
    case Offers.import_basket(socket.assigns.offer, actor(socket)) do
      {:ok, offer, 0} ->
        {:noreply,
         socket
         |> assign_offer(offer)
         |> put_flash(:info, gettext("The customer's basket is empty."))}

      {:ok, offer, count} ->
        {:noreply,
         socket
         |> assign_offer(offer)
         |> put_flash(:info, ngettext("1 item taken over.", "%{count} items taken over.", count))}

      error ->
        result(error, socket)
    end
  end

  def handle_event("open_products", _params, socket),
    do: {:noreply, assign(socket, adding?: true, product_query: "", products: [])}

  def handle_event("close_products", _params, socket),
    do: {:noreply, assign(socket, :adding?, false)}

  def handle_event("search_products", %{"q" => query}, socket) do
    products =
      case String.trim(query) do
        "" ->
          []

        query ->
          query
          |> Catalog.search_products!(actor: actor(socket))
          |> Enum.take(10)
          |> Ash.load!([variants: [:prices]], actor: actor(socket))
      end

    {:noreply, assign(socket, product_query: query, products: products)}
  end

  def handle_event("add_product", %{"variant" => variant_id}, socket) do
    case Offers.add_product(socket.assigns.offer, variant_id, 1, actor(socket)) do
      {:ok, offer} ->
        {:noreply, socket |> assign(:adding?, false) |> assign_offer(offer)}

      {:error, :no_price} ->
        {:noreply, put_flash(socket, :error, gettext("This product has no price."))}

      error ->
        result(error, socket)
    end
  end

  def handle_event("submit", _params, socket) do
    case Offers.submit(socket.assigns.offer, actor(socket)) do
      {:ok, %{state: :pending_approval} = offer} ->
        {:noreply,
         socket
         |> assign_offer(offer)
         |> put_flash(:info, gettext("The offer awaits a sales manager's approval."))}

      {:ok, offer} ->
        {:noreply,
         socket |> assign_offer(offer) |> put_flash(:info, gettext("The offer was sent."))}

      error ->
        result(error, socket)
    end
  end

  def handle_event("approve", _params, socket) do
    case Offers.approve(socket.assigns.offer, actor(socket)) do
      {:ok, offer} ->
        {:noreply,
         socket
         |> assign_offer(offer)
         |> put_flash(:info, gettext("Approved; the offer was sent."))}

      error ->
        result(error, socket)
    end
  end

  def handle_event("open_reject", _params, socket),
    do: {:noreply, assign(socket, :rejecting?, true)}

  def handle_event("close_reject", _params, socket),
    do: {:noreply, assign(socket, :rejecting?, false)}

  def handle_event("reject", %{"note" => note}, socket) do
    case Offers.reject(socket.assigns.offer, note, actor(socket)) do
      {:ok, offer} -> {:noreply, socket |> assign(:rejecting?, false) |> assign_offer(offer)}
      error -> result(error, socket)
    end
  end

  def handle_event("copy", _params, socket) do
    case Offers.copy(socket.assigns.offer, actor(socket)) do
      {:ok, copy} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Copied as a new offer with today's prices."))
         |> push_navigate(to: ~p"/admin/offers/#{copy.id}")}

      error ->
        result(error, socket)
    end
  end

  def handle_event("withdraw", _params, socket) do
    socket.assigns.offer |> Offers.withdraw(actor(socket)) |> result(socket)
  end

  def handle_event("revise", _params, socket) do
    case Offers.revise(socket.assigns.offer, actor(socket)) do
      {:ok, revision} -> {:noreply, push_navigate(socket, to: ~p"/admin/offers/#{revision.id}")}
      error -> result(error, socket)
    end
  end

  defp actor(socket), do: socket.assigns.current_user

  defp find_item(socket, id), do: Enum.find(socket.assigns.offer.items, &(&1.id == id))

  defp result({:ok, offer}, socket), do: {:noreply, assign_offer(socket, offer)}

  defp result({:error, error}, socket),
    do: {:noreply, put_flash(socket, :error, error_message(error))}

  defp error_message(%{errors: [%{message: message} = error | _]}) when is_binary(message) do
    field = Map.get(error, :field)
    if field in [nil, :items, :offer_id, :valid_until], do: message, else: "#{field}: #{message}"
  end

  defp error_message(%Ash.Error.Forbidden{}), do: gettext("You are not allowed to do that.")
  defp error_message(_error), do: gettext("That did not work. Please check your input.")

  # form strings → attributes; decimals accept a comma, empty optional texts become nil
  defp parse_attrs(params) do
    params
    |> Enum.map(fn
      {key, value} when key in ~w(quantity unit_net discount_percent) ->
        {String.to_existing_atom(key), parse_decimal(value)}

      {"unit", value} ->
        {:unit, Enum.find(Unit.values(), &(to_string(&1) == value))}

      {"valid_until", value} ->
        {:valid_until, parse_date(value)}

      {key, value} ->
        {String.to_existing_atom(key), blank_to_nil(value)}
    end)
    # a required field being typed (empty or incomplete) keeps its value
    |> Enum.reject(fn {key, value} -> is_nil(value) and key in @required end)
    |> Map.new()
  end

  defp parse_decimal(value) do
    case Decimal.parse(String.replace(value || "", ",", ".")) do
      {decimal, ""} -> decimal
      _ -> nil
    end
  end

  defp parse_date(value) do
    case Date.from_iso8601(value || "") do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  defp blank_to_nil(value), do: value

  defp approver?(%{roles: roles}), do: :sales_manager in roles or :administrator in roles

  defp decimal_value(nil), do: nil
  defp decimal_value(decimal), do: decimal |> Decimal.normalize() |> Decimal.to_string(:normal)

  # --- view ---

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        draft?: assigns.offer.state == :draft,
        approval?:
          assigns.offer.state == :draft and assigns.offer.items != [] and
            not approver?(assigns.current_user) and Offers.needs_approval?(assigns.offer)
      )

    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="offers">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div>
          <.link navigate={~p"/admin/offers"} class="link text-sm">← {gettext("Offers")}</.link>
          <h1 class="flex items-center gap-3 text-3xl font-bold">
            {gettext("Offer %{number}", number: Offer.display_number(@offer))}
            <.state_badge state={@offer.state} id="offer-state" />
          </h1>
          <p class="text-sm text-base-content/70">
            {gettext("for %{customer}", customer: Desk.display_name(@offer.customer))} · {@offer.customer.email}
            <span :if={@offer.consultant}>
              · {gettext("by %{consultant}", consultant: Desk.display_name(@offer.consultant))}
            </span>
          </p>
        </div>
        <.offer_actions offer={@offer} current_user={@current_user} approval?={@approval?} />
      </div>

      <div :if={@draft? and @offer.approval_note} class="alert alert-warning" id="approval-note">
        <.icon name="hero-arrow-uturn-left" class="size-5" />
        <span>{gettext("Sent back: %{note}", note: @offer.approval_note)}</span>
      </div>

      <div class="grid gap-6 lg:grid-cols-3">
        <div class="space-y-4 lg:col-span-2">
          <section class="card bg-base-100 shadow-sm">
            <div class="card-body gap-3">
              <div class="flex flex-wrap items-center justify-between gap-2">
                <h2 class="card-title text-base">{gettext("Items")}</h2>
                <div :if={@draft?} class="flex flex-wrap gap-2">
                  <button type="button" class="btn btn-sm" phx-click="open_products" id="add-product">
                    <.icon name="hero-cube" class="size-4" /> {gettext("Product")}
                  </button>
                  <button
                    type="button"
                    class="btn btn-sm"
                    phx-click="import_basket"
                    id="import-basket"
                  >
                    <.icon name="hero-shopping-cart" class="size-4" /> {gettext("Take over basket")}
                  </button>
                  <button type="button" class="btn btn-sm" phx-click="add_text" id="add-text">
                    <.icon name="hero-pencil-square" class="size-4" /> {gettext("Free item")}
                  </button>
                </div>
              </div>

              <p :if={@offer.items == []} class="text-sm text-base-content/60" id="no-items">
                {gettext("No items yet.")}
              </p>

              <%= if @draft? do %>
                <div class="divide-y divide-base-300" id="offer-items">
                  <.item_form :for={item <- @offer.items} item={item} locale={@locale} />
                </div>
              <% else %>
                <.offer_items :if={@offer.items != []} offer={@offer} locale={@locale} />
              <% end %>
            </div>
          </section>
        </div>

        <aside class="space-y-4">
          <section class="card bg-base-100 shadow-sm">
            <div class="card-body gap-2">
              <.form
                :if={@draft?}
                for={@header_form}
                id="offer-header"
                phx-change="save_header"
                phx-submit="save_header"
              >
                <.input
                  field={@header_form[:valid_until]}
                  type="date"
                  label={gettext("Valid until")}
                  phx-debounce="500"
                />
                <.input
                  field={@header_form[:discount_percent]}
                  type="number"
                  step="any"
                  min="0"
                  max="100"
                  label={gettext("Overall discount (%)")}
                  phx-debounce="500"
                />
                <.input
                  field={@header_form[:note]}
                  type="textarea"
                  rows="4"
                  label={gettext("Note for the customer")}
                  phx-debounce="800"
                />
              </.form>
              <div :if={!@draft?} class="space-y-1 text-sm" id="offer-header">
                <p>{gettext("Valid until")}: {Format.date(@offer.valid_until)}</p>
                <p :if={@offer.sent_at}>{gettext("Sent")}: {Format.datetime(@offer.sent_at)}</p>
                <p :if={@offer.approved_by}>
                  {gettext("Approved by %{name}", name: Desk.display_name(@offer.approved_by))}
                </p>
                <p :if={@offer.note} class="whitespace-pre-line pt-2">{@offer.note}</p>
              </div>

              <.offer_totals offer={@offer} locale={@locale} />

              <div :if={@approval?} class="alert alert-warning text-sm" id="approval-hint">
                <.icon name="hero-shield-exclamation" class="size-5" />
                <span>
                  {gettext(
                    "Discount above %{limit} % (up to %{max} %): a sales manager approves before the offer is sent.",
                    limit: Format.percent(Offer.approval_limit()),
                    max:
                      Format.percent(OfferTotals.max_discount(@offer.items, @offer.discount_percent))
                  )}
                </span>
              </div>
            </div>
          </section>

          <section class="card bg-base-100 shadow-sm text-sm">
            <div class="card-body gap-1">
              <.link
                :if={@offer.conversation_id}
                navigate={~p"/admin/desk/#{@offer.conversation_id}"}
                class="link"
                id="offer-conversation"
              >
                {gettext("Conversation")}
              </.link>
              <.link
                href={~p"/admin/offers/#{@offer.id}/print"}
                target="_blank"
                class="link"
                id="print-link"
              >
                <.icon name="hero-printer" class="size-4" /> {gettext("Print")}
              </.link>
              <.link
                href={~p"/admin/offers/#{@offer.id}/pdf"}
                target="_blank"
                class="link"
                id="pdf-link"
              >
                <.icon name="hero-document-arrow-down" class="size-4" /> {gettext("Create PDF")}
              </.link>
              <.link
                :if={@offer.order}
                navigate={~p"/admin/orders/#{@offer.order.number}"}
                class="link font-semibold"
                id="offer-order"
              >
                {gettext("Order %{number}", number: @offer.order.number)}
              </.link>
              <.link
                :if={@offer.previous_offer_id}
                navigate={~p"/admin/offers/#{@offer.previous_offer_id}"}
                class="link"
                id="previous-version"
              >
                {gettext("Previous version")}
              </.link>
              <p class="text-base-content/60">
                {gettext("Created %{date}", date: Format.datetime(@offer.inserted_at))}
              </p>
            </div>
          </section>
        </aside>
      </div>

      <div :if={@adding?} class="modal modal-open" id="product-modal">
        <div class="modal-box max-w-2xl">
          <h2 class="text-lg font-bold">{gettext("Add a product")}</h2>
          <form
            id="product-search"
            phx-change="search_products"
            phx-submit="search_products"
            class="mt-3"
          >
            <label class="input w-full">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input
                type="search"
                name="q"
                value={@product_query}
                placeholder={gettext("Product name or number")}
                phx-debounce="300"
                autofocus
              />
            </label>
          </form>
          <ul class="mt-3 space-y-2" id="product-results">
            <li :for={product <- @products} class="rounded-box bg-base-200 p-2">
              <p class="font-semibold">{Mercator.Translated.t(product.title, @locale)}</p>
              <p :if={product.kind == :configurable} class="text-xs text-base-content/60">
                {gettext("Default configuration; configured items come with the customer's basket.")}
              </p>
              <div class="mt-1 flex flex-wrap gap-1">
                <button
                  :for={variant <- Enum.filter(product.variants, & &1.active)}
                  type="button"
                  class="btn btn-xs"
                  phx-click="add_product"
                  phx-value-variant={variant.id}
                  id={"add-variant-#{variant.id}"}
                >
                  <.icon name="hero-plus" class="size-3" />
                  {variant.number}
                  <span :if={variant.name}>· {Mercator.Translated.t(variant.name, @locale)}</span>
                </button>
              </div>
            </li>
          </ul>
          <div class="modal-action">
            <button type="button" class="btn" phx-click="close_products">{gettext("Close")}</button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_products"></div>
      </div>

      <div :if={@rejecting?} class="modal modal-open" id="reject-modal">
        <div class="modal-box">
          <h2 class="text-lg font-bold">{gettext("Send back to the consultant")}</h2>
          <form id="reject-form" phx-submit="reject" class="mt-3">
            <.input
              type="textarea"
              name="note"
              value=""
              rows="3"
              label={gettext("Reason")}
              required
            />
            <div class="modal-action">
              <button type="button" class="btn" phx-click="close_reject">{gettext("Cancel")}</button>
              <button type="submit" class="btn btn-warning">{gettext("Send back")}</button>
            </div>
          </form>
        </div>
        <div class="modal-backdrop" phx-click="close_reject"></div>
      </div>
    </Layouts.admin>
    """
  end

  attr :offer, :map, required: true
  attr :current_user, :map, required: true
  attr :approval?, :boolean, required: true

  defp offer_actions(assigns) do
    ~H"""
    <div class="flex flex-wrap gap-2" id="offer-actions">
      <button
        :if={@offer.state == :draft}
        type="button"
        class="btn btn-primary"
        phx-click="submit"
        id="submit-offer"
      >
        <.icon name="hero-paper-airplane" class="size-4" />
        {if @approval?, do: gettext("Submit for approval"), else: gettext("Send offer")}
      </button>
      <button
        :if={@offer.state == :pending_approval and approver?(@current_user)}
        type="button"
        class="btn btn-success"
        phx-click="approve"
        id="approve-offer"
      >
        <.icon name="hero-check" class="size-4" /> {gettext("Approve and send")}
      </button>
      <button
        :if={@offer.state == :pending_approval and approver?(@current_user)}
        type="button"
        class="btn btn-warning"
        phx-click="open_reject"
        id="reject-offer"
      >
        <.icon name="hero-arrow-uturn-left" class="size-4" /> {gettext("Send back")}
      </button>
      <button
        :if={@offer.state in [:sent, :expired]}
        type="button"
        class="btn"
        phx-click="revise"
        id="revise-offer"
      >
        <.icon name="hero-document-duplicate" class="size-4" /> {gettext("Revise")}
      </button>
      <button
        type="button"
        class="btn"
        phx-click="copy"
        title={gettext("A new offer with a new number for the same customer, at today's prices")}
        id="copy-offer"
      >
        <.icon name="hero-square-2-stack" class="size-4" /> {gettext("Copy")}
      </button>
      <button
        :if={@offer.state in [:draft, :pending_approval, :sent]}
        type="button"
        class="btn btn-ghost"
        phx-click="withdraw"
        data-confirm={gettext("Withdraw this offer?")}
        id="withdraw-offer"
      >
        {gettext("Withdraw")}
      </button>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :locale, :string, required: true

  defp item_form(assigns) do
    ~H"""
    <form
      id={"item-form-#{@item.id}"}
      phx-change="save_item"
      phx-submit="save_item"
      class="grid grid-cols-2 gap-x-3 py-3 sm:grid-cols-6"
    >
      <input type="hidden" name="item_id" value={@item.id} />
      <div class="col-span-2 sm:col-span-6 flex items-start justify-between gap-2">
        <div class="min-w-0 flex-1">
          <%= if @item.kind == :text do %>
            <.input
              name="title"
              value={@item.title}
              label={gettext("Title")}
              phx-debounce="500"
              id={"item-title-#{@item.id}"}
            />
            <.input
              type="textarea"
              name="description"
              value={@item.description}
              rows="2"
              label={gettext("Description")}
              phx-debounce="800"
              id={"item-description-#{@item.id}"}
            />
          <% else %>
            <p class="font-semibold">{@item.title}</p>
            <p class="text-sm text-base-content/70">
              {[@item.number, @item.description] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
            </p>
          <% end %>
        </div>
        <span class="pt-1 font-semibold whitespace-nowrap" id={"item-net-#{@item.id}"}>
          {Format.money(OfferTotals.item_net(@item), @locale)}
        </span>
        <button
          type="button"
          class="btn btn-ghost btn-sm btn-square"
          phx-click="remove_item"
          phx-value-id={@item.id}
          aria-label={gettext("Remove")}
          id={"remove-item-#{@item.id}"}
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
      </div>
      <.input
        type="number"
        name="quantity"
        value={decimal_value(@item.quantity)}
        step="any"
        min="0"
        label={gettext("Quantity")}
        phx-debounce="500"
        id={"item-quantity-#{@item.id}"}
      />
      <%= if @item.kind == :text do %>
        <.input
          type="select"
          name="unit"
          value={@item.unit}
          options={Enum.map(Unit.values(), &{Unit.symbol(&1), &1})}
          label={gettext("Unit")}
          id={"item-unit-#{@item.id}"}
        />
      <% else %>
        <div class="fieldset mb-2">
          <span class="label mb-1">{gettext("Unit")}</span>
          <span class="py-2">{Unit.symbol(@item.unit)}</span>
        </div>
      <% end %>
      <div>
        <.input
          type="number"
          name="unit_net"
          value={decimal_value(@item.unit_net)}
          step="any"
          min="0"
          label={gettext("Net price per unit")}
          phx-debounce="500"
          id={"item-price-#{@item.id}"}
        />
        <p
          :if={@item.list_unit_net && !Decimal.equal?(@item.list_unit_net, @item.unit_net)}
          class="-mt-1 text-xs text-base-content/60"
        >
          {gettext("List price %{price}", price: Format.money(@item.list_unit_net, @locale))}
        </p>
      </div>
      <.input
        type="number"
        name="discount_percent"
        value={decimal_value(@item.discount_percent)}
        step="any"
        min="0"
        max="100"
        label={gettext("Discount (%)")}
        phx-debounce="500"
        id={"item-discount-#{@item.id}"}
      />
      <div class="col-span-2">
        <.input
          name="delivery_time"
          value={@item.delivery_time}
          label={gettext("Delivery time")}
          phx-debounce="500"
          id={"item-delivery-#{@item.id}"}
        />
      </div>
    </form>
    """
  end
end
