defmodule MercatorWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MercatorWeb, :html

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
  attr :nav_categories, :list, default: [], doc: "top-level categories for the main navigation"
  attr :basket_count, :integer, default: 0, doc: "number of items in the basket"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar bg-base-100 shadow-sm px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <.link navigate={~p"/"} class="flex items-center gap-3" id="brand">
          <img src={~p"/brand/pin"} alt="" class="h-10 w-auto" id="brand-pin" />
          <span class="text-xl font-bold text-primary">{Mercator.Brand.name()}</span>
        </.link>
      </div>
      <div class="flex-none flex items-center gap-2">
        <form action={~p"/suche"} method="get" class="hidden md:block" id="navbar-search">
          <label class="input input-sm w-48 lg:w-64">
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
          navigate={~p"/suche"}
          class="btn btn-ghost btn-sm md:hidden"
          aria-label={gettext("Search")}
        >
          <.icon name="hero-magnifying-glass" class="size-5" />
        </.link>
        <.catalog_menu :if={@nav_categories != []} categories={@nav_categories} locale={@locale} />
        <.link
          navigate={~p"/warenkorb"}
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
        <.locale_switch locale={@locale} />
        <.theme_toggle />
        <%= if @current_user do %>
          <.user_menu current_user={@current_user} />
        <% else %>
          <.link navigate={~p"/sign-in"} class="btn btn-ghost btn-sm" id="sign-in-link">
            {gettext("Sign in")}
          </.link>
          <.link navigate={~p"/register"} class="btn btn-primary btn-sm" id="register-link">
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

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :locale, :string, default: nil
  attr :active, :string, default: nil, doc: "id of the active navigation entry"
  slot :inner_block, required: true

  @doc "Layout of the admin area (#16): top bar plus a sidebar filtered by role."
  def admin(assigns) do
    assigns = assign(assigns, :sections, MercatorWeb.AdminNav.sections(assigns.current_user))

    ~H"""
    <div class="drawer lg:drawer-open">
      <input id="admin-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex min-h-screen flex-col">
        <header class="navbar bg-base-100 shadow-sm px-4">
          <div class="flex-1 gap-2">
            <label
              for="admin-drawer"
              class="btn btn-ghost btn-sm lg:hidden"
              aria-label={gettext("Menu")}
            >
              <.icon name="hero-bars-3" class="size-5" />
            </label>
            <.link navigate={~p"/admin"} class="flex items-center gap-2" id="admin-brand">
              <img src={~p"/brand/pin"} alt="" class="h-8 w-auto" />
              <span class="font-bold text-primary">{Mercator.Brand.name()}</span>
              <span class="badge badge-neutral badge-sm">{gettext("Admin")}</span>
            </.link>
          </div>
          <div class="flex-none flex items-center gap-2">
            <.link navigate={~p"/"} class="btn btn-ghost btn-sm" id="to-shop">
              <.icon name="hero-building-storefront" class="size-5" />
              <span class="hidden sm:inline">{gettext("Shop")}</span>
            </.link>
            <.locale_switch locale={@locale} />
            <.theme_toggle />
            <.user_menu current_user={@current_user} />
          </div>
        </header>
        <main class="flex-1 bg-base-200 px-4 py-8 sm:px-6 lg:px-8">
          <div class="mx-auto max-w-6xl space-y-4">
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
                <.link
                  navigate={item.path}
                  class={[@active == item.id && "menu-active"]}
                  id={"admin-nav-#{item.id}"}
                >
                  <.icon name={item.icon} class="size-5" /> {item.label}
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

  attr :categories, :list, required: true
  attr :locale, :string, default: nil

  defp catalog_menu(assigns) do
    ~H"""
    <div class="dropdown dropdown-end" id="catalog-menu">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
        <.icon name="hero-squares-2x2" class="size-5" />
        <span class="hidden sm:inline">{pgettext("shop navigation", "Products")}</span>
      </div>
      <ul tabindex="0" class="menu dropdown-content bg-base-100 rounded-box z-10 mt-2 w-64 p-2 shadow">
        <li :for={category <- @categories}>
          <.link navigate={~p"/kategorien/#{category.slug}"} id={"nav-#{category.slug}"}>
            {Mercator.Translated.t(category.name, @locale || "de")}
          </.link>
        </li>
      </ul>
    </div>
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
        <li :if={MercatorWeb.AdminNav.staff?(@current_user)}>
          <.link navigate={~p"/admin"} id="admin-link">{gettext("Administration")}</.link>
        </li>
        <li><.link href={~p"/sign-out"} id="sign-out-link">{gettext("Sign out")}</.link></li>
      </ul>
    </div>
    """
  end

  attr :locale, :string, default: nil

  @doc "Switches the UI language by reloading the current page with `?locale=`."
  def locale_switch(assigns) do
    ~H"""
    <div class="join" id="locale-switch">
      <a
        :for={locale <- MercatorWeb.Locale.locales()}
        href={"?locale=#{locale}"}
        class={["btn btn-xs join-item", locale == @locale && "btn-active"]}
        id={"locale-#{locale}"}
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
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
