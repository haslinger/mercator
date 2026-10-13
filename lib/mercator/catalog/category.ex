defmodule Mercator.Catalog.Category do
  @moduledoc """
  A product category in a tree (decision #49: materialised `ltree` path).

  States (#52): `draft` (only staff), `active` (shown in the navigation),
  `hidden` (reachable by link, not in the navigation).
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Catalog.Changes.{SetCategoryPath, SetSlug}
  alias Mercator.Catalog.Preparations.Tree

  @editable [:name, :description, :long_description, :slug, :position]

  postgres do
    table "categories"
    repo Mercator.Repo

    references do
      reference :parent, on_delete: :restrict
    end

    custom_indexes do
      index [:path], using: "gist"
    end
  end

  state_machine do
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :activate, from: [:draft, :hidden], to: :active
      transition :hide, from: [:draft, :active], to: :hidden
      transition :deactivate, from: [:active, :hidden], to: :draft
    end
  end

  actions do
    defaults [:read, :destroy]

    read :roots do
      description "Top-level categories, in order."
      filter expr(is_nil(parent_id))
      prepare build(sort: [position: :asc, slug: :asc])
    end

    read :children do
      argument :category_id, :uuid, allow_nil?: false
      filter expr(parent_id == ^arg(:category_id))
      prepare build(sort: [position: :asc, slug: :asc])
    end

    read :ancestors do
      description "All ancestors of a category, root first."
      argument :category_id, :uuid, allow_nil?: false
      prepare {Tree, relation: :ancestors}
    end

    read :subtree do
      description "A category and all its descendants."
      argument :category_id, :uuid, allow_nil?: false
      prepare {Tree, relation: :subtree}
    end

    create :create do
      primary? true
      accept @editable ++ [:parent_id]
      change SetSlug
      change SetCategoryPath
    end

    update :update do
      primary? true
      require_atomic? false
      accept @editable
      change SetSlug
    end

    update :move do
      description "Move the category below another parent (or to the top level with nil)."
      require_atomic? false
      accept [:parent_id, :position]
      change SetCategoryPath
    end

    update :activate do
      change transition_state(:active)
    end

    update :hide do
      change transition_state(:hidden)
    end

    update :deactivate do
      change transition_state(:draft)
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
      authorize_if expr(state in [:active, :hidden])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 200
    end

    attribute :description, Mercator.Translated do
      public? true
      constraints max_length: 1000
    end

    attribute :long_description, Mercator.Translated do
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9]+(-[a-z0-9]+)*$/, max_length: 200
    end

    attribute :path, AshPostgres.Ltree do
      description "Ids of the ancestors and the category itself (ltree)."
      allow_nil? false
      public? true
      writable? false
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :parent, __MODULE__ do
      public? true
    end

    has_many :children, __MODULE__ do
      destination_attribute :parent_id
      sort position: :asc, slug: :asc
      public? true
    end

    has_many :categorizations, Mercator.Catalog.Categorization, public?: true

    many_to_many :products, Mercator.Catalog.Product do
      through Mercator.Catalog.Categorization
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
