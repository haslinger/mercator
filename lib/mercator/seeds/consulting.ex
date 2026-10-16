defmodule Mercator.Seeds.Consulting do
  @moduledoc """
  Demo conversations and offers for guided selling (step 7), so the sales
  desk, the archive, the offer list and the customers' accounts have content:

    * Karl Luchs asked about a garden house; the offer was revised (with
      foundation and assembly), accepted and ordered; rated 5 stars.
    * Karl Luchs asked about a terrace; the offer expired.
    * Karl Luchs has a sent offer for firewood (without a conversation)
      that he can still order.
    * Lena Igel (English) was advised on delivery to Germany (4 stars) and
      is being advised on pellets now; the offer with 12 % discount waits
      for a sales manager's approval (#98).
    * A visitor is waiting and asked for a callback (#95).
    * Calls (phase 10): Sepp called Karl about the garden house by video and
      shared a plan; Lena declined a call about the pellets.

  Everything goes through the real functions as the demo staff and is then
  backdated; emails are dropped. Each scenario is identified by its
  conversation subject (or offer note) and is not created twice.
  """

  import Ecto.Query, only: [from: 2]

  alias Mercator.Accounts.User
  alias Mercator.{Catalog, Repo, Sales}
  alias Mercator.Consulting.{Call, Calls, Conversation, Conversations, Desk, Offer, Offers}
  alias Mercator.Sales.Checkout
  alias Mercator.Seeds.Orders

  require Ash.Query

  @visitor_token "seed-visitor-brennholz"

  @workers [
    "Mercator.Consulting.Workers.SendCallbackRequest",
    "Mercator.Consulting.Workers.SendNewConversationNotice",
    "Mercator.Consulting.Workers.SendOfferEmail",
    "Mercator.Consulting.Workers.SendPhoneNotification",
    "Mercator.Consulting.Workers.SendReplyNotice",
    "Mercator.Consulting.Workers.WatchCall",
    "Mercator.Sales.Workers.SendOrderConfirmation"
  ]

  @doc "Creates the demo conversations and offers that do not exist yet."
  def run do
    last_job = Repo.one(from j in Oban.Job, select: max(j.id)) || 0

    staff = %{
      sepp: user!("sales@mittenin.at"),
      maria: user!("manager@mittenin.at"),
      karl: user!("kunde@mittenin.at"),
      lena: user!("customer@mittenin.at")
    }

    garden_house(staff)
    terrace(staff)
    firewood_offer(staff)
    delivery_to_germany(staff)
    greenhouse_pellets(staff)
    waiting_visitor()

    Repo.delete_all(from j in Oban.Job, where: j.worker in @workers and j.id > ^last_job)
    :ok
  end

  # Karl: garden house, offer revised, accepted and ordered, rated
  defp garden_house(%{sepp: sepp, karl: karl}) do
    subject = "Gartenhaus „Almhütte“"

    unless conversation?(subject) do
      owner = {:user, karl}
      variant = variant!("BH-GH-ALM-3X4")

      c =
        start(
          owner,
          -21,
          0,
          "Grüß Gott! Passt das Gartenhaus 3 × 4 m auf einen leichten Hang?",
          %{
            subject: subject,
            page: "/products/gartenhaus-almhuette",
            product_id: variant.product_id
          }
        )

      c =
        c
        |> step(-21, 2, fn c ->
          Desk.post(
            c,
            sepp,
            "Grüß Gott, Herr Luchs! Bei leichtem Hang empfehlen wir Punktfundamente, dann steht das Haus waagrecht und luftig."
          )
        end)
        |> step(-21, 4, fn c ->
          customer(
            owner,
            c,
            "Können Sie das Fundament auch machen? Und was kostet das Ganze mit Lasur?"
          )
        end)
        |> step(-21, 6, fn c ->
          Desk.recommend(
            c,
            sepp,
            product_id("BH-OEL-TERRASSE-1"),
            "Für die Almhütte nehmen wir das Lärchenöl, zwei Gebinde reichen für den ersten Anstrich."
          )
        end)
        |> call(sepp, owner, -21, 8, talk: 6, screen: true)

      {:ok, offer} = Offers.create_for_conversation(c, sepp)
      {:ok, offer} = Offers.add_product(offer, variant.id, 1, sepp)
      {:ok, offer} = Offers.add_product(offer, variant_id("BH-OEL-TERRASSE-1"), 2, sepp)
      {:ok, offer} = discount_item(offer, 0, "5", sepp)
      {:ok, v1} = submit_at(c, offer, sepp, -21, 15)

      c =
        c
        |> step(-21, 20, fn c ->
          customer(owner, c, "Danke! Bitte noch mit Fundament und Montage, dann bestelle ich.")
        end)
        |> step(-20, 0, fn c ->
          Desk.post(
            c,
            sepp,
            "Gerne, ich schicke Ihnen eine neue Version mit Punktfundament und Montage."
          )
        end)

      {:ok, v2} = Offers.revise(v1, sepp)

      {:ok, v2} =
        Offers.add_text(
          v2,
          %{
            title: "Punktfundamente und Montage vor Ort",
            description: "8 Punktfundamente, Aufbau durch unser Montageteam (2 Tage)",
            quantity: 1,
            unit: :piece,
            unit_net: Decimal.new("1450")
          },
          sepp
        )

      backdate_offer(v2, at(-20, 5), nil)
      {:ok, v2} = submit_at(c, v2, sepp, -20, 10)

      c =
        c
        |> step(-20, 30, fn c ->
          customer(owner, c, "Passt so, ich bestelle gleich. Vielen Dank für die Beratung!")
        end)
        |> step(-20, 35, fn c -> Desk.close(c, sepp) end)

      {:ok, _c} =
        Conversations.rate(
          owner,
          c.id,
          5,
          "Sehr kompetent, sogar das Fundament wurde mitgedacht."
        )

      backdate_conversation(c, rated_at: at(-20, 50))

      order = order_offer(v2, karl, "Montage wie im Angebot besprochen.")

      order =
        Sales.confirm_order!(
          order,
          %{shipping_gross: "0", note: "Lieferung und Montage in KW 46.", notify: false},
          actor: sepp
        )

      Orders.backdate(order, at(-19, 0), [1])
      Repo.update_all(offer_query(v2.id), set: [accepted_at: at(-19, 0)])
    end
  end

  # Karl: terrace, offer expired
  defp terrace(%{sepp: sepp, karl: karl}) do
    subject = "Terrasse aus Lärche"

    unless conversation?(subject) do
      owner = {:user, karl}

      c =
        start(
          owner,
          -60,
          0,
          "Ich plane eine Terrasse mit 20 m². Welche Dielen halten am längsten?",
          %{
            subject: subject,
            page: "/categories/terrassendielen"
          }
        )

      c =
        c
        |> step(-60, 3, fn c ->
          Desk.post(
            c,
            sepp,
            "Lärche ist heimisch und hält unbehandelt viele Jahre. Douglasie ist etwas günstiger."
          )
        end)
        |> step(-60, 4, fn c ->
          Desk.recommend(
            c,
            sepp,
            product_id("BH-TD-LAE-4M"),
            "Mit 4-m-Dielen haben Sie wenig Verschnitt."
          )
        end)
        |> step(-60, 6, fn c ->
          Desk.share_link(c, sepp, "/pages/faq", "Häufige Fragen zu Holz im Garten")
        end)
        |> step(-60, 9, fn c ->
          customer(owner, c, "Könnten Sie mir ein Angebot für alles machen?")
        end)

      {:ok, offer} = Offers.create_for_conversation(c, sepp)
      {:ok, offer} = Offers.add_product(offer, variant_id("BH-TD-LAE-4M"), 40, sepp)
      {:ok, offer} = Offers.add_product(offer, variant_id("BH-TD-UK-LAE-1"), 18, sepp)
      {:ok, offer} = Offers.add_product(offer, variant_id("BH-TD-SCHRAUBEN-1"), 3, sepp)

      {:ok, offer} =
        Offers.update(offer, %{note: "Gerne liefern wir Ihnen alles für Ihre Terrasse."}, sepp)

      {:ok, offer} = submit_at(c, offer, sepp, -60, 20)

      c =
        c
        |> step(-60, 25, fn c -> customer(owner, c, "Danke, ich melde mich nach dem Urlaub.") end)
        |> step(-60, 26, fn c -> Desk.close(c, sepp) end)

      backdate_conversation(c)

      Repo.update_all(offer_query(offer.id),
        set: [valid_until: Date.add(Mercator.Clock.today(), -30)]
      )

      Ash.update!(offer, %{}, action: :expire, authorize?: false)
    end
  end

  # Karl: an offer without a conversation, still valid
  defp firewood_offer(%{maria: maria, karl: karl}) do
    note = "Ihr Wintervorrat: trockene Buche, ofenfertig, frei Haus geliefert."

    unless Repo.exists?(from o in "offers", where: o.note == ^note) do
      {:ok, offer} =
        Offers.create(karl.id, maria, %{note: note, discount_percent: Decimal.new(5)})

      {:ok, offer} = Offers.add_product(offer, variant_id("BH-SCHEIT-BUCHE-33CM"), 6, maria)
      {:ok, offer} = Offers.add_product(offer, variant_id("BH-ANZUENDHOLZ-1"), 2, maria)
      {:ok, offer} = Offers.submit(offer, maria)
      sent_at = at(-3, 0)

      Repo.update_all(offer_query(offer.id),
        set: [
          inserted_at: sent_at,
          updated_at: sent_at,
          sent_at: sent_at,
          valid_until: Date.add(Mercator.Clock.today(), 27)
        ]
      )
    end
  end

  # Lena: an earlier conversation, answered and rated
  defp delivery_to_germany(%{maria: maria, lena: lena}) do
    subject = "Delivery to Germany"

    unless conversation?(subject) do
      owner = {:user, lena}

      c =
        start(
          owner,
          -30,
          0,
          "Hello! Do you deliver pellets to Munich, and how long does it take?",
          %{subject: subject, page: "/"}
        )

      c =
        c
        |> step(-30, 5, fn c ->
          Desk.post(
            c,
            maria,
            "Hello Ms Igel! Yes, we deliver to Germany by parcel within about 5 working days; pallets by freight."
          )
        end)
        |> step(-30, 7, fn c -> customer(owner, c, "Great, thank you!") end)
        |> step(-30, 8, fn c -> Desk.close(c, maria) end)

      {:ok, _c} =
        Conversations.rate(
          owner,
          c.id,
          4,
          "Quick answer. Freight costs would have been nice to know."
        )

      backdate_conversation(c, rated_at: at(-30, 12))
    end
  end

  # Lena: being advised now; the offer waits for approval
  defp greenhouse_pellets(%{sepp: sepp, lena: lena}) do
    subject = "Pellets for our greenhouse heating"

    unless conversation?(subject) do
      owner = {:user, lena}
      variant = variant!("BH-PELLETS-SACK-PALETTE")

      c =
        start(
          owner,
          0,
          -95,
          "We heat our show greenhouse with pellets. Can we get a better price for three pallets?",
          %{
            subject: subject,
            page: "/products/holzpellets-enplus-a1-sack-15-kg",
            product_id: variant.product_id
          }
        )

      c =
        c
        |> step(0, -92, fn c ->
          Desk.post(
            c,
            sepp,
            "Good afternoon, Ms Igel! For three pallets I can offer you a special price; I will prepare an offer."
          )
        end)
        |> step(0, -88, fn c ->
          customer(owner, c, "Perfect. Delivery in two weeks would be fine.")
        end)
        |> call(sepp, owner, 0, -87, talk: 0, locale: "en")

      {:ok, offer} = Offers.create_for_conversation(c, sepp)
      {:ok, offer} = Offers.add_product(offer, variant.id, 3, sepp)
      {:ok, offer} = discount_item(offer, 0, "12", sepp)

      {:ok, offer} =
        Offers.update(offer, %{note: "Delivery by freight in about two weeks."}, sepp)

      {:ok, offer} = Offers.submit(offer, sepp)

      Repo.update_all(offer_query(offer.id),
        set: [inserted_at: at(0, -85), updated_at: at(0, -80)]
      )

      c =
        step(c, 0, -80, fn c ->
          Desk.post(
            c,
            sepp,
            "The offer is with my manager for approval; you will receive it shortly."
          )
        end)

      backdate_conversation(c)
    end
  end

  # a visitor waited in vain and left a phone number
  defp waiting_visitor do
    subject = "Brennholz für den Winter"

    unless conversation?(subject) do
      owner = {:session, @visitor_token}

      c =
        start(
          owner,
          0,
          -40,
          "Hallo, liefern Sie Brennholz auch ins Zillertal? Wir bräuchten 8 Raummeter.",
          %{
            subject: subject,
            page: "/products/brennholz-buche-ofenfertig"
          }
        )

      c =
        step(c, 0, -37, fn c ->
          Conversations.request_callback(owner, c.id, :phone, "+43 664 1234567")
        end)

      backdate_conversation(c)
    end
  end

  ## helpers

  defp user!(email) do
    User |> Ash.Query.filter(email == ^email) |> Ash.read_one!(authorize?: false)
  end

  defp variant!(number), do: Catalog.get_variant_by_number!(number, authorize?: false)
  defp variant_id(number), do: variant!(number).id
  defp product_id(number), do: variant!(number).product_id

  defp conversation?(subject) do
    Conversation |> Ash.Query.filter(subject == ^subject) |> Ash.exists?(authorize?: false)
  end

  # `days` (negative: ago) and `minutes` from now, so seeding always looks recent
  defp at(days, minutes),
    do: DateTime.utc_now() |> DateTime.add(days, :day) |> DateTime.add(minutes, :minute)

  defp start(owner, days, minutes, body, context) do
    {:ok, c} = Conversations.start(owner, body, context)
    stamp_messages(c, at(days, minutes))
    reload(c)
  end

  defp customer(owner, c, body), do: Conversations.post(owner, c.id, body)

  # runs an action in the conversation and moves the messages it wrote to that time
  defp step(c, days, minutes, fun) do
    {:ok, _} = fun.(c)
    stamp_messages(c, at(days, minutes))
    reload(c)
  end

  defp reload(c), do: Ash.get!(Conversation, c.id, authorize?: false)

  defp end_call(call, _consultant, owner, 0, _screen?),
    do: Conversations.hang_up_call(owner, call.id)

  defp end_call(call, consultant, owner, _talk, screen?) do
    {:ok, call} = Conversations.accept_call(owner, call.id)

    if screen?,
      do: Ash.update!(call, %{screen_shared: true}, action: :note_media, authorize?: false)

    Desk.hang_up(call, consultant)
  end

  # A call by the consultant at `days`/`minutes`: answered and `talk` minutes
  # long, or declined (`talk: 0`); then the call and its chat line are moved
  # to that time (the line names the times, so it is written again).
  defp call(c, consultant, owner, days, minutes, opts) do
    Gettext.with_locale(MercatorWeb.Gettext, Keyword.get(opts, :locale, "de"), fn ->
      {:ok, call} = Desk.call(c, consultant, Keyword.get(opts, :video, true))
      talk = Keyword.fetch!(opts, :talk)
      started = at(days, minutes)

      {:ok, _call} = end_call(call, consultant, owner, talk, opts[:screen])

      answered = if talk > 0, do: [answered_at: DateTime.add(started, 20, :second)], else: []

      Repo.update_all(
        from(row in "conversation_calls", where: row.id == type(^call.id, :binary_id)),
        set: [inserted_at: started, ended_at: DateTime.add(started, talk, :minute)] ++ answered
      )

      line = Calls.summary(Ash.get!(Call, call.id, authorize?: false))

      Repo.update_all(
        from(m in "conversation_messages",
          where:
            m.conversation_id == type(^c.id, :binary_id) and m.sender_kind == "system" and
              m.inserted_at > ^DateTime.add(DateTime.utc_now(), -60, :second)
        ),
        set: [body: line]
      )

      stamp_messages(c, DateTime.add(started, talk, :minute))
      reload(c)
    end)
  end

  # messages written just now (later than any backdated one), a few seconds apart
  defp stamp_messages(c, time) do
    from(m in "conversation_messages",
      where:
        m.conversation_id == type(^c.id, :binary_id) and
          m.inserted_at > ^DateTime.add(DateTime.utc_now(), -60, :second),
      order_by: m.inserted_at,
      select: m.id
    )
    |> Repo.all()
    |> Enum.with_index()
    |> Enum.each(fn {id, index} ->
      Repo.update_all(from(m in "conversation_messages", where: m.id == ^id),
        set: [inserted_at: DateTime.add(time, index, :second)]
      )
    end)
  end

  # the conversation spans its (backdated) messages
  defp backdate_conversation(c, extra \\ []) do
    c = reload(c)

    {started_at, last_at} =
      Repo.one(
        from m in "conversation_messages",
          where: m.conversation_id == type(^c.id, :binary_id),
          select: {min(m.inserted_at), max(m.inserted_at)}
      )

    closed = if c.state == :closed, do: [closed_at: last_at], else: []

    Repo.update_all(from(row in "conversations", where: row.id == type(^c.id, :binary_id)),
      set:
        [inserted_at: started_at, updated_at: last_at, last_message_at: last_at] ++
          closed ++ extra
    )
  end

  defp discount_item(offer, index, percent, actor) do
    offer.items
    |> Enum.at(index)
    |> Offers.update_item(%{discount_percent: Decimal.new(percent)}, actor)
  end

  defp submit_at(c, offer, actor, days, minutes) do
    {:ok, offer} = Offers.submit(offer, actor)
    stamp_messages(c, at(days, minutes))
    backdate_offer(offer, at(days, minutes - 5), at(days, minutes))
    {:ok, Ash.get!(Offer, offer.id, authorize?: false)}
  end

  defp backdate_offer(offer, created_at, sent_at) do
    sent =
      if sent_at,
        do: [sent_at: sent_at, valid_until: Date.add(DateTime.to_date(sent_at), 30)],
        else: []

    Repo.update_all(offer_query(offer.id),
      set: [inserted_at: created_at, updated_at: sent_at || created_at] ++ sent
    )
  end

  defp offer_query(id), do: from(o in "offers", where: o.id == type(^id, :binary_id))

  defp order_offer(offer, customer, note) do
    {:ok, offer} = Offers.for_checkout(offer.id, customer)

    params = %{
      "shipping_method" => "freight",
      "payment_method" => "prepayment",
      "gtc" => "true",
      "note" => note
    }

    {:ok, order} = Checkout.place(customer, params, {:offer, offer})
    order
  end
end
