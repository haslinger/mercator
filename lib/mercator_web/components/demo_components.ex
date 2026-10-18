defmodule MercatorWeb.DemoComponents do
  @moduledoc """
  What demo mode shows (`Mercator.Demo`): the "Demo" badge in the headers and
  the one-click demo sign-in on the sign-in page.
  """
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext
  use MercatorWeb, :verified_routes

  import MercatorWeb.CoreComponents, only: [icon: 1]
  import MercatorWeb.RoleComponents, only: [role_label: 1]

  alias Mercator.Demo

  attr :id, :string, default: "demo-badge"

  @doc "A small badge that marks the demo (nothing outside demo mode)."
  def demo_badge(assigns) do
    ~H"""
    <span
      :if={Demo.enabled?()}
      class="badge badge-warning badge-sm tooltip tooltip-bottom shrink-0"
      data-tip={gettext("Demo shop: no real orders, everything is reset every night")}
      id={@id}
    >
      {gettext("Demo")}
    </span>
    """
  end

  attr :logins?, :boolean,
    default: true,
    doc: "list the demo logins (sign-in), or only the reset hint (register, reset)"

  @doc """
  The demo hint card of the sign-in pages: one-click sign-in buttons for
  the public demo accounts, and that everything is reset at night (nothing
  outside demo mode). The buttons post only the login key (`/demo/sign-in`,
  `MercatorWeb.AuthController.demo_sign_in/2`): no email address or password
  appears on the page, so nothing can be harvested for spam.
  """
  def demo_logins(assigns) do
    assigns = assign(assigns, :logins, Demo.public_logins())

    ~H"""
    <section
      :if={Demo.enabled?()}
      class="card w-full max-w-md bg-base-100 shadow-xl p-6"
      id="demo-logins"
    >
      <h2 class="flex items-center gap-2 text-lg font-bold">
        <.icon name="hero-beaker" class="size-5 text-warning" /> {gettext("This is a demo")}
      </h2>
      <p class="text-sm text-base-content/70 mt-1">
        {gettext(
          "Everything is reset every night at 3 o'clock, including accounts you register, and everyone is signed out (also with \"Remember me\"). Orders are not delivered and payments are simulated."
        )}
      </p>
      <div :if={@logins?} class="mt-4">
        <p class="text-sm">{gettext("Sign in with one of the demo accounts:")}</p>
        <ul class="mt-2 divide-y divide-base-200" id="demo-login-list">
          <li
            :for={login <- @logins}
            class="flex items-center justify-between gap-2 py-2"
            id={"demo-login-#{Demo.login_key(login)}"}
          >
            <div class="min-w-0">
              <p class="font-medium truncate">{login.name}</p>
              <p class="text-xs text-base-content/60 truncate">{role_text(login)}</p>
            </div>
            <.form
              for={%{}}
              action={~p"/demo/sign-in"}
              method="post"
              id={"demo-sign-in-#{Demo.login_key(login)}"}
            >
              <input type="hidden" name="login" value={Demo.login_key(login)} />
              <button type="submit" class="btn btn-primary btn-sm btn-outline shrink-0">
                {gettext("Sign in")}
              </button>
            </.form>
          </li>
        </ul>
      </div>
    </section>
    """
  end

  defp role_text(%{roles: [], locale: :en}), do: gettext("Customer, English")
  defp role_text(%{roles: []}), do: gettext("Customer")
  defp role_text(%{roles: roles}), do: Enum.map_join(roles, ", ", &role_label/1)
end
