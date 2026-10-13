defmodule Mercator.Catalog.OptionChoice do
  @moduledoc """
  A choice of a configurator option, e.g. "Eiche" for the wood species. Choices
  of the `:base_price` option carry the net base price per pricing unit
  (e.g. per m³); choices of `:surcharge` options add an absolute amount per
  piece and/or a percentage.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  @editable [:name, :base_price, :surcharge_amount, :surcharge_percent, :position, :default]

  postgres do
    table "option_choices"
    repo Mercator.Repo

    references do
      reference :option, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:option_id, :key | @editable]
    end

    update :update do
      primary? true
      accept @editable
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    bypass {ActorHasRole, role: :productmanager} do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(option.product.state == :active)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :key, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_]+$/, max_length: 50
    end

    attribute :name, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 100
    end

    attribute :base_price, :decimal do
      description "Net price per pricing unit (m³, m², lfm or piece) for :base_price options."
      public? true
      constraints min: 0
    end

    attribute :surcharge_amount, :decimal do
      description "Net amount added per piece."
      public? true
    end

    attribute :surcharge_percent, :decimal do
      description "Percentage added to the base amount, e.g. 12 for +12 %."
      public? true
    end

    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    attribute :default, :boolean, allow_nil?: false, default: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :option, Mercator.Catalog.ProductOption, allow_nil?: false, public?: true
  end

  identities do
    identity :unique_option_key, [:option_id, :key]
  end
end
