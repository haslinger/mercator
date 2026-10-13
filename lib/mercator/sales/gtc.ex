defmodule Mercator.Sales.Gtc do
  @moduledoc """
  General terms and conditions (AGB). Each version is valid from its date;
  the newest version is the current one. Orders store the version the
  customer accepted. The text is plain text: paragraphs are separated by a
  blank line, lines starting with `## ` are headings.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Sales,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole

  postgres do
    table "gtcs"
    repo Mercator.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:version, :text]
    end

    update :update do
      primary? true
      accept [:text]
    end

    read :current do
      description "The newest version."
      get? true
      prepare build(sort: [version: :desc], limit: 1)
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
