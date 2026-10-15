defmodule MercatorWeb.MakingOfLiveTest do
  # not async: switches the making-of on and off (application config)
  use MercatorWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defp making_of(enabled?), do: put_env(:making_of, enabled?)

  # sets an application setting for one test; afterwards it is exactly as
  # before (removed if it was not set: nil would be a setting of its own)
  defp put_env(key, value) do
    previous = Application.fetch_env(:mercator, key)
    Application.put_env(:mercator, key, value)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:mercator, key, value)
        :error -> Application.delete_env(:mercator, key)
      end
    end)
  end

  describe "switched off (a customer shop)" do
    setup do: making_of(false)

    test "the pages do not exist and nothing links to them", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/making-of") end
      assert_error_sent 404, fn -> get(conn, ~p"/making-of/metrics") end

      {:ok, view, _html} = live(conn, ~p"/basket")
      refute has_element?(view, "#making-of-link")
    end
  end

  describe "switched on (the demo)" do
    setup do: making_of(true)

    test "introduction, metrics and the sessions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/making-of")

      assert has_element?(view, "#making-of-intro", "Claude Code")
      assert has_element?(view, ~s(#making-of-metrics[href="/making-of/metrics"]))
      assert has_element?(view, "#session-2026-10-13-2a53ba5b", "Session 2026-10-13")
      assert has_element?(view, "#session-2026-10-13-2a53ba5b", "messages")
    end

    test "a session shows the conversation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/making-of/2026-10-13-2a53ba5b")

      assert has_element?(view, "#making-of-chapter h1", "Session 2026-10-13 (2a53ba5b)")
      assert has_element?(view, ~s(#making-of-chapter .session h3[id^="user"]))
      assert has_element?(view, ~s(#making-of-chapter .session h3[id^="claude"]))
      refute has_element?(view, "#making-of-toc")
    end

    test "the metrics with their table of contents", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/making-of/metrics")

      assert has_element?(view, "#making-of-chapter h1", "Project metrics")
      assert has_element?(view, "#making-of-toc")
    end

    test "unknown pages lead back to the overview", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/making-of"}}} = live(conn, ~p"/making-of/nope")
    end

    test "the footer links to it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/basket")
      assert has_element?(view, ~s(#making-of-link[href="/making-of"]))
    end
  end

  test "without the setting it follows demo mode" do
    making_of(nil)

    put_env(:demo_mode, false)
    refute Mercator.Docs.making_of?()
    put_env(:demo_mode, true)
    assert Mercator.Docs.making_of?()
  end
end
