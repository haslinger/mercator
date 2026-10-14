defmodule Mercator.Consulting.ConsultingEmail do
  @moduledoc """
  Emails of guided selling (#97), text and HTML:

    * to the customer, in their language: a consultant answered while the
      customer was not in the shop; an offer was sent
    * to staff, in German like the other back office emails: a new
      conversation while nobody is at the sales desk; an offer awaits
      approval (#98)
  """
  use Gettext, backend: MercatorWeb.Gettext
  use MercatorWeb, :verified_routes

  import Swoosh.Email

  alias Mercator.Brand
  alias Mercator.Consulting.{Desk, Offer}
  alias Mercator.Content.Workers.SendSubmission
  alias MercatorWeb.Format

  @doc "A consultant's answers (`messages`) for a customer who is not online."
  def reply_notice(recipient, locale, messages) do
    Gettext.with_locale(MercatorWeb.Gettext, locale, fn ->
      lines =
        [gettext("Hello,"), "", gettext("our consultant has answered your question:"), ""] ++
          Enum.map(messages, &("> " <> message_text(&1, locale))) ++
          [
            "",
            gettext("Continue the conversation in our shop:"),
            url(~p"/?#{%{chat: "open"}}"),
            "",
            Brand.name()
          ]

      new()
      |> from(Mercator.Mailer.default_from())
      |> to(recipient)
      |> subject(gettext("Your consultant at %{shop} has answered", shop: Brand.name()))
      |> bodies(lines)
    end)
  end

  defp message_text(%{body: body}, _locale) when is_binary(body), do: body
  defp message_text(%{product: %{title: title}}, locale), do: Mercator.Translated.t(title, locale)
  defp message_text(%{link_title: title}, _locale) when is_binary(title), do: title
  defp message_text(%{link_url: url}, _locale) when is_binary(url), do: url
  defp message_text(%{offer_id: id}, _locale) when not is_nil(id), do: gettext("(an offer)")
  defp message_text(_message, _locale), do: gettext("(a file)")

  @doc "A sent offer for the customer (customer loaded)."
  def offer_sent(offer) do
    Gettext.with_locale(MercatorWeb.Gettext, offer.locale, fn ->
      number = Offer.display_number(offer)

      lines =
        [
          gettext("Hello,"),
          "",
          gettext("we have prepared an offer for you:"),
          "",
          gettext("Offer %{number}", number: number),
          gettext("Total: %{amount}", amount: Format.money(offer.gross, offer.locale)),
          gettext("valid until %{date}", date: Format.date(offer.valid_until)),
          "",
          gettext("You can see and accept the offer in your account:"),
          url(~p"/account/offers/#{offer.id}"),
          "",
          Brand.name()
        ]

      new()
      |> from(Mercator.Mailer.default_from())
      |> to(to_string(offer.customer.email))
      |> subject(gettext("Your offer %{number} from %{shop}", number: number, shop: Brand.name()))
      |> bodies(lines)
    end)
  end

  @doc "An offer awaits approval: to the sales managers (`recipients`)."
  def approval_request(offer, recipients) do
    number = Offer.display_number(offer)

    lines = [
      "Das Angebot #{number} für #{Desk.display_name(offer.customer)} wartet auf Ihre Freigabe.",
      "Erstellt von: #{offer.consultant && Desk.display_name(offer.consultant)}",
      "Summe: #{Format.money(offer.gross, "de")}",
      "",
      url(~p"/admin/offers/#{offer.id}")
    ]

    new()
    |> from(Mercator.Mailer.default_from())
    |> bcc(recipients)
    |> subject("Freigabe erbeten: Angebot #{number}")
    |> bodies(lines)
  end

  @doc "A new conversation while nobody is at the sales desk: to the shop address."
  def new_conversation(conversation) do
    question =
      conversation.messages
      |> Enum.filter(&(&1.sender_kind == :customer))
      |> Enum.map_join("\n", &("> " <> (&1.body || "")))

    lines =
      [
        "Ein neues Gespräch wartet, aber niemand ist am Beratungsplatz.",
        "Kunde: #{Desk.display_name(conversation.customer)}",
        "Thema: #{conversation.subject || "–"} (#{conversation.page || "–"})",
        ""
      ] ++
        String.split(question, "\n") ++
        ["", url(~p"/admin/desk/#{conversation.id}")]

    new()
    |> from(Mercator.Mailer.default_from())
    |> to(SendSubmission.recipient())
    |> subject(
      "Neues Gespräch: #{conversation.subject || Desk.display_name(conversation.customer)}"
    )
    |> bodies(lines)
  end

  defp bodies(email, lines),
    do: email |> text_body(Enum.join(lines, "\n")) |> html_body(html(lines))

  defp html(lines) do
    paragraphs =
      lines
      |> Enum.chunk_by(&(&1 == ""))
      |> Enum.reject(&Enum.all?(&1, fn line -> line == "" end))
      |> Enum.map_join("\n", fn chunk ->
        "<p>" <> Enum.map_join(chunk, "<br>", &escape/1) <> "</p>"
      end)

    ~s(<div style="font-family: sans-serif; line-height: 1.5">#{paragraphs}</div>)
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
