defmodule Mercator.Countries do
  @moduledoc """
  Countries for addresses (ISO 3166-1 alpha-2 codes):

    * billing addresses: EU countries plus Switzerland and Liechtenstein
    * delivery addresses: only the countries the shop delivers to, configured
      per deployment (`config :mercator, :delivery_countries`, #67)
  """
  use Gettext, backend: MercatorWeb.Gettext

  @billing ~w(AT DE IT CH LI FR BE NL LU DK SE FI IE ES PT PL CZ SK SI HU HR RO BG GR CY MT EE LV LT)

  @doc "Country codes allowed for billing addresses."
  def billing, do: @billing

  @doc "Country codes the shop delivers to."
  def delivery, do: Application.get_env(:mercator, :delivery_countries, ~w(AT))

  @doc "Postcode format per country; nil means any non-empty postcode."
  def postcode_format("AT"), do: ~r/^\d{4}$/
  def postcode_format(code) when code in ~w(DE IT FR ES FI EE HR), do: ~r/^\d{5}$/
  def postcode_format("CH"), do: ~r/^\d{4}$/
  def postcode_format("LI"), do: ~r/^\d{4}$/
  def postcode_format(_code), do: nil

  @doc "The translated name of a country."
  def name("AT"), do: gettext("Austria")
  def name("DE"), do: gettext("Germany")
  def name("IT"), do: gettext("Italy")
  def name("CH"), do: gettext("Switzerland")
  def name("LI"), do: gettext("Liechtenstein")
  def name("FR"), do: gettext("France")
  def name("BE"), do: gettext("Belgium")
  def name("NL"), do: gettext("Netherlands")
  def name("LU"), do: gettext("Luxembourg")
  def name("DK"), do: gettext("Denmark")
  def name("SE"), do: gettext("Sweden")
  def name("FI"), do: gettext("Finland")
  def name("IE"), do: gettext("Ireland")
  def name("ES"), do: gettext("Spain")
  def name("PT"), do: gettext("Portugal")
  def name("PL"), do: gettext("Poland")
  def name("CZ"), do: gettext("Czechia")
  def name("SK"), do: gettext("Slovakia")
  def name("SI"), do: gettext("Slovenia")
  def name("HU"), do: gettext("Hungary")
  def name("HR"), do: gettext("Croatia")
  def name("RO"), do: gettext("Romania")
  def name("BG"), do: gettext("Bulgaria")
  def name("GR"), do: gettext("Greece")
  def name("CY"), do: gettext("Cyprus")
  def name("MT"), do: gettext("Malta")
  def name("EE"), do: gettext("Estonia")
  def name("LV"), do: gettext("Latvia")
  def name("LT"), do: gettext("Lithuania")
  def name(code), do: code

  @doc "Options `{name, code}` for a select, sorted by name."
  def options(codes), do: codes |> Enum.map(&{name(&1), &1}) |> Enum.sort()
end
