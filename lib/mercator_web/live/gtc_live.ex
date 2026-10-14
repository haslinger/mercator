defmodule MercatorWeb.GtcLive do
  @moduledoc """
  The current general terms and conditions (`/terms`).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.MarkdownComponents, only: [markdown: 1]

  alias Mercator.Sales
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Terms and conditions"))
     |> assign(:gtc, Sales.current_gtc!())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav_categories={@nav_categories}
      basket_count={@basket_count}
    >
      <article class="max-w-3xl space-y-4" id="gtc">
        <h1 class="text-3xl font-bold">{gettext("Terms and conditions")}</h1>

        <%= if @gtc do %>
          <p class="text-sm text-base-content/70" id="gtc-version">
            {gettext("Valid from %{date}", date: Format.date(@gtc.version))}
          </p>
          <.markdown text={Translated.t(@gtc.text, @locale)} id="gtc-text" />
        <% else %>
          <p id="no-gtc">{gettext("The terms and conditions have not been published yet.")}</p>
        <% end %>
      </article>
    </Layouts.app>
    """
  end
end
