defmodule MercatorWeb.Admin.UserIndexLive do
  @moduledoc """
  User administration: list of all users with their roles.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.RoleComponents

  alias Mercator.Accounts

  on_mount {MercatorWeb.LiveUserAuth, {:require_role, :administrator}}

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users!(actor: socket.assigns.current_user, query: [sort: [email: :asc]])

    {:ok,
     socket
     |> assign(:page_title, gettext("Users"))
     |> assign(:user_count, length(users))
     |> stream(:users, users)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav_categories={@nav_categories}
    >
      <div class="flex items-baseline justify-between">
        <h1 class="text-3xl font-bold">{gettext("Users")}</h1>
        <span class="text-base-content/70" id="user-count">
          {ngettext("1 user", "%{count} users", @user_count)}
        </span>
      </div>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow">
        <table class="table" id="users-table">
          <thead>
            <tr>
              <th>{gettext("Email")}</th>
              <th>{gettext("Name")}</th>
              <th>{gettext("Roles")}</th>
              <th>{gettext("Language")}</th>
              <th>{gettext("Confirmed")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody id="users" phx-update="stream">
            <tr :for={{dom_id, user} <- @streams.users} id={dom_id} class="hover">
              <td>{user.email}</td>
              <td>{user.name}</td>
              <td><.role_badges roles={user.roles} /></td>
              <td>{String.upcase(to_string(user.locale))}</td>
              <td>
                <.icon :if={user.confirmed_at} name="hero-check" class="size-4 text-success" />
              </td>
              <td class="text-right">
                <.link
                  navigate={~p"/admin/users/#{user.id}"}
                  class="btn btn-ghost btn-xs"
                  id={"edit-#{dom_id}"}
                >
                  {gettext("Edit")}
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
