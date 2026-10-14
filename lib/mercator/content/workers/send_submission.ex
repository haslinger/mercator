defmodule Mercator.Content.Workers.SendSubmission do
  @moduledoc """
  Emails a contact form message to the shop address (brand `:email`, or
  the sender address of the shop's emails), reply-to the visitor.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  import Swoosh.Email

  alias Mercator.Brand
  alias Mercator.Content.Submission

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"submission_id" => id}}) do
    submission = Ash.get!(Submission, id, load: [:page], authorize?: false)

    with {:ok, _} <- submission |> email() |> Mercator.Mailer.deliver(), do: :ok
  end

  @doc "The email to the shop."
  def email(submission) do
    page = submission.page && " (#{submission.page.path})"

    text =
      Enum.join(
        [
          "Name: #{submission.name}",
          "E-Mail: #{submission.email}",
          submission.phone && "Telefon: #{submission.phone}",
          "",
          submission.message
        ]
        |> Enum.reject(&is_nil/1),
        "\n"
      )

    new()
    |> from(Mercator.Mailer.default_from())
    |> to(recipient())
    |> reply_to({submission.name, submission.email})
    |> subject("Kontaktanfrage von #{submission.name}#{page}")
    |> text_body(text)
  end

  @doc "Where contact requests go: the brand's email address, else the shop's sender address."
  def recipient, do: Brand.get(:email) || Mercator.Mailer.default_from()
end
