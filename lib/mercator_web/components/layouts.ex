defmodule MercatorWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MercatorWeb, :html

  import MercatorWeb.DemoComponents, only: [demo_badge: 1]

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, default: nil, doc: "the signed-in user, if any"
  attr :locale, :string, default: nil, doc: "the current UI language"

  attr :nav, :map,
    default: %{categories: [], main: [], footer: []},
    doc: "categories and menu pages, see MercatorWeb.Navigation"

  attr :basket_count, :integer, default: 0, doc: "number of items in the basket"

  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :sidebar?, assigns.nav.categories != [] or assigns.nav.main != [])

    ~H"""
    <div class={["drawer", @sidebar? && "lg:drawer-open"]}>
      <input id="shop-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex min-h-screen flex-col">
        <header class="navbar bg-base-100 shadow-sm px-2 min-[360px]:px-4 sm:px-6 lg:px-8">
          <div class="flex flex-1 items-center gap-1">
            <label
              :if={@sidebar?}
              for="shop-drawer"
              class="btn btn-ghost btn-sm btn-square lg:hidden"
              aria-label={gettext("Menu")}
              id="shop-menu-button"
            >
              <.icon name="hero-bars-3" class="size-5" />
            </label>
            <.back_button />
            <.link navigate={~p"/"} class="flex shrink-0 items-center gap-3" id="brand">
              <img src={~p"/brand/pin"} alt="" class="h-10 w-auto shrink-0" id="brand-pin" />
              <span class="hidden text-xl font-bold whitespace-nowrap text-primary sm:inline">
                {Mercator.Brand.name()}
              </span>
            </.link>
            <.demo_badge />
          </div>
          <div class="flex-none flex items-center gap-0.5 md:gap-2">
            <form action={~p"/search"} method="get" class="hidden lg:block" id="navbar-search">
              <label class="input input-sm w-48 xl:w-64">
                <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
                <input
                  type="search"
                  name="q"
                  placeholder={gettext("Search")}
                  aria-label={gettext("Search")}
                />
              </label>
            </form>
            <.link
              navigate={~p"/search"}
              class="btn btn-ghost btn-sm lg:hidden"
              aria-label={gettext("Search")}
            >
              <.icon name="hero-magnifying-glass" class="size-5" />
            </.link>
            <.link
              navigate={~p"/basket"}
              class="btn btn-ghost btn-sm"
              id="basket-link"
              aria-label={gettext("Basket")}
            >
              <div class="indicator">
                <.icon name="hero-shopping-cart" class="size-5" />
                <span
                  :if={@basket_count > 0}
                  class="badge badge-primary badge-xs indicator-item"
                  id="basket-count"
                >
                  {@basket_count}
                </span>
              </div>
            </.link>
            <div class="hidden items-center gap-2 md:flex">
              <.locale_switch locale={@locale} />
              <.theme_toggle />
            </div>
            <.more_menu locale={@locale} />
            <%= if @current_user do %>
              <.user_menu current_user={@current_user} />
            <% else %>
              <.link
                navigate={~p"/sign-in"}
                class="btn btn-ghost btn-sm"
                id="sign-in-link"
                aria-label={gettext("Sign in")}
              >
                <.icon name="hero-user-circle" class="size-5 sm:hidden" />
                <span class="hidden sm:inline">{gettext("Sign in")}</span>
              </.link>
              <.link
                navigate={~p"/register"}
                class="btn btn-primary btn-sm hidden md:inline-flex"
                id="register-link"
              >
                {gettext("Register")}
              </.link>
            <% end %>
          </div>
        </header>

        <main class="px-4 py-10 sm:px-6 lg:px-8">
          <div class="mx-auto max-w-5xl space-y-4">
            {render_slot(@inner_block)}
          </div>
        </main>

        <footer class="footer sm:footer-horizontal bg-base-200 text-base-content/70 px-4 py-6 sm:px-6 lg:px-8">
          <aside>
            <p class="font-semibold text-base-content">{Mercator.Brand.name()}</p>
            <p :if={Mercator.Brand.get(:address)}>{Mercator.Brand.get(:address)}</p>
            <p :if={Mercator.Brand.get(:email)}>{Mercator.Brand.get(:email)}</p>
          </aside>
          <nav>
            <.link navigate={~p"/help"} class="link link-hover" id="help-link">
              {gettext("Help")}
            </.link>
            <.link
              :if={Mercator.Docs.making_of?()}
              navigate={~p"/making-of"}
              class="link link-hover"
              id="making-of-link"
            >
              Making-of
            </.link>
            <.link navigate={~p"/terms"} class="link link-hover" id="gtc-link">
              {gettext("Terms and conditions")}
            </.link>
            <.link
              :for={page <- @nav.footer}
              navigate={page_path(page)}
              class="link link-hover"
              id={"footer-page-#{page.id}"}
            >
              {page_title(page, @locale)}
            </.link>
          </nav>
        </footer>
      </div>

      <div :if={@sidebar?} class="drawer-side z-20">
        <label for="shop-drawer" class="drawer-overlay" aria-label={gettext("Close menu")}></label>
        <.shop_sidebar nav={@nav} locale={@locale} />
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :locale, :string, default: nil
  attr :active, :string, default: nil, doc: "id of the active navigation entry"
  attr :wide, :boolean, default: false, doc: "use the full width (e.g. the sales desk)"

  attr :open_incidents, :integer,
    default: nil,
    doc: "open incidents for the sidebar badge, see MercatorWeb.IncidentBadge"

  attr :help, :any,
    default: nil,
    doc: "the documentation chapter for this page's \"?\", see MercatorWeb.HelpLink"

  slot :inner_block, required: true

  @doc "Layout of the admin area (#16): top bar plus a sidebar filtered by role."
  def admin(assigns) do
    assigns = assign(assigns, :sections, MercatorWeb.AdminNav.sections(assigns.current_user))

    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="admin-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex min-h-screen flex-col">
        <header class="navbar bg-base-100 shadow-sm px-4">
          <div class="flex flex-1 items-center gap-2">
            <label
              for="admin-drawer"
              class="btn btn-ghost btn-sm lg:hidden"
              aria-label={gettext("Menu")}
            >
              <.icon name="hero-bars-3" class="size-5" />
            </label>
            <.back_button />
            <.link navigate={~p"/admin"} class="flex items-center gap-2" id="admin-brand">
              <img src={~p"/brand/pin"} alt="" class="h-8 w-auto shrink-0" />
              <span class="hidden font-bold whitespace-nowrap text-primary sm:inline">
                {Mercator.Brand.name()}
              </span>
              <span class="badge badge-neutral badge-sm hidden min-[360px]:inline-flex">
                {gettext("Admin")}
              </span>
            </.link>
            <.demo_badge id="admin-demo-badge" />
          </div>
          <div class="flex-none flex items-center gap-0.5 md:gap-2">
            <.link
              :if={@help}
              navigate={Mercator.Docs.link(@help)}
              class="btn btn-ghost btn-sm btn-circle"
              id="page-help"
              title={gettext("Help for this page")}
              aria-label={gettext("Help for this page")}
            >
              <.icon name="hero-question-mark-circle" class="size-5" />
            </.link>
            <.link navigate={~p"/"} class="btn btn-ghost btn-sm" id="to-shop">
              <.icon name="hero-building-storefront" class="size-5" />
              <span class="hidden sm:inline">{gettext("Shop")}</span>
            </.link>
            <div class="hidden items-center gap-2 md:flex">
              <.locale_switch locale={@locale} />
              <.theme_toggle />
            </div>
            <.more_menu locale={@locale} />
            <.user_menu current_user={@current_user} />
          </div>
        </header>
        <main class="flex-1 bg-base-200 px-4 py-8 sm:px-6 lg:px-8">
          <div class={["mx-auto space-y-4", if(@wide, do: "max-w-none", else: "max-w-6xl")]}>
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
      <div class="drawer-side z-20">
        <label for="admin-drawer" class="drawer-overlay" aria-label={gettext("Close menu")}></label>
        <nav class="min-h-full w-64 bg-base-100 p-4" id="admin-nav">
          <div :for={{title, items} <- @sections} class="mb-4">
            <p class="menu-title px-2">{title}</p>
            <ul class="menu w-full">
              <li :for={item <- items}>
                <%!-- own pages without the admin layout: in a new tab --%>
                <.link
                  :if={item.external?}
                  href={item.path}
                  target="_blank"
                  rel="noopener"
                  id={"admin-nav-#{item.id}"}
                >
                  <.icon name={item.icon} class="size-5" /> {item.label}
                  <.icon name="hero-arrow-top-right-on-square" class="ml-auto size-4 opacity-60" />
                </.link>
                <.link
                  :if={!item.external?}
                  navigate={item.path}
                  class={[@active == item.id && "menu-active"]}
                  id={"admin-nav-#{item.id}"}
                >
                  <.icon name={item.icon} class="size-5" /> {item.label}
                  <span
                    :if={item.id == "incidents" and (@open_incidents || 0) > 0}
                    class="badge badge-error badge-sm ml-auto"
                    id="open-incidents-badge"
                  >
                    {@open_incidents}
                  </span>
                </.link>
              </li>
            </ul>
          </div>
        </nav>
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :current_user, :map, required: true

  defp user_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end" id="user-menu">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
        <.icon name="hero-user-circle" class="size-5" />
        <span class="hidden sm:inline">{@current_user.name || @current_user.email}</span>
      </div>
      <ul tabindex="0" class="menu dropdown-content bg-base-100 rounded-box z-10 mt-2 w-56 p-2 shadow">
        <li><.link navigate={~p"/account"} id="account-link">{gettext("My account")}</.link></li>
        <li>
          <.link navigate={~p"/account/orders"} id="my-orders-link">{gettext("My orders")}</.link>
        </li>
        <li>
          <.link navigate={~p"/account/offers"} id="my-offers-link">{gettext("My offers")}</.link>
        </li>
        <li :if={MercatorWeb.AdminNav.staff?(@current_user)}>
          <.link navigate={~p"/admin"} id="admin-link">{gettext("Administration")}</.link>
        </li>
        <li>
          <.link href={~p"/sign-out"} method="delete" id="sign-out-link">
            {gettext("Sign out")}
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  # Goes back in the history, or to the start page when there is none (e.g. a
  # freshly opened PWA, which has no browser buttons). See app.js.
  defp back_button(assigns) do
    ~H"""
    <button
      type="button"
      class="btn btn-ghost btn-sm btn-square"
      phx-click={JS.dispatch("mercator:back")}
      aria-label={gettext("Back")}
      title={gettext("Back")}
      id="back-button"
    >
      <.icon name="hero-arrow-left" class="size-5" />
    </button>
    """
  end

  attr :meta, :map, default: nil, doc: "from MercatorWeb.Seo.assign_meta/2"
  attr :title, :string, default: nil

  @doc "Meta description, canonical URL and Open Graph tags in the root layout (#91)."
  def seo_tags(assigns) do
    assigns = assign(assigns, :meta, assigns.meta || %{})

    ~H"""
    <meta :if={@meta[:description]} name="description" content={@meta[:description]} />
    <link
      :if={@meta[:canonical]}
      rel="canonical"
      href={MercatorWeb.Seo.absolute(@meta[:canonical])}
    />
    <meta property="og:site_name" content={Mercator.Brand.name()} />
    <meta property="og:title" content={@title || Mercator.Brand.name()} />
    <meta :if={@meta[:description]} property="og:description" content={@meta[:description]} />
    <meta
      :if={@meta[:canonical]}
      property="og:url"
      content={MercatorWeb.Seo.absolute(@meta[:canonical])}
    />
    <meta :if={@meta[:image]} property="og:image" content={MercatorWeb.Seo.absolute(@meta[:image])} />
    <meta property="og:type" content="website" />
    """
  end

  attr :nav, :map, required: true
  attr :locale, :string, default: nil

  # The shop navigation (#93): main categories with their photo as icon and
  # the pages of the main navigation with their icon. The entry of the
  # current page (or of its main category) is highlighted.
  defp shop_sidebar(assigns) do
    assigns =
      assign(assigns,
        active_category: active_category(assigns.nav),
        active_page_id: active_page_id(assigns.nav)
      )

    ~H"""
    <%!-- vertically centred; my-auto (not justify-center) keeps the top reachable when it is taller than the screen --%>
    <nav class="flex min-h-full w-64 flex-col bg-base-100 p-4" id="shop-nav">
      <div class="my-auto">
        <div :if={@nav.categories != []} class="mb-4">
          <p class="menu-title px-2">{pgettext("shop navigation", "Products")}</p>
          <ul class="menu w-full">
            <li :for={category <- @nav.categories}>
              <.link
                navigate={~p"/categories/#{category.slug}"}
                id={"nav-#{category.slug}"}
                class={[@active_category == category.slug && "menu-active"]}
                aria-current={@active_category == category.slug && "page"}
              >
                <%= case MercatorWeb.CatalogComponents.first_image(category) do %>
                  <% nil -> %>
                    <.icon name="hero-squares-2x2" class="size-5" />
                  <% image -> %>
                    <img
                      src={Mercator.Catalog.Image.url(image, :thumb)}
                      alt=""
                      class="size-6 rounded-full object-cover"
                    />
                <% end %>
                {Mercator.Translated.t(category.name, @locale || "de")}
              </.link>
            </li>
          </ul>
        </div>
        <div :if={@nav.main != []}>
          <p class="menu-title px-2">{gettext("Information")}</p>
          <.page_menu
            tree={page_tree(@nav.main)}
            parent_id={:root}
            locale={@locale}
            active_id={@active_page_id}
          />
        </div>
      </div>
    </nav>
    """
  end

  attr :tree, :map, required: true
  attr :parent_id, :any, required: true
  attr :locale, :string, default: nil
  attr :active_id, :any, default: nil

  # pages of the main navigation, subpages nested below their parent
  defp page_menu(assigns) do
    assigns = assign(assigns, :pages, Map.get(assigns.tree, assigns.parent_id, []))

    ~H"""
    <ul class={[@parent_id == :root && "menu w-full"]}>
      <li :for={page <- @pages}>
        <.link
          navigate={page_path(page)}
          id={"nav-page-#{page.id}"}
          class={[@active_id == page.id && "menu-active"]}
          aria-current={@active_id == page.id && "page"}
        >
          <.icon name={page.icon || "hero-document-text"} class="size-5" />
          {page_title(page, @locale)}
        </.link>
        <.page_menu
          :if={Map.has_key?(@tree, page.id)}
          tree={@tree}
          parent_id={page.id}
          locale={@locale}
          active_id={@active_id}
        />
      </li>
    </ul>
    """
  end

  # the main category: the first of the trail of a category or product page
  defp active_category(%{category_slugs: [root | _]}), do: root
  defp active_category(_nav), do: nil

  # the menu page shown, or the closest menu page above it (a subpage not in the menu)
  defp active_page_id(%{path: path, main: pages}) when is_binary(path) do
    pages
    |> Enum.filter(&within?(path, page_path(&1)))
    |> Enum.max_by(&String.length(page_path(&1)), fn -> nil end)
    |> then(&(&1 && &1.id))
  end

  defp active_page_id(_nav), do: nil

  defp within?(path, "/"), do: path == "/"

  defp within?(path, page_path),
    do: path == page_path or String.starts_with?(path, page_path <> "/")

  # groups menu pages by parent; a page whose parent is not in the menu is a root
  defp page_tree(pages) do
    ids = MapSet.new(pages, & &1.id)

    Enum.group_by(pages, fn page ->
      if page.parent_id && MapSet.member?(ids, page.parent_id), do: page.parent_id, else: :root
    end)
  end

  @doc "The URL of a CMS page: `/` for the start page, otherwise `/pages/…`."
  def page_path(%{key: "home"}), do: ~p"/"
  def page_path(page), do: ~p"/pages/#{String.split(page.path, "/")}"

  # the published title, which visitors see
  defp page_title(%{published: %{title: title}}, locale),
    do: Mercator.Translated.t(title, locale || "de")

  defp page_title(page, locale), do: Mercator.Translated.t(page.title, locale || "de")

  attr :locale, :string, default: nil

  # Phones and small tablets (#72): language and theme move from the header
  # into this menu.
  defp more_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end md:hidden" id="more-menu">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm" aria-label={gettext("More")}>
        <.icon name="hero-ellipsis-horizontal" class="size-5" />
      </div>
      <div
        tabindex="0"
        class="dropdown-content bg-base-100 rounded-box z-10 mt-2 flex w-56 flex-col gap-3 p-4 shadow"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm">{gettext("Language")}</span>
          <.locale_switch locale={@locale} id="more-locale-switch" />
        </div>
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm">{gettext("Theme")}</span>
          <.theme_toggle />
        </div>
      </div>
    </div>
    """
  end

  attr :locale, :string, default: nil
  attr :id, :string, default: "locale-switch"

  @doc "Switches the UI language by reloading the current page with `?locale=`."
  def locale_switch(assigns) do
    ~H"""
    <div class="join" id={@id}>
      <a
        :for={locale <- MercatorWeb.Locale.locales()}
        href={"?locale=#{locale}"}
        class={["btn btn-xs join-item", locale == @locale && "btn-active"]}
        id={"#{@id}-#{locale}"}
      >
        {String.upcase(locale)}
      </a>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme-mode=light]_&]:left-1/3 [[data-theme-mode=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label={gettext("System theme")}
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label={gettext("Light theme")}
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label={gettext("Dark theme")}
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
