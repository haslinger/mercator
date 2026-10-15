defmodule MercatorWeb.Admin.HelpLive do
  @moduledoc """
  "Hilfe" in the admin area (#124, docs/documentation-design.md, section
  4): `/admin/help` lists the chapters of the manual, operating and
  developer parts the user may see, with a search; `/admin/help/:part/:slug`
  shows one chapter with its own table of contents. The content comes from
  `Mercator.Docs`.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.DocsComponents

  alias Mercator.Docs

  on_mount {MercatorWeb.LiveUserAuth, :require_staff}

  @parts %{"manual" => :manual, "operating" => :operating, "developers" => :developers}

  @impl true
  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, gettext("Help"))}

  @impl true
  def handle_params(params, _uri, %{assigns: %{live_action: :index}} = socket) do
    %{current_user: user, locale: locale} = socket.assigns
    query = String.trim(params["q"] || "")

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:results, Docs.search(query, locale, user, Map.values(@parts)))
     |> assign(:parts, parts(locale, user))}
  end

  def handle_params(%{"part" => part, "slug" => slug}, _uri, socket) do
    %{current_user: user, locale: locale} = socket.assigns

    with {:ok, part} <- Map.fetch(@parts, part),
         {:ok, chapter} <- Docs.chapter(part, slug, locale, user) do
      {:noreply,
       socket
       |> assign(:page_title, chapter.title)
       |> assign(:chapter, chapter)}
    else
      _missing ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("This help page does not exist."))
         |> push_navigate(to: ~p"/admin/help")}
    end
  end

  # the parts with chapters the user may see
  defp parts(locale, user) do
    for part <- [:manual, :operating, :developers],
        chapters = Docs.chapters(part, locale, user),
        chapters != [],
        do: {part, chapters}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    params = if String.trim(query) == "", do: %{}, else: %{q: query}
    {:noreply, push_patch(socket, to: ~p"/admin/help?#{params}")}
  end

  @impl true
  def render(%{live_action: :index} = assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      help={@help_chapter}
      locale={@locale}
      active="help"
    >
      <h1 class="text-3xl font-bold">{gettext("Help")}</h1>

      <form id="help-search" phx-change="search" phx-submit="search" class="max-w-xl">
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
          id={"result-#{chapter.part}-#{chapter.slug}"}
        >
          <div class="card-body gap-1">
            <p class="text-xs text-base-content/60">{part_label(chapter.part)}</p>
            <p class="font-semibold text-primary">{chapter.title}</p>
            <p class="text-sm text-base-content/80">{snippet}</p>
          </div>
        </.link>
      </section>

      <div :if={@query == ""} class="grid gap-6 md:grid-cols-2 xl:grid-cols-3" id="help-parts">
        <section
          :for={{part, chapters} <- @parts}
          class="card bg-base-100 shadow-sm"
          id={"help-part-#{part}"}
        >
          <div class="card-body gap-3">
            <h2 class="card-title">
              <.icon name={part_icon(part)} class="size-5 text-primary" /> {part_label(part)}
            </h2>
            <ul class="menu w-full p-0">
              <li :for={chapter <- chapters}>
                <.link navigate={Docs.link(chapter)} id={"chapter-#{part}-#{chapter.slug}"}>
                  {chapter.title}
                </.link>
              </li>
            </ul>
          </div>
        </section>
      </div>
    </Layouts.admin>
    """
  end

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      help={@help_chapter}
      locale={@locale}
      active="help"
    >
      <div class="breadcrumbs text-sm" id="help-breadcrumbs">
        <ul>
          <li><.link navigate={~p"/admin/help"}>{gettext("Help")}</.link></li>
          <li>{part_label(@chapter.part)}</li>
        </ul>
      </div>

      <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_16rem]">
        <article class="card bg-base-100 shadow-sm" id="help-chapter">
          <div class="card-body">
            <h1 class="text-3xl font-bold">{@chapter.title}</h1>
            <p :if={@chapter.locale != @locale} class="text-sm text-base-content/60" id="help-locale">
              {gettext("This chapter is only available in another language.")}
            </p>
            <.chapter_html chapter={@chapter} class="mt-2" />
          </div>
        </article>

        <aside :if={@chapter.toc != []} class="hidden lg:block" id="help-toc">
          <div class="sticky top-4 card card-sm bg-base-100 shadow-sm">
            <.chapter_toc chapter={@chapter} class="card-body gap-1" />
          </div>
        </aside>
      </div>
    </Layouts.admin>
    """
  end

  defp part_label(:manual), do: gettext("Manual")
  defp part_label(:operating), do: gettext("Operating")
  defp part_label(:developers), do: gettext("Developers")

  defp part_icon(:manual), do: "hero-book-open"
  defp part_icon(:operating), do: "hero-server-stack"
  defp part_icon(:developers), do: "hero-code-bracket"
end
