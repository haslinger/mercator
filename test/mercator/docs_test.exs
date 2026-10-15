defmodule Mercator.DocsTest do
  # runs against the real documentation compiled into the app
  use ExUnit.Case, async: true

  alias Mercator.Docs

  @admin %{roles: [:administrator]}
  @sales %{roles: [:sales]}
  @products %{roles: [:productmanager]}
  @customer %{roles: []}

  defp slugs(part, locale, actor), do: Enum.map(Docs.chapters(part, locale, actor), & &1.slug)

  describe "who sees what (#124, #125)" do
    test "the manual is for staff" do
      assert "index" in slugs(:manual, "de", @sales)
      assert "index" in slugs(:manual, "de", @products)
      assert slugs(:manual, "de", @customer) == []
      assert slugs(:manual, "de", nil) == []
    end

    test "operating and developer chapters only for administrators" do
      for part <- [:operating, :developers] do
        assert slugs(part, "de", @admin) != []
        assert slugs(part, "de", @sales) == []
        assert slugs(part, "de", nil) == []
      end
    end

    test "shop help and making-of for everybody" do
      assert "index" in slugs(:help, "de", nil)
      assert "index" in slugs(:making_of, "en", nil)
    end

    test "manual chapters follow their roles" do
      chapter = %Mercator.Docs.Chapter{
        part: :manual,
        slug: "x",
        locale: "de",
        title: "X",
        html: "",
        roles: [:contentmanager]
      }

      assert Docs.visible?(chapter, %{roles: [:contentmanager]})
      assert Docs.visible?(chapter, @admin)
      refute Docs.visible?(chapter, @sales)
      refute Docs.visible?(chapter, @customer)
    end
  end

  describe "languages (#123, #133)" do
    test "a chapter in the user's language" do
      {:ok, de} = Docs.chapter(:manual, "index", "de", @sales)
      {:ok, en} = Docs.chapter(:manual, "index", "en", @sales)

      assert de.locale == "de" and de.title == "Überblick"
      assert en.locale == "en" and en.title == "Overview"
    end

    test "English-only chapters are shown to German users too" do
      {:ok, chapter} = Docs.chapter(:developers, "payment-design", "de", @admin)
      assert chapter.locale == "en"
      assert {:ok, %{locale: "en"}} = Docs.chapter(:making_of, "metrics", "de", nil)
    end
  end

  describe "sources" do
    test "the developer part has the design documents in order" do
      slugs = slugs(:developers, "en", @admin)

      assert hd(slugs) == "index"

      assert Enum.find_index(slugs, &(&1 == "catalog-design")) <
               Enum.find_index(slugs, &(&1 == "payment-design"))
    end

    test "the making-of has the introduction, the metrics and the sessions" do
      [intro, metrics | sessions] = Docs.chapters(:making_of, "en", nil)

      assert intro.slug == "index"
      assert metrics.slug == "metrics"
      assert [first | _] = sessions
      assert first.title =~ ~r/^Session 2026-10-13 \(\w{8}\)$/
      assert first.toc == []
    end

    test "unknown chapters and hidden ones are errors" do
      assert Docs.chapter(:manual, "nope", "de", @admin) == :error
      assert Docs.chapter(:developers, "payment-design", "de", @sales) == :error
    end
  end

  test "the \"?\" of an admin page finds its chapter" do
    assert %{part: :manual, slug: "index"} = Docs.for_page("admin", "de", @sales)
    assert Docs.for_page("admin", "de", nil) == nil
    assert Docs.for_page("admin/nothing-here", "de", @admin) == nil
  end

  describe "search" do
    test "finds chapters with a snippet, title matches first" do
      [{first, _snippet} | _] = results = Docs.search("payment", "en", @admin)

      assert first.title =~ ~r/payment/i
      assert Enum.all?(results, fn {_chapter, snippet} -> is_binary(snippet) end)
    end

    test "only in what the actor may see" do
      assert Docs.search("Mollie", "de", @admin) != []

      assert Docs.search("Mollie", "de", @sales)
             |> Enum.all?(fn {chapter, _} -> chapter.part not in [:developers, :operating] end)
    end

    test "an empty query finds nothing" do
      assert Docs.search("  ", "de", @admin) == []
      assert Docs.search(nil, "de", @admin) == []
    end
  end
end
