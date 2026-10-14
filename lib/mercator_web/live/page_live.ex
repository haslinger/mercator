defmodule MercatorWeb.PageLive do
  @moduledoc """
  A CMS page at `/pages/…` (#80): the published version for visitors.
  Content managers and administrators can add `?preview=1` to see the
  working copy, also of pages that were never published.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.ContentComponents, only: [block: 1]

  alias Mercator.Content
  alias Mercator.Translated

  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}

  @editor_roles [:contentmanager, :administrator]

  @impl true
  def mount(%{"path" => segments} = params, _session, socket) do
    path = Enum.join(segments, "/")

    case load(path, params["preview"] == "1" and editor?(socket.assigns.current_user), socket) do
      {:ok, page, content, preview?} ->
        {:ok,
         socket
         |> assign(:page, page)
         |> assign(:content, content)
         |> assign(:assets, Content.assets_for_blocks(content.blocks))
         |> assign(:preview?, preview?)
         |> assign(:page_title, Translated.t(content.title, socket.assigns.locale))}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, gettext("Page not found."))
         |> push_navigate(to: ~p"/")}
    end
  end

  defp editor?(%{roles: roles}), do: Enum.any?(@editor_roles, &(&1 in roles))
  defp editor?(_user), do: false

  defp load(path, true = _preview, socket) do
    case Content.get_page_by_path(path, actor: socket.assigns.current_user) do
      {:ok, page} -> {:ok, page, Map.take(page, [:title, :seo_description, :blocks]), true}
      {:error, _} -> :error
    end
  end

  defp load(path, false, _socket) do
    case Content.get_published_page(path) do
      {:ok, %{published: %{} = published} = page} -> {:ok, page, published, false}
      _ -> :error
    end
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
      <div :if={@preview?} role="alert" class="alert alert-warning" id="preview-banner">
        <.icon name="hero-eye" class="size-5" />
        <span>{gettext("Preview of the working copy – visitors see the published version.")}</span>
      </div>

      <article class="space-y-8" id="page">
        <h1 class="text-3xl font-bold" id="page-title">{Translated.t(@content.title, @locale)}</h1>
        <.block :for={block <- @content.blocks} block={block} locale={@locale} assets={@assets} />
      </article>
    </Layouts.app>
    """
  end
end
