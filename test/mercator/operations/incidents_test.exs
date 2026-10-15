defmodule Mercator.Operations.IncidentsTest do
  use Mercator.DataCase, async: true

  import Mercator.AccountsFixtures

  alias Mercator.Consulting.Conversations
  alias Mercator.Operations.{Incident, Incidents, JobFailures}

  defp report!(attrs \\ %{}) do
    {:ok, incident} =
      %{kind: :pdf, title: "PDF failed", description: "Send it by hand.", details: "boom"}
      |> Map.merge(attrs)
      |> Incidents.report()

    incident
  end

  describe "report/1" do
    test "creates an open incident without a reporter" do
      incident = report!()

      assert incident.state == :open
      assert incident.kind == :pdf
      assert incident.occurrences == 1
      assert is_nil(incident.reported_by_id)
    end

    test "the same problem counts up the open incident" do
      customer = user_fixture()
      first = report!(%{customer_id: customer.id})
      again = report!(%{customer_id: customer.id, details: "boom again"})

      assert again.id == first.id
      assert again.occurrences == 2
      assert again.details == "boom again"

      # a different subject is a different incident
      refute report!(%{customer_id: user_fixture().id}).id == first.id
    end

    test "after resolving, the problem opens a new incident" do
      admin = user_fixture(roles: [:administrator])
      first = report!()
      {:ok, _resolved} = Incidents.resolve(first, "Fixed the font.", admin)

      refute report!().id == first.id
    end

    @tag :capture_log
    test "never raises: invalid reports return :error" do
      assert :error = Incidents.report(%{kind: :pdf})
    end

    test "tells subscribers" do
      Incidents.subscribe()
      report!()
      assert_receive :incidents_changed
    end
  end

  describe "staff" do
    setup do
      %{
        admin: user_fixture(roles: [:administrator]),
        sales: user_fixture(roles: [:sales]),
        customer: user_fixture()
      }
    end

    test "sales staff record incidents by hand (#107)", %{sales: sales, customer: customer} do
      assert {:ok, incident} =
               Incidents.create(
                 %{title: "Customer says the delivery was damaged", customer_id: customer.id},
                 sales
               )

      assert incident.kind == :manual
      assert incident.reported_by_id == sales.id

      assert {:error, %Ash.Error.Forbidden{}} =
               Incidents.create(%{title: "X"}, user_fixture(roles: [:contentmanager]))
    end

    test "resolving needs a resolution; reopening clears it", %{admin: admin} do
      incident = report!()

      assert {:error, %Ash.Error.Invalid{}} = Incidents.resolve(incident, "", admin)

      assert {:ok, resolved} = Incidents.resolve(incident, "Restarted the job.", admin)
      assert resolved.state == :resolved
      assert resolved.resolved_by_id == admin.id
      assert resolved.resolved_at

      assert {:ok, reopened} = Incidents.reopen(resolved, admin)
      assert reopened.state == :open
      assert is_nil(reopened.resolved_at)
      assert is_nil(reopened.resolved_by_id)
    end

    test "sales see incidents about customers and their own, admins all (#106)", ctx do
      technical = report!(%{title: "Font missing"})
      about_customer = report!(%{title: "PDF failed", customer_id: ctx.customer.id})
      {:ok, own} = Incidents.create(%{title: "Phone call"}, ctx.sales)

      visible = fn actor -> Incident |> Ash.read!(actor: actor) |> Enum.map(& &1.id) end

      assert Enum.sort(visible.(ctx.sales)) == Enum.sort([about_customer.id, own.id])
      assert technical.id in visible.(ctx.admin)
      assert visible.(user_fixture(roles: [:contentmanager])) == []
      assert visible.(ctx.customer) == []

      assert Incidents.open_count(ctx.sales) == 2
    end
  end

  describe "background jobs that failed for good" do
    test "become incidents linked to the order, offer or conversation" do
      {:ok, conversation} = Conversations.start({:session, "incident-test"}, "Hallo")

      job = %Oban.Job{
        id: 42,
        worker: "Mercator.Consulting.Workers.SendReplyNotice",
        args: %{"conversation_id" => conversation.id},
        attempt: 5,
        max_attempts: 5
      }

      JobFailures.handle_event(
        [:oban, :job, :exception],
        %{},
        %{
          state: :discard,
          job: job,
          kind: :error,
          reason: %RuntimeError{message: "SMTP down"},
          stacktrace: []
        },
        nil
      )

      admin = user_fixture(roles: [:administrator])
      assert [incident] = Ash.read!(Incident, actor: admin)
      assert incident.kind == :job
      assert incident.title =~ "SendReplyNotice"
      assert incident.conversation_id == conversation.id
      assert incident.details =~ "SMTP down"
    end

    test "failures that will be retried do not" do
      JobFailures.handle_event([:oban, :job, :exception], %{}, %{state: :failure}, nil)
      assert Ash.read!(Incident, authorize?: false) == []
    end
  end
end
