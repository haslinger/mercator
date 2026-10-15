defmodule MercatorWeb.PdfIncidentTest do
  # not async: points the application at a typst program that does not exist
  use MercatorWeb.ConnCase, async: false
  use Oban.Testing, repo: Mercator.Repo

  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures
  import Swoosh.TestAssertions

  alias Mercator.Operations.Incident
  alias Mercator.Sales.Workers.SendOrderConfirmation

  @moduletag :capture_log

  setup do
    previous = Application.get_env(:mercator, :typst)
    Application.put_env(:mercator, :typst, "/nonexistent/typst")
    on_exit(fn -> restore(previous) end)

    gtc_fixture()
    customer = customer_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants
    %{customer: customer, order: order_fixture(customer, variant)}
  end

  defp restore(nil), do: Application.delete_env(:mercator, :typst)
  defp restore(value), do: Application.put_env(:mercator, :typst, value)

  defp incidents, do: Ash.read!(Incident, authorize?: false)

  # earlier emails, e.g. the account confirmation
  defp flush_emails do
    receive do
      {:email, _email} -> flush_emails()
    after
      0 -> :ok
    end
  end

  test "the confirmation goes without PDF and an incident is reported", %{order: order} do
    flush_emails()
    assert :ok = perform_job(SendOrderConfirmation, %{order_id: order.id})

    assert_email_sent(fn email ->
      assert email.subject =~ order.number
      assert email.attachments == []
    end)

    assert [incident] = incidents()
    assert incident.kind == :pdf
    assert incident.order_id == order.id
    assert incident.customer_id == order.user_id
    assert incident.description =~ "ohne das PDF"
    assert incident.details =~ "typst"
  end

  test "a failed download reports an incident; again counts up", ctx do
    conn = log_in_user(ctx.conn, ctx.customer)
    path = ~p"/account/orders/#{ctx.order.number}/pdf"

    assert conn |> get(path) |> response(500) =~ "PDF"
    assert conn |> get(path) |> response(500)

    assert [%{kind: :pdf, occurrences: 2, order_id: order_id}] = incidents()
    assert order_id == ctx.order.id
  end
end
