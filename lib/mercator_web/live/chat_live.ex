defmodule MercatorWeb.ChatLive do
  @moduledoc """
  The customer's chat with a consultant (guided selling, step 1): a button
  at the bottom right of every shop page that opens a chat panel.

  Rendered from the root layout (`live_render/3`), so it survives live
  navigation between shop pages and keeps the conversation open. The
  "Beraten lassen" button on product pages dispatches the browser event
  `mercator:open-chat` with a subject and product, which opens the panel.
  A link with `?chat=open` (from the reply email, #97) opens it on load.

  Calls (phase 10): the consultant's call rings in the panel; once accepted,
  the call area (`MercatorWeb.CallComponents`) joins the media room as the
  customer. Since this LiveView survives live navigation, the call goes on
  while the customer browses the shop.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.ConsultingComponents, only: [attachment: 1]
  import MercatorWeb.CallComponents, only: [call_media: 1]

  alias Mercator.Consulting.{Call, Calls, Conversations}

  on_mount {MercatorWeb.Locale, :default}
  on_mount {AshAuthentication.Phoenix.LiveSession, :default}
  on_mount {MercatorWeb.LiveUserAuth, :live_user_optional}
  on_mount {MercatorWeb.BasketSession, :default}

  @hidden_on ~w(/admin /dev /sign-in /sign-out /register /reset /password-reset /auth /magic_link /confirm_new_user)

  @doc "Whether the chat is shown on a request path (shop pages, not admin or sign-in)."
  def show?(%Plug.Conn{request_path: path}), do: not String.starts_with?(path, @hidden_on)
  def show?(_conn), do: false

  @impl true
  def mount(_params, session, socket) do
    conversation = Conversations.current(socket.assigns.basket_owner)
    if conversation && connected?(socket), do: follow(conversation)

    {:ok,
     socket
     |> assign(open?: session["open"] == true, unread: 0, context: %{}, form: new_form(), sent: 0)
     |> assign(rating_for: nil, rated?: false, call_error: nil)
     |> assign_conversation(conversation), layout: false}
  end

  defp assign_conversation(socket, nil) do
    socket
    |> assign(conversation: nil, callback_offered?: false, callback_error: nil)
    |> assign(call: nil, call_requested?: false)
    |> stream(:messages, [], reset: true)
  end

  defp assign_conversation(socket, conversation) do
    socket
    |> assign(:conversation, Map.delete(conversation, :messages))
    |> assign(:callback_offered?, waited_long_enough?(conversation))
    |> assign(:callback_error, nil)
    |> assign(call: Calls.open_call(conversation.id), call_requested?: false)
    |> stream(:messages, conversation.messages, reset: true)
  end

  # #95: after the waiting time, or right away when nobody is at the desk
  defp waited_long_enough?(%{state: :waiting} = conversation) do
    MercatorWeb.Presence.available_count() == 0 or
      DateTime.diff(DateTime.utc_now(), conversation.inserted_at) >= Conversations.wait_seconds()
  end

  defp waited_long_enough?(_conversation), do: false

  defp new_form, do: to_form(%{"body" => ""}, as: :chat)

  defp active_call?(%{assigns: %{call: %Call{state: :active}, conversation: %{}}}), do: true
  defp active_call?(_socket), do: false

  defp consultant_name(%{consultant: %{name: name}}) when is_binary(name) and name != "", do: name
  defp consultant_name(_conversation), do: gettext("Your consultant")

  # receive the conversation's messages and appear online on the sales desk
  defp follow(conversation) do
    Conversations.subscribe(conversation.id)
    MercatorWeb.Presence.track_customer(self(), conversation.id)
  end

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
        {:noreply, clear_input(socket)}

      true ->
        context = Map.put_new(socket.assigns.context, :page, params["page"])
        {:ok, conversation} = Conversations.start(owner, body, context)
        follow(conversation)

        {:noreply,
         socket
         |> assign_conversation(conversation)
         |> assign(rating_for: nil, rated?: false)
         |> clear_input()}
    end
  end

  # the customer moved to another shop page (reported by the hook)
  def handle_event("location", %{"path" => path}, socket) do
    if conversation = socket.assigns.conversation,
      do: Conversations.visit(socket.assigns.basket_owner, conversation.id, path)

    {:noreply, socket}
  end

  # the countdown in the browser has run out
  def handle_event("waited", _params, socket) do
    {:noreply, assign(socket, :callback_offered?, socket.assigns.conversation != nil)}
  end

  def handle_event("callback", %{"kind" => kind, "contact" => contact}, socket)
      when kind in ["email", "phone"] do
    case Conversations.request_callback(
           socket.assigns.basket_owner,
           socket.assigns.conversation.id,
           String.to_existing_atom(kind),
           contact
         ) do
      {:ok, conversation} ->
        {:noreply,
         assign(socket, conversation: Map.delete(conversation, :messages), callback_error: nil)}

      {:error, _} ->
        {:noreply,
         assign(
           socket,
           :callback_error,
           gettext("Please enter a valid email address or phone number.")
         )}
    end
  end

  def handle_event("end", _params, socket) do
    case Conversations.close(socket.assigns.basket_owner, socket.assigns.conversation.id) do
      {:ok, conversation} -> {:noreply, ended(socket, conversation)}
      _ -> {:noreply, socket |> assign_conversation(nil) |> assign(open?: false)}
    end
  end

  # #101: 1 to 5 stars and a comment for an answered conversation
  def handle_event("rate", %{"rating" => rating} = params, socket)
      when rating in ~w(1 2 3 4 5) do
    case Conversations.rate(
           socket.assigns.basket_owner,
           socket.assigns.rating_for.id,
           String.to_integer(rating),
           params["comment"]
         ) do
      {:ok, _conversation} -> {:noreply, assign(socket, rating_for: nil, rated?: true)}
      _ -> {:noreply, assign(socket, :rating_for, nil)}
    end
  end

  def handle_event("rate", _params, socket), do: {:noreply, socket}

  # --- calls (phase 10) ---

  def handle_event("request_call", _params, socket) do
    case Conversations.request_call(socket.assigns.basket_owner, socket.assigns.conversation.id) do
      :ok -> {:noreply, assign(socket, :call_requested?, true)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("accept_call", _params, %{assigns: %{call: %Call{} = call}} = socket) do
    case Conversations.accept_call(socket.assigns.basket_owner, call.id) do
      {:ok, call} -> {:noreply, assign(socket, call: call, call_error: nil)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  def handle_event("hang_up_call", _params, %{assigns: %{call: %Call{} = call}} = socket) do
    Conversations.hang_up_call(socket.assigns.basket_owner, call.id)
    {:noreply, socket}
  end

  # the call area has microphone (and camera): join the media
  def handle_event("call_media_ready", _params, socket) do
    if active_call?(socket),
      do: Calls.join(socket.assigns.conversation.id, :customer, self())

    {:noreply, socket}
  end

  def handle_event("call_signal", params, socket) do
    if active_call?(socket),
      do:
        Calls.signal(
          socket.assigns.conversation.id,
          :customer,
          Map.take(params, ~w(type sdp candidate))
        )

    {:noreply, socket}
  end

  # no microphone, or the permission was refused
  def handle_event("call_media_error", _params, %{assigns: %{call: %Call{} = call}} = socket) do
    Calls.finish(call, :failed)

    {:noreply,
     assign(
       socket,
       :call_error,
       gettext("The call needs your microphone. Please allow access and try again.")
     )}
  end

  def handle_event("call_video", _params, %{assigns: %{call: %Call{} = call}} = socket) do
    Ash.update(call, %{video: true}, action: :note_media, authorize?: false)
    {:noreply, socket}
  end

  def handle_event("call_" <> _event, _params, socket), do: {:noreply, socket}

  def handle_event("skip_rating", _params, socket),
    do: {:noreply, assign(socket, rating_for: nil, open?: false)}

  @impl true
  def handle_info({:message, message}, socket) do
    unread = if socket.assigns.open?, do: 0, else: socket.assigns.unread + 1
    {:noreply, socket |> stream_insert(:messages, message) |> assign(:unread, unread)}
  end

  def handle_info({:visit, _path}, socket), do: {:noreply, socket}

  def handle_info({:call, %Call{state: :ended}}, socket),
    do: {:noreply, assign(socket, call: nil, call_requested?: false)}

  # a ringing call opens the panel
  def handle_info({:call, %Call{state: :ringing} = call}, socket),
    do: {:noreply, assign(socket, call: call, call_error: nil, open?: true, unread: 0)}

  def handle_info({:call, call}, socket), do: {:noreply, assign(socket, :call, call)}

  # signaling from the media room to the call area's hook
  def handle_info({:call_signal, _conversation_id, message}, socket),
    do: {:noreply, push_event(socket, "call:signal", message)}

  def handle_info({:conversation, %{state: :closed} = conversation}, socket) do
    {:noreply, ended(socket, conversation)}
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
          "card relative h-[min(44rem,calc(100vh-7rem))] w-[min(32rem,calc(100vw-2rem))] max-h-[calc(100vh-7rem)] max-w-[calc(100vw-2rem)] flex-col overflow-hidden bg-base-100 shadow-xl",
          if(@open?, do: "flex", else: "hidden")
        ]}
        id="chat-panel"
        aria-label={gettext("Advice")}
      >
        <%!-- drag to resize (the panel grows up and to the left), double-click resets --%>
        <div
          id="chat-resize"
          phx-hook=".ResizeChat"
          data-panel="chat-panel"
          class="absolute top-0 left-0 z-10 hidden size-4 cursor-nwse-resize touch-none sm:block"
          title={gettext("Drag to resize, double-click to reset")}
          aria-hidden="true"
        >
          <span class="absolute top-1 left-1 size-2 rounded-tl-sm border-t-2 border-l-2 border-primary-content/70"></span>
        </div>
        <header class="flex items-center gap-2 bg-primary px-4 py-3 text-primary-content">
          <.icon name="hero-chat-bubble-left-right" class="size-5" />
          <div class="min-w-0 flex-1">
            <p class="font-semibold">{gettext("Advice")}</p>
            <p class="text-xs leading-snug opacity-80" id="chat-status">{status(@conversation)}</p>
          </div>
          <button
            :if={@conversation && @conversation.state == :active && !@call}
            type="button"
            phx-click="request_call"
            disabled={@call_requested?}
            class="btn btn-ghost btn-xs text-primary-content disabled:text-primary-content/60"
            title={
              if @call_requested?, do: gettext("Call requested"), else: gettext("Ask for a call")
            }
            aria-label={gettext("Ask for a call")}
            id="chat-request-call"
          >
            <.icon name="hero-phone" class="size-4" />
          </button>
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

        <.call_area
          :if={@call || @call_error}
          call={@call}
          error={@call_error}
          name={consultant_name(@conversation)}
        />

        <div class="flex-1 space-y-2 overflow-y-auto p-3" id="chat-scroll" phx-hook=".ScrollDown">
          <.rating_form :if={@rating_for} />
          <p :if={@rated?} class="alert alert-success py-2 text-sm" id="chat-rated">
            <.icon name="hero-heart" class="size-5" /> {gettext("Thank you for your rating!")}
          </p>
          <div :if={!@conversation and !@rating_for} class="space-y-2 text-sm" id="chat-intro">
            <p>{gettext("Our experts are happy to help you choose – just ask your question.")}</p>
            <p class="text-xs opacity-70" id="chat-help">
              {gettext("Answers to common questions are also in the")}
              <a href={~p"/help"} class="link">{gettext("help")}</a>.
            </p>
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
              <div
                :if={message.body}
                class={[
                  "chat-bubble whitespace-pre-line text-sm",
                  message.sender_kind == :customer && "chat-bubble-primary",
                  message.sender_kind == :system && "chat-bubble-neutral"
                ]}
              >
                {message.body}
              </div>
              <div class={if message.sender_kind == :customer, do: "col-start-1", else: "col-start-2"}>
                <.attachment message={message} locale={@locale} />
              </div>
            </div>
          </div>
          <.waiting
            :if={@conversation && @conversation.state == :waiting}
            conversation={@conversation}
            offered?={@callback_offered?}
            error={@callback_error}
          />
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
            id={"chat-input-#{@sent}"}
            phx-mounted={@sent > 0 && JS.focus()}
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
          // tell the consultant which page the customer is on (also after live navigation)
          this.onPage = () => this.pushEvent("location", {path: window.location.pathname})
          window.addEventListener("phx:page-loading-stop", this.onPage)
          this.onPage()
          // the page the question is asked on
          this.el.addEventListener("submit", () => {
            const page = this.el.querySelector("#chat-page")
            if (page) page.value = window.location.pathname
          }, true)
        },
        destroyed() {
          window.removeEventListener("mercator:open-chat", this.onOpen)
          window.removeEventListener("phx:page-loading-stop", this.onPage)
        }
      }
    </script>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".ResizeChat">
      // The panel's size, dragged at its top-left corner and kept per browser.
      // Set through this.js(), so LiveView keeps it across page updates.
      const KEY = "mercator:chat-size"
      export default {
        mounted() {
          this.panel = document.getElementById(this.el.dataset.panel)
          try { const size = JSON.parse(localStorage.getItem(KEY)); if (size) this.apply(size.w, size.h) } catch (_e) {}

          this.el.addEventListener("pointerdown", (e) => {
            e.preventDefault()
            this.el.setPointerCapture(e.pointerId)
            const rect = this.panel.getBoundingClientRect()
            this.start = {x: e.clientX, y: e.clientY, w: rect.width, h: rect.height}
          })
          this.el.addEventListener("pointermove", (e) => {
            if (!this.start) return
            this.apply(this.start.w + this.start.x - e.clientX, this.start.h + this.start.y - e.clientY)
          })
          this.el.addEventListener("pointerup", () => {
            if (!this.start) return
            this.start = null
            const rect = this.panel.getBoundingClientRect()
            try { localStorage.setItem(KEY, JSON.stringify({w: rect.width, h: rect.height})) } catch (_e) {}
          })
          this.el.addEventListener("dblclick", () => {
            this.js().removeAttribute(this.panel, "style")
            try { localStorage.removeItem(KEY) } catch (_e) {}
          })
        },
        // at least the size of a phone panel; the CSS max-width/height keep it in the window
        apply(w, h) {
          const width = Math.max(320, Math.round(w)), height = Math.max(420, Math.round(h))
          this.js().setAttribute(this.panel, "style", `width: ${width}px; height: ${height}px`)
        }
      }
    </script>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Countdown">
      export default {
        mounted() { this.tick(); this.timer = setInterval(() => this.tick(), 1000) },
        destroyed() { clearInterval(this.timer) },
        tick() {
          const left = Math.max(0, Math.round((Number(this.el.dataset.until) - Date.now()) / 1000))
          const out = this.el.querySelector("[data-remaining]")
          if (out) out.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`
          if (left === 0) { clearInterval(this.timer); this.pushEvent("waited", {}) }
        }
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

  attr :call, :map, default: nil
  attr :error, :string, default: nil
  attr :name, :string, required: true

  # the consultant calls: ringing, then the call itself (phase 10)
  defp call_area(assigns) do
    ~H"""
    <div class="space-y-2 border-b border-base-200 p-3" id="chat-call">
      <p :if={@error} class="alert alert-warning py-2 text-sm" id="chat-call-error">
        <.icon name="hero-microphone" class="size-5" /> {@error}
      </p>
      <div
        :if={@call && @call.state == :ringing}
        class="flex items-center gap-3"
        id="chat-call-ringing"
      >
        <span class="relative flex size-10 items-center justify-center rounded-full bg-success text-success-content">
          <span class="absolute inline-flex size-full animate-ping rounded-full bg-success opacity-50"></span>
          <.icon
            name={if @call.video, do: "hero-video-camera", else: "hero-phone"}
            class="relative size-5"
          />
        </span>
        <p class="flex-1 text-sm font-semibold">{gettext("%{name} is calling", name: @name)}</p>
        <button
          type="button"
          phx-click="accept_call"
          class="btn btn-success btn-sm"
          id="chat-accept-call"
        >
          {pgettext("call", "Answer")}
        </button>
        <button
          type="button"
          phx-click="hang_up_call"
          class="btn btn-ghost btn-sm"
          id="chat-decline-call"
        >
          {pgettext("call", "Decline")}
        </button>
      </div>
      <div :if={@call && @call.state == :active} class="space-y-2" id="chat-call-active">
        <%!-- the customer starts with audio only (#142) --%>
        <.call_media id="chat-call-media" peer={@name} />
        <button
          type="button"
          phx-click="hang_up_call"
          class="btn btn-error btn-sm w-full"
          id="chat-hang-up"
        >
          <.icon name="hero-phone-x-mark" class="size-4" /> {gettext("Hang up")}
        </button>
      </div>
    </div>
    """
  end

  attr :conversation, :map, required: true
  attr :offered?, :boolean, required: true
  attr :error, :string, default: nil

  # #95: countdown while a consultant is sought, then the callback form
  defp waiting(assigns) do
    assigns =
      assign(
        assigns,
        :until,
        assigns.conversation.inserted_at
        |> DateTime.add(Conversations.wait_seconds())
        |> DateTime.to_unix(:millisecond)
      )

    ~H"""
    <div class="mt-3 text-sm" id="chat-waiting">
      <%= cond do %>
        <% @conversation.callback_requested_at -> %>
          <div class="alert alert-info py-2" id="chat-callback-done">
            <.icon name="hero-check-circle" class="size-5" />
            <span>
              {if @conversation.callback_kind == :email,
                do:
                  gettext("Thank you! We will write to %{contact}.",
                    contact: @conversation.callback_contact
                  ),
                else:
                  gettext("Thank you! We will call you at %{contact}.",
                    contact: @conversation.callback_contact
                  )}
            </span>
          </div>
        <% @offered? -> %>
          <form class="space-y-2 rounded-box bg-base-200 p-3" id="chat-callback" phx-submit="callback">
            <p>{gettext("Sorry, nobody is available right now. May we contact you?")}</p>
            <div class="join w-full">
              <label class="join-item btn btn-sm flex-1 has-[:checked]:btn-primary">
                <input type="radio" name="kind" value="email" checked class="sr-only" /> {gettext(
                  "Email"
                )}
              </label>
              <label class="join-item btn btn-sm flex-1 has-[:checked]:btn-primary">
                <input type="radio" name="kind" value="phone" class="sr-only" /> {gettext("Phone")}
              </label>
            </div>
            <input
              type="text"
              name="contact"
              class="input input-sm w-full"
              placeholder={gettext("Email address or phone number")}
              aria-label={gettext("Email address or phone number")}
              id="chat-callback-contact"
            />
            <p :if={@error} class="text-error" id="chat-callback-error">{@error}</p>
            <button type="submit" class="btn btn-primary btn-sm w-full" id="chat-callback-send">
              {gettext("Please contact me")}
            </button>
          </form>
        <% true -> %>
          <p
            class="text-base-content/70"
            id="chat-countdown"
            phx-hook=".Countdown"
            data-until={@until}
          >
            {gettext("A consultant will be with you shortly …")}
            <span data-remaining class="font-mono"></span>
          </p>
      <% end %>
    </div>
    """
  end

  # a closed conversation: ask for a rating if a consultant advised, else close the panel
  defp ended(socket, conversation) do
    socket = socket |> assign_conversation(nil) |> assign(context: %{})

    if Conversations.rateable?(conversation),
      do: assign(socket, rating_for: conversation, rated?: false),
      else: assign(socket, open?: false)
  end

  # The form has no phx-change, so the server's value stays "" and resetting it
  # changes nothing in the browser: a new textarea (new id) is empty.
  defp clear_input(socket),
    do: socket |> assign(:form, new_form()) |> update(:sent, &(&1 + 1))

  defp rating_form(assigns) do
    ~H"""
    <form id="chat-rating" phx-submit="rate" class="space-y-3 rounded-box bg-base-200 p-4 text-sm">
      <p class="font-semibold">{gettext("How satisfied were you with our advice?")}</p>
      <div class="rating rating-lg" id="chat-rating-stars">
        <input
          :for={stars <- 1..5}
          type="radio"
          name="rating"
          value={stars}
          class="mask mask-star-2 bg-warning"
          aria-label={ngettext("1 star", "%{count} stars", stars)}
          id={"chat-rating-#{stars}"}
        />
      </div>
      <textarea
        name="comment"
        rows="2"
        maxlength="2000"
        class="textarea textarea-sm w-full"
        placeholder={gettext("Anything you want to tell us? (optional)")}
        id="chat-rating-comment"
      ></textarea>
      <div class="flex justify-end gap-2">
        <button
          type="button"
          phx-click="skip_rating"
          class="btn btn-ghost btn-sm"
          id="chat-rating-skip"
        >
          {gettext("No, thanks")}
        </button>
        <button type="submit" class="btn btn-primary btn-sm" id="chat-rating-send">
          {gettext("Send rating")}
        </button>
      </div>
    </form>
    """
  end

  defp status(nil), do: gettext("Ask us anything")
  defp status(%{state: :waiting}), do: gettext("We are connecting you with a consultant …")

  defp status(%{consultant: %{name: name}}) when is_binary(name),
    do: gettext("You are talking to %{name}", name: name)

  defp status(_conversation), do: gettext("A consultant is with you")
end
