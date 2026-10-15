defmodule MercatorWeb.Plugs.AuthContextTest do
  use MercatorWeb.ConnCase, async: true

  alias MercatorWeb.Plugs.AuthContext

  test "puts the client IP into the Ash context (#126)" do
    conn = %{build_conn() | remote_ip: {198, 51, 100, 7}} |> AuthContext.call([])

    assert Ash.PlugHelpers.get_context(conn).client_ip == "198.51.100.7"
  end

  test "keeps an existing context" do
    conn =
      build_conn()
      |> Ash.PlugHelpers.set_context(%{other: 1})
      |> AuthContext.call([])

    assert %{other: 1, client_ip: "127.0.0.1"} = Ash.PlugHelpers.get_context(conn)
  end
end
