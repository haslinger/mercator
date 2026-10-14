defmodule MercatorWeb.Admin.SubmissionLive do
  @moduledoc """
  Contact requests from the contact form (`/admin/submissions`, #83):
  open ones first, newest first; staff mark them as handled.
  """
  use MercatorWeb, :live_view

  require Ash.Query

  alias Mercator.Content
  alias Mercator.Content.Submission
  alias MercatorWeb.Format

  on_mount {MercatorWeb.LiveUserAuth,
            {:require_any_role, [:sales, :sales_manager, :contentmanager, :administrator]}}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Contact requests"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, socket |> assign(:show_all?, params["all"] == "1") |> load()}
  end

  defp load(socket) do
    query =
      Submission
      |> Ash.Query.load(:page)
      |> Ash.Query.sort(inserted_at: :desc)
      |> then(&if(socket.assigns.show_all?, do: &1, else: Ash.Query.filter(&1, not handled)))

    assign(socket, :submissions, Ash.read!(query, actor: socket.assigns.current_user))
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    submission = Enum.find(socket.assigns.submissions, &(&1.id == id))

    if submission.handled,
      do: Content.mark_submission_open!(submission, actor: actor),
      else: Content.mark_submission_handled!(submission, actor: actor)

    {:noreply, load(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_user={@current_user} locale={@locale} active="submissions">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h1 class="text-3xl font-bold">{gettext("Contact requests")}</h1>
        <div class="join">
          <.link
            patch={~p"/admin/submissions"}
            class={["join-item btn btn-sm", !@show_all? && "btn-active"]}
            id="show-open"
          >
            {gettext("Open")}
          </.link>
          <.link
            patch={~p"/admin/submissions?all=1"}
            class={["join-item btn btn-sm", @show_all? && "btn-active"]}
            id="show-all"
          >
            {gettext("All")}
          </.link>
        </div>
      </div>

      <p :if={@submissions == []} class="text-base-content/70" id="no-submissions">
        {gettext("No contact requests.")}
      </p>
      <ul class="space-y-3" id="submissions">
        <li
          :for={submission <- @submissions}
          class={["card bg-base-100 shadow-sm", submission.handled && "opacity-60"]}
          id={"submission-#{submission.id}"}
        >
          <div class="card-body gap-2">
            <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
              <span class="font-semibold">{submission.name}</span>
              <a href={"mailto:#{submission.email}"} class="link text-sm">{submission.email}</a>
              <a :if={submission.phone} href={"tel:#{submission.phone}"} class="link text-sm">{submission.phone}</a>
              <span class="ml-auto text-sm text-base-content/60">
                {Format.datetime(submission.inserted_at)}
                <span :if={submission.page}>· /pages/{submission.page.path}</span>
              </span>
            </div>
            <p class="whitespace-pre-line">{submission.message}</p>
            <button
              type="button"
              phx-click="toggle"
              phx-value-id={submission.id}
              class={[
                "btn btn-sm w-fit",
                if(submission.handled, do: "btn-ghost", else: "btn-primary")
              ]}
              id={"toggle-#{submission.id}"}
            >
              {if submission.handled, do: gettext("Reopen"), else: gettext("Mark as handled")}
            </button>
          </div>
        </li>
      </ul>
    </Layouts.admin>
    """
  end
end
