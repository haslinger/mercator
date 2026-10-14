defmodule MercatorWeb.ContactFormComponent do
  @moduledoc """
  The contact form of a Contact form block (#83). A LiveComponent because
  it keeps its own form state on any page. Spam protection: a hidden
  honeypot field (bots fill it in; the message is dropped silently) and at
  most a few messages per client IP (`Mercator.RateLimit`, bucket
  `:contact`).
  """
  use MercatorWeb, :live_component

  import MercatorWeb.MarkdownComponents, only: [markdown: 1]

  alias Mercator.Content.Submission
  alias Mercator.Translated

  @fields ~w(name email phone message)

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:sent?, fn -> false end)
     |> assign_new(:form, fn -> new_form() end)}
  end

  defp new_form, do: Submission |> AshPhoenix.Form.for_create(:submit) |> to_form()

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply,
     assign(
       socket,
       :form,
       AshPhoenix.Form.validate(socket.assigns.form, Map.take(params, @fields))
     )}
  end

  # the honeypot is filled in: a bot; pretend success
  def handle_event("send", %{"website" => website}, socket) when website != "" do
    {:noreply, assign(socket, :sent?, true)}
  end

  def handle_event("send", %{"form" => params}, socket) do
    case Mercator.RateLimit.check(:contact, socket.assigns.client_ip || "unknown") do
      :ok ->
        params =
          params
          |> Map.take(@fields)
          |> Map.merge(%{"page_id" => socket.assigns.page_id, "locale" => socket.assigns.locale})

        case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
          {:ok, _submission} -> {:noreply, assign(socket, sent?: true, form: new_form())}
          {:error, form} -> {:noreply, assign(socket, :form, form)}
        end

      {:error, _retry_after} ->
        {:noreply,
         assign(
           socket,
           :limit_error,
           gettext("Too many messages. Please try again later or call us.")
         )}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :limit_error, fn -> nil end)

    ~H"""
    <section class="max-w-2xl space-y-4" id={@id}>
      <.markdown text={Translated.t(@block.intro, @locale)} />

      <div :if={@sent?} role="status" class="alert alert-success" id={"#{@id}-sent"}>
        <.icon name="hero-check-circle" class="size-5" />
        <span>{gettext("Thank you! We have received your message and will get back to you.")}</span>
      </div>

      <.form
        :if={!@sent?}
        for={@form}
        id={"#{@id}-form"}
        phx-change="validate"
        phx-submit="send"
        phx-target={@myself}
        class="card bg-base-100 shadow-sm"
      >
        <div class="card-body gap-0">
          <div class="grid gap-x-4 sm:grid-cols-2">
            <.input field={@form[:name]} label={gettext("Name")} required />
            <.input field={@form[:email]} type="email" label={gettext("Email")} required />
          </div>
          <.input field={@form[:phone]} type="tel" label={gettext("Phone (optional)")} />
          <.input
            field={@form[:message]}
            type="textarea"
            rows="6"
            label={gettext("Message")}
            required
          />
          <%!-- honeypot: hidden from people, filled in by bots --%>
          <div class="absolute -left-[9999px]" aria-hidden="true">
            <label>Website
            <input type="text" name="website" value="" tabindex="-1" autocomplete="off" /></label>
          </div>
          <p :if={@limit_error} class="text-error" id={"#{@id}-limit"}>{@limit_error}</p>
          <button
            type="submit"
            class="btn btn-primary mt-4 w-fit"
            phx-disable-with={gettext("Sending …")}
          >
            {gettext("Send message")}
          </button>
        </div>
      </.form>
    </section>
    """
  end
end
