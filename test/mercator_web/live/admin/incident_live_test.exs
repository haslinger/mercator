defmodule MercatorWeb.Admin.IncidentLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures
  import Mercator.SalesFixtures

  alias Mercator.Operations.{Incident, Incidents}

  setup %{conn: conn} do
    sales = user_fixture(roles: [:sales])
    %{conn: log_in_user(conn, sales), sales: sales}
  end

  defp report!(attrs) do
    {:ok, incident} =
      Incidents.report(
        Map.merge(%{kind: :pdf, title: "PDF fehlgeschlagen", details: "enoent"}, attrs)
      )

    incident
  end

  test "lists open incidents the user may see, with the sidebar badge", %{conn: conn} do
    customer = user_fixture()
    visible = report!(%{customer_id: customer.id})
    hidden = report!(%{title: "Schrift fehlt"})

    {:ok, view, _html} = live(conn, ~p"/admin/incidents")

    assert has_element?(view, "#incidents-#{visible.id}")
    refute has_element?(view, "#incidents-#{hidden.id}")
    assert has_element?(view, "#open-incidents-badge", "1")
  end

  test "the list and the badge update when an incident is reported", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/incidents")
    refute has_element?(view, "#open-incidents-badge")

    incident = report!(%{customer_id: user_fixture().id})

    assert has_element?(view, "#incidents-#{incident.id}")
    assert has_element?(view, "#open-incidents-badge", "1")
  end

  test "filters by state", %{conn: conn, sales: sales} do
    incident = report!(%{customer_id: user_fixture().id})
    {:ok, _resolved} = Incidents.resolve(incident, "Erledigt.", sales)

    {:ok, view, _html} = live(conn, ~p"/admin/incidents")
    refute has_element?(view, "#incidents-#{incident.id}")

    view |> form("#incident-filters", %{state: "resolved"}) |> render_change()
    assert_patch(view, ~p"/admin/incidents?state=resolved")
    assert has_element?(view, "#incidents-#{incident.id}")
  end

  test "records an incident from an order (#107)", %{conn: conn, sales: sales} do
    gtc_fixture()
    customer = customer_fixture()
    [variant] = Ash.load!(product_fixture(), :variants).variants
    order = order_fixture(customer, variant)

    {:ok, view, _html} = live(conn, ~p"/admin/orders/#{order.number}")
    view |> element("#report-incident") |> render_click()
    {path, _flash} = assert_redirect(view)

    {:ok, view, _html} = live(conn, path)
    assert has_element?(view, "#incident-links", order.number)

    view
    |> form("#incident-form",
      incident: %{title: "Ware beschädigt", description: "Kunde hat angerufen."}
    )
    |> render_submit()

    [incident] = Ash.read!(Incident, actor: sales)
    assert incident.order_id == order.id
    assert incident.customer_id == customer.id
    assert incident.reported_by_id == sales.id
    assert_redirect(view, ~p"/admin/incidents/#{incident.id}")
  end

  test "a title is required", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/incidents/new")

    view |> form("#incident-form", incident: %{title: ""}) |> render_submit()

    assert has_element?(view, "#new-incident-modal")
    assert Ash.read!(Incident, authorize?: false) == []
  end

  test "resolves with a resolution and opens again", %{conn: conn, sales: sales} do
    incident = report!(%{customer_id: user_fixture().id})
    {:ok, view, _html} = live(conn, ~p"/admin/incidents/#{incident.id}")

    assert has_element?(view, "#incident-details", "enoent")
    assert has_element?(view, "#incident-customer")

    # not without a resolution
    view |> element("#incident-form") |> render_submit(%{action: "resolve"})
    assert has_element?(view, "#incident-state", "Offen")

    view
    |> form("#incident-form", incident: %{resolution: "PDF von Hand geschickt."})
    |> render_submit(%{action: "resolve"})

    assert has_element?(view, "#incident-state", "Erledigt")
    assert has_element?(view, "#incident-resolved")
    assert Ash.get!(Incident, incident.id, actor: sales).resolved_by_id == sales.id

    view |> element("#reopen-incident") |> render_click()
    assert has_element?(view, "#incident-state", "Offen")
  end

  test "users without a sales role see nothing", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(roles: [:contentmanager]))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/incidents")
  end
end
