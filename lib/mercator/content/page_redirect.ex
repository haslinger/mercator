defmodule Mercator.Content.PageRedirect do
  @moduledoc """
  A former path of a page (changed slug or moved in the tree), so old links
  keep working: `/pages/<old_path>` redirects permanently to the page's
  current URL (`MercatorWeb.Plugs.PageRedirect`). Written by
  `Mercator.Content.Changes.SetPagePath`; pointing at the page, not at a
  path, so several moves never form a chain.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Content,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "page_redirects"
    repo Mercator.Repo

    references do
      reference :page, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    read :by_old_path do
      argument :old_path, :string, allow_nil?: false
      get? true
      filter expr(old_path == ^arg(:old_path))
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :old_path, :string, allow_nil?: false, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :page, Mercator.Content.Page, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_old_path, [:old_path]
  end
end
