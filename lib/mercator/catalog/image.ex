defmodule Mercator.Catalog.Image do
  @moduledoc """
  An uploaded image of a product (several, ordered) or a category (#58).

  The file itself lives on local disk (#11) in `images/<id>/` below
  `Mercator.Uploads.root/0`, in the sizes of `Mercator.Catalog.ImageProcessing`.
  """
  use Ash.Resource,
    otp_app: :mercator,
    domain: Mercator.Catalog,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Mercator.Accounts.Checks.ActorHasRole
  alias Mercator.Catalog.Changes.ProcessImage
  alias Mercator.Catalog.Validations.ExactlyOneOwner
  alias Mercator.Uploads

  postgres do
    table "images"
    repo Mercator.Repo

    references do
      reference :product, on_delete: :delete
      reference :category, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :upload do
      primary? true

      description "Store an image file (path on the server, e.g. a LiveView upload) for a product or category."

      accept [:product_id, :category_id, :alt, :position, :original_filename]
      argument :source_path, :string, allow_nil?: false
      validate ExactlyOneOwner
      change ProcessImage
    end

    update :update do
      primary? true
      accept [:alt, :position]
    end

    destroy :destroy do
      primary? true
      require_atomic? false

      change after_action(fn _changeset, image, _context ->
               Uploads.delete_dir("images/#{image.id}")
               {:ok, image}
             end)
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
      authorize_if expr(not is_nil(product_id) and product.state == :active)
      authorize_if expr(not is_nil(category_id) and category.state in [:active, :hidden])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :alt, Mercator.Translated do
      description "Alternative text for screen readers."
      public? true
      constraints max_length: 300
    end

    attribute :position, :integer, allow_nil?: false, default: 0, public?: true
    attribute :original_filename, :string, public?: true, constraints: [max_length: 255]
    attribute :width, :integer, public?: true
    attribute :height, :integer, public?: true
    timestamps()
  end

  relationships do
    belongs_to :product, Mercator.Catalog.Product, public?: true
    belongs_to :category, Mercator.Catalog.Category, public?: true
  end

  @doc "The URL of one size (`:large` or `:thumb`) of an image."
  def url(%__MODULE__{id: id}, size \\ :thumb), do: Uploads.url("images/#{id}/#{size}.webp")
end
