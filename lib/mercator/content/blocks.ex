defmodule Mercator.Content.Blocks do
  @moduledoc """
  The block types of CMS pages (#76) and helpers to edit a page's block
  list. The types themselves are the union members of
  `Mercator.Content.Block`.
  """

  alias Ash.Resource.Info
  alias Mercator.Content.Block

  @doc "Block types that can be added, as `{type, module}`."
  def types do
    Block.subtype_constraints()
    |> Keyword.fetch!(:types)
    |> Enum.map(fn {type, config} -> {to_string(type), config[:type]} end)
  end

  @doc "A stored block (`Ash.Union`) as an input map with string keys."
  def to_input(%Ash.Union{type: type, value: value}) do
    value.__struct__
    |> Info.attributes()
    |> Map.new(&{to_string(&1.name), Map.get(value, &1.name)})
    |> Map.put("type", to_string(type))
  end

  @doc "A new, empty block of a type, as an input map."
  def new(type) when is_binary(type), do: %{"type" => type, "id" => Ash.UUID.generate()}

  @doc "Replaces the block with the same id, or appends it if it is new."
  def put(blocks, %{"id" => id} = block) do
    if Enum.any?(blocks, &(&1["id"] == id)),
      do: Enum.map(blocks, &if(&1["id"] == id, do: Map.merge(&1, block), else: &1)),
      else: blocks ++ [block]
  end

  @doc "Ids of the media library files the blocks refer to."
  def asset_ids(blocks) do
    blocks
    |> Enum.flat_map(fn %Ash.Union{value: value} ->
      [Map.get(value, :image_id), Map.get(value, :document_id) | Map.get(value, :image_ids) || []]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc "Removes the block with the id."
  def delete(blocks, id), do: Enum.reject(blocks, &(&1["id"] == id))

  @doc "Moves the block with the id to `index`."
  def move(blocks, id, index) do
    case Enum.split_with(blocks, &(&1["id"] == id)) do
      {[block], rest} -> List.insert_at(rest, index, block)
      _ -> blocks
    end
  end
end
