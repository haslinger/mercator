defmodule Mercator.Catalog.Price do
  @moduledoc """
  A net price per unit of a variant (#50). Several rows express graduated
  prices (`min_quantity`), time-limited prices (`valid_from`/`valid_until`)
  and promotions. See `Mercator.Catalog.Pricing` for the selection rules.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  @editable [:amount, :min_quantity, :valid_from, :valid_until, :promotion]

  postgres do
    table "prices"
    repo Mercator.Repo

    references do
      reference :variant, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept @editable ++ [:variant_id]
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
      authorize_if expr(variant.active and variant.product.state == :active)
    end
  end

  validations do
    validate compare(:valid_until, greater_than_or_equal_to: :valid_from),
      where: [present([:valid_from, :valid_until])]
  end

  attributes do
    uuid_primary_key :id

    attribute :amount, :decimal do
      description "Net price per unit."
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :min_quantity, :decimal do
      description "Applies from this ordered quantity on (graduated prices)."
      allow_nil? false
      default 1
      public? true
      constraints greater_than: 0
    end

    attribute :valid_from, :date, public?: true
    attribute :valid_until, :date, public?: true

    attribute :promotion, :boolean do
      description "Promotion price; the regular price is shown crossed out."
      allow_nil? false
      default false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :variant, Mercator.Catalog.Variant do
      allow_nil? false
      public? true
    end
  end
end
