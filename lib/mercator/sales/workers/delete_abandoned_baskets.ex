defmodule Mercator.Sales.Workers.DeleteAbandonedBaskets do
  @moduledoc "Nightly: deletes visitor baskets not touched for 30 days (checkout-design.md §3)."
  use Oban.Worker, queue: :default

  alias Mercator.Sales.Baskets

  @impl Oban.Worker
  def perform(_job), do: Baskets.delete_abandoned(30)
end
