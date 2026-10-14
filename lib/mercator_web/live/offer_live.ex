defmodule MercatorWeb.OfferLive do
  @moduledoc """
  An offer of the signed-in customer (`/account/offers/:id`, guided selling
  step 5): items, totals, the consultant's note and validity. "Accept
  offer" leads to the checkout with the offer's items at its prices.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OfferComponents

  alias Mercator.Consulting.{Desk, Offer, Offers}
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Offers.get(id, socket.assigns.current_user) do
      {:ok, %Offer{} = offer} ->
        offer = Ash.load!(offer, [:order], authorize?: false)

        {:ok,
         socket
         |> assign(:page_title, gettext("Offer %{number}", number: Offer.display_number(offer)))
         |> assign(:offer, offer)}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Offer not found."))
         |> push_navigate(to: ~p"/account/offers")}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :acceptable?, Offer.acceptable?(assigns.offer))

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <.link navigate={~p"/account/offers"} class="link link-hover text-sm w-fit" id="back-to-offers">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("My offers")}
      </.link>
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <h1 class="text-3xl font-bold" id="offer-number">
          {gettext("Offer %{number}", number: Offer.display_number(@offer))}
        </h1>
        <.state_badge
          state={if(@offer.state == :sent and not @acceptable?, do: :expired, else: @offer.state)}
          id="offer-state"
        />
      </div>
      <p class="text-sm text-base-content/70">
        {gettext("valid until %{date}", date: Format.date(@offer.valid_until))}
        <span :if={@offer.consultant}>
          · {gettext("Your consultant: %{name}", name: Desk.display_name(@offer.consultant))}
        </span>
      </p>

      <div class="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <div class="space-y-6">
          <section :if={@offer.note} class="card bg-base-100 shadow-sm" id="offer-note">
            <div class="card-body">
              <p class="whitespace-pre-line">{@offer.note}</p>
            </div>
          </section>
          <section class="card bg-base-100 shadow-sm">
            <div class="card-body">
              <h2 class="card-title">{gettext("Items")}</h2>
              <.offer_items offer={@offer} locale={@locale} />
            </div>
          </section>
        </div>

        <aside class="card h-fit bg-base-100 shadow-sm lg:sticky lg:top-4">
          <div class="card-body gap-3">
            <.offer_totals offer={@offer} locale={@locale} />
            <p class="text-xs text-base-content/60">
              {gettext("Shipping costs are added in the checkout.")}
            </p>
            <.link
              :if={@acceptable?}
              navigate={~p"/checkout?#{%{offer: @offer.id}}"}
              class="btn btn-primary"
              id="accept-offer"
            >
              <.icon name="hero-check" class="size-5" /> {gettext("Accept offer")}
            </.link>
            <.link
              :if={@offer.order}
              navigate={~p"/account/orders/#{@offer.order.number}"}
              class="btn btn-outline"
              id="offer-order"
            >
              {gettext("Order %{number}", number: @offer.order.number)}
            </.link>
            <p :if={@offer.state != :accepted and not @acceptable?} class="text-sm" id="offer-expired">
              {gettext("This offer is no longer valid. Please contact us for a new one.")}
            </p>
          </div>
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
