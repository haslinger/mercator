defmodule Mercator.Sales.Baskets do
  @moduledoc """
  Basket operations. Every function takes the basket owner:

    * `{:session, token}` – a visitor, identified by the session's basket token
    * `{:user, user}` – a signed-in user

  Operations run without an actor (`authorize?: false`) but are always
  scoped to the owner's basket, so nobody reaches someone else's basket.

  Changes are announced on the PubSub topic `"baskets"` as
  `{:basket_changed, owner_key}` (`owner_key/1`), e.g. for the sales desk.
  """
  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Catalog
  alias Mercator.Catalog.{Configurator, Unit}
  alias Mercator.Sales.{Basket, BasketItem}

  require Ash.Query

  @item_loads [variant: [:prices, product: [:tax_class, :images, options: :choices]]]

  @doc "The owner's basket with its items (variant, product, prices loaded), or nil."
  def get(owner) do
    Basket
    |> filter_owner(owner)
    |> Ash.Query.load(items: @item_loads)
    |> Ash.read_one!(authorize?: false)
  end

  @doc "Number of items (lines) in the owner's basket."
  def count(owner) do
    Basket
    |> filter_owner(owner)
    |> Ash.Query.load(:items)
    |> Ash.read_one!(authorize?: false)
    |> case do
      nil -> 0
      basket -> length(basket.items)
    end
  end

  @doc """
  Adds `quantity` of a variant (for configurable products with its
  `selections`). Identical items (same variant and configuration) are
  merged. Returns `{:ok, item}` or `{:error, message}`.
  """
  def add(owner, variant_id, quantity, selections \\ %{}) do
    with {:ok, variant} <- fetch_variant(variant_id),
         {:ok, quantity} <- parse_quantity(quantity, variant.unit),
         {:ok, selections, config_number} <- configuration(variant.product, selections) do
      basket = get_or_create(owner)

      case Enum.find(basket.items, &(&1.variant_id == variant.id and &1.selections == selections)) do
        nil ->
          Ash.create(
            BasketItem,
            %{
              basket_id: basket.id,
              variant_id: variant.id,
              quantity: quantity,
              selections: selections,
              config_number: config_number
            },
            authorize?: false
          )

        item ->
          Ash.update(item, %{quantity: Decimal.add(item.quantity, quantity)}, authorize?: false)
      end
      |> changed(owner)
    end
  end

  @doc "Sets the quantity of an item in the owner's basket."
  def update_quantity(owner, item_id, quantity) do
    with {:ok, item} <- fetch_item(owner, item_id),
         {:ok, quantity} <- parse_quantity(quantity, item.variant.unit) do
      item |> Ash.update(%{quantity: quantity}, authorize?: false) |> changed(owner)
    end
  end

  @doc "Removes an item from the owner's basket."
  def remove(owner, item_id) do
    with {:ok, item} <- fetch_item(owner, item_id) do
      item |> Ash.destroy(authorize?: false) |> changed(owner)
    end
  end

  @doc "Deletes the owner's basket with its items (after an order); returns notifications."
  def clear(owner) do
    case Basket |> filter_owner(owner) |> Ash.read_one!(authorize?: false) do
      nil ->
        []

      basket ->
        basket |> Ash.destroy!(authorize?: false, return_notifications?: true) |> changed(owner)
    end
  end

  @doc "A stable key of a basket owner: `{:user, id}` or `{:session, token}`."
  def owner_key({:user, %{id: id}}), do: {:user, id}
  def owner_key({:session, token}), do: {:session, token}

  # announces a successful change, passes the result through
  defp changed({:error, _} = error, _owner), do: error

  defp changed(result, owner) do
    Phoenix.PubSub.broadcast(Mercator.PubSub, "baskets", {:basket_changed, owner_key(owner)})
    result
  end

  @doc """
  At login (#8): moves the items of the visitor basket into the user's
  basket (merging identical items) and deletes the visitor basket.
  """
  def merge(token, user) when is_binary(token) do
    case get({:session, token}) do
      nil ->
        :ok

      visitor_basket ->
        for item <- visitor_basket.items do
          add({:user, user}, item.variant_id, item.quantity, item.selections)
        end

        Ash.destroy!(visitor_basket, authorize?: false)
        :ok
    end
  end

  def merge(_token, _user), do: :ok

  @doc "Deletes visitor baskets not touched for `days` days (Oban job)."
  def delete_abandoned(days \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -days, :day)

    Basket
    |> Ash.Query.filter(is_nil(user_id) and updated_at < ^cutoff)
    |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)

    :ok
  end

  # --- helpers ---

  defp filter_owner(query, {:session, token}),
    do: Ash.Query.filter(query, session_token == ^token and is_nil(user_id))

  defp filter_owner(query, {:user, %{id: id}}), do: Ash.Query.filter(query, user_id == ^id)

  defp get_or_create(owner) do
    get(owner) ||
      case owner do
        {:session, token} -> Ash.create!(Basket, %{session_token: token}, authorize?: false)
        {:user, user} -> Ash.create!(Basket, %{user_id: user.id}, authorize?: false)
      end
      |> Ash.load!([items: @item_loads], authorize?: false)
  end

  defp fetch_variant(variant_id) do
    case Catalog.get_variant(variant_id, load: [product: [:tax_class, options: :choices]]) do
      {:ok, %{active: true, product: %{state: :active}} = variant} -> {:ok, variant}
      _ -> {:error, gettext("This product is not available.")}
    end
  end

  defp fetch_item(owner, item_id) do
    case get(owner) do
      nil -> {:error, gettext("Basket not found.")}
      basket -> find_item(basket, item_id)
    end
  end

  defp find_item(basket, item_id) do
    case Enum.find(basket.items, &(&1.id == item_id)) do
      nil -> {:error, gettext("Item not found.")}
      item -> {:ok, item}
    end
  end

  defp parse_quantity(quantity, unit) do
    with {decimal, ""} <- Decimal.parse(String.replace(to_string(quantity), ",", ".")),
         true <- Decimal.gt?(decimal, 0) do
      if Unit.decimals?(unit) or Decimal.integer?(decimal),
        do: {:ok, decimal},
        else: {:error, gettext("Please enter a whole number.")}
    else
      _ -> {:error, gettext("Please enter a quantity greater than zero.")}
    end
  end

  # configurable products: validate the selections, normalise them and get the
  # configuration number; other products have no configuration
  defp configuration(%{kind: :configurable} = product, selections) do
    case Configurator.quote(product, selections, 1) do
      {:ok, quote} -> {:ok, quote.selections, quote.config_number}
      {:error, _errors} -> {:error, gettext("Please check the configuration.")}
    end
  end

  defp configuration(_product, _selections), do: {:ok, %{}, nil}
end
