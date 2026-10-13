defmodule MercatorWeb.PwaTest do
  use MercatorWeb.ConnCase, async: true

  test "the manifest describes the brand as an installable app", %{conn: conn} do
    conn = get(conn, ~p"/manifest.webmanifest")

    assert response_content_type(conn, :json) =~ "application/manifest+json"
    manifest = conn |> response(200) |> Jason.decode!()

    assert manifest["name"] == "Mercator"
    assert manifest["display"] == "standalone"
    assert manifest["start_url"] == "/"
    assert Enum.map(manifest["icons"], & &1["sizes"]) == ["192x192", "512x512", "512x512"]
    assert Enum.any?(manifest["icons"], &(&1["purpose"] == "maskable"))

    for icon <- manifest["icons"] do
      assert conn |> recycle() |> get(icon["src"]) |> response(200)
    end
  end

  test "the service worker and the offline page are served", %{conn: conn} do
    assert conn |> get("/sw.js") |> response(200) =~ "offline.html"
    assert conn |> recycle() |> get("/offline.html") |> response(200) =~ "Offline"
  end

  test "pages link the manifest and set a theme colour", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(rel="manifest" href="/manifest.webmanifest")
    assert html =~ ~s(name="theme-color")
  end
end
