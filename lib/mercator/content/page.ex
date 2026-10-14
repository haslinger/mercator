defmodule Mercator.Content.Page do
  @moduledoc """
  A CMS page (docs/cms-design.md): a tree of pages under `/pages/…` (#80),
  each an ordered list of blocks (#76, embedded, #89).

  Title, SEO description and blocks are the **working copy**; `publish`
  copies them to `published`, which visitors see (#90). Every publish is
  recorded as a version (AshPaperTrail, #84); `restore_version` copies a
  version back into the working copy.

  States: `draft` (never published, only staff), `published`, `hidden`
  (reachable by URL, not in menus), `archived` (offline again).

  Kind `shared`: a set of blocks that other pages embed with a Shared block
  (e.g. opening hours); never shown at its own URL and not in menus.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine, AshPaperTrail.Resource]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Catalog.Changes.SetSlug
  alias Mercator.Content.Changes.{DiscardChanges, Publish, RestoreVersion, SetPagePath}

  @content [:title, :seo_description, :blocks]

  postgres do
    table "pages"
    repo Mercator.Repo

    references do
      reference :parent, on_delete: :restrict
    end
  end

  state_machine do
    initial_states [:draft]
    default_initial_state :draft

    transitions do
      transition :publish,
        from: [:draft, :published, :hidden, :archived],
        to: [:published, :hidden]

      transition :hide, from: :published, to: :hidden
      transition :show, from: :hidden, to: :published
      transition :archive, from: [:published, :hidden], to: :archived
    end
  end

  paper_trail do
    change_tracking_mode(:snapshot)
    on_actions([:publish])
    store_action_name?(true)
    create_version_on_destroy?(false)
    ignore_actions([:create])
    ignore_attributes([:inserted_at, :updated_at])
    belongs_to_actor(:user, Mercator.Accounts.User, domain: Mercator.Accounts, public?: true)
  end

  actions do
    defaults [:read]

    read :published_by_path do
      description "A page visitors can see (published or hidden), by its path."
      argument :path, :string, allow_nil?: false
      get? true
      filter expr(path == ^arg(:path) and kind == :page and state in [:published, :hidden])
    end

    read :published_by_key do
      description "A visible page by its key, e.g. `home` for the start page."
      argument :key, :string, allow_nil?: false
      get? true
      filter expr(key == ^arg(:key) and kind == :page and state in [:published, :hidden])
    end

    read :menu do
      description "Published pages in a menu (`:main` or `:footer`), in tree order."
      argument :menu, :atom, allow_nil?: false
      filter expr(menu == ^arg(:menu) and kind == :page and state == :published)
      prepare build(sort: [position: :asc, path: :asc])
    end

    create :create do
      primary? true
      accept @content ++ [:slug, :key, :menu, :position, :parent_id, :kind, :icon]
      change {SetSlug, from: :title}
      change SetPagePath
    end

    update :update do
      description "Edits the working copy and the page settings."
      primary? true
      require_atomic? false
      accept @content ++ [:slug, :key, :menu, :position, :icon]
      change {SetSlug, from: :title}
      change SetPagePath
      change set_attribute(:changes_pending, true), where: [changing(:title)]
      change set_attribute(:changes_pending, true), where: [changing(:seo_description)]
      change set_attribute(:changes_pending, true), where: [changing(:blocks)]
    end

    update :move do
      description "Move the page below another parent (or to the top level with nil)."
      require_atomic? false
      accept [:parent_id, :position]
      change SetPagePath
    end

    update :publish do
      description "Makes the working copy the published version; recorded in the history."
      require_atomic? false
      change Publish
    end

    update :discard_changes do
      description "Resets the working copy to the published version."
      require_atomic? false
      validate present(:published), message: "has not been published yet"
      change DiscardChanges
    end

    update :restore_version do
      description "Copies a published version from the history into the working copy."
      require_atomic? false
      argument :version_id, :uuid, allow_nil?: false
      change RestoreVersion
    end

    update :hide, change: transition_state(:hidden)
    update :show, change: transition_state(:published)
    update :archive, change: transition_state(:archived)

    destroy :destroy do
      primary? true

      validate attribute_equals(:state, :draft),
        message: "only pages that were never published can be deleted; archive them instead"
    end
  end

  policies do
    bypass {ActorHasRole, role: :administrator} do
      authorize_if always()
    end

    bypass {ActorHasRole, role: :contentmanager} do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if expr(state in [:published, :hidden])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, Mercator.Translated do
      allow_nil? false
      public? true
      constraints required: ["de"], max_length: 200
    end

    attribute :seo_description, Mercator.Translated do
      description "Meta description for search engines (#91)."
      public? true
      constraints max_length: 300
    end

    attribute :blocks, {:array, Mercator.Content.Block} do
      allow_nil? false
      default []
      public? true
    end

    attribute :published, Mercator.Content.PageContent do
      description "The published content; nil until the first publish."
      public? true
      writable? false
    end

    attribute :published_at, :utc_datetime_usec, public?: true, writable?: false

    attribute :changes_pending, :boolean do
      description "The working copy differs from the published version."
      allow_nil? false
      default false
      public? true
      writable? false
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9]+(-[a-z0-9]+)*$/, max_length: 100
    end

    attribute :path, :string do
      description "Slugs of the ancestors and the page, e.g. `ueber-uns/team` (URL /pages/…)."
      allow_nil? false
      public? true
      writable? false
    end

    attribute :key, :string do
      description "For pages the code links to, e.g. `home`, `imprint`, `privacy`, `contact`."
      public? true
      constraints match: ~r/^[a-z_]+$/, max_length: 50
    end

    attribute :menu, :atom do
      description "Where the page is linked: main navigation, footer, or nowhere."
      allow_nil? false
      default :none
      public? true
      constraints one_of: [:none, :main, :footer]
    end

    attribute :position, :integer do
      allow_nil? false
      default 0
      public? true
    end

    attribute :icon, :string do
      description "Heroicon shown in the navigation, e.g. `hero-envelope`."
      public? true
      constraints match: ~r/^hero-[a-z0-9-]+$/, max_length: 60
    end

    attribute :kind, :atom do
      description "`page`, or `shared`: blocks embedded in other pages."
      allow_nil? false
      default :page
      public? true
      constraints one_of: [:page, :shared]
    end

    timestamps()
  end

  relationships do
    belongs_to :parent, __MODULE__, public?: true

    has_many :children, __MODULE__ do
      destination_attribute :parent_id
      sort position: :asc, path: :asc
      public? true
    end
  end

  identities do
    identity :unique_path, [:path]
    identity :unique_key, [:key]
  end
end
