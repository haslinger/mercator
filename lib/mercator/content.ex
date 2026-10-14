defmodule Mercator.Content do
  @moduledoc """
  Content domain (CMS, phase 5, see docs/cms-design.md): pages built from
  blocks, with a working copy, publishing and a history of published
  versions.
  """
  use Ash.Domain,
    otp_app: :mercator,
    extensions: [AshAdmin.Domain, AshPhoenix, AshPaperTrail.Domain]

  admin do
    show? true
  end

  paper_trail do
    include_versions?(true)
  end

  resources do
    resource Mercator.Content.Page do
      define :get_page, action: :read, get_by: [:id]
      define :get_published_page, action: :published_by_path, args: [:path], get?: true
      define :get_page_by_path, action: :read, get_by: [:path]
      define :list_pages, action: :read
      define :create_page, action: :create
      define :update_page, action: :update
      define :move_page, action: :move
      define :publish_page, action: :publish
      define :discard_page_changes, action: :discard_changes
      define :restore_page_version, action: :restore_version, args: [:version_id]
      define :hide_page, action: :hide
      define :show_page, action: :show
      define :archive_page, action: :archive
      define :destroy_page, action: :destroy
    end
  end
end
