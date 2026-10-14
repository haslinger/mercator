defmodule MercatorWeb.ChatLive do
  @moduledoc """
  The customer's chat with a consultant (guided selling, step 1): a button
  at the bottom right of every shop page that opens a chat panel.

  Rendered from the root layout (`live_render/3`), so it survives live
  navigation between shop pages and keeps the conversation open. The
  "Beraten lassen" button on product pages dispatches the browser event
  `mercator:open-chat` with a subject and product, which opens the panel.
  """
  use MercatorWeb, :live_view

  alias Mercator.Consulting.Conversations

  on_mount {MercatorWeb.Locale, :default}
  on_mount {AshAuthentication.Phoenix.LiveSession, :default}
  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}
  on_mount {MercatorWeb.BasketSession, :default}

  @hidden_on ~w(/admin /dev /sign-in /sign-out /register /reset /password-reset /auth /magic_link /confirm_new_user)

  @doc "Whether the chat is shown on a request path (shop pages, not admin or sign-in)."
  def show?(%Plug.Conn{request_path: path}), do: not String.starts_with?(path, @hidden_on)
  def show?(_conn), do: false

  @impl true
  def mount(_params, _session, socket) do
    conversation = Conversations.current(socket.assigns.basket_owner)
    if conversation && connected?(socket), do: Conversations.subscribe(conversation.id)

    {:ok,
     socket
     |> assign(open?: false, unread: 0, context: %{}, form: new_form())
     |> assign_conversation(conversation), layout: false}
  end

  defp assign_conversation(socket, nil) do
    socket |> assign(:conversation, nil) |> stream(:messages, [], reset: true)
  end

  defp assign_conversation(socket, conversation) do
    socket
    |> assign(:conversation, Map.delete(conversation, :messages))
    |> stream(:messages, conversation.messages, reset: true)
  end

  defp new_form, do: to_form(%{"body" => ""}, as: :chat)

  @impl true
  def handle_event("toggle", _params, socket) do
    {:noreply, assign(socket, open?: !socket.assigns.open?, unread: 0)}
  end

  # from the "Beraten lassen" button (via the hook): open with a subject
  def handle_event("open", params, socket) do
    context = %{
      subject: params["subject"],
      product_id: params["product_id"],
      page: params["page"]
    }

    {:noreply, assign(socket, open?: true, unread: 0, context: context)}
  end

  def handle_event("send", %{"chat" => %{"body" => body}} = params, socket) do
    body = String.trim(body)
    owner = socket.assigns.basket_owner

    cond do
      body == "" ->
        {:noreply, socket}

      socket.assigns.conversation ->
        Conversations.post(owner, socket.assigns.conversation.id, body)
        {:noreply, assign(socket, :form, new_form())}

      true ->
        context = Map.put_new(socket.assigns.context, :page, params["page"])
        {:ok, conversation} = Conversations.start(owner, body, context)
        Conversations.subscribe(conversation.id)
        {:noreply, socket |> assign_conversation(conversation) |> assign(:form, new_form())}
    end
  end

  def handle_event("end", _params, socket) do
    Conversations.close(socket.assigns.basket_owner, socket.assigns.conversation.id)
    {:noreply, socket |> assign_conversation(nil) |> assign(context: %{}, open?: false)}
  end

  @impl true
  def handle_info({:message, message}, socket) do
    unread = if socket.assigns.open?, do: 0, else: socket.assigns.unread + 1
    {:noreply, socket |> stream_insert(:messages, message) |> assign(:unread, unread)}
  end

  def handle_info({:conversation, %{state: :closed}}, socket) do
    {:noreply, assign_conversation(socket, nil)}
  end

  def handle_info({:conversation, conversation}, socket) do
    {:noreply, assign(socket, :conversation, Map.delete(conversation, :messages))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="chat-widget"
      phx-hook=".OpenChat"
      class="fixed right-4 bottom-4 z-30 flex flex-col items-end gap-3"
    >
      <%!-- always in the page (only hidden), so the message stream keeps its history --%>
      <section
        class={[
          "card h-[28rem] max-h-[calc(100vh-6rem)] w-[min(24rem,calc(100vw-2rem))] flex-col overflow-hidden bg-base-100 shadow-xl",
          if(@open?, do: "flex", else: "hidden")
        ]}
        id="chat-panel"
        aria-label={gettext("Advice")}
      >
        <header class="flex items-center gap-2 bg-primary px-4 py-3 text-primary-content">
          <.icon name="hero-chat-bubble-left-right" class="size-5" />
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{gettext("Advice")}</p>
            <p class="text-xs leading-snug opacity-80" id="chat-status">{status(@conversation)}</p>
          </div>
          <button
            :if={@conversation}
            type="button"
            phx-click="end"
            data-confirm={gettext("End the conversation?")}
            class="btn btn-ghost btn-xs text-primary-content"
            id="chat-end"
          >
            {gettext("End")}
          </button>
          <button
            type="button"
            phx-click="toggle"
            class="btn btn-ghost btn-sm btn-square text-primary-content"
            aria-label={gettext("Close")}
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </header>

        <div class="flex-1 space-y-2 overflow-y-auto p-3" id="chat-scroll" phx-hook=".ScrollDown">
          <div :if={!@conversation} class="space-y-2 text-sm" id="chat-intro">
            <p>{gettext("Our experts are happy to help you choose – just ask your question.")}</p>
            <p :if={@context[:subject]} class="badge badge-ghost h-auto py-1">
              {gettext("About: %{subject}", subject: @context[:subject])}
            </p>
          </div>
          <div id="chat-messages" phx-update="stream">
            <div
              :for={{dom_id, message} <- @streams.messages}
              id={dom_id}
              class={[
                "chat",
                if(message.sender_kind == :customer, do: "chat-end", else: "chat-start")
              ]}
            >
              <div :if={message.sender_kind == :consultant} class="chat-header text-xs opacity-70">
                {message.sender && (message.sender.name || gettext("Consultant"))}
              </div>
              <div class={[
                "chat-bubble whitespace-pre-line text-sm",
                message.sender_kind == :customer && "chat-bubble-primary",
                message.sender_kind == :system && "chat-bubble-neutral"
              ]}>
                {message.body}
              </div>
            </div>
          </div>
        </div>

        <.form
          for={@form}
          id="chat-form"
          phx-submit="send"
          class="flex gap-2 border-t border-base-200 p-2"
        >
          <input type="hidden" name="page" id="chat-page" value="" />
          <textarea
            name={@form[:body].name}
            rows="2"
            class="textarea textarea-sm flex-1 resize-none"
            placeholder={
              if @conversation, do: gettext("Your message"), else: gettext("Your question")
            }
            aria-label={gettext("Your message")}
            id="chat-input"
          >{@form[:body].value}</textarea>
          <button
            type="submit"
            class="btn btn-primary btn-square self-end"
            aria-label={gettext("Send")}
            id="chat-send"
          >
            <.icon name="hero-paper-airplane" class="size-5" />
          </button>
        </.form>
      </section>

      <button
        type="button"
        phx-click="toggle"
        class="btn btn-primary btn-lg rounded-full shadow-lg"
        id="chat-toggle"
        aria-expanded={to_string(@open?)}
      >
        <div class="indicator">
          <.icon
            name={if @open?, do: "hero-chevron-down", else: "hero-chat-bubble-left-right"}
            class="size-6"
          />
          <span
            :if={@unread > 0}
            class="badge badge-secondary badge-sm indicator-item"
            id="chat-unread"
          >
            {@unread}
          </span>
        </div>
        <span class="hidden sm:inline">{gettext("Advice")}</span>
      </button>
    </div>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".OpenChat">
      export default {
        mounted() {
          // "Beraten lassen" buttons dispatch this event (with subject and product)
          this.onOpen = (e) => this.pushEvent("open", {...(e.detail || {}), page: window.location.pathname})
          window.addEventListener("mercator:open-chat", this.onOpen)
          // the page the question is asked on
          this.el.addEventListener("submit", () => {
            const page = this.el.querySelector("#chat-page")
            if (page) page.value = window.location.pathname
          }, true)
        },
        destroyed() { window.removeEventListener("mercator:open-chat", this.onOpen) }
      }
    </script>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ScrollDown">
      export default {
        mounted() { this.el.scrollTop = this.el.scrollHeight },
        updated() { this.el.scrollTop = this.el.scrollHeight }
      }
    </script>
    """
  end

  defp status(nil), do: gettext("Ask us anything")
  defp status(%{state: :waiting}), do: gettext("We are connecting you with a consultant …")

  defp status(%{consultant: %{name: name}}) when is_binary(name),
    do: gettext("You are talking to %{name}", name: name)

  defp status(_conversation), do: gettext("A consultant is with you")
end
