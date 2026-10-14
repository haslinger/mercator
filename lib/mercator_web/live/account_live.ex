defmodule MercatorWeb.AccountLive do
  @moduledoc """
  The signed-in user's account page: profile (name, phone, language) and
  password change.
  """
  use MercatorWeb, :live_view

  alias Mercator.Accounts

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, gettext("My account"))
     |> assign_profile_form(user)
     |> assign_password_form(user)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      locale={@locale}
      nav={@nav}
      basket_count={@basket_count}
    >
      <h1 class="text-3xl font-bold">{gettext("My account")}</h1>
      <p class="text-base-content/70" id="account-email">{@current_user.email}</p>
      <div class="flex flex-wrap gap-2">
        <.link navigate={~p"/account/orders"} class="btn btn-outline btn-sm" id="orders-link">
          <.icon name="hero-shopping-bag" class="size-4" /> {gettext("My orders")}
        </.link>
        <.link navigate={~p"/account/addresses"} class="btn btn-outline btn-sm" id="addresses-link">
          <.icon name="hero-map-pin" class="size-4" /> {gettext("My addresses")}
        </.link>
      </div>

      <div class="grid gap-6 md:grid-cols-2">
        <section class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">{gettext("Profile")}</h2>
            <.form
              for={@profile_form}
              id="profile-form"
              phx-change="validate_profile"
              phx-submit="save_profile"
            >
              <.input field={@profile_form[:name]} type="text" label={gettext("Name")} />
              <.input field={@profile_form[:phone]} type="tel" label={gettext("Phone")} />
              <.input
                field={@profile_form[:locale]}
                type="select"
                label={gettext("Language")}
                options={[{"Deutsch", "de"}, {"English", "en"}]}
              />
              <button type="submit" class="btn btn-primary mt-4" id="save-profile">
                {gettext("Save")}
              </button>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title">{gettext("Change password")}</h2>
            <p class="text-sm text-base-content/70">
              {gettext("After changing your password you will be signed out on all devices.")}
            </p>
            <.form
              for={@password_form}
              id="password-form"
              phx-change="validate_password"
              phx-submit="change_password"
            >
              <.input
                field={@password_form[:current_password]}
                type="password"
                label={gettext("Current password")}
              />
              <.input
                field={@password_form[:password]}
                type="password"
                label={gettext("New password")}
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label={gettext("Repeat new password")}
              />
              <button type="submit" class="btn btn-primary mt-4" id="change-password">
                {gettext("Change password")}
              </button>
            </.form>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate_profile", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :profile_form, AshPhoenix.Form.validate(socket.assigns.profile_form, params))}
  end

  def handle_event("save_profile", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.profile_form, params: params) do
      {:ok, user} ->
        # A full page load lets the locale plug remember a changed language.
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your profile has been saved."))
         |> redirect(to: ~p"/account?locale=#{user.locale}")}

      {:error, form} ->
        {:noreply, assign(socket, :profile_form, form)}
    end
  end

  def handle_event("validate_password", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :password_form,
       AshPhoenix.Form.validate(socket.assigns.password_form, params)
     )}
  end

  def handle_event("change_password", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.password_form, params: params) do
      {:ok, _user} ->
        # Changing the password revokes all tokens, including this session's.
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your password has been changed. Please sign in again."))
         |> redirect(to: ~p"/sign-in")}

      {:error, form} ->
        {:noreply, assign(socket, :password_form, form)}
    end
  end

  defp assign_profile_form(socket, user) do
    form = user |> Accounts.form_to_update_profile(actor: user) |> to_form()
    assign(socket, :profile_form, form)
  end

  defp assign_password_form(socket, user) do
    form = user |> Accounts.form_to_change_password(actor: user) |> to_form()
    assign(socket, :password_form, form)
  end
end
