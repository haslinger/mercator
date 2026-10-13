defmodule Mercator.Seeds.BiberHolz do
  @moduledoc """
  Demo catalogue of the fictional Biber Holz (decision #41): 8 top
  categories, 32 subcategories and about 85 products, "from the timber
  house down to sawdust". Prices are invented but plausible Austrian net
  prices; VAT classes follow the Wirtschaftskammer information (#51).

  Idempotent: categories are matched by slug, products by number. Existing
  records are left untouched. Configurable products follow in a later step.
  """

  alias Mercator.Catalog

  require Ash.Query

  @pricing_fields [:pricing, :rounding_mm, :cutting_fee, :min_billing_quantity, :min_order_value]

  # --- Entry point --------------------------------------------------------------

  @doc "Seeds the demo catalogue. Needs the tax classes `standard` and `reduced`."
  def run do
    tax = %{
      standard: Catalog.get_tax_class_by_key!("standard", authorize?: false).id,
      reduced: Catalog.get_tax_class_by_key!("reduced", authorize?: false).id
    }

    categories = ensure_categories()
    properties = ensure_properties()

    for spec <- products(), do: ensure_product(spec, categories, properties, tax)
    for relation <- relations(), do: ensure_relation(relation)

    :ok
  end

  # --- Helpers for the data below ----------------------------------------------

  defp t(de, en), do: %{"de" => de, "en" => en}

  defp delivery(:stock), do: t("sofort lieferbar", "in stock")
  defp delivery(:week), do: t("1–2 Wochen", "1–2 weeks")
  defp delivery(:order), do: t("auf Bestellung, 4–6 Wochen", "made to order, 4–6 weeks")
  defp delivery(:season), do: t("lieferbar ab 1. Dezember", "available from 1 December")

  # net price of a piece of timber from a price per m³ and its dimensions in mm
  defp per_m3(price_m3, width, height, length) do
    price_m3
    |> Decimal.new()
    |> Decimal.mult(width * height * length)
    |> Decimal.div(1_000_000_000)
    |> Decimal.round(2)
  end

  # net price of a piece from a price per running metre and its length in mm
  defp per_lfm(price_lfm, length) do
    price_lfm |> Decimal.new() |> Decimal.mult(length) |> Decimal.div(1000) |> Decimal.round(2)
  end

  defp species(:spruce), do: t("Fichte", "Spruce")
  defp species(:larch), do: t("Lärche", "Larch")
  defp species(:douglas), do: t("Douglasie", "Douglas fir")
  defp species(:oak), do: t("Eiche", "Oak")
  defp species(:walnut), do: t("Nuss", "Walnut")
  defp species(:stone_pine), do: t("Zirbe", "Swiss stone pine")
  defp species(:beech), do: t("Buche", "Beech")
  defp species(:ash), do: t("Thermo-Esche", "Thermo ash")
  defp species(:mixed), do: t("Hartholz-Mischung", "Mixed hardwood")
  defp species(:cherry), do: t("Kirsche", "Cherry")
  defp species(:fir), do: t("Nordmanntanne", "Nordmann fir")
  defp species(:blue_spruce), do: t("Blaufichte", "Blue spruce")

  # --- Categories ---------------------------------------------------------------

  defp categories do
    [
      {"holzhaeuser-bausaetze", t("Holzhäuser & Bausätze", "Timber houses & kits"),
       t(
         "Vom Gerätehaus bis zum Blockhaus – aus eigenem Alpenholz.",
         "From tool sheds to log houses – made from our own alpine timber."
       ),
       [
         {"blockhaeuser", t("Blockhäuser", "Log houses")},
         {"gartenhaeuser", t("Gartenhäuser", "Garden houses")},
         {"carports-pergolen", t("Carports & Pergolen", "Carports & pergolas")},
         {"saunahaeuser", t("Saunahäuser", "Sauna houses")}
       ]},
      {"bauholz", t("Bauholz", "Construction timber"),
       t(
         "Tragende Hölzer für Dach, Wand und Decke.",
         "Load-bearing timber for roofs, walls and ceilings."
       ),
       [
         {"konstruktionsvollholz",
          t("Konstruktionsvollholz (KVH)", "Structural solid timber (KVH)")},
         {"brettschichtholz", t("Brettschichtholz (BSH)", "Glued laminated timber (glulam)")},
         {"kanthoelzer-balken", t("Kanthölzer & Balken", "Squared timber & beams")},
         {"latten-staffeln", t("Latten & Staffeln", "Battens & laths")}
       ]},
      {"platten-bretter", t("Platten & Bretter", "Panels & boards"),
       t("Für Innenausbau, Schalung und Boden.", "For interior finishing, sheathing and floors."),
       [
         {"dreischichtplatten", t("3-Schicht-Platten", "Three-layer panels")},
         {"rauspund-schalung", t("Rauspund & Schalung", "Tongue & groove sheathing")},
         {"hobeldielen", t("Hobeldielen", "Planed floorboards")},
         {"leimholzplatten", t("Leimholzplatten", "Glued wood panels")}
       ]},
      {"terrasse-fassade-garten", t("Terrasse, Fassade & Garten", "Decking, cladding & garden"),
       t("Wetterfeste Hölzer für draußen.", "Weatherproof timber for outdoors."),
       [
         {"terrassendielen", t("Terrassendielen", "Decking boards")},
         {"fassadenschalung", t("Fassadenschalung", "Facade cladding")},
         {"zaeune-sichtschutz", t("Zäune & Sichtschutz", "Fences & privacy screens")},
         {"hochbeete", t("Hochbeete & Pflanzkästen", "Raised beds & planters")}
       ]},
      {"edelholz-tischplatten", t("Edelholz & Tischplatten", "Fine wood & table tops"),
       t(
         "Ausgesuchte Edelhölzer für Möbelbau und Tischlerei.",
         "Selected fine woods for furniture making and joinery."
       ),
       [
         {"eiche", t("Eiche", "Oak")},
         {"nuss", t("Nuss", "Walnut")},
         {"zirbe", t("Zirbe", "Swiss stone pine")},
         {"tischplatten", t("Tischplatten", "Table tops")}
       ]},
      {"moebel-wohnen", t("Möbel & Wohnen", "Furniture & living"),
       t(
         "Massivholzmöbel aus der eigenen Tischlerei.",
         "Solid wood furniture from our own joinery."
       ),
       [
         {"zirbenbetten", t("Zirbenbetten", "Stone pine beds")},
         {"tische-baenke", t("Tische & Bänke", "Tables & benches")},
         {"hocker-garderoben", t("Hocker & Garderoben", "Stools & coat racks")},
         {"kuechenhelfer",
          t("Küchenhelfer & Wohnaccessoires", "Kitchen helpers & home accessories")}
       ]},
      {"brennholz-energie", t("Brennholz & Energie", "Firewood & energy"),
       t(
         "Heizen mit Holz aus nachhaltiger Forstwirtschaft – bis zum letzten Span.",
         "Heating with wood from sustainable forestry – down to the last shaving."
       ),
       [
         {"scheitholz", t("Scheitholz", "Split logs")},
         {"pellets", t("Pellets", "Pellets")},
         {"briketts", t("Briketts", "Briquettes")},
         {"hackschnitzel", t("Hackschnitzel", "Wood chips")},
         {"spaene", t("Säge- & Hobelspäne", "Sawdust & shavings")}
       ]},
      {"forst-rundholz", t("Forst & Rundholz", "Forestry & round timber"),
       t(
         "Direkt aus unseren Wäldern in den Tiroler Alpen.",
         "Straight from our forests in the Tyrolean Alps."
       ),
       [
         {"rundholz", t("Rundholz", "Round timber")},
         {"christbaeume", t("Christbäume", "Christmas trees")},
         {"dienstleistungen", t("Dienstleistungen", "Services")}
       ]}
    ]
  end

  defp ensure_categories do
    categories()
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {{slug, name, description, children}, position} ->
      parent =
        ensure_category(%{slug: slug, name: name, description: description, position: position})

      children
      |> Enum.with_index(1)
      |> Enum.map(fn {{child_slug, child_name}, child_position} ->
        ensure_category(%{
          slug: child_slug,
          name: child_name,
          position: child_position,
          parent_id: parent.id
        })
      end)
      |> then(&[parent | &1])
    end)
    |> Map.new(&{&1.slug, &1})
  end

  defp ensure_category(%{slug: slug} = attrs) do
    case Catalog.get_category_by_slug(slug, authorize?: false) do
      {:ok, category} ->
        category

      {:error, _} ->
        attrs
        |> Catalog.create_category!(authorize?: false)
        |> Catalog.activate_category!(authorize?: false)
    end
  end

  # --- Properties ---------------------------------------------------------------

  defp groups,
    do: [
      wood: {t("Holz", "Wood"), 1},
      dimensions: {t("Abmessungen", "Dimensions"), 2},
      surface: {t("Oberfläche & Qualität", "Surface & quality"), 3},
      energy: {t("Brennstoff", "Fuel"), 4}
    ]

  defp properties,
    do: [
      species: {:wood, t("Holzart", "Wood species"), :text, nil, true},
      origin: {:wood, t("Herkunft", "Origin"), :text, nil, false},
      drying: {:wood, t("Trocknung", "Drying"), :text, nil, true},
      grade: {:wood, t("Festigkeitsklasse", "Strength class"), :text, nil, true},
      thickness: {:dimensions, t("Stärke", "Thickness"), :number, "mm", true},
      width: {:dimensions, t("Breite", "Width"), :number, "mm", false},
      length: {:dimensions, t("Länge", "Length"), :number, "mm", false},
      floor_area: {:dimensions, t("Grundfläche", "Floor area"), :number, "m²", false},
      wall: {:dimensions, t("Wandstärke", "Wall thickness"), :number, "mm", false},
      surface: {:surface, t("Oberfläche", "Surface"), :text, nil, true},
      treated: {:surface, t("Imprägniert", "Impregnated"), :boolean, nil, false},
      calorific: {:energy, t("Heizwert", "Calorific value"), :number, "kWh/kg", false},
      moisture: {:energy, t("Wassergehalt", "Moisture content"), :number, "%", false}
    ]

  defp ensure_properties do
    existing_groups = Catalog.list_property_groups!(authorize?: false)

    groups =
      Map.new(groups(), fn {key, {name, position}} ->
        group =
          Enum.find(existing_groups, &(&1.name["de"] == name["de"])) ||
            Catalog.create_property_group!(%{name: name, position: position}, authorize?: false)

        {key, group}
      end)

    existing = Catalog.list_properties!(authorize?: false)

    properties()
    |> Enum.with_index(1)
    |> Map.new(fn {{key, {group, name, kind, unit, filterable}}, position} ->
      property =
        Enum.find(existing, &(&1.name["de"] == name["de"])) ||
          Catalog.create_property!(
            %{
              name: name,
              kind: kind,
              unit: unit,
              filterable: filterable,
              position: position,
              property_group_id: groups[group].id
            },
            authorize?: false
          )

      {key, property}
    end)
  end

  # --- Products -----------------------------------------------------------------

  defp ensure_product(spec, categories, properties, tax) do
    case Catalog.get_product_by_number(spec.number, authorize?: false) do
      {:ok, product} -> product
      {:error, _} -> create_product(spec, categories, properties, tax)
    end
  end

  defp create_product(spec, categories, properties, tax) do
    variants = variant_specs(spec)
    product = Catalog.create_product!(product_attrs(spec, variants, tax), authorize?: false)

    variants
    |> Enum.with_index()
    |> Enum.each(fn {variant, position} -> create_variant(product, variant, position) end)

    for {option, position} <- Enum.with_index((spec[:configurable] || %{})[:options] || [], 1) do
      create_option(product, option, position)
    end

    for slug <- List.wrap(spec.category) do
      Catalog.categorize!(categories[slug].id, product.id, authorize?: false)
    end

    for {key, value} <- spec[:properties] || [] do
      Catalog.set_product_property!(property_value(product, properties[key], value),
        authorize?: false
      )
    end

    Catalog.activate_product!(product, authorize?: false)
  end

  # A product without explicit variants gets one variant from its own price data.
  defp variant_specs(%{variants: variants}), do: variants

  defp variant_specs(%{configurable: _} = spec),
    do: [%{suffix: "1", price: nil, delivery: spec[:delivery]}]

  defp variant_specs(spec) do
    [
      Map.merge(
        %{suffix: "1"},
        Map.take(spec, [:price, :unit, :stock, :delivery, :tiers, :promo, :weight])
      )
    ]
  end

  defp product_attrs(spec, variants, tax) do
    defaults = %{highlights: [], tax: :standard, shipping: :parcel, new: false, bestseller: false}
    spec = Map.merge(defaults, spec)

    %{
      number: spec.number,
      title: spec.title,
      subtitle: spec[:subtitle],
      description: spec[:description],
      highlights: spec.highlights,
      kind: kind(spec, variants),
      tax_class_id: tax[spec.tax],
      shipping: spec.shipping,
      new_arrival: spec.new,
      bestseller: spec.bestseller
    }
    |> Map.merge(Map.take(spec[:configurable] || %{}, @pricing_fields))
  end

  defp kind(%{configurable: _}, _variants), do: :configurable
  defp kind(_spec, variants) when length(variants) > 1, do: :variants
  defp kind(_spec, _variants), do: :simple

  defp create_variant(product, spec, position) do
    variant =
      Catalog.create_variant!(
        %{
          product_id: product.id,
          number: "#{product.number}-#{spec.suffix}",
          name: spec[:name],
          options: spec[:options] || %{},
          unit: spec[:unit] || :piece,
          stock: spec[:stock],
          delivery_time: delivery(spec[:delivery] || :stock),
          weight_kg: spec[:weight],
          position: position
        },
        authorize?: false
      )

    prices =
      if(spec.price, do: [%{amount: spec.price, min_quantity: 1}], else: []) ++
        for({min, amount} <- spec[:tiers] || [], do: %{amount: amount, min_quantity: min}) ++
        if(spec[:promo], do: [%{amount: spec.promo, promotion: true}], else: [])

    for price <- prices do
      price
      |> Map.update!(:amount, &to_string/1)
      |> Map.put(:variant_id, variant.id)
      |> Catalog.create_price!(authorize?: false)
    end
  end

  # {key, name, :choice, role, [{key, name, attrs}]} or {key, name, :number, role, attrs}
  defp create_option(product, {key, name, :choice, role, choices}, position) do
    option =
      Catalog.create_product_option!(
        %{
          product_id: product.id,
          key: key,
          name: name,
          kind: :choice,
          role: role,
          position: position
        },
        authorize?: false
      )

    for {{choice_key, choice_name, attrs}, choice_position} <- Enum.with_index(choices, 1) do
      attrs
      |> Map.new(fn {k, v} -> {k, if(is_boolean(v), do: v, else: to_string(v))} end)
      |> Map.merge(%{
        option_id: option.id,
        key: choice_key,
        name: choice_name,
        position: choice_position
      })
      |> Map.put_new(:default, choice_position == 1)
      |> Catalog.create_option_choice!(authorize?: false)
    end
  end

  defp create_option(product, {key, name, :number, role, attrs}, position) do
    attrs
    |> Map.new(fn {k, v} -> {k, to_string(v)} end)
    |> Map.merge(%{
      product_id: product.id,
      key: key,
      name: name,
      kind: :number,
      role: role,
      position: position,
      unit: "mm"
    })
    |> Catalog.create_product_option!(authorize?: false)
  end

  defp property_value(product, property, value) do
    base = %{product_id: product.id, property_id: property.id}

    case property.kind do
      :text when is_atom(value) -> Map.put(base, :text_value, species(value))
      :text -> Map.put(base, :text_value, value)
      :number -> Map.put(base, :number_value, to_string(value))
      :boolean -> Map.put(base, :boolean_value, value)
    end
  end

  # --- Relations ----------------------------------------------------------------

  defp relations do
    [
      {"BH-TD-LAE", "BH-TD-SCHRAUBEN", :accessory, nil},
      {"BH-TD-LAE", "BH-TD-UK-LAE", :accessory, nil},
      {"BH-TD-DOU", "BH-TD-SCHRAUBEN", :accessory, nil},
      {"BH-TD-DOU", "BH-TD-UK-LAE", :accessory, nil},
      {"BH-TD-THE", "BH-TD-SCHRAUBEN", :accessory, nil},
      {"BH-TD-LAE", "BH-OEL-TERRASSE", :recommended,
       t("Schützt die Lärche vor dem Vergrauen", "Keeps larch from turning grey")},
      {"BH-TD-LAE", "BH-TD-DOU", :related, nil},
      {"BH-TD-DOU", "BH-TD-LAE", :related, nil},
      {"BH-GH-ALM", "BH-OEL-TERRASSE", :recommended,
       t("Für einen langlebigen Holzschutz", "For long-lasting wood protection")},
      {"BH-BETT-ZIRBE", "BH-ZIRBENKISSEN", :recommended,
       t("Zirbenduft für noch besseren Schlaf", "Stone pine scent for even better sleep")},
      {"BH-SCHEIT-BUCHE", "BH-ANZUENDHOLZ", :accessory, nil},
      {"BH-SCHEIT-FICHTE", "BH-ANZUENDHOLZ", :accessory, nil},
      {"BH-PELLETS-SACK", "BH-PELLETS-LOSE", :related, nil},
      {"BH-KVH-FI", "BH-BSH-FI", :related, nil},
      {"BH-TISCH-EICHE", "BH-BANK-EICHE", :recommended,
       t("Passende Bank aus demselben Stamm", "Matching bench from the same log")}
    ]
  end

  defp ensure_relation({number, related_number, kind, reason}) do
    product = Catalog.get_product_by_number!(number, authorize?: false)
    related = Catalog.get_product_by_number!(related_number, authorize?: false)

    exists? =
      Mercator.Catalog.ProductRelation
      |> Ash.Query.filter(
        product_id == ^product.id and related_product_id == ^related.id and kind == ^kind
      )
      |> Ash.exists?(authorize?: false)

    unless exists? do
      Catalog.relate_products!(
        %{product_id: product.id, related_product_id: related.id, kind: kind, reason: reason},
        authorize?: false
      )
    end
  end

  # --- Product data -------------------------------------------------------------

  @doc false
  def products do
    made_to_measure() ++
      houses() ++
      construction_timber() ++
      panels() ++ outdoor() ++ fine_wood() ++ furniture() ++ energy() ++ forestry()
  end

  # Configurable products (#55): cut to size, price calculated by the configurator
  defp made_to_measure do
    length = fn min, max, default ->
      {"length", t("Länge", "Length"), :number, :length,
       %{min: min, max: max, default: default, step: 10}}
    end

    width = fn min, max, default ->
      {"width", t("Breite", "Width"), :number, :width,
       %{min: min, max: max, default: default, step: 10}}
    end

    [
      %{
        number: "BH-KVH-MASS",
        category: ["konstruktionsvollholz", "kanthoelzer-balken"],
        title: t("Konstruktionsholz nach Maß", "Structural timber cut to size"),
        subtitle:
          t(
            "Holzart, Querschnitt und Länge frei wählbar",
            "Choose species, cross-section and length"
          ),
        description:
          t(
            "Aus unserem Sägewerk auf den Millimeter zugeschnitten – abgerechnet nach Kubikmeter.",
            "Cut to the millimetre in our sawmill – priced per cubic metre."
          ),
        highlights: [
          t("Zuschnitt auf ganze Zentimeter", "Cut to whole centimetres"),
          t("Ab 0,05 m³", "From 0.05 m³")
        ],
        new: true,
        shipping: :freight,
        delivery: :week,
        configurable: %{
          pricing: :per_volume,
          rounding_mm: 10,
          cutting_fee: "2.50",
          min_billing_quantity: "0.05",
          options: [
            {"species", t("Holzart", "Wood species"), :choice, :base_price,
             [
               {"spruce", species(:spruce), %{base_price: 560}},
               {"larch", species(:larch), %{base_price: 920}},
               {"douglas", species(:douglas), %{base_price: 740}},
               {"oak", species(:oak), %{base_price: 1650}}
             ]},
            {"surface", t("Oberfläche", "Surface"), :choice, :surcharge,
             [
               {"rough", t("sägerau", "rough-sawn"), %{}},
               {"planed", t("gehobelt", "planed"), %{surcharge_percent: 15}},
               {"chamfered", t("gehobelt und gefast", "planed and chamfered"),
                %{surcharge_percent: 20}}
             ]},
            {"drying", t("Trocknung", "Drying"), :choice, :surcharge,
             [
               {"fresh", t("frisch", "fresh"), %{}},
               {"kiln", t("technisch getrocknet", "kiln-dried"), %{surcharge_percent: 12}}
             ]},
            length.(500, 13_000, 4000),
            width.(40, 300, 100),
            {"height", t("Höhe", "Height"), :number, :thickness,
             %{min: 40, max: 300, default: 120, step: 10}}
          ]
        }
      },
      %{
        number: "BH-TISCHPLATTE-MASS",
        category: ["tischplatten", "eiche", "nuss"],
        title: t("Tischplatte nach Maß", "Table top made to measure"),
        subtitle: t("Massivholz aus unserer Tischlerei", "Solid wood from our joinery"),
        description:
          t(
            "Wählen Sie Holzart, Maße, Stärke, Kante und Oberfläche – wir fertigen Ihre Tischplatte.",
            "Choose species, size, thickness, edge and finish – we make your table top."
          ),
        bestseller: true,
        shipping: :freight,
        delivery: :order,
        configurable: %{
          pricing: :per_area,
          rounding_mm: 10,
          min_order_value: "150",
          options: [
            {"species", t("Holzart", "Wood species"), :choice, :base_price,
             [
               {"oak", species(:oak), %{base_price: 320}},
               {"walnut", species(:walnut), %{base_price: 520}},
               {"stone_pine", species(:stone_pine), %{base_price: 280}},
               {"cherry", species(:cherry), %{base_price: 360}}
             ]},
            {"thickness", t("Stärke", "Thickness"), :choice, :surcharge,
             [
               {"30", t("30 mm", "30 mm"), %{}},
               {"40", t("40 mm", "40 mm"), %{surcharge_percent: 25}},
               {"50", t("50 mm", "50 mm"), %{surcharge_percent: 45}}
             ]},
            {"edge", t("Kante", "Edge"), :choice, :surcharge,
             [
               {"straight", t("gerade", "straight"), %{}},
               {"bevel", t("Facette", "bevelled"), %{surcharge_amount: 35}},
               {"live_edge", t("Baumkante", "live edge"), %{surcharge_amount: 90}}
             ]},
            {"finish", t("Oberfläche", "Finish"), :choice, :surcharge,
             [
               {"oiled", t("natur geölt", "natural oil"), %{}},
               {"white_oil", t("weiß geölt", "white oil"), %{surcharge_percent: 8}},
               {"lacquered", t("matt lackiert", "matt lacquer"), %{surcharge_percent: 12}}
             ]},
            length.(600, 3000, 1800),
            width.(400, 1200, 900)
          ]
        }
      },
      %{
        number: "BH-3S-ZUSCHNITT",
        category: "dreischichtplatten",
        title: t("3-Schicht-Platte Zuschnitt", "Three-layer panel cut to size"),
        description:
          t(
            "Massivholzplatte auf Ihr Maß zugeschnitten, ideal für Möbel und Regale.",
            "Solid wood panel cut to your size, ideal for furniture and shelves."
          ),
        shipping: :parcel,
        delivery: :week,
        configurable: %{
          pricing: :per_area,
          rounding_mm: 1,
          cutting_fee: "3.00",
          min_billing_quantity: "0.25",
          options: [
            {"species", t("Holzart", "Wood species"), :choice, :base_price,
             [
               {"spruce", species(:spruce), %{base_price: 42}},
               {"larch", species(:larch), %{base_price: 68}},
               {"stone_pine", species(:stone_pine), %{base_price: 95}}
             ]},
            {"thickness", t("Stärke", "Thickness"), :choice, :surcharge,
             [
               {"19", t("19 mm", "19 mm"), %{}},
               {"27", t("27 mm", "27 mm"), %{surcharge_percent: 18}},
               {"42", t("42 mm", "42 mm"), %{surcharge_percent: 45}}
             ]},
            {"length", t("Länge", "Length"), :number, :length,
             %{min: 200, max: 5000, default: 1000, step: 1}},
            {"width", t("Breite", "Width"), :number, :width,
             %{min: 100, max: 2050, default: 600, step: 1}}
          ]
        }
      },
      %{
        number: "BH-LEISTEN-MASS",
        category: "latten-staffeln",
        title: t("Latten & Leisten nach Maß", "Battens and strips cut to length"),
        description:
          t(
            "Gehobelte Latten in Standardprofilen, auf Länge geschnitten.",
            "Planed battens in standard profiles, cut to length."
          ),
        delivery: :stock,
        configurable: %{
          pricing: :per_length,
          rounding_mm: 10,
          cutting_fee: "0.80",
          options: [
            {"profile", t("Profil", "Profile"), :choice, :base_price,
             [
               {"24x48", t("24 × 48 mm", "24 × 48 mm"), %{base_price: "0.95"}},
               {"30x50", t("30 × 50 mm", "30 × 50 mm"), %{base_price: "1.10"}},
               {"40x60", t("40 × 60 mm", "40 × 60 mm"), %{base_price: "1.60"}},
               {"50x80", t("50 × 80 mm", "50 × 80 mm"), %{base_price: "2.40"}}
             ]},
            {"species", t("Holzart", "Wood species"), :choice, :surcharge,
             [
               {"spruce", species(:spruce), %{}},
               {"larch", species(:larch), %{surcharge_percent: 70}}
             ]},
            length.(500, 6000, 3000)
          ]
        }
      }
    ]
  end

  defp houses do
    [
      %{
        number: "BH-BLOCK-TIROL",
        category: "blockhaeuser",
        title: t("Blockhaus „Tirol“", "Log house “Tirol”"),
        subtitle:
          t(
            "Wohnblockhaus 5 × 4 m, Wandstärke 70 mm",
            "Residential log house 5 × 4 m, 70 mm walls"
          ),
        description:
          t(
            "Massives Blockhaus aus Fichte mit doppelter Nut und Feder – als Bausatz oder schlüsselfertig.",
            "Solid spruce log house with double tongue and groove – as a kit or turnkey."
          ),
        highlights: [
          t("Eigenes Alpenholz", "Our own alpine timber"),
          t("Inklusive Statik", "Structural calculation included")
        ],
        shipping: :freight,
        properties: [species: :spruce, wall: 70, floor_area: 20],
        variants: [
          %{
            suffix: "BAUSATZ",
            name: t("Bausatz", "Kit"),
            options: %{"version" => "kit"},
            price: "18900",
            delivery: :order,
            weight: 6800
          },
          %{
            suffix: "MONTIERT",
            name: t("Montiert", "Assembled"),
            options: %{"version" => "assembled"},
            price: "26900",
            delivery: :order,
            weight: 6800
          }
        ]
      },
      %{
        number: "BH-BLOCK-ALPENBLICK",
        category: "blockhaeuser",
        title: t("Blockhaus „Alpenblick“", "Log house “Alpenblick”"),
        subtitle: t("Ferienhaus 8 × 6 m mit Galerie", "Holiday home 8 × 6 m with gallery"),
        description:
          t(
            "Großzügiges Ferienhaus mit überdachter Terrasse und Galerie, Wandstärke 95 mm.",
            "Spacious holiday home with covered terrace and gallery, 95 mm walls."
          ),
        shipping: :freight,
        new: true,
        properties: [species: :spruce, wall: 95, floor_area: 48],
        price: "49900",
        delivery: :order,
        weight: 18_500
      },
      %{
        number: "BH-GH-ALM",
        category: "gartenhaeuser",
        title: t("Gartenhaus „Almhütte“", "Garden house “Almhütte”"),
        description:
          t(
            "Rustikales Gartenhaus mit Satteldach und Vordach, Wandstärke 44 mm.",
            "Rustic garden house with gable roof and canopy, 44 mm walls."
          ),
        highlights: [t("Fenster und Doppeltür inklusive", "Window and double door included")],
        shipping: :freight,
        bestseller: true,
        properties: [species: :spruce, wall: 44],
        variants: [
          %{
            suffix: "3X3",
            name: t("3 × 3 m", "3 × 3 m"),
            options: %{"size" => "3 × 3 m"},
            price: "3290",
            delivery: :week,
            weight: 950
          },
          %{
            suffix: "3X4",
            name: t("3 × 4 m", "3 × 4 m"),
            options: %{"size" => "3 × 4 m"},
            price: "3890",
            delivery: :week,
            weight: 1180
          },
          %{
            suffix: "4X4",
            name: t("4 × 4 m", "4 × 4 m"),
            options: %{"size" => "4 × 4 m"},
            price: "4690",
            delivery: :order,
            weight: 1450
          }
        ]
      },
      %{
        number: "BH-GH-KOMPAKT",
        category: "gartenhaeuser",
        title: t("Gerätehaus „Kompakt“", "Tool shed “Kompakt”"),
        description:
          t(
            "Kleines Gerätehaus mit Pultdach für Rasenmäher und Werkzeug.",
            "Small tool shed with pent roof for mower and tools."
          ),
        shipping: :freight,
        properties: [species: :spruce, wall: 19, floor_area: 4],
        price: "1290",
        promo: "1090",
        delivery: :stock,
        stock: 6,
        weight: 320
      },
      %{
        number: "BH-CARPORT",
        category: "carports-pergolen",
        title: t("Carport Lärche", "Larch carport"),
        description:
          t(
            "Freistehender Carport aus Brettschichtholz Lärche mit Flachdach.",
            "Free-standing carport made of larch glulam with flat roof."
          ),
        shipping: :freight,
        properties: [species: :larch],
        variants: [
          %{
            suffix: "EINZEL",
            name: t("Einzelcarport 3 × 5 m", "Single carport 3 × 5 m"),
            options: %{"size" => "3 × 5 m"},
            price: "2490",
            delivery: :week
          },
          %{
            suffix: "DOPPEL",
            name: t("Doppelcarport 6 × 5 m", "Double carport 6 × 5 m"),
            options: %{"size" => "6 × 5 m"},
            price: "3990",
            delivery: :week
          }
        ]
      },
      %{
        number: "BH-PERGOLA",
        category: "carports-pergolen",
        title: t("Pergola Lärche 3 × 3 m", "Larch pergola 3 × 3 m"),
        description:
          t(
            "Pergola aus Lärche, ideal für Kletterpflanzen.",
            "Larch pergola, ideal for climbing plants."
          ),
        shipping: :freight,
        properties: [species: :larch],
        price: "1690",
        delivery: :week
      },
      %{
        number: "BH-SAUNA-FASS",
        category: "saunahaeuser",
        title: t("Fass-Sauna Thermoholz", "Barrel sauna thermo wood"),
        subtitle: t("2,4 m, für 4 Personen", "2.4 m, for 4 people"),
        description:
          t(
            "Fass-Sauna aus thermisch behandeltem Holz mit Holzofen.",
            "Barrel sauna made of thermally treated wood with wood-fired stove."
          ),
        shipping: :freight,
        new: true,
        properties: [species: :ash],
        price: "6900",
        delivery: :order
      },
      %{
        number: "BH-SAUNA-ZIRBE",
        category: "saunahaeuser",
        title: t("Saunahaus „Zirbenstube“", "Sauna house “Zirbenstube”"),
        subtitle: t("2,5 × 2,5 m mit Vorraum", "2.5 × 2.5 m with anteroom"),
        description:
          t(
            "Saunahaus mit Innenverkleidung aus duftender Zirbe.",
            "Sauna house lined with fragrant Swiss stone pine."
          ),
        shipping: :freight,
        properties: [species: :stone_pine],
        price: "12900",
        delivery: :order
      }
    ]
  end

  defp construction_timber do
    kvh =
      for {w, h} <- [{60, 120}, {80, 160}, {100, 200}], len <- [5000, 7000] do
        %{
          suffix: "#{w}X#{h}-#{div(len, 1000)}M",
          name: t("#{w} × #{h} mm, #{div(len, 1000)} m", "#{w} × #{h} mm, #{div(len, 1000)} m"),
          options: %{"cross_section" => "#{w} × #{h} mm", "length_mm" => len},
          price: per_m3("520", w, h, len),
          tiers: [{10, per_m3("495", w, h, len)}],
          delivery: :stock,
          stock: 40
        }
      end

    bsh =
      for {w, h} <- [{100, 200}, {120, 240}, {140, 280}] do
        %{
          suffix: "#{w}X#{h}",
          name: t("#{w} × #{h} mm, 6 m", "#{w} × #{h} mm, 6 m"),
          options: %{"cross_section" => "#{w} × #{h} mm"},
          price: per_m3("640", w, h, 6000),
          delivery: :week
        }
      end

    [
      %{
        number: "BH-KVH-FI",
        category: "konstruktionsvollholz",
        title: t("Konstruktionsvollholz Fichte", "Structural solid timber spruce"),
        description:
          t(
            "Keilgezinktes, technisch getrocknetes KVH für sichtbare und nicht sichtbare Konstruktionen.",
            "Finger-jointed, kiln-dried KVH for visible and hidden structures."
          ),
        highlights: [
          t("Holzfeuchte 15 % ± 3 %", "Moisture 15 % ± 3 %"),
          t("Gehobelt und gefast", "Planed and chamfered")
        ],
        bestseller: true,
        shipping: :freight,
        properties: [
          species: :spruce,
          grade: t("C24", "C24"),
          drying: t("technisch getrocknet", "kiln-dried"),
          surface: t("gehobelt", "planed")
        ],
        variants: kvh
      },
      %{
        number: "BH-KVH-LAE",
        category: "konstruktionsvollholz",
        title: t("Konstruktionsvollholz Lärche", "Structural solid timber larch"),
        description:
          t(
            "Witterungsbeständiges KVH aus Lärche für den Außenbereich.",
            "Weather-resistant larch KVH for outdoor use."
          ),
        shipping: :freight,
        properties: [
          species: :larch,
          grade: t("C24", "C24"),
          drying: t("technisch getrocknet", "kiln-dried")
        ],
        variants: [
          %{
            suffix: "100X100-5M",
            name: t("100 × 100 mm, 5 m", "100 × 100 mm, 5 m"),
            options: %{"cross_section" => "100 × 100 mm"},
            price: per_m3("890", 100, 100, 5000),
            delivery: :week
          },
          %{
            suffix: "120X120-5M",
            name: t("120 × 120 mm, 5 m", "120 × 120 mm, 5 m"),
            options: %{"cross_section" => "120 × 120 mm"},
            price: per_m3("890", 120, 120, 5000),
            delivery: :week
          }
        ]
      },
      %{
        number: "BH-BSH-FI",
        category: "brettschichtholz",
        title: t("Brettschichtholz Fichte GL24h", "Glulam spruce GL24h"),
        description:
          t(
            "Formstabile Leimbinder für große Spannweiten.",
            "Dimensionally stable glulam beams for large spans."
          ),
        shipping: :freight,
        properties: [
          species: :spruce,
          grade: t("GL24h", "GL24h"),
          surface: t("gehobelt", "planed")
        ],
        variants: bsh
      },
      %{
        number: "BH-BSH-LAE",
        category: "brettschichtholz",
        title: t("Brettschichtholz Lärche GL24h", "Glulam larch GL24h"),
        description:
          t(
            "Leimbinder aus Lärche für Carports, Pergolen und Balkone.",
            "Larch glulam for carports, pergolas and balconies."
          ),
        shipping: :freight,
        properties: [species: :larch, grade: t("GL24h", "GL24h")],
        price: per_m3("1150", 120, 240, 6000),
        delivery: :order
      },
      %{
        number: "BH-KANT-FI",
        category: "kanthoelzer-balken",
        title: t("Kantholz Fichte sägerau", "Squared timber spruce, rough-sawn"),
        description:
          t(
            "Sägeraues Kantholz für Dachstuhl und Unterkonstruktion.",
            "Rough-sawn squared timber for roof trusses and substructures."
          ),
        shipping: :freight,
        properties: [
          species: :spruce,
          surface: t("sägerau", "rough-sawn"),
          drying: t("frisch", "fresh")
        ],
        variants:
          for {w, h} <- [{80, 80}, {100, 100}, {120, 160}] do
            %{
              suffix: "#{w}X#{h}",
              name: t("#{w} × #{h} mm, 4 m", "#{w} × #{h} mm, 4 m"),
              options: %{"cross_section" => "#{w} × #{h} mm"},
              price: per_m3("450", w, h, 4000),
              delivery: :stock,
              stock: 120
            }
          end
      },
      %{
        number: "BH-BALKEN-EICHE",
        category: "kanthoelzer-balken",
        title: t("Eichenbalken Altholz", "Reclaimed oak beam"),
        description:
          t(
            "Handbehauener Altholzbalken aus Eiche, jedes Stück ein Unikat.",
            "Hand-hewn reclaimed oak beam, every piece unique."
          ),
        shipping: :freight,
        properties: [species: :oak, surface: t("handbehauen", "hand-hewn")],
        price: "590",
        delivery: :stock,
        stock: 9
      },
      %{
        number: "BH-DACHLATTE",
        category: "latten-staffeln",
        title: t("Dachlatte Fichte 30 × 50 mm", "Roof batten spruce 30 × 50 mm"),
        description:
          t(
            "Sortierte Dachlatte nach DIN 4074, imprägniert.",
            "Graded roof batten to DIN 4074, impregnated."
          ),
        bestseller: true,
        properties: [species: :spruce, thickness: 30, width: 50, treated: true],
        variants:
          for len <- [4000, 5000] do
            %{
              suffix: "#{div(len, 1000)}M",
              name: t("#{div(len, 1000)} m", "#{div(len, 1000)} m"),
              options: %{"length_mm" => len},
              price: per_lfm("0.85", len),
              tiers: [{100, per_lfm("0.75", len)}],
              delivery: :stock,
              stock: 2000
            }
          end
      },
      %{
        number: "BH-STAFFEL",
        category: "latten-staffeln",
        title: t("Staffel Fichte 50 × 80 mm", "Lath spruce 50 × 80 mm"),
        properties: [species: :spruce, thickness: 50, width: 80],
        price: per_lfm("1.95", 4000),
        delivery: :stock,
        stock: 800
      },
      %{
        number: "BH-KONTERLATTE",
        category: "latten-staffeln",
        title: t("Konterlatte Fichte 40 × 60 mm", "Counter batten spruce 40 × 60 mm"),
        properties: [species: :spruce, thickness: 40, width: 60, treated: true],
        price: per_lfm("1.25", 4000),
        tiers: [{100, per_lfm("1.10", 4000)}],
        delivery: :stock,
        stock: 1200
      },
      %{
        number: "BH-KVH-DOU",
        category: "konstruktionsvollholz",
        title: t("Konstruktionsvollholz Douglasie", "Structural solid timber Douglas fir"),
        description:
          t(
            "Kräftig gefärbtes KVH für sichtbare Dachkonstruktionen.",
            "Richly coloured KVH for visible roof structures."
          ),
        shipping: :freight,
        new: true,
        properties: [
          species: :douglas,
          grade: t("C24", "C24"),
          drying: t("technisch getrocknet", "kiln-dried")
        ],
        price: per_m3("690", 100, 200, 6000),
        delivery: :week
      },
      %{
        number: "BH-SCHALBRETT",
        category: "rauspund-schalung",
        title: t("Schalbrett Fichte 24 mm, besäumt", "Formwork board spruce 24 mm, edged"),
        properties: [species: :spruce, thickness: 24, surface: t("sägerau", "rough-sawn")],
        unit: :m2,
        price: "11.90",
        tiers: [{50, "10.90"}],
        delivery: :stock,
        stock: 1200
      }
    ]
  end

  defp panels do
    [
      %{
        number: "BH-3S-FI",
        category: "dreischichtplatten",
        title: t("3-Schicht-Platte Fichte", "Three-layer panel spruce"),
        description:
          t(
            "Massivholzplatte für Möbel, Wand und Decke, Format 5000 × 2050 mm.",
            "Solid wood panel for furniture, walls and ceilings, 5000 × 2050 mm."
          ),
        shipping: :freight,
        properties: [
          species: :spruce,
          surface: t("geschliffen, Qualität B/C", "sanded, grade B/C")
        ],
        variants:
          for {thick, m2} <- [{19, "31.90"}, {27, "38.50"}, {42, "52.00"}] do
            %{
              suffix: "#{thick}",
              name: t("#{thick} mm", "#{thick} mm"),
              options: %{"thickness_mm" => thick},
              unit: :m2,
              price: m2,
              delivery: :stock,
              stock: 300
            }
          end
      },
      %{
        number: "BH-3S-ZIRBE",
        category: ["dreischichtplatten", "zirbe"],
        title: t("3-Schicht-Platte Zirbe 19 mm", "Three-layer panel stone pine 19 mm"),
        description:
          t(
            "Astige Zirbenplatte für Schlafzimmermöbel.",
            "Knotty stone pine panel for bedroom furniture."
          ),
        shipping: :freight,
        new: true,
        properties: [species: :stone_pine, thickness: 19],
        unit: :m2,
        price: "89.00",
        delivery: :week
      },
      %{
        number: "BH-RAUSPUND",
        category: "rauspund-schalung",
        title: t("Rauspund Fichte 24 mm", "Tongue and groove boards spruce 24 mm"),
        description:
          t(
            "Sägeraue Schalung mit Nut und Feder für Dach und Boden.",
            "Rough-sawn tongue and groove sheathing for roofs and floors."
          ),
        properties: [species: :spruce, thickness: 24, surface: t("sägerau", "rough-sawn")],
        unit: :m2,
        price: "14.90",
        tiers: [{50, "13.50"}],
        delivery: :stock,
        stock: 900
      },
      %{
        number: "BH-SCHALUNG-OSB",
        category: "rauspund-schalung",
        title: t("OSB-Platte 18 mm", "OSB board 18 mm"),
        description:
          t(
            "Verlegeplatte mit Nut und Feder, 2500 × 675 mm.",
            "Tongue and groove flooring board, 2500 × 675 mm."
          ),
        properties: [thickness: 18],
        price: "16.40",
        delivery: :stock,
        stock: 400
      },
      %{
        number: "BH-HOBELDIELE-FI",
        category: "hobeldielen",
        title: t("Hobeldiele Fichte 27 × 146 mm", "Planed floorboard spruce 27 × 146 mm"),
        description:
          t(
            "Massive Bodendiele, gehobelt, mit Nut und Feder.",
            "Solid floorboard, planed, tongue and groove."
          ),
        properties: [
          species: :spruce,
          thickness: 27,
          width: 146,
          surface: t("gehobelt", "planed")
        ],
        unit: :m2,
        price: "29.90",
        delivery: :stock,
        stock: 500
      },
      %{
        number: "BH-HOBELDIELE-LAE",
        category: "hobeldielen",
        title: t("Hobeldiele Lärche 27 × 146 mm", "Planed floorboard larch 27 × 146 mm"),
        properties: [species: :larch, thickness: 27, width: 146, surface: t("gehobelt", "planed")],
        unit: :m2,
        price: "39.90",
        delivery: :week
      },
      %{
        number: "BH-LEIMHOLZ-EICHE",
        category: ["leimholzplatten", "eiche"],
        title:
          t("Leimholzplatte Eiche durchgehende Lamelle", "Glued panel oak, full-length staves"),
        description:
          t(
            "Für Treppenstufen, Fensterbänke und Arbeitsplatten.",
            "For stair treads, window sills and worktops."
          ),
        properties: [species: :oak, thickness: 26],
        variants:
          for {len, w, price} <- [{1200, 400, "89"}, {2000, 600, "189"}, {3000, 650, "299"}] do
            %{
              suffix: "#{len}X#{w}",
              name: t("#{len} × #{w} mm", "#{len} × #{w} mm"),
              options: %{"size" => "#{len} × #{w} mm"},
              price: price,
              delivery: :stock,
              stock: 15
            }
          end
      },
      %{
        number: "BH-LEIMHOLZ-FI",
        category: "leimholzplatten",
        title: t("Leimholzplatte Fichte 18 mm", "Glued panel spruce 18 mm"),
        properties: [species: :spruce, thickness: 18],
        price: "39.90",
        delivery: :stock,
        stock: 40
      },
      %{
        number: "BH-3S-LAE",
        category: "dreischichtplatten",
        title:
          t(
            "3-Schicht-Platte Lärche 27 mm, wetterfest",
            "Three-layer panel larch 27 mm, weatherproof"
          ),
        description:
          t(
            "Mit wasserfester Verleimung für Fassade und Balkon.",
            "Waterproof bonding for facades and balconies."
          ),
        shipping: :freight,
        properties: [species: :larch, thickness: 27],
        unit: :m2,
        price: "64.00",
        delivery: :week
      }
    ]
  end

  defp outdoor do
    decking = fn price_lfm ->
      for len <- [3000, 4000, 5000] do
        %{
          suffix: "#{div(len, 1000)}M",
          name: t("#{div(len, 1000)} m", "#{div(len, 1000)} m"),
          options: %{"length_mm" => len},
          price: per_lfm(price_lfm, len),
          tiers: [{50, per_lfm(Decimal.mult(Decimal.new(price_lfm), "0.92"), len)}],
          delivery: :stock,
          stock: 600
        }
      end
    end

    [
      %{
        number: "BH-TD-LAE",
        category: "terrassendielen",
        title: t("Terrassendiele Lärche 28 × 145 mm", "Decking board larch 28 × 145 mm"),
        description:
          t(
            "Sibirische Lärche, glatt/glatt, natürlich dauerhaft.",
            "Siberian larch, smooth both sides, naturally durable."
          ),
        highlights: [
          t("Resistenzklasse 3", "Durability class 3"),
          t("Ohne chemischen Holzschutz", "No chemical treatment")
        ],
        bestseller: true,
        properties: [species: :larch, thickness: 28, width: 145, surface: t("glatt", "smooth")],
        variants: decking.("6.20")
      },
      %{
        number: "BH-TD-DOU",
        category: "terrassendielen",
        title: t("Terrassendiele Douglasie 27 × 145 mm", "Decking board Douglas fir 27 × 145 mm"),
        properties: [
          species: :douglas,
          thickness: 27,
          width: 145,
          surface: t("genutet/glatt", "grooved/smooth")
        ],
        variants: decking.("5.40")
      },
      %{
        number: "BH-TD-THE",
        category: "terrassendielen",
        title:
          t("Terrassendiele Thermo-Esche 21 × 130 mm", "Decking board thermo ash 21 × 130 mm"),
        description:
          t(
            "Thermisch modifiziert, splitterfrei und formstabil.",
            "Thermally modified, splinter-free and stable."
          ),
        new: true,
        properties: [species: :ash, thickness: 21, width: 130],
        variants: decking.("9.80")
      },
      %{
        number: "BH-TD-UK-LAE",
        category: "terrassendielen",
        title: t("Unterkonstruktion Lärche 45 × 70 mm", "Substructure larch 45 × 70 mm"),
        properties: [species: :larch, thickness: 45, width: 70],
        price: per_lfm("4.50", 4000),
        delivery: :stock,
        stock: 700
      },
      %{
        number: "BH-TD-SCHRAUBEN",
        category: "terrassendielen",
        title:
          t("Terrassenschrauben Edelstahl 5 × 60 mm", "Stainless steel decking screws 5 × 60 mm"),
        description: t("Packung mit 500 Stück, inklusive Bit.", "Pack of 500, bit included."),
        price: "39.90",
        delivery: :stock,
        stock: 150
      },
      %{
        number: "BH-OEL-TERRASSE",
        category: ["terrassendielen", "fassadenschalung"],
        title: t("Holzöl Lärche 2,5 l", "Wood oil larch 2.5 l"),
        description:
          t("Pigmentiertes Pflegeöl auf Naturbasis.", "Pigmented care oil on a natural basis."),
        price: "34.90",
        delivery: :stock,
        stock: 80
      },
      %{
        number: "BH-FASSADE-RHOMBUS",
        category: "fassadenschalung",
        title: t("Rhombusleiste Lärche 21 × 68 mm", "Rhombus cladding larch 21 × 68 mm"),
        description:
          t("Moderne, hinterlüftete Fassadenschalung.", "Modern, ventilated facade cladding."),
        properties: [species: :larch, thickness: 21, width: 68],
        unit: :m2,
        price: "42.00",
        delivery: :week
      },
      %{
        number: "BH-FASSADE-BODEN-DECKEL",
        category: "fassadenschalung",
        title: t("Boden-Deckel-Schalung Fichte", "Board-and-batten cladding spruce"),
        properties: [species: :spruce, thickness: 24, surface: t("sägerau", "rough-sawn")],
        unit: :m2,
        price: "24.00",
        delivery: :stock,
        stock: 350
      },
      %{
        number: "BH-SICHTSCHUTZ",
        category: "zaeune-sichtschutz",
        title: t("Sichtschutzelement Lärche 180 × 180 cm", "Privacy screen larch 180 × 180 cm"),
        properties: [species: :larch],
        price: "89.00",
        tiers: [{5, "82.00"}],
        delivery: :stock,
        stock: 60
      },
      %{
        number: "BH-STAKETENZAUN",
        category: "zaeune-sichtschutz",
        title: t("Staketenzaun Kastanie, Rolle 5 m", "Chestnut picket fence, 5 m roll"),
        properties: [treated: false],
        variants:
          for h <- [100, 120, 150] do
            %{
              suffix: "H#{h}",
              name: t("Höhe #{h} cm", "Height #{h} cm"),
              options: %{"height_cm" => h},
              price: Decimal.add(Decimal.new("49"), Decimal.new(h - 100) |> Decimal.mult("0.6")),
              delivery: :stock,
              stock: 40
            }
          end
      },
      %{
        number: "BH-HOCHBEET",
        category: "hochbeete",
        title: t("Hochbeet Lärche", "Raised bed larch"),
        description:
          t(
            "Stecksystem ohne Schrauben, mit Wühlmausgitter.",
            "Plug-in system without screws, with vole mesh."
          ),
        bestseller: true,
        properties: [species: :larch],
        variants: [
          %{
            suffix: "120X80",
            name: t("120 × 80 × 80 cm", "120 × 80 × 80 cm"),
            options: %{"size" => "120 × 80 cm"},
            price: "179",
            delivery: :stock,
            stock: 25
          },
          %{
            suffix: "200X100",
            name: t("200 × 100 × 80 cm", "200 × 100 × 80 cm"),
            options: %{"size" => "200 × 100 cm"},
            price: "249",
            delivery: :stock,
            stock: 18
          }
        ]
      },
      %{
        number: "BH-PFLANZKASTEN",
        category: "hochbeete",
        title: t("Pflanzkasten Zirbe 60 cm", "Planter stone pine 60 cm"),
        properties: [species: :stone_pine],
        price: "69.00",
        delivery: :stock,
        stock: 30
      },
      %{
        number: "BH-ZAUNPFOSTEN-LAE",
        category: "zaeune-sichtschutz",
        title: t("Zaunpfosten Lärche 9 × 9 cm", "Fence post larch 9 × 9 cm"),
        properties: [species: :larch, thickness: 90, width: 90],
        variants:
          for len <- [1500, 2000, 2500] do
            %{
              suffix: "#{len}",
              name: t("#{len} mm", "#{len} mm"),
              options: %{"length_mm" => len},
              price: per_lfm("7.90", len),
              delivery: :stock,
              stock: 150
            }
          end
      },
      %{
        number: "BH-GARTENTISCH-LAE",
        category: "hochbeete",
        title: t("Gartentisch Lärche 160 × 80 cm", "Larch garden table 160 × 80 cm"),
        properties: [species: :larch],
        shipping: :freight,
        price: "459",
        delivery: :week
      }
    ]
  end

  defp fine_wood do
    [
      %{
        number: "BH-EICHE-BOHLE",
        category: "eiche",
        title: t("Eichenbohle luftgetrocknet 52 mm", "Oak plank air-dried 52 mm"),
        description:
          t(
            "Unbesäumte Bohle aus heimischer Eiche, mehrjährig luftgetrocknet.",
            "Unedged plank of local oak, air-dried for several years."
          ),
        properties: [
          species: :oak,
          thickness: 52,
          drying: t("luftgetrocknet", "air-dried"),
          origin: t("Österreich", "Austria")
        ],
        unit: :m3,
        price: "1450",
        delivery: :stock,
        stock: 12
      },
      %{
        number: "BH-EICHE-BRETT",
        category: "eiche",
        title: t("Eichenbrett gehobelt 26 × 200 mm", "Oak board planed 26 × 200 mm"),
        properties: [species: :oak, thickness: 26, width: 200, surface: t("gehobelt", "planed")],
        variants:
          for len <- [1000, 2000] do
            %{
              suffix: "#{div(len, 1000)}M",
              name: t("#{div(len, 1000)} m", "#{div(len, 1000)} m"),
              options: %{"length_mm" => len},
              price: per_m3("2450", 26, 200, len),
              delivery: :stock,
              stock: 50
            }
          end
      },
      %{
        number: "BH-NUSS-BRETT",
        category: "nuss",
        title: t("Nussbrett gehobelt 26 mm", "Walnut board planed 26 mm"),
        properties: [species: :walnut, thickness: 26, surface: t("gehobelt", "planed")],
        unit: :m2,
        price: "149.00",
        delivery: :week
      },
      %{
        number: "BH-NUSS-BAUMKANTE",
        category: ["nuss", "tischplatten"],
        title: t("Tischplatte Nuss mit Baumkante", "Walnut table top with live edge"),
        description:
          t(
            "Einzelstück aus einem Stamm, 2200 × 900 × 40 mm.",
            "Unique piece from a single log, 2200 × 900 × 40 mm."
          ),
        new: true,
        properties: [species: :walnut, thickness: 40, length: 2200, width: 900],
        price: "1890",
        delivery: :stock,
        stock: 2
      },
      %{
        number: "BH-ZIRBE-BRETT",
        category: "zirbe",
        title: t("Zirbenbrett 20 × 200 × 2000 mm", "Stone pine board 20 × 200 × 2000 mm"),
        description:
          t(
            "Astige Zirbe aus Tiroler Hochlagen – mit dem typischen Duft.",
            "Knotty stone pine from high Tyrolean altitudes – with its typical scent."
          ),
        properties: [
          species: :stone_pine,
          thickness: 20,
          width: 200,
          length: 2000,
          origin: t("Tirol", "Tyrol")
        ],
        price: "49.00",
        tiers: [{10, "44.00"}],
        delivery: :stock,
        stock: 70
      },
      %{
        number: "BH-ZIRBE-KANTEL",
        category: "zirbe",
        title: t("Zirbenkantel 60 × 60 mm", "Stone pine square 60 × 60 mm"),
        properties: [species: :stone_pine, thickness: 60, width: 60],
        price: per_lfm("12.50", 1000),
        delivery: :stock,
        stock: 90
      },
      %{
        number: "BH-KIRSCHE-BRETT",
        category: "tischplatten",
        title: t("Kirschbrett gehobelt 26 mm", "Cherry board planed 26 mm"),
        properties: [species: :cherry, thickness: 26],
        unit: :m2,
        price: "119.00",
        delivery: :week
      },
      %{
        number: "BH-TISCHPLATTE-EICHE",
        category: "tischplatten",
        title: t("Tischplatte Eiche massiv 40 mm", "Solid oak table top 40 mm"),
        description: t("Durchgehende Lamellen, geölt.", "Full-length staves, oiled."),
        properties: [species: :oak, thickness: 40, surface: t("geölt", "oiled")],
        variants:
          for {len, w, price} <- [{1600, 800, "690"}, {1800, 900, "820"}, {2200, 1000, "1090"}] do
            %{
              suffix: "#{len}X#{w}",
              name: t("#{len} × #{w} mm", "#{len} × #{w} mm"),
              options: %{"size" => "#{len} × #{w} mm"},
              price: price,
              delivery: :order
            }
          end
      },
      %{
        number: "BH-AHORN-BRETT",
        category: "tischplatten",
        title: t("Ahornbrett gehobelt 26 mm", "Maple board planed 26 mm"),
        properties: [thickness: 26, surface: t("gehobelt", "planed")],
        unit: :m2,
        price: "98.00",
        delivery: :week
      }
    ]
  end

  defp furniture do
    [
      %{
        number: "BH-BETT-ZIRBE",
        category: "zirbenbetten",
        title: t("Zirbenbett „Bergschlaf“", "Stone pine bed “Bergschlaf”"),
        description:
          t(
            "Metallfreies Massivholzbett aus Zirbe, geölt.",
            "Metal-free solid stone pine bed, oiled."
          ),
        highlights: [
          t("Ohne Metall verbunden", "Joined without metal"),
          t("Natürlicher Zirbenduft", "Natural stone pine scent")
        ],
        bestseller: true,
        shipping: :freight,
        properties: [species: :stone_pine, surface: t("geölt", "oiled")],
        variants:
          for {w, price} <- [{90, "1590"}, {160, "2290"}, {180, "2490"}] do
            %{
              suffix: "#{w}X200",
              name: t("#{w} × 200 cm", "#{w} × 200 cm"),
              options: %{"size" => "#{w} × 200 cm"},
              price: price,
              delivery: :order
            }
          end
      },
      %{
        number: "BH-NACHTKASTL-ZIRBE",
        category: "zirbenbetten",
        title: t("Nachtkästchen Zirbe", "Bedside table stone pine"),
        properties: [species: :stone_pine],
        price: "390",
        delivery: :order
      },
      %{
        number: "BH-TISCH-EICHE",
        category: "tische-baenke",
        title: t("Esstisch Eiche massiv", "Solid oak dining table"),
        shipping: :freight,
        properties: [species: :oak, surface: t("geölt", "oiled")],
        variants: [
          %{
            suffix: "180",
            name: t("180 × 90 cm", "180 × 90 cm"),
            options: %{"size" => "180 × 90 cm"},
            price: "1690",
            delivery: :order
          },
          %{
            suffix: "200",
            name: t("200 × 100 cm", "200 × 100 cm"),
            options: %{"size" => "200 × 100 cm"},
            price: "1890",
            delivery: :order
          }
        ]
      },
      %{
        number: "BH-BANK-EICHE",
        category: "tische-baenke",
        title: t("Sitzbank Eiche 160 cm", "Oak bench 160 cm"),
        properties: [species: :oak],
        price: "690",
        delivery: :order
      },
      %{
        number: "BH-GARTENBANK-LAE",
        category: ["tische-baenke", "hochbeete"],
        title: t("Gartenbank Lärche", "Larch garden bench"),
        properties: [species: :larch],
        price: "349",
        promo: "299",
        delivery: :stock,
        stock: 12
      },
      %{
        number: "BH-HOCKER-ZIRBE",
        category: "hocker-garderoben",
        title: t("Hocker Zirbe", "Stone pine stool"),
        properties: [species: :stone_pine],
        price: "89.00",
        delivery: :stock,
        stock: 35
      },
      %{
        number: "BH-MELKSCHEMEL",
        category: "hocker-garderoben",
        title: t("Melkschemel Esche", "Milking stool ash"),
        price: "59.00",
        delivery: :stock,
        stock: 40
      },
      %{
        number: "BH-GARDEROBE-ZIRBE",
        category: "hocker-garderoben",
        title: t("Wandgarderobe Zirbe mit 5 Haken", "Wall coat rack stone pine with 5 hooks"),
        properties: [species: :stone_pine],
        price: "129.00",
        delivery: :stock,
        stock: 20
      },
      %{
        number: "BH-SCHNEIDBRETT",
        category: "kuechenhelfer",
        title: t("Schneidbrett Massivholz", "Solid wood cutting board"),
        bestseller: true,
        variants:
          for {sp, price} <- [{:stone_pine, "39.00"}, {:oak, "45.00"}, {:walnut, "59.00"}] do
            %{
              suffix: sp |> to_string() |> String.upcase(),
              name: species(sp),
              options: %{"species" => to_string(sp)},
              price: price,
              delivery: :stock,
              stock: 60
            }
          end
      },
      %{
        number: "BH-BROTDOSE-ZIRBE",
        category: "kuechenhelfer",
        title: t("Brotdose Zirbe", "Bread box stone pine"),
        description:
          t("Zirbe hält Brot länger frisch.", "Stone pine keeps bread fresh for longer."),
        properties: [species: :stone_pine],
        price: "79.00",
        delivery: :stock,
        stock: 25
      },
      %{
        number: "BH-ZIRBENKISSEN",
        category: "kuechenhelfer",
        title: t("Zirbenkissen mit Zirbenspänen", "Pillow filled with stone pine shavings"),
        new: true,
        properties: [species: :stone_pine],
        price: "29.00",
        delivery: :stock,
        stock: 100
      },
      %{
        number: "BH-WANDREGAL-EICHE",
        category: "hocker-garderoben",
        title: t("Wandregal Eiche mit Baumkante", "Oak wall shelf with live edge"),
        properties: [species: :oak],
        variants:
          for len <- [60, 90, 120] do
            %{
              suffix: "#{len}",
              name: t("#{len} cm", "#{len} cm"),
              options: %{"length_cm" => len},
              price:
                Decimal.new(len) |> Decimal.mult("1.15") |> Decimal.add(20) |> Decimal.round(2),
              delivery: :stock,
              stock: 20
            }
          end
      },
      %{
        number: "BH-ZIRBENWUERFEL",
        category: "kuechenhelfer",
        title: t("Zirbenwürfel mit Duftöl", "Stone pine cube with scented oil"),
        description:
          t(
            "Natürlicher Raumduft aus Zirbenholz.",
            "Natural room fragrance from stone pine wood."
          ),
        properties: [species: :stone_pine],
        price: "19.90",
        delivery: :stock,
        stock: 150
      }
    ]
  end

  defp energy do
    [
      %{
        number: "BH-SCHEIT-BUCHE",
        category: "scheitholz",
        title: t("Brennholz Buche ofenfertig", "Beech firewood, ready for the stove"),
        description:
          t("Kammergetrocknet, gestapelt geliefert.", "Kiln-dried, delivered stacked."),
        highlights: [t("Wassergehalt unter 20 %", "Moisture below 20 %")],
        tax: :reduced,
        bestseller: true,
        shipping: :freight,
        properties: [
          species: :beech,
          moisture: 18,
          calorific: "4.2",
          drying: t("kammergetrocknet", "kiln-dried")
        ],
        variants:
          for len <- [25, 33, 50] do
            %{
              suffix: "#{len}CM",
              name: t("Scheitlänge #{len} cm", "Log length #{len} cm"),
              options: %{"log_length_cm" => len},
              unit: :rm,
              price: if(len == 25, do: "119", else: "109"),
              tiers: [{3, if(len == 25, do: "112", else: "102")}],
              delivery: :stock,
              stock: 300
            }
          end
      },
      %{
        number: "BH-SCHEIT-FICHTE",
        category: "scheitholz",
        title: t("Brennholz Fichte/Tanne", "Spruce/fir firewood"),
        description:
          t(
            "Leicht entzündliches Weichholz, ideal zum Anheizen.",
            "Easily ignited softwood, ideal for lighting the fire."
          ),
        tax: :reduced,
        shipping: :freight,
        properties: [species: :spruce, moisture: 20, calorific: "4.3"],
        unit: :rm,
        price: "79",
        tiers: [{3, "74"}],
        delivery: :stock,
        stock: 250
      },
      %{
        number: "BH-KAMINHOLZ-SACK",
        category: "scheitholz",
        title: t("Kaminholz im Sack, 25 dm³", "Fireplace wood in a sack, 25 dm³"),
        tax: :reduced,
        properties: [species: :mixed],
        unit: :sack,
        price: "8.90",
        delivery: :stock,
        stock: 400
      },
      %{
        number: "BH-ANZUENDHOLZ",
        category: "scheitholz",
        title: t("Anzündholz Fichte, 5 kg", "Kindling spruce, 5 kg"),
        tax: :reduced,
        properties: [species: :spruce],
        unit: :sack,
        price: "5.90",
        delivery: :stock,
        stock: 500
      },
      %{
        number: "BH-PELLETS-SACK",
        category: "pellets",
        title: t("Holzpellets ENplus A1, Sack 15 kg", "Wood pellets ENplus A1, 15 kg bag"),
        description:
          t(
            "Aus Sägespänen unseres eigenen Sägewerks.",
            "Made from sawdust from our own sawmill."
          ),
        tax: :reduced,
        bestseller: true,
        properties: [calorific: "4.9", moisture: 8],
        variants: [
          %{
            suffix: "SACK",
            name: t("Einzelsack", "Single bag"),
            options: %{"packaging" => "sack"},
            unit: :sack,
            price: "6.40",
            tiers: [{10, "6.10"}],
            delivery: :stock,
            stock: 3000
          },
          %{
            suffix: "PALETTE",
            name: t("Palette, 66 Säcke (990 kg)", "Pallet, 66 bags (990 kg)"),
            options: %{"packaging" => "pallet"},
            unit: :pallet,
            price: "389",
            tiers: [{3, "375"}],
            delivery: :stock,
            stock: 45
          }
        ]
      },
      %{
        number: "BH-PELLETS-LOSE",
        category: "pellets",
        title:
          t(
            "Holzpellets lose, Einblasung per Silowagen",
            "Loose wood pellets, blown in by silo truck"
          ),
        tax: :reduced,
        shipping: :freight,
        properties: [calorific: "4.9", moisture: 8],
        unit: :t,
        price: "345",
        tiers: [{3, "329"}, {6, "315"}],
        delivery: :week
      },
      %{
        number: "BH-BRIKETTS-BUCHE",
        category: "briketts",
        title: t("Holzbriketts Buche", "Beech wood briquettes"),
        tax: :reduced,
        properties: [species: :beech, calorific: "5.0"],
        variants: [
          %{
            suffix: "10KG",
            name: t("Paket 10 kg", "Pack 10 kg"),
            options: %{"packaging" => "sack"},
            unit: :sack,
            price: "4.90",
            delivery: :stock,
            stock: 800
          },
          %{
            suffix: "PALETTE",
            name: t("Palette, 96 Pakete", "Pallet, 96 packs"),
            options: %{"packaging" => "pallet"},
            unit: :pallet,
            price: "449",
            delivery: :stock,
            stock: 20
          }
        ]
      },
      %{
        number: "BH-HACKSCHNITZEL",
        category: "hackschnitzel",
        title: t("Hackschnitzel G30", "Wood chips G30"),
        description:
          t(
            "Für Hackschnitzelheizungen, Wassergehalt unter 30 %.",
            "For wood chip boilers, moisture below 30 %."
          ),
        tax: :reduced,
        shipping: :freight,
        properties: [moisture: 28, calorific: "3.6"],
        unit: :srm,
        price: "39",
        tiers: [{20, "35"}],
        delivery: :week
      },
      %{
        number: "BH-SAEGESPAENE-LOSE",
        category: "spaene",
        title: t("Sägespäne lose, als Brennstoff", "Loose sawdust as fuel"),
        description:
          t(
            "Direkt aus dem Sägewerk, Abholung oder Lieferung im Container.",
            "Straight from the sawmill, pick-up or container delivery."
          ),
        tax: :reduced,
        shipping: :pickup_only,
        properties: [species: :spruce],
        unit: :srm,
        price: "19",
        delivery: :stock
      },
      %{
        number: "BH-EINSTREU-SPAENE",
        category: "spaene",
        title:
          t("Hobelspäne als Einstreu, Ballen 20 kg", "Wood shavings for bedding, 20 kg bale"),
        description:
          t(
            "Entstaubt, für Pferde und Kleintiere.",
            "Dust-extracted, for horses and small animals."
          ),
        properties: [species: :spruce],
        unit: :sack,
        price: "12.90",
        tiers: [{20, "11.50"}],
        delivery: :stock,
        stock: 600
      },
      %{
        number: "BH-SAEGEMEHL-KG",
        category: "spaene",
        title: t("Sägemehl fein, lose", "Fine sawdust, loose"),
        description:
          t(
            "Für Räucheröfen und Werkstatt – vom Haus bis zum Sägemehl.",
            "For smokers and workshops – from the house down to the sawdust."
          ),
        properties: [species: :beech],
        unit: :kg,
        price: "0.90",
        delivery: :stock,
        stock: 2000
      },
      %{
        number: "BH-HOLZBRIKETT-RUF",
        category: "briketts",
        title: t("Holzbriketts Fichte (RUF), 10 kg", "Spruce wood briquettes (RUF), 10 kg"),
        tax: :reduced,
        properties: [species: :spruce, calorific: "4.8"],
        unit: :sack,
        price: "4.20",
        tiers: [{20, "3.90"}],
        delivery: :stock,
        stock: 900
      }
    ]
  end

  defp forestry do
    [
      %{
        number: "BH-RUNDHOLZ-FI",
        category: "rundholz",
        title: t("Rundholz Fichte ab Waldstraße", "Spruce round timber at the forest road"),
        description:
          t(
            "Sägerundholz Güteklasse B/C, Mindestabnahme 10 fm.",
            "Saw logs grade B/C, minimum order 10 fm."
          ),
        shipping: :pickup_only,
        properties: [species: :spruce, origin: t("Tiroler Alpen", "Tyrolean Alps")],
        unit: :fm,
        price: "95",
        tiers: [{50, "89"}],
        delivery: :week
      },
      %{
        number: "BH-RUNDHOLZ-LAE",
        category: "rundholz",
        title: t("Rundholz Lärche ab Waldstraße", "Larch round timber at the forest road"),
        shipping: :pickup_only,
        properties: [species: :larch, origin: t("Tiroler Alpen", "Tyrolean Alps")],
        unit: :fm,
        price: "140",
        delivery: :week
      },
      %{
        number: "BH-BRENNHOLZ-LANG",
        category: ["rundholz", "scheitholz"],
        title: t("Brennholz lang, 1-m-Stämme", "Firewood in 1 m logs"),
        description:
          t(
            "Zum Selbstspalten, Buche und Esche gemischt.",
            "For splitting yourself, mixed beech and ash."
          ),
        tax: :reduced,
        shipping: :pickup_only,
        properties: [species: :mixed],
        unit: :fm,
        price: "75",
        delivery: :stock
      },
      %{
        number: "BH-CHRISTBAUM-NORDMANN",
        category: "christbaeume",
        title: t("Christbaum Nordmanntanne", "Christmas tree Nordmann fir"),
        description:
          t("Frisch geschlagen aus eigener Kultur.", "Freshly cut from our own plantation."),
        tax: :reduced,
        new: true,
        properties: [species: :fir],
        variants:
          for {height, price} <- [{"150–175", "39"}, {"175–200", "49"}, {"200–250", "69"}] do
            %{
              suffix: String.replace(height, "–", "-"),
              name: t("#{height} cm", "#{height} cm"),
              options: %{"height_cm" => height},
              price: price,
              delivery: :season
            }
          end
      },
      %{
        number: "BH-CHRISTBAUM-BLAUFICHTE",
        category: "christbaeume",
        title: t("Christbaum Blaufichte 150–175 cm", "Christmas tree blue spruce 150–175 cm"),
        tax: :reduced,
        properties: [species: :blue_spruce],
        price: "29",
        delivery: :season
      },
      %{
        number: "BH-SERVICE-ZUSCHNITT",
        category: "dienstleistungen",
        title: t("Zuschnittservice", "Cutting service"),
        description:
          t("Präziser Zuschnitt auf Maß, pro Schnitt.", "Precise cutting to size, per cut."),
        shipping: :none,
        price: "1.50",
        delivery: :stock
      },
      %{
        number: "BH-SERVICE-HOBELN",
        category: "dienstleistungen",
        title: t("Hobelservice", "Planing service"),
        description:
          t(
            "Hobeln von Brettern und Kanthölzern, pro Laufmeter.",
            "Planing of boards and squared timber, per running metre."
          ),
        shipping: :none,
        unit: :lfm,
        price: "0.90",
        delivery: :stock
      },
      %{
        number: "BH-SERVICE-WALDPFLEGE",
        category: "dienstleistungen",
        title: t("Waldpflege durch unsere Forstwirte", "Forest care by our foresters"),
        description:
          t(
            "Durchforstung, Schlägerung und Aufforstung – Abrechnung pro Stunde.",
            "Thinning, felling and reforestation – charged per hour."
          ),
        shipping: :none,
        price: "85",
        delivery: :week
      }
    ]
  end
end
