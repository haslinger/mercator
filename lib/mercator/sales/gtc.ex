defmodule Mercator.Sales.Gtc do
  @moduledoc """
  General terms and conditions (AGB, #92). Each version is valid from its
  date; the current one is the newest whose date has come (shop time zone).
  Orders store the version the customer accepted, so a version in force is
  never changed: new versions are dated today or later, and only versions
  not yet in force can be edited or deleted. The text is Markdown.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Clock

  postgres do
    table "gtcs"
    repo Mercator.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:version, :text]
      validate {Mercator.Sales.Validations.GtcNotInForce, field: :version}
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:version, :text]
      validate {Mercator.Sales.Validations.GtcNotInForce, field: :version}
      validate {Mercator.Sales.Validations.GtcNotInForce, data: true}
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      validate {Mercator.Sales.Validations.GtcNotInForce, data: true}
    end

    read :current do
      description "The version in force: the newest whose date has come."
      get? true

      prepare fn query, _context ->
        today = Clock.today()

        query
        |> Ash.Query.filter(version <= ^today)
        |> Ash.Query.sort(version: :desc)
        |> Ash.Query.limit(1)
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if {ActorHasRole, role: :administrator}
      authorize_if {ActorHasRole, role: :contentmanager}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :version, :date do
      description "Valid from this date."
      allow_nil? false
      public? true
    end

    attribute :text, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 100_000
    end

    timestamps()
  end

  identities do
    identity :unique_version, [:version]
  end
end
