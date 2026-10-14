defmodule MercatorWeb.OffersLive do
  @moduledoc """
  The signed-in customer's offers (`/account/offers`, guided selling step 5):
  sent, accepted and expired ones, newest first.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.OfferComponents, only: [state_badge: 1]

  alias Mercator.Consulting.Offer
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    offers = Ash.read!(Offer, action: :mine, actor: socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, gettext("My offers"))
     |> assign(:offers_empty?, offers == [])
     |> stream(:offers, offers)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <.link navigate={~p"/account"} class="link link-hover text-sm w-fit" id="back-to-account">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("My account")}
      </.link>
      <h1 class="text-3xl font-bold">{gettext("My offers")}</h1>

      <div :if={@offers_empty?} class="card bg-base-100 shadow-sm" id="no-offers">
        <div class="card-body items-start">
          <p>{gettext("You have no offers yet. Our consultants are happy to make you one.")}</p>
        </div>
      </div>

      <ul id="offers" phx-update="stream" class="space-y-3">
        <li :for={{dom_id, offer} <- @streams.offers} id={dom_id}>
          <.link
            navigate={~p"/account/offers/#{offer.id}"}
            class="card bg-base-100 shadow-sm transition hover:shadow-md"
          >
            <div class="card-body flex-row flex-wrap items-center justify-between gap-x-6 gap-y-2 py-4">
              <div>
                <p class="font-semibold">{Offer.display_number(offer)}</p>
                <p class="text-sm text-base-content/70">
                  {gettext("valid until %{date}", date: Format.date(offer.valid_until))}
                </p>
              </div>
              <div class="flex items-center gap-4">
                <.state_badge state={customer_state(offer)} />
                <span class="font-semibold whitespace-nowrap">
                  {Format.money(offer.gross, @locale)}
                </span>
                <.icon name="hero-chevron-right" class="size-4 text-base-content/50" />
              </div>
            </div>
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  # until the nightly job runs, a sent offer past its date is already expired for the customer
  defp customer_state(%{state: :sent} = offer),
    do: if(Offer.acceptable?(offer), do: :sent, else: :expired)

  defp customer_state(offer), do: offer.state
end
