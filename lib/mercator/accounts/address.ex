defmodule Mercator.Accounts.Address do
  @moduledoc """
  An address in a customer's address book (checkout-design.md §3). The
  checkout copies the chosen addresses onto the order as a snapshot.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Accounts.Validations.PostcodeFormat

  require Ash.Query

  @editable [:name, :company, :street, :postcode, :city, :country, :phone, :vat_id]

  postgres do
    table "addresses"
    repo Mercator.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept @editable ++ [:default_billing, :default_shipping]
      change relate_actor(:user)
      validate PostcodeFormat
      change after_action(&clear_other_defaults/3)
    end

    update :update do
      primary? true
      require_atomic? false
      accept @editable ++ [:default_billing, :default_shipping]
      validate PostcodeFormat
      change after_action(&clear_other_defaults/3)
    end

    read :mine do
      description "The actor's addresses, defaults first."
      filter expr(user_id == ^actor(:id))
      prepare build(sort: [default_billing: :desc, default_shipping: :desc, inserted_at: :asc])
    end
  end

  # only one default billing / shipping address per user
  defp clear_other_defaults(_changeset, address, _context) do
    for {flag, true} <- [
          default_billing: address.default_billing,
          default_shipping: address.default_shipping
        ] do
      __MODULE__
      |> Ash.Query.filter(user_id == ^address.user_id and id != ^address.id)
      |> Ash.Query.do_filter([{flag, true}])
      |> Ash.bulk_update!(:update, %{flag => false}, authorize?: false, strategy: :stream)
    end

    {:ok, address}
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :update, :destroy]) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  validations do
    validate attribute_in(:country, Mercator.Countries.billing())
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :company, :string, public?: true, constraints: [max_length: 200]
    attribute :street, :string, allow_nil?: false, public?: true, constraints: [max_length: 200]
    attribute :postcode, :string, allow_nil?: false, public?: true, constraints: [max_length: 20]
    attribute :city, :string, allow_nil?: false, public?: true, constraints: [max_length: 100]

    attribute :country, :string do
      description "ISO 3166-1 alpha-2 code, see Mercator.Countries."
      allow_nil? false
      default "AT"
      public? true
    end

    attribute :phone, :string, public?: true, constraints: [max_length: 50]

    attribute :vat_id, :string do
      description "VAT identification number of business customers (#69: shown only, no reverse charge yet)."
      public? true
      constraints max_length: 30
    end

    attribute :default_billing, :boolean, allow_nil?: false, default: false, public?: true
    attribute :default_shipping, :boolean, allow_nil?: false, default: false, public?: true
    timestamps()
  end

  relationships do
    belongs_to :user, Mercator.Accounts.User, allow_nil?: false, public?: true
  end
end
