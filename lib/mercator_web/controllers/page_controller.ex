defmodule MercatorWeb.PageController do
  use MercatorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
