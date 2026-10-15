defmodule MercatorWeb.DemoComponents do
  @moduledoc """
  What demo mode shows (`Mercator.Demo`): the "Demo" badge in the headers and
  the public demo logins on the sign-in page.
  """
  use Phoenix.Component
  use Gettext, backend: MercatorWeb.Gettext

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
  The demo hint card of the sign-in pages: the public demo logins with a
  button that fills in the sign-in form, and that everything is reset at
  night (nothing outside demo mode).
  """
  def demo_logins(assigns) do
    assigns =
      assign(assigns, logins: Demo.public_logins(), password: Demo.password())

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
          "Everything is reset every night at 3 o'clock, including accounts you register. Orders are not delivered and payments are simulated."
        )}
      </p>
      <div :if={@logins?} class="mt-4">
        <p class="text-sm">
          {gettext("Try one of the demo accounts, password:")}
          <code class="font-mono font-semibold" id="demo-password">{@password}</code>
        </p>
        <ul class="mt-2 divide-y divide-base-200" id="demo-login-list">
          <li
            :for={login <- @logins}
            class="flex items-center justify-between gap-2 py-2"
            id={"demo-login-#{login.email |> String.split("@") |> hd()}"}
          >
            <div class="min-w-0">
              <p class="font-medium truncate">{login.name}</p>
              <p class="text-xs text-base-content/60 truncate">
                {role_text(login)} · <span class="font-mono">{login.email}</span>
              </p>
            </div>
            <button
              type="button"
              class="btn btn-ghost btn-xs shrink-0"
              phx-hook=".DemoLogin"
              id={"demo-fill-#{login.email |> String.split("@") |> hd()}"}
              data-email={login.email}
              data-password={@password}
            >
              {gettext("Use")}
            </button>
          </li>
        </ul>
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".DemoLogin">
        export default {
          mounted() {
            this.el.addEventListener("click", () => {
              const form = document.getElementById("user-password-sign-in-with-password")
              if (!form) return
              const fill = (name, value) => {
                const input = form.querySelector(`input[name="user[${name}]"]`)
                if (!input) return
                input.value = value
                input.dispatchEvent(new Event("input", {bubbles: true}))
              }
              fill("email", this.el.dataset.email)
              fill("password", this.el.dataset.password)
              form.querySelector("button[type=submit], input[type=submit]")?.focus()
            })
          }
        }
      </script>
    </section>
    """
  end

  defp role_text(%{roles: [], locale: :en}), do: gettext("Customer, English")
  defp role_text(%{roles: []}), do: gettext("Customer")
  defp role_text(%{roles: roles}), do: Enum.map_join(roles, ", ", &role_label/1)
end
