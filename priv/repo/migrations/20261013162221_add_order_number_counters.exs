defmodule Mercator.Repo.Migrations.AddOrderNumberCounters do
  @moduledoc """
  Gap-free order number counters per year (#68), used by
  `Mercator.Sales.Changes.AssignOrderNumber`. Not an Ash resource.
  """
  use Ecto.Migration

  def change do
    create table(:order_number_counters, primary_key: false) do
      add :year, :integer, primary_key: true
      add :last, :integer, null: false
    end
  end
end
