defmodule Mercator.Content.Asset do
  @moduledoc """
  A file of the media library (docs/cms-design.md, #85): an image or a PDF
  document, used by page blocks. Organised with tags (at least one) and
  found by search.

  Files live below `Mercator.Uploads.root/0` in `assets/<id>/`: images as
  WebP in the sizes `wide` (1920 px, for hero images), `large` and `thumb`;
  documents as uploaded, under a cleaned-up file name.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Content,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require Ash.Query

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Content.Changes.{NormalizeTags, StoreAsset}
  alias Mercator.Uploads

  postgres do
    table "assets"
    repo Mercator.Repo

    custom_indexes do
      index [:tags], using: "gin"
    end
  end

  actions do
    defaults [:read]

    read :search do
      description "Newest first; filtered by a text (title, file name, tag) and/or a tag and kind."
      argument :query, :string
      argument :tag, :string
      argument :kind, :atom, constraints: [one_of: [:image, :document]]

      filter expr(is_nil(^arg(:kind)) or kind == ^arg(:kind))
      filter expr(is_nil(^arg(:tag)) or ^arg(:tag) in tags)

      prepare fn query, _context ->
        case String.trim(Ash.Query.get_argument(query, :query) || "") do
          "" ->
            query

          text ->
            pattern = "%" <> String.replace(text, ~r/[\\%_]/, "\\\\\\0") <> "%"

            Ash.Query.filter(
              query,
              fragment(
                "concat_ws(' ', ? ->> 'de', ? ->> 'en', ?, array_to_string(?, ' ')) ILIKE ?",
                title,
                title,
                original_filename,
                tags,
                ^pattern
              )
            )
        end
      end

      prepare build(sort: [inserted_at: :desc])
    end

    create :upload do
      primary? true

      description "Store a file (path on the server, e.g. a LiveView upload) in the media library."

      accept [:title, :alt, :tags, :original_filename]
      argument :source_path, :string, allow_nil?: false
      change NormalizeTags
      change StoreAsset
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:title, :alt, :tags]
      change NormalizeTags
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      validate Mercator.Content.Validations.AssetUnused

      change after_action(fn _changeset, asset, _context ->
               Uploads.delete_dir("assets/#{asset.id}")
               {:ok, asset}
             end)
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
      # assets are shown on public pages
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :kind, :atom do
      allow_nil? false
      public? true
      writable? false
      constraints one_of: [:image, :document]
    end

    attribute :title, Mercator.Translated do
      public? true
      constraints max_length: 200
    end

    attribute :alt, Mercator.Translated do
      description "Alternative text of an image for screen readers."
      public? true
      constraints max_length: 300
    end

    attribute :tags, {:array, :string} do
      allow_nil? false
      public? true
      constraints min_length: 1, items: [max_length: 40]
    end

    attribute :original_filename, :string, public?: true, constraints: [max_length: 255]

    attribute :file_name, :string do
      description "Stored name of a document."
      public? true
      writable? false
    end

    attribute :content_type, :string, public?: true, writable?: false
    attribute :byte_size, :integer, public?: true, writable?: false
    attribute :width, :integer, public?: true, writable?: false
    attribute :height, :integer, public?: true, writable?: false

    timestamps()
  end

  @doc "The URL of an image size (`:wide`, `:large`, `:thumb`) or of a document."
  def url(asset, size \\ :large)

  def url(%__MODULE__{kind: :document} = asset, _size),
    do: Uploads.url("assets/#{asset.id}/#{asset.file_name}")

  def url(%__MODULE__{id: id}, size), do: Uploads.url("assets/#{id}/#{size}.webp")
end
