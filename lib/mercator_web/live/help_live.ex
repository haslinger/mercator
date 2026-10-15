defmodule MercatorWeb.HelpLive do
  @moduledoc """
  The help for shop visitors (#125, docs/documentation-design.md,
  section 4): `/help` shows the introduction, the other chapters and a
  search; `/help/:slug` one chapter. Generic help from the repository
  (ordering, account, payment, advice and offers); customer-specific
  content (delivery areas, FAQ, terms) stays in the CMS.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.DocsComponents

  alias Mercator.Docs

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, gettext("Help"))}

  @impl true
  def handle_params(params, _uri, %{assigns: %{live_action: :index}} = socket) do
    %{current_user: user, locale: locale} = socket.assigns
    query = String.trim(params["q"] || "")
    {intro, chapters} = Enum.split_with(Docs.chapters(:help, locale, user), &(&1.slug == "index"))

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:results, Docs.search(query, locale, user, [:help]))
     |> assign(:intro, List.first(intro))
     |> assign(:chapters, chapters)}
  end

  def handle_params(%{"slug" => slug}, _uri, socket) do
    %{current_user: user, locale: locale} = socket.assigns

    case Docs.chapter(:help, slug, locale, user) do
      {:ok, chapter} ->
        {:noreply,
         socket
         |> assign(:page_title, chapter.title)
         |> assign(:chapter, chapter)}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("This help page does not exist."))
         |> push_navigate(to: ~p"/help")}
    end
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    params = if String.trim(query) == "", do: %{}, else: %{q: query}
    {:noreply, push_patch(socket, to: ~p"/help?#{params}")}
  end

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
      <div class="max-w-3xl space-y-6" id="help">
        <h1 class="text-3xl font-bold">{(@intro && @intro.title) || gettext("Help")}</h1>
        <.chapter_html :if={@intro} chapter={@intro} id="help-intro" />

        <form id="help-search" phx-change="search" phx-submit="search">
          <label class="input w-full">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="search"
              name="q"
              value={@query}
              placeholder={gettext("Search the help")}
              phx-debounce="300"
              id="help-query"
            />
          </label>
        </form>

        <section :if={@query != ""} id="help-results" class="space-y-3">
          <p :if={@results == []} class="text-base-content/70">
            {gettext("Nothing found for “%{query}”.", query: @query)}
          </p>
          <.link
            :for={{chapter, snippet} <- @results}
            navigate={Docs.link(chapter)}
            class="card card-sm bg-base-100 shadow-sm transition hover:shadow-md"
            id={"result-#{chapter.slug}"}
          >
            <div class="card-body gap-1">
              <p class="font-semibold text-primary">{chapter.title}</p>
              <p class="text-sm text-base-content/80">{snippet}</p>
            </div>
          </.link>
        </section>

        <div
          :if={@query == "" and @chapters != []}
          class="grid gap-4 sm:grid-cols-2"
          id="help-chapters"
        >
          <.link
            :for={chapter <- @chapters}
            navigate={Docs.link(chapter)}
            class="card bg-base-100 shadow-sm transition hover:shadow-md"
            id={"chapter-#{chapter.slug}"}
          >
            <div class="card-body gap-1">
              <p class="card-title text-base">{chapter.title}</p>
              <p class="line-clamp-2 text-sm text-base-content/70">{chapter.text}</p>
            </div>
          </.link>
        </div>
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
      <div class="breadcrumbs text-sm" id="help-breadcrumbs">
        <ul>
          <li><.link navigate={~p"/help"}>{gettext("Help")}</.link></li>
          <li>{@chapter.title}</li>
        </ul>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_14rem]">
        <article class="max-w-3xl space-y-4" id="help-chapter">
          <h1 class="text-3xl font-bold">{@chapter.title}</h1>
          <.chapter_html chapter={@chapter} />
        </article>

        <aside :if={@chapter.toc != []} class="hidden lg:block" id="help-toc">
          <.chapter_toc chapter={@chapter} class="sticky top-4" />
        </aside>
      </div>
    </Layouts.app>
    """
  end
end
