defmodule MercatorWeb.Admin.HelpLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Docs

  defp sign_in(conn, roles), do: log_in_user(conn, user_fixture(roles: roles))

  test "only staff may read the admin help", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(sign_in(conn, []), ~p"/admin/help")
    assert {:ok, _view, _html} = live(sign_in(conn, [:productmanager]), ~p"/admin/help")
  end

  test "the sidebar links to the help", %{conn: conn} do
    {:ok, view, _html} = live(sign_in(conn, [:sales]), ~p"/admin")
    assert has_element?(view, ~s(#admin-nav a[href="/admin/help"]))
  end

  describe "table of contents" do
    test "sales staff see the manual, not operating or developers", %{conn: conn} do
      {:ok, view, _html} = live(sign_in(conn, [:sales]), ~p"/admin/help")

      assert has_element?(view, "#help-part-manual")
      assert has_element?(view, "#chapter-manual-index", "Überblick")
      refute has_element?(view, "#help-part-operating")
      refute has_element?(view, "#help-part-developers")
    end

    test "administrators see all three parts", %{conn: conn} do
      {:ok, view, _html} = live(sign_in(conn, [:administrator]), ~p"/admin/help")

      for part <- ~w(manual operating developers),
          do: assert(has_element?(view, "#help-part-#{part}"))

      assert has_element?(view, "#chapter-developers-payment-design")
    end
  end

  describe "a chapter" do
    test "with its text and table of contents", %{conn: conn} do
      {:ok, view, _html} =
        live(sign_in(conn, [:administrator]), ~p"/admin/help/developers/payment-design")

      assert has_element?(view, "#help-chapter h1", "Online payment")
      assert has_element?(view, ~s(#help-toc a[href="#1-goals"]))
      # English only (#133), the German user is told
      assert has_element?(view, "#help-locale")
      assert has_element?(view, "#help-breadcrumbs", "Entwicklung")
    end

    test "in the user's language", %{conn: conn} do
      {:ok, view, _html} = live(sign_in(conn, [:sales]), ~p"/admin/help/manual/index")

      assert has_element?(view, "#help-chapter h1", "Überblick")
      refute has_element?(view, "#help-locale")
    end

    test "hidden or unknown chapters lead back to the contents", %{conn: conn} do
      conn = sign_in(conn, [:sales])

      for path <- [
            ~p"/admin/help/developers/payment-design",
            ~p"/admin/help/manual/nope",
            ~p"/admin/help/making-of/index"
          ] do
        assert {:error, {:live_redirect, %{to: "/admin/help"}}} = live(conn, path)
      end
    end
  end

  test "search", %{conn: conn} do
    {:ok, view, _html} = live(sign_in(conn, [:administrator]), ~p"/admin/help")

    view |> element("#help-search") |> render_change(%{"q" => "Mollie"})
    assert_patch(view, ~p"/admin/help?q=Mollie")
    assert has_element?(view, "#result-developers-payment-design")
    refute has_element?(view, "#help-parts")

    view |> element("#help-search") |> render_change(%{"q" => "xyzzy-nothing"})
    assert has_element?(view, "#help-results", "xyzzy-nothing")

    view |> element("#help-search") |> render_change(%{"q" => ""})
    assert_patch(view, ~p"/admin/help")
    assert has_element?(view, "#help-parts")
  end

  describe "the \"?\" of admin pages" do
    test "opens the chapter that names the page", %{conn: conn} do
      {:ok, view, _html} = live(sign_in(conn, [:sales]), ~p"/admin")
      assert has_element?(view, ~s(#page-help[href="/admin/help/manual/index"]))
    end

    test "every admin area has its chapter", %{conn: conn} do
      {:ok, view, _html} = live(sign_in(conn, [:administrator]), ~p"/admin/tax-classes")
      assert has_element?(view, ~s(#page-help[href="/admin/help/manual/tax-classes"]))
    end

    test "is missing where no chapter names the page", %{conn: conn} do
      {:ok, view, _html} = live(sign_in(conn, [:administrator]), ~p"/admin/help")
      refute has_element?(view, "#page-help")
    end

    test "every admin page has a chapter for its \"?\"" do
      named = MapSet.new(Docs.pages())

      missing =
        for %{path: "/admin" <> _ = path, plug: plug} <- Phoenix.Router.routes(MercatorWeb.Router),
            plug == Phoenix.LiveView.Plug,
            not String.starts_with?(path, "/admin/help"),
            # the LiveDashboard has its own layout, without a "?"
            not String.starts_with?(path, "/admin/system"),
            page = MercatorWeb.HelpLink.page(path),
            page not in named,
            do: page

      assert missing == [], "admin pages without a help chapter: #{inspect(missing)}"
    end

    test "every page a chapter names is an admin route" do
      routes =
        for %{path: path} <- Phoenix.Router.routes(MercatorWeb.Router),
            into: MapSet.new(),
            do: MercatorWeb.HelpLink.page(path)

      for page <- Docs.pages(),
          do: assert(page in routes, "#{page} (named in a chapter's front matter) is no route")
    end
  end
end
