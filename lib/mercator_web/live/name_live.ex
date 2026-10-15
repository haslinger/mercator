defmodule MercatorWeb.NameLive do
  @moduledoc """
  Asks a signed-in user without a name for it (#102). Users who signed up
  with a magic link have none; `MercatorWeb.LiveUserAuth` (`:require_name`)
  sends them here until they have entered it, then on to `return_to`.
  """
  use MercatorWeb, :live_view

  alias Mercator.Accounts

  on_mount {MercatorWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    form = user |> Accounts.form_to_update_profile(actor: user) |> to_form()

    {:ok,
     socket
     |> assign(:page_title, gettext("Your name"))
     |> assign(:return_to, MercatorWeb.LiveUserAuth.local_path(params["return_to"]))
     |> assign(:form, form)}
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
      <section class="card bg-base-100 shadow max-w-md mx-auto w-full">
        <div class="card-body">
          <h1 class="card-title text-2xl">{gettext("How may we address you?")}</h1>
          <p class="text-base-content/70">
            {gettext(
              "Our staff address you by name, and we need it for your offers and orders. You can change it any time under My account."
            )}
          </p>
          <.form for={@form} id="name-form" phx-change="validate" phx-submit="save">
            <.input
              field={@form[:name]}
              type="text"
              label={gettext("Name")}
              autocomplete="name"
              required
              phx-mounted={JS.focus()}
            />
            <button type="submit" class="btn btn-primary w-full mt-2" id="save-name">
              {gettext("Continue")}
            </button>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Thank you!"))
         |> redirect(to: socket.assigns.return_to)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
