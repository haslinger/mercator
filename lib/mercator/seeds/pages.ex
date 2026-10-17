defmodule Mercator.Seeds.Pages do
  @moduledoc """
  CMS demo content for Biber Holz (docs/cms-design.md, step 8): the start
  page, "Über uns", "Unser Sägewerk", FAQ, contact, imprint and privacy
  policy, a shared block with the opening hours, and the photos they use in
  the media library (tag `demo`, taken from `assets/img/categories`).

  Idempotent: files are matched by name and tag, pages by their path; an
  existing page is left as it is (content managers may have changed it).
  All texts are placeholders of a fictitious company.
  """

  require Ash.Query

  alias Mercator.Content
  alias Mercator.Content.{Asset, Page}

  @doc """
  Creates the demo pages and files that do not exist yet. Photos come from
  the config `:seed_image_dir` (default `assets/img/categories`); without one
  (tests) the pages have no photos.
  """
  def run(image_dir \\ Application.get_env(:mercator, :seed_image_dir, "assets/img/categories")) do
    images = Map.new(images_used(), &{&1, ensure_image(image_dir, &1)})

    hours = ensure_page(opening_hours())
    Enum.each(pages(images, hours), &ensure_page/1)
  end

  defp t(de, en), do: %{"de" => de, "en" => en}

  defp images_used do
    ~w(holzhaeuser-bausaetze.jpeg forst-rundholz.jpeg dienstleistungen.jpeg bauholz.jpeg
       kanthoelzer-balken.jpeg rundholz.jpeg scheitholz.jpeg zirbe.jpeg)
  end

  defp ensure_image(nil, _file), do: nil

  defp ensure_image(dir, file) do
    path = Path.join(dir, file)

    existing =
      Asset
      |> Ash.Query.filter(original_filename == ^file and "demo" in tags)
      |> Ash.read_one!(authorize?: false)

    cond do
      existing ->
        existing.id

      File.regular?(path) ->
        Content.upload_asset!(
          %{
            source_path: path,
            original_filename: file,
            title: t(Path.rootname(file), Path.rootname(file)),
            alt: t("Holz von Biber Holz", "Timber from Biber Holz"),
            tags: ["demo", "biber holz"]
          },
          authorize?: false
        ).id

      true ->
        nil
    end
  end

  defp ensure_page(%{slug: slug} = attrs) do
    case Page |> Ash.Query.filter(path == ^slug) |> Ash.read_one!(authorize?: false) do
      nil ->
        attrs
        |> Content.create_page!(authorize?: false)
        |> Content.publish_page!(authorize?: false)

      # pages created before icons existed get theirs; nothing else changes
      %{icon: nil} = page when is_map_key(attrs, :icon) ->
        Content.update_page!(page, %{icon: attrs.icon}, authorize?: false)

      page ->
        page
    end
  end

  defp text(de, en), do: %{type: "text", text: t(de, en)}

  defp opening_hours do
    %{
      kind: :shared,
      slug: "oeffnungszeiten",
      title: t("Öffnungszeiten", "Opening hours"),
      blocks: [
        text(
          """
          ### Öffnungszeiten Sägewerk und Abholung
          Montag bis Freitag 7–17 Uhr
          Samstag 8–12 Uhr

          Biber Holz GmbH, Waldweg 1, 3914 Waldhausen
          Telefon +43 1 234 56 78
          """,
          """
          ### Opening hours of the sawmill and pickup
          Monday to Friday 7 am–5 pm
          Saturday 8 am–12 noon

          Biber Holz GmbH, Waldweg 1, 3914 Waldhausen, Austria
          Phone +43 1 234 56 78
          """
        )
      ]
    }
  end

  defp pages(images, hours) do
    [
      %{
        slug: "start",
        key: "home",
        title: t("Willkommen bei Biber Holz", "Welcome to Biber Holz"),
        seo_description:
          t(
            "Bau- und Edelholz aus dem Waldviertel: vom Holzhaus bis zum Sägespan, seit 1928.",
            "Construction and fine timber from the Waldviertel: from timber houses to sawdust, since 1928."
          ),
        blocks: [
          %{
            type: "hero",
            image_id: images["holzhaeuser-bausaetze.jpeg"],
            headline: t("Holz aus dem Waldviertel", "Timber from the Waldviertel"),
            text:
              t(
                "Vom Holzhaus bis zum Sägespan – aus eigenen Wäldern, im eigenen Sägewerk verarbeitet. **Seit 1928.**",
                "From timber houses to sawdust – from our own forests, processed in our own sawmill. **Since 1928.**"
              ),
            button_label: t("Zum Sortiment", "Browse the range"),
            button_link: "/categories/bauholz"
          },
          %{type: "categories", heading: t("Unser Sortiment", "Our range")},
          %{
            type: "columns",
            items: [
              %{
                title: t("Regional", "Regional"),
                text:
                  t(
                    "Unser Holz wächst im Waldviertel und wird wenige Kilometer weiter gesägt.",
                    "Our timber grows in the Waldviertel and is sawn a few kilometres away."
                  )
              },
              %{
                title: t("Nachhaltig", "Sustainable"),
                text:
                  t(
                    "Wir ernten nur, was nachwächst – und verwerten jeden Span.",
                    "We only harvest what grows back – and use every shaving."
                  )
              },
              %{
                title: t("Nach Maß", "Made to measure"),
                text:
                  t(
                    "Bauholz, Platten und Tischplatten schneiden wir auf Ihr Maß zu.",
                    "We cut construction timber, panels and table tops to your size."
                  )
              }
            ]
          },
          %{
            type: "products",
            heading: t("Topseller", "Bestsellers"),
            source: :bestsellers,
            limit: 4
          },
          %{
            type: "contact_options",
            headline: t("Wie möchten Sie beraten werden?", "How would you like to be advised?"),
            text:
              t(
                "Unsere Holzexperten helfen bei Auswahl, Mengen und Zuschnitt – schriftlich oder im Gespräch.",
                "Our timber experts help with choice, quantities and cutting – in writing or in a call."
              ),
            message_link: "/pages/kontakt",
            show_phone: true
          }
        ]
      },
      %{
        slug: "ueber-uns",
        icon: "hero-information-circle",
        menu: :main,
        position: 1,
        title: t("Über uns", "About us"),
        blocks: [
          %{
            type: "text_image",
            image_id: images["forst-rundholz.jpeg"],
            image_side: :right,
            text:
              t(
                """
                ## Seit 1928 im Waldviertel
                Was als kleines Sägewerk am Waldrand begann, ist heute ein Familienbetrieb in vierter Generation. Wir bewirtschaften eigene Wälder rund um Waldhausen und verarbeiten das Holz selbst – vom Rundholz bis zum fertigen Holzhaus.

                *Biber Holz ist ein erfundenes Unternehmen für diese Demo.*
                """,
                """
                ## In the Waldviertel since 1928
                What began as a small sawmill at the edge of the forest is now a family business in its fourth generation. We manage our own forests around Waldhausen and process the timber ourselves – from round logs to finished timber houses.

                *Biber Holz is a fictitious company for this demo.*
                """
              )
          },
          %{
            type: "columns",
            items: [
              %{title: t("120 ha", "120 ha"), text: t("eigener Wald", "of our own forest")},
              %{title: t("35", "35"), text: t("Mitarbeiterinnen und Mitarbeiter", "employees")},
              %{
                title: t("4. Generation", "4th generation"),
                text: t("Familienbetrieb", "family business")
              }
            ]
          }
        ]
      },
      %{
        slug: "saegewerk",
        icon: "hero-wrench-screwdriver",
        menu: :main,
        position: 2,
        title: t("Unser Sägewerk", "Our sawmill"),
        blocks: [
          %{
            type: "hero",
            image_id: images["dienstleistungen.jpeg"],
            headline: t("Unser Sägewerk", "Our sawmill"),
            text:
              t(
                "Schneiden, trocknen, hobeln – alles an einem Ort.",
                "Cutting, drying, planing – all in one place."
              )
          },
          text(
            """
            ## Was wir für Sie tun
            - **Lohnschnitt:** Wir schneiden Ihr Rundholz nach Liste.
            - **Technische Trocknung** auf 15 % Holzfeuchte, für Bauholz und Möbel.
            - **Hobeln und Profilieren** von Brettern, Latten und Dielen.
            - **Zuschnitt** von Platten und Tischplatten auf Maß.
            """,
            """
            ## What we do for you
            - **Contract sawing:** we saw your round logs to your list.
            - **Kiln drying** to 15 % moisture content, for construction timber and furniture.
            - **Planing and profiling** of boards, battens and floorboards.
            - **Cutting** panels and table tops to size.
            """
          ),
          %{
            type: "gallery",
            image_ids:
              Enum.reject(
                [
                  images["bauholz.jpeg"],
                  images["kanthoelzer-balken.jpeg"],
                  images["rundholz.jpeg"],
                  images["scheitholz.jpeg"],
                  images["zirbe.jpeg"]
                ],
                &is_nil/1
              )
          },
          %{type: "shared", page_id: hours.id}
        ]
      },
      %{
        slug: "faq",
        icon: "hero-question-mark-circle",
        menu: :main,
        position: 3,
        title: t("Häufige Fragen", "Frequently asked questions"),
        blocks: [
          %{
            type: "faq",
            items: [
              %{
                question: t("Wohin liefern Sie?", "Where do you deliver?"),
                answer:
                  t(
                    "Pakete nach Österreich, Deutschland und Italien. Große Mengen und Holzhäuser liefern wir per Spedition; die Frachtkosten bestätigen wir vor der Lieferung.",
                    "Parcels to Austria, Germany and Italy. Large quantities and timber houses go by freight; we confirm the freight costs before delivery."
                  )
              },
              %{
                question: t("Kann ich selbst abholen?", "Can I pick up myself?"),
                answer:
                  t(
                    "Ja, kostenlos im Sägewerk in Waldhausen. Wir melden uns, sobald Ihre Bestellung abholbereit ist.",
                    "Yes, free of charge at the sawmill in Waldhausen. We let you know as soon as your order is ready for pickup."
                  )
              },
              %{
                question: t("Schneiden Sie auf Maß zu?", "Do you cut to size?"),
                answer:
                  t(
                    "Ja: Konstruktionsholz, Dreischichtplatten, Leisten und Tischplatten konfigurieren Sie direkt im Shop – der Preis wird sofort berechnet.",
                    "Yes: you configure construction timber, three-layer panels, mouldings and table tops directly in the shop – the price is calculated right away."
                  )
              },
              %{
                question: t("Wie trocken ist Ihr Holz?", "How dry is your timber?"),
                answer:
                  t(
                    "Bauholz und Möbelholz sind technisch getrocknet (ca. 15 % Holzfeuchte), Brennholz luftgetrocknet unter 20 %.",
                    "Construction and furniture timber are kiln-dried (about 15 % moisture), firewood is air-dried below 20 %."
                  )
              },
              %{
                question: t("Wie kann ich bezahlen?", "How can I pay?"),
                answer:
                  t(
                    "Per Vorauskasse, bei Abholung bar oder mit Karte, und für freigeschaltete Firmenkunden auf Rechnung.",
                    "By prepayment, cash or card on pickup, and on invoice for approved business customers."
                  )
              }
            ]
          }
        ]
      },
      %{
        slug: "kontakt",
        icon: "hero-envelope",
        key: "contact",
        menu: :main,
        position: 4,
        title: t("Kontakt", "Contact"),
        blocks: [
          %{type: "shared", page_id: hours.id},
          %{
            type: "contact_options",
            headline: t("So erreichen Sie uns", "How to reach us"),
            show_phone: true
          },
          %{
            type: "contact_form",
            intro:
              t(
                "Fragen zu Holzarten, Mengen oder Zuschnitt? Schreiben Sie uns – wir melden uns innerhalb eines Werktags.",
                "Questions about wood species, quantities or cutting? Write to us – we reply within one working day."
              )
          }
        ]
      },
      %{
        slug: "impressum",
        icon: "hero-scale",
        key: "imprint",
        menu: :footer,
        position: 10,
        title: t("Impressum", "Imprint"),
        blocks: [
          text(
            """
            **Biber Holz GmbH** (fiktives Demo-Unternehmen)
            Waldweg 1, 3914 Waldhausen, Österreich
            Telefon +43 1 234 56 78 · service@example.com

            Firmenbuchnummer: FN 000000x (Demo) · UID: ATU00000000 (Demo)
            Unternehmensgegenstand: Forstwirtschaft, Sägewerk, Holzhandel

            *Dies ist ein Demo-Shop. Es werden keine Bestellungen ausgeführt.*
            """,
            """
            **Biber Holz GmbH** (fictitious demo company)
            Waldweg 1, 3914 Waldhausen, Austria
            Phone +43 1 234 56 78 · service@example.com

            Company register: FN 000000x (demo) · VAT ID: ATU00000000 (demo)
            Business: forestry, sawmill, timber trade

            *This is a demo shop. No orders are carried out.*
            """
          )
        ]
      },
      %{
        slug: "datenschutz",
        icon: "hero-shield-check",
        key: "privacy",
        menu: :footer,
        position: 11,
        title: t("Datenschutz", "Privacy policy"),
        blocks: [
          text(
            """
            ## Platzhalter
            Hier steht die Datenschutzerklärung des Shopbetreibers. Für die Demo nur so viel: Wir speichern die Daten, die Sie bei Registrierung, Bestellung und im Kontaktformular angeben, um Ihre Anfragen und Bestellungen zu bearbeiten. Die Demo-Daten werden regelmäßig zurückgesetzt.

            ## Beratung und Anrufe
            Nachrichten im Beratungs-Chat speichern wir mit dem Gespräch. Anrufe (Ton, Video, Bildschirm teilen) laufen verschlüsselt über unseren eigenen Server, nicht über einen fremden Dienst, und werden nicht aufgezeichnet. Wir speichern nur, wann ein Anruf begann und endete und ob Video oder eine Bildschirmfreigabe genutzt wurden. Für die Verbindung sieht unser Server die IP-Adresse Ihres Geräts.
            """,
            """
            ## Placeholder
            This is where the shop operator's privacy policy goes. For the demo only this much: we store the data you enter when registering, ordering and in the contact form to process your requests and orders. The demo data is reset regularly.

            ## Advice and calls
            We store the messages of the advice chat with the conversation. Calls (audio, video, screen sharing) run encrypted through our own server, not a third-party service, and are not recorded. We only store when a call began and ended and whether video or screen sharing was used. For the connection our server sees your device's IP address.
            """
          )
        ]
      }
    ]
  end
end
