defmodule MercatorWeb.ContactFormTest do
  # not async: one test changes the global rate limit config
  use MercatorWeb.ConnCase, async: false
  use Oban.Testing, repo: Mercator.Repo

  import Phoenix.LiveViewTest
  import Mercator.AccountsFixtures

  alias Mercator.Content
  alias Mercator.Content.Workers.SendSubmission
  alias Swoosh.Email.Recipient

  doctest MercatorWeb.ClientIp

  setup do
    editor = user_fixture(roles: [:contentmanager])

    page =
      %{
        title: %{"de" => "Kontakt"},
        slug: "kontakt-test",
        blocks: [%{type: "contact_form", intro: %{"de" => "Schreiben Sie uns!"}}]
      }
      |> Content.create_page!(actor: editor)
      |> Content.publish_page!(actor: editor)

    [%{value: %{id: block_id}}] = page.blocks
    %{page: page, form: "#block-#{block_id}-form"}
  end

  defp params(attrs \\ %{}) do
    Map.merge(
      %{
        "name" => "Karl Luchs",
        "email" => "karl@example.com",
        "message" => "Brauche 5 m³ Fichte."
      },
      attrs
    )
  end

  test "visitors send a message; it is stored and emailed to the shop", %{
    conn: conn,
    page: page,
    form: form
  } do
    {:ok, view, _html} = live(conn, ~p"/pages/kontakt-test")
    assert has_element?(view, "#page", "Schreiben Sie uns!")

    view |> form(form, form: params(), website: "") |> render_submit()
    assert has_element?(view, "[id$='-sent']")

    [submission] = Content.list_submissions!(authorize?: false)
    assert submission.page_id == page.id
    assert submission.message =~ "Fichte"

    assert_enqueued worker: SendSubmission, args: %{submission_id: submission.id}
    assert :ok = perform_job(SendSubmission, %{submission_id: submission.id})
    assert_received {:email, %{subject: "Kontaktanfrage von Karl Luchs" <> _} = email}
    assert email.to == [Recipient.format(SendSubmission.recipient())]
    assert email.reply_to == {"Karl Luchs", "karl@example.com"}
  end

  test "invalid input is shown, nothing is stored", %{conn: conn, form: form} do
    {:ok, view, _html} = live(conn, ~p"/pages/kontakt-test")

    html =
      view
      |> form(form, form: params(%{"email" => "keine-adresse"}), website: "")
      |> render_submit()

    assert html =~ "valid email address" or html =~ "gültige"
    assert Content.list_submissions!(authorize?: false) == []
  end

  test "bots filling in the honeypot get a thank-you but nothing is stored", %{
    conn: conn,
    form: form
  } do
    {:ok, view, _html} = live(conn, ~p"/pages/kontakt-test")
    view |> form(form, form: params()) |> render_submit(%{"website" => "http://spam.example"})

    assert has_element?(view, "[id$='-sent']")
    assert Content.list_submissions!(authorize?: false) == []
  end

  test "too many messages from one address are refused", %{conn: conn, form: form} do
    previous = Application.get_env(:mercator, :rate_limits)
    Application.put_env(:mercator, :rate_limits, contact: {0, :timer.minutes(1)})
    on_exit(fn -> Application.put_env(:mercator, :rate_limits, previous || []) end)

    {:ok, view, _html} = live(conn, ~p"/pages/kontakt-test")
    view |> form(form, form: params(), website: "") |> render_submit()

    assert has_element?(view, "[id$='-limit']")
    assert Content.list_submissions!(authorize?: false) == []
  end

  describe "back office" do
    test "staff see open requests and mark them as handled", %{conn: conn, page: page} do
      submission =
        Content.submit_contact_form!(%{
          name: "Lena Igel",
          email: "lena@example.com",
          message: "Rückruf bitte",
          page_id: page.id
        })

      for roles <- [[], [:productmanager]] do
        other = log_in_user(build_conn(), user_fixture(roles: roles))
        assert {:error, {:redirect, %{to: "/"}}} = live(other, ~p"/admin/submissions")
      end

      conn = log_in_user(conn, user_fixture(roles: [:sales]))
      {:ok, view, _html} = live(conn, ~p"/admin/submissions")
      assert has_element?(view, "#submission-#{submission.id}", "Rückruf bitte")
      assert has_element?(view, "#submission-#{submission.id}", "/pages/kontakt-test")

      view |> element("#toggle-#{submission.id}") |> render_click()
      refute has_element?(view, "#submission-#{submission.id}")

      {:ok, view, _html} = live(conn, ~p"/admin/submissions?all=1")
      assert has_element?(view, "#submission-#{submission.id}")
    end
  end
end
