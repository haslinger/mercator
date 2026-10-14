defmodule Mercator.Consulting.Workers.SendNewConversationNotice do
  @moduledoc """
  A conversation was started while nobody was at the sales desk (#97): an
  email to the shop address, unless a consultant has taken it meanwhile.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  alias Mercator.Consulting.{ConsultingEmail, Conversation}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => id}}) do
    case Ash.get!(Conversation, id, load: [:customer, :messages], authorize?: false) do
      %{state: :waiting} = conversation ->
        with {:ok, _} <-
               conversation |> ConsultingEmail.new_conversation() |> Mercator.Mailer.deliver(),
             do: :ok

      _taken_or_closed ->
        :ok
    end
  end
end
