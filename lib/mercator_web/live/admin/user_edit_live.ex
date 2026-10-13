defmodule MercatorWeb.Admin.UserEditLive do
  @moduledoc """
  User administration: edit the roles of a user and approve payment by
  invoice (#64).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.RoleComponents

  alias Mercator.Accounts
  alias Mercator.Accounts.Role

  on_mount {MercatorWeb.LiveUserAuth, {:require_role, :administrator}}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns.current_user

    case Accounts.get_user(id, actor: actor) do
      {:ok, user} ->
        {:ok,
         socket
         |> assign(:page_title, to_string(user.email))
         |> assign(:user, user)
         |> assign(:selected_roles, user.roles)
         |> assign_form()}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, gettext("User not found."))
         |> push_navigate(to: ~p"/admin/users")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="users">
      <.link navigate={~p"/admin/users"} class="link link-hover text-sm" id="back-to-users">
        <.icon name="hero-arrow-left" class="size-4" /> {gettext("Users")}
      </.link>

      <h1 class="text-3xl font-bold" id="user-email">{@user.email}</h1>
      <p :if={@user.name} class="text-base-content/70">{@user.name}</p>

      <section class="card bg-base-100 shadow max-w-xl">
        <div class="card-body">
          <h2 class="card-title">{gettext("Roles")}</h2>
          <p class="text-sm text-base-content/70">
            {gettext("Customers have no role. Staff members can have several roles.")}
          </p>

          <.form for={@form} id="roles-form" phx-change="validate" phx-submit="save">
            <%!-- the hidden field keeps "no roles" submittable --%>
            <input type="hidden" name="form[roles][]" value="" />
            <%!-- DaisyUI's .label is inline-flex, so stack the labels explicitly --%>
            <div class="flex flex-col gap-2 mt-2" id="role-checkboxes">
              <label :for={role <- Role.values()} class="label text-base-content">
                <input
                  type="checkbox"
                  name="form[roles][]"
                  value={role}
                  checked={role in @selected_roles}
                  class="checkbox checkbox-sm"
                  id={"role-#{role}"}
                />
                {role_label(role)}
              </label>
            </div>

            <p
              :for={msg <- Enum.map(@form[:roles].errors, &translate_error/1)}
              class="mt-2 text-sm text-error"
              id="roles-error"
            >
              {msg}
            </p>

            <button type="submit" class="btn btn-primary mt-4" id="save-roles">
              {gettext("Save")}
            </button>
          </.form>
        </div>
      </section>

      <section class="card bg-base-100 shadow max-w-xl">
        <div class="card-body">
          <h2 class="card-title">{gettext("Payment")}</h2>
          <label class="label text-base-content">
            <input
              type="checkbox"
              class="toggle toggle-primary"
              checked={@user.invoice_allowed}
              phx-click="toggle_invoice"
              id="invoice-allowed"
            />
            {gettext("May pay by invoice")}
          </label>
          <p class="text-sm text-base-content/70">
            {gettext("For known customers, e.g. trade customers. Others pay in advance or on pickup.")}
          </p>
        </div>
      </section>
    </Layouts.admin>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    params = clean(params)

    {:noreply,
     socket
     |> assign(:selected_roles, selected(params))
     |> assign(:form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: clean(params)) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Roles saved."))
         |> assign(:user, user)
         |> assign(:selected_roles, user.roles)
         |> assign_form()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("toggle_invoice", _params, socket) do
    %{user: user, current_user: actor} = socket.assigns

    case Accounts.set_invoice_allowed(user, !user.invoice_allowed, actor: actor) do
      {:ok, user} ->
        {:noreply,
         socket |> assign(:user, user) |> put_flash(:info, gettext("Payment settings saved."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not save the payment settings."))}
    end
  end

  defp assign_form(socket) do
    form =
      socket.assigns.user
      |> Accounts.form_to_set_user_roles(actor: socket.assigns.current_user)
      |> to_form()

    assign(socket, :form, form)
  end

  defp clean(params) do
    Map.update(params, "roles", [], &Enum.reject(&1, fn role -> role == "" end))
  end

  defp selected(%{"roles" => roles}) do
    Enum.filter(Role.values(), &(to_string(&1) in roles))
  end
end
