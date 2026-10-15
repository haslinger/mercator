defmodule MercatorWeb.MakingOfLive do
  @moduledoc """
  The making-of (#131–#133, docs/documentation-design.md, section 4):
  how Mercator was ported with AI. `/making-of` shows the introduction,
  the metrics and the list of work sessions; `/making-of/:slug` one of
  them, a session as the cleaned conversation. English only (#133).

  Only where `Mercator.Docs.making_of?/0` says so (the demo); elsewhere
  the pages answer 404 and nothing links to them.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.DocsComponents

  alias Mercator.Docs

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket) do
    if Docs.making_of?() do
      {:ok, assign(socket, :page_title, "Making-of")}
    else
      raise MercatorWeb.NotFoundError
    end
  end

  @impl true
  def handle_params(_params, _uri, %{assigns: %{live_action: :index}} = socket) do
    chapters = Docs.chapters(:making_of, "en", socket.assigns.current_user)
    {special, sessions} = Enum.split_with(chapters, &(&1.slug in ["index", "metrics"]))

    {:noreply,
     socket
     |> assign(:intro, Enum.find(special, &(&1.slug == "index")))
     |> assign(:metrics, Enum.find(special, &(&1.slug == "metrics")))
     |> assign(:sessions, Enum.map(sessions, &{&1, messages(&1)}))}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Docs.chapter(:making_of, slug, "en", socket.assigns.current_user) do
      {:ok, chapter} ->
        {:noreply,
         socket
         |> assign(:page_title, chapter.title)
         |> assign(:chapter, chapter)}

      :error ->
        {:noreply, push_navigate(socket, to: ~p"/making-of")}
    end
  end

  # the number of messages in a session (each starts with a heading)
  defp messages(chapter), do: length(Regex.scan(~r/<h3 id="(user|claude)/, chapter.html))

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <div class="max-w-3xl space-y-6" id="making-of" lang="en">
        <h1 class="text-3xl font-bold">Making-of</h1>
        <.chapter_html :if={@intro} chapter={@intro} id="making-of-intro" />

        <.link
          :if={@metrics}
          navigate={Docs.link(@metrics)}
          class="card bg-base-100 shadow-sm transition hover:shadow-md"
          id="making-of-metrics"
        >
          <div class="card-body flex-row items-center gap-4">
            <.icon name="hero-chart-bar" class="size-8 text-primary" />
            <div>
              <p class="card-title text-base">{@metrics.title}</p>
              <p class="text-sm text-base-content/70">
                Code size, tests, commits and working time, compared with the Rails original.
              </p>
            </div>
          </div>
        </.link>

        <section class="space-y-3" id="making-of-sessions">
          <h2 class="text-xl font-bold">The sessions</h2>
          <.link
            :for={{session, messages} <- @sessions}
            navigate={Docs.link(session)}
            class="card card-sm bg-base-100 shadow-sm transition hover:shadow-md"
            id={"session-#{session.slug}"}
          >
            <div class="card-body flex-row items-center justify-between gap-4">
              <p class="font-semibold text-primary">{session.title}</p>
              <span class="badge badge-ghost whitespace-nowrap">{messages} messages</span>
            </div>
          </.link>
        </section>
      </div>
    </Layouts.app>
    """
  end

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <div class="breadcrumbs text-sm" id="making-of-breadcrumbs">
        <ul>
          <li><.link navigate={~p"/making-of"}>Making-of</.link></li>
          <li>{@chapter.title}</li>
        </ul>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_14rem]" lang="en">
        <article class="max-w-3xl space-y-4" id="making-of-chapter">
          <h1 class="text-3xl font-bold">{@chapter.title}</h1>
          <.chapter_html chapter={@chapter} class="session" />
        </article>

        <aside :if={@chapter.toc != []} class="hidden lg:block" id="making-of-toc">
          <.chapter_toc chapter={@chapter} class="sticky top-4" />
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
