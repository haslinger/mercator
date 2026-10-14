defmodule Mercator.Repo.Migrations.AddOfferNumberCounters do
  @moduledoc """
  Gap-free offer number counters per year, used by
  `Mercator.Consulting.Changes.AssignOfferNumber`. Not an Ash resource.
  """
  use Ecto.Migration

  def change do
    create table(:offer_number_counters, primary_key: false) do
      add :year, :integer, primary_key: true
      add :last, :integer, null: false
    end
  end
end
