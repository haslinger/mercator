defmodule Mercator.Operations.Settings do
  @moduledoc """
  Reading and changing runtime settings (`Mercator.Operations.Setting`).
  Reading needs no actor; changing is for administrators.
  """
  require Ash.Query

  alias Mercator.Operations.Setting

  @doc "The value (a map) of a setting, or `default`."
  def get(key, default \\ %{}) when is_binary(key) do
    Setting
    |> Ash.Query.filter(key == ^key)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> default
      setting -> setting.value
    end
  end

  @doc "Sets a value as `actor`."
  def put(key, value, actor) when is_binary(key) and is_map(value) do
    Setting
    |> Ash.Changeset.for_create(:put, %{key: key, value: value}, actor: actor)
    |> Ash.create()
  end
end
