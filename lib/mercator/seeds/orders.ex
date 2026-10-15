defmodule Mercator.Seeds.Orders do
  @moduledoc """
  Demo orders for Karl Luchs and Lena Igel in different states (checkout
  step 7), so the order history and the back office have content.

  Orders go through the real checkout (basket, stock, totals) and the real
  state transitions by the demo sales staff, without emails, and are then
  backdated. Each demo order is identified by its customer note: an order
  that already exists for that customer is not created again.
  """

  import Ecto.Query, only: [from: 2]

  alias Mercator.{Accounts, Catalog, Repo, Sales}
  alias Mercator.Accounts.User
  alias Mercator.Sales.{Baskets, Checkout}

  require Ash.Query

  @addresses %{
    "kunde@example.com" => %{
      name: "Karl Luchs",
      street: "Waldweg 3",
      postcode: "6020",
      city: "Innsbruck",
      country: "AT",
      phone: "+43 512 123456"
    },
    "customer@example.com" => %{
      name: "Lena Igel",
      company: "Igel Gartenbau GmbH",
      street: "Leopoldstraße 12",
      postcode: "80802",
      city: "München",
      country: "DE"
    }
  }

  # days: placed that many days ago; steps: {action, days after placing, args}
  @orders [
    %{
      customer: "kunde@example.com",
      note: "Bitte beim Nachbarn abgeben, falls niemand da ist.",
      days: 40,
      lines: [{"BH-ZIRBE-BRETT-1", 4}, {"BH-OEL-TERRASSE-1", 2}],
      params: %{"shipping_method" => "parcel", "payment_method" => "invoice"},
      steps: [
        {:confirm_order!, 1, %{}},
        {:ship_order!, 2, %{note: "Paket an die Post übergeben."}},
        {:mark_order_paid!, 16, %{note: "Rechnung bezahlt."}},
        {:complete_order!, 17, %{}}
      ]
    },
    %{
      customer: "kunde@example.com",
      note: "Zufahrt über den Forstweg, LKW bis 12 m möglich.",
      days: 14,
      lines: [
        {"BH-GH-KOMPAKT-1", 1},
        {"BH-TISCHPLATTE-MASS-1", 1,
         %{
           "species" => "oak",
           "thickness" => "40",
           "edge" => "live_edge",
           "finish" => "oiled",
           "length" => "2000",
           "width" => "900"
         }}
      ],
      params: %{"shipping_method" => "freight", "payment_method" => "prepayment"},
      steps: [
        {:confirm_order!, 1,
         %{
           shipping_gross: "189",
           note: "Lieferung mit Kran-LKW in KW 44, mit Kunde telefonisch vereinbart."
         }},
        {:mark_order_paid!, 4, %{}}
      ]
    },
    %{
      customer: "kunde@example.com",
      note: "Abholung am Samstag Vormittag.",
      days: 0,
      lines: [{"BH-BRENNHOLZ-LANG-1", 2}],
      params: %{"shipping_method" => "pickup", "payment_method" => "on_pickup"},
      steps: []
    },
    %{
      customer: "kunde@example.com",
      note: "Ein Geschenk für die Enkel.",
      days: 2,
      lines: [{"BH-PLUSHIE-1", 3}],
      params: %{"shipping_method" => "parcel", "payment_method" => "prepayment"},
      steps: []
    },
    %{
      customer: "customer@example.com",
      note: "Please deliver on a weekday.",
      days: 25,
      lines: [{"BH-PELLETS-SACK-PALETTE", 1}],
      params: %{"shipping_method" => "parcel", "payment_method" => "prepayment"},
      steps: [
        {:cancel_order!, 2, %{note: "Customer ordered the wrong quantity; a new order follows."}}
      ]
    },
    %{
      customer: "customer@example.com",
      note: "For our show garden.",
      days: 8,
      lines: [{"BH-PELLETS-SACK-SACK", 10}, {"BH-PLUSHIE-1", 1}],
      params: %{"shipping_method" => "parcel", "payment_method" => "prepayment"},
      steps: [
        {:confirm_order!, 0, %{}},
        {:mark_order_paid!, 2, %{note: "Payment received."}},
        {:ship_order!, 3, %{note: "Shipped with DPD."}}
      ]
    }
  ]

  @doc "Creates the demo addresses and orders that do not exist yet."
  def run do
    customers =
      Map.new(@addresses, fn {email, address} -> {email, ensure_customer(email, address)} end)

    sales = user!("sales@example.com")

    @orders
    |> Enum.reject(&exists?(customers[&1.customer], &1.note))
    |> Enum.sort_by(& &1.days, :desc)
    |> Enum.each(&create(&1, customers[&1.customer], sales))
  end

  defp user!(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp ensure_customer(email, address) do
    user = user!(email)

    if Accounts.list_my_addresses!(actor: user) == [],
      do: Accounts.create_address!(address, actor: user)

    user
  end

  defp exists?(user, note) do
    Repo.exists?(
      from o in "orders", where: o.user_id == type(^user.id, :binary_id) and o.note == ^note
    )
  end

  defp create(spec, user, sales) do
    order = place(spec, user)
    placed_at = DateTime.add(DateTime.utc_now(), -spec.days, :day)

    order =
      Enum.reduce(spec.steps, order, fn {action, _days, args}, order ->
        apply(Sales, action, [order, Map.put(args, :notify, false), [actor: sales]])
      end)

    backdate(order, placed_at, Enum.map(spec.steps, &elem(&1, 1)))
  end

  # Places the order and drops its confirmation email job in the same
  # transaction, so seeding sends no emails.
  defp place(spec, user) do
    Repo.transaction(fn ->
      Baskets.clear({:user, user})

      for line <- spec.lines do
        {number, quantity, selections} = line(line)
        variant = Catalog.get_variant_by_number!(number, authorize?: false)
        {:ok, _item} = Baskets.add({:user, user}, variant.id, quantity, selections)
      end

      params = Map.merge(spec.params, %{"gtc" => "true", "note" => spec.note})
      {:ok, order} = Checkout.place(user, params)

      Repo.delete_all(
        from j in Oban.Job,
          where:
            j.worker == "Mercator.Sales.Workers.SendOrderConfirmation" and
              fragment("?->>'order_id' = ?", j.args, ^order.id)
      )

      order
    end)
    |> then(fn {:ok, order} -> order end)
  end

  defp line({number, quantity}), do: {number, quantity, %{}}
  defp line({_number, _quantity, _selections} = line), do: line

  @doc """
  Moves an order to `placed_at` and its events (in their order) to the
  given days after it, a few hours apart.
  """
  def backdate(order, placed_at, step_days) do
    Repo.update_all(from(o in "orders", where: o.id == type(^order.id, :binary_id)),
      set: [inserted_at: placed_at, updated_at: placed_at]
    )

    events =
      Repo.all(
        from e in "order_events",
          where: e.order_id == type(^order.id, :binary_id),
          order_by: e.inserted_at,
          select: e.id
      )

    events
    |> Enum.zip(step_days)
    |> Enum.with_index(1)
    |> Enum.each(fn {{event_id, days}, index} ->
      # a few hours apart, so changes on the same day keep their order
      at = placed_at |> DateTime.add(days, :day) |> DateTime.add(index * 2, :hour)
      Repo.update_all(from(e in "order_events", where: e.id == ^event_id), set: [inserted_at: at])
    end)
  end
end
