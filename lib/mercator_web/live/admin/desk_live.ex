defmodule MercatorWeb.Admin.DeskLive do
  @moduledoc """
  The sales desk (`/admin/desk`, guided selling step 2): consultants say
  whether they are available (Phoenix Presence), see waiting and open
  conversations, take one and chat with the customer. Available consultants
  are notified of new conversations with a tone and a browser notification.
  """
  use MercatorWeb, :live_view

  alias Mercator.Consulting.Desk
  alias MercatorWeb.{Format, Presence}

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mercator.PubSub, "desk")

      Presence.track(self(), Presence.topic(), user.id, %{
        available: false,
        name: Desk.display_name(user)
      })

      # keeps the waiting times current
      :timer.send_interval(30_000, :tick)
    end

    {:ok,
     socket
     |> assign(
       page_title: gettext("Sales desk"),
       available?: false,
       selected: nil,
       form: new_form()
     )
     |> stream(:messages, [])
     |> load_lists()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Desk.get(id, socket.assigns.current_user) do
      {:ok, %{} = conversation} ->
        {:noreply, select(socket, conversation)}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Conversation not found."))
         |> push_patch(to: ~p"/admin/desk")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, unselect(socket)}

  defp select(socket, conversation) do
    if previous = socket.assigns.selected,
      do: Phoenix.PubSub.unsubscribe(Mercator.PubSub, "conversation:#{previous.id}")

    if connected?(socket),
      do: Phoenix.PubSub.subscribe(Mercator.PubSub, "conversation:#{conversation.id}")

    socket
    |> assign(:selected, Map.delete(conversation, :messages))
    |> assign(:page_title, conversation.subject || gettext("Sales desk"))
    |> stream(:messages, conversation.messages, reset: true)
  end

  defp unselect(socket) do
    if previous = socket.assigns.selected,
      do: Phoenix.PubSub.unsubscribe(Mercator.PubSub, "conversation:#{previous.id}")

    socket |> assign(:selected, nil) |> stream(:messages, [], reset: true)
  end

  defp load_lists(socket) do
    actor = socket.assigns.current_user
    active = Desk.active(actor)
    {mine, others} = Enum.split_with(active, &(&1.consultant_id == actor.id))
    assign(socket, waiting: Desk.waiting(actor), mine: mine, others: others)
  end

  defp new_form, do: to_form(%{"body" => ""}, as: :reply)

  # --- events ---

  @impl true
  def handle_event("availability", _params, socket) do
    available? = !socket.assigns.available?
    user = socket.assigns.current_user

    Presence.update(self(), Presence.topic(), user.id, %{
      available: available?,
      name: Desk.display_name(user)
    })

    {:noreply, assign(socket, :available?, available?)}
  end

  def handle_event("take", _params, socket) do
    case Desk.take(socket.assigns.selected, socket.assigns.current_user) do
      {:ok, conversation} ->
        {:noreply, socket |> assign(:selected, conversation) |> load_lists()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("This change is not possible."))}
    end
  end

  def handle_event("close", _params, socket) do
    Desk.close(socket.assigns.selected, socket.assigns.current_user)
    {:noreply, socket |> load_lists() |> push_patch(to: ~p"/admin/desk")}
  end

  def handle_event("send", %{"reply" => %{"body" => body}}, socket) do
    case String.trim(body) do
      "" ->
        {:noreply, socket}

      body ->
        Desk.post(socket.assigns.selected, socket.assigns.current_user, body)
        {:noreply, assign(socket, :form, new_form())}
    end
  end

  # --- updates ---

  @impl true
  def handle_info({:conversation, conversation}, socket) do
    socket = load_lists(socket)

    socket =
      if socket.assigns.selected && socket.assigns.selected.id == conversation.id,
        do:
          assign(
            socket,
            :selected,
            Map.merge(
              socket.assigns.selected,
              Map.take(conversation, [
                :state,
                :consultant_id,
                :consultant,
                :callback_kind,
                :callback_contact,
                :callback_requested_at
              ])
            )
          ),
        else: socket

    socket =
      if conversation.state == :waiting and socket.assigns.available? and new?(conversation),
        do:
          push_event(socket, "desk:notify", %{
            title: gettext("New conversation"),
            body: conversation.subject || gettext("A customer would like advice.")
          }),
        else: socket

    {:noreply, socket}
  end

  def handle_info({:message, message}, socket),
    do: {:noreply, stream_insert(socket, :messages, message)}

  def handle_info(:tick, socket), do: {:noreply, load_lists(socket)}

  # a conversation that was just started (not one that changed later)
  defp new?(conversation), do: DateTime.diff(DateTime.utc_now(), conversation.inserted_at) < 10

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="desk">
      <div class="flex flex-wrap items-center justify-between gap-2" id="desk" phx-hook=".DeskNotify">
        <h1 class="text-3xl font-bold">{gettext("Sales desk")}</h1>
        <button
          type="button"
          phx-click="availability"
          class={["btn", if(@available?, do: "btn-success", else: "btn-outline")]}
          id="availability"
        >
          <span class={[
            "inline-block size-2.5 rounded-full",
            if(@available?, do: "bg-success-content", else: "bg-base-content/40")
          ]}></span>
          {if @available?, do: gettext("Available"), else: gettext("Away")}
        </button>
      </div>

      <div class="grid gap-6 lg:grid-cols-[20rem_1fr]">
        <aside class="space-y-4">
          <.conversation_list
            id="waiting"
            title={gettext("Waiting")}
            conversations={@waiting}
            selected={@selected}
            empty={gettext("Nobody is waiting.")}
          />
          <.conversation_list
            id="mine"
            title={gettext("My conversations")}
            conversations={@mine}
            selected={@selected}
            empty={gettext("None.")}
          />
          <.conversation_list
            :if={@others != []}
            id="others"
            title={gettext("Other open conversations")}
            conversations={@others}
            selected={@selected}
            empty=""
          />
        </aside>

        <section :if={!@selected} class="card bg-base-100 shadow-sm" id="no-selection">
          <div class="card-body items-center text-center text-base-content/60">
            <.icon name="hero-chat-bubble-left-right" class="size-10" />
            <p>{gettext("Choose a conversation.")}</p>
          </div>
        </section>

        <section
          :if={@selected}
          class="card flex h-[36rem] flex-col overflow-hidden bg-base-100 shadow-sm"
          id="conversation"
        >
          <header class="flex flex-wrap items-center gap-2 border-b border-base-200 p-4">
            <div class="min-w-0 flex-1">
              <p class="font-semibold" id="conversation-customer">
                {Desk.display_name(@selected.customer)}
              </p>
              <p
                :if={@selected.callback_requested_at}
                class="text-sm text-warning"
                id="conversation-callback"
              >
                <.icon name="hero-phone-arrow-down-left" class="size-4" />
                {if @selected.callback_kind == :email,
                  do:
                    gettext("Callback requested by email: %{contact}",
                      contact: @selected.callback_contact
                    ),
                  else:
                    gettext("Callback requested by phone: %{contact}",
                      contact: @selected.callback_contact
                    )}
              </p>
              <p class="truncate text-sm text-base-content/60">
                <span :if={@selected.subject}>{@selected.subject} · </span>
                <a :if={@selected.page} href={@selected.page} target="_blank" class="link">{@selected.page}</a>
              </p>
            </div>
            <span :if={@selected.consultant} class="badge badge-ghost" id="conversation-consultant">
              {Desk.display_name(@selected.consultant)}
            </span>
            <button
              :if={@selected.state == :waiting or @selected.consultant_id != @current_user.id}
              type="button"
              phx-click="take"
              class="btn btn-primary btn-sm"
              id="take"
            >
              {if @selected.state == :waiting, do: gettext("Take"), else: gettext("Take over")}
            </button>
            <button
              type="button"
              phx-click="close"
              data-confirm={gettext("End the conversation?")}
              class="btn btn-ghost btn-sm"
              id="close-conversation"
            >
              {gettext("End")}
            </button>
          </header>

          <div class="flex-1 overflow-y-auto p-4" id="desk-scroll" phx-hook=".DeskScroll">
            <div id="desk-messages" phx-update="stream">
              <div
                :for={{dom_id, message} <- @streams.messages}
                id={dom_id}
                class={[
                  "chat",
                  if(message.sender_kind == :customer, do: "chat-start", else: "chat-end")
                ]}
              >
                <div class="chat-header text-xs opacity-70">
                  {sender(message)} · {Format.datetime(message.inserted_at)}
                </div>
                <div class={[
                  "chat-bubble whitespace-pre-line text-sm",
                  message.sender_kind == :consultant && "chat-bubble-primary",
                  message.sender_kind == :system && "chat-bubble-neutral"
                ]}>
                  {message.body}
                </div>
              </div>
            </div>
          </div>

          <.form
            for={@form}
            id="reply-form"
            phx-submit="send"
            class="flex gap-2 border-t border-base-200 p-3"
          >
            <textarea
              name={@form[:body].name}
              rows="2"
              class="textarea flex-1 resize-none"
              placeholder={gettext("Your answer")}
              id="reply-input"
            >{@form[:body].value}</textarea>
            <button type="submit" class="btn btn-primary self-end" id="reply-send">
              <.icon name="hero-paper-airplane" class="size-5" /> {gettext("Send")}
            </button>
          </.form>
        </section>
      </div>
    </Layouts.admin>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".DeskNotify">
      export default {
        mounted() {
          // ask for notification permission when going available (a user gesture)
          this.el.querySelector("#availability")?.addEventListener("click", () => {
            if ("Notification" in window && Notification.permission === "default") Notification.requestPermission()
          })
          this.handleEvent("desk:notify", ({title, body}) => {
            try {
              const ctx = new (window.AudioContext || window.webkitAudioContext)()
              const tone = ctx.createOscillator(), gain = ctx.createGain()
              tone.frequency.value = 880
              gain.gain.setValueAtTime(0.2, ctx.currentTime)
              gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.6)
              tone.connect(gain).connect(ctx.destination)
              tone.start(); tone.stop(ctx.currentTime + 0.6)
            } catch (_e) {}
            if ("Notification" in window && Notification.permission === "granted" && document.hidden) {
              new Notification(title, {body})
            }
          })
        }
      }
    </script>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".DeskScroll">
      export default {
        mounted() { this.el.scrollTop = this.el.scrollHeight },
        updated() { this.el.scrollTop = this.el.scrollHeight }
      }
    </script>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :conversations, :list, required: true
  attr :selected, :any, required: true
  attr :empty, :string, required: true

  defp conversation_list(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-sm" id={"#{@id}-list"}>
      <div class="card-body gap-2 p-4">
        <h2 class="flex items-center justify-between font-semibold">
          {@title} <span class="badge badge-sm">{length(@conversations)}</span>
        </h2>
        <p :if={@conversations == []} class="text-sm text-base-content/60">{@empty}</p>
        <ul class="menu -mx-2 w-auto p-0">
          <li :for={conversation <- @conversations}>
            <.link
              patch={~p"/admin/desk/#{conversation.id}"}
              class={[@selected && @selected.id == conversation.id && "menu-active"]}
              id={"desk-conversation-#{conversation.id}"}
            >
              <div class="min-w-0 flex-1">
                <p class="truncate font-medium">
                  {Desk.display_name(conversation.customer)}
                  <span :if={conversation.callback_requested_at} class="badge badge-warning badge-xs">
                    {gettext("Callback")}
                  </span>
                </p>
                <p class="truncate text-xs opacity-70">{conversation.subject || conversation.page}</p>
              </div>
              <span class="text-xs opacity-70">{since(conversation.inserted_at)}</span>
            </.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  defp sender(%{sender_kind: :customer}), do: gettext("Customer")
  defp sender(%{sender_kind: :system}), do: gettext("System")
  defp sender(%{sender: sender}), do: Desk.display_name(sender)

  defp since(time) do
    case DateTime.diff(DateTime.utc_now(), time, :minute) do
      0 -> gettext("now")
      minutes when minutes < 60 -> gettext("%{count} min", count: minutes)
      minutes -> gettext("%{count} h", count: div(minutes, 60))
    end
  end
end
