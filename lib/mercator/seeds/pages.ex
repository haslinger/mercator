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
            ## Demo-Shop
            **Biber Holz ist ein erfundenes Unternehmen.** Dieser Shop führt die Shop-Software Mercator vor: Produkte, Preise, Personen und Adressen sind frei erfunden. Bestellungen werden nicht ausgeführt, Zahlungen nur simuliert, und alle Daten werden jede Nacht gelöscht.

            ## Betreiber und Medieninhaber
            Angaben gemäß § 5 ECG, § 14 UGB und § 63 GewO, Offenlegung gemäß § 25 MedienG

            **Informatom EDV-Dienstleistungen e.U.**
            Inhaber: Mag. Stefan Haslinger
            Vorgartenstraße 145–157/2/3, 1020 Wien, Österreich
            Telefon: +43 680 213 30 30
            E-Mail: stefan.haslinger@informatom.com
            Web: [www.informatom.com](https://www.informatom.com)

            Rechtsform: eingetragenes Einzelunternehmen
            Firmenbuchnummer: FN 357693 w
            Firmenbuchgericht: Handelsgericht Wien
            UID-Nummer: ATU66331917
            Firmensitz: Wien
            Unternehmensgegenstand: Dienstleistungen in der automatischen Datenverarbeitung und Informationstechnik
            Gewerbebehörde: Magistratisches Bezirksamt für den 2. Bezirk
            Anwendbare Rechtsvorschriften: Gewerbeordnung, abrufbar unter [www.ris.bka.gv.at](https://www.ris.bka.gv.at)

            Medieninhaber: Mag. Stefan Haslinger
            Grundlegende Richtung: Vorführung der Shop-Software Mercator

            ## Haftung
            Alle Inhalte dieses Demo-Shops dienen nur der Vorführung; Angebote, Preise und Auskünfte sind unverbindlich und erfunden. Für die Inhalte verlinkter fremder Websites sind ausschließlich deren Betreiber verantwortlich.

            ## Datenschutz
            Wie wir mit Ihren Daten umgehen und welche Cookies wir verwenden, steht in der [Datenschutzerklärung](/pages/datenschutz).
            """,
            """
            ## Demo shop
            **Biber Holz is a fictitious company.** This shop demonstrates the shop software Mercator: products, prices, people and addresses are made up. Orders are not carried out, payments are only simulated, and all data is deleted every night.

            ## Operator and media owner
            Information according to § 5 ECG, § 14 UGB and § 63 GewO, disclosure according to § 25 MedienG (Austria)

            **Informatom EDV-Dienstleistungen e.U.**
            Owner: Mag. Stefan Haslinger
            Vorgartenstraße 145–157/2/3, 1020 Vienna, Austria
            Phone: +43 680 213 30 30
            Email: stefan.haslinger@informatom.com
            Web: [www.informatom.com](https://www.informatom.com)

            Legal form: registered sole proprietorship
            Company register number: FN 357693 w
            Register court: Commercial Court of Vienna (Handelsgericht Wien)
            VAT ID: ATU66331917
            Registered office: Vienna
            Business: services in automatic data processing and information technology
            Trade authority: Magistratisches Bezirksamt for the 2nd district of Vienna
            Applicable regulations: Austrian Trade Regulation Act (Gewerbeordnung), available at [www.ris.bka.gv.at](https://www.ris.bka.gv.at)

            Media owner: Mag. Stefan Haslinger
            Basic orientation: demonstration of the shop software Mercator

            ## Liability
            All content of this demo shop is for demonstration only; offers, prices and information are non-binding and made up. The operators of linked external websites are solely responsible for their content.

            ## Privacy
            How we handle your data and which cookies we use is described in the [privacy policy](/pages/datenschutz).
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
            ## Das Wichtigste in Kürze
            - Dies ist ein **Demo-Shop**. Bitte geben Sie keine echten persönlichen Daten ein; erfundene genügen zum Ausprobieren.
            - **Alle Daten werden jede Nacht um 3 Uhr gelöscht**: Kundenkonten, Bestellungen, Angebote, Gespräche und hochgeladene Dateien.
            - Wir verwenden **keine Analyse-, Tracking- oder Werbedienste**, keine fremden Schriften oder Content-Delivery-Netzwerke, und wir verkaufen keine Daten.
            - Wir setzen nur **technisch notwendige Cookies** (siehe unten).

            ## Verantwortlicher
            Informatom EDV-Dienstleistungen e.U., Mag. Stefan Haslinger
            Vorgartenstraße 145–157/2/3, 1020 Wien, Österreich
            Telefon: +43 680 213 30 30 · E-Mail: stefan.haslinger@informatom.com

            Biber Holz ist ein erfundenes Unternehmen; den Demo-Shop betreibt Informatom (siehe [Impressum](/pages/impressum)).

            ## Welche Daten wir verarbeiten und wozu
            **Kundenkonto:** E-Mail-Adresse, Name, Passwort (nur verschlüsselt als Hash gespeichert), Sprache, auf Wunsch Telefonnummer und Adressen. Zweck: Anmeldung, Bestellungen und Angebote. Rechtsgrundlage: Vertrag und vorvertragliche Maßnahmen (Art. 6 Abs. 1 lit. b DSGVO).

            **Warenkorb, Bestellungen und Angebote:** die gewählten Produkte, Adressen, Versand- und Zahlungsart. Gäste erhalten einen Warenkorb über das Sitzungs-Cookie. Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO.

            **Beratung im Chat:** Ihre Nachrichten und Dateien, das Thema und die Shop-Seite, auf der Sie gerade sind (die Beraterin oder der Berater sieht sie, solange das Gespräch läuft), ob Sie gerade im Shop sind, und auf Wunsch Ihre E-Mail-Adresse oder Telefonnummer für einen Rückruf sowie Ihre Bewertung. Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO, für Rückruf und Bewertung Ihre Einwilligung (Art. 6 Abs. 1 lit. a DSGVO).

            **Anrufe:** Anrufe (Ton, Video, Bildschirm teilen) laufen verschlüsselt über unseren eigenen Server, nicht über einen fremden Dienst, und werden nicht aufgezeichnet. Wir speichern nur, wann ein Anruf begann und endete und ob Video oder eine Bildschirmfreigabe genutzt wurden. Für die Verbindung sieht unser Server die IP-Adresse Ihres Geräts; kommt eine Verbindung nicht zustande, speichern wir die versuchten Netzwerkadressen zur Fehlersuche. Rechtsgrundlage: Art. 6 Abs. 1 lit. b und f DSGVO.

            **Kontaktformular:** Name, E-Mail-Adresse und Nachricht, um Ihre Anfrage zu beantworten; die Nachricht geht auch per E-Mail an uns. Rechtsgrundlage: Art. 6 Abs. 1 lit. b und f DSGVO.

            **E-Mails:** Bestätigungen, Anmeldelinks, Bestell- und Angebotsmails versenden wir über unseren eigenen Mailserver.

            **Sicherheit:** Um Konten vor dem Erraten von Passwörtern zu schützen, zählen wir Anmeldeversuche und angeforderte E-Mails je Adresse und IP-Adresse für 15 Minuten bis eine Stunde im Arbeitsspeicher. Wird eine Grenze erreicht, protokollieren wir die IP-Adresse. Rechtsgrundlage: berechtigtes Interesse an der Sicherheit des Shops (Art. 6 Abs. 1 lit. f DSGVO).

            **Zahlung:** Im Demo-Shop fließt kein Geld; Zahlungen werden simuliert. Wählen Sie eine Online-Zahlung im Testmodus, leiten wir Sie zur Zahlungsseite der Mollie B.V., Keizersgracht 126, 1015 CW Amsterdam, Niederlande, weiter. Wir übermitteln dabei nur den Betrag und die Bestellnummer; was Sie auf der Zahlungsseite eingeben, verarbeitet Mollie nach der eigenen [Datenschutzerklärung](https://www.mollie.com/at/privacy).

            **Benachrichtigungen für Mitarbeiter:** Mitarbeiterinnen und Mitarbeiter können sich über neue Gespräche aufs Telefon benachrichtigen lassen. Die Nachricht geht verschlüsselt über den Push-Dienst ihres Browsers (z. B. Google, Mozilla oder Apple), der den Inhalt nicht lesen kann.

            ## Cookies und Speicherung im Browser
            Wir verwenden nur Cookies, die für den Betrieb des Shops unbedingt nötig sind. Dafür ist keine Einwilligung erforderlich (§ 165 Abs. 3 TKG 2021); Analyse- oder Werbe-Cookies setzen wir nicht.

            | Name | Zweck | Speicherdauer |
            |---|---|---|
            | `_mercator_key` | Sitzung: Anmeldung, Warenkorb, Sprache und Schutz vor gefälschten Formularen | bis zum Schließen des Browsers |
            | `remember_me` | „Angemeldet bleiben“, nur wenn Sie es ankreuzen | 30 Tage oder bis zum Abmelden |

            Zusätzlich merkt sich Ihr Browser einige Einstellungen im lokalen Speicher. Diese werden nicht an uns übertragen:

            | Name | Zweck |
            |---|---|
            | `phx:theme` | helle oder dunkle Darstellung |
            | `mercator:chat-size` | Größe des Chatfensters |
            | `mercator:cookie-notice` | dass Sie den Cookie-Hinweis geschlossen haben |
            | `desk-available` | nur Mitarbeiter: verfügbar am Beratungsplatz (bis zum Schließen des Tabs) |

            Sie können Cookies und gespeicherte Daten jederzeit in Ihrem Browser löschen; danach sind Sie abgemeldet und Ihr Warenkorb als Gast ist leer.

            ## Speicherdauer
            Im Demo-Shop werden alle Daten jede Nacht um 3 Uhr gelöscht. Server-Protokolle bewahren wir höchstens sieben Tage auf.

            ## Empfänger
            Der Shop läuft auf unserem eigenen Server in Österreich. Wir geben Ihre Daten nicht weiter, außer an die oben genannten Dienste (Mollie bei einer Testzahlung, Push-Dienste für Mitarbeiter).

            ## Ihre Rechte
            Sie haben das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch sowie das Recht, eine Einwilligung jederzeit zu widerrufen. Schreiben Sie uns dazu an die oben genannte Adresse.

            Wenn Sie meinen, dass wir Ihre Daten nicht rechtmäßig verarbeiten, können Sie sich bei der Aufsichtsbehörde beschweren; in Österreich ist das die Datenschutzbehörde, Barichgasse 40–42, 1030 Wien, [www.dsb.gv.at](https://www.dsb.gv.at).
            """,
            """
            ## In short
            - This is a **demo shop**. Please do not enter real personal data; made-up data is enough to try it out.
            - **All data is deleted every night at 3 a.m.**: customer accounts, orders, offers, conversations and uploaded files.
            - We use **no analytics, tracking or advertising services**, no third-party fonts or content delivery networks, and we do not sell data.
            - We only set **strictly necessary cookies** (see below).

            ## Controller
            Informatom EDV-Dienstleistungen e.U., Mag. Stefan Haslinger
            Vorgartenstraße 145–157/2/3, 1020 Vienna, Austria
            Phone: +43 680 213 30 30 · Email: stefan.haslinger@informatom.com

            Biber Holz is a fictitious company; the demo shop is operated by Informatom (see [imprint](/pages/impressum)).

            ## What data we process and why
            **Customer account:** email address, name, password (only stored as an encrypted hash), language, and optionally phone number and addresses. Purpose: signing in, orders and offers. Legal basis: contract and pre-contractual measures (Art. 6(1)(b) GDPR).

            **Basket, orders and offers:** the chosen products, addresses, shipping and payment method. Guests get a basket through the session cookie. Legal basis: Art. 6(1)(b) GDPR.

            **Advice in the chat:** your messages and files, the topic and the shop page you are on (the consultant sees it while the conversation runs), whether you are in the shop right now, and on request your email address or phone number for a callback, and your rating. Legal basis: Art. 6(1)(b) GDPR, for callback and rating your consent (Art. 6(1)(a) GDPR).

            **Calls:** calls (audio, video, screen sharing) run encrypted through our own server, not a third-party service, and are not recorded. We only store when a call began and ended and whether video or screen sharing was used. For the connection our server sees your device's IP address; if a connection fails, we store the network addresses that were tried, to find the fault. Legal basis: Art. 6(1)(b) and (f) GDPR.

            **Contact form:** name, email address and message, to answer your request; the message is also emailed to us. Legal basis: Art. 6(1)(b) and (f) GDPR.

            **Emails:** we send confirmations, sign-in links, order and offer emails through our own mail server.

            **Security:** to protect accounts from password guessing, we count sign-in attempts and requested emails per address and IP address for 15 minutes to one hour in memory. If a limit is reached, we log the IP address. Legal basis: legitimate interest in the security of the shop (Art. 6(1)(f) GDPR).

            **Payment:** no money changes hands in the demo shop; payments are simulated. If you choose an online payment in test mode, we forward you to the payment page of Mollie B.V., Keizersgracht 126, 1015 CW Amsterdam, Netherlands. We only transmit the amount and the order number; what you enter on the payment page is processed by Mollie under its own [privacy policy](https://www.mollie.com/privacy).

            **Notifications for staff:** staff can be notified of new conversations on their phone. The message goes encrypted through their browser's push service (e.g. Google, Mozilla or Apple), which cannot read its content.

            ## Cookies and storage in the browser
            We only use cookies that are strictly necessary to run the shop. They need no consent (§ 165(3) of the Austrian Telecommunications Act, TKG 2021); we set no analytics or advertising cookies.

            | Name | Purpose | Duration |
            |---|---|---|
            | `_mercator_key` | session: sign-in, basket, language and protection against forged forms | until the browser is closed |
            | `remember_me` | "Remember me", only if you tick it | 30 days or until you sign out |

            In addition, your browser keeps a few settings in its local storage. They are not sent to us:

            | Name | Purpose |
            |---|---|
            | `phx:theme` | light or dark appearance |
            | `mercator:chat-size` | size of the chat window |
            | `mercator:cookie-notice` | that you closed the cookie notice |
            | `desk-available` | staff only: available at the sales desk (until the tab is closed) |

            You can delete cookies and stored data in your browser at any time; you are then signed out and your guest basket is empty.

            ## Storage period
            In the demo shop all data is deleted every night at 3 a.m. We keep server logs for at most seven days.

            ## Recipients
            The shop runs on our own server in Austria. We do not pass your data on, except to the services named above (Mollie for a test payment, push services for staff).

            ## Your rights
            You have the right of access, rectification, erasure, restriction of processing, data portability and objection, and the right to withdraw a consent at any time. Write to us at the address above.

            If you believe we process your data unlawfully, you can complain to the supervisory authority; in Austria this is the Datenschutzbehörde, Barichgasse 40–42, 1030 Vienna, [www.dsb.gv.at](https://www.dsb.gv.at).
            """
          )
        ]
      }
    ]
  end
end
