defmodule MercatorWeb.Admin.DashboardLive do
  @moduledoc "Start page of the admin area (#16): key figures and shortcuts."
  use MercatorWeb, :live_view

  alias Mercator.Catalog

  on_mount {MercatorWeb.LiveUserAuth, :require_staff}

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user
    products = Catalog.list_products!(actor: actor)

    {:ok,
     socket
     |> assign(:page_title, gettext("Dashboard"))
     |> assign(:sections, MercatorWeb.AdminNav.sections(actor))
     |> assign(:stats, %{
       products: length(products),
       active: Enum.count(products, &(&1.state == :active)),
       drafts: Enum.count(products, &(&1.state == :draft)),
       categories: length(Catalog.list_categories!(actor: actor))
     })}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      locale={@locale}
      active="dashboard"
    >
      <h1 class="text-3xl font-bold">{gettext("Dashboard")}</h1>
      <p class="text-base-content/70">
        {gettext("Welcome, %{name}.", name: @current_user.name || @current_user.email)}
      </p>

      <div class="stats stats-vertical bg-base-100 shadow sm:stats-horizontal" id="stats">
        <div class="stat">
          <div class="stat-title">{gettext("Products")}</div>
          <div class="stat-value" id="stat-products">{@stats.products}</div>
          <div class="stat-desc">
            {gettext("%{active} active, %{drafts} drafts",
              active: @stats.active,
              drafts: @stats.drafts
            )}
          </div>
        </div>
        <div class="stat">
          <div class="stat-title">{gettext("Categories")}</div>
          <div class="stat-value" id="stat-categories">{@stats.categories}</div>
        </div>
      </div>

      <%!-- the shortcuts, grouped like the sidebar (without the dashboard itself) --%>
      <section
        :for={{title, items} <- shortcut_sections(@sections)}
        class="space-y-2"
        id={"shortcuts-#{items |> hd() |> Map.fetch!(:id)}"}
      >
        <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
          {title}
        </h2>
        <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <.shortcut :for={item <- items} item={item} open_incidents={@open_incidents} />
        </div>
      </section>
    </Layouts.admin>
    """
  end

  defp shortcut_sections(sections) do
    sections
    |> Enum.map(fn {title, items} -> {title, Enum.reject(items, &(&1.id == "dashboard"))} end)
    |> Enum.reject(fn {_title, items} -> items == [] end)
  end

  attr :item, :map, required: true
  attr :open_incidents, :integer, default: nil

  defp shortcut(assigns) do
    ~H"""
    <.link
      navigate={if(!@item.external?, do: @item.path)}
      href={if(@item.external?, do: @item.path)}
      class="card bg-base-100 shadow-sm hover:shadow-md transition-shadow"
      id={"shortcut-#{@item.id}"}
    >
      <div class="card-body flex-row items-center gap-3">
        <.icon name={@item.icon} class="size-6 text-primary" />
        <span class="font-semibold">{@item.label}</span>
        <span
          :if={@item.id == "incidents" and (@open_incidents || 0) > 0}
          class="badge badge-error ml-auto"
          id="shortcut-open-incidents"
        >
          {@open_incidents}
        </span>
      </div>
    </.link>
    """
  end
end
