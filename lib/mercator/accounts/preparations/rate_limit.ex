defmodule Mercator.Accounts.Preparations.RateLimit do
  @moduledoc """
  Limits authentication attempts per email address (#87, `Mercator.RateLimit`):
  sign-ins (`bucket: :sign_in`) and emails for password reset or magic link
  (`bucket: :auth_email`), so passwords cannot be guessed at speed and no
  one's mailbox can be flooded. Works for read and generic actions.
  """
  use Ash.Resource.Preparation
  use Gettext, backend: MercatorWeb.Gettext

  @impl true
  def supports(_opts), do: [Ash.Query, Ash.ActionInput]

  @impl true
  def prepare(subject, opts, _context) do
    email = subject |> argument(:email) |> to_string() |> String.downcase()

    case Mercator.RateLimit.check(opts[:bucket], email) do
      :ok ->
        subject

      {:error, _retry_after} ->
        add_error(subject,
          field: :email,
          message: dgettext_noop("errors", "too many attempts, please try again later")
        )
    end
  end

  defp argument(%Ash.Query{} = query, name), do: Ash.Query.get_argument(query, name)
  defp argument(%Ash.ActionInput{} = input, name), do: Ash.ActionInput.get_argument(input, name)

  defp add_error(%Ash.Query{} = query, error), do: Ash.Query.add_error(query, error)
  defp add_error(%Ash.ActionInput{} = input, error), do: Ash.ActionInput.add_error(input, error)
end
