defmodule MercatorWeb.GtcLive do
  @moduledoc """
  The current general terms and conditions (`/terms`).
  """
  use MercatorWeb, :live_view

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
          <.gtc_text text={Translated.t(@gtc.text, @locale)} />
        <% else %>
          <p id="no-gtc">{gettext("The terms and conditions have not been published yet.")}</p>
        <% end %>
      </article>
    </Layouts.app>
    """
  end

  attr :text, :string, required: true

  @doc """
  Renders GTC plain text: blank lines separate paragraphs, a line starting
  with `## ` is a heading (the following lines are its first paragraph).
  """
  def gtc_text(assigns) do
    assigns = assign(assigns, :blocks, blocks(assigns.text))

    ~H"""
    <div class="space-y-3 leading-relaxed">
      <%= for block <- @blocks do %>
        <%= case block do %>
          <% {:heading, text} -> %>
            <h2 class="text-xl font-semibold pt-2">{text}</h2>
          <% {:paragraph, text} -> %>
            <p class="whitespace-pre-line">{text}</p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp blocks(text) do
    text
    |> String.split(~r/\n\s*\n/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn
      "## " <> heading ->
        case String.split(heading, "\n", parts: 2) do
          [heading, paragraph] -> [{:heading, heading}, {:paragraph, String.trim(paragraph)}]
          [heading] -> [{:heading, heading}]
        end

      paragraph ->
        [{:paragraph, paragraph}]
    end)
  end
end
