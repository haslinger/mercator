defmodule Mercator.Consulting.Workers.ExpireOffers do
  @moduledoc "Nightly: sent offers past their validity date expire."
  use Oban.Worker, queue: :default

  alias Mercator.Consulting.Offers

  @impl Oban.Worker
  def perform(_job), do: Offers.expire_overdue()
end
