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

    resource Mercator.Content.Asset do
      define :get_asset, action: :read, get_by: [:id]
      define :list_assets, action: :read
      define :search_assets, action: :search
      define :upload_asset, action: :upload
      define :update_asset, action: :update
      define :destroy_asset, action: :destroy
    end
  end

  require Ash.Query

  alias Mercator.Content.Blocks

  @doc """
  Moves a page below `parent_id` (nil = top level) at `index` among its
  siblings and renumbers the siblings' positions. Runs as `actor`.
  """
  def place_page(page, parent_id, index, actor) do
    with {:ok, page} <- maybe_move(page, parent_id, actor) do
      page.parent_id
      |> siblings(actor)
      |> Enum.reject(&(&1.id == page.id))
      |> List.insert_at(index, page)
      |> Enum.with_index(1)
      |> Enum.each(fn {sibling, position} -> set_position(sibling, position, actor) end)

      get_page(page.id, actor: actor)
    end
  end

  defp maybe_move(%{parent_id: parent_id} = page, parent_id, _actor), do: {:ok, page}

  defp maybe_move(page, parent_id, actor),
    do: move_page(page, %{parent_id: parent_id}, actor: actor)

  defp siblings(parent_id, actor) do
    Mercator.Content.Page
    |> then(fn query ->
      if parent_id,
        do: Ash.Query.filter(query, parent_id == ^parent_id),
        else: Ash.Query.filter(query, is_nil(parent_id))
    end)
    |> Ash.Query.sort(position: :asc, path: :asc)
    |> Ash.read!(actor: actor)
  end

  defp set_position(%{position: position}, position, _actor), do: :ok

  defp set_position(page, position, actor),
    do: update_page!(page, %{position: position}, actor: actor)

  @doc """
  Changes the block list of a page's working copy with `fun`, which gets
  and returns the blocks as input maps (see `Mercator.Content.Blocks`).
  """
  def update_page_blocks(page, fun, actor) do
    blocks = page.blocks |> Enum.map(&Blocks.to_input/1) |> fun.()
    update_page(page, %{blocks: blocks}, actor: actor)
  end

  @doc "All tags used in the media library, alphabetically."
  def asset_tags do
    %{rows: rows} =
      Mercator.Repo.query!("SELECT DISTINCT unnest(tags) AS tag FROM assets ORDER BY tag")

    List.flatten(rows)
  end
end
