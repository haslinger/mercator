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
      define :get_published_page_by_key, action: :published_by_key, args: [:key], get?: true
      define :get_page_by_key, action: :read, get_by: [:key]
      define :list_menu_pages, action: :menu, args: [:menu]
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

    resource Mercator.Content.Submission do
      define :submit_contact_form, action: :submit
      define :list_submissions, action: :read
      define :mark_submission_handled, action: :mark_handled
      define :mark_submission_open, action: :mark_open
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

  alias Mercator.Content.{Blocks, Page}

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

  @doc """
  The paths above a page path, root first:

      iex> Mercator.Content.ancestor_paths("kontakt/anfahrt/parken")
      ["kontakt", "kontakt/anfahrt"]
  """
  def ancestor_paths(path) do
    path
    |> String.split("/")
    |> Enum.drop(-1)
    |> Enum.scan(&(&2 <> "/" <> &1))
  end

  @doc """
  Paths of pages that are offline (draft or archived). Their subpages are
  offline too: see `reachable?/2`.
  """
  def offline_paths do
    Page
    |> Ash.Query.filter(kind == :page and state in [:draft, :archived])
    |> Ash.Query.select([:path])
    |> Ash.read!(authorize?: false)
    |> MapSet.new(& &1.path)
  end

  @doc "Whether no ancestor of the page is offline (`offline_paths/0`)."
  def reachable?(%{path: path}, offline \\ offline_paths()) do
    not Enum.any?(ancestor_paths(path), &MapSet.member?(offline, &1))
  end

  @doc "The visible ancestors of a page (published or hidden), root first."
  def published_ancestors(%{path: path}) do
    case ancestor_paths(path) do
      [] ->
        []

      paths ->
        Page
        |> Ash.Query.filter(path in ^paths and kind == :page and state in [:published, :hidden])
        |> Ash.read!(authorize?: false)
        |> Enum.sort_by(&String.length(&1.path))
    end
  end

  @doc "The published subpages of a page (hidden ones are not listed), in order."
  def published_children(%{id: id}) do
    Page
    |> Ash.Query.filter(parent_id == ^id and kind == :page and state == :published)
    |> Ash.Query.sort(position: :asc, path: :asc)
    |> Ash.read!(authorize?: false)
  end

  @doc "The media library files the blocks refer to, as a map id => asset."
  def assets_for_blocks(blocks), do: blocks |> Blocks.asset_ids() |> assets_by_ids()

  @doc "Media library files by id, as a map id => asset; unknown ids are left out."
  def assets_by_ids(ids) do
    case Enum.reject(ids, &(&1 in [nil, ""])) do
      [] ->
        %{}

      ids ->
        Mercator.Content.Asset
        |> Ash.Query.filter(id in ^ids)
        |> Ash.read!(authorize?: false)
        |> Map.new(&{&1.id, &1})
    end
  end

  @doc "All tags used in the media library, alphabetically."
  def asset_tags do
    %{rows: rows} =
      Mercator.Repo.query!("SELECT DISTINCT unnest(tags) AS tag FROM assets ORDER BY tag")

    List.flatten(rows)
  end
end
