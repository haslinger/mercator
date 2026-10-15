defmodule Mercator.Operations.Setting do
  @moduledoc """
  A setting staff change at runtime (CLAUDE.md: typed runtime config where
  possible, a DB setting only for what is changed at runtime), e.g. the
  active payment provider. A key with a map value; read and written through
  `Mercator.Operations.Settings`. Only administrators change settings.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Operations,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "settings"
    repo Mercator.Repo
  end

  actions do
    defaults [:read]

    create :put do
      description "Sets a value, replacing the old one."
      accept [:key, :value]
      upsert? true
      upsert_identity :unique_key
      upsert_fields [:value, :updated_at]
    end
  end

  policies do
    policy always() do
      authorize_if {ActorHasRole, role: :administrator}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      allow_nil? false
      public? true
      constraints max_length: 100, match: ~r/^[a-z_]+$/
    end

    attribute :value, :map, allow_nil?: false, default: %{}, public?: true
    timestamps()
  end

  identities do
    identity :unique_key, [:key]
  end
end
