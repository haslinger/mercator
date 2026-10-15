defmodule MercatorWeb.NotFoundError do
  @moduledoc """
  Raised for pages that do not exist in this deployment, e.g. the making-of
  when it is switched off: Phoenix answers with the 404 error page.
  """
  defexception message: "not found", plug_status: 404
end
