defmodule MercatorWeb.Admin.DeskLive do
  @moduledoc """
  The sales desk (`/admin/desk`, guided selling step 2): consultants say
  whether they are available (Phoenix Presence), see waiting and open
  conversations, take one and chat with the customer. Available consultants
  are notified of new conversations with a tone and a browser notification.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.ConsultingComponents, only: [attachment: 1]
  import MercatorWeb.OfferComponents, only: [state_badge: 1]

  alias Mercator.{Catalog, Content}
  alias Mercator.Consulting.{Desk, Offer, Offers}
  alias Mercator.Content.FileTypes
  alias Mercator.Sales.Baskets
  alias MercatorWeb.{Format, Presence}

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mercator.PubSub, "desk")
      # customers coming online or leaving (their chat widget)
      Phoenix.PubSub.subscribe(Mercator.PubSub, Presence.chat_topic())
      # the selected customer's basket changes
      Phoenix.PubSub.subscribe(Mercator.PubSub, "baskets")

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
       context: nil,
       share: nil,
       share_query: "",
       share_results: [],
       share_error: nil,
       form: new_form(),
       sent: 0
     )
     |> allow_upload(:chat_file,
       accept: ~w(.jpg .jpeg .png .webp .pdf) ++ FileTypes.extensions(),
       max_entries: 1,
       max_file_size: 20_000_000
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
    |> assign(:context, Desk.context(conversation, socket.assigns.current_user))
    |> assign(:page_title, conversation.subject || gettext("Sales desk"))
    |> stream(:messages, conversation.messages, reset: true)
  end

  defp unselect(socket) do
    if previous = socket.assigns.selected,
      do: Phoenix.PubSub.unsubscribe(Mercator.PubSub, "conversation:#{previous.id}")

    socket |> assign(selected: nil, context: nil) |> stream(:messages, [], reset: true)
  end

  defp load_lists(socket) do
    actor = socket.assigns.current_user
    active = Desk.active(actor)
    {mine, others} = Enum.split_with(active, &(&1.consultant_id == actor.id))
    assign(socket, waiting: Desk.waiting(actor), mine: mine, others: others)
  end

  defp new_form, do: to_form(%{"body" => ""}, as: :reply)

  # Presence tells the shop whether someone is at the desk; the tab keeps
  # the choice in sessionStorage (event "desk:availability").
  defp set_available(socket, available?) do
    user = socket.assigns.current_user

    Presence.update(self(), Presence.topic(), user.id, %{
      available: available?,
      name: Desk.display_name(user)
    })

    socket
    |> assign(:available?, available?)
    |> push_event("desk:availability", %{available: available?})
  end

  # --- events ---

  @impl true
  def handle_event("availability", _params, socket),
    do: {:noreply, set_available(socket, !socket.assigns.available?)}

  # after a reload or reconnect the hook restores the tab's last choice
  def handle_event("restore_availability", %{"available" => available?}, socket)
      when is_boolean(available?),
      do: {:noreply, set_available(socket, available?)}

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

  # sharing (step 3, #96): products, links, files of the media library
  def handle_event("create_offer", _params, socket) do
    case Offers.create_for_conversation(socket.assigns.selected, socket.assigns.current_user) do
      {:ok, offer} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/offers/#{offer.id}")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The offer could not be created."))}
    end
  end

  def handle_event("share_open", %{"kind" => kind}, socket)
      when kind in ~w(product link file upload) do
    kind = String.to_existing_atom(kind)

    {:noreply,
     socket |> assign(share: kind, share_query: "", share_error: nil) |> load_share_results()}
  end

  def handle_event("share_close", _params, socket) do
    socket =
      Enum.reduce(socket.assigns.uploads.chat_file.entries, socket, fn entry, socket ->
        cancel_upload(socket, :chat_file, entry.ref)
      end)

    {:noreply, assign(socket, :share, nil)}
  end

  # a file from the consultant's computer: stored outside the media library
  def handle_event("upload_validate", _params, socket), do: {:noreply, socket}

  def handle_event("upload_cancel", %{"ref" => ref}, socket),
    do: {:noreply, cancel_upload(socket, :chat_file, ref)}

  def handle_event("upload_share", _params, socket) do
    %{selected: conversation, current_user: user} = socket.assigns

    results =
      consume_uploaded_entries(socket, :chat_file, fn %{path: path}, entry ->
        {:ok,
         Content.upload_chat_file(%{source_path: path, original_filename: entry.client_name},
           actor: user
         )}
      end)

    case results do
      [{:ok, asset}] ->
        shared(socket, Desk.share_file(conversation, user, asset.id))

      [{:error, _error}] ->
        {:noreply,
         assign(socket, :share_error, gettext("The file could not be read. Please try another."))}

      [] ->
        {:noreply, assign(socket, :share_error, gettext("Please choose a file."))}
    end
  end

  def handle_event("share_search", %{"q" => query}, socket) do
    {:noreply, socket |> assign(:share_query, query) |> load_share_results()}
  end

  def handle_event("share_product", %{"id" => id}, socket) do
    shared(socket, Desk.recommend(socket.assigns.selected, socket.assigns.current_user, id))
  end

  def handle_event("share_file", %{"id" => id}, socket) do
    shared(socket, Desk.share_file(socket.assigns.selected, socket.assigns.current_user, id))
  end

  def handle_event("share_link", %{"url" => url} = params, socket) do
    title = params |> Map.get("title", "") |> String.trim()
    title = if title == "", do: nil, else: title

    shared(
      socket,
      Desk.share_link(socket.assigns.selected, socket.assigns.current_user, url, title)
    )
  end

  def handle_event("send", %{"reply" => %{"body" => body}}, socket) do
    case String.trim(body) do
      "" ->
        {:noreply, socket}

      body ->
        Desk.post(socket.assigns.selected, socket.assigns.current_user, body)
        # a new textarea (new id) is empty; resetting the value alone changes nothing
        {:noreply, socket |> assign(:form, new_form()) |> update(:sent, &(&1 + 1))}
    end
  end

  defp shared(socket, {:ok, _message}), do: {:noreply, assign(socket, :share, nil)}

  defp shared(socket, {:error, _error}) do
    {:noreply,
     assign(
       socket,
       :share_error,
       gettext("Please enter a shop page (starting with /) or a web address.")
     )}
  end

  defp load_share_results(%{assigns: %{share: :product, share_query: query}} = socket) do
    results =
      case String.trim(query) do
        "" ->
          []

        query ->
          query |> Catalog.search_products!(actor: socket.assigns.current_user) |> Enum.take(10)
      end

    assign(socket, :share_results, results)
  end

  defp load_share_results(%{assigns: %{share: :file, share_query: query}} = socket) do
    assign(socket, :share_results, Content.search_assets!(%{query: query}) |> Enum.take(24))
  end

  defp load_share_results(socket), do: assign(socket, :share_results, [])

  defp share_title(:product), do: gettext("Recommend a product")
  defp share_title(:link), do: gettext("Share a link")
  defp share_title(:file), do: gettext("File from the media library")
  defp share_title(:upload), do: gettext("File from my computer")

  defp upload_error(:too_large), do: gettext("The file is larger than 20 MB.")
  defp upload_error(:not_accepted), do: gettext("This file type cannot be shared.")
  defp upload_error(:too_many_files), do: gettext("One file at a time.")
  defp upload_error(_error), do: gettext("The file could not be uploaded.")

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
              conversation
              |> Map.take([
                :state,
                :consultant_id,
                :consultant,
                :callback_kind,
                :callback_contact,
                :callback_requested_at,
                :closed_at
              ])
              |> Map.reject(fn {_key, value} -> match?(%Ash.NotLoaded{}, value) end)
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

  # the customer moved to another page: show it and refresh the basket etc.
  def handle_info({:visit, path}, %{assigns: %{selected: %{} = selected}} = socket) do
    selected = %{selected | current_page: path}
    context = Desk.context(selected, socket.assigns.current_user)
    {:noreply, assign(socket, selected: selected, context: context)}
  end

  def handle_info({:visit, _path}, socket), do: {:noreply, socket}

  def handle_info({:basket_changed, key}, %{assigns: %{selected: %{} = selected}} = socket) do
    if Baskets.owner_key(Desk.basket_owner(selected)) == key,
      do:
        {:noreply, assign(socket, :context, Desk.context(selected, socket.assigns.current_user))},
      else: {:noreply, socket}
  end

  def handle_info({:basket_changed, _key}, socket), do: {:noreply, socket}

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    case socket.assigns.selected do
      nil ->
        {:noreply, socket}

      selected ->
        {:noreply, assign(socket, :context, Desk.context(selected, socket.assigns.current_user))}
    end
  end

  def handle_info(:tick, socket), do: {:noreply, load_lists(socket)}

  # a conversation that was just started (not one that changed later)
  defp new?(conversation), do: DateTime.diff(DateTime.utc_now(), conversation.inserted_at) < 10

  # --- rendering ---

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="desk" wide>
      <div class="flex flex-wrap items-center justify-between gap-2" id="desk" phx-hook=".DeskNotify">
        <h1 class="text-3xl font-bold">{gettext("Sales desk")}</h1>
        <.link navigate={~p"/admin/conversations"} class="btn btn-ghost ml-auto" id="to-archive">
          <.icon name="hero-archive-box" class="size-5" /> {pgettext("conversations", "Archive")}
        </.link>
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

      <div class="grid gap-6 lg:grid-cols-[18rem_1fr] xl:grid-cols-[18rem_1fr_22rem] 2xl:grid-cols-[20rem_1fr_26rem]">
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
          class="card flex h-[calc(100vh-13rem)] min-h-[32rem] flex-col overflow-hidden bg-base-100 shadow-sm"
          id="conversation"
        >
          <header class="flex flex-wrap items-center gap-2 border-b border-base-200 p-4">
            <div class="min-w-0 flex-1">
              <p class="flex items-center gap-2 font-semibold" id="conversation-customer">
                <span
                  class={[
                    "inline-block size-2.5 rounded-full",
                    if(@context.online?, do: "bg-success", else: "bg-base-300")
                  ]}
                  title={if @context.online?, do: gettext("online"), else: gettext("offline")}
                  data-online={to_string(@context.online?)}
                  id="customer-online"
                ></span>
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
            <span
              :if={@selected.state == :closed}
              class="badge badge-neutral"
              id="conversation-closed"
            >
              {gettext("Ended")}
              <span :if={@selected.closed_at}>{Format.datetime(@selected.closed_at)}</span>
            </span>
            <button
              :if={
                @selected.state == :waiting or
                  (@selected.state == :active and @selected.consultant_id != @current_user.id)
              }
              type="button"
              phx-click="take"
              class="btn btn-primary btn-sm"
              id="take"
            >
              {if @selected.state == :waiting, do: gettext("Take"), else: gettext("Take over")}
            </button>
            <button
              :if={@selected.state != :closed}
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
                <div
                  :if={message.body}
                  class={[
                    "chat-bubble whitespace-pre-line text-sm",
                    message.sender_kind == :consultant && "chat-bubble-primary",
                    message.sender_kind == :system && "chat-bubble-neutral"
                  ]}
                >
                  {message.body}
                </div>
                <div class={attachment_column(message.sender_kind == :customer)}>
                  <.attachment message={message} locale={@locale} desk />
                </div>
              </div>
            </div>
          </div>

          <p
            :if={@selected.state == :closed}
            class="border-t border-base-200 p-3 text-sm text-base-content/60"
            id="conversation-ended"
          >
            {gettext("This conversation has ended; it can only be read.")}
          </p>
          <.form
            :if={@selected.state != :closed}
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
              id={"reply-input-#{@sent}"}
              phx-mounted={@sent > 0 && JS.focus()}
            >{@form[:body].value}</textarea>
            <div class="flex flex-col gap-1 self-end">
              <div class="dropdown dropdown-top dropdown-end" id="share-menu">
                <div tabindex="0" role="button" class="btn btn-ghost btn-sm w-full">
                  <.icon name="hero-paper-clip" class="size-4" /> {gettext("Share")}
                </div>
                <ul
                  tabindex="0"
                  class="menu dropdown-content z-10 mb-1 w-56 rounded-box bg-base-100 p-2 shadow"
                >
                  <li>
                    <button
                      type="button"
                      phx-click="share_open"
                      phx-value-kind="product"
                      id="share-product"
                    >
                      <.icon name="hero-cube" class="size-4" /> {gettext("Recommend a product")}
                    </button>
                  </li>
                  <li>
                    <button type="button" phx-click="share_open" phx-value-kind="link" id="share-link">
                      <.icon name="hero-link" class="size-4" /> {gettext("Share a link")}
                    </button>
                  </li>
                  <li>
                    <button type="button" phx-click="share_open" phx-value-kind="file" id="share-file">
                      <.icon name="hero-document" class="size-4" /> {gettext(
                        "File from the media library"
                      )}
                    </button>
                  </li>
                  <li>
                    <button
                      type="button"
                      phx-click="share_open"
                      phx-value-kind="upload"
                      id="share-upload"
                    >
                      <.icon name="hero-arrow-up-tray" class="size-4" /> {gettext(
                        "File from my computer"
                      )}
                    </button>
                  </li>
                </ul>
              </div>
              <button type="submit" class="btn btn-primary" id="reply-send">
                <.icon name="hero-paper-airplane" class="size-5" /> {gettext("Send")}
              </button>
            </div>
          </.form>
        </section>

        <div :if={@share} class="modal modal-open" id="share-modal">
          <div class="modal-box max-w-2xl">
            <h2 class="text-xl font-bold">{share_title(@share)}</h2>

            <form
              :if={@share in [:product, :file]}
              id="share-search"
              phx-change="share_search"
              phx-submit="share_search"
              class="mt-4"
            >
              <input
                type="search"
                name="q"
                value={@share_query}
                placeholder={
                  if @share == :product,
                    do: gettext("Search products or article numbers"),
                    else: gettext("Search the media library")
                }
                phx-debounce="300"
                class="input w-full"
                id="share-query"
                autofocus
              />
            </form>

            <ul
              :if={@share == :product}
              class="mt-3 max-h-80 divide-y divide-base-200 overflow-y-auto"
              id="share-products"
            >
              <li :for={product <- @share_results} class="flex items-center gap-3 py-2">
                <span class="min-w-0 flex-1">
                  <span class="block truncate font-medium">{Mercator.Translated.t(
                    product.title,
                    @locale
                  )}</span>
                  <span class="text-xs text-base-content/60">{product.number}</span>
                </span>
                <button
                  type="button"
                  phx-click="share_product"
                  phx-value-id={product.id}
                  class="btn btn-primary btn-sm"
                  id={"recommend-#{product.id}"}
                >
                  {gettext("Recommend")}
                </button>
              </li>
            </ul>

            <div
              :if={@share == :file}
              class="mt-3 grid max-h-80 grid-cols-3 gap-2 overflow-y-auto sm:grid-cols-4"
              id="share-files"
            >
              <button
                :for={asset <- @share_results}
                type="button"
                phx-click="share_file"
                phx-value-id={asset.id}
                class="rounded-box border border-base-300 p-1 text-left hover:border-primary"
                id={"share-file-#{asset.id}"}
                title={Mercator.Translated.t(asset.title, @locale) || asset.original_filename}
              >
                <img
                  :if={asset.kind == :image}
                  src={Mercator.Content.Asset.url(asset, :thumb)}
                  alt=""
                  class="aspect-square w-full rounded object-cover"
                />
                <span
                  :if={asset.kind == :document}
                  class="flex aspect-square flex-col items-center justify-center gap-1 bg-base-200 p-1 text-center text-xs"
                >
                  <.icon name="hero-document-text" class="size-6" />
                  <span class="line-clamp-2">{Mercator.Translated.t(asset.title, @locale) ||
                    asset.original_filename}</span>
                </span>
              </button>
            </div>

            <form
              :if={@share == :link}
              id="share-link-form"
              phx-submit="share_link"
              class="mt-4 space-y-2"
            >
              <input
                type="text"
                name="url"
                placeholder={gettext("Shop page (/pages/faq) or web address (https://…)")}
                class="input w-full"
                id="share-url"
                required
              />
              <input
                type="text"
                name="title"
                placeholder={gettext("Title (optional)")}
                class="input w-full"
                id="share-link-title"
              />
              <p :if={@share_error} class="text-sm text-error" id="share-error">{@share_error}</p>
              <button type="submit" class="btn btn-primary" id="share-link-send">{gettext("Send link")}</button>
            </form>

            <form
              :if={@share == :upload}
              id="upload-form"
              phx-change="upload_validate"
              phx-submit="upload_share"
              class="mt-4 space-y-3"
            >
              <label
                class="flex cursor-pointer flex-col items-center gap-2 rounded-box border-2 border-dashed border-base-300 p-8 text-center transition hover:border-primary"
                phx-drop-target={@uploads.chat_file.ref}
                for={@uploads.chat_file.ref}
              >
                <.icon name="hero-arrow-up-tray" class="size-8 text-primary" />
                <span>{gettext("Drop a file here or click to choose one")}</span>
                <span class="text-xs text-base-content/60">
                  {gettext(
                    "Images, PDF, Word, Excel, LibreOffice (ODT, ODS) or AutoCAD (DWG, DXF), up to 20 MB"
                  )}
                </span>
                <.live_file_input upload={@uploads.chat_file} class="hidden" />
              </label>
              <div
                :for={entry <- @uploads.chat_file.entries}
                class="flex items-center gap-3"
                id={"upload-entry-#{entry.ref}"}
              >
                <.live_img_preview
                  :if={String.starts_with?(entry.client_type, "image/")}
                  entry={entry}
                  class="size-14 rounded object-cover"
                />
                <.icon
                  :if={!String.starts_with?(entry.client_type, "image/")}
                  name="hero-document-text"
                  class="size-10 text-primary"
                />
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm">{entry.client_name}</p>
                  <progress class="progress progress-primary w-full" value={entry.progress} max="100"></progress>
                  <p
                    :for={error <- upload_errors(@uploads.chat_file, entry)}
                    class="text-sm text-error"
                  >
                    {upload_error(error)}
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="upload_cancel"
                  phx-value-ref={entry.ref}
                  class="btn btn-ghost btn-sm btn-square"
                  aria-label={gettext("Remove")}
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>
              <p :if={@share_error} class="text-sm text-error" id="upload-error">{@share_error}</p>
              <button
                type="submit"
                class="btn btn-primary"
                disabled={@uploads.chat_file.entries == []}
                id="upload-send"
              >
                <.icon name="hero-paper-airplane" class="size-4" /> {gettext("Send")}
              </button>
            </form>

            <p
              :if={@share in [:product, :file] and @share_results == []}
              class="mt-3 text-sm text-base-content/60"
            >
              {gettext("Nothing found.")}
            </p>

            <div class="modal-action">
              <button type="button" phx-click="share_close" class="btn btn-ghost">{gettext("Close")}</button>
            </div>
          </div>
        </div>

        <.customer_context
          :if={@selected}
          conversation={@selected}
          context={@context}
          locale={@locale}
        />
      </div>
    </Layouts.admin>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".DeskNotify">
      export default {
        restoreAvailability() {
          let stored = null
          try { stored = sessionStorage.getItem("desk-available") } catch (_e) {}
          if (stored === "true") this.pushEvent("restore_availability", {available: true})
        },
        reconnected() { this.restoreAvailability() },
        mounted() {
          // the availability survives reloads and reconnects of this tab, not a new tab
          this.handleEvent("desk:availability", ({available}) => {
            try { sessionStorage.setItem("desk-available", available ? "true" : "false") } catch (_e) {}
          })
          this.restoreAvailability()
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

  attr :conversation, :map, required: true
  attr :context, :map, required: true
  attr :locale, :string, required: true

  # what the consultant knows about the customer (guided selling step 3)
  defp customer_context(assigns) do
    ~H"""
    <aside class="space-y-4 lg:col-span-2 xl:col-span-1" id="customer-context">
      <div class="card bg-base-100 shadow-sm">
        <div class="card-body gap-1 p-4 text-sm">
          <h2 class="font-semibold">{gettext("Now on")}</h2>
          <a
            :if={@conversation.current_page}
            href={@conversation.current_page}
            target="_blank"
            class="link break-all"
            id="customer-page"
          >
            {@conversation.current_page}
          </a>
          <p :if={!@context.online?} class="text-base-content/60">
            {gettext("The customer is not in the shop right now.")}
          </p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm" id="customer-basket">
        <div class="card-body gap-2 p-4 text-sm">
          <h2 class="font-semibold">{gettext("Basket")}</h2>
          <p :if={!@context.basket or @context.basket.lines == []} class="text-base-content/60">
            {gettext("Empty.")}
          </p>
          <ul :if={@context.basket} class="space-y-1">
            <li :for={line <- @context.basket.lines} class="flex justify-between gap-2">
              <span class="min-w-0">
                {Format.quantity(line.item.quantity, line.variant.unit, @locale)}
                {Mercator.Catalog.Unit.symbol(line.variant.unit)}
                {Mercator.Translated.t(line.product.title, @locale)}
              </span>
              <span class="whitespace-nowrap">{line.gross && Format.money(line.gross, @locale)}</span>
            </li>
          </ul>
          <p
            :if={@context.basket && @context.basket.lines != []}
            class="flex justify-between border-t border-base-200 pt-1 font-semibold"
          >
            <span>{gettext("Total")}</span>
            <span>{Format.money(@context.basket.gross, @locale)}</span>
          </p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm" id="customer-offers">
        <div class="card-body gap-2 p-4 text-sm">
          <h2 class="flex items-center justify-between font-semibold">
            {gettext("Offers")}
            <button
              :if={@conversation.customer_id}
              type="button"
              class="btn btn-primary btn-xs"
              phx-click="create_offer"
              id="create-offer"
            >
              <.icon name="hero-plus" class="size-3" /> {gettext("New offer")}
            </button>
          </h2>
          <p :if={!@conversation.customer_id} class="text-base-content/60">
            {gettext("Offers need an account: the customer signs in first.")}
          </p>
          <p
            :if={not is_nil(@conversation.customer_id) and @context.offers == []}
            class="text-base-content/60"
          >
            {gettext("None.")}
          </p>
          <ul class="space-y-1">
            <li :for={offer <- @context.offers} class="flex items-center justify-between gap-2">
              <.link navigate={~p"/admin/offers/#{offer.id}"} class="link">
                {Offer.display_number(offer)}
              </.link>
              <.state_badge state={offer.state} />
              <span class="whitespace-nowrap">{Format.money(offer.gross, @locale)}</span>
            </li>
          </ul>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm" id="customer-earlier">
        <div class="card-body gap-2 p-4 text-sm">
          <h2 class="font-semibold">{gettext("Earlier conversations")}</h2>
          <p :if={@context.earlier == []} class="text-base-content/60">{gettext("None.")}</p>
          <ul class="space-y-1">
            <li :for={earlier <- @context.earlier}>
              <.link
                patch={~p"/admin/desk/#{earlier.id}"}
                class="link"
                id={"earlier-#{earlier.id}"}
              >
                {Format.datetime(earlier.closed_at || earlier.inserted_at)}
              </.link>
              <span :if={earlier.consultant} class="text-base-content/60">
                · {Desk.display_name(earlier.consultant)}
              </span>
              <span :if={earlier.subject} class="block truncate text-base-content/60">
                {earlier.subject}
              </span>
            </li>
          </ul>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm" id="customer-orders">
        <div class="card-body gap-2 p-4 text-sm">
          <h2 class="font-semibold">{gettext("Orders")}</h2>
          <p :if={@context.orders == []} class="text-base-content/60">{gettext("None.")}</p>
          <ul class="space-y-1">
            <li :for={order <- @context.orders} class="flex justify-between gap-2">
              <.link navigate={~p"/admin/orders/#{order.number}"} class="link">{order.number}</.link>
              <span class="text-base-content/60">{Format.date(order.inserted_at)}</span>
              <span class="whitespace-nowrap">{Format.money(order.gross, @locale)}</span>
            </li>
          </ul>
        </div>
      </div>
    </aside>
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

  # attachments sit in the bubble's column of the daisyUI chat grid
  defp attachment_column(true = _start?), do: "col-start-2"
  defp attachment_column(false), do: "col-start-1"

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
