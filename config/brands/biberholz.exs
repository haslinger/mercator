import Config

# The Biber Holz demo brand (#36): used in development and by the demo
# deployment (BRAND=biberholz, #43). Every brand of config/brands/ is part of
# every build; Mercator.Brand uses the one named by `:brand_key`.
config :mercator, :brands,
  biberholz: [
    name: "Biber Holz",
    tagline: %{
      "de" => "Österreichische Alpen-Forstwirtschaft\nQualitäts-Bau- und Edelholz seit 1928",
      "en" => "Austrian alpine forestry\nQuality construction and fine timber since 1928"
    },
    email: "service@example.com",
    phone: "+43 000 1234567",
    address: "Waldweg 1, 0000 Waldhausen",
    # order numbers like BH-2026-00042 (#68)
    order_prefix: "BH",
    # demo bank account (the example IBAN from the ISO 13616 standard)
    bank: %{
      holder: "Biber Holz GmbH",
      iban: "AT61 1904 3002 3457 3201",
      bic: "DEMOATWW",
      name: "Demo-Bank"
    },
    assets: "/images/brands/biberholz",
    logo: "logo.webp",
    pin: "pin.webp",
    favicon: "favicon.svg",
    apple_touch_icon: "apple-touch-icon.png",
    short_name: "Biber Holz",
    theme_color: "#67482d",
    background_color: "#fbf6ec",
    light_theme: "biberholz",
    dark_theme: "biberholz-dark"
  ]
