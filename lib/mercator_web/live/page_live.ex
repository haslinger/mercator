defmodule MercatorWeb.PageLive do
  @moduledoc """
  A CMS page: at `/pages/…` (#80), or the start page `/`, which is the page
  with the key `home` (#81); without one the start page shows the brand and
  the main categories.

  Visitors see the published version. Content managers and administrators
  can add `?preview=1` to see the working copy, also of pages that were
  never published. A page that starts with a hero shows its title only to
  screen readers: the hero is the headline.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.ContentComponents, only: [block: 1]

  alias Mercator.Content
  alias Mercator.Content.Blocks
  alias Mercator.Translated

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @editor_roles [:contentmanager, :administrator]

  @impl true
  def mount(params, _session, socket) do
    preview? = params["preview"] == "1" and editor?(socket.assigns.current_user)

    case load(lookup(params, socket.assigns.live_action), preview?, socket) do
      {:ok, page, content} ->
        {:ok,
         socket
         |> assign(:page, page)
         |> assign(:content, content)
         |> assign(:block_data, MercatorWeb.BlockData.load(content.blocks))
         |> assign(:preview?, preview?)
         |> assign(:page_title, Translated.t(content.title, socket.assigns.locale))}

      :error when socket.assigns.live_action == :home ->
        {:ok, socket |> assign(:page, nil) |> assign(:preview?, false)}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Page not found."))
         |> push_navigate(to: ~p"/")}
    end
  end

  defp lookup(_params, :home), do: {:key, "home"}
  defp lookup(%{"path" => segments}, _action), do: {:path, Enum.join(segments, "/")}

  defp editor?(%{roles: roles}), do: Enum.any?(@editor_roles, &(&1 in roles))
  defp editor?(_user), do: false

  defp load(lookup, true = _preview, socket) do
    actor = socket.assigns.current_user

    result =
      case lookup do
        {:key, key} -> Content.get_page_by_key(key, actor: actor)
        {:path, path} -> Content.get_page_by_path(path, actor: actor)
      end

    case result do
      {:ok, page} -> {:ok, page, Map.take(page, [:title, :seo_description, :blocks])}
      {:error, _} -> :error
    end
  end

  defp load(lookup, false, _socket) do
    result =
      case lookup do
        {:key, key} -> Content.get_published_page_by_key(key)
        {:path, path} -> Content.get_published_page(path)
      end

    case result do
      {:ok, %{published: %{} = published} = page} -> {:ok, page, published}
      _ -> :error
    end
  end

  @impl true
  def render(%{page: nil} = assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <.default_home categories={@nav.categories} locale={@locale} />
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <div :if={@preview?} role="alert" class="alert alert-warning" id="preview-banner">
        <.icon name="hero-eye" class="size-5" />
        <span>{gettext("Preview of the working copy – visitors see the published version.")}</span>
      </div>

      <article class="space-y-8" id="page">
        <h1
          class={["text-3xl font-bold", starts_with_hero?(@content.blocks) && "sr-only"]}
          id="page-title"
        >
          {Translated.t(@content.title, @locale)}
        </h1>
        <.block :for={block <- @content.blocks} block={block} locale={@locale} data={@block_data} />
      </article>
    </Layouts.app>
    """
  end

  defp starts_with_hero?([%Ash.Union{value: %Blocks.Hero{}} | _]), do: true
  defp starts_with_hero?(_blocks), do: false

  attr :categories, :list, required: true
  attr :locale, :string, required: true

  # the start page until a CMS page with the key "home" is published
  defp default_home(assigns) do
    ~H"""
    <div class="hero bg-base-200 rounded-box py-12" id="home-hero">
      <div class="hero-content flex-col gap-8 lg:flex-row">
        <img src={~p"/brand/logo"} alt={Mercator.Brand.name()} class="w-56 lg:w-72" id="brand-logo" />
        <div class="max-w-xl text-center lg:text-left">
          <h1 class="text-4xl font-bold" id="brand-name">{Mercator.Brand.name()}</h1>
          <p
            :if={tagline = Mercator.Brand.tagline(@locale)}
            class="pt-2 text-lg text-base-content/80 whitespace-pre-line"
            id="brand-tagline"
          >
            {tagline}
          </p>
          <p class="py-6">
            {gettext("Shop on your own or get advice from our consultants.")}
          </p>
        </div>
      </div>
    </div>

    <section :if={@categories != []} id="home-categories">
      <h2 class="mb-4 text-2xl font-bold">{gettext("Our range")}</h2>
      <div class="grid grid-cols-2 gap-4 md:grid-cols-4">
        <MercatorWeb.CatalogComponents.category_tile
          :for={category <- @categories}
          category={category}
          locale={@locale}
        />
      </div>
    </section>
    """
  end
end
