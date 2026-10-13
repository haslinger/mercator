defmodule Mercator.Catalog.Configurator do
  @moduledoc """
  Validates configurations of configurable products and calculates their
  price (catalog-design.md, section 4):

  1. every option needs a value: a valid choice key, or a number within
     min/max; dimensions are rounded up to `rounding_mm`
  2. the measure per piece follows the pricing model (m³, m², lfm or piece)
  3. billed measure = max(measure × quantity, minimum billing quantity)
  4. base amount = billed measure × base price of the chosen `:base_price` choice
  5. percent surcharges apply to the base amount, absolute surcharges and the
     cutting fee per piece
  6. a line below the minimum order value is raised to it
  7. VAT from the product's tax class, totals rounded to cents
  """

  use Gettext, backend: MercatorWeb.Gettext

  alias Mercator.Catalog.Quote
  alias Mercator.Translated

  @units %{per_volume: :m3, per_area: :m2, per_length: :lfm, per_unit: :piece}

  @doc """
  Calculates a quote. `selections` maps option keys to strings; missing
  values fall back to the option's default. Returns `{:ok, %Quote{}}` or
  `{:error, errors}` with errors as `%{option_key => message}` (key
  `"quantity"` for the quantity).
  """
  def quote(product, selections, quantity \\ 1) do
    product = Ash.load!(product, [:tax_class, options: :choices], authorize?: false, lazy?: true)

    with {:ok, quantity} <- parse_quantity(quantity),
         {:ok, values} <- resolve(product, selections) do
      {:ok, calculate(product, values, quantity)}
    end
  end

  @doc "The default configuration of a product: option key => value string."
  def defaults(product) do
    product = Ash.load!(product, [options: :choices], authorize?: false, lazy?: true)

    Map.new(product.options, fn
      %{kind: :choice} = option ->
        {option.key, default_choice(option) && default_choice(option).key}

      %{kind: :number} = option ->
        {option.key, option.default && Decimal.to_string(option.default, :normal)}
    end)
  end

  @doc """
  A configuration as text, e.g. "Holzart: Lärche, Länge: 2500 mm", in the
  given content locale. `product` needs `options: :choices` loaded.
  """
  def describe(product, selections, locale) do
    Enum.map_join(product.options, ", ", fn option ->
      value = selections[option.key]

      label =
        case option.kind do
          :choice ->
            choice = Enum.find(option.choices, &(&1.key == value))
            choice && Translated.t(choice.name, locale)

          :number ->
            "#{value} #{option.unit}"
        end

      "#{Translated.t(option.name, locale)}: #{label}"
    end)
  end

  # --- validation ---

  defp parse_quantity(quantity) do
    case Integer.parse(to_string(quantity)) do
      {n, ""} when n > 0 ->
        {:ok, n}

      _ ->
        {:error, %{"quantity" => dgettext("errors", "must be a whole number greater than zero")}}
    end
  end

  defp resolve(product, selections) do
    {values, errors} =
      Enum.reduce(product.options, {%{}, %{}}, fn option, {values, errors} ->
        case resolve_option(product, option, selections[option.key]) do
          {:ok, value} -> {Map.put(values, option.key, {option, value}), errors}
          {:error, message} -> {values, Map.put(errors, option.key, message)}
        end
      end)

    if errors == %{}, do: {:ok, values}, else: {:error, errors}
  end

  defp resolve_option(_product, %{kind: :choice} = option, value) do
    key =
      if value in [nil, ""], do: default_choice(option) && default_choice(option).key, else: value

    case Enum.find(option.choices, &(&1.key == key)) do
      nil -> {:error, dgettext("errors", "please choose")}
      choice -> {:ok, choice}
    end
  end

  defp resolve_option(product, %{kind: :number} = option, value) do
    raw =
      if value in [nil, ""],
        do: option.default && Decimal.to_string(option.default, :normal),
        else: value

    with {:ok, number} <- parse_decimal(raw),
         :ok <- check_range(number, option) do
      {:ok, round_up(number, option.role, product.rounding_mm)}
    end
  end

  defp parse_decimal(nil), do: {:error, dgettext("errors", "please enter a value")}

  defp parse_decimal(raw) do
    case Decimal.parse(String.replace(to_string(raw), ",", ".")) do
      {number, ""} -> {:ok, number}
      _ -> {:error, dgettext("errors", "please enter a number")}
    end
  end

  defp check_range(number, option) do
    cond do
      option.min && Decimal.lt?(number, option.min) ->
        {:error,
         dgettext("errors", "must be at least %{min}",
           min: Decimal.to_string(option.min, :normal)
         )}

      option.max && Decimal.gt?(number, option.max) ->
        {:error,
         dgettext("errors", "must be at most %{max}", max: Decimal.to_string(option.max, :normal))}

      true ->
        :ok
    end
  end

  defp round_up(number, role, rounding)
       when role in [:length, :width, :thickness] and is_integer(rounding) do
    number |> Decimal.div(rounding) |> Decimal.round(0, :ceiling) |> Decimal.mult(rounding)
  end

  defp round_up(number, _role, _rounding), do: number

  defp default_choice(option),
    do: Enum.find(option.choices, & &1.default) || List.first(option.choices)

  # --- calculation ---

  defp calculate(product, values, quantity) do
    measure = measure(product.pricing, values)
    total = Decimal.mult(measure, quantity)
    billed = max_decimal(total, product.min_billing_quantity || 0) |> Decimal.round(4)

    base_choice = choice_with_role(values, :base_price)
    base_price = (base_choice && base_choice.base_price) || Decimal.new(0)
    base_amount = billed |> Decimal.mult(base_price) |> Decimal.round(2)

    lines =
      [%{type: :base, name: base_choice && base_choice.name, amount: base_amount}] ++
        surcharge_lines(values, base_amount, quantity) ++
        cutting_fee_line(product.cutting_fee, quantity)

    lines = lines ++ minimum_line(sum(lines), product.min_order_value)
    net = sum(lines)
    rate = product.tax_class.rate
    vat = net |> Decimal.mult(rate) |> Decimal.div(100) |> Decimal.round(2)

    %Quote{
      quantity: quantity,
      selections: Map.new(values, fn {key, {_option, value}} -> {key, value_string(value)} end),
      measure: Decimal.round(measure, 4),
      measure_unit: @units[product.pricing],
      billed_measure: billed,
      base_price: base_price,
      lines: lines,
      net: net,
      vat: vat,
      gross: Decimal.add(net, vat),
      vat_rate: rate,
      unit_net: net |> Decimal.div(quantity) |> Decimal.round(2),
      config_number: config_number(product.number, values)
    }
  end

  defp measure(:per_volume, values),
    do: dimension_product(values, [:length, :width, :thickness], 1_000_000_000)

  defp measure(:per_area, values), do: dimension_product(values, [:length, :width], 1_000_000)
  defp measure(:per_length, values), do: dimension_product(values, [:length], 1000)
  defp measure(_per_unit, _values), do: Decimal.new(1)

  # dimensions are in mm; divisor converts to m³, m² or m
  defp dimension_product(values, roles, divisor) do
    roles
    |> Enum.map(&(dimension(values, &1) || Decimal.new(0)))
    |> Enum.reduce(Decimal.new(1), &Decimal.mult/2)
    |> Decimal.div(divisor)
  end

  defp dimension(values, role) do
    Enum.find_value(values, fn
      {_key, {%{role: ^role}, %Decimal{} = number}} -> number
      _ -> nil
    end)
  end

  defp choice_with_role(values, role) do
    Enum.find_value(values, fn
      {_key, {%{role: ^role}, choice}} -> choice
      _ -> nil
    end)
  end

  defp surcharge_lines(values, base_amount, quantity) do
    values
    |> Enum.sort_by(fn {_key, {option, _}} -> option.position end)
    |> Enum.flat_map(fn
      {_key, {%{role: :surcharge}, choice}} -> surcharge(choice, base_amount, quantity)
      _ -> []
    end)
  end

  defp surcharge(choice, base_amount, quantity) do
    percent =
      if nonzero?(choice.surcharge_percent),
        do:
          base_amount
          |> Decimal.mult(choice.surcharge_percent)
          |> Decimal.div(100)
          |> Decimal.round(2)

    absolute =
      if nonzero?(choice.surcharge_amount), do: Decimal.mult(choice.surcharge_amount, quantity)

    case [percent, absolute] |> Enum.reject(&is_nil/1) do
      [] ->
        []

      amounts ->
        [%{type: :surcharge, name: choice.name, amount: Enum.reduce(amounts, &Decimal.add/2)}]
    end
  end

  defp cutting_fee_line(fee, quantity) do
    if nonzero?(fee),
      do: [%{type: :cutting_fee, name: nil, amount: Decimal.mult(fee, quantity)}],
      else: []
  end

  defp minimum_line(subtotal, minimum) do
    if minimum && Decimal.lt?(subtotal, minimum),
      do: [%{type: :minimum, name: nil, amount: Decimal.sub(minimum, subtotal)}],
      else: []
  end

  defp sum(lines),
    do:
      lines
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      |> Decimal.round(2)

  defp max_decimal(a, b), do: if(Decimal.compare(a, b) == :lt, do: Decimal.new(b), else: a)

  defp nonzero?(nil), do: false
  defp nonzero?(decimal), do: not Decimal.eq?(decimal, 0)

  defp value_string(%Decimal{} = number),
    do: number |> Decimal.normalize() |> Decimal.to_string(:normal)

  defp value_string(choice), do: choice.key

  # product number plus a short, stable hash of the configuration
  defp config_number(number, values) do
    canonical =
      values
      |> Enum.map(fn {key, {_option, value}} -> "#{key}=#{value_string(value)}" end)
      |> Enum.sort()
      |> Enum.join(";")

    hash = :crypto.hash(:sha256, canonical) |> Base.encode16() |> binary_part(0, 6)
    "#{number}-#{hash}"
  end
end
