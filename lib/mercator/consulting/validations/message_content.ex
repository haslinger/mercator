defmodule Mercator.Consulting.Validations.MessageContent do
  @moduledoc """
  A message has a text or an attachment, and a link is a shop path or an
  http(s) URL (no `javascript:` or other schemes).
  """
  use Ash.Resource.Validation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def validate(changeset, _opts, _context) do
    get = &Ash.Changeset.get_attribute(changeset, &1)
    link = get.(:link_url)

    cond do
      Enum.all?([:body, :product_id, :asset_id, :link_url, :offer_id], &(get.(&1) in [nil, ""])) ->
        {:error, field: :body, message: dgettext_noop("errors", "is required")}

      link && not valid_link?(link) ->
        {:error,
         field: :link_url,
         message: dgettext_noop("errors", "must be a shop page or an http(s) address")}

      true ->
        :ok
    end
  end

  defp valid_link?("/" <> rest), do: not String.starts_with?(rest, "/")

  defp valid_link?(url),
    do:
      match?(
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host),
        URI.parse(url)
      )
end
