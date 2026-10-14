defmodule MercatorWeb.Admin.GtcAdminLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.{Clock, Sales}

  setup %{conn: conn} do
    today = Clock.today()

    current =
      Ash.Seed.seed!(Sales.Gtc, %{
        version: Date.add(today, -30),
        text: %{"de" => "## 1. Geltung\nAlte AGB"}
      })

    conn = log_in_user(conn, user_fixture(roles: [:contentmanager]))
    %{conn: conn, current: current, today: today}
  end

  test "only content managers and administrators", %{current: _current} do
    conn = log_in_user(build_conn(), user_fixture(roles: [:sales]))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/terms")
  end

  test "lists versions; the one in force can only be viewed", %{conn: conn, current: current} do
    {:ok, view, _html} = live(conn, ~p"/admin/terms")

    assert has_element?(view, "#gtc-#{current.id}-status", "in Kraft")
    refute has_element?(view, "#edit-#{current.id}")
    refute has_element?(view, "#delete-#{current.id}")

    view |> element("#view-#{current.id}") |> render_click()
    assert has_element?(view, "#gtc-view h2", "Geltung")
  end

  test "a new version starts from the text in force and applies from its date",
       %{conn: conn, today: today} do
    {:ok, view, _html} = live(conn, ~p"/admin/terms")
    view |> element("#new-gtc") |> render_click()
    assert view |> element("#gtc-form") |> render() =~ "Alte AGB"

    future = Date.add(today, 14)

    view
    |> form("#gtc-form",
      form: %{version: Date.to_iso8601(future), text: %{de: "## 1. Geltung\nNeue AGB"}}
    )
    |> render_submit()

    [upcoming] = Enum.filter(Sales.list_gtcs!(), &(&1.version == future))
    assert has_element?(view, "#gtc-#{upcoming.id}-status", "künftig")
    # the customers still see the version in force
    assert Sales.current_gtc!().text["de"] =~ "Alte AGB"

    view |> element("#edit-#{upcoming.id}") |> render_click()
    view |> form("#gtc-form", form: %{text: %{de: "Neue AGB, korrigiert"}}) |> render_submit()
    assert Ash.get!(Sales.Gtc, upcoming.id).text["de"] == "Neue AGB, korrigiert"

    view |> element("#delete-#{upcoming.id}") |> render_click()
    refute has_element?(view, "#gtc-#{upcoming.id}")
  end

  test "versions cannot be dated in the past", %{conn: conn, today: today} do
    {:ok, view, _html} = live(conn, ~p"/admin/terms")
    view |> element("#new-gtc") |> render_click()

    html =
      view
      |> form("#gtc-form",
        form: %{version: Date.to_iso8601(Date.add(today, -1)), text: %{de: "x"}}
      )
      |> render_submit()

    assert html =~ "heute oder später" or html =~ "today or later"
    assert length(Sales.list_gtcs!()) == 1
  end
end
