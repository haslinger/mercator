defmodule MercatorWeb.Admin.PageAdminLiveTest do
  use MercatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Content

  setup %{conn: conn} do
    editor = user_fixture(roles: [:contentmanager])
    %{conn: log_in_user(conn, editor), editor: editor}
  end

  defp page!(editor, attrs \\ %{}) do
    attrs
    |> Map.new()
    |> Map.put_new(:title, %{"de" => "Sägewerk"})
    |> Content.create_page!(actor: editor)
  end

  describe "access" do
    test "only content managers and administrators" do
      for roles <- [[], [:sales], [:productmanager]] do
        conn = log_in_user(build_conn(), user_fixture(roles: roles))
        assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/pages")
      end

      conn = log_in_user(build_conn(), user_fixture(roles: [:administrator]))
      assert {:ok, _view, _html} = live(conn, ~p"/admin/pages")
    end

    test "the sidebar links to the pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin")
      assert has_element?(view, ~s(#admin-nav a[href="/admin/pages"]))
    end
  end

  describe "page tree" do
    test "creates a page and opens its editor", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/pages")
      assert has_element?(view, "#no-pages")

      view |> element("#new-page") |> render_click()

      {:ok, _editor, html} =
        view
        |> form("#page-form", form: %{title: %{de: "Über uns", en: "About us"}})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Über uns"

      assert {:ok, %{path: "ueber-uns", state: :draft}} =
               Content.get_page_by_path("ueber-uns", authorize?: false)
    end

    test "shows the tree, moves and deletes drafts", %{conn: conn, editor: editor} do
      about = page!(editor, title: %{"de" => "Über uns"})
      team = page!(editor, title: %{"de" => "Team"})

      {:ok, view, _html} = live(conn, ~p"/admin/pages")
      assert has_element?(view, "#page-#{about.id}", "/pages/ueber-uns")

      render_hook(view, "move", %{"id" => team.id, "parent_id" => about.id, "index" => 0})
      assert has_element?(view, "#page-#{team.id}", "/pages/ueber-uns/team")

      render_hook(view, "move", %{"id" => team.id, "parent_id" => nil, "index" => 0})
      view |> element("#delete-#{team.id}") |> render_click()
      refute has_element?(view, "#page-#{team.id}")
    end
  end

  describe "page editor" do
    test "adds, edits, reorders and deletes blocks", %{conn: conn, editor: editor} do
      page = page!(editor)
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")
      assert has_element?(view, "#no-blocks")

      view |> element("#add-block-text") |> render_click()
      assert has_element?(view, "#block-modal [phx-hook=MarkdownEditor]")

      view
      |> form("#block-form", block: %{text: %{de: "## Seit 1928\nim Waldviertel"}})
      |> render_submit()

      refute has_element?(view, "#block-modal")
      assert has_element?(view, "#blocks h2", "Seit 1928")
      assert has_element?(view, "#changes-pending")

      view |> element("#add-block-text") |> render_click()
      view |> form("#block-form", block: %{text: %{de: "Zweiter Block"}}) |> render_submit()

      [first, second] = Content.get_page!(page.id, actor: editor).blocks
      render_hook(view, "reorder_blocks", %{"id" => second.value.id, "index" => 0})

      assert [%{value: %{text: %{"de" => "Zweiter Block"}}}, _] =
               Content.get_page!(page.id, actor: editor).blocks

      view |> element("#edit-#{first.value.id}") |> render_click()
      view |> form("#block-form", block: %{text: %{de: "Geändert"}}) |> render_submit()
      assert has_element?(view, "#edit-block-#{first.value.id}", "Geändert")

      view |> element("#delete-#{second.value.id}") |> render_click()
      refute has_element?(view, "#edit-block-#{second.value.id}")
    end

    test "image blocks choose files from the media library", %{conn: conn, editor: editor} do
      upload = fn tags, source, name ->
        Content.upload_asset!(
          %{source_path: source, original_filename: name, tags: tags, title: %{"de" => name}},
          actor: editor
        )
      end

      forest = upload.(["wald"], "test/fixtures/wood.jpg", "wald.jpg")
      logs = upload.(["stamm"], "test/fixtures/wood.jpg", "staemme.jpg")
      pdf = upload.(["preise"], "test/fixtures/sample.pdf", "preise.pdf")

      page = page!(editor)
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")

      # hero with an image, found by searching the media library
      view |> element("#add-block-hero") |> render_click()
      view |> form("#block-form", %{"picker_q" => "wald"}) |> render_change()
      assert has_element?(view, "#pick-#{forest.id}")
      refute has_element?(view, "#pick-#{logs.id}")
      refute has_element?(view, "#pick-#{pdf.id}")

      view
      |> form("#block-form", %{
        "block" => %{
          "image_id" => forest.id,
          "headline" => %{"de" => "Holz aus dem Waldviertel"},
          "button_label" => %{"de" => "Zum Sortiment"},
          "button_link" => "/categories/bauholz"
        }
      })
      |> render_submit()

      assert has_element?(view, "#blocks .hero h2", "Holz aus dem Waldviertel")
      assert has_element?(view, ~s(#blocks .hero a[href="/categories/bauholz"]))

      # gallery with two images
      view |> element("#add-block-gallery") |> render_click()

      view
      |> form("#block-form", %{"block" => %{"image_ids" => [forest.id, logs.id]}})
      |> render_submit()

      assert has_element?(view, ~s(#blocks img[src="/uploads/assets/#{logs.id}/thumb.webp"]))

      # download: only documents to choose from
      view |> element("#add-block-download") |> render_click()
      assert has_element?(view, "#pick-#{pdf.id}")
      refute has_element?(view, "#pick-#{forest.id}")
      view |> form("#block-form", %{"block" => %{"document_id" => pdf.id}}) |> render_submit()
      assert has_element?(view, ~s(#blocks a[href="/uploads/assets/#{pdf.id}/preise.pdf"]))

      # visitors see the blocks after publishing
      view |> element("#publish") |> render_click()
      {:ok, public, _html} = live(build_conn(), ~p"/pages/saegewerk")
      assert has_element?(public, "#page .hero h2", "Holz aus dem Waldviertel")
      assert has_element?(public, ~s(#page a[href="/uploads/assets/#{pdf.id}/preise.pdf"]), "PDF")

      # files in use cannot be deleted
      assert {:error, _} = Content.destroy_asset(forest, actor: editor)
    end

    test "shop blocks show products and categories", %{conn: conn, editor: editor} do
      wood = category_fixture(name: %{"de" => "Bauholz"}, slug: "bauholz", state: :active)
      _beam = product_fixture(title: %{"de" => "Balken"}, number: "BALKEN", bestseller: true)
      lath = product_fixture(title: %{"de" => "Latte"}, number: "LATTE")
      Mercator.Catalog.categorize!(wood.id, lath.id, authorize?: false)

      page = page!(editor)
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")

      view |> element("#add-block-products") |> render_click()
      refute has_element?(view, "#block-form select[name='block[category_id]']")

      view |> form("#block-form", %{"block" => %{"source" => "category"}}) |> render_change()
      assert has_element?(view, "#block-form select[name='block[category_id]']")

      view
      |> form("#block-form", %{
        "block" => %{
          "heading" => %{"de" => "Aus dem Bauholz"},
          "source" => "category",
          "category_id" => wood.id
        }
      })
      |> render_submit()

      assert has_element?(view, "#blocks h2", "Aus dem Bauholz")
      assert has_element?(view, "#blocks", "Latte")
      refute has_element?(view, "#blocks", "Balken")

      view |> element("#add-block-products") |> render_click()
      view |> form("#block-form", %{"block" => %{"source" => "bestsellers"}}) |> render_submit()
      assert has_element?(view, "#blocks", "Balken")

      view |> element("#add-block-categories") |> render_click()
      view |> form("#block-form", %{"block" => %{"category_ids" => [wood.id]}}) |> render_submit()
      assert has_element?(view, "#blocks #category-tile-bauholz")

      view |> element("#add-block-call_to_action") |> render_click()

      view
      |> form("#block-form", %{
        "block" => %{
          "headline" => %{"de" => "Beratung gewünscht?"},
          "button_label" => %{"de" => "Kontakt"},
          "button_link" => "/pages/kontakt"
        }
      })
      |> render_submit()

      assert has_element?(view, ~s(#blocks a[href="/pages/kontakt"]), "Kontakt")

      # #154: the ways to get advice; the phone number is on by default
      view |> element("#add-block-contact_options") |> render_click()

      assert has_element?(
               view,
               ~s(#block-form input[type=checkbox][name="block[show_phone]"][checked])
             )

      view
      |> form("#block-form", %{
        "block" => %{
          "headline" => %{"de" => "So beraten wir Sie"},
          "message_link" => "/pages/schreiben",
          "show_phone" => "false"
        }
      })
      |> render_submit()

      assert has_element?(view, "#blocks h2", "So beraten wir Sie")
      assert has_element?(view, ~s(#blocks [id$=-message] a[href="/pages/schreiben"]))
      refute has_element?(view, "#blocks [id$=-phone]")
    end

    test "columns and FAQ have a list of entries", %{conn: conn, editor: editor} do
      page = page!(editor)
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")

      view |> element("#add-block-faq") |> render_click()
      view |> element("#add-item") |> render_click()

      assert view
             |> element("#block-form")
             |> render()
             |> String.contains?("block[items][3][question][de]")

      view
      |> form("#block-form", %{
        "block" => %{
          "heading" => %{"de" => "Häufige Fragen"},
          "items" => %{
            "0" => %{
              "question" => %{"de" => "Liefern Sie auch?"},
              "answer" => %{"de" => "Ja, **österreichweit**."}
            },
            "1" => %{"question" => %{"de" => ""}, "answer" => %{"de" => ""}},
            "2" => %{
              "question" => %{"de" => "Kann ich abholen?"},
              "answer" => %{"de" => "Im Sägewerk."}
            }
          }
        }
      })
      |> render_submit()

      assert has_element?(view, "#blocks details summary", "Liefern Sie auch?")
      assert has_element?(view, "#blocks details strong", "österreichweit")
      [%{value: faq}] = Content.get_page!(page.id, actor: editor).blocks
      assert length(faq.items) == 2

      # editing keeps the entries
      view |> element("#edit-#{faq.id}") |> render_click()
      assert view |> element("#block-form") |> render() |> String.contains?("Kann ich abholen?")
      view |> element("#block-modal button[phx-click=cancel_block]") |> render_click()

      view |> element("#add-block-columns") |> render_click()

      view
      |> form("#block-form", %{
        "block" => %{
          "items" => %{
            "0" => %{"title" => %{"de" => "Regional"}, "text" => %{"de" => "Aus dem Waldviertel"}},
            "1" => %{"title" => %{"de" => "Nachhaltig"}, "text" => %{"de" => "PEFC-zertifiziert"}}
          }
        }
      })
      |> render_submit()

      assert has_element?(view, "#blocks .md\\:grid-cols-2 h3", "Nachhaltig")
    end

    test "shared blocks are maintained once and shown on other pages", %{
      conn: conn,
      editor: editor
    } do
      text = fn markdown -> [%{type: "text", text: %{"de" => markdown}}] end

      # created from the page list as a shared block
      {:ok, view, _html} = live(conn, ~p"/admin/pages/new?kind=shared")

      {:ok, _editor, _html} =
        view
        |> form("#page-form", form: %{title: %{de: "Öffnungszeiten"}})
        |> render_submit()
        |> follow_redirect(conn)

      {:ok, hours} = Content.get_page_by_path("oeffnungszeiten", actor: editor)
      assert hours.kind == :shared

      hours =
        hours
        |> Content.update_page!(%{blocks: text.("Mo–Fr 7–17 Uhr")}, actor: editor)
        |> Content.publish_page!(actor: editor)

      # never shown at its own URL
      assert {:error, _} = Content.get_published_page("oeffnungszeiten")

      {:ok, list, _html} = live(conn, ~p"/admin/pages")
      assert has_element?(list, "#shared-pages #page-#{hours.id}")

      page = page!(editor)
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")
      view |> element("#add-block-shared") |> render_click()
      view |> form("#block-form", %{"block" => %{"page_id" => hours.id}}) |> render_submit()
      assert has_element?(view, "#blocks", "Mo–Fr 7–17 Uhr")

      view |> element("#publish") |> render_click()
      {:ok, public, _html} = live(build_conn(), ~p"/pages/saegewerk")
      assert has_element?(public, "#page", "Mo–Fr 7–17 Uhr")

      # a change of the shared block shows everywhere once it is published
      hours
      |> Content.update_page!(%{blocks: text.("Mo–Sa 7–12 Uhr")}, actor: editor)
      |> Content.publish_page!(actor: editor)

      {:ok, public, _html} = live(build_conn(), ~p"/pages/saegewerk")
      assert has_element?(public, "#page", "Mo–Sa 7–12 Uhr")

      # no shared blocks inside shared blocks
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{hours.id}")
      refute has_element?(view, "#add-block-shared")
      refute has_element?(view, "#settings-form select[name='form[menu]']")
    end

    test "saves settings, publishes, archives; history and restore", %{conn: conn, editor: editor} do
      page = page!(editor, blocks: [%{type: "text", text: %{"de" => "Erste Fassung"}}])
      {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}")

      view
      |> form("#settings-form", form: %{slug: "saegewerk", menu: "main", icon: "hero-truck"})
      |> render_submit()

      assert %{menu: :main, icon: "hero-truck"} = Content.get_page!(page.id, actor: editor)
      assert has_element?(view, "#icon-hero-truck.btn-primary")

      view |> form("#settings-form", %{"icon_q" => "envelope"}) |> render_change()
      assert has_element?(view, "#icon-hero-envelope")
      assert has_element?(view, "#icon-hero-truck")
      refute has_element?(view, "#icon-hero-home")

      view |> element("#publish") |> render_click()
      assert has_element?(view, "#page-state", "Veröffentlicht")
      refute has_element?(view, "#publish")
      assert has_element?(view, "#history li", "1")

      view |> element("#add-block-text") |> render_click()
      view |> form("#block-form", block: %{text: %{de: "Zweite Fassung"}}) |> render_submit()
      assert has_element?(view, "#discard")

      [version] =
        Content.get_page!(page.id, actor: editor)
        |> Ash.load!(:paper_trail_versions, actor: editor)
        |> Map.fetch!(:paper_trail_versions)

      view |> element("#restore-#{version.id}") |> render_click()
      assert Content.get_page!(page.id, actor: editor).blocks |> length() == 1

      view |> element("#hide") |> render_click()
      assert has_element?(view, "#page-state", "Ausgeblendet")

      view |> element("#archive") |> render_click()
      assert has_element?(view, "#page-state", "Archiviert")
      assert {:error, _} = Content.get_published_page("saegewerk")
    end
  end
end
