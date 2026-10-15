defmodule MercatorWeb.Admin.PaymentProviderLiveTest do
  # not async: the active provider is one setting row shared by all tests
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Payments

  test "administrators switch the provider and online payment off", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(roles: [:administrator]))
    {:ok, view, _html} = live(conn, ~p"/admin/payment-providers")

    # off at first
    assert has_element?(view, "#provider-none .badge", "Aktiv")
    assert has_element?(view, "#provider-simulator")

    view |> element("#activate-simulator") |> render_click()
    assert has_element?(view, "#provider-simulator .badge", "Aktiv")
    assert Payments.online?()

    view |> element("#activate-none") |> render_click()
    assert has_element?(view, "#provider-none .badge", "Aktiv")
    refute Payments.online?()
  end

  test "only administrators", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(roles: [:sales]))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/payment-providers")
  end
end
