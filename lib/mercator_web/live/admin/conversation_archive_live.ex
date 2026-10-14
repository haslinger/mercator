defmodule MercatorWeb.Admin.ConversationArchiveLive do
  @moduledoc """
  Closed conversations (`/admin/conversations`), for quality assurance and
  to read up on earlier advice: search by customer (name, email) or
  subject, optionally only the consultant's own, newest first. A
  conversation opens read-only on the sales desk.
  """
  use MercatorWeb, :live_view

  import MercatorWeb.ConsultingComponents, only: [stars: 1]

  alias Mercator.Consulting.Desk
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :administrator]}}

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Conversation archive"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_user
    filters = %{"q" => params["q"] || "", "mine" => params["mine"] == "true"}
    page = max(parse_int(params["page"]), 1)

    result =
      Desk.archive(
        user,
        %{query: filters["q"], consultant_id: if(filters["mine"], do: user.id)},
        limit: @per_page,
        offset: (page - 1) * @per_page,
        count: true
      )

    {:noreply,
     socket
     |> assign(filters: filters, page: page, count: result.count)
     |> assign(:pages, max(ceil(result.count / @per_page), 1))
     |> stream(:conversations, result.results, reset: true)}
  end

  defp parse_int(nil), do: 1

  defp parse_int(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> 1
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    query =
      %{"q" => String.trim(params["q"] || ""), "mine" => params["mine"]}
      |> Enum.reject(fn {_key, value} -> value in [nil, "", "false"] end)
      |> Map.new()

    {:noreply, push_patch(socket, to: ~p"/admin/conversations?#{query}")}
  end

  defp page_query(filters, page) do
    filters
    |> Map.put("page", page)
    |> Enum.reject(fn {_key, value} -> value in ["", false] end)
    |> Map.new()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="desk">
      <div class="flex flex-wrap items-baseline justify-between gap-2">
        <div>
          <.link navigate={~p"/admin/desk"} class="link text-sm">← {gettext("Sales desk")}</.link>
          <h1 class="text-3xl font-bold">{gettext("Conversation archive")}</h1>
        </div>
        <span class="text-sm text-base-content/70" id="conversation-count">
          {ngettext("1 conversation", "%{count} conversations", @count)}
        </span>
      </div>

      <form
        id="archive-filters"
        phx-change="filter"
        phx-submit="filter"
        class="flex flex-wrap items-center gap-4"
      >
        <label class="input input-sm w-80">
          <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
          <input
            type="search"
            name="q"
            value={@filters["q"]}
            placeholder={gettext("Customer name, email or subject")}
            phx-debounce="300"
            id="archive-search"
          />
        </label>
        <label class="label cursor-pointer gap-2 text-sm">
          <input type="hidden" name="mine" value="false" />
          <input
            type="checkbox"
            name="mine"
            value="true"
            checked={@filters["mine"]}
            class="checkbox checkbox-sm"
            id="archive-mine"
          />
          {gettext("Only my conversations")}
        </label>
      </form>

      <div class="overflow-x-auto rounded-box bg-base-100 shadow-sm">
        <table class="table">
          <thead>
            <tr>
              <th>{gettext("Ended")}</th>
              <th>{gettext("Customer")}</th>
              <th>{gettext("Subject")}</th>
              <th class="hidden md:table-cell">{gettext("Consultant")}</th>
              <th>{gettext("Rating")}</th>
            </tr>
          </thead>
          <tbody id="conversations" phx-update="stream">
            <tr class="hidden only:table-row" id="no-conversations">
              <td colspan="5" class="text-center text-base-content/70">
                {gettext("No conversations found.")}
              </td>
            </tr>
            <tr
              :for={{dom_id, conversation} <- @streams.conversations}
              id={dom_id}
              class="hover:bg-base-200"
            >
              <td class="whitespace-nowrap">
                <.link navigate={~p"/admin/desk/#{conversation.id}"} class="link font-semibold">
                  {Format.datetime(conversation.closed_at || conversation.updated_at)}
                </.link>
              </td>
              <td>
                {Desk.display_name(conversation.customer)}
                <div :if={conversation.customer} class="text-xs text-base-content/70">
                  {conversation.customer.email}
                </div>
              </td>
              <td class="max-w-xs truncate">{conversation.subject || conversation.page}</td>
              <td class="hidden md:table-cell">
                {conversation.consultant && Desk.display_name(conversation.consultant)}
              </td>
              <td>
                <.stars :if={conversation.rating} rating={conversation.rating} />
                <p
                  :if={conversation.rating_comment}
                  class="max-w-xs truncate text-xs text-base-content/70"
                  title={conversation.rating_comment}
                >
                  {conversation.rating_comment}
                </p>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div :if={@pages > 1} class="join self-center" id="archive-pages">
        <.link
          :for={page <- 1..@pages}
          patch={~p"/admin/conversations?#{page_query(@filters, page)}"}
          class={["join-item btn btn-sm", page == @page && "btn-active"]}
          id={"archive-page-#{page}"}
        >
          {page}
        </.link>
      </div>
    </Layouts.admin>
    """
  end
end
