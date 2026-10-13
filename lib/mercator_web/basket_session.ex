defmodule MercatorWeb.BasketSession do
  @moduledoc """
  Connects the web layer with baskets (#8):

    * as a plug, gives every browser session a random basket token
      (LiveViews cannot write the session themselves) and assigns
      `@basket_count` for controller pages
    * as an `on_mount` hook, assigns `@basket_owner` and `@basket_count`
      in LiveViews (after the current user is known)
  """
  @behaviour Plug

  import Plug.Conn

  alias Mercator.Sales.Baskets

  @key "basket_token"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn =
      case get_session(conn, @key) do
        nil ->
          put_session(
            conn,
            @key,
            :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
          )

        _token ->
          conn
      end

    assign(
      conn,
      :basket_count,
      Baskets.count(owner(conn.assigns[:current_user], get_session(conn, @key)))
    )
  end

  def on_mount(:default, _params, session, socket) do
    owner = owner(socket.assigns[:current_user], session[@key])

    {:cont,
     socket
     |> Phoenix.Component.assign(:basket_owner, owner)
     |> Phoenix.Component.assign(:basket_count, Baskets.count(owner))}
  end

  @doc "The basket owner for a user (if signed in) or the session's token."
  def owner(%{id: _} = user, _token), do: {:user, user}
  def owner(_user, token), do: {:session, token}

  @doc "The session key of the basket token."
  def key, do: @key
end
