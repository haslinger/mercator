defmodule MercatorWeb.AdminNav do
  @moduledoc """
  Navigation of the admin area (#16): one area, each entry visible to the
  roles that may use it.
  """
  use Gettext, backend: MercatorWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: MercatorWeb.Endpoint,
    router: MercatorWeb.Router,
    statics: MercatorWeb.static_paths()

  @doc "Whether the user has any staff role, i.e. may enter the admin area."
  def staff?(%{roles: roles}) when is_list(roles), do: roles != []
  def staff?(_user), do: false

  @doc "Sections of `{title, [%{label, path, icon, id}]}` visible to the user."
  def sections(user) do
    roles = MapSet.new((user && user.roles) || [])

    [
      {gettext("Overview"),
       [
         item(gettext("Dashboard"), ~p"/admin", "hero-home", "dashboard", :all)
       ]},
      {gettext("Sales"),
       [
         item(gettext("Orders"), ~p"/admin/orders", "hero-shopping-bag", "orders", [
           :sales,
           :sales_manager,
           :administrator
         ]),
         item(
           gettext("Contact requests"),
           ~p"/admin/submissions",
           "hero-envelope",
           "submissions",
           [:sales, :sales_manager, :contentmanager, :administrator]
         )
       ]},
      {gettext("Catalogue"),
       [
         item(gettext("Products"), ~p"/admin/products", "hero-cube", "products", [
           :productmanager,
           :administrator
         ]),
         item(gettext("Categories"), ~p"/admin/categories", "hero-folder", "categories", [
           :productmanager,
           :administrator
         ])
       ]},
      {gettext("Content"),
       [
         item(gettext("Pages"), ~p"/admin/pages", "hero-document-text", "pages", [
           :contentmanager,
           :administrator
         ]),
         item(gettext("Media"), ~p"/admin/media", "hero-photo", "media", [
           :contentmanager,
           :administrator
         ])
       ]},
      {gettext("Administration"),
       [
         item(gettext("Users"), ~p"/admin/users", "hero-users", "users", [:administrator]),
         item(
           gettext("Tax classes"),
           ~p"/admin/tax-classes",
           "hero-receipt-percent",
           "tax-classes",
           [
             :administrator
           ]
         )
       ]}
    ]
    |> Enum.map(fn {title, items} -> {title, Enum.filter(items, &visible?(&1, roles))} end)
    |> Enum.reject(fn {_title, items} -> items == [] end)
  end

  defp item(label, path, icon, id, roles),
    do: %{label: label, path: path, icon: icon, id: id, roles: roles}

  defp visible?(%{roles: :all}, roles), do: MapSet.size(roles) > 0
  defp visible?(%{roles: allowed}, roles), do: Enum.any?(allowed, &MapSet.member?(roles, &1))
end
