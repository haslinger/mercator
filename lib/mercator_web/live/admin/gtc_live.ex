defmodule MercatorWeb.Admin.GtcLive do
  @moduledoc """
  The GTC in the back office (`/admin/terms`, #92): all versions with their
  status, a new version (prefilled with the text in force), and editing or
  deleting versions that are not in force yet. Versions in force are fixed,
  because orders refer to them (`Mercator.Sales.Gtc`).
  """
  use MercatorWeb, :live_view

  import MercatorWeb.TranslatedComponents
  import MercatorWeb.MarkdownComponents, only: [markdown: 1]

  alias Mercator.{Clock, Sales}
  alias Mercator.Translated
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth, {:require_any_role, [:contentmanager, :administrator]}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Terms and conditions"))
     |> assign(form: nil, viewing: nil)
     |> load()}
  end

  defp load(socket) do
    actor = socket.assigns.current_user
    current = Sales.current_gtc!()

    assign(socket,
      versions: Sales.list_gtcs!(actor: actor),
      current: current,
      today: Clock.today()
    )
  end

  @impl true
  def handle_event("new", _params, socket) do
    text = if socket.assigns.current, do: socket.assigns.current.text, else: %{}

    form =
      Sales.form_to_create_gtc(
        actor: socket.assigns.current_user,
        id: "gtc-new-#{System.unique_integer([:positive])}",
        params: %{"version" => Date.to_iso8601(socket.assigns.today), "text" => text}
      )

    {:noreply, assign(socket, form: to_form(form), viewing: nil)}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    gtc = find(socket, id)

    form =
      Sales.form_to_update_gtc(gtc, actor: socket.assigns.current_user, id: "gtc-#{gtc.id}")

    {:noreply, assign(socket, form: to_form(form), viewing: nil)}
  end

  def handle_event("view", %{"id" => id}, socket) do
    {:noreply, assign(socket, viewing: find(socket, id), form: nil)}
  end

  def handle_event("close", _params, socket),
    do: {:noreply, assign(socket, form: nil, viewing: nil)}

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, clean(params)))}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: clean(params)) do
      {:ok, _gtc} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Terms and conditions saved."))
         |> assign(:form, nil)
         |> load()}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Sales.destroy_gtc(find(socket, id), actor: socket.assigns.current_user) do
      :ok ->
        {:noreply, socket |> put_flash(:info, gettext("Version deleted.")) |> load()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Versions in force cannot be deleted."))}
    end
  end

  defp find(socket, id), do: Enum.find(socket.assigns.versions, &(&1.id == id))

  # drops LiveView's _unused_ keys of the translated text
  defp clean(params) do
    Map.update(params, "text", %{}, fn text ->
      text |> Enum.reject(fn {k, _v} -> String.starts_with?(k, "_unused_") end) |> Map.new()
    end)
  end

  defp status(gtc, current, today) do
    cond do
      current && gtc.id == current.id -> :current
      Date.compare(gtc.version, today) == :gt -> :upcoming
      true -> :replaced
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_user={@current_user}
      open_incidents={@open_incidents}
      locale={@locale}
      active="terms"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Terms and conditions")}</h1>
        <button type="button" phx-click="new" class="btn btn-primary" id="new-gtc">
          <.icon name="hero-plus" class="size-5" /> {gettext("New version")}
        </button>
      </div>
      <p class="text-sm text-base-content/70">
        {gettext(
          "Versions in force cannot be changed, because orders refer to them. A new version applies from its date; until then it can still be edited."
        )}
      </p>

      <p :if={@versions == []} class="text-base-content/70" id="no-gtc">{gettext("No terms yet.")}</p>
      <ul class="divide-y divide-base-200 rounded-box bg-base-100 shadow-sm" id="gtc-versions">
        <li :for={gtc <- @versions} class="flex flex-wrap items-center gap-3 p-4" id={"gtc-#{gtc.id}"}>
          <span class="font-semibold">{gettext("Valid from %{date}", date: Format.date(gtc.version))}</span>
          <%= case status(gtc, @current, @today) do %>
            <% :current -> %>
              <span class="badge badge-success" id={"gtc-#{gtc.id}-status"}>{gettext("in force")}</span>
            <% :upcoming -> %>
              <span class="badge badge-info" id={"gtc-#{gtc.id}-status"}>{gettext("upcoming")}</span>
            <% :replaced -> %>
              <span class="badge badge-ghost" id={"gtc-#{gtc.id}-status"}>{gettext("replaced")}</span>
          <% end %>
          <div class="ml-auto flex gap-1">
            <button
              type="button"
              phx-click="view"
              phx-value-id={gtc.id}
              class="btn btn-ghost btn-sm"
              id={"view-#{gtc.id}"}
            >
              <.icon name="hero-eye" class="size-4" /> {gettext("View")}
            </button>
            <button
              :if={status(gtc, @current, @today) == :upcoming}
              type="button"
              phx-click="edit"
              phx-value-id={gtc.id}
              class="btn btn-ghost btn-sm"
              id={"edit-#{gtc.id}"}
            >
              <.icon name="hero-pencil-square" class="size-4" /> {gettext("Edit")}
            </button>
            <button
              :if={status(gtc, @current, @today) == :upcoming}
              type="button"
              phx-click="delete"
              phx-value-id={gtc.id}
              data-confirm={gettext("Delete this version?")}
              class="btn btn-ghost btn-sm text-error"
              id={"delete-#{gtc.id}"}
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </li>
      </ul>

      <div :if={@viewing} class="modal modal-open" id="gtc-view">
        <div class="modal-box max-w-3xl">
          <h2 class="text-xl font-bold">
            {gettext("Valid from %{date}", date: Format.date(@viewing.version))}
          </h2>
          <.markdown text={Translated.t(@viewing.text, @locale)} class="mt-4" />
          <div class="modal-action">
            <button type="button" phx-click="close" class="btn">{gettext("Close")}</button>
          </div>
        </div>
      </div>

      <div :if={@form} class="modal modal-open" id="gtc-modal">
        <div class="modal-box max-w-4xl">
          <h2 class="text-xl font-bold">{gettext("Terms and conditions")}</h2>
          <.form for={@form} id="gtc-form" phx-change="validate" phx-submit="save" class="mt-4">
            <.input
              field={@form[:version]}
              type="date"
              min={Date.to_iso8601(@today)}
              label={gettext("Valid from")}
            />
            <.translated_input field={@form[:text]} label={gettext("Text")} type="markdown" />
            <div class="modal-action">
              <button type="button" phx-click="close" class="btn btn-ghost">{gettext("Cancel")}</button>
              <button type="submit" class="btn btn-primary" id="save-gtc">{gettext("Save")}</button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
