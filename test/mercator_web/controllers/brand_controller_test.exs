defmodule MercatorWeb.BrandControllerTest do
  use MercatorWeb.ConnCase, async: true

  test "redirects to the configured brand's images", %{conn: conn} do
    assert redirected_to(get(conn, ~p"/brand/logo")) =~ "/images/brands/mercator/logo"
    assert redirected_to(get(conn, ~p"/brand/favicon")) =~ "/images/brands/mercator/favicon"

    assert redirected_to(get(conn, ~p"/brand/apple-touch-icon")) =~
             "/images/brands/mercator/apple-touch-icon"
  end

  test "the pin falls back to the logo when the brand has none", %{conn: conn} do
    assert redirected_to(get(conn, ~p"/brand/pin")) =~ "/images/brands/mercator/logo"
  end

  test "unknown images are not found", %{conn: conn} do
    assert conn |> get(~p"/brand/secret") |> response(404)
  end

  test "pages link the brand favicon and show the brand name", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(href="/brand/favicon")
    assert html =~ ~s(data-light-theme="light")
    assert html =~ "Mercator"
  end
end
