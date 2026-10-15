defmodule MercatorWeb.Plugs.ContentSecurityPolicyTest do
  use MercatorWeb.ConnCase, async: true

  test "shop pages send the policy; the theme script carries its nonce", %{conn: conn} do
    conn = get(conn, ~p"/")
    [policy] = get_resp_header(conn, "content-security-policy")

    assert policy =~ "default-src 'self'"
    assert policy =~ "object-src 'none'"
    assert [_all, nonce] = Regex.run(~r/script-src 'self' 'nonce-([^']+)'/, policy)

    document = conn |> html_response(200) |> LazyHTML.from_document()
    assert document |> LazyHTML.query(~s(script[nonce="#{nonce}"])) |> Enum.count() == 1
    # every inline script has the nonce
    assert document |> LazyHTML.query("script:not([src]):not([nonce])") |> Enum.empty?()
  end

  test "a new nonce for every request", %{conn: conn} do
    first = conn |> get(~p"/") |> get_resp_header("content-security-policy")
    second = build_conn() |> get(~p"/") |> get_resp_header("content-security-policy")
    refute first == second
  end
end
