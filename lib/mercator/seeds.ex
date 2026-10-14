defmodule Mercator.Seeds do
  @moduledoc """
  Demo and development data, loaded by `priv/repo/seeds.exs`.

  Seeding is idempotent: users that already exist (matched by email) are not
  created again, only their demo name is brought up to date, so
  `mix run priv/repo/seeds.exs` can run any number of times.

  All demo users share the password `demo_password/0` and are confirmed.
  The demo catalogue comes from `Mercator.Seeds.BiberHolz`, demo addresses
  and orders from `Mercator.Seeds.Orders`, CMS pages from `Mercator.Seeds.Pages`.
  """

  alias Mercator.Accounts.User
  alias Mercator.Seeds.{BiberHolz, Orders, Pages}

  require Ash.Query

  @demo_password "mercator-demo"

  # Surnames of animals living in the woods (Biber Holz demo)
  @demo_users [
    %{email: "admin@example.com", name: "Anna Specht", roles: [:administrator]},
    %{email: "sales@example.com", name: "Sepp Fuchs", roles: [:sales]},
    %{email: "manager@example.com", name: "Maria Hirsch", roles: [:sales, :sales_manager]},
    %{email: "content@example.com", name: "Klara Eichhorn", roles: [:contentmanager]},
    %{email: "products@example.com", name: "Peter Dachs", roles: [:productmanager]},
    %{
      email: "kunde@example.com",
      name: "Karl Luchs",
      roles: [],
      locale: :de,
      invoice_allowed: true
    },
    %{email: "customer@example.com", name: "Lena Igel", roles: [], locale: :en}
  ]

  # Austrian VAT rates for the demo (#51, information from the Wirtschaftskammer):
  # 13 % for firewood, wood pellets and Christmas trees, 20 % for everything
  # else, including saw logs that are not sold as fuel.
  @tax_classes [
    %{
      key: "standard",
      name: %{"de" => "Normalsatz 20 %", "en" => "Standard rate 20 %"},
      rate: 20,
      position: 1
    },
    %{
      key: "reduced",
      name: %{"de" => "Ermäßigt 13 %", "en" => "Reduced rate 13 %"},
      rate: 13,
      position: 2
    }
  ]

  @doc "The password of all demo users."
  def demo_password, do: @demo_password

  @doc "The demo users as attribute maps."
  def demo_users, do: @demo_users

  @doc "Seeds all demo data. Returns the demo users."
  def run do
    Enum.each(@tax_classes, &ensure_tax_class/1)
    users = Enum.map(@demo_users, &ensure_user/1)
    BiberHolz.run()
    ensure_gtc()
    Orders.run()
    Pages.run()
    users
  end

  defp ensure_gtc do
    %{version: version, text: text} = BiberHolz.gtc()

    Mercator.Sales.Gtc
    |> Ash.Query.filter(version == ^version)
    |> Ash.exists?(authorize?: false)
    |> unless(do: Ash.Seed.seed!(Mercator.Sales.Gtc, %{version: version, text: text}))
  end

  defp ensure_tax_class(%{key: key} = attrs) do
    case Mercator.Catalog.get_tax_class_by_key(key, authorize?: false) do
      {:ok, tax_class} -> tax_class
      {:error, _} -> Ash.Seed.seed!(Mercator.Catalog.TaxClass, attrs)
    end
  end

  defp ensure_user(%{email: email} = attrs) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> create_user(attrs)
      user -> sync_user(user, attrs)
    end
  end

  defp sync_user(user, attrs) do
    changes = %{name: attrs.name, invoice_allowed: Map.get(attrs, :invoice_allowed, false)}

    if Map.take(user, Map.keys(changes)) == changes,
      do: user,
      else: Ash.Seed.update!(user, changes)
  end

  # Seeds bypass the registration action (no confirmation email, no token)
  # and write confirmed users directly.
  defp create_user(attrs) do
    Ash.Seed.seed!(
      User,
      Map.merge(
        %{
          hashed_password: Bcrypt.hash_pwd_salt(@demo_password),
          confirmed_at: DateTime.utc_now(),
          locale: :de
        },
        attrs
      )
    )
  end
end
