defmodule Mercator.Seeds.OrdersTest do
  use Mercator.DataCase, async: false

  alias Mercator.Accounts.User
  alias Mercator.{Sales, Seeds}

  require Ash.Query

  setup do
    Seeds.run()
    :ok
  end

  defp orders(email) do
    user = User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
    Sales.list_my_orders!(actor: user, load: [:events])
  end

  test "creates demo orders in different states, backdated, without emails" do
    orders = orders("kunde@example.com") ++ orders("customer@example.com")

    assert length(orders) == 6

    assert orders |> Enum.map(& &1.state) |> Enum.uniq() |> Enum.sort() ==
             Enum.sort([:placed, :paid, :completed, :shipped, :cancelled])

    assert Enum.any?(orders, &(&1.shipping_method == :pickup))
    refute Enum.any?(orders, & &1.shipping_estimate)

    oldest = Enum.min_by(orders, & &1.inserted_at, DateTime)
    assert DateTime.diff(DateTime.utc_now(), oldest.inserted_at, :day) >= 39

    assert Enum.all?(
             oldest.events,
             &(DateTime.compare(&1.inserted_at, oldest.inserted_at) == :gt)
           )

    refute Enum.any?(orders, fn order -> Enum.any?(order.events, & &1.customer_notified) end)

    refute Repo.exists?(Oban.Job)
  end

  test "is idempotent" do
    Seeds.run()
    assert length(orders("kunde@example.com")) == 4
  end
end
