defmodule Mercator.Consulting.EmailsTest do
  # Presence (who is at the desk, who is online) is global: not async
  use Mercator.DataCase, async: false
  use Oban.Testing, repo: Mercator.Repo

  import Swoosh.TestAssertions
  import Mercator.AccountsFixtures
  import Mercator.CatalogFixtures

  alias Mercator.Consulting.{Conversations, Desk, Offers}

  alias Mercator.Consulting.Workers.{
    SendNewConversationNotice,
    SendOfferEmail,
    SendReplyNotice
  }

  alias MercatorWeb.Presence

  setup do
    context = %{
      consultant: user_fixture(roles: [:sales]) |> Ash.Seed.update!(%{name: "Sepp Fuchs"}),
      customer: user_fixture()
    }

    flush_emails()
    context
  end

  # registration sends confirmation emails to the test process
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  describe "answers for customers who are not in the shop" do
    test "one email with the answers since the customer's last message", context do
      {:ok, conversation} =
        Conversations.start({:user, context.customer}, "Lärche oder Douglasie?")

      {:ok, _} = Desk.post(conversation, context.consultant, "Für die Terrasse: Lärche.")
      {:ok, _} = Desk.post(conversation, context.consultant, "Sie hält länger.")

      assert [_job] = all_enqueued(worker: SendReplyNotice)
      assert :ok = perform_job(SendReplyNotice, %{conversation_id: conversation.id})

      assert_email_sent(fn email ->
        assert email.to == [{"", to_string(context.customer.email)}]
        assert email.text_body =~ "> Für die Terrasse: Lärche."
        assert email.text_body =~ "> Sie hält länger."
        refute email.text_body =~ "Lärche oder Douglasie?"
        assert email.text_body =~ "?chat=open"
      end)
    end

    test "no email when the customer is online, or a visitor without an address", context do
      {:ok, conversation} = Conversations.start({:user, context.customer}, "Hallo")
      Presence.track_customer(self(), conversation.id)
      {:ok, _} = Desk.post(conversation, context.consultant, "Grüß Gott!")
      refute_enqueued(worker: SendReplyNotice)

      {:ok, visit} = Conversations.start({:session, "mail-visitor"}, "Hallo")
      {:ok, _} = Desk.post(visit, context.consultant, "Grüß Gott!")
      assert :ok = perform_job(SendReplyNotice, %{conversation_id: visit.id})
      refute_email_sent()
    end

    test "a visitor who left an email address for a callback gets it", context do
      owner = {:session, "mail-visitor-2"}
      {:ok, conversation} = Conversations.start(owner, "Rückruf?")

      {:ok, _} =
        Conversations.request_callback(owner, conversation.id, :email, "karl@example.com")

      {:ok, _} =
        Desk.post(
          Desk.get(conversation.id, context.consultant) |> elem(1),
          context.consultant,
          "Gerne!"
        )

      assert :ok = perform_job(SendReplyNotice, %{conversation_id: conversation.id})
      assert_email_sent(to: [{"", "karl@example.com"}])
    end
  end

  test "a new conversation while nobody is at the desk", context do
    {:ok, conversation} =
      Conversations.start({:user, context.customer}, "Ist jemand da?", %{subject: "Sauna"})

    assert_enqueued(worker: SendNewConversationNotice, args: %{conversation_id: conversation.id})
    assert :ok = perform_job(SendNewConversationNotice, %{conversation_id: conversation.id})

    assert_email_sent(fn email ->
      assert email.subject =~ "Sauna"
      assert email.text_body =~ "> Ist jemand da?"
      assert email.text_body =~ "/admin/desk/#{conversation.id}"
    end)
  end

  test "a new conversation of a customer who would rather talk (#155)", context do
    {:ok, conversation} = Conversations.start_call({:user, context.customer})
    assert :ok = perform_job(SendNewConversationNotice, %{conversation_id: conversation.id})

    assert_email_sent(fn email ->
      assert email.text_body =~ "Der Kunde möchte telefonieren."
    end)
  end

  describe "offers" do
    setup context do
      [variant] = Ash.load!(product_fixture(), :variants).variants
      {:ok, offer} = Offers.create(context.customer.id, context.consultant)
      {:ok, offer} = Offers.add_product(offer, variant.id, 1, context.consultant)
      %{offer: offer}
    end

    test "the customer gets the sent offer", %{offer: offer} = context do
      {:ok, offer} = Offers.submit(offer, context.consultant)

      assert :ok = perform_job(SendOfferEmail, %{offer_id: offer.id, kind: "sent"})

      assert_email_sent(fn email ->
        assert email.to == [{"", to_string(context.customer.email)}]
        assert email.subject =~ offer.number
        assert email.text_body =~ "/account/offers/#{offer.id}"

        # the offer as PDF (#17)
        assert [%{filename: filename, content_type: "application/pdf", data: "%PDF-" <> _}] =
                 email.attachments

        assert filename =~ ".pdf"
      end)
    end

    test "sales managers are asked for approval", %{offer: offer} = context do
      manager = user_fixture(roles: [:sales_manager])
      flush_emails()
      {:ok, offer} = Offers.update(offer, %{discount_percent: "20"}, context.consultant)
      {:ok, offer} = Offers.submit(offer, context.consultant)

      assert_enqueued(worker: SendOfferEmail, args: %{offer_id: offer.id, kind: :approval})
      assert :ok = perform_job(SendOfferEmail, %{offer_id: offer.id, kind: "approval"})

      assert_email_sent(fn email ->
        assert {"", to_string(manager.email)} in email.bcc
        assert email.text_body =~ "/admin/offers/#{offer.id}"
      end)
    end
  end
end
